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
| `textures/grass_blade_tuft.png` 512 | 22 tapered blades, dark green root to lighter tip |
| `audio/mower_engine_loop.wav` 1.00 s | 85 Hz + 6 harmonics at 1/k, 10% AM at 13 Hz, tanh saturation — seamless (85 and 13 both close in 1 s) |
| `audio/grass_cut.wav` 0.16 s | white noise, one-pole lowpass sweeping 2800 → 500 Hz, fast attack + exponential decay |
| `audio/discovery_chime.wav` 0.70 s | E6 then B6 after 0.12 s, exponential decay |

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

## Not in G1

Tractor, robot, driver character, pool art, neighbourhood (house/road/trees/
fence/cars), secret discovery flow, clipping particles, clouds. These come in
later sprints, in the order the sprint briefs arrive.
