extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var spawn_point := Vector3(-4.5, 0.6, 4.5)
@export var rally_point := Vector3(4.5, 0.6, -4.5)
@export var wave_size := 5
@export var wave_interval := 3.0
@export var enemy_move_speed := 3.0

const WAVE_CHOICES := [1, 2, 3, 4, 5, 0]
const ENEMY_MIN := 1
const ENEMY_MAX := 20
const BOUNDARY_WALL_H := 1.5

var wave_count_index := 4
var enemy_count := 5
var picking: String = ""

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var spawner: Node3D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var start_button: Button = $HUD/Panel/Controls/StartButton
@onready var reset_button: Button = $HUD/Panel/Controls/ResetButton

var spawn_marker: Node3D
var rally_marker: Node3D


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	grid.build()

	spawner.spawn_point = spawn_point
	spawner.rally_point = rally_point
	spawner.wave_size = wave_size
	spawner.wave_interval = wave_interval

	spawner.wave_spawned.connect(_on_wave_spawned)
	spawner.all_enemies_reached_rally.connect(_on_all_reached)
	spawner.waves_finished.connect(_on_waves_finished)

	$HUD/BackButton.pressed.connect(_on_back_pressed)
	$HUD/Panel/Controls/StartButton.pressed.connect(_on_start_pressed)
	$HUD/Panel/Controls/ResetButton.pressed.connect(_on_reset_pressed)
	$HUD/Panel/Controls/SetSpawnButton.pressed.connect(_on_set_spawn_pressed)
	$HUD/Panel/Controls/SetRallyButton.pressed.connect(_on_set_rally_pressed)
	$HUD/Panel/Controls/WaveCountSelector/WaveCountPrev.pressed.connect(_on_wave_count_prev)
	$HUD/Panel/Controls/WaveCountSelector/WaveCountNext.pressed.connect(_on_wave_count_next)
	$HUD/Panel/Controls/EnemyCountSelector/EnemyCountPrev.pressed.connect(_on_enemy_count_prev)
	$HUD/Panel/Controls/EnemyCountSelector/EnemyCountNext.pressed.connect(_on_enemy_count_next)

	_refresh_count_labels()
	_set_markers()
	_set_status("Configure and click Start Waves")


func _unhandled_input(event):
	if picking == "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_point(event.position)
		get_viewport().set_input_as_handled()


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _on_start_pressed():
	if spawner.running:
		spawner.stop()
		_set_running_ui(false)
		_set_status("Stopped after wave %d" % spawner.wave_number)
		return
	_reset_waves()
	spawner.max_waves = WAVE_CHOICES[wave_count_index]
	spawner.wave_size = enemy_count
	spawner.start()
	_set_running_ui(true)
	_set_status("Started: %s waves, %d enemies/wave" % [_wave_label(), enemy_count])


func _on_reset_pressed():
	_reset_waves()
	_set_status("Waves stopped, enemies cleared")


func _on_set_spawn_pressed():
	_reset_waves()
	picking = "spawn"
	_set_status("Click a tile to set the spawn point")


func _on_set_rally_pressed():
	_reset_waves()
	picking = "rally"
	_set_status("Click a tile to set the rally point")


func _on_wave_count_prev():
	wave_count_index = (wave_count_index - 1 + WAVE_CHOICES.size()) % WAVE_CHOICES.size()
	_refresh_count_labels()


func _on_wave_count_next():
	wave_count_index = (wave_count_index + 1) % WAVE_CHOICES.size()
	_refresh_count_labels()


func _on_enemy_count_prev():
	enemy_count = maxi(enemy_count - 1, ENEMY_MIN)
	_refresh_count_labels()


func _on_enemy_count_next():
	enemy_count = mini(enemy_count + 1, ENEMY_MAX)
	_refresh_count_labels()


func _refresh_count_labels():
	var wave_label := _wave_label()
	($HUD/Panel/Controls/WaveCountSelector/WaveCountValue as Label).text = wave_label
	($HUD/Panel/Controls/WaveCountLabel as Label).text = "Waves: " + wave_label
	($HUD/Panel/Controls/EnemyCountSelector/EnemyCountValue as Label).text = str(enemy_count)
	($HUD/Panel/Controls/EnemyCountLabel as Label).text = "Enemies / wave: " + str(enemy_count)


func _wave_label() -> String:
	return "∞" if WAVE_CHOICES[wave_count_index] == 0 else str(WAVE_CHOICES[wave_count_index])


func _pick_point(screen_pos: Vector2):
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var t := -from.y / dir.y if dir.y < -0.0001 else -1.0
	if t < 0.0:
		return
	var world := from + dir * t
	var snapped := _snap_to_tile(world)
	if picking == "spawn":
		spawn_point = snapped
		spawner.spawn_point = snapped
		_update_marker(spawn_marker, snapped)
		_set_status("Spawn point set to (%d, %d)" % [snapped.x, snapped.z])
	elif picking == "rally":
		rally_point = snapped
		spawner.rally_point = snapped
		_update_marker(rally_marker, snapped)
		_set_status("Rally point set to (%d, %d)" % [snapped.x, snapped.z])
	picking = ""


func _snap_to_tile(world: Vector3) -> Vector3:
	var cx := clampi(roundi(world.x), -grid.width / 2, grid.width / 2 - 1)
	var cz := clampi(roundi(world.z), -grid.depth / 2, grid.depth / 2 - 1)
	return Vector3(cx + 0.5, 0.6, cz + 0.5)


func _reset_waves():
	spawner.clear()
	_set_running_ui(false)


func _set_running_ui(running: bool):
	start_button.text = "Stop Waves" if running else "Start Waves"


func _set_markers():
	spawn_marker = _make_circle_marker(Color(0, 1, 1, 0.35))
	add_child(spawn_marker)
	rally_marker = _make_circle_marker(Color(1, 1, 0, 0.35))
	add_child(rally_marker)
	_update_marker(spawn_marker, spawn_point)
	_update_marker(rally_marker, rally_point)


func _update_marker(marker: Node3D, point: Vector3):
	marker.position = Vector3(point.x, 0.08, point.z)


func _make_circle_marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	marker.mesh = mesh
	return marker


func _on_wave_spawned(wave: int, count: int):
	_set_status("Wave %d spawned (%d enemies) — walking to rally point" % [wave, count])


func _on_all_reached():
	_set_status("All enemies reached the rally point")


func _on_waves_finished():
	_set_running_ui(false)
	_set_status("All %s waves finished" % [_wave_label()])


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
