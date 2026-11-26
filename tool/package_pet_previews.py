"""Package actual Flutter renders into review artifacts (requires Pillow).
Run the Flutter exporters first; this never draws replacement character artwork.
"""
import hashlib
import html
import json
import re
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path('build/pet_reconstruction')
GALLERY = Path('build/companion_gallery')
BEFORE = Path('build/pet_polished_before')


def light_image(path):
    image = Image.open(path).convert('RGBA')
    background = Image.new('RGBA', image.size, '#ece9e2')
    background.alpha_composite(image)
    return background.convert('RGB')


def package():
    for directory in (OUT / 'motion').iterdir():
        if not directory.is_dir():
            continue
        frames = [light_image(path) for path in sorted(directory.glob('*.png'))]
        if frames:
            frames[0].save(directory.with_suffix('.gif'), save_all=True,
                           append_images=frames[1:], duration=50, loop=0)

    for after_path in sorted(GALLERY.glob('*.png')):
        before_path = BEFORE / after_path.name
        if not before_path.exists():
            continue
        mapping = after_path.with_suffix('.txt').read_text()
        assert mapping == before_path.with_suffix('.txt').read_text(), after_path.name
        before, after = light_image(before_path), light_image(after_path)
        assert before.size == after.size
        comparison = Image.new('RGB', (after.width, after.height * 2 + 48), '#ece9e2')
        draw = ImageDraw.Draw(comparison)
        draw.text((12, 6), 'Previous polished design', fill='#34322d')
        comparison.paste(before, (0, 24))
        draw.text((12, before.height + 30), 'Softer matte companions / Flutter runtime', fill='#34322d')
        comparison.paste(after, (0, before.height + 48))
        path = OUT / 'comparisons' / after_path.name
        path.parent.mkdir(parents=True, exist_ok=True)
        comparison.save(path)

    species = [path.name for path in sorted((OUT / 'neutral').iterdir()) if path.is_dir()]
    sizes = [32, 48, 64, 96, 128, 256]
    sheet = Image.new('RGB', (6 * 280, len(species) * 280), '#ece9e2')
    draw = ImageDraw.Draw(sheet)
    for row, name in enumerate(species):
        for col, size in enumerate(sizes):
            x, y = col * 280, row * 280
            draw.text((x + 8, y + 8), f'{name} · {size}px', fill='#34322d')
            sheet.paste(light_image(OUT / 'neutral' / name / f'{size}_transparent.png'),
                        (x + (280 - size) // 2, y + 20 + (256 - size) // 2))
    sheet.save(OUT / 'small_sizes.png')
    mappings = {path.stem: path.read_text() for path in OUT.glob('*.txt')}
    manifest = {
        'renderer': 'Flutter AvatarScenePainter with native scene geometry',
        'head_only': True,
        'species': species,
        'sizes': sizes,
        'backgrounds': ['transparent', 'light', 'dark'],
        'catalog_sha256': hashlib.sha256(Path('assets/avatars/scenes/avatar_scenes.json').read_bytes()).hexdigest(),
        'mappings': mappings,
        'neutral_png_count': len(list((OUT / 'neutral').glob('*/*.png'))),
        'motion_source': 'Seeded PetBehaviorEngine and live Avatar3DView; idle, click, play; 20 FPS; 6 seconds',
        'gif_files': [str(p.relative_to(OUT)) for p in (OUT / 'motion').glob('*.gif')],
    }
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    reference = Path('/private/tmp/oneworks-avatar-reference/.github/assets/avatar-cover-light-en.jpg')
    if reference.exists():
        (OUT / 'reference.jpg').write_bytes(reference.read_bytes())
    options = ''.join(f'<option>{html.escape(name)}</option>' for name in species)
    (OUT / 'index.html').write_text('''<!doctype html><meta charset="utf-8">
<title>Companion head review</title><style>
body{font:15px system-ui;background:#ece9e2;color:#34322d;max-width:1120px;margin:40px auto;padding:20px}
select,a{margin-right:14px}img{max-width:100%;height:auto}.pet{width:256px;height:256px;object-fit:contain}
nav{line-height:2.4}.motions{display:flex;gap:20px;flex-wrap:wrap}.motions img{width:128px}
</style><h1>Softer companion heads</h1><p><strong><a href="http://127.0.0.1:8766/">Open the live interactive companion</a></strong> — follows your cursor, reacts to clicks, and has a size slider.</p><p>This sheet contains saved images and recordings. Use the live preview for interaction.</p><p>Matte shading, gentler motion, and revised alpaca, sheep and parrot anatomy. All 32 pets remain head-only.</p>
<h2>Alpaca fit and anatomy</h2><p><a href="http://127.0.0.1:8766/?species=alpaca">Try the alpaca live</a></p><img src="alpaca_views.png" alt="Revised alpaca front, three-quarter and side views"><img src="alpaca_poses.png" alt="Alpaca fitting all eight poses"><details><summary>View the original OneWorks reference</summary><p><a href="https://github.com/oneworks-ai/avatar">OneWorks Avatar repository</a></p><img src="reference.jpg" alt="Official OneWorks Avatar reference gallery"></details><h2>Sheep and parrot</h2><img src="cute_focus_views.png" alt="Revised sheep and parrot in front, three-quarter and side views"><h2>All 32 heads</h2><img src="../companion_gallery/1_species_0.png" alt="Corrected species row 1"><img src="../companion_gallery/1_species_1.png" alt="Corrected species row 2"><img src="../companion_gallery/1_species_2.png" alt="Corrected species row 3"><img src="../companion_gallery/1_species_3.png" alt="Corrected species row 4"><h2>Inspect a head</h2>
<select id="species">''' + options + '''</select><select id="size"><option>32</option><option>48</option><option>64</option><option>96</option><option>128</option><option selected>256</option></select>
<select id="background"><option>transparent</option><option>light</option><option>dark</option></select>
<p><img id="pet" class="pet" alt="Selected companion head"></p>
<nav><a href="all_views.png">All views</a><a href="silhouettes.png">Silhouettes</a><a href="all_emotions.png">384 expressions</a><a href="all_poses.png">256 poses</a><a href="all_activities.png">288 activity previews</a><a href="small_sizes.png">Actual pixel sizes</a><a href="manifest.json">Mappings</a><a href="performance.json">Measured geometry cost</a></nav>
<h2>Foundation views</h2><img src="foundation_views.png" alt="Front, three-quarter and side views of cat, dog, parrot, capybara and seal">
<h2>Live behavior recordings</h2><div class="motions">''' + ''.join(
        f'<figure><img src="motion/{name}.gif" alt="{name} interaction and recovery"><figcaption>{name}</figcaption></figure>'
        for name in ['alpaca', 'sheep', 'parrot', 'cat', 'dog', 'capybara', 'seal']) + '''</div>
<h2>Before and after</h2><nav>''' + ''.join(
        f'<a href="comparisons/{path.name}">{html.escape(path.stem)}</a>'
        for path in sorted((OUT / 'comparisons').glob('*.png'))) + '''</nav>
<script>const species=document.querySelector('#species'),size=document.querySelector('#size'),background=document.querySelector('#background');function update(){const pet=document.querySelector('#pet');pet.src=`neutral/${species.value}/${size.value}_${background.value}.png`;pet.style.width=size.value+'px';pet.style.height=size.value+'px'}[species,size,background].forEach(e=>e.onchange=update);update()</script>''')
    revision = hashlib.sha256(
        Path('assets/avatars/scenes/avatar_scenes.json').read_bytes() +
        b''.join(path.read_bytes() for path in sorted(Path('lib/features/companion/avatar3d').glob('*.dart')))
    ).hexdigest()[:12]
    document = (OUT / 'index.html').read_text()
    document = re.sub(r'(src|href)="([^"?]+\.(?:png|gif|jpg))"',
                      lambda match: f'{match[1]}="{match[2]}?v={revision}"', document)
    document = document.replace('${background.value}.png`', '${background.value}.png?v=' + revision + '`')
    (OUT / 'index.html').write_text(document)
    (OUT / 'reference-review.html').write_text(document)
    print(json.dumps({'species': len(species), 'neutral_pngs': manifest['neutral_png_count'],
                      'gifs': len(manifest['gif_files']), 'review': str(OUT / 'index.html')}))


if __name__ == '__main__':
    package()
