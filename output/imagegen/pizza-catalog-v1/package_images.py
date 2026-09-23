from pathlib import Path
import json
import zipfile
from PIL import Image

root = Path(__file__).resolve().parent
plan = json.loads((root / 'generation-plan.json').read_text(encoding='utf-8'))
expected = {p['output'] for p in plan}
actual = {p.relative_to(root).as_posix() for p in (root / '4k').glob('*.jpg')}
assert len(plan) == 33 and actual == expected, (len(plan), expected - actual, actual - expected)
for product in plan:
    with Image.open(root / product['output']) as image:
        assert image.size == (3840, 3840) and image.format == 'JPEG'
        image.verify()
lines = ['Delycafe — 33 пиццы, JPG 3840×3840',
         '4К получено программным увеличением согласованных генераций.',
         'Файл — название товара (ID каталога)', '']
for product in plan:
    lines.append(f"{Path(product['output']).name} — {product['title']} (ID {product['id']})")
(root / 'CATALOG.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8-sig')
archive = root / 'delycafe-pizzas-4k.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
    for product in plan:
        bundle.write(root / product['output'], Path(product['output']).name)
    bundle.write(root / 'CATALOG.txt', 'CATALOG.txt')
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
    assert len([p for p in bundle.namelist() if p.endswith('.jpg')]) == 33
print(f'Checked 33 JPEGs at 3840x3840; archive {archive.stat().st_size / 1024 / 1024:.1f} MiB; ZIP integrity OK.')
