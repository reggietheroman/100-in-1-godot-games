# Manual configuration reference

How to configure each `isometric_kit` system by hand. All systems are driven by
exported vars, so you can set them in the Inspector on the scene node, or in
code after `instantiate()`. Everything lives in `addons/isometric_kit/`.

> See `architecture.md` for why this is the pattern.

## Player — `scripts/player_controller.gd` / `scenes/player.tscn`

`CharacterBody3D`, camera-relative WASD + touch joystick. Group: `player`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `move_speed` | float | 4.0 | Horizontal speed (units/s). |
| `acceleration` | float | 12.0 | How quickly velocity approaches target (higher = snappier). |
| `body_color` | Color | blue | Capsule tint. |
| `joystick` | Control | unset | Joystick to use; falls back to the first `joystick`-group node. |

## Enemy — `scripts/enemy_mover.gd` / `scenes/enemy.tscn`

`CharacterBody3D` that walks to `target` and idles. Group: `enemy`.
Signals: `reached_rally_point`, `damaged(amount, health)`, `died(enemy)`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `move_speed` | float | 3.0 | Horizontal speed (units/s). |
| `body_color` | Color | red | Capsule tint. |
| `stop_distance` | float | 0.1 | Distance to `target` considered "reached". |
| `loot_scene` | PackedScene | unset | Dropped on death (see loot below). |
| `max_health` | int | 1 | Health pool; `take_damage()` reduces it, 0 = `die()`. |

Runtime: set `target: Vector3` before adding to the tree. Call
`take_damage(amount)` / `die()`. `die()` is idempotent and drops `loot_scene`
once.

## Enemy spawner — `scripts/enemy_spawner.gd`

`Node3D` wave spawner. Signals: `wave_spawned(wave, count)`,
`all_enemies_reached_rally`, `waves_finished`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `enemy_scene` | PackedScene | unset | Scene to spawn (must walk to `target`, emit `reached_rally_point`). |
| `spawn_point` | Vector3 | (4, 0.5, 4) | Where each wave spawns. |
| `rally_point` | Vector3 | (-4, 0.5, -4) | Point every enemy walks to. |
| `wave_size` | int | 5 | Enemies per wave when `ramp_enabled` is false. |
| `wave_interval` | float | 6.0 | Seconds between waves. |
| `max_waves` | int | 0 | Total waves before `waves_finished`; 0 = infinite. |
| `auto_start` | bool | true | Start spawning in `_ready()`. |
| `ramp_enabled` | bool | false | Ignore `wave_size`, grow waves per ramp. |
| `ramp_start` | int | 1 | Wave size in ramp mode: `ramp_start + (wave_number-1)/ramp_every`. |
| `ramp_every` | int | 3 | Add one enemy every N waves. |

Methods: `start()`, `stop()`, `clear()` (frees live enemies, resets counters).

## Trigger area — `scripts/trigger_area.gd` / `scenes/trigger_area.tscn`

`Area3D` that logs enter/exit. Signals: `player_entered/exited(area)`,
`enemy_entered/exited(area)`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `track_player` | bool | true | Watch `player`-group bodies. |
| `track_enemies` | bool | true | Watch `enemy`-group bodies. |
| `area_size` | Vector3 | (2, 2, 2) | Full footprint extents of the zone. |
| `active_color` / `inactive_color` | Color | green / gray | Zone tint while occupied / empty. |

## Grid map — `scripts/grid_map.gd`

`Node3D` checkerboard floor + walls. Coordinates: tile (x, z) centers on
`(x - width/2 + 0.5, z - depth/2 + 0.5)`. Tiles and walls are 1-unit
`StaticBody3D` boxes (a floor + colliders).

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `width` / `depth` | int | 12 | Tiles along X / Z. |
| `tile_size` | float | 1.0 | Tile edge length (player/enemies expect 1.0). |
| `tile_height` | float | 0.1 | Floor slab thickness. |
| `color_a` / `color_b` | Color | light / dark | Checkerboard colors. |
| `wall_color` | Color | brown | Wall box color. |

Methods: `build()` (rebuild after width/depth/wall changes), `set_wall(x, z,
height)` (height <= 0 removes), `clear_walls()`, `is_wall(x, z)`,
`get_world_size()`.

## Visible footprint — `scripts/visible_footprint.gd`

`class_name VisibleFootprint`, static helpers (no node): `configure_map`,
`ground_footprint`, `inside`, `tile_center`, `is_boundary_wall`. Sizes a grid to
the camera's visible ground footprint and marks boundary walls. Note:
`camera.size` is the *full* ortho frustum height in Godot 4, so half-height is
`size / 2`.

## Isometric camera — `scripts/isometric_camera.gd` / `scenes/isometric_camera.tscn`

`Camera3D`, orthographic, auto-fits a map. Call `setup()` after changing config.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `map` | Node3D | unset | Node whose `get_world_size()` drives auto-fit. |
| `angle` | float | 35.0 | Elevation above the ground, degrees. |
| `yaw` | float | 45.0 | Rotation around vertical axis (45 = classic iso). |
| `distance` | float | 14.0 | Overridden by `setup()` (affects near clipping only). |
| `fit_size` | Vector2 | ZERO | World size to fit instead of `map`; ZERO = use map. |

## Joystick — `scripts/joystick.gd` / `scenes/joystick.tscn`

Floating touch joystick `Control`. Group: `joystick`. Exposes `vector` (≤ 1).

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `radius` | float | 60.0 | Max drag distance; input clamped to it. |
| `knob_radius` | float | 30.0 | Visual knob size. |
| `visible_on_desktop` | bool | false | Show on desktop too (normally WASD only). |

## Projectile — `scripts/projectile.gd` / `scenes/projectile.tscn`

`Area3D` that flies along `direction`, applies `damage`, despawns on `enemy` /
`wall` / `lifetime`. Signal: `hit(enemy)`. Group: `projectile`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `speed` | float | 18.0 | Movement speed (units/s). |
| `lifetime` | float | 3.0 | Max lifespan before despawn. |
| `body_color` | Color | gold | Mesh tint. |
| `damage` | int | 1 | Damage applied via `take_damage()`. |
| `splash_radius` | float | 0.0 | >0 = also damage other enemies within radius of impact. |

Runtime: set `direction: Vector3` after instantiation.

## Loot item — `scripts/loot_item.gd` / `scenes/loot_item.tscn` (+ `loot_coin.tscn`)

`Node3D` pickup (gem mesh in `loot_item.tscn`, coin mesh in `loot_coin.tscn`).
Group: `loot`. Signal: `picked_up(item)`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `item_name` | String | "Gem" | Shown in the pickup label. |
| `body_color` | Color | gold | Mesh tint. |
| `value` | int | 1 | Worth (sandboxes convert this to currency). |
| `pickup_mode` | enum | Auto | Auto = on contact; Key = press `pickup` (E). |
| `pickup_radius` | float | 1.4 | Horizontal distance to collect. |
| `lifetime` | float | 30.0 | Seconds before despawn (0 = never). |
| `blink_duration` / `fade_duration` | float | 1.5 / 0.4 | Blink then fade near despawn. |
| `show_particle_burst` / `show_floating_label` / `show_fly_anim` | bool | true | One-shot pickup feedback toggles. |

Variant scenes reuse this script with different meshes/defaults (`loot_coin.tscn`
= coin, named "Coin").

## Loot drop — `scripts/loot_drop.gd`

`class_name LootDrop`, static helper: `LootDrop.spawn(loot_scene, at, parent)`
places a loot scene on the ground. Used by `enemy_mover.die()`.

## Currency wallet — `scripts/currency_wallet.gd`

`Node3D` balance tracker. Group: `wallet`. Signal: `currency_changed(amount)`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `currency` | int | 0 | Current balance (set a starting amount in the Inspector). |

Methods: `add_currency(amount)` (no-op on ≤0), `spend_currency(amount)` →
returns amount actually spent (clamped to balance).

## Currency deposit — `scripts/currency_deposit.gd` / `scenes/currency_deposit.tscn`

`Area3D` pad that drains a wallet while the player stands on it. Group:
`deposit`. Signal: `deposited_changed(deposited, capacity)`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `area_size` | Vector3 | (2.5, 2, 2.5) | Full pad footprint. |
| `capacity` | int | 0 | Total currency this pad accepts. |
| `display_name` | String | "Deposit" | Shown on the on-pad label. |
| `auto_activate` | bool | true | Drain automatically while stood on; false = press `activation_action`. |
| `activation_action` | String | "pickup" | Input action when `auto_activate` is false. |
| `transfer_amount` | int | 1 | Units per transfer tick. |
| `transfer_interval` | float | 0.12 | Seconds per tick (each coin flight). |
| `show_transfer_visuals` | bool | true | Flying coin + pad pulses. |
| `active_color` / `inactive_color` / `full_color` | Color | — | Pad tints. |
| `register_in_group` | bool | true | Set false when embedded (e.g. `build_site`) so it doesn't pollute the group. |

Runtime: `deposited` (current), `paused` (freezes transfers), `refresh()`.

## Build site — `scripts/build_site.gd` / `scenes/build_site.tscn`

`Node3D` predefined build area. Embeds a `currency_deposit` payment pad (with
`register_in_group = false`). Group: `build_site`. Signals: `leveled_up(level)`,
`completed`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `display_name` | String | "Build Site" | Shown on the pad label. |
| `stages` | Array[int] | [10, 25, 50] | Cost of each level, paid in sequence. |
| `payment_area_size` | Vector3 | (2.5, 2, 2.5) | Pad footprint. |
| `structure_offset` | Vector3 | (3.5, 0, 0) | Where the structure sits beside the pad. |
| `structure_scene` | PackedScene | unset | Asset instanced once per level; falls back to box blocks. |
| `structure_colors` | Array[Color] | greens/yellows/reds | Tint per level (empty = keep asset materials). |
| `tower_scene` | PackedScene | unset | Instead builds ONE functional tower (see below). |
| `tower_level_stats` | Array[Dict] | [] | Per-level stats for `tower_scene`, indexed `level-1`. |
| `auto_activate` / `transfer_amount` / `transfer_interval` / `show_transfer_visuals` | — | — | Pass-throughs to the embedded pad. |
| `celebration_enabled` | bool | true | Popup + confetti on every level-up. |
| `first_level_pause` | float | 0.6 | Seconds the pad pauses after the first level (0 disables). |

Tower sites (`tower_scene` set): one hidden tower instance; each paid stage
calls its `apply_level()` with `tower_level_stats[level-1]`; `structure_scene`
/ `structure_colors` ignored.

## Tower — `scripts/tower.gd` / `scenes/tower.tscn`

`Node3D` auto-shooter. Group: `tower`. Signals: `fired(enemy)`,
`enemy_killed(enemy)`.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `fire_interval` | float | 0.6 | Seconds between shots. |
| `range` | float | 5.0 | Max horizontal distance to engage. |
| `damage` | int | 1 | Damage per shot (primary enemy). |
| `splash_radius` | float | 0.0 | >0 = AoE around impact (excludes primary). |
| `projectile_speed` | float | 18.0 | Speed of fired projectiles. |
| `projectile_scene` | PackedScene | default | Scene to fire (must expose `speed/direction/damage/splash_radius` + `hit`). |
| `enemy_group` | String | "enemy" | Group the tower targets. |
| `body_color` | Color | blue | Body tint. |
| `aim_speed` | float | 8.0 | Turret turn speed (rad/s). |
| `level_stats` | Array[Dict] | [] | Per-level stat overrides, indexed `level-1`. |
| `level_colors` | Array[Color] | [] | Per-level tint, indexed `level-1`. |

Runtime: `apply_level(n, stats)` upgrades stats and tint. Idle while
`scale == Vector3.ZERO` (pre-build state).

## Celebration — `scripts/celebration.gd` / `scenes/celebration.tscn`

`Node3D` one-shot popup. Call `celebrate(text, color)`; the node frees itself.

| Export | Type | Default | What it does |
| --- | --- | --- | --- |
| `rise` | float | 1.6 | How far the label floats up. |
| `hold_time` | float | 0.55 | Seconds at peak before fading. |

## Input actions (`project.godot`)

`move_left/right/up/down` (WASD + arrows), `shoot` (Space/Fire button),
`pickup` (E).

## Reference sandboxes

The best way to see each system configured by hand: read the matching sandbox
in `scenes/sandbox/` (each lists its type configs as exported arrays at the
top):

- `player_sandbox` — player movement.
- `spawner_sandbox` — waves + click-to-place spawn/rally.
- `trigger_sandbox` — trigger zones.
- `shooting_sandbox` — player shooting + full-POV map.
- `pickup_sandbox` / `loot_spawn_sandbox` / `loot_drop_sandbox` — loot.
- `currency_sandbox` — waves → loot → wallet → deposit banks.
- `build_sandbox` — building + tower sites.
- `tower_sandbox` — Rapid/Cannon/Sniper tower types vs waves.
- `combined_sandbox` — everything wired together with 4 Rapid tower build pads.
