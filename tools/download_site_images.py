import json
import re
import time
from difflib import SequenceMatcher
from pathlib import Path
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup


BASE_URL = "https://pizzaozersk.ru"

GENERATED_CATALOG_FILE = Path("lib/data/generated_catalog.dart")
OVERRIDES_FILE = Path("tools/catalog_overrides.json")
REPORT_FILE = Path("tools/site_images_report.json")

REQUEST_TIMEOUT = 25
SLEEP_SECONDS = 0.25

CATEGORY_PAGES = [
    {"category": "Пицца", "url": "https://pizzaozersk.ru/pizza/", "folder": "pizza"},
    {"category": "Шаурма", "url": "https://pizzaozersk.ru/shaurma/", "folder": "shaurma"},
    {"category": "Пироги", "url": "https://pizzaozersk.ru/pirogi/", "folder": "pies"},
    {"category": "Картошечка в фольге", "url": "https://pizzaozersk.ru/kartoshechka-v-folg/", "folder": "potato"},
    {"category": "Супы", "url": "https://pizzaozersk.ru/sup/", "folder": "soups"},
    {"category": "Блины", "url": "https://pizzaozersk.ru/bliny/", "folder": "pancakes"},
    {"category": "Салаты", "url": "https://pizzaozersk.ru/salatyi/", "folder": "salads"},
    {"category": "Напитки", "url": "https://pizzaozersk.ru/napitki/", "folder": "drinks"},
    {"category": "Соусы", "url": "https://pizzaozersk.ru/sousyi/", "folder": "sauces"},
    {"category": "Бургеры", "url": "https://pizzaozersk.ru/burgeryi/", "folder": "burger"},
    {"category": "Фастфуд", "url": "https://pizzaozersk.ru/hotdog/", "folder": "fastfood"},
    {"category": "Десерты", "url": "https://pizzaozersk.ru/desert/", "folder": "desserts"},
    {"category": "Паста", "url": "https://pizzaozersk.ru/pasta/", "folder": "pasta"},
]

# Тексты, которые сайт отдаёт рядом с карточками, но это не товары.
JUNK_NORMALIZED_TITLES = {
    "меню",
    "нет фото",
    "отвечаем за качество",
    "свежие продукты",
    "все натуральное без химии",
    "жарим на углях",
}

JUNK_TITLE_PARTS = {
    "logo деликафе",
    "доставка пиццы роллов и бургеров",
}

# Ручные соответствия: сайт -> каталог.
# Ключ и значение пишем обычным текстом, скрипт сам нормализует.
MANUAL_SITE_TO_CATALOG_ALIASES = {
    ("Пицца", "Пицца «Цыплёнок барбекю»"): "Цыпленок барбекью",
    ("Пицца", "Пицца «Барбекю»"): "Барбекью",

    ("Шаурма", "Шаурма Кесадилья"): "Кесадилья",
    ("Шаурма", "Шаурма Шашлычная XXL"): "Шаурма шашл XXL",
    ("Шаурма", "Шаурма Шашлычная"): "Шаурма шашлык",
    ("Шаурма", "Шаурма Сальса"): "Шурма Сальса",
    ("Шаурма", "Шаурма Классическая"): "Шаурма\"Классическая\"",
    ("Шаурма", "Шаурма Гирос"): "Гирос",
    ("Шаурма", "Шаурма Барбекю"): "Шаурма Барбекью",

    ("Пироги", "Пирог с картошкой и курицей"): "Пирог курица + картошка",
    ("Пироги", "Пирог с картошкой и грибами"): "Пирог картошкой и грибами",
    ("Пироги", "Пиром с мясом и картошкой"): "Пирог мясо+картошка",

    ("Супы", "Суп Брокколи"): "Крем суп из брокколи",
    ("Супы", "Грибной суп-крем"): "Грибной крем суп",
    ("Супы", "Суп Солянка"): "Солянка",
    ("Супы", "Суп Уха"): "Уха",
    ("Супы", "Крем-суп Сырный"): "Сырный суп",
    ("Супы", "Суп куриный"): "Куриный",
    ("Супы", "Суп Борщ"): "Борщ",

    ("Блины", "Блин с грибами и сыром"): "Блин грибы+сыр",
    ("Блины", "Блин с грибами, яйцом и зеленью"): "Блин грибы+яйцо+зелень",
    ("Блины", "Блин с грибами, ветчиной и сыром"): "Блин с грибами+ветчина+сыр",
    ("Блины", "Блинчик Цезарь"): "Блин Цезарь",
    ("Блины", "Блинчик со сгущёнкой"): "Блин со сгущенкой",
    ("Блины", "Блин-дог двойной"): "Блин-Дог 2",
    ("Блины", "Блинчик с джемом"): "Блины с джемом",

    ("Салаты", "Салат Цезарь"): "Цезарь",
    ("Салаты", "Салат Нежность"): "Нежность",
    ("Салаты", "Салат Пикантный"): "Пикантный",
    ("Салаты", "Салат Моника"): "Моника",
    ("Салаты", "Салат Верона"): "Верона",

    ("Напитки", "Кофе Американо"): "Американо 200мл",
    ("Напитки", "Кофе Эспрессо"): "Эспрессо 70мл",
    ("Напитки", "Кофе капучино"): "Капучино 200мл",
    ("Напитки", "Кофе Латтэ"): "Латте 200мл",

    ("Бургеры", "Бургер «Классический»"): "Бургер классик",

    ("Фастфуд", "Френч-дог с охотничьей колбаской"): "Френч дог Охота",
    ("Фастфуд", "Сырные шарики"): "Сырные шарики 100г",
    ("Фастфуд", "Куриное филе в хлопьях"): "Курица Хлопья 100г",
    ("Фастфуд", "Наггетсы 100 г"): "Наггетсы 100г",
    ("Фастфуд", "Картошка Фри"): "Картофель Фри 100г",

    ("Десерты", "Чизкейк «Карамельный с арахисом»"): "Чизкейк Карамельный арахис",

    ("Паста", "Паста «С курицей и грибами»"): "Паста курица грибы",
    ("Паста", "Паста «Карбонара»"): "Паста  с беконом",
}


def normalize_text(value: str) -> str:
    value = value or ""
    value = value.lower().replace("ё", "е")

    replacements = {
        "барбекью": "барбекю",
        "латтэ": "латте",
        "шурма": "шаурма",
        "наггеттсы": "наггетсы",
        "пиром": "пирог",
        "френч-дог": "френч дог",
        "крем-суп": "крем суп",
        "суп-крем": "суп крем",
        "запеченный": "запеченый",
        "запечённый": "запеченый",
    }

    for old, new in replacements.items():
        value = value.replace(old, new)

    value = value.replace("«", "").replace("»", "")
    value = value.replace('"', "").replace("'", "")
    value = re.sub(r"\bмаленькая\b|\bмалая\b|\bсредняя\b|\bбольшая\b", " ", value)
    value = re.sub(r"\b\d+\s*(г|гр|мл|л)\b", " ", value)
    value = re.sub(r"[^a-zа-я0-9]+", " ", value, flags=re.IGNORECASE)
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def normalize_for_category(value: str, category: str) -> str:
    value = normalize_text(value)

    remove_by_category = {
        "Пицца": {"пицца"},
        "Шаурма": {"шаурма"},
        "Супы": {"суп", "крем", "из"},
        "Салаты": {"салат"},
        "Напитки": {"кофе"},
    }

    stop_words = {"с", "со", "и", "в", "из", "на", "по"}
    words_to_remove = stop_words | remove_by_category.get(category, set())

    tokens = [
        token
        for token in value.split()
        if token and token not in words_to_remove
    ]

    return " ".join(tokens).strip()


def token_sort_key(value: str) -> str:
    tokens = value.split()
    return " ".join(sorted(tokens))


def get_match_keys(category: str, title: str) -> set[str]:
    base = normalize_text(title)
    canonical = normalize_for_category(title, category)

    keys = {base, canonical}

    if canonical:
        keys.add(token_sort_key(canonical))

    # Начинка 1 на сайте должна подходить к "Начинка 1 Ветчина+сыр" в каталоге.
    filling_match = re.match(r"^(начинка\s+\d+)\b", canonical)
    if filling_match:
        keys.add(filling_match.group(1))

    return {key for key in keys if key}


def is_junk_title(title: str) -> bool:
    normalized = normalize_text(title)

    if normalized in JUNK_NORMALIZED_TITLES:
        return True

    return any(part in normalized for part in JUNK_TITLE_PARTS)


def slugify(value: str) -> str:
    translit = {
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "е": "e", "ё": "e",
        "ж": "zh", "з": "z", "и": "i", "й": "y", "к": "k", "л": "l", "м": "m",
        "н": "n", "о": "o", "п": "p", "р": "r", "с": "s", "т": "t", "у": "u",
        "ф": "f", "х": "h", "ц": "c", "ч": "ch", "ш": "sh", "щ": "sch",
        "ъ": "", "ы": "y", "ь": "", "э": "e", "ю": "yu", "я": "ya",
    }
    value = (value or "").lower().replace("ё", "е")
    value = "".join(translit.get(char, char) for char in value)
    value = re.sub(r"[^a-z0-9]+", "_", value)
    value = re.sub(r"_+", "_", value)
    return value.strip("_") or "image"


def first_attr(tag, attrs):
    for attr in attrs:
        value = tag.get(attr)
        if value:
            return value
    return ""


def image_url_from_tag(img):
    value = first_attr(
        img,
        [
            "data-src",
            "data-original",
            "data-lazy",
            "data-lazy-src",
            "data-srcset",
            "src",
        ],
    )

    if value and "," in value and " " in value:
        value = value.split(",")[0].strip().split(" ")[0]

    if not value:
        srcset = img.get("srcset") or img.get("data-srcset")
        if srcset:
            value = srcset.split(",")[0].strip().split(" ")[0]

    if not value or value.startswith("data:"):
        return ""

    return urljoin(BASE_URL, value)


def clean_product_title(value: str) -> str:
    value = value or ""
    value = value.replace("Image:", "")
    value = re.sub(r"\s+", " ", value)
    return value.strip()


def get_card_text_lines(card):
    text = card.get_text("\n", strip=True)
    lines = []

    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue

        if line in {"В корзину", "- +", "-", "+", "add_shopping_cart"}:
            continue

        lines.append(line)

    return lines


def find_product_card(img):
    current = img

    for _ in range(9):
        current = current.parent

        if current is None:
            return None

        text = current.get_text(" ", strip=True).lower()

        if "в корзину" in text and ("руб" in text or "₽" in text):
            return current

    return None


def extract_title_from_lines(lines):
    for line in lines:
        if line in {"New", "ХИТ", "New ХИТ", "ХИТ New"}:
            continue
        if "руб" in line or "₽" in line:
            continue
        if is_junk_title(line):
            continue
        return clean_product_title(line)

    return ""


def extract_product_from_card(card, img, category, folder):
    image_url = image_url_from_tag(img)

    if not image_url:
        return None

    raw_title = img.get("alt") or img.get("title") or ""
    title = clean_product_title(raw_title)
    lines = get_card_text_lines(card)

    if not title or is_junk_title(title):
        title = extract_title_from_lines(lines)

    if not title or is_junk_title(title):
        return None

    category_names = {item["category"] for item in CATEGORY_PAGES}

    if title in category_names:
        return None

    full_text = "\n".join(lines)
    is_new = bool(re.search(r"\bNew\b", full_text, flags=re.IGNORECASE))
    is_hit = "ХИТ" in full_text or "HOT" in full_text.upper()

    weight = ""
    weight_match = re.search(r"Вес:\s*([^\n]+)", full_text, flags=re.IGNORECASE)
    if weight_match:
        weight = weight_match.group(1).strip()

    description = ""

    try:
        title_index = next(
            i for i, line in enumerate(lines)
            if normalize_text(line) == normalize_text(title)
        )

        for line in lines[title_index + 1:]:
            if "ms2_product_size" in line:
                break
            if "руб" in line or "₽" in line:
                break
            if line.startswith("Вес:"):
                break
            if line in {"New", "ХИТ", "New ХИТ", "ХИТ New"}:
                continue
            if is_junk_title(line):
                continue

            description = line.strip()
            break
    except StopIteration:
        pass

    return {
        "category": category,
        "folder": folder,
        "title": title,
        "normalizedTitle": normalize_text(title),
        "matchKeys": sorted(get_match_keys(category, title)),
        "description": description,
        "weight": weight,
        "isNew": is_new,
        "isHit": is_hit,
        "imageUrl": image_url,
    }


def fetch_html(session, url):
    response = session.get(url, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()
    return response.text


def find_category_page_urls(session, start_url):
    html = fetch_html(session, start_url)
    soup = BeautifulSoup(html, "html.parser")
    urls = {start_url}
    start_path = urlparse(start_url).path.rstrip("/")

    for a in soup.find_all("a", href=True):
        href = urljoin(start_url, a["href"])
        parsed = urlparse(href)
        path = parsed.path.rstrip("/")

        if parsed.netloc != urlparse(BASE_URL).netloc:
            continue

        if path == start_path or path.startswith(start_path + "/"):
            if not href.endswith(".html"):
                urls.add(href)

    return sorted(urls)


def make_session():
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 Chrome/120 Safari/537.36"
            )
        }
    )
    return session


def scrape_site_products():
    session = make_session()
    products_by_key = {}

    for category_info in CATEGORY_PAGES:
        category = category_info["category"]
        folder = category_info["folder"]
        start_url = category_info["url"]

        try:
            page_urls = find_category_page_urls(session, start_url)
        except Exception as error:
            print(f"[WARN] Не смог открыть категорию {category}: {error}")
            continue

        for page_url in page_urls:
            try:
                html = fetch_html(session, page_url)
                soup = BeautifulSoup(html, "html.parser")
            except Exception as error:
                print(f"[WARN] Не смог открыть страницу {page_url}: {error}")
                continue

            for img in soup.find_all("img"):
                card = find_product_card(img)

                if card is None:
                    continue

                product = extract_product_from_card(card, img, category, folder)

                if product is None:
                    continue

                key = (category, product["normalizedTitle"])

                if key not in products_by_key:
                    products_by_key[key] = product

            time.sleep(SLEEP_SECONDS)

    return list(products_by_key.values())


def extract_dart_string(block, field):
    pattern = rf"{field}:\s*'((?:\\'|[^'])*)'"
    match = re.search(pattern, block)

    if not match:
        return ""

    return match.group(1).replace("\\'", "'").replace("\\\\", "\\")


def parse_catalog_block(block):
    title = extract_dart_string(block, "title")
    category = extract_dart_string(block, "category")
    item_id = extract_dart_string(block, "id")

    if not title or not category or not item_id:
        return None

    ids = []

    if item_id.startswith("saby_") and not item_id.startswith("saby_pizza_"):
        raw_id = item_id.replace("saby_", "", 1)

        if raw_id.isdigit():
            ids.append(raw_id)

    for match in re.finditer(r"ProductVariant\([\s\S]*?id:\s*'([^']+)'", block):
        variant_id = match.group(1)

        if variant_id.isdigit():
            ids.append(variant_id)

    if item_id.startswith("saby_pizza_"):
        for part in item_id.replace("saby_pizza_", "").split("_"):
            if part.isdigit():
                ids.append(part)

    ids = sorted(set(ids), key=lambda x: int(x))

    return {
        "id": item_id,
        "ids": ids,
        "title": title,
        "category": category,
        "normalizedTitle": normalize_text(title),
        "matchKeys": sorted(get_match_keys(category, title)),
    }


def parse_generated_catalog():
    if not GENERATED_CATALOG_FILE.exists():
        raise FileNotFoundError(f"Не найден файл {GENERATED_CATALOG_FILE}")

    lines = GENERATED_CATALOG_FILE.read_text(encoding="utf-8").splitlines()
    items = []
    block = []
    in_block = False

    for line in lines:
        if line.startswith("  CatalogItem("):
            in_block = True
            block = [line]
            continue

        if in_block:
            block.append(line)

            if line == "  ),":
                parsed = parse_catalog_block("\n".join(block))

                if parsed is not None:
                    items.append(parsed)

                in_block = False

    return items


def choose_extension(image_url, content_type):
    suffix = Path(urlparse(image_url).path).suffix.lower()

    if suffix in {".jpg", ".jpeg", ".png", ".webp"}:
        return suffix

    if "png" in content_type:
        return ".png"

    if "webp" in content_type:
        return ".webp"

    return ".jpg"


def download_image(session, image_url, output_base_path):
    response = session.get(image_url, timeout=REQUEST_TIMEOUT)
    response.raise_for_status()

    content_type = response.headers.get("content-type", "")
    extension = choose_extension(image_url, content_type)
    output_path = output_base_path.with_suffix(extension)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(response.content)

    return output_path.as_posix()


def load_existing_overrides():
    if not OVERRIDES_FILE.exists():
        return {}

    with open(OVERRIDES_FILE, "r", encoding="utf-8") as file:
        return json.load(file)


def save_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)

    with open(path, "w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=2)


def build_catalog_indexes(catalog_items):
    catalog_by_key = {}
    catalog_by_category = {}

    for item in catalog_items:
        catalog_by_category.setdefault(item["category"], []).append(item)

        for key in item["matchKeys"]:
            catalog_by_key[(item["category"], key)] = item

    return catalog_by_key, catalog_by_category


def get_manual_alias_key(product):
    for (category, site_title), catalog_title in MANUAL_SITE_TO_CATALOG_ALIASES.items():
        if category != product["category"]:
            continue

        if normalize_text(site_title) == normalize_text(product["title"]):
            return normalize_for_category(catalog_title, category)

    return None


def find_catalog_match(product, catalog_by_key, catalog_by_category):
    category = product["category"]

    manual_key = get_manual_alias_key(product)
    if manual_key:
        item = catalog_by_key.get((category, manual_key))
        if item:
            return item, "manual alias"

    for key in product["matchKeys"]:
        item = catalog_by_key.get((category, key))

        if item:
            return item, "key match"

    # Специально для начинок: сайт даёт "Начинка 1", а каталог — "Начинка 1 Ветчина+сыр".
    if category == "Картошечка в фольге":
        for key in product["matchKeys"]:
            filling_match = re.match(r"^(начинка\s+\d+)$", key)

            if not filling_match:
                continue

            prefix = filling_match.group(1)

            for item in catalog_by_category.get(category, []):
                item_key = normalize_for_category(item["title"], category)

                if re.match(rf"^{re.escape(prefix)}\b", item_key):
                    return item, "filling prefix"

    # Осторожный fuzzy-match только внутри одной категории.
    # Не применяем к слишком коротким названиям, чтобы не словить неправильный чизкейк.
    best_item = None
    best_score = 0.0
    product_best_key = ""

    for product_key in product["matchKeys"]:
        if len(product_key) < 5:
            continue

        for item in catalog_by_category.get(category, []):
            for item_key in item["matchKeys"]:
                if len(item_key) < 5:
                    continue

                score = SequenceMatcher(None, product_key, item_key).ratio()

                if score > best_score:
                    best_score = score
                    best_item = item
                    product_best_key = product_key

    if best_item is not None and best_score >= 0.86:
        return best_item, f"fuzzy {best_score:.2f} by {product_best_key}"

    return None, ""


def main():
    print("Читаю generated_catalog.dart...")
    catalog_items = parse_generated_catalog()
    catalog_by_key, catalog_by_category = build_catalog_indexes(catalog_items)

    print("Сканирую сайт и ищу изображения товаров...")
    site_products = scrape_site_products()
    session = make_session()
    overrides = load_existing_overrides()

    matched = []
    unmatched_site = []
    unmatched_catalog = {
        (item["category"], item["id"])
        for item in catalog_items
    }

    for product in site_products:
        catalog_item, match_reason = find_catalog_match(
            product,
            catalog_by_key,
            catalog_by_category,
        )

        if catalog_item is None:
            unmatched_site.append(
                {
                    "category": product["category"],
                    "title": product["title"],
                    "normalizedTitle": product["normalizedTitle"],
                    "matchKeys": product["matchKeys"],
                }
            )
            continue

        output_base_path = (
            Path("assets/images")
            / product["folder"]
            / slugify(product["title"])
        )

        try:
            image_path = download_image(
                session,
                product["imageUrl"],
                output_base_path,
            )
        except Exception as error:
            print(f"[WARN] Не скачалась картинка для {product['title']}: {error}")
            continue

        for saby_id in catalog_item["ids"]:
            entry = overrides.get(saby_id, {})
            entry["image"] = image_path

            if product["description"]:
                entry["description"] = product["description"]

            if product["weight"]:
                entry["weight"] = product["weight"]

            if product["isNew"]:
                entry["isNew"] = True

            if product["isHit"]:
                entry["isHit"] = True

            overrides[saby_id] = entry

        matched.append(
            {
                "category": product["category"],
                "title": product["title"],
                "catalogTitle": catalog_item["title"],
                "ids": catalog_item["ids"],
                "image": image_path,
                "matchReason": match_reason,
            }
        )

        unmatched_catalog.discard((catalog_item["category"], catalog_item["id"]))

    save_json(OVERRIDES_FILE, overrides)

    unmatched_catalog_items = []

    for category, item_id in sorted(unmatched_catalog):
        item = next(
            catalog_item
            for catalog_item in catalog_items
            if catalog_item["category"] == category and catalog_item["id"] == item_id
        )
        unmatched_catalog_items.append(
            {
                "category": item["category"],
                "title": item["title"],
                "id": item["id"],
                "matchKeys": item["matchKeys"],
            }
        )

    report = {
        "siteProductsFound": len(site_products),
        "catalogItemsFound": len(catalog_items),
        "matched": len(matched),
        "unmatchedSiteProducts": unmatched_site,
        "unmatchedCatalogItems": unmatched_catalog_items,
        "matchedItems": matched,
        "overridesFile": str(OVERRIDES_FILE),
    }

    save_json(REPORT_FILE, report)

    print("Готово.")
    print(f"Найдено товаров на сайте: {len(site_products)}")
    print(f"Найдено товаров в generated_catalog.dart: {len(catalog_items)}")
    print(f"Совпало и обработано: {len(matched)}")
    print(f"Файл overrides обновлён: {OVERRIDES_FILE}")
    print(f"Отчёт создан: {REPORT_FILE}")
    print("Теперь запусти:")
    print("python .\\tools\\generate_flutter_catalog.py")
    print("flutter pub get")
    print("flutter run")


if __name__ == "__main__":
    main()
