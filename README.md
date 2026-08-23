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

## Not in G1-G6.11

Nothing major — every REFERENCE.md system through §12 is in. Remaining polish
lives in future briefs.
