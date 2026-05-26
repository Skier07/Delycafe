import json
import re
import html
from pathlib import Path


INPUT_FILE = Path("tools/saby_nomenclature_response.json")
OUTPUT_FILE = Path("lib/data/generated_catalog.dart")
REPORT_FILE = Path("tools/generated_catalog_report.json")
OVERRIDES_FILE = Path("tools/catalog_overrides.json")

DEFAULT_IMAGE = "assets/images/delycafe.jpg"

PIZZA_CATEGORY_NAME = "Пицца"

SAUCE_CATEGORY_NAME = "Соусы"
SAUCE_SOURCE_CATEGORY_NAMES = {"Соуса", "Соусы"}

SAUCE_PRODUCT_TITLES = {
    "соус сливочно чесночный": "Соус сливочно-чесночный",
    "соус сливочно-чесночный": "Соус сливочно-чесночный",
    "соус сырный": "Соус сырный",
    "соус кетчуп": "Кетчуп",
    "кетчуп": "Кетчуп",
    "соус барбекю": "Соус барбекю",
    "соус дьябло": "Соус диабло острый",
    "соус диабло": "Соус диабло острый",
    "соус сальса": "Соус Сальса средне-острый",
    "соус сальсо": "Соус Сальса средне-острый",
}

SAUCE_PRODUCT_ID_OVERRIDES = {
    594: {
        "title": "Соус сливочно-чесночный",
        "price": 40,
    },
    537: {
        "title": "Соус сырный",
        "price": 40,
    },
    177: {
        "title": "Кетчуп",
        "price": 40,
    },
    525: {
        "title": "Соус барбекю",
        "price": 40,
    },
    598: {
        "title": "Соус диабло острый",
        "price": 40,
    },
    535: {
        "title": "Соус Сальса средне-острый",
        "price": 50,
    },
}

SIZE_ORDER = {
    "Маленькая": 0,
    "Средняя": 1,
    "Большая": 2,
}

CATEGORY_RENAMES = {
    "Вода": "Напитки",
    "Кофе": "Напитки",

    "Чизкейк": "Десерты",
    "Картошечка": "Картошечка в фольге",

    "Фаст- Фуд": "Фастфуд",
    "Фаст-Фуд": "Фастфуд",
    "Фаст Фуд": "Фастфуд",
}

HIDDEN_CATEGORIES = {
    "Сырье",
    "Сырьё",
    "Доставка",

    # Скрываем технические/служебные разделы.
    # Нужные соусы вытаскиваем отдельно ДО этой проверки.
    "Добавки",
    "Питание",
    "Столовая",
}

HIDDEN_PRODUCT_IDS = {
    # Шаурма
    396,  # Шашлык 100г

    # Супы
    309,  # Окрошка

    # Блины
    41,  # Блинбургер

    # Салаты
    279,  # Салат Помидорка

    # Бургеры
    49,  # Бургер Студенческий

    # Напитки / лишние складские позиции
    140,  # Кофе черный
    141,  # Кофе черный с молоком
    143,  # Чай зеленый 200мл
    144,  # Чай зеленый с лимоном
    145,  # Чай с молоком
    146,  # Чай со сливками
    147,  # Чай черный 200мл
    148,  # Чай черный с лимоном
    150,  # Молочный коктейль
    882,  # Чай KURORTI 0.5

    949,  # Ягод сок. Морс вишневый
    950,  # Ягод сок. Морс клюквенный
    951,  # Ягод сок. Морс облепиховый
    952,  # Ягод сок. Морс черносмородиновый
    953,  # Niagara Premium газ.
    954,  # Niagara Premium негаз

    987,  # Берн гуава
    993,  # Бона Аква сильногазированная
    994,  # Бона Аква негаз
    995,  # Берн арбуз зеро
    996,  # Добрый лимон лайм
    998,  # Добрый яблочный сок
    999,  # Rich чай манго
    1000,  # Rich чай лимон
    1001,  # Берн оригинальный
    1009,  # BURN Манго
    1052,  # Добрый кола без сахара
    1069,  # Морсэль
    1070,  # SIMPATEA облепиха
    1072,  # Натахтари груша
    1073,  # Натахтари тархун
    1074,  # ZENO черный чай
    1085,  # Натахтари виноград 1л
    1098,  # Натахтари тархун стекло
    1099,  # Натахтари виноград стекло
    1100,  # ZENO зеленый чай

    # Фастфуд
    322,  # Булка хд
    324,  # Карт по дерев со спец 140г
    325,  # Карт по-дерев 100г
    328,  # Картофель Фри140г
    330,  # Луковые кольца
    332,  # Наггеттсы 135г

    # Десерты, которых нет на сайте
    381,  # Чизкейк Нью-Йорк
    383,  # Чизкейк лайм
    384,  # Чизкейк малина
    903,  # Чизкейк Кокос
    1071,  # Чизкейк Нью-Йорк суфле Фисташковый
}

PRODUCT_NAME_OVERRIDES = {
    867: "Запечённый картофель",

    # Пиццы: исправляем опечатки/разнобой в Saby, чтобы размеры склеились.
    # Если ID не совпадает с твоей выгрузкой, просто убери или поправь строку.
    222: "Дьявольская большая",
    267: "Цыпленок барбекью пицца большая",

    # Фастфуд
    331: "Наггетсы 100г",

    # Пицца на сайте называется так.
    250: "Пицца «Пепперони» большая",
    251: "Пицца «Пепперони» маленькая",
    252: "Пицца «Пепперони» средняя",

    # Пример на будущее:
    # 397: "Шаурма Сальса",
}

PRODUCT_DESCRIPTION_OVERRIDES = {
    # Пример:
    # 397: "Описание для товара.",
}

PRODUCT_PRICE_OVERRIDES = {
    138: 140,  # Капучино 200мл
}

PIZZA_BASE_TITLE_OVERRIDES = {
    "голодный мясник чили": "Голодный мясник ЧИЛИ",
    "дьявольская": "Дьявольская",
    "дьяволская": "Дьявольская",
    "пепперони классик": "Пицца «Пепперони»",
    "пепперони": "Пицца «Пепперони»",
    "пицца пепперони": "Пицца «Пепперони»",
    "цыпленок барбекью": "Цыпленок барбекью",
    "цыпленок барбекю": "Цыпленок барбекью",
    "цыплнок барбекью": "Цыпленок барбекью",
    "цыплнок барбекю": "Цыпленок барбекью",
}


def load_catalog_overrides():
    if not OVERRIDES_FILE.exists():
        return {}

    with open(OVERRIDES_FILE, "r", encoding="utf-8") as file:
        data = json.load(file)

    # В JSON ключи всегда строки, поэтому приводим всё к строковым id.
    return {str(key): value for key, value in data.items()}


CATALOG_OVERRIDES = load_catalog_overrides()


def get_catalog_override(product):
    product_id = product.get("id")

    if product_id is None:
        return {}

    return CATALOG_OVERRIDES.get(str(product_id), {})


def get_status(product):
    override = get_catalog_override(product)

    is_new = bool(
        override.get("isNew")
        or override.get("new")
    )

    is_hit = bool(
        override.get("isHit")
        or override.get("isHot")
        or override.get("hot")
    )

    return {
        "isNew": is_new,
        "isHit": is_hit,
    }


def dart_bool(value):
    return "true" if bool(value) else "false"


def dart_string(value):
    if value is None:
        value = ""

    value = str(value)
    value = value.replace("\\", "\\\\")
    value = value.replace("'", "\\'")
    value = value.replace("$", "\\$")
    value = value.replace("\r", "")
    value = value.replace("\n", "\\n")

    return f"'{value}'"


def clean_html(value):
    if not value:
        return ""

    value = html.unescape(value)
    value = re.sub(r"<[^>]+>", "", value)
    value = value.replace("\xa0", " ")
    value = re.sub(r"\s+", " ", value)

    return value.strip()


def normalize_category_name(name):
    name = (name or "Другое").strip()
    return CATEGORY_RENAMES.get(name, name)


def normalize_match_text(value):
    value = (value or "").strip().lower()
    value = value.replace("ё", "е")
    value = value.replace("«", "")
    value = value.replace("»", "")
    value = value.replace('"', "")
    value = value.replace("'", "")
    value = value.replace("-", " ")
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def get_sauce_title(product):
    name = normalize_match_text(product.get("name"))

    for raw_name, display_name in SAUCE_PRODUCT_TITLES.items():
        pattern = normalize_match_text(raw_name)

        if pattern in name:
            return display_name

    return None


def get_display_name(product):
    product_id = product.get("id")

    if product_id in PRODUCT_NAME_OVERRIDES:
        return PRODUCT_NAME_OVERRIDES[product_id]

    return (product.get("name") or "").strip()


def get_description(product):
    description = product.get("description_simple")
    if description:
        return clean_html(description)

    description = product.get("description")
    if description:
        return clean_html(description)

    return ""


def get_display_description(product):
    product_id = product.get("id")

    if product_id in PRODUCT_DESCRIPTION_OVERRIDES:
        return PRODUCT_DESCRIPTION_OVERRIDES[product_id]

    return get_description(product)


def get_price(product):
    product_id = product.get("id")

    if product_id in PRODUCT_PRICE_OVERRIDES:
        return PRODUCT_PRICE_OVERRIDES[product_id]

    cost = product.get("cost")

    if cost is None:
        return 0

    return int(round(float(cost)))


def get_weight(product):
    override = get_catalog_override(product)

    if override.get("weight"):
        return str(override["weight"])

    attributes = product.get("attributes") or {}
    weight = attributes.get("weight")

    if weight is None:
        return ""

    try:
        weight_float = float(weight)

        if weight_float <= 0:
            return ""

        if weight_float.is_integer():
            return f"{int(weight_float)} г"

        return f"{weight_float} г"
    except Exception:
        return str(weight)


def get_image(product):
    override = get_catalog_override(product)

    if override.get("image"):
        return str(override["image"])

    images = product.get("images")

    # Сейчас Flutter-каталог использует Image.asset.
    # Поэтому пока отдаём локальную картинку-заглушку.
    # Saby-картинки позже лучше тянуть через backend/proxy.
    if not images:
        return DEFAULT_IMAGE

    return DEFAULT_IMAGE


def get_sort_order(item):
    value = item.get("indexNumber")

    if value is None:
        return 999999999

    try:
        return int(value)
    except Exception:
        return 999999999


def find_pizza_category_id(categories):
    for category_id, category in categories.items():
        if category.get("name") == PIZZA_CATEGORY_NAME:
            return category_id

    return None


def get_pizza_size_categories(categories, pizza_category_id):
    result = {}

    if pizza_category_id is None:
        return result

    for category_id, category in categories.items():
        if category.get("hierarchicalParent") != pizza_category_id:
            continue

        name = (category.get("name") or "").strip().lower()

        if name in ("малая", "маленькая"):
            result[category_id] = "Маленькая"
        elif name == "средняя":
            result[category_id] = "Средняя"
        elif name == "большая":
            result[category_id] = "Большая"

    return result


def get_category_chain(categories, category_id):
    chain = []
    visited = set()
    current_id = category_id

    while current_id is not None and current_id not in visited:
        visited.add(current_id)

        category = categories.get(current_id)

        if category is None:
            break

        chain.append(category)

        current_id = category.get("hierarchicalParent")

    return chain


def is_in_category_tree(categories, category_id, category_name):
    chain = get_category_chain(categories, category_id)

    for category in chain:
        raw_name = (category.get("name") or "").strip()

        if raw_name == category_name:
            return True

    return False


def is_in_any_category_tree(categories, category_id, category_names):
    return any(
        is_in_category_tree(categories, category_id, category_name)
        for category_name in category_names
    )


def is_sauce_product(product, categories):
    product_id = product.get("id")

    if product_id is None:
        return False

    # Самый надёжный путь: соусы фиксируем по ID.
    if product_id in SAUCE_PRODUCT_ID_OVERRIDES:
        return True

    # Запасной вариант: если Saby начнёт отдавать соусы с нормальной ценой.
    if product.get("cost") is None:
        return False

    parent_id = product.get("hierarchicalParent")

    if not is_in_any_category_tree(
        categories,
        parent_id,
        SAUCE_SOURCE_CATEGORY_NAMES,
    ):
        return False

    return get_sauce_title(product) is not None


def get_sauce_catalog_item(product):
    product_id = product.get("id")
    override = SAUCE_PRODUCT_ID_OVERRIDES.get(product_id)

    if override is not None:
        title = override["title"]
        price = override["price"]
    else:
        title = get_sauce_title(product)
        price = get_price(product)

    if not title:
        return None

    description = get_display_description(product)
    status = get_status(product)

    return {
        "id": f"saby_{product_id}",
        "title": title,
        "category": SAUCE_CATEGORY_NAME,
        "price": price,
        "image": get_image(product),
        "description": description or f"{title} из меню DelyCafe.",
        "weight": get_weight(product),
        "variants": [],
        "sortOrder": get_sort_order(product),
        "isNew": status["isNew"],
        "isHit": status["isHit"],
    }


def is_hidden_category_tree(categories, category_id):
    chain = get_category_chain(categories, category_id)

    for category in chain:
        raw_name = (category.get("name") or "").strip()
        normalized_name = normalize_category_name(raw_name)

        if raw_name in HIDDEN_CATEGORIES or normalized_name in HIDDEN_CATEGORIES:
            return True

    return False


def get_root_category(categories, category_id):
    chain = get_category_chain(categories, category_id)

    if not chain:
        return None

    return chain[-1]


def get_display_category_name(categories, parent_id):
    root_category = get_root_category(categories, parent_id)

    if root_category is None:
        return "Другое"

    return normalize_category_name(root_category.get("name"))


def normalize_base_pizza_name(name):
    result = (name or "").strip()
    result = re.sub(r"\s+", " ", result)

    # Убираем размер в конце, включая варианты через дефис.
    result = re.sub(
        r"\s*[-–—]?\s*(большая|средняя|маленькая|малая)\s*$",
        "",
        result,
        flags=re.IGNORECASE,
    )

    # Убираем слово "пицца" в конце, если оно технически добавлено в названии.
    result = re.sub(
        r"\s+пицца\s*$",
        "",
        result,
        flags=re.IGNORECASE,
    )

    result = re.sub(r"\s+", " ", result).strip()

    normalized = normalize_match_text(result)
    return PIZZA_BASE_TITLE_OVERRIDES.get(normalized, result)


def should_include_product(product):
    product_id = product.get("id")

    if product_id is None:
        return False

    if product_id in HIDDEN_PRODUCT_IDS:
        return False

    if product_id in SAUCE_PRODUCT_ID_OVERRIDES:
        return True

    if product.get("cost") is None:
        return False

    if not get_display_name(product):
        return False

    return True


def build_catalog(data):
    nomenclatures = data.get("nomenclatures", [])

    categories = {}
    products_by_id = {}
    hidden_by_id_products = []

    for item in nomenclatures:
        if item.get("isParent") is True:
            categories[item.get("hierarchicalId")] = item
            continue

        product_id = item.get("id")

        if product_id in HIDDEN_PRODUCT_IDS:
            hidden_by_id_products.append(
                {
                    "id": product_id,
                    "name": item.get("name"),
                    "reason": "hidden product id",
                }
            )
            continue

        if should_include_product(item):
            # Защита от дублей Saby: один и тот же товар может прийти повторно.
            if product_id not in products_by_id:
                products_by_id[product_id] = item

    products = list(products_by_id.values())

    pizza_category_id = find_pizza_category_id(categories)
    pizza_size_categories = get_pizza_size_categories(
        categories,
        pizza_category_id,
    )

    catalog = []
    normal_items = []
    pizza_groups = {}
    skipped_hidden = 0
    skipped_hidden_products = []
    duplicate_pizza_variants = []

    for product in products:
        parent_id = product.get("hierarchicalParent")

        if is_sauce_product(product, categories):
            sauce_item = get_sauce_catalog_item(product)

            if sauce_item is not None:
                normal_items.append(sauce_item)

            continue

        if is_hidden_category_tree(categories, parent_id):
            skipped_hidden += 1
            skipped_hidden_products.append(
                {
                    "id": product.get("id"),
                    "name": product.get("name"),
                    "reason": "hidden category",
                }
            )
            continue

        if parent_id in pizza_size_categories:
            size_name = pizza_size_categories[parent_id]
            display_name = get_display_name(product)
            base_name = normalize_base_pizza_name(display_name)

            if not base_name:
                base_name = display_name

            group_key = normalize_match_text(base_name)

            if group_key not in pizza_groups:
                pizza_groups[group_key] = {
                    "title": base_name,
                    "category": PIZZA_CATEGORY_NAME,
                    "description": "",
                    "image": DEFAULT_IMAGE,
                    "variants": [],
                    "sortOrder": get_sort_order(product),
                    "isNew": False,
                    "isHit": False,
                }

            description = get_display_description(product)
            if description and not pizza_groups[group_key]["description"]:
                pizza_groups[group_key]["description"] = description

            image = get_image(product)
            if image != DEFAULT_IMAGE:
                pizza_groups[group_key]["image"] = image

            status = get_status(product)
            pizza_groups[group_key]["isNew"] = (
                pizza_groups[group_key]["isNew"] or status["isNew"]
            )
            pizza_groups[group_key]["isHit"] = (
                pizza_groups[group_key]["isHit"] or status["isHit"]
            )

            pizza_groups[group_key]["sortOrder"] = min(
                pizza_groups[group_key]["sortOrder"],
                get_sort_order(product),
            )

            new_variant = {
                "id": str(product.get("id")),
                "title": size_name,
                "price": get_price(product),
                "weight": get_weight(product),
                "sortOrder": get_sort_order(product),
                "sabyName": display_name,
            }

            existing_variant = next(
                (
                    variant
                    for variant in pizza_groups[group_key]["variants"]
                    if variant["title"] == size_name
                ),
                None,
            )

            if existing_variant is None:
                pizza_groups[group_key]["variants"].append(new_variant)
            else:
                duplicate_pizza_variants.append(
                    {
                        "pizza": base_name,
                        "size": size_name,
                        "keptId": existing_variant["id"],
                        "skippedId": new_variant["id"],
                        "skippedName": display_name,
                    }
                )

                if new_variant["sortOrder"] < existing_variant["sortOrder"]:
                    index = pizza_groups[group_key]["variants"].index(existing_variant)
                    pizza_groups[group_key]["variants"][index] = new_variant

            continue

        category_name = get_display_category_name(categories, parent_id)
        title = get_display_name(product)
        description = get_display_description(product)
        status = get_status(product)

        normal_items.append(
            {
                "id": f"saby_{product.get('id')}",
                "title": title,
                "category": category_name,
                "price": get_price(product),
                "image": get_image(product),
                "description": description or f"{title} из меню DelyCafe.",
                "weight": get_weight(product),
                "variants": [],
                "sortOrder": get_sort_order(product),
                "isNew": status["isNew"],
                "isHit": status["isHit"],
            }
        )

    for group in pizza_groups.values():
        variants = group["variants"]
        variants.sort(
            key=lambda variant: (
                SIZE_ORDER.get(variant["title"], 99),
                variant["sortOrder"],
            )
        )

        default_variant = None

        for variant in variants:
            if variant["title"] == "Средняя":
                default_variant = variant
                break

        if default_variant is None and variants:
            default_variant = variants[0]

        item_id = "saby_pizza_" + "_".join(
            variant["id"] for variant in variants
        )

        catalog.append(
            {
                "id": item_id,
                "title": group["title"],
                "category": PIZZA_CATEGORY_NAME,
                "price": default_variant["price"] if default_variant else 0,
                "image": group["image"],
                "description": group["description"] or f"Пицца {group['title']}.",
                "weight": default_variant["weight"] if default_variant else "",
                "variants": variants,
                "sortOrder": group["sortOrder"],
                "isNew": group["isNew"],
                "isHit": group["isHit"],
            }
        )

    catalog.extend(normal_items)

    catalog.sort(
        key=lambda item: (
            item["category"],
            item["sortOrder"],
            item["title"],
        )
    )

    report = {
        "totalNomenclatures": len(nomenclatures),
        "categoriesFound": len(categories),
        "productsFound": len(products),
        "catalogItemsGenerated": len(catalog),
        "newItemsGenerated": sum(1 for item in catalog if item.get("isNew")),
        "hotItemsGenerated": sum(1 for item in catalog if item.get("isHit")),
        "itemsWithWeight": sum(1 for item in catalog if item.get("weight")),
        "itemsWithCustomImage": sum(
            1
            for item in catalog
            if item.get("image") and item.get("image") != DEFAULT_IMAGE
        ),
        "overridesFile": str(OVERRIDES_FILE),
        "overridesLoaded": len(CATALOG_OVERRIDES),
        "pizzaItemsGenerated": sum(
            1 for item in catalog if item["category"] == PIZZA_CATEGORY_NAME
        ),
        "sauceItemsGenerated": sum(
            1 for item in catalog if item["category"] == SAUCE_CATEGORY_NAME
        ),
        "hiddenProductIdsCount": len(HIDDEN_PRODUCT_IDS),
        "hiddenByIdProductsFound": hidden_by_id_products,
        "skippedHiddenProductsList": skipped_hidden_products,
        "duplicatePizzaVariants": duplicate_pizza_variants,
        "sauceItems": [
            {
                "id": item["id"],
                "title": item["title"],
                "price": item["price"],
            }
            for item in catalog
            if item["category"] == SAUCE_CATEGORY_NAME
        ],
        "skippedHiddenProducts": skipped_hidden,
        "categoriesInGeneratedCatalog": sorted(
            list({item["category"] for item in catalog})
        ),
    }

    return catalog, report


def render_dart(catalog):
    lines = []

    lines.append("import 'package:delycafe/models/catalog_item.dart';")
    lines.append("")
    lines.append("// Файл сгенерирован автоматически из JSON Saby.")
    lines.append("// Не редактируй вручную.")
    lines.append("// Для обновления запусти: python tools/generate_flutter_catalog.py")
    lines.append("")
    lines.append("const List<CatalogItem> generatedCatalog = [")

    for item in catalog:
        lines.append("  CatalogItem(")
        lines.append(f"    id: {dart_string(item['id'])},")
        lines.append(f"    title: {dart_string(item['title'])},")
        lines.append(f"    category: {dart_string(item['category'])},")
        lines.append(f"    price: {item['price']},")
        lines.append(f"    image: {dart_string(item['image'])},")
        lines.append(f"    description: {dart_string(item['description'])},")

        if item.get("weight"):
            lines.append(f"    weight: {dart_string(item['weight'])},")

        if item.get("sortOrder") is not None:
            lines.append(f"    sortOrder: {item['sortOrder']},")

        if item.get("isHit"):
            lines.append("    isHit: true,")

        if item.get("isNew"):
            lines.append("    isNew: true,")

        variants = item.get("variants") or []

        if variants:
            lines.append("    variants: [")
            for variant in variants:
                lines.append("      ProductVariant(")
                lines.append(f"        id: {dart_string(variant['id'])},")
                lines.append(f"        title: {dart_string(variant['title'])},")
                lines.append(f"        price: {variant['price']},")
                lines.append(f"        weight: {dart_string(variant['weight'])},")
                lines.append("      ),")
            lines.append("    ],")

        lines.append("  ),")

    lines.append("];")
    lines.append("")

    return "\n".join(lines)


def save_report(report):
    REPORT_FILE.parent.mkdir(parents=True, exist_ok=True)

    with open(REPORT_FILE, "w", encoding="utf-8") as file:
        json.dump(report, file, ensure_ascii=False, indent=2)


def main():
    if not INPUT_FILE.exists():
        print(f"Не найден файл: {INPUT_FILE}")
        print("Сначала получи JSON из Saby и сохрани его как:")
        print(INPUT_FILE)
        return

    with open(INPUT_FILE, "r", encoding="utf-8") as file:
        data = json.load(file)

    catalog, report = build_catalog(data)

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    dart_code = render_dart(catalog)

    with open(OUTPUT_FILE, "w", encoding="utf-8") as file:
        file.write(dart_code)

    save_report(report)

    print("Готово.")
    print(f"Всего номенклатур из Saby: {report['totalNomenclatures']}")
    print(f"Товаров найдено: {report['productsFound']}")
    print(f"Товаров в generatedCatalog: {report['catalogItemsGenerated']}")
    print(f"New-товаров: {report['newItemsGenerated']}")
    print(f"Hot-товаров: {report['hotItemsGenerated']}")
    print(f"Товаров с весом: {report['itemsWithWeight']}")
    print(f"Товаров с кастомной картинкой: {report['itemsWithCustomImage']}")
    print(f"Override-записей загружено: {report['overridesLoaded']}")
    print(f"Пицц собрано с вариантами: {report['pizzaItemsGenerated']}")
    print(f"Соусов добавлено: {report['sauceItemsGenerated']}")
    print(f"Скрыто товаров из технических категорий: {report['skippedHiddenProducts']}")
    print(f"Скрыто товаров по ID: {len(report['hiddenByIdProductsFound'])}")
    print(f"Дублей вариантов пиццы пропущено: {len(report['duplicatePizzaVariants'])}")
    print(f"Файл каталога создан: {OUTPUT_FILE}")
    print(f"Отчёт создан: {REPORT_FILE}")


if __name__ == "__main__":
    main()
