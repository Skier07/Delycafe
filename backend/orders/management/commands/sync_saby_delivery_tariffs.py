import json

from django.core.management.base import BaseCommand, CommandError

from orders.saby_delivery_sync import DeliverySyncError, sync_delivery_tariffs
from orders.models import DeliveryInfoSection, DeliveryZone
from orders.delivery_text import TOKEN


class Command(BaseCommand):
    help = 'Получить тарифы районов Saby и обновить местные зоны доставки.'

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true', help='Показать изменения без записи.')

    def handle(self, *args, **options):
        try:
            result = sync_delivery_tariffs(dry_run=options['dry_run'])
        except DeliverySyncError as error:
            raise CommandError(str(error)) from error
        self.stdout.write(json.dumps(result, ensure_ascii=False, indent=2))
        for zone in DeliveryZone.objects.filter(code__in=[row['zone'] for row in result]):
            if f'{{{{delivery_tariff:{zone.code}}}}}' not in zone.checkout_description:
                self.stderr.write(self.style.WARNING(
                    f'Зона «{zone.title}»: собственное описание сохранено. '
                    f'Замените в нём строку стоимости на {{{{delivery_tariff:{zone.code}}}}}.'
                ))
        for section in DeliveryInfoSection.objects.filter(is_active=True):
            if not TOKEN.search(section.content) and any(word in section.title.lower() for word in ('озёр', 'озер', 'татыш', 'промплощад')):
                self.stderr.write(self.style.WARNING(
                    f'Блок «{section.title}» (ID {section.pk}): проверьте текст стоимости; '
                    'для автоматических цен используйте метку delivery_tariff из подсказки поля.'
                ))
