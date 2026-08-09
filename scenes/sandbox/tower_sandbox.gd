extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")
const TOWER_SCENE := "res://addons/isometric_kit/scenes/tower.tscn"
const SPAWNER_SCRIPT := "res://addons/isometric_kit/scripts/enemy_spawner.gd"
const ENEMY_SCENE := "res://addons/isometric_kit/scenes/enemy.tscn"

@export var play_width := 28.0
@export var play_depth := 13.31
@export var map_padding := 3
@export var wave_size := 3
@export var max_waves := 6
@export var wave_interval := 0.8

## One lane per tower: the map is split into three wide lanes along X, each
## centered on its tower. Lanes are spaced further apart than the longest tower
## range (Sniper 9.0), so no tower can reach into a neighbor lane's targets.
## Each lane has its own spawn point (bottom) and rally point (top).
@export var tower_configs := [
	{
		"name": "Rapid",
		"position": Vector3(-9.33, 0, 0),
		"spawn_point": Vector3(-9.33, 0.6, 5.5),
		"rally_point": Vector3(-9.33, 0.6, -5.5),
		"fire_interval": 0.22,
		"range": 4.0,
		"damage": 1,
		"splash_radius": 0.0,
		"color": Color(0.35, 0.7, 1.0),
	},
	{
		"name": "Cannon",
		"position": Vector3(0, 0, 0),
		"spawn_point": Vector3(0, 0.6, 5.5),
		"rally_point": Vector3(0, 0.6, -5.5),
		"fire_interval": 1.1,
		"range": 6.5,
		"damage": 3,
		"splash_radius": 1.6,
		"color": Color(1.0, 0.55, 0.2),
	},
	{
		"name": "Sniper",
		"position": Vector3(9.33, 0, 0),
		"spawn_point": Vector3(9.33, 0.6, 5.5),
		"rally_point": Vector3(9.33, 0.6, -5.5),
		"fire_interval": 1.8,
		"range": 9.0,
		"damage": 5,
		"splash_radius": 0.0,
		"color": Color(0.8, 0.4, 1.0),
	},
]

const BOUNDARY_WALL_H := 1.5

var kills := 0
var _towers: Array[Node3D] = []
var _spawners: Array[Node3D] = []
var _finished_count := 0

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var hud: CanvasLayer = $HUD


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	grid.build()

	for cfg in tower_configs:
		_add_tower(cfg)
		_add_spawner(cfg)

	$HUD/BackButton.pressed.connect(_on_back_pressed)
	$HUD/Panel/Controls/StartButton.pressed.connect(_on_start_pressed)
	_build_tower_panel()
	_set_status("Click Start Waves — each lane's tower shoots enemies marching to its rally point")


func _add_tower(cfg: Dictionary):
	var tower = load(TOWER_SCENE).instantiate()
	tower.name = cfg["name"]
	tower.position = cfg["position"]
	tower.fire_interval = cfg["fire_interval"]
	tower.range = cfg["range"]
	tower.damage = cfg["damage"]
	tower.splash_radius = cfg["splash_radius"]
	tower.body_color = cfg["color"]
	tower.enemy_killed.connect(_on_enemy_killed.bind(tower))
	add_child(tower)
	_towers.append(tower)


## One spawner per tower lane: enemies spawn at the lane's spawn point and
## march to its rally point, crossing the tower's third of the map.
func _add_spawner(cfg: Dictionary):
	var spawner = load(SPAWNER_SCRIPT).new()
	spawner.name = "%sSpawner" % cfg["name"]
	spawner.enemy_scene = load(ENEMY_SCENE)
	spawner.auto_start = false
	spawner.spawn_point = cfg["spawn_point"]
	spawner.rally_point = cfg["rally_point"]
	spawner.wave_size = wave_size
	spawner.max_waves = max_waves
	spawner.wave_interval = wave_interval
	spawner.waves_finished.connect(_on_waves_finished)
	add_child(spawner)
	_spawners.append(spawner)


func _build_tower_panel():
	var controls := $HUD/Panel/Controls as VBoxContainer
	for cfg in tower_configs:
		var label := Label.new()
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		var splash := ""
		if float(cfg["splash_radius"]) > 0.0:
			splash = ", AoE %.1f" % cfg["splash_radius"]
		label.text = "%s: rate %.2fs, range %.0f, dmg %d%s" % [
			cfg["name"], cfg["fire_interval"], cfg["range"], cfg["damage"], splash]
		controls.add_child(label)


func _on_start_pressed():
	if _any_spawner_running():
		for s in _spawners:
			s.stop()
		($HUD/Panel/Controls/StartButton as Button).text = "Start Waves"
		_set_status("Waves stopped")
		return
	_finished_count = 0
	for s in _spawners:
		s.max_waves = max_waves
		s.start()
	($HUD/Panel/Controls/StartButton as Button).text = "Stop Waves"
	_set_status("Waves started — towers are shooting")


func _any_spawner_running() -> bool:
	for s in _spawners:
		if s.running:
			return true
	return false


func _on_waves_finished():
	_finished_count += 1
	if _finished_count >= _spawners.size():
		($HUD/Panel/Controls/StartButton as Button).text = "Start Waves"
		_set_status("All waves finished — %d enemies killed" % kills)


func _on_enemy_killed(_enemy: Node3D, _tower: Node3D):
	kills += 1
	_refresh_hud()


func _refresh_hud():
	($HUD/KillsLabel as Label).text = "Enemies killed: %d" % kills


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/sandbox_menu.tscn")


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
