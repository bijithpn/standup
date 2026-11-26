# Reference-style, head-only companions

The active collection now uses the actual MIT-licensed model definitions from
[OneWorks Avatar](https://github.com/oneworks-ai/avatar), pinned to commit
`a06ba84c123cf82e2b1a59c36b403392e22f9d08`.

The earlier custom organic-skull generator produced elongated ovals, tiny eyes,
muted colors, and inappropriate muzzle bulges. It has been retired; the Node
importer is the supported entry point. All 32 animals remain head-only; the reference squirrel's tail is
excluded to respect that composition.

## What is preserved from the reference

- Authored primitive combinations, proportions, attachment positions, head taper,
  roundness, and depth.
- The natural palettes, larger rounded eye shapes, noses, and facial markings.
- Actual curved marking boundaries, sampled on the upstream part-local 3D surfaces.
- Official bear breed definitions for panda, red panda, and raccoon.

`tool/import_oneworks_heads.mjs` reads a local source checkout without modifying
it. It requires a modern Node version with TypeScript stripping and module hooks;
it installs no runtime dependencies. The Flutter application continues to render
natively. The MIT notice is retained in `assets/avatars/LICENSE`.

```sh
node tool/import_oneworks_heads.mjs /path/to/oneworks/avatar --foundation
node tool/import_oneworks_heads.mjs /path/to/oneworks/avatar
```

The generated `assets/avatars/scenes/oneworks_source.json` records provenance,
minor eye-placement adaptations to avoid muzzle occlusion, and numerical geometry
samples obtained from the upstream authoring engine. Tests compare native primitive
sampling against these external reference values.

## Rendering corrections

Whole-part average depth cannot resolve overlapping skulls, ears, muzzles and cheek
volumes. The renderer now computes frontmost surface ownership from triangle depth,
then clips each native mesh and its vector facial features to its visible regions.
Ownership resolution is bounded and adaptive. Small overlap between merged clip
runs prevents pinholes during rasterization.

Eyelid-only updates reuse the body meshes and ownership masks. Part-local surfaces
remain in a bounded shared cache. Existing expression identifiers, behavior state
ownership, personality profiles, pointer tracking, reduced-motion handling and
resource disposal remain in place.

The reference faces bypass the rejected generic eye tuning, glossy pupil treatment,
floating brows, blush overlays, and added whiskers. Native shape projection handles
tapered heads and rounded triangular noses consistently with the source geometry.

## Review artifacts and validation

```sh
flutter test --no-pub test/features/companion
PET_COMPLETE_EXPORT=1 flutter test --no-pub test/features/companion/avatar3d/reconstruction_preview_test.dart
flutter test --no-pub test/features/companion/avatar3d/companion_gallery_test.dart
python3 tool/package_pet_previews.py
```

## Live cursor preview and desktop sizing

The image review sheets are saved renderings. For actual interaction, compile
the dedicated Flutter entry point, then serve it locally:

```sh
flutter build web --no-pub --target tool/pet_live_preview.dart --output build/pet_live_preview
python3 -m http.server 8766 --bind 127.0.0.1 --directory build/pet_live_preview
```

Open `http://127.0.0.1:8766/` (or `?species=alpaca` to select a specific pet). This runs `Avatar3DView` and
`PetBehaviorEngine`, with all 32 species, a 240–560 px size slider, pointer
tracking across the view, click/play/treat reactions, and reduced motion.
The default stage is 440 px. Rendering suspends when the page is hidden. The
local preview bootstrap retires older service workers and uses local CanvasKit
assets so cached definitions cannot hide an updated character.

Desktop PiP defaults to 360 × 400 px and supports up to 560 × 620 px.
Hover to reveal the plus/minus window controls. The former saved 280 × 320 px
default migrates to the new size; deliberate custom sizes remain unchanged.
The native window bridge binds directly to the PiP panel, so frame queries and
cursor samples share screen coordinates. Local hover events also feed the
behavior engine. Cursor movement wakes a settled frame loop; the initial cursor
sample initializes position without triggering a false startle reaction.

Regression coverage in `live_cursor_preview_test.dart` exercises real pointer
events, checks left/right changes in the rendered scene yaw, and verifies click
feedback. The engine tests also verify cursor wake-up after settling.

The packager uses development-only Pillow to assemble actual runtime exports;
it does not generate or substitute character artwork.

Open `build/pet_reconstruction/index.html`. It shows all 32 corrected heads first,
then species/size/background controls, representative motion GIFs, full expression
and pose sheets, and before/after comparisons against the rejected custom design.
The seven original sheets retain their TXT row/column mappings. The export also
contains 576 neutral PNGs across six sizes and three background modes, plus front,
three-quarter, side and silhouette comparisons.

Visual acceptance requires inspecting these artifacts; passing tests alone does
not establish art-direction parity. Software geometry timings exclude production
GPU cost, desktop idle CPU and long-run memory use.

## Softer companion art direction

The local refinement layer, `tool/pet_character_refinements.mjs`, now supplies a
matte finish for the collection and distinct local alpaca/sheep/parrot anatomy. The sheep
has a compact contrasting lamb face inside an asymmetric wool silhouette. The
parrot replaces the upstream cone with a curved volumetric hook and a separate
hinged lower jaw. These local refinements are intentional departures from the
unmodified source definitions.

The alpaca has a shorter, fuller cranium, rounded upright ears with embedded
lining, an asymmetric fluffy forelock, and a projecting muzzle below the eyes.
Its former tall face mask is removed. A scene-authored minimum frame padding of
0.16 preserves space for ear movement and stretch poses. Bounce displacement
scales with the widget size using the existing 220 px pose reference, so small
pets retain the same motion proportions. `alpaca_framing_test.dart` captures the
actual widget with transparent margins and checks all eight poses at all six
supported sizes for pixels outside the pet frame.

Matte shading uses quiet, flat tonal bands, softer outlines and no forced eye
sparkles. Geometry remains anti-aliased and depth-correct. The renderer adds no
random noise, blur, or texture effect. The behavior engine owns recurring motion;
the view only eases transitions and ear follow-through. Reaction springs are more
damped, idle squash is smaller, and interaction strength follows species temperament.

`cute_focus_views.png` and the sheep/parrot GIFs in the review gallery are generated
from the same native geometry and live behavior snapshots. Motion recordings include
idle, a click response and a playful response across six seconds.

Record the actual widget, including finite expression transitions, with:

```sh
PET_COMPLETE_EXPORT=1 flutter test --no-pub test/features/companion/avatar3d/cute_motion_preview_test.dart
python3 tool/package_pet_previews.py
```
