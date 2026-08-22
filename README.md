# Under The Lawn

A Godot **4.2+** 3D mobile prototype (built and verified on **4.7.2**): drive a lawn mower with a virtual joystick,
cut a procedurally generated lawn, watch the completion percentage climb, and
uncover the first thing buried under the grass.

## Run it

1. Open Godot 4.2 or newer → **Import** → pick this folder's `project.godot`.
2. Press **F5**. `scenes/Main.tscn` is the main scene.

**Controls**

| Input | Action |
| --- | --- |
| Drag anywhere on the left ~half of the screen | Steer + throttle (dynamic joystick) |
| Arrow keys / gamepad left stick | Same, for desktop testing |
| Reset button (top right) | Restart the lawn |

Mouse dragging works in the editor because `pointing/emulate_touch_from_mouse`
is enabled, so the same touch code path is exercised on desktop.

## How it is built

```
project.godot          mobile renderer, landscape, zero gravity, touch emulation
scenes/Main.tscn       world, sun/sky, lawn, mower, camera rig, UI layer
scenes/Mower.tscn      mower model, collision, clipping + dust particles, engine audio
scripts/lawn_manager.gd  the lawn: grid state, cut mask, ground, grass MultiMesh, hedges
scripts/mower.gd         driving, the cutting sweep, engine/FX/camera feedback
scripts/virtual_joystick.gd  touch stick (class TouchJoystick), drawn with _draw()
scripts/camera_rig.gd    smoothed top-down chase cam with cut shake
scripts/secret_object.gd first secret: buried stone hatch that emerges as grass falls
scripts/engine_audio.gd  runtime engine synth (AudioStreamGenerator)
scripts/sfx.gd           runtime chime/thud generation (AudioStreamWAV)
scripts/hud.gd           completion meter, secret toast, finish banner (built in code)
shaders/lawn_ground.gdshader  uncut/cut ground colour + mown stripes
shaders/grass_blade.gdshader  per-blade cut collapse, wind sway, parting around the mower
```

### The grass tiles

The lawn is a `grid_width × grid_depth` grid of tiles (default 26×26 at 1.2 m =
31.2 m square, 676 tiles). Two things render it:

* **One ground plane** with `lawn_ground.gdshader`.
* **One MultiMesh** of grass clumps (6 clumps/tile × 3 blades = ~12,000 blades),
  shadow casting off.

Tile state lives in a 26×26 `RGBA8` texture, the **cut mask**:

* `R` = cut animation progress, `0` (standing) → `1` (cut)
* `G` = the mow direction captured when that tile was cut

Both shaders sample the mask, so **cutting a tile is one pixel write** — there is
no per-blade CPU work and no per-tile node. `filter_linear` on the mask makes the
boundary between cut and uncut grass soft and organic rather than blocky.

### Uncut → cut transition

`Mower._do_cutting()` hands the lawn an oriented rectangle in front of the deck
each physics tick; `LawnManager.cut_rect()` flips every uncut tile whose centre
falls inside it and pushes it onto a small "animating" list. Only tiles cut in
the last ~0.2 s are updated per frame.

What you see for each tile, all driven by that one mask value:

* Blades **fall over** in the direction of the pass (cubic ease), then shrink to
  stubble (`cut_height`).
* Standing blades **part around the chassis** as it approaches.
* The ground blends from deep, patchy green to bright cut green with **mown
  stripes** whose axis flips with the direction of the pass — back-and-forth
  passes therefore alternate light/dark, like a real lawn.
* A short **fresh-clipping flash** brightens the ground right after the blades pass.
* Clipping and dust **particles** spray up and back off the deck.
* A small **camera shake** scales with how many tiles were cut this tick.

### Completion tracking

`LawnManager` emits `completion_changed(percent, cut_tiles, total_tiles)` on
every change and `lawn_completed` at 100%. The HUD shows a meter, a tile count,
a popping percentage, and a finish banner. Hedge walls are placed so 100% is
actually reachable in every corner.

### Audio

No audio files. `engine_audio.gd` synthesises the engine in `_process()` with an
`AudioStreamGenerator`: a wobbling fundamental (42–96 Hz) plus saw/square/sine
harmonics, intake noise, and a high-passed hiss layer that rises with `cut_load`
so the engine audibly bogs down and shreds while it is actually cutting.
`sfx.gd` generates the secret's chime and a thud into `AudioStreamWAV` buffers at
load time.

### The first secret

`scenes/Main.tscn → Secrets/StoneHatch` is a `SecretObject`: an "Ancient Stone
Hatch" hidden under the grass at `(-7.2, 0, -6.6)`.

`LawnManager` finds every node in the `secret` group, precomputes the tiles
inside its `reveal_radius`, and pushes the cut ratio of that patch to
`set_exposure()`. The hatch fades in and rises out of the soil as its grass is
cut; at `reveal_threshold` (80%) it **pops**: elastic scale, rune ring glow,
omni light, a particle burst, a chime, a camera shake, and a HUD toast.

**Adding another secret:** duplicate the `StoneHatch` node, move it, and set
`display_name` / `reveal_radius`. Anything in the `secret` group implementing
`set_exposure(ratio: float)` is picked up automatically.

## Tuning

| Where | Knob |
| --- | --- |
| `Lawn` node | `grid_width`, `grid_depth`, `tile_size`, `clumps_per_tile`, blade heights, `cut_anim_speed` |
| `Mower` node | `max_speed`, `turn_speed`, `turn_drag`, `cut_width`, `cut_length` |
| `CameraRig` | `height`, `back_offset`, `smoothing`, `max_shake` |
| `Joystick` | `base_radius`, `knob_radius`, `deadzone`, `rest_anchor` |
| Shader uniforms | blade/ground colours, `cut_height`, `cut_lean`, `wind_strength`, `stripe_width` |

Lower `clumps_per_tile` to 3–4 for weaker devices; the shaders themselves are
cheap (no branching per fragment, one texture fetch).

## Verified

Checked against Godot **4.7.2** on macOS:

* `--headless --editor --quit` → no parse errors, all global classes register.
* `--headless --quit-after 150` → no runtime errors; the mower cuts the two
  tiles under its deck at spawn as expected.
* Rendered frame sequences (`--write-movie`) → shaders compile, grass/stripes/
  clippings/HUD all draw, and a scripted drive reached 13% completion.
* Forced reveal → hatch pop, particle burst, omni light, HUD toast all fire.
* Movie-mode WAV output → engine synth is audible at about -22 dBFS RMS,
  peaking near -13 dBFS (no clipping).

Useful while iterating:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 150
```

## Notes / not done

* The joystick class is named `TouchJoystick`, not `VirtualJoystick` — Godot 4.7
  has a native class by the latter name.
* `GPUParticles3D.amount_ratio` is used to scale the clipping spray, which needs
  Godot **4.2+**.
* Single secret only, as asked. No save/load, no scoring, no menus.
* Not tested on a real phone yet: mobile export needs export templates plus the
  Android SDK or Xcode.
