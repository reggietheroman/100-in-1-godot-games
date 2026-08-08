extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var player_start := Vector3(-4, 0.6, -4)
@export var spawn_point := Vector3(5, 0.6, 5)
@export var rally_point := Vector3(-5, 0.6, -5)
@export var wave_size := 3
@export var wave_interval := 8.0

const BOUNDARY_WALL_H := 1.5

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var player: CharacterBody3D = $Player
@onready var spawner: Node3D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var zone_a: Area3D = $Zones/ZoneA
@onready var zone_b: Area3D = $Zones/ZoneB
@onready var zone_c: Area3D = $Zones/ZoneC


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	grid.build()

	player.position = player_start

	spawner.spawn_point = spawn_point
	spawner.rally_point = rally_point
	spawner.wave_size = wave_size
	spawner.wave_interval = wave_interval
	spawner.start()
	$HUD/BackButton.pressed.connect(_on_back_pressed)

	_connect_zone(zone_a, "Zone A")
	_connect_zone(zone_b, "Zone B")
	_connect_zone(zone_c, "Zone C")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _connect_zone(zone: Area3D, name: String):
	zone.player_entered.connect(_on_zone_event.bind(name, "player entered"))
	zone.player_exited.connect(_on_zone_event.bind(name, "player left"))
	zone.enemy_entered.connect(_on_zone_event.bind(name, "enemy entered"))
	zone.enemy_exited.connect(_on_zone_event.bind(name, "enemy left"))


func _on_zone_event(_zone: Area3D, zone_name: String, event: String):
	_log(zone_name + ": " + event)


func _log(msg: String):
	var log_label := hud.get_node("LogLabel") as Label
	log_label.text = msg
