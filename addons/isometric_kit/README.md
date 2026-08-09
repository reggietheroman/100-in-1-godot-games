# Isometric Kit

Reusable 3D systems for isometric-style games (Godot 4.7, GL Compatibility,
Jolt Physics). Each component is a small `Node3D`/`CharacterBody3D`/`Area3D`
driven by exported variables, so you drop a scene in and tune it from the
inspector. Playable reference sandboxes live in `scenes/sandbox/`.

> Full class, property, signal, and method docs are also in the scripts as
> GDScript `##` doc comments — hover any exported property or method in the
> editor to see them.

## Components

| Component | Scene | Script | What it does |
| --- | --- | --- | --- |
| Player | `scenes/player.tscn` | `scripts/player_controller.gd` | WASD/arrow or joystick movement, camera-relative, group `player` |
| Enemy | `scenes/enemy.tscn` | `scripts/enemy_mover.gd` | Walks to a `target` and idles, group `enemy`, emits `reached_rally_point`; `die()` drops its `loot_scene` |
| Spawner | *(add as `Node3D`)* | `scripts/enemy_spawner.gd` | Spawns waves of enemies spawn→rally; optional ramp growth |
| Trigger area | `scenes/trigger_area.tscn` | `scripts/trigger_area.gd` | Reports player/enemy enter/exit events |
| Grid map | *(add as `Node3D`)* | `scripts/grid_map.gd` | Checkerboard floor + blocking walls |
| Camera | `scenes/isometric_camera.tscn` | `scripts/isometric_camera.gd` | Ortho camera that auto-fits the map |
| Footprint | — | `scripts/visible_footprint.gd` | Sizes a grid to fill the camera POV + boundary walls |
| Joystick | `scenes/joystick.tscn` | `scripts/joystick.gd` | Floating touch joystick |
| Projectile | `scenes/projectile.tscn` | `scripts/projectile.gd` | Flies toward a target, reports hits, blocked by walls |
| Loot item | `scenes/loot_item.tscn` | `scripts/loot_item.gd` | Collectible pickup: `Auto`/`Key` modes, despawn timer, pickup effects; group `loot`, emits `picked_up` |
| Loot drop | — | `scripts/loot_drop.gd` | Static helper that spawns a loot scene on the ground (used by `enemy_mover.die()`) |

## Quick start

1. Add the `isometric_kit` folder to your project's `addons/` and enable it in
   **Project Settings → Plugins**.
2. Define input actions `move_left/right/up/down` (WASD + arrows), `shoot`
   (Space), and `pickup` (E) in **Project Settings → Input Map** (see
   `project.godot`).
3. Build a scene:
   - `GridMap` (script `grid_map.gd`) — set `width`/`depth`, call `build()`.
   - `IsometricCamera` — either set `map` to the grid (auto-fit) or `fit_size`;
     call `setup()` after changing either.
   - `Player` + `Joystick` (in a `CanvasLayer`) — the player finds the joystick
     through the `joystick` group.
   - An `EnemySpawner` `Node3D` with `enemy_scene` = `enemy.tscn`.
   - Optional `TriggerArea`s and the `projectile.tscn` for shooting.

### Minimal spawner wiring

```gdscript
@onready var spawner: Node3D = $Spawner
@onready var enemy_scene := preload("res://addons/isometric_kit/scenes/enemy.tscn")

func _ready():
    spawner.enemy_scene = enemy_scene
    spawner.spawn_point = Vector3(4, 0.5, 4)
    spawner.rally_point = Vector3(-4, 0.5, -4)
    spawner.wave_size = 5
    spawner.wave_interval = 6.0
    spawner.max_waves = 3          # 0 = infinite
    spawner.wave_spawned.connect(_on_wave)
    spawner.start()                # or set auto_start = true

func _on_wave(wave: int, count: int):
    print("Wave %d: %d enemies" % [wave, count])
```

### Shooting wiring

```gdscript
@onready var projectile_scene := preload("res://addons/isometric_kit/scenes/projectile.tscn")

func _unhandled_input(event):
    if event.is_action_pressed("shoot"):
        _fire()

func _fire():
    var enemy := get_tree().get_first_node_in_group("enemy")
    if enemy == null:
        return
    var p := projectile_scene.instantiate()
    p.speed = 18.0
    p.direction = (enemy.global_position - global_position).normalized()
    p.direction.y = 0.0
    p.position = global_position + Vector3(0, 0.4, 0)
    add_child(p)
    p.hit.connect(func(hit_enemy): hit_enemy.queue_free())
```

### Loot wiring

```gdscript
const LOOT_SCENE := "res://addons/isometric_kit/scenes/loot_item.tscn"

enemy.loot_scene = load(LOOT_SCENE)   # what this enemy drops on death
enemy.die()                           # drops loot at its feet, then frees

var loot := LOOT_SCENE.instantiate()  # or spawn loot directly anywhere
loot.picked_up.connect(_on_picked_up)
add_child(loot)

func _on_picked_up(item: Area3D, collector: Node3D):
    print("collector got ", item.get_script().resource_path)
```

`loot_item.tscn` defaults to `Auto` mode (collects on contact). Switch to `Key`
mode to require the `pickup` action, and set `despawn_time` for timed items.

### POV-filling map (fill the whole screen + boundary walls)

```gdscript
const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")

func _ready():
    $Camera.fit_size = Vector2(11.31, 11.31)
    $Camera.setup()                                   # camera.size must be final
    VisibleFootprint.configure_map($GridMap, $Camera, 3, 1.5)
    $GridMap.build()
```

## Conventions & gotchas

- **Groups** — components self-register: `player`, `enemy`, `wall`, `joystick`,
  `loot`. Trigger areas, spawners, and projectiles discover each other through
  them.
- **`camera.size` is the FULL ortho height** in Godot 4. Half-extents are
  `size / 2` — `visible_footprint.gd` handles this.
- **`camera.setup()` before `configure_map`** — the footprint math reads
  `camera.size`, which `setup()` computes.
- **Call `setup()`** after changing `fit_size`, `map`, `angle`, or `yaw`.
- **Call `grid.build()`** after changing `width`/`depth` or setting walls.
- **Waves with `max_waves = 0`** never emit `waves_finished`.
- **`active_enemies`** only counts down when enemies reach the rally point —
  enemies freed earlier (e.g. shot) don't count down. This affects only the
  `all_enemies_reached_rally` signal.
- **Restart safety** — `clear()` then `start()` discards any pending wave timer.
- Enemies/player expect **1-unit tiles** (`tile_size = 1.0`) and a `y` spawn
  height ~0.5–0.6 above the ground.
- Ramp mode: set `ramp_enabled = true`; wave size becomes
  `ramp_start + (wave_number - 1) / ramp_every` (e.g. start 1, +1 every 3 waves).

## Tests

Headless unit tests live in `tests/`. Run them with:

```bash
godot --headless --path . --script addons/isometric_kit/tests/test_main.gd
```

(Any command-line flag works; the runner prints a pass/fail summary and exits
nonzero on failure.) Tests cover grid maps and walls, footprint math, the camera
sizing/clip guard, spawner wave counts and ramp growth, enemy target reaching,
trigger-area signals, projectile hits/walls/lifetime, joystick vector math, and
loot drops/pickups.

Reference sandboxes that exercise everything together (reachable from the main
menu under "Dev Sandboxes"): `scenes/sandbox/combined_sandbox.tscn` (player +
zones + waves + shooting + loot), plus focused ones — `pickup_sandbox.tscn`
(collect on contact / on key), `loot_spawn_sandbox.tscn` (spawn a pile), and
`loot_drop_sandbox.tscn` (enemies drop loot when shot).
