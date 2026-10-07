import json
from io import StringIO
from unittest.mock import Mock, patch

from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import SimpleTestCase, override_settings


@override_settings(SABY_POINT_ID=187, SABY_PRICE_LIST_ID=4)
class SabyDeliveryLookupTests(SimpleTestCase):
    @patch('catalog.services.saby_catalog_service.SabyCatalogService.get_token', return_value='test')
    @patch('catalog.management.commands.list_saby_delivery.requests.get')
    def test_reads_later_pages_without_syncing_catalog(self, get, token):
        pages = [
            {'nomenclatures': [{'name': 'Доставка', 'isParent': True, 'hierarchicalId': 10}],
             'outcome': {'hasMore': True}},
            {'nomenclatures': [{'name': 'Доставка Татыш 250', 'nomNumber': 'X2808804',
                               'id': 101, 'cost': 250, 'hierarchicalId': 11}],
             'outcome': {'hasMore': False}},
        ]
        params = []

        def respond(*args, **kwargs):
            params.append(dict(kwargs['params']))
            return Mock(json=Mock(return_value=pages[len(params) - 1]))

        get.side_effect = respond
        output = StringIO()
        call_command('list_saby_delivery', stdout=output)
        self.assertEqual(json.loads(output.getvalue())['nomNumber'], 'X2808804')
        self.assertEqual(params[0]['priceListId'], 4)
        self.assertNotIn('position', params[0])
        self.assertEqual(params[1]['position'], 10)

    @patch('catalog.services.saby_catalog_service.SabyCatalogService.get_token', return_value='test')
    @patch('catalog.management.commands.list_saby_delivery.requests.get')
    def test_repeating_cursor_reports_incomplete_result(self, get, token):
        get.return_value = Mock(json=Mock(return_value={
            'nomenclatures': [{'name': 'Доставка', 'isParent': True, 'hierarchicalId': 10}],
            'outcome': {'hasMore': True},
        }))
        with self.assertRaises(CommandError):
            call_command('list_saby_delivery', stdout=StringIO())
