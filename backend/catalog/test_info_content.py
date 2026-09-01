from django.test import SimpleTestCase

from catalog.info_content import content_to_plain_text, parse_content, resolved_lines
from catalog.widgets import InfoContentField


class InfoContentTests(SimpleTestCase):
    def test_parse_legacy_text(self):
        content = parse_content(None, 'Простой текст')

        self.assertEqual(len(content['lines']), 1)
        self.assertEqual(content['lines'][0]['text'], 'Простой текст')
        self.assertEqual(content['lines'][0]['marker'], 'bullet')

    def test_content_to_plain_text(self):
        content = {
            'lines': [
                {'text': 'Первый', 'marker': 'bullet'},
                {'text': 'Второй', 'marker': 'number'},
            ],
        }

        self.assertEqual(content_to_plain_text(content), 'Первый\nВторой')

    def test_resolved_lines_filters_empty(self):
        content = {
            'lines': [
                {'text': 'Есть текст', 'marker': 'dash'},
                {'text': '', 'marker': 'bullet'},
            ],
        }

        lines = resolved_lines(content)
        self.assertEqual(len(lines), 1)
        self.assertEqual(lines[0]['marker'], 'dash')

    def test_info_content_field_bound_data_accepts_dict(self):
        field = InfoContentField()
        payload = {
            'lines': [
                {'text': 'Текст', 'marker': 'bullet', 'font_size': 'normal'},
            ],
        }

        self.assertEqual(field.bound_data(payload, {}), parse_content(payload))
