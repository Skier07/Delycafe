"""Point catalog originals at existing gallery files; never move/delete media."""
import hashlib
import json
from datetime import datetime
from pathlib import Path, PurePosixPath

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from PIL import Image

from catalog.image_variants import refresh_image_variants
from catalog.models import Product, ProductGalleryImage


class Command(BaseCommand):
    help = 'Проверить пути фотографий; --apply переводит их в products/gallery/.'

    def add_arguments(self, parser):
        parser.add_argument('--apply', action='store_true')

    def handle(self, *args, **options):
        root = Path(settings.MEDIA_ROOT).resolve()
        models = (Product, ProductGalleryImage)
        plan, errors, snapshot = [], [], {}

        def local(name):
            path = (root / name).resolve()
            if not path.is_relative_to(root):
                raise ValueError('Путь за пределами media')
            return path

        def digest(path):
            with path.open('rb') as stream:
                return hashlib.file_digest(stream, 'sha256').hexdigest()

        for model in models:
            rows = list(model.objects.values('id', 'image', 'image_variants'))
            snapshot[model.__name__] = rows
            for row in rows:
                old = row['image']
                if not old:
                    continue
                new = 'products/gallery/' + PurePosixPath(old).name
                try:
                    target = local(new)
                    if not target.is_file():
                        raise ValueError(f'Нет файла {new}')
                    with Image.open(target) as image:
                        image.verify()
                    source = local(old)
                    if old != new and source.is_file() and digest(source) != digest(target):
                        raise ValueError(f'Разное содержимое: {old} и {new}')
                    if old != new:
                        plan.append((model, row, new))
                        self.stdout.write(f'{model.__name__} #{row["id"]}: {old} -> {new}')
                except (OSError, ValueError) as exc:
                    errors.append(f'{model.__name__} #{row["id"]}: {exc}')

        for error in errors:
            self.stderr.write(error)
        self.stdout.write(f'К замене: {len(plan)}. Проблемных записей: {len(errors)}.')
        if not options['apply']:
            self.stdout.write('Только проверка. Для применения добавьте --apply.')
            return

        backup_dir = Path(settings.BASE_DIR) / 'backups'
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup = backup_dir / f'gallery-paths-{datetime.now():%Y%m%d-%H%M%S-%f}.json'
        with backup.open('x', encoding='utf-8') as stream:
            json.dump(snapshot, stream, ensure_ascii=False, indent=2)
        self.stdout.write(f'Резервная копия: {backup}')

        with transaction.atomic():
            for model, row, new in plan:
                updated = model.objects.filter(pk=row['id'], image=row['image']).update(
                    image=new, image_variants=[],
                )
                if updated != 1:
                    raise CommandError('Параллельное изменение фотографии: замена путей отменена.')

        # Regenerate metadata after changing paths and missing cached files.
        for model in models:
            for obj in model.objects.exclude(image='').exclude(image__isnull=True).iterator():
                if not obj.image.name.startswith('products/gallery/'):
                    continue
                try:
                    if not local(obj.image.name).is_file():
                        continue
                    variants = obj.image_variants or []
                    if variants and all(local(v['name']).is_file() for v in variants):
                        continue
                    refresh_image_variants(obj)
                    self.stdout.write(f'WEBP: {model.__name__} #{obj.pk}')
                except Exception as exc:
                    errors.append(f'{model.__name__} #{obj.pk}: {exc}')
                    self.stderr.write(errors[-1])

        remaining = sum(model.objects.exclude(image='').exclude(image__isnull=True)
                        .exclude(image__startswith='products/gallery/').count()
                        for model in models)
        self.stdout.write(f'Заменено: {len(plan)}. Ссылок вне gallery: {remaining}.')
        if errors or remaining:
            raise CommandError('Есть нерешённые записи. Старые папки пока не удалять.')
        self.stdout.write('Все оригиналы товаров и галереи проверены в products/gallery/. '
                          'Папку products/renditions обязательно сохранить. '
                          'Старые прямые URL и другие ссылки в текстах не проверялись.')
