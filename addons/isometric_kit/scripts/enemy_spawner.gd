## Wave-based enemy spawner.
##
## Spawns `wave_size` enemies from `spawn_point` toward `rally_point` every
## `wave_interval` seconds. Wave count can be capped with `max_waves` (0 =
## infinite). Enemies are instances of `enemy_scene` — they must be a
## `CharacterBody3D` that walks to `target` and emits `reached_rally_point`
## when it arrives (see `enemy_mover.gd`).
##
## Optional per-wave growth: when `ramp_enabled` is true the fixed `wave_size`
## is ignored and each wave holds `ramp_start + (wave_number - 1) / ramp_every`
## enemies (e.g. start with 1 enemy, +1 every 2 waves).
##
## Call `start()` manually when `auto_start` is false. `clear()` stops the
## spawner and frees all live enemies. Restarting (clear + start) is safe: a
## pending wave timer from a previous run is discarded.
extends Node3D

## Scene to spawn per enemy. Should be a `CharacterBody3D` grouped "enemy" that
## walks to `target` and emits `reached_rally_point` when it arrives.
@export var enemy_scene: PackedScene

## Where each wave spawns its enemies (with a small grid offset between them).
@export var spawn_point: Vector3 = Vector3(4, 0.5, 4)

## Point every enemy walks to.
@export var rally_point: Vector3 = Vector3(-4, 0.5, -4)

## Enemies per wave when `ramp_enabled` is false.
@export var wave_size := 5

## Seconds between waves (must be > 0 for more than one wave).
@export var wave_interval := 6.0

## Total waves to spawn before emitting `waves_finished`. 0 = never stop.
@export var max_waves := 0

## Start spawning automatically in `_ready()`.
@export var auto_start := true

## When true, ignore `wave_size` and grow each wave on the ramp schedule below.
@export var ramp_enabled := false

## Starting enemy count per wave in ramp mode.
@export var ramp_start := 1

## In ramp mode, add one enemy every this many waves.
@export var ramp_every := 3

## Waves spawned so far.
var wave_number := 0

## Enemies that have spawned but not yet reached the rally point. Note: enemies
## freed before reaching it (e.g. killed) are never counted down from this.
var active_enemies := 0

## Whether the spawner is currently spawning.
var running := false

## Emitted after a wave spawns: wave index and how many enemies it contained.
signal wave_spawned(wave_number: int, count: int)

## Emitted when `active_enemies` drops to 0 (every spawned enemy reached the rally point).
signal all_enemies_reached_rally

## Emitted when `max_waves` waves have spawned.
signal waves_finished

var _run_id := 0


func _ready():
	if auto_start:
		start()


func start():
	if running:
		return
	running = true
	_run_id += 1
	_spawn_wave()


func stop():
	running = false


func clear():
	stop()
	for child in get_children():
		if child is CharacterBody3D:
			child.queue_free()
	active_enemies = 0
	wave_number = 0


func _spawn_wave():
	if not running:
		return
	if enemy_scene == null:
		push_warning("EnemySpawner: no enemy_scene assigned")
		return
	if max_waves > 0 and wave_number >= max_waves:
		stop()
		waves_finished.emit()
		return

	wave_number += 1
	var count := _current_wave_size()
	for i in count:
		var enemy := enemy_scene.instantiate() as CharacterBody3D
		enemy.target = rally_point
		enemy.position = spawn_point + _spawn_offset(i)
		enemy.reached_rally_point.connect(_on_enemy_reached)
		add_child(enemy)
		active_enemies += 1

	wave_spawned.emit(wave_number, count)
	if wave_interval > 0.0:
		var run := _run_id
		await get_tree().create_timer(wave_interval).timeout
		if run != _run_id:
			return
		_spawn_wave()


func _current_wave_size() -> int:
	if not ramp_enabled:
		return wave_size
	return ramp_start + (wave_number - 1) / maxi(ramp_every, 1)


func _spawn_offset(i: int) -> Vector3:
	var spacing := 0.9
	var side := 3
	var x := (i % side) - side / 2.0
	var z := (i / side) - side / 2.0
	return Vector3(x * spacing, 0.0, z * spacing)


func _on_enemy_reached():
	active_enemies -= 1
	if active_enemies <= 0:
		all_enemies_reached_rally.emit()
