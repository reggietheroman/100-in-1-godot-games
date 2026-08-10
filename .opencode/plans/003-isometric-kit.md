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
8. Loot: enemies drop a collectible item on death (`enemy_mover.die()`); items support auto-pickup on contact and key-based pickup, with optional despawn timers. Shot enemies drop coins in the tower defense sandbox, and the player collects them (coin counter in the HUD; each pickup adds its value to the wallet).
9. Currency: a wallet on the player accumulates currency from loot pickups; banks (deposit pads) on the map drain the wallet up to a per-pad capacity while the player stands on them (or on an activation action), showing a running `{name} deposited/capacity` label. The currency sandbox wires the full loop (waves → loot → wallet → banks of 10/25/50).
10. Towers: auto-shooting defensive structures with configurable fire rate (shooting speed), range (shooting distance), damage per shot, and shot AoE (splash radius). Enemies have health (`enemy_mover.max_health`/`take_damage()`), and projectiles carry `damage` + `splash_radius`. Towers work standalone or as `build_site` structures that upgrade their stats per paid stage.

## Addon components (`addons/isometric_kit/`)

All components are driven by exported vars so each scene can tune behavior for dev mode.

- `scripts/player_controller.gd` — `CharacterBody3D`, camera-relative WASD + optional joystick. Exports `move_speed`, `acceleration`, `body_color`, `joystick`. Grouped `player`.
- `scripts/enemy_mover.gd` — `CharacterBody3D` that walks to `target` and idles. Exports `move_speed`, `body_color`, `stop_distance`, `loot_scene`, `max_health` (default 1 = one-shot). `take_damage(amount)` reduces `health`, emits `damaged(amount, health)`, and calls `die()` at zero; `die()` drops `loot_scene` once (idempotent) and emits `died(enemy)` before freeing itself. Grouped `enemy`, also emits `reached_rally_point`.
- `scripts/enemy_spawner.gd` — `Node3D` wave spawner. Exports `enemy_scene`, `spawn_point`, `rally_point`, `wave_size`, `wave_interval`, `max_waves`, `auto_start`. Optional per-wave growth via `ramp_enabled`/`ramp_start`/`ramp_every`: wave size = `ramp_start + (wave_number - 1) / ramp_every`. Emits `wave_spawned(wave, count)`, `all_enemies_reached_rally`, `waves_finished`.
- `scripts/trigger_area.gd` — `Area3D` with `player_entered/exited` and `enemy_entered/exited` signals. Exports `area_size`, `track_player`, `track_enemies`.
- `scripts/grid_map.gd` — checkerboard `Node3D` built from `width`/`depth`/`tile_size`/`tile_height`/colors. `build()` regenerates tiles. Supports walls via `set_wall(x, z, height)`/`clear_walls()`/`is_wall(x, z)` (stored in `walls`, built as `StaticBody3D` boxes grouped `wall`, `wall_color`). `get_world_size()` used by the camera.
- `scripts/isometric_camera.gd` — orthographic `Camera3D`, `setup()` applies ortho projection and positions the camera; exports `map`, `angle`/`yaw`, `fit_size` (overrides the fitted world size for a fixed play area). `distance` is clamped to `max(size * 0.9, fitted_world * 0.9)` so the frustum bottom stays above the ground plane (avoids a clear-color band at the bottom of the view); the ortho image is distance-invariant, so this only affects near-plane clipping.
- `scripts/visible_footprint.gd` — `class_name VisibleFootprint`, static helpers (`configure_map`, `ground_footprint`, `inside`, `tile_center`, `is_boundary_wall`) that size a grid to the camera's visible ground footprint and mark boundary walls around it. `camera.size` is the *full* ortho frustum height in Godot 4, so the true half-height is `size / 2`.
- `scripts/joystick.gd` — floating touch joystick `Control`. Exports `radius`, `knob_radius`, `visible_on_desktop`.
- `scripts/projectile.gd` — `Area3D` projectile. Moves along `direction` at `speed`, frees after `lifetime`, emits `hit(enemy)` when it collides with a `enemy`-group body; despawns on `wall`-group bodies. Exports `damage` (default 1, applied via the enemy's `take_damage`) and `splash_radius` (0 = single target; when set, also damages other enemies within that radius of the impact, excluding the primary). Grouped `projectile`.
- `scripts/loot_item.gd` — `Area3D` collectible. Exports `pickup_mode` (`Auto` collect on contact / `Key` requires the `pickup` action), `despawn_time`, `pickup_sound`, `pickup_particles`. Grouped `loot`, emits `picked_up(item, collector)`.
- `scripts/loot_drop.gd` — `class_name LootDrop`, static helper `drop(item_scene, pos)` that places a loot scene on the ground.
- `scenes/projectile.tscn` — `Area3D` + sphere mesh/collision.
- `scenes/loot_item.tscn` — `Area3D` + gem mesh/collision; defaults to `Auto` pickup.
- `scenes/loot_coin.tscn` — `loot_item` variant: flat gold cylinder coin named "Coin" (used by the tower defense sandbox so enemy kills drop currency).
- `scripts/currency_wallet.gd` — `Node3D` that tracks a currency balance. Exports `currency` (starting amount); `add_currency(n)` credits, `spend_currency(n)` clamps to the balance and returns what was spent. Emits `currency_changed(amount)`. Grouped `wallet`.
- `scripts/currency_deposit.gd` — `Area3D` deposit pad. Exports `capacity`, `display_name`, `area_size`, `auto_activate` (default true: drains while the player stands on it; otherwise requires `activation_action`), `activation_action` (default `pickup`/E), `transfer_amount`/`transfer_interval` (per-tick size and spacing), `show_transfer_visuals` (flying coin per tick + pad bumps on landing and a pop/flash when full), pad colors, `register_in_group` (default true; set false when embedded in another component). Drains the nearest `wallet` up to capacity in animated ticks (counts tick up/down instead of jumping); shows `{display_name} deposited/capacity` on a `Label3D`. `refresh()` re-applies label + pad tint after external `capacity` changes. `paused` (runtime) freezes transfers until cleared, used by `build_site` for a post-milestone beat. Grouped `deposit`, emits `deposited_changed(deposited, capacity)`.
- `scripts/build_site.gd` — `Node3D` predefined build area. Exports `display_name`, `stages` (each level's cost, paid in sequence; e.g. `[10, 25, 50]` = pay 10 for level 1, then 25, then 50 for max), `payment_area_size`, `structure_offset` (where the structure sits beside the pad), `structure_scene` (optional 3D asset instantiated once per level; falls back to default `BoxMesh` blocks), `structure_colors` (tint per level; empty keeps an asset's own materials), `celebration_enabled` (plays a popup + confetti burst above the structure on every level-up, the final one reading "{display_name} Complete!"), `first_level_pause` (seconds the pad pauses after the first level is collected so the milestone lands; 0 disables), and pass-throughs `auto_activate`/`transfer_amount`/`transfer_interval`/`show_transfer_visuals`. Embeds a `currency_deposit` pad (auto-drains the wallet while the player stands on it); when a stage's amount is paid a structure instance pops in, the structure recolors, a celebration plays, the pad pauses (first level only), and the pad resets to `0/{next}`; once the final stage is paid the pad is freed and `completed` fires. Setting `tower_scene` + `tower_level_stats` instead turns the site into a functional tower: ONE tower instance is built (hidden until its first stage is paid) and each paid stage calls its `apply_level()`, upgrading stats from `tower_level_stats` (indexed `level - 1`; `structure_scene`/`structure_colors` are ignored then). Structure/stages/colors are dev-configured. Grouped `build_site`, emits `leveled_up(level)`/`completed`.
- `scripts/tower.gd` / `scenes/tower.tscn` — auto-shooting tower. `Node3D` (`Tower` scene: `Body` + aiming `Turret/Barrel` + `Muzzle`) that finds the nearest live `enemy`-group body within `range` (2D horizontal) and fires `projectile_scene` from the muzzle every `fire_interval` seconds, inheriting `damage` and `splash_radius` (turret only aims visually; projectiles fly horizontally). Exports `fire_interval`/`range`/`damage`/`splash_radius`/`projectile_speed`/`projectile_scene`/`enemy_group`/`body_color`/`aim_speed`/`level_stats`/`level_colors`. `apply_level(n, stats)` upgrades stats from `level_stats` (or the passed dict) and tints via `level_colors`, so one scene configures many tower types (rapid/cannon/sniper). Hidden when `scale == Vector3.ZERO` (pre-build state). Watches each target's `died` signal once (re-emits as `enemy_killed`) and disconnects on exit so freed towers leave no dangling connections. Emits `fired(enemy)`/`enemy_killed(enemy)`. Grouped `tower`.
- `scenes/currency_deposit.tscn` — `Area3D` + pad mesh/collision + floating `Label3D`.
- `scenes/transfer_coin.tscn` — flat gold disc (CylinderMesh) that arcs up from above the player to the pad with a tumble on each transfer tick.
- `scenes/build_site.tscn` — `Node3D` + embedded `currency_deposit` payment pad (`register_in_group = false`) + foundation slab, with one structure segment per `stages` entry (a `structure_scene` instance or a default box block) created in `_ready`.
- `scripts/celebration.gd` / `scenes/celebration.tscn` — one-shot feedback popup: `celebrate(text, color)` pops in a billboarded `Label3D` message (back-eased scale-in) that floats up and fades out, plus a `CPUParticles3D` confetti burst tinted `color`; the node frees itself when done (`rise`/`hold_time` tune it). Used by `build_site` on every level-up.

## Sandboxes (`scenes/sandbox/`)

Each sandbox scene is a `Node3D` with exported dev config applied in `_ready()`, plus an
isometric camera and on-screen hint labels.

- `player_sandbox.tscn` — player movement, tune `player_move_speed`.
- `spawner_sandbox.tscn` — enemy waves, tune `spawn_point`/`rally_point`/`wave_size`/`wave_interval`.
- `trigger_sandbox.tscn` — three trigger zones logging player/enemy enter/exit events.
- `tower_defense.tscn` — player + configurable wave spawner + shooting + loot + four pre-defined Rapid tower build pads all together. Configure spawn/rally points (click to place), wave count, and enemies per wave via the panel (1–5, then ∞); Start Waves, then shoot with Space/Fire (auto-fire and fire rate controls included). In ∞ mode the spawner ramps from 1 enemy per wave, +1 every N waves (configurable). Shots kill enemies permanently and drop coins worth currency (picked up on contact; wallet starts at 0), which pays the four build pads that build/upgrade functional Rapid towers (stages `[15, 30, 50]`); waves refill the field.
- `shooting_sandbox.tscn` — player shoots projectiles toward the nearest enemy; collisions remove the enemy and respawn one. Space / Fire button, auto-fire toggle, and adjustable fire rate (0.1–3.0s). The map is built to fill the whole camera POV (footprint computed from the camera frustum) and boundary walls trace the POV edge, keeping player/enemies on screen and blocking projectiles.
- `pickup_sandbox.tscn` — loot items scattered on the map: collect on contact (`Auto`) and on key press (`Key`).
- `loot_spawn_sandbox.tscn` — spawn a pile of loot on click (LootDrop static helper).
- `loot_drop_sandbox.tscn` — player shoots enemies, each drops a loot item; pickup counter in the HUD.
- `currency_sandbox.tscn` — the full currency loop: wave enemies spawn and rally to a nearby point; killed enemies drop loot that becomes currency on pickup (wallet on the player); three banks with capacities 10/25/50 auto-drain the wallet while you stand on them (on-pad labels show `Bank d/c`). Kill via click or Space/Fire.
- `build_sandbox.tscn` — the building loop: start with 500 currency; four dev-configured build sites (Outpost `[10, 25, 50]`, Barracks `[15, 35]`, Keep `[20, 40, 80]`, and a "Gatling Tower" site that builds a functional tower upgrading its stats via `tower_level_stats`). Standing on a pad pays coins (ticking coin arcs) and a tower of blocks grows beside it; every level-up fires a celebration popup + confetti, and the pad is removed once a site reaches its final stage.
- `tower_sandbox.tscn` — towers vs. enemy waves: three pre-configured towers (Rapid — fast, low damage; Cannon — slow, splash AoE; Sniper — long range, high damage) auto-shoot waves of enemies that walk from the spawn point to the rally point. Start/Stop Waves button and a kills counter in the HUD.

All sandboxes are reachable from the main menu via the "Dev Sandboxes" button (scenes/menu/sandbox_menu.tscn).

## Tests

Headless unit tests in `addons/isometric_kit/tests/test_main.gd` (146 checks) cover grid
geometry/walls, footprint math, camera setup, spawner wave counts/ramp/restart, enemy
reaching, enemy health (`take_damage`/`damaged`/`died`, idempotent `die()` + single loot
drop), trigger zones, projectile despawn + damage/splash, joystick vectors, player
movement, loot drops/pickups, currency wallet/deposit caps (including the pad `paused`
state), build-site stage level-ups (tower blocks, pad removal at max level,
structure_scene segments, first-level pause, tower sites building/upgrading a tower),
tower behavior (aiming, firing only in range, configured damage, `enemy_killed` on a kill,
`level_stats` overrides/clamping), and the celebration popup (spawns on level-up, confetti
burst, disabled flag).
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
