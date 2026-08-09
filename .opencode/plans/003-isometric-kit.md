# Isometric Kit — 3D Systems Addon

Reusable 3D systems for isometric-style games, packaged as the `addons/isometric_kit`
addon and exercised by playable sandboxes in `scenes/sandbox/`.

## Goals

1. Control a 3D player on an isometric plane (WASD on desktop, floating joystick on mobile), with dev-mode configurable speed.
2. Spawn enemy units from a configurable spawn point toward a rally point, in configurable waves.
3. Designate map areas with enter/exit triggers for the player and enemy units.
4. Grid-based map planes (checkerboard default), 1-unit tiles shared by map, player, and enemies.
5. Player and enemies share the same model, differentiated by color (blue = player, red = enemy).
6. Shooting: fire projectiles at the nearest enemy (Space/Fire, auto-fire, adjustable rate); projectiles are blocked by walls.
7. Maps fill the camera's visible ground footprint, with boundary walls tracing the POV edge so everything stays on screen.
8. Loot: enemies drop a collectible item on death (`enemy_mover.die()`); items support auto-pickup on contact and key-based pickup, with optional despawn timers. Shot enemies drop loot in the combined sandbox, and the player collects it (counter in the HUD).
9. Currency: a wallet on the player accumulates currency from loot pickups; banks (deposit pads) on the map drain the wallet up to a per-pad capacity while the player stands on them (or on an activation action), showing a running `{name} deposited/capacity` label. The currency sandbox wires the full loop (waves → loot → wallet → banks of 10/25/50).

## Addon components (`addons/isometric_kit/`)

All components are driven by exported vars so each scene can tune behavior for dev mode.

- `scripts/player_controller.gd` — `CharacterBody3D`, camera-relative WASD + optional joystick. Exports `move_speed`, `acceleration`, `body_color`, `joystick`. Grouped `player`.
- `scripts/enemy_mover.gd` — `CharacterBody3D` that walks to `target` and idles. Exports `move_speed`, `body_color`, `stop_distance`. Grouped `enemy`, emits `reached_rally_point`.
- `scripts/enemy_spawner.gd` — `Node3D` wave spawner. Exports `enemy_scene`, `spawn_point`, `rally_point`, `wave_size`, `wave_interval`, `max_waves`, `auto_start`. Optional per-wave growth via `ramp_enabled`/`ramp_start`/`ramp_every`: wave size = `ramp_start + (wave_number - 1) / ramp_every`. Emits `wave_spawned(wave, count)`, `all_enemies_reached_rally`, `waves_finished`.
- `scripts/trigger_area.gd` — `Area3D` with `player_entered/exited` and `enemy_entered/exited` signals. Exports `area_size`, `track_player`, `track_enemies`.
- `scripts/grid_map.gd` — checkerboard `Node3D` built from `width`/`depth`/`tile_size`/`tile_height`/colors. `build()` regenerates tiles. Supports walls via `set_wall(x, z, height)`/`clear_walls()`/`is_wall(x, z)` (stored in `walls`, built as `StaticBody3D` boxes grouped `wall`, `wall_color`). `get_world_size()` used by the camera.
- `scripts/isometric_camera.gd` — orthographic `Camera3D`, `setup()` applies ortho projection and positions the camera; exports `map`, `angle`/`yaw`, `fit_size` (overrides the fitted world size for a fixed play area). `distance` is clamped to `max(size * 0.9, fitted_world * 0.9)` so the frustum bottom stays above the ground plane (avoids a clear-color band at the bottom of the view); the ortho image is distance-invariant, so this only affects near-plane clipping.
- `scripts/visible_footprint.gd` — `class_name VisibleFootprint`, static helpers (`configure_map`, `ground_footprint`, `inside`, `tile_center`, `is_boundary_wall`) that size a grid to the camera's visible ground footprint and mark boundary walls around it. `camera.size` is the *full* ortho frustum height in Godot 4, so the true half-height is `size / 2`.
- `scripts/joystick.gd` — floating touch joystick `Control`. Exports `radius`, `knob_radius`, `visible_on_desktop`.
- `scripts/projectile.gd` — `Area3D` projectile. Moves along `direction` at `speed`, frees after `lifetime`, emits `hit(enemy)` when it collides with a `enemy`-group body; despawns on `wall`-group bodies.
- `scripts/loot_item.gd` — `Area3D` collectible. Exports `pickup_mode` (`Auto` collect on contact / `Key` requires the `pickup` action), `despawn_time`, `pickup_sound`, `pickup_particles`. Grouped `loot`, emits `picked_up(item, collector)`.
- `scripts/loot_drop.gd` — `class_name LootDrop`, static helper `drop(item_scene, pos)` that places a loot scene on the ground.
- `scripts/enemy_mover.gd` — additionally exports `loot_scene` (what the enemy drops) and `die()` drops it via `LootDrop` then frees the enemy.
- `scenes/projectile.tscn` — `Area3D` + sphere mesh/collision.
- `scenes/loot_item.tscn` — `Area3D` + gem mesh/collision; defaults to `Auto` pickup.
- `scripts/currency_wallet.gd` — `Node3D` that tracks a currency balance. Exports `currency` (starting amount); `add_currency(n)` credits, `spend_currency(n)` clamps to the balance and returns what was spent. Emits `currency_changed(amount)`. Grouped `wallet`.
- `scripts/currency_deposit.gd` — `Area3D` deposit pad. Exports `capacity`, `display_name`, `area_size`, `auto_activate` (default true: drains while the player stands on it; otherwise requires `activation_action`), `activation_action` (default `pickup`/E), `transfer_amount`/`transfer_interval` (per-tick size and spacing), `show_transfer_visuals` (flying coin per tick), pad colors. Drains the nearest `wallet` up to capacity in animated ticks (counts tick up/down instead of jumping); shows `{display_name} deposited/capacity` on a `Label3D`. Grouped `deposit`, emits `deposited_changed(deposited, capacity)`.
- `scenes/currency_deposit.tscn` — `Area3D` + pad mesh/collision + floating `Label3D`.
- `scenes/transfer_coin.tscn` — flat gold disc (CylinderMesh) that arcs up from above the player to the pad with a tumble on each transfer tick.

## Sandboxes (`scenes/sandbox/`)

Each sandbox scene is a `Node3D` with exported dev config applied in `_ready()`, plus an
isometric camera and on-screen hint labels.

- `player_sandbox.tscn` — player movement, tune `player_move_speed`.
- `spawner_sandbox.tscn` — enemy waves, tune `spawn_point`/`rally_point`/`wave_size`/`wave_interval`.
- `trigger_sandbox.tscn` — three trigger zones logging player/enemy enter/exit events.
- `combined_sandbox.tscn` — player + trigger zones + configurable wave spawner + shooting + loot all together. Configure spawn/rally points (click to place), wave count, and enemies per wave via the panel (1–5, then ∞); Start Waves, then shoot with Space/Fire (auto-fire and fire rate controls included). In ∞ mode the spawner ramps from 1 enemy per wave, +1 every N waves (configurable). Shots kill enemies permanently and drop loot the player collects (Loot counter in the HUD); waves refill the field.
- `shooting_sandbox.tscn` — player shoots projectiles toward the nearest enemy; collisions remove the enemy and respawn one. Space / Fire button, auto-fire toggle, and adjustable fire rate (0.1–3.0s). The map is built to fill the whole camera POV (footprint computed from the camera frustum) and boundary walls trace the POV edge, keeping player/enemies on screen and blocking projectiles.
- `pickup_sandbox.tscn` — loot items scattered on the map: collect on contact (`Auto`) and on key press (`Key`).
- `loot_spawn_sandbox.tscn` — spawn a pile of loot on click (LootDrop static helper).
- `loot_drop_sandbox.tscn` — player shoots enemies, each drops a loot item; pickup counter in the HUD.
- `currency_sandbox.tscn` — the full currency loop: wave enemies spawn and rally to a nearby point; killed enemies drop loot that becomes currency on pickup (wallet on the player); three banks with capacities 10/25/50 auto-drain the wallet while you stand on them (on-pad labels show `Bank d/c`). Kill via click or Space/Fire.

All sandboxes are reachable from the main menu via the "Dev Sandboxes" button (scenes/menu/sandbox_menu.tscn).

## Tests

Headless unit tests in `addons/isometric_kit/tests/test_main.gd` (90 checks) cover grid
geometry/walls, footprint math, camera setup, spawner wave counts/ramp/restart, enemy
reaching, trigger zones, projectile despawn, joystick vectors, player movement, loot
drops/pickups, and currency wallet/deposit caps.
Run with:

```
godot --headless --path . --script addons/isometric_kit/tests/test_main.gd
```

Notes for the test harness: await a `process_frame` before instancing scene nodes (nodes
added before the first frame never enter the tree), and use real-time waits (`create_timer`
/ msec-capped `await process_frame` loops) instead of fixed physics-frame counts since
headless timing varies.

## Input

`move_left/right/up/down` actions (WASD + arrow keys), `shoot` (Space), and `pickup` (E) are defined in `project.godot` and
shared by all games/sandboxes.
