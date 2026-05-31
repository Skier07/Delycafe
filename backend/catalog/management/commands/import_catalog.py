import re
import shutil
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand

from catalog.models import Category, Product, ProductVariant


CATEGORY_ORDER = {
    'Пицца': 10,
    'Шаурма': 20,
    'Бургеры': 30,
    'Фастфуд': 40,
    'Картошечка в фольге': 50,
    'Соусы': 60,
    'Напитки': 70,
    'Десерты': 80,
    'Блины': 90,
    'Паста': 100,
    'Пироги': 110,
    'Салаты': 120,
    'Супы': 130,
}


TRANSLIT = {
    'а': 'a',
    'б': 'b',
    'в': 'v',
    'г': 'g',
    'д': 'd',
    'е': 'e',
    'ё': 'e',
    'ж': 'zh',
    'з': 'z',
    'и': 'i',
    'й': 'y',
    'к': 'k',
    'л': 'l',
    'м': 'm',
    'н': 'n',
    'о': 'o',
    'п': 'p',
    'р': 'r',
    'с': 's',
    'т': 't',
    'у': 'u',
    'ф': 'f',
    'х': 'h',
    'ц': 'c',
    'ч': 'ch',
    'ш': 'sh',
    'щ': 'sch',
    'ъ': '',
    'ы': 'y',
    'ь': '',
    'э': 'e',
    'ю': 'yu',
    'я': 'ya',
}


def slugify(value):
    value = (value or '').lower().replace('ё', 'е')
    value = ''.join(TRANSLIT.get(char, char) for char in value)
    value = re.sub(r'[^a-z0-9]+', '-', value)
    value = re.sub(r'-+', '-', value)
    return value.strip('-') or 'item'


def extract_dart_string(block, field):
    pattern = rf"{field}:\s*'((?:\\'|\\\\|[^'])*)'"
    match = re.search(pattern, block)

    if not match:
        return ''

    value = match.group(1)
    value = value.replace("\\n", "\n")
    value = value.replace("\\'", "'")
    value = value.replace("\\$", "$")
    value = value.replace("\\\\", "\\")

    return value


def extract_dart_int(block, field, default=0):
    pattern = rf"{field}:\s*(\d+)"
    match = re.search(pattern, block)

    if not match:
        return default

    return int(match.group(1))


def extract_dart_bool(block, field, default=False):
    pattern = rf"{field}:\s*(true|false)"
    match = re.search(pattern, block)

    if not match:
        return default

    return match.group(1) == 'true'


def split_catalog_item_blocks(text):
    lines = text.splitlines()
    blocks = []
    current_block = []
    in_block = False

    for line in lines:
        if line.startswith('  CatalogItem('):
            in_block = True
            current_block = [line]
            continue

        if in_block:
            current_block.append(line)

            # У ProductVariant закрытие с большим отступом: "      ),"
            # У CatalogItem закрытие с двумя пробелами: "  ),"
            if line == '  ),':
                blocks.append('\n'.join(current_block))
                in_block = False

    return blocks


def parse_variants(block):
    variants = []

    variant_blocks = re.findall(
        r'ProductVariant\(([\s\S]*?)\n      \),',
        block,
    )

    for variant_block in variant_blocks:
        variant_id = extract_dart_string(variant_block, 'id')
        title = extract_dart_string(variant_block, 'title')
        price = extract_dart_int(variant_block, 'price')
        weight = extract_dart_string(variant_block, 'weight')

        if not title:
            continue

        variants.append(
            {
                'saby_id': int(variant_id) if variant_id.isdigit() else None,
                'title': title,
                'price': price,
                'weight': weight,
            }
        )

    return variants


def parse_catalog_item(block):
    item_id = extract_dart_string(block, 'id')
    title = extract_dart_string(block, 'title')
    category = extract_dart_string(block, 'category')
    image = extract_dart_string(block, 'image')
    description = extract_dart_string(block, 'description')
    weight = extract_dart_string(block, 'weight')
    price = extract_dart_int(block, 'price')
    sort_order = extract_dart_int(block, 'sortOrder', default=500)
    is_new = extract_dart_bool(block, 'isNew')
    is_hit = extract_dart_bool(block, 'isHit')
    variants = parse_variants(block)

    if not item_id or not title or not category:
        return None

    saby_id = None

    if item_id.startswith('saby_') and not item_id.startswith('saby_pizza_'):
        raw_id = item_id.replace('saby_', '', 1)

        if raw_id.isdigit():
            saby_id = int(raw_id)

    return {
        'item_id': item_id,
        'saby_id': saby_id,
        'title': title,
        'category': category,
        'image': image,
        'description': description,
        'weight': weight,
        'price': price,
        'sort_order': sort_order,
        'is_new': is_new,
        'is_hit': is_hit,
        'has_variants': len(variants) > 0,
        'variants': variants,
    }


def parse_generated_catalog(catalog_file):
    if not catalog_file.exists():
        raise FileNotFoundError(f'Не найден файл: {catalog_file}')

    text = catalog_file.read_text(encoding='utf-8')
    blocks = split_catalog_item_blocks(text)

    items = []

    for block in blocks:
        item = parse_catalog_item(block)

        if item is not None:
            items.append(item)

    return items


def copy_image_to_media(project_root, image_path, category_slug):
    if not image_path:
        return ''

    source_path = project_root / image_path

    if not source_path.exists():
        return ''

    file_name = source_path.name
    relative_media_path = Path('products') / category_slug / file_name
    destination_path = Path(settings.MEDIA_ROOT) / relative_media_path

    destination_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_path, destination_path)

    return relative_media_path.as_posix()


class Command(BaseCommand):
    help = 'Импортирует текущий Flutter-каталог generated_catalog.dart в Django backend.'

    def handle(self, *args, **options):
        backend_root = Path(settings.BASE_DIR)
        project_root = backend_root.parent

        catalog_file = project_root / 'lib' / 'data' / 'generated_catalog.dart'

        self.stdout.write('Читаю generated_catalog.dart...')
        catalog_items = parse_generated_catalog(catalog_file)

        self.stdout.write(f'Найдено товаров в Flutter-каталоге: {len(catalog_items)}')

        categories_cache = {}
        products_created = 0
        products_updated = 0
        variants_created = 0
        variants_updated = 0
        images_copied = 0
        images_missing = 0

        for item in catalog_items:
            category_title = item['category']
            category_slug = slugify(category_title)

            if category_title not in categories_cache:
                category, _ = Category.objects.update_or_create(
                    slug=category_slug,
                    defaults={
                        'title': category_title,
                        'sort_order': CATEGORY_ORDER.get(category_title, 500),
                        'is_active': True,
                    },
                )

                categories_cache[category_title] = category

            category = categories_cache[category_title]

            image_name = copy_image_to_media(
                project_root=project_root,
                image_path=item['image'],
                category_slug=category_slug,
            )

            if image_name:
                images_copied += 1
            else:
                images_missing += 1

            product_defaults = {
                'category': category,
                'title': item['title'],
                'description': item['description'],
                'price': item['price'],
                'weight': item['weight'],
                'is_new': item['is_new'],
                'is_hit': item['is_hit'],
                'is_active': True,
                'has_variants': item['has_variants'],
                'sort_order': item['sort_order'],
            }

            if image_name:
                product_defaults['image'] = image_name

            if item['saby_id'] is not None:
                product, created = Product.objects.update_or_create(
                    saby_id=item['saby_id'],
                    defaults=product_defaults,
                )
            else:
                product, created = Product.objects.update_or_create(
                    category=category,
                    title=item['title'],
                    defaults=product_defaults,
                )

            if created:
                products_created += 1
            else:
                products_updated += 1

            active_variant_ids = []

            for index, variant_data in enumerate(item['variants']):
                variant_defaults = {
                    'product': product,
                    'title': variant_data['title'],
                    'price': variant_data['price'],
                    'weight': variant_data['weight'],
                    'sort_order': (index + 1) * 10,
                    'is_active': True,
                }

                variant_saby_id = variant_data['saby_id']

                if variant_saby_id is not None:
                    variant, variant_created = ProductVariant.objects.update_or_create(
                        saby_id=variant_saby_id,
                        defaults=variant_defaults,
                    )
                else:
                    variant, variant_created = ProductVariant.objects.update_or_create(
                        product=product,
                        title=variant_data['title'],
                        defaults=variant_defaults,
                    )

                active_variant_ids.append(variant.id)

                if variant_created:
                    variants_created += 1
                else:
                    variants_updated += 1

            if item['has_variants']:
                product.variants.exclude(id__in=active_variant_ids).update(
                    is_active=False,
                )

        self.stdout.write(self.style.SUCCESS('Импорт завершён.'))
        self.stdout.write(f'Создано товаров: {products_created}')
        self.stdout.write(f'Обновлено товаров: {products_updated}')
        self.stdout.write(f'Создано вариантов: {variants_created}')
        self.stdout.write(f'Обновлено вариантов: {variants_updated}')
        self.stdout.write(f'Картинок скопировано в media: {images_copied}')
        self.stdout.write(f'Картинок не найдено: {images_missing}')