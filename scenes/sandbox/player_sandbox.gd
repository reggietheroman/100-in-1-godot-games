extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var player_move_speed := 4.0
@export var player_start := Vector3(0, 0.6, 0)

const BOUNDARY_WALL_H := 1.5

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	grid.build()

	player.move_speed = player_move_speed
	player.position = player_start

	_hud_setup()
	$HUD/BackButton.pressed.connect(_on_back_pressed)


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _hud_setup():
	var speed_label := hud.get_node("SpeedLabel") as Label
	speed_label.text = "Move speed: %.1f" % player_move_speed
