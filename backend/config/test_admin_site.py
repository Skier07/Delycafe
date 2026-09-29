from unittest.mock import patch

from django.contrib.admin import AdminSite
from django.test import SimpleTestCase

from config.admin_site import DelyCafeAdminSite, MENU_GROUPS


class AdminMenuTests(SimpleTestCase):
    def _apps(self):
        apps = {}
        for _, _, keys in MENU_GROUPS:
            for label, name in keys:
                app = apps.setdefault(label, {'app_label': label, 'name': label,
                                              'models': []})
                app['models'].append({'object_name': name, 'name': name,
                                     'admin_url': f'/admin/{label}/{name.lower()}/'})
        return list(apps.values())

    @patch('config.admin_site.reverse', return_value='/admin/')
    def test_group_order_and_model_order(self, reverse):
        with patch.object(AdminSite, 'get_app_list', return_value=self._apps()):
            groups = DelyCafeAdminSite().get_app_list(None)
        self.assertEqual([g['name'] for g in groups], [g[1] for g in MENU_GROUPS])
        for actual, (_, _, keys) in zip(groups, MENU_GROUPS):
            self.assertEqual([m['object_name'] for m in actual['models']],
                             [key[1] for key in keys])

    @patch('config.admin_site.reverse', return_value='/admin/')
    def test_does_not_restore_models_hidden_by_permissions(self, reverse):
        apps = [{'app_label': 'orders', 'models': [{'object_name': 'Order'}]}]
        with patch.object(AdminSite, 'get_app_list', return_value=apps) as original:
            groups = DelyCafeAdminSite().get_app_list('request', 'orders')
        original.assert_called_once_with('request', 'orders')
        self.assertEqual([g['name'] for g in groups], ['SETTINGS'])
        self.assertEqual(groups[0]['models'], [{'object_name': 'Order'}])

    @patch('config.admin_site.reverse', return_value='/admin/')
    def test_future_models_remain_accessible(self, reverse):
        apps = [{'app_label': 'new', 'name': 'New', 'models': [{'object_name': 'Extra'}]}]
        with patch.object(AdminSite, 'get_app_list', return_value=apps):
            self.assertEqual(DelyCafeAdminSite().get_app_list(None), apps)
