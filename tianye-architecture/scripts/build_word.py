"""Fill the bundled letterhead with confirmed structured content."""
import argparse
import json
from pathlib import Path
import os
import tempfile

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Pt, RGBColor

SKILL = Path(__file__).resolve().parents[1]
STYLES = {'body': 'Normal', 'heading1': 'Heading 1', 'heading2': 'Heading 2', 'attachment': 'Normal'}


def build(input_path, output_path, template_path=None):
    source = Path(input_path).resolve()
    target = Path(output_path).resolve()
    template = Path(template_path or SKILL / 'assets/tianye_letterhead_v03.docx').resolve()
    if target.suffix.lower() != '.docx':
        raise ValueError('Output must have the .docx extension')
    if target in (source, template) or SKILL / 'assets' in target.parents:
        raise ValueError('Output must be a new working document outside skill assets')
    if target.exists():
        raise FileExistsError('Output already exists; choose a new versioned filename')
    payload = json.loads(source.read_text(encoding='utf-8-sig'))
    if not isinstance(payload.get('title'), str) or not payload['title'].strip():
        raise ValueError('A non-empty title is required')
    paragraphs = payload.get('paragraphs', [])
    if not isinstance(paragraphs, list):
        raise ValueError('paragraphs must be an array')
    if not isinstance(payload.get('recipient', ''), str):
        raise ValueError('recipient must be text')
    signoff = payload.get('signoff', [])
    if not isinstance(signoff, list) or any(not isinstance(line, str) for line in signoff):
        raise ValueError('signoff must be an array of text lines')
    for block in paragraphs:
        if not isinstance(block, dict) or block.get('type', 'body') not in STYLES or not isinstance(block.get('text'), str):
            raise ValueError('Each paragraph needs a supported type and text')
    doc = Document(template)
    body = doc.element.body
    for child in list(body):
        if child.tag != qn('w:sectPr'):
            body.remove(child)

    def paragraph(text, style='Normal', align=None):
        p = doc.add_paragraph(text, style)
        if align is not None:
            p.alignment = align
        for run in p.runs:
            run.font.name = 'MiSans'
            fonts = run._r.get_or_add_rPr().get_or_add_rFonts()
            fonts.attrib.clear()
            for key in ('ascii', 'hAnsi', 'eastAsia', 'cs'):
                fonts.set(qn('w:' + key), 'MiSans')
            run.font.color.rgb = RGBColor(0, 0, 0)
        return p

    paragraph(payload['title'], 'Title')
    if payload.get('recipient'):
        paragraph(payload['recipient'])
    for block in paragraphs:
        paragraph(block['text'], STYLES[block.get('type', 'body')])
    for text in payload.get('signoff', []):
        p = paragraph(text, align=WD_ALIGN_PARAGRAPH.RIGHT)
        p.paragraph_format.keep_with_next = True
    if doc.paragraphs:
        doc.paragraphs[-1].paragraph_format.keep_with_next = False
    title = doc.styles['Title']
    title.font.size = Pt(14)
    for section in doc.sections:
        for p in section.footer.paragraphs:
            if any('NUMPAGES' in node.text for node in p._p.iter(qn('w:instrText')) if node.text):
                p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    update = doc.settings.element.find(qn('w:updateFields'))
    if update is None:
        update = OxmlElement('w:updateFields')
        doc.settings.element.append(update)
    update.set(qn('w:val'), 'true')
    doc.core_properties.title = payload['title']
    doc.core_properties.last_modified_by = 'TIANYE ARCHITECTURE'
    target.parent.mkdir(parents=True, exist_ok=True)
    # Never leave a half-written DOCX or replace a concurrent caller's output.
    with tempfile.NamedTemporaryFile(dir=target.parent, suffix='.docx', delete=False) as stream:
        temporary = Path(stream.name)
    try:
        doc.save(temporary)
        if os.name == 'nt':
            os.rename(temporary, target)
        else:
            os.link(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)
    return {'output': str(target), 'template': template.name, 'rendered': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--template')
    args = parser.parse_args()
    print(json.dumps(build(args.input, args.output, args.template), ensure_ascii=False))
