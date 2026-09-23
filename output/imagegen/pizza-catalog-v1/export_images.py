"""Export user-approved generated pizza images at 3840x3840 (resampled, not native 4K)."""
from pathlib import Path
import json
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent
for directory in ('originals', '4k'):
    (ROOT / directory).mkdir(exist_ok=True)

report = []
for source in sorted((ROOT / 'originals').glob('*.png')):
    with Image.open(source) as opened:
        image = ImageOps.exif_transpose(opened).convert('RGB')
        if image.width != image.height:
            raise ValueError(f'Non-square source must be reviewed: {source.name}')
        outputs = {}
        for directory, size in [('4k', 3840)]:
            extension = '.jpg'
            destination = ROOT / directory / (source.stem + extension)
            if not destination.exists() or source.stat().st_mtime > destination.stat().st_mtime:
                resized = image.resize((size, size), Image.Resampling.LANCZOS)
                resized.save(destination, quality=95, subsampling=0, optimize=True)
            with Image.open(destination) as check:
                assert check.size == (size, size)
            outputs[directory] = {'path': str(destination.relative_to(ROOT)), 'width': size, 'height': size, 'bytes': destination.stat().st_size}
        report.append({'original': str(source.relative_to(ROOT)), 'native_size': list(image.size), 'method': 'Pillow LANCZOS resampling; not native 4K', 'exports': outputs})
(ROOT / 'export-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Exported and checked {len(report)} images at 3840x3840 pixels only.')
