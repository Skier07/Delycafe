from django.test import SimpleTestCase

from catalog.page_content import parse_content, content_to_plain_text


class PageContentIconsTests(SimpleTestCase):
    def test_text_keeps_its_icon_through_normalization(self):
        content = {'lines': [{'text': 'Бонусы', 'icon_url': ' /media/bonus.png '}]}
        line = parse_content(content)['lines'][0]
        self.assertEqual(line['icon_url'], '/media/bonus.png')
        self.assertEqual(line['type'], 'text')
        self.assertEqual(content_to_plain_text(content), 'Бонусы')

    def test_existing_images_remain_separate_blocks(self):
        content = {'lines': [{'type': 'image', 'image_url': '/media/photo.png'}]}
        line = parse_content(content)['lines'][0]
        self.assertEqual(line['type'], 'image')
        self.assertEqual(line['icon_url'], '')
