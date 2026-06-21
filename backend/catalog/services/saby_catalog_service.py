import requests

from django.conf import settings
from catalog.models import Category
from django.utils.text import slugify


class SabyCatalogService:
    TOKEN_URL = "https://online.sbis.ru/oauth/service/"
    CATALOG_URL = "https://api.sbis.ru/retail/v2/nomenclature/list"

    def get_token(self):
        response = requests.post(
            self.TOKEN_URL,
            json={
                "app_client_id": settings.SABY_APP_CLIENT_ID,
                "app_secret": settings.SABY_APP_SECRET,
                "secret_key": settings.SABY_SECRET_KEY,
            },
            timeout=30,
        )

        response.raise_for_status()

        data = response.json()

        return (
            data.get("access_token")
            or data.get("token")
            or data
        )

    def get_catalog(self):
        token = self.get_token()

        response = requests.get(
            self.CATALOG_URL,
            headers={
                "X-SBISAccessToken": token,
            },
            params={
                "pageSize": 1000,
            },
            timeout=60,
        )

        response.raise_for_status()

        return response.json()

    def get_or_create_category(
        self,
        category_id,
        category_name,
    ):
        category = Category.objects.filter(
            saby_category_id=category_id
        ).first()

        if category:
            return category

        category = Category.objects.filter(
            title=category_name
        ).first()

        if category:
            category.saby_category_id = category_id
            category.save(
                update_fields=[
                    'saby_category_id',
                ]
            )
            return category

        return Category.objects.create(
            title=category_name,
            slug=f'saby-category-{category_id}',
            saby_category_id=category_id,
            is_active=True,
        )

    def create_new_saby_product(
        self,
        category,
        saby_id,
        title,
    ):
        product, created = Product.objects.get_or_create(
            saby_id=saby_id,
            defaults={
                'category': category,
                'title': title,
                'saby_name': title,
                'source': Product.Source.SABY,
                'needs_review': True,
                'is_active': False,
                'price': 0,
            },
        )

        return product, created

    def sync_catalog(self):
        catalog = self.get_catalog()

        print('Тип каталога:', type(catalog))

        if not isinstance(catalog, dict):
            raise Exception(
                f'Ожидался dict, получен {type(catalog)}'
            )

        print(
            'Ключи ответа:',
            list(catalog.keys())
        )

        print(
            'Количество nomenclatures:',
            len(catalog.get('nomenclatures', []))
        )

        from pprint import pprint

        items = catalog.get('nomenclatures', [])

        for item in items:
            if not item.get('isParent'):
               print('\nПЕРВЫЙ НАСТОЯЩИЙ ТОВАР:')
               pprint(item)
               break

        return catalog
