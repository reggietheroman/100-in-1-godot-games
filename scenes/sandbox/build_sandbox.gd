extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")
const BUILD_SITE_SCENE := "res://addons/isometric_kit/scenes/build_site.tscn"

@export var play_width := 13.31
@export var play_depth := 13.31
@export var map_padding := 3
@export var player_move_speed := 4.0
@export var starting_currency := 500

@export var site_configs := [
	{
		"name": "Outpost",
		"stages": [10, 25, 50],
		"offset": Vector3(-4, 0, -3),
		"structure_offset": Vector3(3.5, 0, 0),
		"colors": [Color(0.45, 0.9, 0.45), Color(1.0, 0.7, 0.2), Color(1.0, 0.4, 0.35)],
	},
	{
		"name": "Barracks",
		"stages": [15, 35],
		"offset": Vector3(4, 0, -3),
		"structure_offset": Vector3(-3.5, 0, 0),
		"colors": [Color(0.5, 0.7, 1.0), Color(0.8, 0.5, 1.0)],
	},
	{
		"name": "Keep",
		"stages": [20, 40, 80],
		"offset": Vector3(0, 0, 4),
		"structure_offset": Vector3(3.5, 0, 0),
		"colors": [Color(1.0, 0.6, 0.3), Color(1.0, 0.4, 0.3), Color(0.9, 0.3, 0.5)],
	},
	{
		"name": "Gatling Tower",
		"stages": [20, 40],
		"offset": Vector3(4, 0, 4),
		"structure_offset": Vector3(-3.5, 0, 0),
		"tower_scene": "res://addons/isometric_kit/scenes/tower.tscn",
		"tower_level_stats": [
			{"fire_interval": 0.5, "range": 5.0, "damage": 1},
			{"fire_interval": 0.3, "range": 7.0, "damage": 2, "splash_radius": 1.2},
		],
	},
]

const BOUNDARY_WALL_H := 1.5
const TILE_Y := 0.6

var _map_center := Vector3.ZERO

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var player: CharacterBody3D = $Player
@onready var wallet: Node3D = $Player/CurrencyWallet


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	grid.build()
	_map_center = _compute_map_center()

	player.move_speed = player_move_speed
	player.position = _map_center
	wallet.currency = starting_currency

	for cfg in site_configs:
		var site = load(BUILD_SITE_SCENE).instantiate()
		site.name = "Site_%s" % cfg["name"]
		site.display_name = cfg["name"]
		var stages: Array[int] = []
		for v in cfg["stages"]:
			stages.append(v)
		site.stages = stages
		if cfg.has("colors"):
			var colors: Array[Color] = []
			for c in cfg["colors"]:
				colors.append(c)
			site.structure_colors = colors
		if cfg.has("tower_scene"):
			site.tower_scene = load(cfg["tower_scene"])
		if cfg.has("tower_level_stats"):
			var level_stats: Array[Dictionary] = []
			for s in cfg["tower_level_stats"]:
				level_stats.append(s)
			site.tower_level_stats = level_stats
		site.structure_offset = cfg["structure_offset"]
		site.position = _map_center + cfg["offset"]
		add_child(site)
		site.leveled_up.connect(_on_leveled_up.bind(cfg["name"]))
		site.completed.connect(_on_completed.bind(cfg["name"]))

	$HUD/BackButton.pressed.connect(_on_back_pressed)
	wallet.currency_changed.connect(_on_currency_changed)
	_refresh_hud()
	_set_status("Stand on a pad to pay coins — the tower builds beside it")


func _compute_map_center() -> Vector3:
	var pts := VisibleFootprint.ground_footprint(camera)
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.y)
		max_z = maxf(max_z, p.y)
	return Vector3((min_x + max_x) / 2.0, TILE_Y, (min_z + max_z) / 2.0)


func _on_currency_changed(_amount: int):
	_refresh_hud()


func _on_leveled_up(level: int, site_name: String):
	_set_status("%s grew to level %d" % [site_name, level])


func _on_completed(site_name: String):
	_set_status("%s complete — its payment pad was removed" % site_name)


func _refresh_hud():
	($HUD/CurrencyLabel as Label).text = "Currency: %d" % wallet.currency


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/sandbox_menu.tscn")


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
