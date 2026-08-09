# Clanker Slop 100 in 1

Godot 4.7 project — collection of 5 mini-games.

## Project structure

```
scenes/
├── menu/          — main menu (games + dev sandboxes)
├── sandbox/       — playable 3D dev sandboxes
└── games/
    ├── zombie_math/
    ├── sands_of_hanoi/   — fully implemented
    ├── snow_survival/   — clone of Pizza Ready
    ├── pin_puzzles/
    └── throne_defender/  — clone of Thronefall
addons/isometric_kit/   — reusable 3D systems addon
.opencode/plans/   — stored plans and proposals
```

Each mini-game has a `title.tscn/gd` (title screen with Start/Back buttons) and a `game.tscn/gd`. `sands_of_hanoi` is the only game fully implemented so far; the other four `game.tscn/gd` files are placeholders.

## 3D systems addon (`addons/isometric_kit`)

Reusable 3D components driven by exported vars; sandboxes in `scenes/sandbox/` exercise each one.

- **Player controller** (`scripts/player_controller.gd`): `CharacterBody3D`, camera-relative WASD + touch joystick, exports `move_speed`/`acceleration`. Grouped `player`.
- **Enemy mover** (`scripts/enemy_mover.gd`): `CharacterBody3D` that walks to a `target` and idles. Grouped `enemy`, emits `reached_rally_point`.
- **Enemy spawner** (`scripts/enemy_spawner.gd`): wave spawner with `spawn_point`, `rally_point`, `wave_size`, `wave_interval`, `max_waves`. Optional per-wave growth via `ramp_enabled`/`ramp_start`/`ramp_every`: wave size = `ramp_start + (wave_number - 1) / ramp_every`. Signals `wave_spawned`, `all_enemies_reached_rally`, `waves_finished`.
- **Trigger area** (`scripts/trigger_area.gd`): `Area3D` with `player_entered/exited` + `enemy_entered/exited` signals, `area_size`, `track_player`/`track_enemies`.
- **Grid map** (`scripts/grid_map.gd`): checkerboard plane via `width`/`depth`/`tile_size`/colors; player/enemies use the same 1-unit tile size. Walls via `set_wall(x, z, height)`/`clear_walls()`/`is_wall(x, z)`; built as static boxes grouped `wall`.
- **Visible footprint** (`scripts/visible_footprint.gd`): static helpers (`configure_map`, `ground_footprint`, `inside`, `is_boundary_wall`) that size a grid to the camera's visible ground footprint and mark boundary walls around it. `camera.size` is the *full* ortho frustum height, so the half-height is `size / 2`.
- **Isometric camera** (`scripts/isometric_camera.gd`): orthographic camera, `map` ref, `angle`/`yaw`, auto-fits to map; `fit_size` overrides the fitted size. `setup()` computes `distance = max(size * 0.9, fitted_world * 0.9)` so the frustum bottom stays above the ground plane (avoids a clear-color band at the bottom of the view). Ortho image is distance-invariant, so this only affects near-plane clipping.
- **Joystick** (`scripts/joystick.gd`): floating touch joystick (`visible_on_desktop` for testing).
- **Projectile** (`scripts/projectile.gd`): `Area3D` that flies along a `direction` and emits `hit(enemy)` on collision with `enemy`-group bodies; despawns on `wall`-group bodies.

### Sandboxes (`scenes/sandbox/`)

Each is a `Node3D` with exported dev config applied in `_ready()`, an isometric camera, and HUD hint labels. All are reachable from the main menu under "Dev Sandboxes".

- `player_sandbox` — player movement, tune `player_move_speed`.
- `spawner_sandbox` — enemy waves; spawn/rally point click-to-place + wave/enemy count UI.
- `trigger_sandbox` — three trigger zones logging player/enemy enter/exit events.
- `combined_sandbox` — everything together: player, zones, configurable waves (spawn/rally click-to-place, wave count, enemies 1–5 then ∞ ramp), and shooting (Space/Fire, auto-fire, fire rate, hits). Shots kill enemies permanently; waves refill the field.
- `shooting_sandbox` — shooting vs. random enemies (killed enemies respawn); map fills the whole camera POV with boundary walls.

WASD/arrow input actions (`move_left/right/up/down`) and `shoot` (Space) are defined in `project.godot`.

## Architecture

- **Scene navigation**: `get_tree().change_scene_to_file()` between .tscn files
- **Menus**: `Control`-rooted scenes with `VBoxContainer` layout + dark `ColorRect` background
- **Game scenes**: `Node2D` root (swap to `Node3D` per-game as needed)
- **Signal connections**: wired in `_ready()` via `.pressed.connect()`
- **Rendering**: Sands of Hanoi uses custom `_draw()` on the `Node2D` root, with UI (buttons, labels) in a `CanvasLayer` overlay
- **Input**: Sands of Hanoi handles mouse and touch via `_unhandled_input()`

## Conventions

- snake_case for files and directories
- PascalCase for node names
- One scene + one script per screen
- Extend from root node type (Control for UI, Node2D/Node3D for game)
- GDScript: tabs for indentation, class-based helpers as inner classes (`class Bottle:`), constants in `SCREAMING_SNAKE_CASE`

## Game designs

Design specs live in `.opencode/plans/002-game-designs.md`. Keep the plan in sync when implementing a game.

## Settings

- Window stretch: canvas_items (expand)
- Renderer: gl_compatibility
- Physics: Jolt Physics 3D

## Commands

- The `.godot` directory is excluded from version control.
- Run the headless Isometric Kit test suite:

  ```
  godot --headless --path . --script addons/isometric_kit/tests/test_main.gd
  ```

  Expect `tests passed: 61, failed: 0`. Tests must await a `process_frame` before
  instancing scene nodes, since nodes added before the first frame never enter the tree.
