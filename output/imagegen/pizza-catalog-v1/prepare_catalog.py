"""Prepare reference/ingredient prompts; this script does not call any image API."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
catalog = json.loads((ROOT / 'catalog-source.json').read_text(encoding='utf-8-sig'))
supplements = {
    61: 'Грудка куриная копченая, ананас, перец болгарский, лук красный, соус сливочно-чесночный, сыр',
    66: 'Сливочный соус, сосиски, помидоры, сыр, зелень',
    67: 'Соус Дьябло, колбаса пепперони, сервелат Элитный, острый перец Халапеньо, помидоры, сыр, оливки, зелень',
    74: 'Красная рыба, креветки, кальмары, авторский сливочный соус, сыр, оливки, зелень',
    75: 'Ветчина, свинина варено-копченая, помидоры, соус томатный, сыр, оливки, зелень, соус сливочно-чесночный',
    76: 'Ветчина, картофель, обжаренный лук, маринованные огурчики, соус Портабелло, оливки, зелень',
    77: 'Пепперони, томатный соус, помидоры, сыр, острый соус, оливки, зелень, соус Баффало',
    78: 'Колбаски Пепперони, бекон, жареный лук, картофель, сыр, томатный соус, оливки, зелень',
    80: 'Творожная масса, сгущенное молоко, свежие киви, банан, ананас, топпинг клубничный',
}
slugs = ['assorti', 'barbecue', 'vecherinka', 'hawaiian', 'hungry-butcher-chili',
         'hungry-butcher', 'mushroom', 'country-chicken', 'kids', 'diavola',
         'hot-chica', 'zlodeyka', 'carbonara', 'korona', 'margherita', 'mister-bacon',
         'seafood', 'meat', 'okay', 'pepperoni', 'cosmos', 'prosciutto', 'fruit',
         'caesar', 'chicken-bbq', 'chicken', 'berry', 'sea-breeze', 'marquise',
         'fantasy', 'creamy-salmon', 'spicy-salmon', 'unagi']
base = (
    'Use case: product-mockup. Generate ONE individual photorealistic pizza product photograph for Delycafe. '
    'The approved style reference is ONLY for camera angle, pizza scale, modest golden thin crust, pure white backdrop, '
    'soft upper-left diffuse lighting, delicate contact shadow and sharp natural baked texture throughout. '
    'Do NOT copy its toppings. The original product photograph, when supplied, is a reference for food identity and topping cut shapes. '
    'The ingredient list is authoritative and overrides conflicting visual ingredients in reference photographs. '
    'Camera nearly overhead with a subtle diagonal tilt, matching the approved reference. Full round pizza centered, '
    'all crust edges visible and white margins on all sides. Square canvas, highest available native quality. '
    'No plate, board, props, text, logo, collage, swollen Neapolitan crust or heavy charring. '
    'No invented toppings or garnish. Finely chopped herbs only when listed, no decorative whole basil leaves. '
    'Natural cafe food, not plastic. '
)
(ROOT / 'prompts').mkdir(exist_ok=True)
for product, slug in zip(catalog, slugs, strict=True):
    product['slug'] = f"{product['id']:03d}-{slug}"
    product['ingredients_source'] = 'tools/catalog_overrides.json'
    if product['id'] in supplements:
        product['ingredients'] = supplements[product['id']]
        product['ingredients_source'] = 'user-confirmed 2026-09-23' if product['id'] == 74 else 'https://pizzaozersk.ru/pizza/?page=2'
    if not product['source']:
        candidate = 'assets/images/pizza/' + product['fallbackImage'].rsplit('/', 1)[-1]
        product['source'] = candidate if (PROJECT / candidate).exists() else None
    if not product['ingredients']:
        raise ValueError(f"Missing ingredients: {product['title']}")
    product['style_reference'] = 'originals/069-zlodeyka.png'
    product['output'] = f"4k/{product['slug']}.jpg"
    product['status'] = 'ready' if (ROOT / product['output']).exists() else 'pending_generation'
    prompt = base + f"Pizza: {product['title']}. Strict ingredient list: {product['ingredients']}. "
    if product['id'] in (80, 84):
        prompt += 'This is a SWEET dessert pizza: no tomato sauce, meat, savory cheese, olives or herbs. '
    if product['id'] == 79:
        prompt += 'Despite its name, follow this cafe recipe with chicken; do NOT substitute Italian prosciutto ham. '
    if product['id'] == 88:
        prompt += 'Creamy salmon version: no orange spicy sauce drizzle. '
    if product['id'] == 62:
        prompt += 'Spicy sauce does not imply whole chili or jalapeno toppings; do not add unlisted peppers. '
    if product['id'] == 74:
        prompt += " No mussels or tomato as these are NOT in the user's confirmed recipe."
    if product['id'] == 75:
        prompt += ' Only one image is provided: it is the approved style reference, not a reference for meat toppings. Follow the strict ingredient list.'
    product['prompt'] = prompt
    (ROOT / 'prompts' / (product['slug'] + '.txt')).write_text(prompt, encoding='utf-8')
(ROOT / 'generation-plan.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2), encoding='utf-8')
ready = sum(p['status'] == 'ready' for p in catalog)
print(f'{len(catalog)} recipes prepared; {ready} ready, {len(catalog)-ready} pending generation.')
