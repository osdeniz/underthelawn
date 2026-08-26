# Under The Lawn

Godot 4 port of the **LastLawn** SwiftUI + SceneKit prototype. The full
specification lives in [REFERENCE.md](REFERENCE.md) (§1-§19) and is the source
of truth for every number; [SPRINT_G1.md](SPRINT_G1.md) is the current sprint
brief. Built and verified on **Godot 4.7.2**.

## Run

```bash
open -a Godot "/Users/omersalihdeniz/Desktop/Under The Lawn/project.godot"
```

Press **F5**. Portrait, 1170x2532 logical viewport (the window opens at 390x844
on desktop). Drag anywhere on the lawn to drive: hold to throttle, drag to
steer. Mouse drag works because `emulate_touch_from_mouse` is on.

## Sprint G1 — core feel (done)

| Area | Where | Spec |
| --- | --- | --- |
| Data model | `scripts/lawn_model.gd` | §3 — 16x24, CellState, mow(), obstacles, secret placement |
| Ground + striping | `scripts/lawn_view.gd`, `shaders/lawn_ground.gdshader` | §4, §5 — one plane, 16x24 tint texture, 4 direction tones, re-striping |
| Tufts | `scripts/tuft_field.gd`, `shaders/grass_tuft.gdshader` | §5 — 8 MultiMesh variants, 7 tufts x 2 crossed quads, GPU wind, 0.1 s topple |
| Push mower | `scenes/Mower.tscn`, `scripts/mower.gd` | §6, §7 — primitives, throttle/coast, smooth steering, wall + obstacle response |
| Camera | `scripts/camera_rig.gd` | §10 — chase, mid preset, bird's-eye reward |
| Light + atmosphere | `scenes/Main.tscn` | §13 — sun, sky gradient, ambient, depth fog, fake AO (no SSAO) |
| HUD | `ui/hud.tscn`, `scripts/hud.gd` | §16 — percentage, capsule, mute, LAWN COMPLETE |
| Audio | `scripts/audio_director.gd` | §14 — file based, no runtime synthesis |
| Haptics | `scripts/haptics.gd` | §15 — light/medium/success, one per frame |
| Config | `scripts/game_config.gd` | §17 — every tunable number |

Autoloads: `GameState`, `Haptics`, `AudioDirector`.

### Deliberate platform deviations

* **No SSAO** — it does not work in the Mobile renderer. §13's fake AO (radial
  dark decal under the mower) is the only contact shading.
* **No runtime audio synthesis** — `AudioDirector` loads the four `.ogg` files
  named in `audio/README.md`; missing files warn to the console and the game
  runs silent.
* **Spec yaw kept as-is** — the spec's yaw grows clockwise, Godot's grows
  counter-clockwise, so `mower.yaw` stays in spec space and is applied as
  `rotation.y = -yaw`. Every §7 formula is therefore verbatim.

### Requested deviations from the spec

Asked for after the first G1 pass, so these override §5 on purpose:

* `TUFTS_PER_CLUSTER` 7 → **11** (denser lawn).
* `TUFT_CLUSTER_SPREAD` 0.34 → **0.44**, so clusters cross cell borders and the
  grid pattern of gaps disappears.
* Per-cluster colour variation on the tuft MultiMesh (brightness 0.82-1.14 plus
  a nudge towards dry yellow or deep green) so the lawn is not one flat green.
* MSAA **4x**, anisotropic filtering **4x**, and `alpha_to_coverage` on the tuft
  shader so blade edges are antialiased instead of stair-stepped.

## Generated placeholder assets

`tools/gen_assets.gd` writes the textures §5 describes and the sounds §14
describes to disk as **real files**, so the game only ever loads files (the
brief forbids runtime synthesis). Regenerate with:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/gen_assets.gd
```

| File | Recipe |
| --- | --- |
| `textures/grass_albedo.png` 512 | seamless wrapped fbm: green patchiness, blade grain, dry yellow tips, faint clipping streaks |
| `textures/grass_normal.png` 256 | normal from the same fine grain height field |
| `textures/grass_blade_tuft.png` 512 | **supplied artwork**, processed by `tools/import_tuft.gd` (see below) |
| `audio/mower_engine_loop.wav` 1.00 s | 85 Hz + 6 harmonics at 1/k, 10% AM at 13 Hz, tanh saturation — seamless (85 and 13 both close in 1 s) |
| `audio/grass_cut.wav` 0.16 s | white noise, one-pole lowpass sweeping 2800 → 500 Hz, fast attack + exponential decay |
| `audio/discovery_chime.wav` 0.70 s | E6 then B6 after 0.12 s, exponential decay |

The generator **never overwrites an existing file** — real art or recordings
dropped into `textures/` or `audio/` are safe. Delete a file first if you want
its placeholder back.

### Importing supplied artwork

`tools/import_tuft.py` (needs Pillow) turns a supplied grass PNG into a
Godot-ready alpha card:

```bash
python3 tools/import_tuft.py ~/Downloads/grass_blade_tuft.png textures/grass_blade_tuft.png
```

It fixes the two things image generators get wrong:

1. **No alpha channel.** Generated "transparent" PNGs often have the
   transparency *checkerboard drawn into the pixels*, or a flat white/black
   backdrop. The backdrop is keyed out by **saturation** — grey is background,
   green is grass — which handles checker, white and black alike.
2. **Backdrop bleeding into antialiased edges.** Edge pixels are un-mixed
   against the measured backdrop colour, so no white or dark halo survives.

Then it crops to the artwork, keeps the aspect ratio and resizes to 512 tall.
It prints `KART_ENBOY` (the cropped aspect) — put that in
`GameConfig.TUFT_CARD_ASPECT` so quad width follows the art and the blades are
never squashed.

The current card is 368x512, roughly 16% covered, one tuft of ~9 blades. If a
future card is a dense grass *wall* instead of a single tuft, the field needs
the opposite treatment (fewer, wider quads and UV slicing).

`ambient_birds_loop` is intentionally NOT generated — §14 says it is never
synthesised. Drop in a real recording and it plays at 18%.

`AudioDirector` accepts `.ogg`, `.wav` or `.mp3` by base name, so replacing any
of these with a real recording of the same name needs no code change. Same for
the textures via `TextureLibrary`.

## Verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/model_check.gd
```

34 assertions over §3: grid size, obstacle cells, the pool's single collision
rect, cell centre maths, stripe buckets, secret placement rules, mow results,
re-striping, completion, restart. Plus `--headless --editor --quit` for parse
errors and `--write-movie` renders for visual checks.

## Sprint G2 — effects, audio, secret discovery (done)

| Area | Where | Spec |
| --- | --- | --- |
| Clipping particles | `scenes/Mower.tscn` (Clippings), `mower.gd` | §9 — right side, 0.06 s bursts min 0.12 s apart, alpha blend not additive |
| Audio mixing | `scripts/audio_director.gd` | §14 — engine idle/moving lerp, 3-voice cut pool, ambient, mute, background suspend |
| Haptics | `scripts/haptics.gd` | §15 — 10 ms mow, 25 ms reveal, double pulse on collect and 100% |
| Secret shimmer | `scripts/secret_glow.gd` | §9 — orb r0.15, float, pulse, spin, looping sparks |
| Dig burst | `scripts/dig_burst.gd` | §9 — soil burst, 160/s over 0.15 s, gravity |
| Secret items | `scripts/secret_item.gd` | §9 — key and radio primitives, rise/hold/drift |
| Discovery card | `ui/hud.tscn`, `hud.gd` | §16 — card, then shrinks into the counter |
| Collection + missed | `hud.gd` | §16 — slots, "You missed something..." |
| Screen dressing | `shaders/screen_overlay.gdshader` | §16 — sun gradient + vignette, input-transparent |

A tap is tested against the shimmers first (ray/sphere via `camera.project_ray`);
only a miss becomes a mower command. Collecting is optional — a secret cell
counts toward 100% as soon as it is mown, so ignoring the shimmer costs nothing.

## Sprint G3 — tractor, robot, mower picker (done)

The movement core was lifted out of the push mower into a shared base first, so
all three types run the *same* §7 maths and differ only in parameters, input
source and model.

| File | Role |
| --- | --- |
| `scripts/mower_controller.gd` | Shared core: throttle, 0.4 s/0.55 s ramps, steering smoothing 9.0, speed-widened turns, wall clip, circle-rect obstacle push-out, deck sweep, clippings, fake AO |
| `scripts/push_mower.gd` | §7 Push — hold to throttle, drag past 8 pt to steer |
| `scripts/tractor_mower.gd` | §7 Tractor — joystick Y throttle (reverse 0.5x), X steering with sign flip in reverse |
| `scripts/robot_mower.gd` | §7 Robot — boustrophedon route, tap-to-go, 60 pt swipe nudge, breathing LED |
| `scripts/mower_math.gd` | Pure, autoload-free tractor mapping + route planner, unit tested |
| `scripts/tractor_joystick.gd` | §7 joystick: base r55 pt, knob r24 pt, deadzone 0.25, spring return |
| `scripts/mower_selector.gd` | §16 three-way picker, hides at 100% |
| `scenes/PushMower.tscn` `Tractor.tscn` `Robot.tscn` | §6 models |

Switching keeps position and heading, resets speed, swaps the camera preset and
the engine mix, and replans the robot route from the current lawn state.

`tests/g3_check.gd` covers the §6 parameter table, the tractor mapping
(including the reverse sign flip), and the route planner (serpentine order, no
waypoint on an obstacle, detour around the stone, nothing inside the pool, every
mowable cell visited).

### Unit note

§7 measures touch distances in SwiftUI **points** on a 390 pt wide screen. The
viewport is 1170 px wide, so `GameConfig.POINT_SCALE` is 3. G1 read the 8 pt
drag threshold as 8 *pixels*, which triggered steering almost instantly; it is
now 8 pt = 24 px. The robot's 60 pt swipe threshold uses the same conversion.

## Sprint G4 — driver character (done)

`scripts/character.gd` builds the §8 driver entirely from primitives: no
skeleton, every joint its own Node3D pivot, all animation sine/lerp. One shared
material set, shadows on, a small ground-hugging fake-AO decal.

| Mode | Where | Behaviour |
| --- | --- | --- |
| Push | child of the push mower at (0, 0.79, 1.45) | leans into the handle; walks when speed > 0.06 (legs opposite phase, knees fold only on the back swing, torso roll + bob); idle recovers at 8/s and breathes |
| Tractor | child of the tractor at (0, 0.80, 0.42) | seated, hands on the wheel; torso yaw answers steering (-steer × 0.18 at 6/s), head follows at 0.6, arms shift with it, 40 Hz engine shiver |
| Robot | scene root, `CHAR_BENCH_POS` | sits at the lawn's north edge watching; breath only. The constant moves to the G5 porch later |

The mower picker drives the mode: `Game._place_character` reparents the one
character instance on every switch.

Sign note: §8 rotations are SceneKit eulers; limbs here hang along -Y, so
forward is +X rotation for limbs and -X for the torso. Magnitudes are §8's.

## Sprint G5 — neighborhood and environment (done)

`scripts/environment_builder.gd` builds §11 + §12 as one static node
(`Neighborhood` in Main.tscn): primitives only, textures from `textures/` via
TextureLibrary with flat-colour fallbacks.

* **House** at z=-16.8: siding body 13x3.2x4.2, SurfaceTool pyramid shingle
  roof, chimney, panelled door + doormat, two windows (frame, dark interior,
  curtains, reflective glass, muntins, sill), porch (deck, posts, railing,
  eave, step), five bushes, wall contact-shadow band. The G4 sitter now sits ON
  the porch (`CHAR_BENCH_POS`).
* **Pool** (§11): 16x12-segment water plane with the vertex wave, semi-
  transparent turquoise over the pool-floor tint, cream stone border; wooden
  lounger + orange towel on the sunbed cell facing west. The stone and the
  flowerbed soil replace their grey placeholders too (placeholders hidden).
* **Fence**: one MultiMesh for all ~113 posts (single draw call) + three beam
  boxes; per-post height/tilt jitter.
* **Trees** x3 (§12 spots): leaning bark trunk, two branches, nine deformed
  clumps (dark low / light high), ground shadow blot offset from the sun.
* **Road**: jointed sidewalk, textured asphalt, dashed centre line; **cars**:
  blue sedan + red pickup with glasshouse, side windows, door seams, plates,
  mirrors, emissive head/tail lights, rimmed wheels.
* **Neighbours** x3 low-detail beyond the road, softened by the §13 fog.
* **Smalls**: mailbox, coiled hose, flowerbed + two garden clusters (daisy /
  tulip / lavender, ±0.06 rad sway at ~1.9 s), four drifting cloud billboards.

`tools/gen_assets.gd` now also writes siding, shingles, bark, wood, asphalt,
dirt and cloud textures (same skip-if-exists rule).

## Sprint G6 — living neighborhood: traffic, water, sky, Blade (done)

New content beyond REFERENCE.md, layered on top without touching G1-G5 systems.

* **Traffic** (`scripts/traffic_controller.gd`): pooled sedan/pickup/SUV/van
  variants with random colours cross the road both ways (right-hand lanes,
  6-8 u/s, 8-20 s apart); every 90-120 s one pulls into a neighbour driveway,
  kills its lights, waits 10 s, backs out and leaves. Per-car
  AudioStreamPlayer3D plays `audio/car_pass.ogg` when present.
* **Water**: second fast ripple layer, fresnel alpha/specular (clear from
  above, bright at grazing angles), two counter-scrolling normal fields for
  crawling sun glints, tiled pool floor with refraction wobble
  (`shaders/pool_floor.gdshader`), dark wet band on the border lip.
* **Sky/light**: warm-horizon/saturated-top gradient, static cirrus layer at
  y=40, shadow blur 3.0 + runtime 2048 atlas, subtle additive bloom (threshold
  1.25, intensity 0.35), roughness pass on trim/door/boots.
* **Micro-motion**: canopy sway (±0.02 rad, 3.5 s), mailbox flag salute every
  60-90 s, rare single bird (`audio/bird_single.ogg` when present).
* **Blade** (`scripts/blade_mower.gd`, 4th selector entry ⚙️): yaw-free saw
  disk that chases the finger at 9 u/s within a 2.5-unit grab radius, glides
  0.3 s on release; spinning disk (720°/s +20% with motion), omnidirectional
  double-density clippings, counter-rotating blur ring, green speed trail,
  orange sparks + clink + 25 ms haptic when grinding the stone; engine loop at
  pitch 2.6 (a real `audio/blade_spin.ogg` is preferred when present); the
  driver watches from the porch, camera wide with low lookAhead.

### G6 quality switches (game_config.gd)

`TRAFFIC_ENABLED`, `WATER_FANCY_ENABLED`, `SKY_HIGH_CLOUDS_ENABLED`,
`GLOW_ENABLED`, `SHADOW_MAP_2048`, `MICRO_MOTION_ENABLED`, `BLADE_FX_ENABLED`.

## Sprint G6.5 — grass overhaul + Blade repair (done)

**Grass**: the alpha-card tufts are replaced by VOLUMETRIC opaque clumps
(`shaders/grass_clump.gdshader`, rebuilt `tuft_field.gd`): 5-7 V-folded
two-segment blades per clump, baked root->tip vertex-colour gradients
(converted sRGB->linear — raw values rendered washed-out), 8 weighted variants
(5 vivid greens, 2 dry-yellow, 1 light green with tiny white flower
octahedra). No texture, no alpha. Density knob: `TUFTS_PER_CLUSTER` (5).
Cut feedback: clippings inherit the cut clump's colour, and a freshly cut cell
flashes bright for 0.4 s before settling into its stripe tone.

**Blade repair**: root cause was NOT code — the editor had rewritten Main.tscn
and dropped the externally added Blade node, so ⚙️ silently activated the robot
through `clampi`. Fixes: `Game._ensure_all_mowers()` spawns any missing
GameConfig mower type from code (with a console note), and `_activate` warns
instead of silently clamping. The input chain was traced end-to-end and is
sound. Trail softened to fading round puffs.

`tests/FourMowers.tscn` drives all four mowers in one automated scene run and
fails unless each cuts ≥5 cells (the robot gets a longer window: its §7
executor zeroes throttle at every waypoint, so it averages ~0.8 u/s — a pace
fix would change robot feel and needs its own approval).

Desktop FPS with the new grass: 120 (vsync cap). Phone knob: TUFTS_PER_CLUSTER.

## Sprint G6.6 — grass palette system, carpet density, chakram (done)

**A) Palette infrastructure.** `GameConfig.GRASS_PALETTES` defines a whole grass
look in one place: `cluster_base`/`cluster_tip` (the vertex gradient), weighted
`accents` (dry 15%, flowered 5%), `ground_mowed` stripe ladder and `clipping`.
`ground_tall_tint()` DERIVES the uncut ground from the cluster family, so the
ground always reads as the base of the grass — new palettes get a correct ground
for free. Every grass colour in the codebase now reads from the palette; no
hard-coded grass colour remains. `ACTIVE_GRASS_PALETTE` is the single switch;
a `PURPLE` palette is defined as proof and verified by screenshot, then reverted
to `GREEN`.

Prerequisite fix: `grass_albedo.png` is regenerated as NEUTRAL luminance detail.
It used to bake green in, so a purple palette could never multiply to purple.

**B) Carpet density.** Each cell's mesh now holds `TUFTS_PER_CLUSTER` (9) clumps
spread across the cell with baked bimodal heights (70% short filler, 30% tall
spikes, 0.4-0.9 band), so instance scale no longer shrinks footprints. Uncut
ground is essentially invisible from the air; it only appears where mowed.
Triangles 169k, 254 draw calls, 91 FPS on desktop.

**C) Blade → chakram.** Blue donut hub (section r0.07, hole in the middle) with
seven dark rivets, six white-cream sickle blades sweeping back 25° per segment
as SOLID slabs with glowing blue tips, diameter ~1.1, translucent white-blue
spin-blur disk beneath. `BLADE_SCALE` grows mesh, cut radius and body radius
together for future Size upgrades. Mechanics unchanged.

Debug note worth keeping: the sickles rendered BLACK through four wrong
hypotheses (normals, cull mode, geometry, shadows). Measuring the mesh proved
normals/material/environment were all fine; the cause is that **Godot treats
CLOCKWISE winding as front-facing**, so the auto-correction was culling exactly
the faces it meant to keep and showing the slab's unlit underside.

### Grass knobs
`ACTIVE_GRASS_PALETTE`, `TUFTS_PER_CLUSTER` (9→7→5), `CLUMP_BLADES` (6),
`CLUMP_HEIGHT_MIN/MAX`, `CLUMP_TALL_CHANCE`, `BLADE_SCALE`.

## Sprint G6.7 — movement tuning (done)

**Robot pace fix.** Arriving at a waypoint used to set `throttle = 0`, so the
0.4 s acceleration ramp restarted at every single cell and the robot averaged
~0.8 u/s against its 2.1 nominal. `_gather_input` now advances the route cursor
and picks the next target **in the same tick** (bounded loop, so several
consumed waypoints do not stall it), and only stops when nothing is left to mow.
Measured: **0.8 → 1.89 u/s (89% of nominal)**.

**Per-type steering.** `MOWER_TYPES` gained `steer_gain` and `turn_drag` so each
vehicle tunes without touching the shared §7 core:

| Type | steer_gain | turn_drag | Why |
| --- | --- | --- | --- |
| Push | 5.0 | 0.45 | §7 reference feel, unchanged |
| Tractor | 5.0 | **0.28** | at 4.8 u/s the §7 0.45 gave a ~5.8 unit turning radius — wider than a third of the lawn |
| Robot | **7.0** | 0.30 | chases waypoints, needs to snap onto a heading; its 2.6 rad/s ceiling still bounds it |
| Blade | — | — | yaw-free, inert |

`ROBOT_ARRIVE_DISTANCE` 0.35 → **0.5** (it used to orbit its target).

`tests/PaceCheck.tscn` audits average speed against nominal for all four types
and fails below 55%. Current: push 89%, tractor 88%, robot 89%, blade 99%.

## Sprint G6.8 — chakram redesign + blade feel (done)

**Form.** The saw disk is now the ceremonial chakram from the reference art:
four cream-and-gold arms ending in crescent horns, four emerald gems set in the
gaps, and a pierced gold hub (ring + stepped collar + diamond frame). Arms are
extruded 2D silhouettes run through `Geometry2D.triangulate_polygon`, so the
concave crescent notch comes out clean; the colour banding (gold root → cream
body → silver horns, plus two darker engraved arcs) is baked into vertex
colours rather than textures. Span ~2.0.

Two calibration notes worth keeping: the gold band has to reach past r≈0.47 or
the hub's diamond bars hide it, and arm metallic had to drop 0.45 → 0.12
because at 0.45 the plates mirrored the bright sky and read as white plastic.

**Proportional follow.** The flat 9 u/s chase felt like a teleport. Desired
speed is now `distance × BLADE_FOLLOW_GAIN` capped at `BLADE_MAX_SPEED` (3.2 and
5.0), so fine finger moves drift and big sweeps accelerate.

**Variable spin.** The disk idles lazily at `BLADE_SPIN_IDLE_DEG` (70°/s) and
revs to `BLADE_SPIN_FAST_DEG` (1000°/s) with motion, eased at
`BLADE_SPIN_LERP` so it reads as spin-up. Measured 119°/s at rest, 646°/s under
a normal drag. The blur halo is fully transparent at rest and fades in with
speed.

## Sprint G6.9 — chakram detail pass (items 2 + 4 of 3)

**Line work (item 2).** `tools/gen_assets.gd` writes `chakram_arm.png`: a
MOSTLY-WHITE map that MULTIPLIES over the vertex banding — vertex colours
cannot carry engraving at ~40 verts per arm. It holds longitudinal gold lines,
two cross bands near the hub, a spine groove, rim darkening and light
weathering scratches. `_extrude_arm` now emits real UVs (u across the arm,
v along the radius), so a constant-radius arc is a horizontal line in the map.

**Hub teeth (item 4).** 24 radial teeth around the ring's inner mouth — small,
but it is what sells the hub as machined rather than a plain donut.

**Exact silhouette (item 1) — NOT DONE.** It needs the reference image as a
file to trace; chat attachments cannot be read from disk. Drop it at
`textures/ref_chakram.png` and the outline can be measured from pixels instead
of eyeballed.

### Two traps worth remembering

* **UV normalisation.** Dividing the lateral coordinate by the LOCAL half-width
  would make stripes follow the taper exactly, but the arm is a triangulated
  outline with NO interior vertices, so every boundary vertex lands on u=0 or
  u=1 and most triangles go UV-degenerate — the line work vanished completely.
  A fixed divisor is used instead. Following the taper properly needs a gridded
  arm mesh; that is the same rebuild item 1 wants, so do them together.
* **Generated textures need an import pass.** After `gen_assets` writes a NEW
  png, `ResourceLoader.exists()` returns false until Godot imports it, so
  `TextureLibrary.find()` silently misses and the material renders untextured.
  Run `--headless --editor --quit` between generating and testing.

## G6.10 — chakram traced from the reference

`textures/chakram1.0.svg` (a potrace line trace of the reference photo) turned
"looks like it" into "is it". `tools/trace_chakram.gd` rasterises the SVG,
finds the filled centroid, polar-marches 720 angles for the outer radius,
averages the four sectors so the result is exactly 4-fold symmetric, and scales
the peak to `BLADE_ARM_REACH`. It prints a 128-point `PLATE_OUTLINE`, which now
lives in `blade_mower.gd`.

The payoff of tracing: because the plate mesh is measured from the SAME svg
that `gen_assets._chakram_plate()` colourises into `chakram_plate.png`, a plain
top-down UV (`_plate_uv`, fixed divisor `HALF_EXTENT = 1.30`) registers every
engraved line — arm arcs, hub diamond frame, square windows, crescent horn
detail — pixel-for-pixel with the silhouette. No hand-fitting.

Consequences of the single-plate rebuild:

* The four separate extruded arms, `ARM_SIDE`/`ARM_NOTCH` and `_arm_color` are
  gone; one extruded plate replaces them.
* The hub hole is real geometry, punched with `TRANSPARENCY_ALPHA_SCISSOR`
  inside `BLADE_HUB_INNER` — you can see grass through it.
* The hub torus shrank to a narrow raised lip and the diamond bars were
  deleted, because both hid the engraved frame the texture already draws.
* Gems moved inward to radius 0.165-0.300 and up to y=0.062: the traced outline
  dips to ~0.29 at 45 degrees, so anything further out poked past the
  silhouette, and anything lower was swallowed by the domed plate.

### Shape and palette pass

`BLADE_PLATE_SHARPEN` (1.32) remaps each outline radius as
`r' = reach * (r/reach)^g`, which pulls the waist in and leaves the horn tips
where they are, so the corners read sharp instead of rounded. The exponent is
faded in with `smoothstep(0.34, 0.62, r)` — applied flat it collapses the
engraved hub frame into the centre hole, and at 2.1 the whole plate degenerates
into four thin propeller blades. UVs are taken from the UNSHARPENED trace point
so the engraved rim line still lands on the rim.

Palette: `BLADE_GOLD`/`BLADE_CREAM` darkened, gold now carries the plate out to
r=0.30 (cream only takes the outer third, silver just the horns), and
`BLADE_GEM` is a glowing purple at emission energy 1.6.

### G6.11 — thinner, sharper, purple

* `BLADE_ARM_TAPER` (0.68) pulls each outline point's ANGLE toward its own arm
  axis. The radial sharpen alone thins the waist but leaves the arms fat; the
  angular squeeze is what turns them into spikes. Both fade in with the same
  `smoothstep(0.34, 0.62, r)` so the hub survives.
* Gems roughly doubled (0.140-0.355 radius, +/-0.100 wide, peak y 0.150). The
  outer tip has to stay under ~0.36 or it overhangs the now-thinner plate.
* `BLADE_SHIMMER` purple: the motion halo is tinted with it and a rim-emitted
  particle ring throws purple sparkles whenever the plate is really turning
  (gated at speed > 0.6 rather than > 4.0, so it shows during normal play).

Two fixes worth keeping in mind for any future glow:

* **Additive, not alpha.** Purple alpha-blended over green grass averages to a
  muddy grey — exactly the "grey" complaint. `BLEND_MODE_ADD` makes it glow.
* **No hard-edged disks.** The halo was a `CylinderMesh`, and its perfect
  circular edge read as a pancake lying on the lawn no matter how low the
  alpha went. A `PlaneMesh` with the feathered `cloud_billboard` texture fades
  into the grass instead.

## G6.12 — one control scheme, and the cut bug

### The cut bug: cut radius vs visible footprint

The blade "drove over grass without cutting it". The mow loop was fine; the
numbers were not. The chakram plate reaches `BLADE_ARM_REACH` (~1.02) but the
blade's deck was **0.55**, so grass under the outer half of the visible disk was
never touched. Separately, cells are 1.0 wide, so half a cell diagonal is
**0.708** — any deck under that can sit on a cell corner and reach no cell
centre at all. Push and robot were at 0.7, just under the line.

Decks are now push/robot 0.75 and blade 0.95, and `tests/CutCoverage.tscn`
pins both rules. It was written to fail first: at deck 0.55 it reports
`kesme yaricapi 0.550 < hucre kosesi 0.707, gorunen 1.02, kesen 0.55`.

`_mow` also sweeps the deck along the segment travelled since the last tick
rather than point-sampling the current centre. Worth noting honestly: at 60 Hz
and these speeds the stride is ~0.08 units, so the sweep changes nothing today
and is NOT what fixed the bug — it is cheap insurance if speeds ever rise.

### Shared drag pad

Every mower now uses one scheme, in `MowerController`: press **anywhere** on
screen and the drag offset from that point becomes a virtual stick — up is
forward, down is reverse, sideways steers. It runs through
`MowerMath.tractor_input`, the §7 mapping that already handled reverse speed and
the steering-sign flip, so all four types share one set of rules.

* Push dropped its absolute-heading steering for the pad.
* The tractor's HUD joystick still works; a drag anywhere else drives the same
  mapping.
* The robot keeps tap-to-go and swipe-to-nudge, but a drag that leaves the dead
  zone takes it off its route and drives it by hand until release.
* The blade no longer has to be grabbed (`GRAB_RADIUS` is gone) and no longer
  snaps to the finger: the stick is its travel direction and its deflection is
  its speed.

Push also turns much tighter — `max_turn` 1.7 -> 2.6 and `turn_drag` 0.45 ->
0.26. §7's values turned like a bus on a 16x24 lawn. `tests/g3_check.gd` pins
the deviations so a later drift still trips.

**The trap: camera-relative control plus a camera that follows you.** The
camera yaw chases the mower's yaw, and the blade derived its heading from the
live camera yaw — so every direction except straight ahead curved away, in a
feedback spiral. Straight ahead is the loop's fixed point, which is exactly why
it was the only direction that looked correct. `pad_camera_yaw()` latches the
camera yaw when the finger lands and holds it for the gesture.

Both new suites are `tests/CutCoverage.tscn` and `tests/DragPad.tscn`; the
latter drives each mower through the real touch entry points from a press in a
screen corner.

## G7 — case framing

The lawn is the same lawn; what changed is what it means. A retired officer is
searching a property for a girl who did not come home. Sunny-melancholy, uneasy,
never frightening — the outbreak is over and is only ever implied.

No gameplay system was rewritten. Mowing, striping, the four mowers, the secret
placement and the HUD are untouched; they were re-labelled.

### All narrative text lives in data/story.json

`Story` (scripts/story.gd) loads it once and reads it by dotted path —
`Story.text("briefing.body")`, `Story.list("intro.cards")`. It is static and
cached, so it needs no autoload and no project.godot entry (which the editor
likes to rewrite). A missing key returns the caller's fallback rather than
crashing, so a half-written story file still boots. That forgiveness hides
typos, so `tests/story_check.gd` asserts every key the UI actually asks for.

G11's data-driven chapters will read files shaped like this one — keep the
structure rather than flattening it.

### Flow

Opening cards (first launch only) -> briefing box -> camera descends onto the
property while the opening title holds -> search.

* `IntroSequence` builds its three cards in code: illustration, one or two white
  lines, 6 s Ken Burns from 1.0 to 1.06, fade between cards. Every card is the
  same three nodes with different data, so it is a loop, not a tree worth
  hand-editing.
* `_search_started` in game.gd gates `_unhandled_input`, so the lawn hears
  nothing while the cards or the briefing are up, and the run clock does not
  start until the case is accepted.
* Watched-once is persisted as `[story] intro_seen` in `user://settings.cfg`.
  The **STORY** button beside mute replays it; that button is the whole settings
  surface until G8's hub arrives.
* `CameraRig.descend_to()` glides from high above onto the mower's own §10
  preset. Cosmetic only — the rig keeps following the target, so tapping early
  costs nothing.

### Two UI traps this sprint

* **`set_anchors_preset` does not size anything.** It moves the anchors and
  leaves the offsets alone, so every intro node stayed 0x0 and the card text
  wrapped to one character per line down the screen edge.
  `set_anchors_and_offsets_preset` is the one that sizes.
* **An unset `ColorRect` is opaque white.** The intro scrim was a bare
  `ColorRect` used only as a parent for its gradient child, and it painted over
  the warm ground completely. It is a plain `Control` now.
* Also: the default theme's `PanelContainer` is nearly invisible, so the
  briefing text floated over the grass until it got an explicit `StyleBoxFlat`.

### Art this sprint expects (none of it required to run)

All optional — each has a fallback, so the sprint is playable and reads
correctly with no art at all.

| File | Size | Fallback when missing |
| --- | --- | --- |
| `textures/intro/intro_1.png` | 1170x2532 portrait | flat `INTRO_GROUND` warm dark |
| `textures/intro/intro_2.png` | 1170x2532 portrait | same |
| `textures/intro/intro_3.png` | 1170x2532 portrait | same |
| `textures/portraits/marshal.png` | 320x320 square | circle with the speaker's initial |

Intro cards are drawn `STRETCH_KEEP_ASPECT_COVERED`, so a little bleed is fine,
but keep the subject clear of the bottom third — the text and the scrim sit
there. Portraits are cropped to a circle, so keep the face centred.

## G7.1 — Ellie's toy, and real multi-language support

### The toy mesh

Evidence 0 was still §9's rusty key while the label said "Ellie's Toy".
`_build_toy()` replaces `_build_key()`: spheres and capsules, no metalness so it
reads as cloth beside the metal radio, everything sized from `TOY_BODY` so the
whole toy scales as one number. The head sits slightly forward and is
oversized, which is what makes a plush toy read as a plush toy from the
top-down camera.

Two things had to be measured rather than assumed. `TorusMesh` already lies in
XZ, so rotating it by PI/2 for a "collar" stood the loop up front-to-back and
buried it inside the body. And even lying flat it has to reach WIDER than the
head (0.78r) and sit below the head's underside, or the overhead camera never
sees it. The key constants stay in GameConfig; only the mesh call is gone.

### Multi-language: keys, not sentences

`data/story.json` now holds **translation keys**, and `i18n/strings.csv` holds
the sentences with one column per language. Adding Turkish, Arabic, French,
German or Chinese means adding a column — never editing the json, a scene, or a
script. `Story.text()` runs the key through the `TranslationServer`;
`Story.raw()` returns literals that are not language-dependent (image paths,
emoji, ids).

All player-facing UI moved to `tr()` as well: the percentage, the evidence
counter, the completion stats (English now: `368 cells searched · 1:24`), the
restart and story buttons, the empty-slot dash, and the four mower names in the
picker (`MOWER_TYPES["label"]` is a key now).

**Placeholders are named, not positional.** `{cells}`/`{time}`, not `%d`/`%s`.
A translator can reorder `{cells}` for a language whose grammar demands it; a
positional `%d` cannot move. `tests/story_check.gd` asserts this.

### Two things that break when you add a language, both handled

* **Glyphs.** The default theme font is Latin-only, so Arabic, Hebrew, Chinese,
  Japanese, Korean, Hindi and Thai render as empty boxes. Drop a wide-coverage
  font (Noto Sans is the usual answer) at `fonts/i18n_fallback.ttf` and
  `LocaleSupport.apply()` appends it to `ThemeDB.fallback_font` — appends, so
  the current Latin look is untouched and only missing glyphs come from the new
  file. With no file present it warns only when the active locale actually needs
  those glyphs, so an English build stays quiet.
* **Direction.** Arabic and Hebrew need the whole layout mirrored, not just the
  text runs reversed. That is `rendering/root_node_layout_direction`.
  **The trap: `2` is "force RTL", not "locale based".** Setting 2 mirrored the
  entire English UI — percentage on the right, counter on the left, evidence
  listed backwards. The locale-based value is **0**.

### How to verify i18n without any translation

`tests/story_check.gd` proves the key -> csv -> screen path using Godot's
built-in pseudolocalization, so no invented translation is needed. It also
catches prose pasted back into the json (verified: replacing a key with
`AREA SEARCHED` fails two assertions).

That test proves the pipeline works, not that every string uses it. To find
strings that bypass `tr()`, run with
`internationalization/pseudolocalization/use_pseudolocalization=true` and look
for text that stayed plain English.

### Adding a language, start to finish

1. Add a column to `i18n/strings.csv` (`keys,en,tr`) and fill it.
2. Add `res://i18n/strings.<code>.translation` to
   `internationalization/locale/translations` in project.godot.
3. For a non-Latin script, drop `fonts/i18n_fallback.ttf` in place.
4. Nothing else. Locale is never forced in code — Godot follows the OS locale
   and falls back to `en`, which is correct on a phone.

### Turkish is in (G7.2)

`i18n/strings.csv` now has an `en` and a `tr` column and both are registered in
`internationalization/locale/translations`. Verified end to end: the whole HUD,
briefing, opening title and completion panel render Turkish, and every Turkish
diacritic (i-dotless, s-cedilla, g-breve, dotted capital I, a-circumflex) draws
with the default theme font — no fallback font needed for Turkish.

`tests/story_check.gd` grew with the second language and now checks, per
language:

* every key is filled in for **every** column (a blank cell silently shows
  English or the bare key)
* the `{named}` placeholder set is identical across languages, so no language
  can print a literal `{cells}`
* each locale actually loads and differs from English, so a copy-pasted English
  cell cannot pass as a translation
* the `en` column carries no Turkish letters — checked per COLUMN, not on the
  whole file, since the Turkish column contains them on purpose

Both new failure modes were verified to trip the test: blanking a Turkish cell
and renaming `{cells}` to `{hucre}` each produce failures.

The CSV is parsed with `FileAccess.get_csv_line()`, not `split(",")` — half
these strings contain commas inside quotes and a plain split shreds them.

## G8 — community hub + data-driven dialogue

### Flow

    intro cards (first launch only)
      -> HUB  (case board / town / workshop)
      -> case board -> pick a chapter
      -> briefing dialogue  [SEARCH THE PROPERTY]
      -> game scene (scenes/Main.tscn)
      -> debrief dialogue -> AREA SEARCHED panel
      -> [RETURN TO TOWN] -> HUB

`scenes/Root.tscn` (`RootFlow`) is the new main scene and owns every transition,
each behind a black fade. `scenes/Main.tscn` is untouched as the game scene and
still runs standalone — all five scene tests instantiate it directly, so it must
never depend on RootFlow. It is handed a `variant_id`, reports back through
`search_finished(evidence, total)`, and if nobody is listening it just keeps
playing. `RETURN TO TOWN` calls `return_to_hub()` on its parent if that method
exists and restarts otherwise, so the panel never dead-ends.

### A chapter is an ID, never a scene

`data/story.json` `chapters[]` entries carry a `variant_id` and no path.
Chapter selection emits `chapter_chosen(variant_id)`; RootFlow sets that string
on the game scene before `_ready`. G9 will build all eight chapters from this
one scene plus LevelVariant data, so `tests/flow_check.gd` asserts every chapter
entry has a `variant_id` and carries **no** `scene`/`path` key — that assertion
exists specifically to stop "one .tscn per chapter" creeping back in.

Progress lives in `user://settings.cfg` under `[progress]`, keyed by
`variant_id`. Evidence counts only ever go **up**: replaying a chapter and
finding less must not erase what the case already knows (asserted).

### One dialogue system

`data/dialogue.json` + `DialogueBox`. A conversation is a list of entries; an
entry is a spoken line `{speaker, text}` or a flavour choice
`{choice: {options: [...]}}`. **A choice never branches** — picking an option
splices its single reaction line in right after the current entry and the
conversation continues. That keeps every caller's control flow linear, which is
why the briefing, the debrief and town chatter are all the same data and the
same UI. Speaker ids double as portrait file names.

The G7 briefing panel is **gone** from `hud.tscn`; it was a second dialogue
implementation and DialogueBox replaced it. Typewriter runs at 55 cps; the first
tap completes the line, the second advances, so a reader is never slowed and a
skimmer is never blocked.

Town chatter picks the highest variant whose `min_done` the player has reached,
so the town reacts to case progress with no bookkeeping at the call site.

### Two traps

* **The intro art loaded as JPEG data inside `.png` files.** Godot's PNG
  importer refused them (`valid=false` in the `.import`), `ResourceLoader.exists`
  still returned true, and `load()` failed — so the cards silently fell back to
  the flat ground. Renaming to `.jpg` fixed it with no code change, because
  `TextureLibrary` already searches `.png/.jpg/.jpeg/.webp`. Check `file` output,
  not the extension.
* **Godot does not clip children to a parent's rounded StyleBox.** The portrait
  drew as a hard square over its rounded frame until the frame got
  `clip_children = CLIP_CHILDREN_ONLY`.

### Art status and what portraits want

Present: `textures/intro/intro_1..3.jpg`, `textures/portraits/marshal.png`,
`textures/portraits/ellie.png`. Missing (all fall back cleanly):
`textures/hub/town_square.png` (warm gradient instead) and portraits for
`sarah`, `gus`, `cole`, `stranger` (lettered card instead).

The supplied portraits are tall full-figure illustrations rather than the 320x320
the brief suggested, so the frame is a **tall rounded card (150x200)** instead of
a circle — a circle cropped them to a torso. Either shape works; if you'd rather
have circles, crop the sources square on the face.

### G8.1 — the portrait art, used at both sizes

The supplied character art is 9:16 full-figure illustration, so it is now used
two ways from ONE source file per character — nothing needs re-cropping by hand.

* **Dialogue** shows the full illustration LARGE
  (`DIALOGUE_PORTRAIT_SIZE`, 430x764), standing above the text panel, with the
  panel overlapping its foot so figure and box read as one unit instead of two
  stacked rectangles. A thumbnail wasted the art.
* **The town list** needs a face, so `tools/crop_faces.gd` generates
  `textures/portraits/face_<id>.png` (320x320) from the same file, using
  `GameConfig.PORTRAIT_FACES` — face centre and crop size as **fractions** of
  the source, since the sources are not all the same resolution. The crop is
  square in pixels off the shorter edge, so no face comes out stretched.

The fractions were tuned by looking at the contact sheet the tool writes to
`/tmp/faces_sheet.png`, not guessed once: the first pass cut every face at the
eyes, the second at the chin, the third framed all six. Regenerate after
changing art or the fractions:

    Godot --headless --path . --script res://tools/crop_faces.gd
    Godot --headless --editor --quit --path .

**The extension trap, in reverse.** This batch had `marshal.jpg` and
`ellie.jpg` containing PNG data (the other four were real JPEGs). Godot's
importer goes by extension, so those two would have failed exactly like the
`.png`-named JPEGs did in G8. Renamed to `.png`. The rule either way: check
`file <path>` output, not the extension — `TextureLibrary` searches
`.png/.jpg/.jpeg/.webp` so any correct extension works.

### G8.2 — the hub illustration landed

`textures/hub/town_square.jpg` is in and the fallback gradient is retired.
Two fixes it forced:

* **Buttons over an illustration need an explicit ground.** The default theme
  button is nearly transparent, so the three hub cards read as smudges floating
  on the art rather than as tappable cards. `_style_card()` gives them a dark
  rounded panel with an accent border and a real pressed state, and dims the
  locked one. The same helper now styles the chapter rows, the town rows and the
  back button, so nothing in the hub relies on the default theme.
* **Two vignettes stack.** The illustration already darkens its own top and
  bottom, and the scrim I sized for a flat gradient (0.68 / 0.78) turned the
  whole square muddy. Now 0.46 / 0.62.

The cards also moved to the bottom (`anchor_top = 0.54`, `ALIGNMENT_END`): the
art's subject is mid-frame and cards parked over it hid the entire square.

One localisation note: the artwork has a legible-ish **Turkish** notice pinned to
the board. Text baked into an image cannot be translated, so any language other
than Turkish will show it as-is. It is small and mostly illegible at phone size,
so it is left alone — but for future art, ask for signage with no readable
lettering.

### G8.3 — list backdrop, face crops, and art weight

**List backdrop.** Eight card rows straight over the illustration left art
showing through every gap and read as stripes. `_list_backdrop()` puts one calm
dark rounded panel behind the case board and the town list, so each reads as a
single panel.

**Face crops, per character.** Reviewed one at a time at full 320px:
`marshal`, `sarah` and `stranger` were already right; `gus`, `cole` and `ellie`
were cut at the chin, so only those three moved (y down, crop wider). The tool
writes a contact sheet to `/tmp/faces_sheet.png` for exactly this review.

### Art weight: what actually costs

Measured, because the source file size is the least important number here.

| | before | after |
| --- | --- | --- |
| source files on disk | 27.5 MB | 4.4 MB |
| imported data shipped to iOS | 36 MB | 16 MB |
| VRAM per full-screen illustration | ~16.9 MB | ~2.6 MB |

Two independent causes, two fixes:

* **`compress/mode=0` (Lossless) was the real problem.** A 1536x2752 texture
  costs `w*h*4` = 16.9 MB of VRAM as RGBA8, and ten of them would be ~170 MB —
  not viable on a phone. `compress/mode=2` (VRAM Compressed) becomes ETC2/ASTC
  at roughly 4 bits per pixel instead of 32. Verified at 1:1 on the intro card:
  the sky gradient stays smooth and the fine detail is intact, so there is no
  quality reason to keep Lossless here.
* **The art was larger than anything that displays it.** `tools/shrink_art.gd`
  resizes each source to its actual drawn size, derived rather than guessed: the
  viewport is 1170x2532 and the backgrounds are drawn KEEP_ASPECT_COVERED, so
  height binds; the intro cards additionally need `INTRO_KEN_BURNS_TO` (1.06) of
  headroom, which is why they stayed near their original size while the portraits
  went to 2x of `DIALOGUE_PORTRAIT_SIZE`. `INTRO_KEN_BURNS_TO` now lives in
  GameConfig and `IntroSequence` reads it, so the zoom and the source size cannot
  drift apart.

`shrink_art.gd` overwrites in place and always writes JPEG (lossless PNG of a
painted illustration is many times larger for no visible gain), replacing a
`.png` source with `.jpg` and deleting the old file. Masters were copied to
`~/Desktop/UTL-art-originals/` first — outside the repo, so git does not carry
27 MB forever. Keep that folder; re-running the tool on already-shrunk files is
a no-op but re-exporting from masters is how to change targets.

Two things left alone on purpose:

* `TextureLibrary` caches every texture it loads and never evicts. Resident art
  after visiting the hub and town is roughly 19 MB, which is fine — but G9 adds
  eight chapters of art, and that is when eviction will start to matter.
* The full-resolution headless render (`--resolution 1170x2532`) reports a
  square 2532x2532 viewport to Controls and draws the hub black. It is a headless
  artifact, not a layout bug: every verified render at 468x1013 is correct.

## G9 — chapter variants, evidence flow, scrap

### One scene, eight yards

`data/levels.json` holds one `LevelVariant` per chapter and **no scene paths**.
`LevelVariant.apply()` is the single place a variant touches the engine, and it
runs from `Game._enter_tree()` — not `_ready()` — because `EnvironmentBuilder`
builds the house and landmark in its own `_ready`, and child `_ready` always
precedes the parent's. Getting that order wrong means the yard is built before
anyone knows which yard it is.

The grid is data now. `GRID_COLS`/`GRID_ROWS`/`CELL_COUNT`/`HALF_X`/`HALF_Z`
kept their names but became `static var`s that `set_grid()` rewrites, so all
fifty existing call sites are untouched and the model, view, tuft field, camera
bounds, robot route planner and completion percentage all follow automatically.
Sizes: small 12x18, medium 16x24, large 20x30, and the cellar's 10x14.

Obstacle layouts (`beds` / `pool` / `stones` / `open`) store positions as
**fractions** of the grid and sizes in cells, so one layout works at 10x14 and
20x30 without a second table, clamped so nothing hangs off a small yard.
`LawnModel.resolve_layout()` is static and side-effect free because
`EnvironmentBuilder` needs the same answer before any model exists — one
resolver means the pool prop and the pool collision can never disagree.

| ch | palette | size | layout | structure |
| --- | --- | --- | --- | --- |
| 1 Aldridge House | GREEN | medium | beds | house v1 |
| 2 Neighbor's Yard | GREEN_COOL | small | pool | house v2, no porch |
| 3 Old Playground | DRY_GOLD | medium | open | playground |
| 4 Flooded Lot | MARSH | medium | stones | none |
| 5 Greenhouse | LUSH | small | beds | greenhouse |
| 6 Water Tower Field | AMBER | **large** | open | water tower |
| 7 Behind the Mill | DUSK_VIOLET | medium | stones | mill |
| 8 Cellar Garden | EMERALD | cellar 10x14 | beds | none, vignette |

Chapter 8 is the one indoor chapter and it reuses the existing light rig rather
than adding one: the sun becomes a steep, dim, cool shaft, ambient drops, and a
ring of dark quads closes the edges. The `Environment` is **duplicated** first —
it is a shared sub-resource, so editing it in place would leak the cellar mood
into every other chapter in the session.

Four landmarks (playground, greenhouse, water tower, mill) stand where the house
would, at the same distance, so camera framing and the fence line need no
special case. Each is one low-detail composition from the same primitives and
textures as the house.

### Evidence flow: the early exit

Finding both pieces of evidence raises a card: **CONTINUE THE CASE** closes the
chapter now, **KEEP MOWING** dismisses it and leaves a small `Continue →` badge
so the offer is never lost. A chapter therefore completes two ways — evidence
plus the player's consent, or 100% mown.

### Scrap

`scrap_budget` points are buried in mowable cells, seeded from `decor_seed` so a
yard's salvage sits in the same spots on every visit — a replay should feel like
the same place, not a reroll (asserted). Cutting one pops a bolt and flies a
`+n` label to the counter, so the number going up is visibly caused by the thing
on the ground.

The payout splits 30% ground haul / 70% completion bonus, and the bonus scales
from `SCRAP_BONUS_FLOOR` (0.55) at 0% mown to 1.0 at 100%, with a separate
`Thorough Search +15%` line only at 100%. **The early exit must not read as a
punishment**, so the test asserts that leaving early still pays a clear majority
of a full mow while 100% stays strictly the most profitable. Totals persist in
`settings.cfg` under `[economy]`; there is nowhere to spend it until G10's
Workshop.

### Tests updated, not deleted

`model_check` and `g3_check` encode §3/§7 numbers from the original yard. G9 made
that yard data and made the *pool-free* `beds` layout the default, so both suites
now **state the world they are checking** (`set_grid_named("medium")` +
`layout_id = "pool"`) and assert against the model's own obstacle rects instead
of remembered cell coordinates. The stone moved to its own model built from the
`stones` layout rather than being asserted into a yard that has none.
`tests/variant_check.gd` is new and covers all eight variants, the grid
propagation, layout clamping at every size, and the economy curve.

### A measurement trap worth remembering

Headless runs are uncapped, so frame counts are NOT time. A tween scheduled for
0.22 s had not finished after 30 headless frames, which looked exactly like a
broken callback. `--fixed-fps 30` makes frames map to seconds; without it, any
timing assertion is meaningless.

### G9.1 — the surroundings follow the grid

Every world anchor around the lawn (fence lines, sidewalk, road, traffic lanes,
neighbor row, driveways, house distance, tree ring, mower spawn) was a constant
tuned for the medium yard, so a small yard sat inside a fence built for a big
one. They are all static functions of `HALF_X`/`HALF_Z` now, expressed as the
ORIGINAL offsets (fence side = HALF_X + 1.6, road = HALF_Z + 7.4, ...), verified
to reproduce the old medium-yard numbers exactly — a behaviour-preserving
refactor on B1 that makes B2-B8 wrap correctly. Trees became edge fractions so
they stay just outside whichever fence the chapter has.

## G9.2 — feel pass: audio, controls, assists, and the review fixes

### Audio: the game makes sound now

`tools/gen_audio.py` synthesizes every file the game looks for into `audio/` as
WAV — engine loop, grass cut, discovery chime, money pickup, blade clank, bird
chirp, ambient bed, car pass, blade whoosh, and a 29 s town theme (Am-F-C-G pad
with a sparse plucked line). Generated OFFLINE and loaded from disk, so the G1
no-runtime-synthesis rule holds; AudioDirector tries `.ogg` first, so a real
recording dropped in later silently replaces any placeholder. Loops carry
`edit/loop_mode=1` in their `.import`. The theme fades in over the intro and the
hub and fades out when a chapter starts.

### Controls: heading steering

Rate steering (finger x = steering wheel) read as "inconsistent" because the
same drag produced a different arc depending on the current heading. The shared
pad now uses HEADING steering: the mower turns toward the direction the finger
points, throttle scales with alignment, and a target behind the mower backs up
instead of pirouetting. The tractor's HUD joystick keeps its §7 wheel mapping.

The blade's camera is LOCKED (`camera_yaw_locked`): a yaw-free mower spinning
the camera made screen directions drift mid-drag — that was the actual source of
"the blade doesn't steer right". With the camera fixed, the live camera yaw is
safe again and the G6.12 per-gesture latch is gone.

### Assists

* **Last-5% finder**: past 90% completion, every remaining uncut cell gets a
  soft pulsing marker (one MultiMesh, ≤40 additive billboards). The end of a
  search is a walk to the glow, not a hunt by eye — the PowerWash lesson.
* **Pad ring**: a ghost-joystick ring appears where the finger lands, with a
  clamped dot tracking the drag. The pad finally has a visible body.
  Trap: it was first added at child index 0 and the HUD's Overlay vignette
  swallowed it — verified by probing state (all correct) and z-order (wrong).
* **First-run hint**: "Drag anywhere to drive", pulsing until the first real
  drag, then never again (persisted under `[hints]`).

### Review fixes

* The locked teaser is a REAL door now: `NEXT: <chapter> →`, primary-styled,
  briefs and starts the next chapter through RootFlow. "Coming soon" is gone —
  it dead-ended since G9 made every chapter playable. Standalone runs (tests)
  hide the button because no flow is above them to serve it.
* Button hierarchy: one primary per screen (NEXT on the notes panel, CONTINUE on
  the exit card); RETURN and RESTART are secondary. The porch flag from G9 was
  written but never read — every house variant grew the same porch; gated now,
  and portless houses get a bare doorstep.
* Ground pickups are MONEY (💵, banknote-green pop), per the design call.
* B1 is `small`: the first chapter is a welcome, not a chore. The movement test
  scenes pin `ch03_playground` (medium, open) via the now-exported `variant_id`.
* GREEN_COOL re-tuned to dew-grey teal: B1 and B2 sit side by side on the board
  and previously read as siblings.
* Outbreak traces, seeded per chapter and never inside the lawn: boarded windows
  on a neighbor, a faded quarantine ring, a tended roadside memorial, a leaning
  blank sign. Implied past only — no text, no gore.

### G9.3 — small-jobs pass (review items 5-7 + pause)

* **Per-chapter openers.** The 847-days line belonged to one house; every
  variant now carries its own `opening` key pair in levels.json (falling back to
  story.json's default), and story_check asserts each pair exists in the csv.
* **Case line fades** `CASE_LINE_HOLD` (6 s) after the search starts —
  objectives parked over play are noise, and the hub repeats the case anyway.
* **STORY moved to the hub** (a quiet card under the three tiles). In the game
  HUD it had been a DEAD button since G8 moved the intro to RootFlow: its signal
  had no listener. The dangling signal is deleted.
* **Ellie's town card** speaks with her mother's voice now (it used to play a
  stranger's shrug), and gains a post-progress line.
* **Pause menu**: ⏸ top-right opens resume / sound / return to town / restart on
  `PROCESS_MODE_ALWAYS`, with everything else frozen by `get_tree().paused`.

Item 8 from the review (GPU profile, then maybe mesh batching) needs a real
phone and stays open on purpose — batching without a measurement is blind.

### G9.4 — birds to the intro, visible cash

* **Birdsong plays over the opening cards only.** In gameplay it read as an
  untraceable background noise; the ambient loop now starts with the intro and
  stops when the hub opens, the Neighborhood's random chirps are off, and the
  town theme carries hub AND gameplay (standalone scene runs start it
  themselves, so tests sound the same).
* **Money is visible now** — the genre-classic green cash stack hovering over
  its cell, bobbing and spinning (`MoneyProp`), collected by mowing into it:
  pop-and-shrink, flying `+$` label, two-tone cash blip (regenerated
  `scrap_pickup`). Design call: bundles stay at the seeded budget points rather
  than money-per-cut — visible pickups are goals to steer toward, money-per-cut
  is noise that devalues the counter. First pass washed out to the pale grass
  tips in full sun; saturated albedo plus a soft self-glow
  (`MONEY_GLOW`) is what makes them read, ad-game style. `ScrapPop` is deleted.

## G10 — the workshop and the corkboard

### Workshop

Gus's shop opens from the hub tile: his face and a progress-picked greeting on
top, then the four mower cards. Each card is either an unlock
(push free, robot 300, tractor 800, blade 1500 — `UNLOCK_COSTS`) or a
three-tier upgrade line with pips (`●●○`): +10%/tier speed for push and
tractor, +12% for the robot, and `BLADE_SCALE +0.15`/tier for the blade — the
G6.6 decision that mesh, cut radius and collision all derive from that one
number is exactly what makes the blade upgrade a one-liner. State lives in
`Garage` ([garage] in settings.cfg, keyed by mower ID, never index).

Purchases go through a confirm sheet (cost + effect), deduct, cha-ching +
success haptic, card and hub counter refresh. Insufficient funds: the price
shakes red and Gus says his line. **The selector now shows only owned mowers**;
`DEV_UNLOCK_ALL` in GameConfig bypasses for tests/dev.

`garage_check` caught a real balance failure before any player did: two fully
mown early chapters paid ~206 against the Robot's 300 — a grind wall at the
first purchase. Ground pickups went 2-5 → 4-8, and the suite asserts the Robot
stays reachable inside two chapters.

### The corkboard

Second tab on the case board (PLACES / THE BOARD). Found evidence hangs as
pinned, slightly tilted cards at positions authored in `story.json` `board`
(fractions of the usable board); unfound slots are grey `?` silhouettes. Red
string sags between COMPLETED chapters — drawn by the game, never the player —
and each connection carries the Marshal's one-line deduction, which together
narrate the case's real shape: she wasn't taken, she chose to go, and someone
cared for them on the way. B8 done pins Ellie's card centre-board with the
CASE 02 note.

Two Control-drawing traps, both caught on render:

* **PanelContainer stretches every child**, so a 16 px pin head became a full
  red card. Pins are siblings laid over the card, not children inside it.
* **A Control's `_draw` renders UNDER its children**, so the string vanished
  beneath the cork texture. Strings live on their own layer between cork and
  cards.

Integrations: VIEW CASE BOARD on the case-notes panel (returns to the hub with
the corkboard open + pin thunk, `audio/pin.wav` in the generator), scrap
counter in the hub top bar, synced to purchases via the `purchased` signal.

## G10.1 — pickups, carrying, flow, and a UI pass

### Evidence is an object you drive over

The reveal spawns the ACTUAL item mesh in the grass (`SecretItem.setup_prop`)
instead of an abstract orb — the player has to see WHAT they found from across
the lawn. Collection is contact-based: `_check_pickups()` takes anything within
`deck_radius + PICKUP_REACH` every frame.

**Why it "sometimes didn't pick up":** collection was a TAP with ray picking,
and since G6.12 every touch also drives the mower. The two fought for the same
touch. Tap-collection and `_pick_glow` are deleted; `tests/pickup_check.gd`
pins the new rule, including that a piece at the deck's edge still counts —
"I drove over it" and "it counted" must agree.

### The haul rides on your back

`CarryStack` piles every pickup on the driver's back (push, tractor) or the
machine's rear deck (robot, blade), re-parented on every mower switch. Cash
bundles stack with a slight per-bundle skew and a squash on each addition;
evidence rides on top as the visible crown. The stack caps at 14 bundles — a
tower taller than the driver reads as a bug, not a reward — while the counter
keeps climbing. Seeing the haul grow IS the reward loop; the corner number is
just the receipt.

### First run goes straight into the grass

Intro cards → briefing → chapter 1. The hub is a place you EARN: showing a menu
of screens before anyone has mown a cell buries the game under its own
furniture. Returning players still land in the hub.

### UI pass

* **Top bar rebuilt as one panel** with explicit non-overlapping slots
  (percentage + evidence on row one, money on row two, progress bar, case line),
  replacing offsets that had accumulated across eight sprints. Pause sits in the
  bar's right end; mute moved into the pause sheet.
* **The hub's top bar uses the same panel language**, so both screens read as
  one product.
* **Tabs are legible.** The inactive tab had been styled as a dark card whose
  dim font made its own label unreadable over the artwork — a tab is a LABEL,
  not decoration, so only its GROUND changes now.
* **Rows are left-aligned two-liners** (title line, state line) across chapters,
  town and hub tiles; a centred label beside a left-hand portrait read as two
  unrelated elements. Completed chapters read green.
* Tabs and lists moved down to clear the taller top bar, which they had been
  overlapping.

### G10.2 — the evidence card is a beat, not a toast

Nearly double the height with a poster-sized art slot showing the object itself,
name and line at bigger sizes, and `CARD_SHOW_TIME` 2.0 -> 3.6 s so both lines
can be read without hurrying. The emoji moved out of the title into its own
slot, so the title is just the name.

### G10.3 — top bars that hold their contents

The hub's money label overflowed the panel: three stacked rows of that type
simply do not fit a bar that height, and growing the bar would eat the artwork.
It is two columns now — case identity left, wallet chip right.

**Trap: `Panel` is not a container.** It does not lay out its children, so the
row collapsed to its own width and the wallet clung to the title.
`PanelContainer` is the one that fills.

The game HUD follows the same language: percentage / evidence / wallet chip on
one row, progress bar, case line, with the chip ending clear of the pause
button. Both bars now read as one product.

## G11 — Case 1, filled in

No new systems. The existing ones now carry the whole of Case 1, all of it in
`i18n/strings.csv` (en + tr) and the three data files.

### The case, in evidence

Every chapter has a briefing (2-3 lines), two named pieces of evidence, a
debrief for full and partial finishes, and a Marshal deduction on the board.
The chain is deliberate: a dropped rabbit, then a boot and a child-sized gap
(she crawled, she wasn't dragged), an arrow drawn east (she is FOLLOWING, not
fleeing), two sets of prints walking side by side, tended seedlings and a
cardigan thread (someone LIVES out here), a station flashlight with the serial
half filed off and a note saying *don't tell the town*, an oiled hatch with a
child's stone game beside it — and Ellie, unharmed, in a lit cellar garden.

Two beats are voiced by someone other than the Marshal, on purpose: Sarah comes
along in B3 and recognises the ribbon, and in B6 the Marshal recognises his own
precinct's lamp and asks to see it when you're back.

### B8 is the case's ending, not a search

Finishing B8 with both pieces plays `finale_case01` (Ellie speaks, the Marshal
counts his blessings and then his questions), then `ReunionCard`: two tapped
full-screen beats — Ellie home, then CASE 02 "WHAT ELLIE SAW" — and lands the
player on the completed corkboard, because the pins ARE the ending. A partial
B8 gets the ordinary "she's close" nudge instead.

`story.json` carries a `case_02` skeleton (keys, no content) so the shape of
what follows is visible in the data rather than only in a plan.

### Polish

* Town chatter runs in three phases (case start / after B4 / after B8), and
  **Ellie is not in town until she is home** — `requires_done` gates a person,
  and the town list rebuilds per visit. Putting her card there from the start
  would answer the question the case is asking.
* Typewriter 55 -> 42 cps and the text box gained a fourth line of headroom:
  Case 1 has lines that wrap to three, and a box that grows mid-read pushes the
  text under the reader's thumb.
* B8's scrap budget dropped to 6 — it is a short finale, and `variant_check`'s
  floor moved with it.

### Known edge case (v1, deliberate)

Leaving a chapter through pause -> RETURN TO TOWN discards that run: the chapter
starts fresh next time, and nothing is recorded. Mid-chapter save state is not
worth its complexity while a chapter is a few minutes long.

### Manual playthrough checklist

1. Fresh install -> opening cards -> B1 briefing -> straight into the grass.
2. B1..B7: briefing -> search -> evidence card -> exit offer -> case notes ->
   VIEW CASE BOARD (pin thunk, new cards, red string) -> NEXT chapter.
3. Workshop after ~2 chapters: unlock the Robot; check the selector gains it.
4. B8: search -> Ellie dialogue -> reunion -> CASE 02 -> completed board.
5. Town at three points (start, after B4, after B8) — Ellie appears only last.

### Art still expected

`textures/story/reunion.png` and `textures/hub/case2_teaser.png` both fall back
to a flat warm ground, so the ending plays without them.

## G12.5 — Case 1 realigned, and a neighbourhood that reads as abandoned

### Text patch (data only)

Five lines rewritten in en + tr so Case 1 plants the right backward-compatible
clues: the drawing gains one concrete detail (seven stars in a ring, worn on his
coat) with its meaning still unstated; the can is SHARING his food rather than
feeding her; Ellie says she followed him and that being seen was dangerous for
HER; and two new board deductions land — the half-filed serial ("Rivera's
batch") and the new face in town the same week as the garden.

**Audit finding:** four board notes still cited the pre-G11 evidence — a shoe, a
seed box, a satchel and a key, and a grown BOOT beside what the chapter calls
bare feet. A deduction that names evidence the case does not contain is a
contradiction, not a style choice, so NOTE_CH02/04/05/07 were realigned.

### The street

* **Traffic is off.** A car cruising past told the player the world was fine,
  which is the opposite of what every other surface says.
* **Derelict houses on all three sides**, seeded per chapter: weathered bodies,
  dark doorways, boards nailed across most windows, some with a missing roof
  corner. None are enterable — they are silhouette and mood.
* **Side yards**: dry grass strips, a sagging fence line and a shed or two
  between our fence and theirs.

Honest limitation, measured rather than assumed: in a portrait top-down camera
the player sees roughly five units either side of the mower, so the sides only
open up at the lawn's edge and buildings out there are seen from almost
directly overhead. The **ground-level dressing does the work on the flanks**
(that is why the yard strips exist), while the north row across the road is
where a house actually reads as a house. Side houses were pulled in to
`fence + 2.6` after measuring where the frame really ends, and their roofs were
lightened because dark ones turned into featureless slabs at the frame edge.

Art: `textures/story/reunion.jpg` and `textures/hub/case2_teaser.jpg` are in.
The reunion file arrived in a `textures/stroy/` folder (typo) and was moved.

## G12.6 — world depth, find markers, town restoration

### World depth

A fourth opening card ("bigger settlements survived, somewhere east") sits
between the rebuild and the disappearance, and every chapter hides ONE **echo**
— a world-history find kept entirely separate from the case evidence
(`echo_def` in levels.json, `EchoLog` for state). A yellowed headline, an
evacuation leaflet, a child's notebook, a guard patch from an emblem nobody here
recognises, a broadcast log whose last east-relay contact was three years ago.

They never advance the case, they are buried like evidence with no glow at all,
and the word "zombie" appears nowhere — the register is *the dead years*. Found
echoes are readable in a new **ECHOES** hub screen; unfound ones are blank slots,
so the collection shows its size without spoiling its contents. The echo card
deliberately drops the evidence card's fly-to-counter flourish: dressing an
aside like a story beat would lie about its importance.

### Find markers

Every find now leaves a permanent mark: a green ring, a thin beam, and the
object's own icon lying at its foot. It flares for 2.4 s and settles to a faint
shaft for the rest of the chapter, so a mown lawn becomes a map of the player's
own search. The camera also glances at the spot for 0.6 s once the card clears
(`FIND_PAN_ENABLED` turns it off), and the case notes now say WHERE each piece
turned up (`location_tag` per evidence, e.g. *near the fence line*).

The beam is a thin cylinder rather than particles: cheaper, steadier, and it
reads from across the lawn, which is the entire job.

### Town restoration — what the money is FOR

A new hub screen (`projects.json`, `RestoreBoard`) spends money on the town
rather than the machine: Ellie's Swing 300, Square Lantern 250, Sarah's
Greenhouse 400, Clinic Supplies 600 (the one with a mechanical effect: +1
salvage point per search), Radio Mast Repair 800 — whose crumb is the bridge to
Case 2 ("something repeats on the east band, same pattern, every night").

Each finished project adds a hub background layer
(`textures/hub/restore_<id>.png`, falling back to a badge) and appends a
**permanent thank-you plus one crumb** to that NPC's town dialogue.

**Economy note.** Restoration is deliberately a SEPARATE screen from the
workshop, and priced above it at the low end: the workshop answers "what do I
need", restoration answers "what is the money for now that I have it". Mixing
them into one list would let a sentimental purchase starve a functional one.
Only the clinic feeds back into income, and only mildly — the swing is the one
I expect players to buy first, and it does nothing at all except exist.

### Analytics

`Analytics.track()` records `echo_found`, `restore_bought` and
`evidence_location_panned`. Nothing leaves the device: events buffer in memory
and print, so the funnel's shape is visible now and a real backend is a change
in one function. It is static and dependency-free on purpose — an analytics call
must never be able to break gameplay.

**Trap, again:** `story_check` had to become a scene test. `RestoreBoard` reads
`GameState`, and in `--script` mode autoloads register AFTER script compilation,
so the suite failed to compile at all.

## G12.7 — restoration tier 2: buildings

Five buildings on the same shape as the tier-1 repairs — cost, hub layer, NPC
thank-you phase, story crumb, at most a mild bonus. No walkable town, no
production loop, no timers.

| project | cost | npc | effect |
| --- | --- | --- | --- |
| Marshal's Station | 1200 | marshal | groups the case screens under one STATION card |
| The Farm | 900 | gus | +5% search payout |
| The Barn | 500 | gus | none — gated behind the Farm |
| Two Homes | 700 | sarah | none |
| Watchtower | 600 | marshal | none |

Tier 2 stays **visible but locked** until two tier-1 repairs are done
(`TIER2_REQUIRES_TIER1`), with the price and the reason both on the card: a
priced door you cannot open yet is a goal, a hidden one is nothing. The Barn
additionally requires the Farm.

The station's "effect" is regrouping, not a new screen — the chapter list and
the corkboard are already two tabs behind one door, so finishing the station
renames that door to STATION and reskins its icon. Town cards gain a small badge
per finished project, so whose life changed is visible at a glance.

### Economy table (measured, not estimated)

| | total |
| --- | --- |
| Case 1 earnings, all 8 chapters at 100% | **1 548** |
| Workshop (unlocks 2 600 + upgrades 5 560) | 8 160 |
| Restoration (tier 1 2 350 + tier 2 3 900) | 6 250 |
| Everything | 14 410 |

**The targets are not met yet, and the gap is worth stating plainly.** Case 1
earns 66% of tier 1's total, so "about half of tier 1 affordable by the end of
V1" holds — but only for a player who buys nothing in the workshop, and the
Robot alone is 300. Across V1+V2 (~3 100) a player who unlocks the Robot and the
Tractor and takes a few upgrades has roughly 1 000 left, which does **not** reach
the 1 200 Station. To hit the brief's target, either chapter earnings roughly
double (per-chapter ~190 → ~380) or costs come down about 40%.

Per the brief these numbers wait for real play measurement, so nothing was
silently rebalanced. `GameConfig.DEV_GRANT_SCRAP` (ships `false`) adds a
+2 000 button to the pause menu for exactly that testing.

An observation from writing the tests: the Watchtower (600) and the Barn (500)
both undercut the tier-1 Radio Mast (800), so "tier 2 is pricier" is not true
item by item. What actually creates the curve is the GATE, and the tests assert
the two things that are true — tier 2 costs more in total, and every tier-2
project starts locked.

### Analytics

`restore_bought` now carries its tier, plus `restore_tier2_unlocked` and
`station_completed`.

### Art keying (tools/key_out.gd) — flat-background path

The overlays were regenerated on a flat magenta background, which is the exact
path: one reference value everywhere, so soft glows resolve correctly. Three
things still had to be measured rather than assumed.

* **The key colour drifts.** The generator does not deliver the `#FF00FF` it is
  asked for, and JPEG pulls it further — these arrived around
  (0.85, 0.25, 0.70) and (0.98, 0.35, 0.95) in two batches. The tool measures
  the key per file from a border strip instead of hard-coding one.
* **Alpha from RGB distance leaves a pink halo.** Distance conflates "half
  transparent" with "a colour that happens to sit near the key". Magenta's
  signature is red and blue high with green low, and this warm palette never
  produces that, so the amount of key in a pixel is measured directly:
  `mix = ((r + b)/2 - g) / same_for_key`, then the colour is un-premultiplied
  and despilled. That removed the halo completely.
* **`get_used_rect()` returns the whole canvas**, because JPEG noise leaves a
  haze of nearly-transparent pixels at the borders. Trimming uses a real
  visibility floor (`TRIM_ALPHA`).

Layers are trimmed to their own bounds and placed by `layer_rect` in
projects.json (screen fractions), because where the generator happened to put an
object on its canvas is arbitrary — the composition belongs to the game. The
values were tuned against renders: the first pass buried the tree under a pile
of buildings, the second left them hanging in its branches, the third put them
on the ground line where the hub's own houses sit.

### Art keying (tools/key_out.gd)

The restoration overlays arrived with the transparency checkerboard **drawn
into the image** rather than written as an alpha channel — a routine failure of
image generators. `tools/key_out.gd` finds the two checker greys, erases them,
and reconstructs the soft shadows: a shadow on a checkerboard is the checker
multiplied down, so `alpha = 1 - darkness` gives back a real alpha shadow
instead of a grey smear. The alpha channel is then box-blurred over one checker
cell, which erases a symmetric alternating pattern exactly while a shadow's
gradient survives; solid artwork keeps its own alpha so object edges stay sharp.

Three things were measured rather than assumed, each after looking at the
result: guessing a pixel's checker square from its BRIGHTNESS fails inside
shadows (a shadow on a light square lands on the dark square's value, so half of
every shadow was being deleted); JPEG noise pushes a grey shadow past a 0.10
saturation test; and a cast shadow reaches ~0.57 below its square, so the
original darkness threshold kept most of every shadow opaque. The naive blur was
also 2.2 billion reads per image — it is separable with running sums now.

**What is still imperfect, and why it cannot be fixed here:** a soft coloured
glow over a checkerboard is two unknowns per pixel (its colour and its alpha)
against one equation. The lantern's halo and the darkest core of each cast
shadow keep some pattern. The fix is upstream — generate on a FLAT colour
instead — and `FLAT_KEY` in the tool already implements that path exactly.

## G12.8 — play-test fixes

Six findings from playing on device.

### Evidence had two meshes for sixteen objects

`SecretItem` only knew the teddy bear and the radio, so a found ribbon lay in
the grass as a bear and rode home on the driver's back as one. There is now a
builder per evidence id (16 pieces + 8 echoes), each small on purpose — at
gameplay distance these read as a silhouette and a colour, not as detail. All
sixteen were checked side by side on a contact sheet.

### The icons were invisible on the phone

The ground marker and the reveal card both drew an EMOJI. macOS falls back to
its colour-emoji font, so it looked right on the desktop; iOS's default font has
no emoji glyphs and Godot does not reach for the system one, so on device every
marker and every card was blank. Both now show the OBJECT: the marker drops a
small copy of the mesh, and `ItemPreview` renders the mesh live into the card
through a `SubViewport` with its own world. Font-independent, always matches what
is lying in the grass, and needs no art.

### The camera lurched, late

`FIND_PAN_ENABLED` is off. The glance fired after the evidence card closed —
3.6 s after the find — so the camera moved to a spot the player had stopped
thinking about. The permanent light beam already does the spatial-memory job the
pan was there for.

### Economy: earnings roughly tripled

The measured gap was real: all eight chapters at 100% paid **1 548** against a
workshop of 8 160 and a town of 6 250, so a player who bought the Robot and the
Tractor could not reach the 1 200 station across two whole cases. Pickups went
4-8 → 9-16 and per-yard budgets rose with yard size, which lifts the completion
bonus too since the bonus pool is derived from the expected ground haul.

Case 1 at 100% now pays **4 192**. After the Robot and the Tractor (1 100) a
player finishes V1 with ~3 100 — enough for all of tier 1 — and across V1+V2 can
afford the station plus two or three buildings. The split is unchanged: ground
pickups stay the smaller half.

### Ellie is on screen

A MISSING poster sits under the top bar during a search — her face, her name,
"since last night" — and the opening now ends on a fifth card with the same
photo and the reason to start. The word for what happened to the world is still
never used.

`DEV_STARTING_SCRAP` (50 000) seeds a fresh save so systems downstream of the
economy can be exercised without grinding to them; it ships at 0.

### Test suites are all scenes now

`model_check`, `g3_check` and `variant_check` ran through `--script`, where
autoloads register after compilation — with `RestoreBoard` now in the dependency
chain that surfaced as a confusing "Compilation failed" line before a pass. All
eleven suites are scene tests.

## G12.9 — eight device bugs

* **Only the push mower picked money up.** `_ensure_all_mowers()` spawns the
  three mowers that are not in Main.tscn, and it repeated the scene wiring —
  except for `scrap_field` and `scrap_found`. So exactly the one mower that IS
  in the scene worked. Both lines added where the rest of the wiring lives.
* **The blade kept spinning over the hub.** AudioDirector is an autoload and
  outlives the chapter, so the engine has to be handed back: `_exit_tree` stops
  it, and the stop LATCHES — `set_engine_state` restarts a stopped player on its
  own, so without the flag a dying scene's last frame would start it again.
* **The robot crawled** at §7's 2.1 next to a 3.0 push mower. Now 3.2; the §7
  table in `g3_check` records the deviation.
* **The blade's camera turns again.** It was locked in G9.2 to stop the control
  frame drifting mid-drag, but the drift came from reading the LIVE camera yaw
  while the camera chased the blade. Latching the frame at press
  (`pad_camera_yaw`) removes the loop, so rotation and stable controls coexist.
* **The tractor has a bed**, and the haul rides in it — a seated driver cannot
  carry a stack on their back. Plus two spinning cutter discs at the front. The
  first pass put them at z −0.86, inside the existing deck box (z −1.25..−0.35),
  so both were invisible; they sit in front of it now.
* **A home button on the HUD.** Returning to town was one tap inside the pause
  sheet and players reported there was no way out at all.
* **The mower picker uses drawn icons.** It showed an emoji plus a label; on a
  phone the emoji is a blank box that still takes its width, which is why the
  labels looked shoved right. `MowerIcons` paints a small silhouette per machine
  into an ImageTexture at startup — no font, no art file — and the labels are
  centred under them.
* The wallet chip and evidence counter moved left to clear the new home button.

## Yama G12.10 — dört bulgu

* **Blade steering: the camera now freezes for the duration of a gesture.**
  G12.9 latched the control frame at press instead, which is self-consistent but
  the camera kept swinging underneath it, so "right on screen" and "right in the
  frame" drifted further apart the longer a finger was held — exactly the
  reported "stop and re-drag and then it works". `CameraRig.freeze_yaw` holds the
  camera still while `_has_finger`, so the live yaw and the control frame are the
  same number by construction, and the camera swings to the new heading on
  release. `tests/BladeFrame.tscn` measured 1.29 rad (74°) of drift during a
  single held drag before the fix and 0.00 after; a first version of that test
  passed on the old code because it drove north, where the camera had no reason
  to turn — worth remembering when writing the next one.
* **Bigger tractor discs, with teeth.** 0.30 m → 0.46 m, 14 saw teeth angled
  into the spin, a fatter hub. A plain plate at phone size reads as a wheel.
* **A new grass-cut sound.** The old one was a single lowpassed noise burst — a
  flat "shhh". It is now band-passed hiss plus 7-11 randomly scattered stem pops
  plus a short deck thump. Measured band split: 3 % under 500 Hz, 32 % mid,
  45 % in the 2-6 kHz shearing band, 20 % above.
* **Ellie is on the town page**, as a MISSING poster above the neighbours rather
  than a person row — she is not someone you can talk to until she is found.
* **The corkboard scrolls and nothing overlaps.** Eight chapters of two cards
  plus a wrapped note plus the finale do not fit one portrait screen; the notes
  were free-positioned Labels with no collision check at all.
  `tests/BoardLayout.tscn` counted 6 real overlaps before, 0 after. The fix is a
  two-pass layout (every card placed before any note dodges anything), a note
  solver that tries below-then-above and nine horizontal offsets, and a board
  that is `BOARD_SCALE` screens tall inside a ScrollContainer.
  - Card positions come from `_layout_width`/`_layout_height`, NOT `size`: inside
    a ScrollContainer the control has no size when `refresh()` runs, and deriving
    from a size that grows to fit the notes would move the cards every refresh.
  - `refresh()` uses `remove_child` before `queue_free`. `queue_free` defers to
    the end of the frame, so tabbing in and out in one frame laid a second set of
    cards over the first.

* **Corkboard cards show the evidence mesh, not an emoji.** Same iOS blank-box
  problem the mower picker had. `ItemPreview` took a `view_size` and a `spin`
  flag so the board can pin sixteen small, still, render-once previews; a card
  that has not been found keeps a plain "?". `show_item` now queues the request
  when the node is not in the tree yet — the board builds a whole card and adds
  it afterwards, so `_ready` had not run and the first version threw 32 nulls.
* **The completion screen followed.** The evidence strip and the case-notes
  list drew the same emoji; both now render the object. `_collected` entries
  carry an `id` so the screen can build the mesh. Slots are 200 px wide, since
  at the preview's own 96 px the captions wrapped mid-syllable.
  Still emoji, and still blank on a phone: the top bar's evidence and wallet
  chips (`hud.gd`).

## Sprint G13 — 3D kasaba diyoraması (dikey dilim)

A TRIAL of replacing the hub's 2D collage with a small fixed-camera 3D town.
Three buildings only: Marshal's station, two homes, the watchtower. If the
slice is rejected, `GameConfig.hub_mode = "legacy"` puts the collage back — the
legacy path is still wired, and `tests/DioramaCheck.tscn` asserts it builds a
hub with no diorama in it and that `set_diorama_active` is safe to call there.

| Piece | Where |
| --- | --- |
| Scene | `scenes/TownDiorama.tscn` → `scripts/town_diorama.gd` |
| Tuning | `GameConfig` `DIORAMA_*`, `RESTORE_*` |
| Hub host | `hub_screen.gd` `_build_diorama_background`, `_play_restore_scene` |
| Tests | `tests/DioramaCheck.tscn` |
| Frames | `docs/g13/` — ruined vs restored, and the five transition beats |

**Framing was the hard part, and it is a portrait-screen problem.** Godot
measures `fov` VERTICALLY. At 1170x2532 a 42-degree vertical fov leaves about a
20-degree horizontal window, so the two side buildings sat completely outside
the frame while the measurements all looked correct. Two fixes together:
`camera.keep_aspect = KEEP_WIDTH` makes the angle horizontal, and the plate is
17x23 — NARROW AND DEEP, turned to face the phone. Laid the other way (24x16)
it filled the width and left two thirds of the screen empty.

`camera.v_offset` shifts the model up into the half the hub's cards do not
cover. It is a frustum shift, not a rotation: turning the camera up would tilt
the model off its plate. The restore close-up tweens it back to 0, or the
building it flew to ends up off the top of the screen.

**The transition** (`play_restore`): push in along the camera's OWN view line
(going in along the line from the square outward swung round behind whichever
building sat on that side), the ruin sinks and flattens with a dust puff, then
the restored parts fall from 2.8 m — sorted by resting height, so it reads as
construction rather than collapse in reverse — each with a tick and a puff, then
a warm light blooms inside and fades. A tap anywhere skips; `skip()` is checked
between every step, and the test asserts a skipped transition still leaves the
building standing with no part left in the air.

* The parts are the restored form's TOP-LEVEL children; anything nested deeper
  rides along with its parent instead of landing on its own.
* The flash is an OmniLight3D inside the building, not a tint: the materials in
  `_mats` are shared with every other building.
* `_drop_part` is started with `.call(...)`, not awaited — the parts have to
  overlap, and a coroutine cannot be called bare.

**Performance.** 40 visible meshes / 1266 triangles ruined, 67 / 1806 fully
restored — far under the yard. The SubViewport draws every other frame (30 fps
behind menus), and `set_diorama_active(false)` disables it entirely while a
chapter is playing: `root.gd` only HIDES the hub, so without that the town
would keep rendering behind the yard.

### G13.1 — the yard's quality recipe, applied

The first slice was small, empty, untextured and dead. Every part of the yard's
recipe now runs in the diorama too.

| | before | after |
| --- | --- | --- |
| Plate | 17x23, flat plane, one albedo colour | 26x34, `lawn_ground.gdshader` + `grass_normal` + a noise tint texture |
| Grass | none | `TuftField.cluster_mesh` MultiMesh, ~600 clumps, `grass_clump.gdshader` wind |
| Buildings | flat colours | `siding_albedo`, `roof_shingles_albedo`, `wood_albedo`, layered windows, ivy on the ruins |
| Light | flat ambient colour | sky as ambient AND reflection source, warm sun, soft shadows, fog, screen overlay |
| Life | nothing | swaying crowns and washing, flickering lanterns, chimney smoke, birds crossing |
| Edges | bare ground into fog | tree clusters, hedges, and a `Horizon` ring of hills and rooftops |
| Draws / triangles | 40 / 1.3k | 432 / 19k — the yard measures 580 / 30k |

Things that had to be measured rather than guessed:

* **`grass_albedo` is a GREYSCALE pattern**, tinted by `lawn_ground.gdshader`.
  Used as a StandardMaterial albedo it renders grey. The diorama runs the same
  shader, and its `cell_tint` texture carries the COLOUR, not just brightness —
  a tint of pale greys left the plate white.
* **Unshaded meshes bypass the tonemapper.** The horizon hills had to be
  authored much darker than they should look; at "correct" values they came out
  near-white and read as snowfields standing over the town.
* **Fog at 30/58 reached the middle of the plate.** It is 52/96 now, so only the
  far rim dissolves, and `fog_sky_affect` is 0.15 or the sky is fog too.
* **Clearing only the clumps TAGGED to a plot was invisible.** The open-field
  grass around a finished house kept it looking abandoned, so anything inside
  the overgrowth radius is cleared.
* No SDFGI and no SSAO: broken on the mobile renderer. Every contact shadow here
  is a painted AO blob, same as the yard.

**`Horizon` runs in every yard too** (`environment_builder.gd`), not just the
hub — distant hills and rooftops at `GameConfig.HORIZON_RADIUS`, so no chapter
ends at a blank wall of fog.

`docs/g13/yard_reference.jpg` and `docs/g13/hub_diorama.jpg` are the two scenes
shot the same way, for judging the gap.

### G13.2 — the frozen hub after a purchase

Buying the station left the hub unresponsive. `_play_restore_scene` fades every
visible page out, waits for the four-second animation, then fades them back —
but `_apply_restore_layers` queue_frees the `Restore_*` badges the instant a
project is bought, so by the time the animation ended those nodes were gone.
The cast threw, `skipper.queue_free()` on the next line never ran, and a
full-screen invisible Button stayed over the hub swallowing every touch.

* **`is_instance_valid` has to come BEFORE the cast.** Casting a freed object
  throws in GDScript, so a guard written after the cast never runs. The first
  fix put the guard after `as Node` and still threw. The same trap was live in
  `town_diorama.gd`'s `_life` loops; those are guarded now too.
* The skip button is removed FIRST and unconditionally, so no later failure can
  leave the hub covered.
* `Restore_*` badges are skipped when collecting pages — they are rebuilt on
  every purchase, so fading them was pointless and holding them was the bug.
* `tests/DioramaCheck.tscn` reproduces it: it frees a visible page mid-animation
  and asserts no blocking button survives and no page is left faded. Without the
  fix it reports 1 blocking button and 6 faded pages.

### G13.5 — all ten restore projects are physical

(Named G13.5, not G13.3: that number is already taken above by the device
console pass.)

The slice's other seven projects now exist on the plate, each with a ruined and
a restored form, each rebuilt through the same Tween transition. A locked
project shows its RUIN rather than an empty lot, so the player can see what the
money buys before Tier 2 opens.

| Project | Ruined | Restored |
| --- | --- | --- |
| swing | bare limb, one frayed rope | ropes, seat, the case's yellow ribbon; Ellie rides it once the case is closed |
| lantern | snapped post in the grass | iron post, warm lamp, an additive light pool on the paving |
| greenhouse | leaning frame, three panes left | new and salvaged glass mixed, seedling beds read through it |
| clinic | boarded door, collapsed veranda | red cross sign, level veranda, supply crates |
| mast | lattice on its side | standing lattice, slow red beacon, hut, sagging cable |
| farm | weeded beds, fence half down | worked rows, stone well, scarecrow |
| barn | half the roof in the loft | patched panel, X-braced door, hay bales, cat asleep on top |

* **Figures.** The brief referred to "the existing cat figure" and Sarah's
  "second stop" — there were no figures at all, so Sarah, Gus, a farmer and the
  cat are new. Each appears only when the project that brings them back is
  built. They walk a two-point line with scissoring legs; there is no navmesh.
* **Peek.** Holding a restore card for `DIORAMA_PEEK_HOLD` leans the camera at
  that plot and back, before any money moves. It refuses while a rebuild plays.
* **Plate 26x34 -> 36x46.** Ten buildings on the old plate stood shoulder to
  shoulder, with the greenhouse inside the barn.
* **The swing needed its own scale.** Every plot is scaled by
  `DIORAMA_BUILDING_SCALE`, but the oak is not — at 1.55 the ropes hung in open
  air beside the tree. Its config entry carries `"scale": 1.0`.
* The clinic cross was authored BEHIND its own sign board (smaller z is further
  back), and `_life` re-places the camera every frame, so the shot script has to
  call `set_process(false)` or every frame comes out at the hub framing.

**Performance, reported as the brief asks — and it is over budget.** 666 draws /
28.7k triangles ruined, **752 draws / 31.3k restored**, against the yard's
580 / 30k. G13 kept the diorama under the yard; ten buildings does not. It still
draws only every other frame and stops entirely during a chapter, but the draw
count is the number to watch on a real device.

Frames: `docs/g13/p_<project>_0ruin.jpg` and `_1built.jpg` for all ten, plus
`docs/g13/hero.jpg`.

### G13.6 — baking the static diorama

752 mesh draws down to 226. `MeshBake` welds a subtree's MeshInstance3Ds into
one mesh per material: the authoring style stays primitives-in-code, and the
runtime cost is paid once at build time.

Measured before touching anything, which is what decided the plan: edge trees
240 draws, bushes 132, horizon 88, farm 72. Trees bake per tree and the whole
tree now leans instead of just its crown — at this distance the same picture
for a tenth of the draws. Bushes bake as one group, since they never move.

Never baked: figures, birds, washing, the swing, the reclaimed weed band, and a
restored building DURING its rebuild — the transition tweens each part. Ruined
forms bake immediately (they sink as one node); restored forms when their
animation ends. Baking is one-way.

`GameConfig.PERF_LOG` prints draws, triangles and fps on hub entry. On desktop
that reads `cizim=334` for the whole screen, UI and shadow passes included.

`surface_get_primitive_type` only exists on ArrayMesh — asking a CylinderMesh
for it throws.

### G13.4 — mowing / case / town

Three links between systems that already existed. Theme: *every lawn you clear,
the town breathes a little easier.*

**Mowing → town.** A band of tall weeds rings the diorama and retreats one of
eight steps per finished chapter. It is its own MultiMesh, deliberately outside
the G13.6 bake, and retreating rewrites the transform list rather than
rebuilding it. Returning to the hub plays the step: the doomed clumps lie down
over 1.5 s, staggered by depth so the fall sweeps outward. The hub bar carries
`TOWN RECLAIMED {percent}` — tied to CHAPTERS, not to money, because this is
the measure of work. Each chapter's case notes gain one line from
`reclaim_line` in `data/levels.json`.

**Town → case.** Building the clinic gives every found corkboard card a second
line of Dr. Cole's reading of the object (`cole_note` per evidence def, sixteen
of them). The watchtower gives the Marshal his line about the east road. The
three projects that serve the case carry a `SERVES THE CASE` badge.

* The taller cards broke the corkboard layout — `tests/BoardLayout.tscn` caught
  two overlaps, and `BOARD_SCALE` went 2.0 → 2.3. Curiously 2.6 fails again:
  more room changes which candidate the note solver settles on.

**Case → mowing.** At 30 % and 60 % of a lawn the Marshal says one line over
the radio and the cells AROUND a still-buried find take the faintest warm tint.
It names a region, never the cell, and the find's own cell is skipped — the
difference between a hint and a waypoint. `GameConfig.hint_moments` switches it
off. `tests/ScentCheck.tscn` asserts both fire, that every region line is
translated, and that off means off.

* Evidence only becomes a node once its cell is mown, so the MODEL is what
  knows where the finds are; the first version looked for spawned props and
  would have found none.

**Text pass.** `RESTORE_POOR` said "Come back richer", pointing at money where
the theme points at work; it now says "Go clear another lawn." No other string
contradicted the theme. New keys: `HUB_RECLAIMED`, `RECLAIM_CH01`–`CH08`,
`HUB_TOWER_LINE`, `RESTORE_CASE_BADGE`, `SCENT_*`, `COLE_*` — en and tr.

Frames: `docs/g134/`.

### G13.7 — four things the device showed

* **A giant swing pasted over the screen.** `_apply_restore_layers` adds a 2D
  picture of each finished building to the hub — that is the LEGACY collage's
  mechanism, and in diorama mode the town is already built in 3D, so every
  purchase stuck a full-screen picture in front of it. It now returns early
  unless `hub_mode` is legacy.
* **Black blotches on the buildings.** The AO blobs are transparent quads;
  welding them into one mesh threw away their per-quad depth sorting. They
  carry a `no_bake` meta now and `MeshBake` skips them. Everything else in a
  plot still welds.
* **The grass flashed overgrown on entry.** `_build_tufts` wrote every clump,
  then `refresh_state` immediately dropped the ones on cleared plots. The first
  write is gone; `refresh_state` does it once, with the cleared plots known.
* **Long rebuilds, the greenhouse worst.** `RESTORE_PART_GAP` was a fixed 0.15 s
  per part, so a thirty-part building took five seconds. It is a CEILING now,
  with `RESTORE_RAISE_SECONDS` spreading however many parts there are across a
  fixed span. Measured after: lantern 3.1 s, greenhouse 3.3, farm 3.3,
  station 3.4 — all inside the brief's 3-4 s.

A building is also welded when its rebuild animation ends, which the first bake
pass missed: a purchase now reports a second, smaller saving.

**Not in the slice.** The other seven projects — swing, lantern, greenhouse,
clinic, mast, farm, barn — have no building in the scene yet. Adding one is a
`DIORAMA_BUILDINGS` entry plus a ruined/restored builder pair; nothing else.
The dead oak in the square is where the swing will hang.

### G13.3 — device console

From a session on an A16 device. Most of that log is Godot's own Metal shader
chatter (`unused variable`, `uninitialized`) and is not ours.

* **Empty Info.plist usage strings.** Xcode flagged
  `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription` and
  `NSCameraUsageDescription` as empty. The game asks for none of them, but Godot
  writes the keys into Info.plist whether or not they have a value, and an empty
  string is invalid — App Store Connect rejects it. They now carry a truthful
  sentence in `export_presets.cfg`.
* **The blade note on every launch.** `_ensure_all_mowers` printed a line for
  the blade every time. The blade has no `.tscn` — it is built in code — so it
  is ALWAYS spawned there and that is expected. The other three do have scenes,
  so those are still reported, now as `push_warning`.
* **`Could not vibrate using haptic engine`.** Godot's own iOS message, from
  `Input.vibrate_handheld`. Our pulses were 10 ms and 25 ms, which came from the
  desktop-era brief; CoreHaptics does nothing useful with a pulse that short, so
  they are 20/40 ms now. NOT confirmed as the cause — the same message also
  appears when the device has System Haptics turned off or Low Power Mode on.
* `mouse_get_position(): Mouse is not supported` is Godot's own UI code, not a
  call of ours; `fopen failed for data file` and the CoreMotion plist warning
  are engine/system noise.

### G13.4 — the leaks at exit

Two orphans, both mine, both from G13:

* `_build_diorama_background` created a `shade` ColorRect, configured it, and
  never added it to the tree — the wash beside it became a TextureRect and the
  ColorRect was left behind. That is one leaked CanvasItem plus its objects,
  every time a hub is built.
* `_on_diorama_building` called `_on_tile(id, false, Button.new())` for a
  throwaway button that `_on_tile` only uses to shake a LOCKED tile. The
  parameter now defaults to null.
* `_dust` built a ParticleProcessMaterial, a QuadMesh and a StandardMaterial3D
  on every call — a dozen per restore, and a fresh particle shader variant each
  time. Both are built once and shared now; per-puff size is the NODE's scale.

Verified with `--verbose`, which names the leaked instances. After the fix both
`tests/DioramaCheck.tscn` and a full purchase run report nothing leaked.

**A tooling lesson, not a game one:** the first attempt at the `_dust` change
used `s[s.index(A):s.index(B)]` to slice out the old function, with B occurring
BEFORE A in the file. That yields an empty string, and `str.replace(, new)`
inserts `new` between every character — it turned a 52 KB script into 90 MB.
Slice bounds have to be ordered, or the edit made with a tool that verifies the
match.

## Not in G1-G9

Nothing major — every REFERENCE.md system through §12 is in. Remaining polish
lives in future briefs.
