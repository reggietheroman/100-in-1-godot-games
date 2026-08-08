extends Node3D

@export var enemy_scene: PackedScene
@export var spawn_point: Vector3 = Vector3(4, 0.5, 4)
@export var rally_point: Vector3 = Vector3(-4, 0.5, -4)
@export var wave_size := 5
@export var wave_interval := 6.0
@export var max_waves := 0
@export var auto_start := true
@export var ramp_enabled := false
@export var ramp_start := 1
@export var ramp_every := 3

var wave_number := 0
var active_enemies := 0
var running := false

signal wave_spawned(wave_number: int, count: int)
signal all_enemies_reached_rally
signal waves_finished


func _ready():
	if auto_start:
		start()


func start():
	if running:
		return
	running = true
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
		await get_tree().create_timer(wave_interval).timeout
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
