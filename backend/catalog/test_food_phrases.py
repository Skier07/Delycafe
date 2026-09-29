from django.test import TestCase
from rest_framework.test import APIClient

from .models import FoodPhrase


class FoodPhraseTests(TestCase):
    def test_seed_contains_fifty_phrases(self):
        self.assertEqual(FoodPhrase.objects.count(), 50)

    def test_public_read_only_list_reflects_admin_edits(self):
        FoodPhrase.objects.all().delete()
        phrase = FoodPhrase.objects.create(text='Перерыв на пасту', sort_order=1)
        FoodPhrase.objects.create(text='Скрытая', is_active=False)
        client = APIClient()
        url = '/api/catalog/food-phrases/'
        self.assertEqual(client.get(url).json(), ['Перерыв на пасту'])
        phrase.text = 'Пора обедать'
        phrase.save()
        self.assertEqual(client.get(url).json(), ['Пора обедать'])
        self.assertEqual(client.post(url, {'text': 'Нельзя'}).status_code, 405)
        phrase.is_active = False
        phrase.save()
        self.assertEqual(client.get(url).json(), [])
