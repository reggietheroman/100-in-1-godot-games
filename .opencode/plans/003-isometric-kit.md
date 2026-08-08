# Isometric Kit — 3D Systems Addon

Reusable 3D systems for isometric-style games, packaged as the `addons/isometric_kit`
addon and exercised by playable sandboxes in `scenes/sandbox/`.

## Goals

1. Control a 3D player on an isometric plane (WASD on desktop, floating joystick on mobile), with dev-mode configurable speed.
2. Spawn enemy units from a configurable spawn point toward a rally point, in configurable waves.
3. Designate map areas with enter/exit triggers for the player and enemy units.
4. Grid-based map planes (checkerboard default), 1-unit tiles shared by map, player, and enemies.
5. Player and enemies share the same model, differentiated by color (blue = player, red = enemy).

## Addon components (`addons/isometric_kit/`)

All components are driven by exported vars so each scene can tune behavior for dev mode.

- `scripts/player_controller.gd` — `CharacterBody3D`, camera-relative WASD + optional joystick. Exports `move_speed`, `acceleration`, `body_color`, `joystick`. Grouped `player`.
- `scripts/enemy_mover.gd` — `CharacterBody3D` that walks to `target` and idles. Exports `move_speed`, `body_color`, `stop_distance`. Grouped `enemy`, emits `reached_rally_point`.
- `scripts/enemy_spawner.gd` — `Node3D` wave spawner. Exports `enemy_scene`, `spawn_point`, `rally_point`, `wave_size`, `wave_interval`, `auto_start`. Emits `wave_spawned(wave, count)` and `all_enemies_reached_rally`.
- `scripts/trigger_area.gd` — `Area3D` with `player_entered/exited` and `enemy_entered/exited` signals. Exports `area_size`, `track_player`, `track_enemies`.
- `scripts/grid_map.gd` — checkerboard `Node3D` built from `width`/`depth`/`tile_size`/`tile_height`/colors. `build()` regenerates tiles. Supports walls via `set_wall(x, z, height)`/`clear_walls()`/`is_wall(x, z)` (stored in `walls`, built as `StaticBody3D` boxes grouped `wall`, `wall_color`). `get_world_size()` used by the camera.
- `scripts/isometric_camera.gd` — orthographic `Camera3D`, auto-fits to the `map`, exports `angle`/`yaw`/`distance`. `fit_size` overrides the fitted world size (used to view a fixed play area).
- `scripts/joystick.gd` — floating touch joystick `Control`. Exports `radius`, `knob_radius`, `visible_on_desktop`.
- `scripts/projectile.gd` — `Area3D` projectile. Moves along `direction` at `speed`, frees after `lifetime`, emits `hit(enemy)` when it collides with a `enemy`-group body; despawns on `wall`-group bodies.
- `scenes/projectile.tscn` — `Area3D` + sphere mesh/collision.

## Sandboxes (`scenes/sandbox/`)

Each sandbox scene is a `Node3D` with exported dev config applied in `_ready()`, plus an
isometric camera and on-screen hint labels.

- `player_sandbox.tscn` — player movement, tune `player_move_speed`.
- `spawner_sandbox.tscn` — enemy waves, tune `spawn_point`/`rally_point`/`wave_size`/`wave_interval`.
- `trigger_sandbox.tscn` — three trigger zones logging player/enemy enter/exit events.
- `combined_sandbox.tscn` — player + trigger zones + configurable wave spawner + shooting all together. Configure spawn/rally points (click to place), wave count, and enemies per wave via the panel (1–5, then ∞); Start Waves, then shoot with Space/Fire (auto-fire and fire rate controls included). In ∞ mode the spawner ramps from 1 enemy per wave, +1 every N waves (configurable). Shots kill enemies permanently; waves refill the field.
- `shooting_sandbox.tscn` — player shoots projectiles toward the nearest enemy; collisions remove the enemy and respawn one. Space / Fire button, auto-fire toggle, and adjustable fire rate (0.1–3.0s). The map is built to fill the whole camera POV (footprint computed from the camera frustum) and boundary walls trace the POV edge, keeping player/enemies on screen and blocking projectiles.

All sandboxes are reachable from the main menu under "Dev Sandboxes".

## Input

`move_left/right/up/down` actions (WASD + arrow keys) and `shoot` (Space) are defined in `project.godot` and
shared by all games/sandboxes.
