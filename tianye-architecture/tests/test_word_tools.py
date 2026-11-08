"""Regression checks for template preservation and safe generation."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from zipfile import ZipFile
from lxml import etree as E

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_word', ROOT / 'scripts/build_word.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
spec = importlib.util.spec_from_file_location('verify_document', ROOT / 'scripts/verify_document.py')
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class WordToolsTest(unittest.TestCase):
    def test_template_preservation_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'letter.docx'
            builder.build(ROOT/'templates/document_input.example.json', output)
            self.assertTrue(validator.verify(output)['passed'])
            with ZipFile(ROOT/'assets/tianye_letterhead_v03.docx') as source, ZipFile(output) as result:
                for name in source.namelist():
                    if not name.endswith('/') and name.startswith(('word/header', 'word/footer', 'word/media')):
                        original, actual = source.read(name), result.read(name)
                        if name.endswith('.xml'):
                            original = E.tostring(E.fromstring(original), method='c14n')
                            actual = E.tostring(E.fromstring(actual), method='c14n')
                        self.assertEqual(original, actual, name)
            original_hash = hashlib.sha256(output.read_bytes()).hexdigest()
            with self.assertRaises(FileExistsError):
                builder.build(ROOT/'templates/document_input.example.json', output)
            self.assertEqual(original_hash, hashlib.sha256(output.read_bytes()).hexdigest())

    def test_invalid_content_leaves_no_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)/'bad.json'
            output = Path(directory)/'bad.docx'
            source.write_text(json.dumps({'title':'test','paragraphs':[{'type':'unknown','text':'x'}]}))
            with self.assertRaises(ValueError):
                builder.build(source,output)
            self.assertFalse(output.exists())

    def test_skill_asset_cannot_be_output(self):
        with self.assertRaises(ValueError):
            builder.build(ROOT/'templates/document_input.example.json', ROOT/'assets/forbidden.docx')


if __name__ == '__main__':
    unittest.main()
