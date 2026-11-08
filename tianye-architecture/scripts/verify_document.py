"""Inspect the template invariants and, when supplied, the actual PDF output."""
import argparse
import json
import re
from pathlib import Path
from zipfile import ZipFile
from lxml import etree as E

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
W = '{' + NS['w'] + '}'


def verify(docx_path, pdf_path=None):
    errors = []
    with ZipFile(docx_path) as package:
        body = E.fromstring(package.read('word/document.xml'))
        styles = E.fromstring(package.read('word/styles.xml'))
        settings = E.fromstring(package.read('word/settings.xml'))
        for section in body.findall('.//w:sectPr', NS):
            size = section.find('w:pgSz', NS)
            if size is None or abs(int(size.get(W+'w', 0))-11906)>3 or abs(int(size.get(W+'h', 0))-16838)>3:
                errors.append('Page size is not A4')
        for name, expected in [('Title', 28), ('Heading 1', 24), ('Heading 2', 22), ('Normal', 22)]:
            matches = [s for s in styles.findall('w:style', NS) if s.find('w:name', NS) is not None and s.find('w:name', NS).get(W+'val', '').casefold() == name.casefold()]
            if not matches or matches[0].find('w:rPr/w:sz', NS) is None or int(matches[0].find('w:rPr/w:sz', NS).get(W+'val')) != expected:
                errors.append('Unexpected size for '+name)
        if settings.find('w:updateFields', NS) is None:
            errors.append('Missing update-on-open setting')
        footer_names = [n for n in package.namelist() if re.fullmatch(r'word/footer\d+\.xml', n)]
        instructions = ''
        for name in footer_names:
            footer = E.fromstring(package.read(name))
            for p in footer.findall('.//w:p', NS):
                code = ''.join(p.xpath('.//w:instrText/text()', namespaces=NS))
                instructions += code
                if 'NUMPAGES' in code:
                    align = p.find('w:pPr/w:jc', NS)
                    if align is None or align.get(W+'val') != 'center':
                        errors.append('Page number is not centered')
        if not all(x in instructions for x in ('IF', 'PAGE', 'NUMPAGES')):
            errors.append('Missing conditional page fields')
        for color in body.findall('.//w:body//w:color', NS):
            if color.get(W+'val', '000000').upper() not in ('000000', 'AUTO'):
                errors.append('Non-black body text')
    report = {'docx': str(docx_path), 'errors': errors, 'pdf_checked': False, 'visual_review': 'required'}
    if pdf_path:
        import pdfplumber
        with pdfplumber.open(pdf_path) as pdf:
            report['pdf_checked'] = True
            report['pages'] = len(pdf.pages)
            report['fonts'] = sorted({c['fontname'].split('+')[-1] for page in pdf.pages for c in page.chars})
            for index, page in enumerate(pdf.pages, 1):
                text = page.extract_text() or ''
                compact = re.sub(r'\s+', '', text)
                expected = f'第{index}页／共{len(pdf.pages)}页'
                if len(pdf.pages) == 1 and '／共' in compact:
                    errors.append('Single-page document shows page numbers')
                if len(pdf.pages) > 1:
                    if expected not in compact:
                        errors.append('Incorrect page number on page '+str(index))
                    else:
                        hits = page.search(r'第\s*'+str(index)+r'\s*页／共\s*'+str(len(pdf.pages))+r'\s*页')
                        if not hits or abs((hits[-1]['x0']+hits[-1]['x1'])/2-page.width/2)>3:
                            errors.append('PDF page number off center')
                for c in page.chars:
                    if 'MiSans' not in c['fontname']:
                        errors.append('Font substituted: '+c['fontname'])
                    if 100 < c['top'] < page.height-100:
                        color = c.get('non_stroking_color')
                        if isinstance(color, (tuple, list)) and len(color) == 3 and len(set(color)) != 1:
                            errors.append('Colored body text in PDF')
                for contact in ('+86-020-36213559', 'tianye_design@126.com'):
                    if contact not in text:
                        errors.append('Missing repeated contact on page '+str(index))
    report['errors'] = sorted(set(errors))
    report['passed'] = not errors
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('docx')
    parser.add_argument('--pdf')
    args = parser.parse_args()
    result = verify(Path(args.docx), args.pdf)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    raise SystemExit(0 if result['passed'] else 1)
