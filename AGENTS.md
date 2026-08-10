# Clanker Slop 100 in 1

Godot 4.7 project — collection of 5 mini-games.

## Project structure

```
scenes/
├── menu/          — main menu (games + "Dev Sandboxes" button), sandbox_menu.tscn lists all sandboxes
├── sandbox/       — playable 3D dev sandboxes
└── games/
    ├── zombie_math/
    ├── sands_of_hanoi/   — fully implemented
    ├── snow_survival/   — clone of Pizza Ready
    ├── pin_puzzles/
    └── throne_defender/  — clone of Thronefall
addons/isometric_kit/   — reusable 3D systems addon
.opencode/plans/   — stored plans and proposals
docs/              — learning docs (architecture, configuration, design decisions)
```

Each mini-game has a `title.tscn/gd` (title screen with Start/Back buttons) and a `game.tscn/gd`. `sands_of_hanoi` is the only game fully implemented so far; the other four `game.tscn/gd` files are placeholders.

## Documentation (docs/)

This project doubles as a learning tool. `docs/` answers "why is it like this?" and "how do I configure X by hand?" — consult it before re-deriving from code.

- `docs/architecture.md` — the "why" document: GDScript OO, data-driven types, composition vs inheritance, duck typing.
- `docs/manual-configuration.md` — every exported var + signal per system and how to tune it by hand. **Keep in sync whenever a system's config/behavior changes.**
- `docs/design-decisions.md` — running log of decisions (newest first) with reasoning. **Append an entry whenever a design decision is made.**

The user often wants the *reasoning* behind code, not just the code — when answering "why" questions or making changes, tie decisions back to these docs.

## 3D systems addon (`addons/isometric_kit`)

Reusable 3D components driven by exported vars; sandboxes in `scenes/sandbox/` exercise each one.

- **Player controller** (`scripts/player_controller.gd`): `CharacterBody3D`, camera-relative WASD + touch joystick, exports `move_speed`/`acceleration`. Grouped `player`.
- **Enemy mover** (`scripts/enemy_mover.gd`): `CharacterBody3D` that walks to a `target` and idles. Has a health pool (`max_health`, default 1 = one-shot): `take_damage(amount)` emits `damaged(amount, health)` and calls `die()` at zero; `die()` is idempotent, drops `loot_scene` once (if set), emits `died(enemy)`, then frees itself. Grouped `enemy`, emits `reached_rally_point`.
- **Enemy spawner** (`scripts/enemy_spawner.gd`): wave spawner with `spawn_point`, `rally_point`, `wave_size`, `wave_interval`, `max_waves`. Optional per-wave growth via `ramp_enabled`/`ramp_start`/`ramp_every`: wave size = `ramp_start + (wave_number - 1) / ramp_every`. Signals `wave_spawned`, `all_enemies_reached_rally`, `waves_finished`.
- **Trigger area** (`scripts/trigger_area.gd`): `Area3D` with `player_entered/exited` + `enemy_entered/exited` signals, `area_size`, `track_player`/`track_enemies`.
- **Grid map** (`scripts/grid_map.gd`): checkerboard plane via `width`/`depth`/`tile_size`/colors; player/enemies use the same 1-unit tile size. Walls via `set_wall(x, z, height)`/`clear_walls()`/`is_wall(x, z)`; built as static boxes grouped `wall`.
- **Visible footprint** (`scripts/visible_footprint.gd`): static helpers (`configure_map`, `ground_footprint`, `inside`, `is_boundary_wall`) that size a grid to the camera's visible ground footprint and mark boundary walls around it. `camera.size` is the *full* ortho frustum height, so the half-height is `size / 2`.
- **Isometric camera** (`scripts/isometric_camera.gd`): orthographic camera, `map` ref, `angle`/`yaw`, auto-fits to map; `fit_size` overrides the fitted size. `setup()` computes `distance = max(size * 0.9, fitted_world * 0.9)` so the frustum bottom stays above the ground plane (avoids a clear-color band at the bottom of the view). Ortho image is distance-invariant, so this only affects near-plane clipping.
- **Joystick** (`scripts/joystick.gd`): floating touch joystick (`visible_on_desktop` for testing).
- **Projectile** (`scripts/projectile.gd`): `Area3D` that flies along a `direction` and emits `hit(enemy)` on collision with `enemy`-group bodies; despawns on `wall`-group bodies. Carries `damage` (default 1) and `splash_radius` (0 = single target; >0 also damages enemies near the impact, excluding the primary). Grouped `projectile`.
- **Loot item** (`scripts/loot_item.gd`): `Node3D` collectible with `pickup_mode` (`Auto` contact / `Key` uses the `pickup` action), `lifetime` (despawn timer, 0 = never), `pickup_radius`, and pickup effects (`show_particle_burst`/`show_floating_label`/`show_fly_anim`). Grouped `loot`, emits `picked_up`. Variant scenes (`loot_coin.tscn`) reuse the script with a different mesh + defaults.
- **Loot drop** (`scripts/loot_drop.gd`): static helper `LootDrop.spawn(loot_scene, at, parent)` that places a loot scene on the ground; `enemy_mover.die()` uses it when `loot_scene` is set.
- **Currency wallet** (`scripts/currency_wallet.gd`): `Node3D` that tracks a currency balance with `add_currency`/`spend_currency`; emits `currency_changed`. Grouped `wallet`.
- **Currency deposit** (`scripts/currency_deposit.gd`): `Area3D` pad with `capacity` and a `Label3D` showing `{display_name} deposited/capacity`. Drains the wallet into the area while the player stands on it (`auto_activate`, default true) or on `activation_action` (default `pickup`/E) when auto is off. Transfers tick (`transfer_amount` units every `transfer_interval` seconds) with a coin arcing up from above the player to the pad, so counts animate instead of jumping; each coin landing bumps the pad and filling up plays a pop + flash + label bump. `paused` freezes transfers until cleared (used by `build_site` for a post-milestone beat). Grouped `deposit`, emits `deposited_changed`. `register_in_group` (default true) lets embedded pads opt out of the group.
- **Build site** (`scripts/build_site.gd`): `Node3D` for a predefined build area. Embeds a `currency_deposit` payment pad (auto-drains the wallet while the player stands on it, reusing the ticked coin-arc transfer). `stages` lists each level's cost paid in sequence (e.g. `[10, 25, 50]` = pay 10 for level 1, then 25 for level 2, then 50 for max); the pad label shows the current stage's progress and resets to `0/{next}` when a stage is paid. Each level-up pops a structure instance onto the spot beside the pad (`structure_offset`) and recolors it (`structure_colors`); the structure is one `structure_scene` instance per level when set (any 3D asset: `.glb`, `.tscn`, ...) or default `BoxMesh` blocks. Every finished stage plays a celebration popup + confetti burst above the structure (`celebration_enabled`); the final stage reads "{display_name} Complete!" and removes the pad, firing `completed`. The pad pauses for a beat after the first level (`first_level_pause`, 0 disables) so the milestone lands before the next stage. Structure, stages, and colors are dev-configured; players only pay by standing on the pad. `tower_scene` + `tower_level_stats` (indexed `level - 1`) instead build ONE functional tower: hidden until its first stage is paid, each paid stage calls its `apply_level()` to upgrade stats. Grouped `build_site`, emits `leveled_up(level)`/`completed`.
- **Tower** (`scripts/tower.gd` + `scenes/tower.tscn`): `Node3D` auto-shooting tower (`Body` + aiming `Turret/Barrel` + `Muzzle`). Finds the nearest live `enemy`-group body within `range` (2D horizontal) and fires `projectile_scene` every `fire_interval` seconds, inheriting `damage` and `splash_radius`. Exports `fire_interval`/`range`/`damage`/`splash_radius`/`projectile_speed`/`projectile_scene`/`enemy_group`/`body_color`/`aim_speed`/`level_stats`/`level_colors`; `apply_level(n, stats)` upgrades stats per level so one scene configures many tower types. Idle (doesn't fire) while `scale == Vector3.ZERO`. Watches each target's `died` once (re-emits `enemy_killed`) and disconnects on exit so freed towers leave no dangling connections. Grouped `tower`, emits `fired(enemy)`/`enemy_killed(enemy)`.
- **Celebration** (`scripts/celebration.gd`): `Node3D` one-shot feedback popup for a win/upgrade moment. `celebrate(text, color)` pops in a billboarded `Label3D` message (scale-in with back ease) that floats up and fades out, plus a `CPUParticles3D` confetti burst in the given color; the node frees itself when done (`rise`/`hold_time` tune it). Used by `build_site` on every level-up.

### Sandboxes (`scenes/sandbox/`)

Each is a `Node3D` with exported dev config applied in `_ready()`, an isometric camera, and HUD hint labels. All are reachable from the main menu via the "Dev Sandboxes" button (scenes/menu/sandbox_menu.tscn).

- `player_sandbox` — player movement, tune `player_move_speed`.
- `spawner_sandbox` — enemy waves; spawn/rally point click-to-place + wave/enemy count UI.
- `trigger_sandbox` — three trigger zones logging player/enemy enter/exit events.
- `combined_sandbox` — everything together: player, four pre-defined Rapid tower build pads, configurable waves (spawn/rally click-to-place, wave count, enemies 1–5 then ∞ ramp), shooting (Space/Fire, auto-fire, fire rate, hits), and loot — shot enemies drop coins worth currency, picked up on contact. Standing on a pad pays currency and builds/upgrades a functional Rapid tower beside it. Shots kill enemies permanently; waves refill the field.
- `shooting_sandbox` — shooting vs. random enemies (killed enemies respawn); map fills the whole camera POV with boundary walls.
- `pickup_sandbox` — loot items scattered on the map: collect on contact (Auto) and on key press (Key).
- `loot_spawn_sandbox` — spawn a pile of loot on click (LootDrop static helper).
- `loot_drop_sandbox` — player shoots enemies, each drops a loot item; pickup counter in the HUD.
- `currency_sandbox` — the currency loop: wave enemies rally to a nearby point; killed enemies drop loot that becomes currency on pickup; three banks (deposit pads, capacities 10/25/50) with on-pad labels auto-drain the wallet while you stand on them.
- `build_sandbox` — building: start with 500 currency; four dev-configured build sites (Outpost `[10, 25, 50]`, Barracks `[15, 35]`, Keep `[20, 40, 80]`, and a "Gatling Tower" site building a functional tower) where standing on a pad pays coins and builds a tower beside it, with a celebration popup + confetti on every level-up, and the pad disappears once a site is fully built.
- `tower_sandbox` — towers vs. waves: Rapid (fast/low damage), Cannon (slow/splash AoE), and Sniper (long range/high damage) auto-shoot enemies walking spawn → rally; Start/Stop Waves button + kills counter.

WASD/arrow input actions (`move_left/right/up/down`), `shoot` (Space), and `pickup` (E) are defined in `project.godot`.

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
- **Documentation**: append to `docs/design-decisions.md` whenever a design decision is made; keep `docs/manual-configuration.md` in sync when a system's exported vars/signals/behavior change (see the Documentation section above).

## Game designs

Design specs live in `.opencode/plans/002-game-designs.md`. Keep the plan in sync when implementing a game.

## Settings

- Window stretch: viewport (expand), base 1280×720
- Renderer: gl_compatibility
- Physics: Jolt Physics 3D

## Commands

- The `.godot` directory is excluded from version control.
- Run the headless Isometric Kit test suite:

  ```
  godot --headless --path . --script addons/isometric_kit/tests/test_main.gd
  ```

  Expect `tests passed: 146, failed: 0`. Tests must await a `process_frame` before
  instancing scene nodes, since nodes added before the first frame never enter the tree.
