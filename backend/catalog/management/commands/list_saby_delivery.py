import json

import requests
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from catalog.services.saby_catalog_service import SabyCatalogService


class Command(BaseCommand):
    help = 'Найти услуги доставки в Saby (только чтение, без синхронизации БД).'

    def add_arguments(self, parser):
        parser.add_argument('--all-catalog', action='store_true',
                            help='Искать во всём каталоге, а не в рабочем прайсе.')

    def handle(self, *args, **options):
        service = SabyCatalogService()
        try:
            token = service.get_token()
            params = {'pointId': settings.SABY_POINT_ID, 'pageSize': 25,
                      'searchString': 'Достав', 'order': 'after'}
            if not options['all_catalog']:
                params['priceListId'] = settings.SABY_PRICE_LIST_ID
            seen = set()
            found = 0
            for _ in range(100):
                response = requests.get(service.CATALOG_URL,
                    headers={'X-SBISAccessToken': token}, params=params, timeout=30)
                response.raise_for_status()
                data = response.json()
                if not isinstance(data, dict) or data.get('error'):
                    raise CommandError('Saby вернул ошибку или неожиданный формат каталога.')
                rows = data.get('nomenclatures')
                if not isinstance(rows, list):
                    raise CommandError('В ответе Saby отсутствует список nomenclatures.')
                for row in rows:
                    if not row.get('isParent') and 'достав' in str(row.get('name', '')).lower():
                        self.stdout.write(json.dumps({key: row.get(key) for key in (
                            'name', 'nomNumber', 'id', 'cost', 'published',
                        )}, ensure_ascii=False))
                        found += 1
                outcome = data.get('outcome')
                more = outcome.get('hasMore') if isinstance(outcome, dict) else outcome
                if not rows or more is False or (more is None and len(rows) < 25):
                    break
                cursor = rows[-1].get('hierarchicalId')
                if cursor is None or cursor in seen:
                    raise CommandError('Saby не продвинул курсор; список может быть неполным.')
                seen.add(cursor)
                params['position'] = cursor
            else:
                raise CommandError('Превышен лимит страниц; список может быть неполным.')
        except (requests.RequestException, ValueError) as exc:
            raise CommandError('Не удалось прочитать каталог Saby; проверьте доступ к API.') from exc
        if not found:
            self.stdout.write('Доставка не найдена. Проверьте публикацию в прайсе; '
                              'для поиска вне прайса используйте --all-catalog.')
