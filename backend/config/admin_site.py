from django.contrib.admin import AdminSite
from django.contrib.admin.apps import AdminConfig
from django.urls import reverse


MENU_GROUPS = (
    ('catalog', 'CATALOG', (
        ('catalog', 'Category'), ('catalog', 'Product'), ('catalog', 'NewSabyProduct'),
    )),
    ('content', 'CUSTOMERS', (
        ('catalog', 'ContentPost'), ('catalog', 'CatalogSnippet'),
        ('catalog', 'AppPageContent'), ('catalog', 'InfoSectionDefinition'),
        ('orders', 'DeliveryInfoSection'), ('catalog', 'FoodPhrase'),
    )),
    ('settings', 'SETTINGS', (
        ('customers', 'CustomerRefreshToken'), ('customers', 'BonusTransaction'),
        ('customers', 'Customer'), ('orders', 'OrderReturn'), ('orders', 'Order'),
        ('orders', 'DeliveryZone'), ('orders', 'OrderItem'),
    )),
    ('auth', 'ПОЛЬЗОВАТЕЛИ И ГРУППЫ', (
        ('auth', 'Group'), ('auth', 'User'),
    )),
)


class DelyCafeAdminSite(AdminSite):
    def get_app_list(self, request, app_label=None):
        # Let Django filter models by the current user's permissions first.
        apps = super().get_app_list(request, app_label)
        available = {
            (app['app_label'], model['object_name']): model
            for app in apps for model in app['models']
        }
        grouped = []
        for label, title, keys in MENU_GROUPS:
            models = [available.pop(key) for key in keys if key in available]
            if models:
                grouped.append({
                    'name': title, 'app_label': label,
                    'app_url': reverse('admin:index', current_app=self.name),
                    'has_module_perms': True, 'models': models,
                })
        # Future registered models must remain reachable without editing this menu.
        for app in apps:
            models = [m for m in app['models']
                      if (app['app_label'], m['object_name']) in available]
            if models:
                grouped.append({**app, 'models': models})
        return grouped


class DelyCafeAdminConfig(AdminConfig):
    default_site = 'config.admin_site.DelyCafeAdminSite'
