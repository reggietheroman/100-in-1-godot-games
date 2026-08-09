extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")
const LootItem := preload("res://addons/isometric_kit/scripts/loot_item.gd")
const LOOT_SCENE := "res://addons/isometric_kit/scenes/loot_item.tscn"

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var player_move_speed := 4.0
@export var player_start := Vector3(0, 0.6, 0)
@export var loot_count := 9

const BOUNDARY_WALL_H := 1.5
const ITEM_Y := 0.25
const MIN_PLAYER_DIST := 2.0

var collected := 0
var collected_value := 0
var _boundary_pts: Array = []

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	_boundary_pts = VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	grid.build()

	player.move_speed = player_move_speed
	player.position = player_start
	$HUD/BackButton.pressed.connect(_on_back_pressed)
	_spawn_loot()
	_refresh_hud()
	_set_status("Walk over gold gems to collect them — press E near blue shards")


func _spawn_loot():
	var presets := [
		{"name": "Gem", "color": Color(1.0, 0.8, 0.2), "value": 1, "mode": LootItem.PickupMode.AUTO},
		{"name": "Shard", "color": Color(0.3, 0.6, 1.0), "value": 2, "mode": LootItem.PickupMode.KEY},
		{"name": "Ruby", "color": Color(1.0, 0.25, 0.25), "value": 3, "mode": LootItem.PickupMode.AUTO},
	]
	for i in loot_count:
		var item = load(LOOT_SCENE).instantiate()
		var p: Dictionary = presets[i % presets.size()]
		item.item_name = p.name
		item.body_color = p.color
		item.value = p.value
		item.pickup_mode = p.mode
		item.lifetime = 0.0
		item.position = _random_tile()
		add_child(item)
		item.picked_up.connect(_on_loot_picked_up)


func _random_tile() -> Vector3:
	for attempt in 1000:
		var x := randi_range(0, grid.width - 1)
		var z := randi_range(0, grid.depth - 1)
		if grid.is_wall(x, z):
			continue
		var c := VisibleFootprint.tile_center(grid, x, z)
		if not VisibleFootprint.inside(_boundary_pts, c):
			continue
		var pos := Vector3(c.x, ITEM_Y, c.y)
		if pos.distance_to(player.global_position) < MIN_PLAYER_DIST:
			continue
		return pos
	return Vector3(0, ITEM_Y, 0)


func _on_loot_picked_up(item: Node3D):
	collected += 1
	collected_value += item.value
	_refresh_hud()
	_set_status("Picked up %s (+%d) — %d left" % [item.item_name, item.value, loot_count - collected])


func _refresh_hud():
	($HUD/CountLabel as Label).text = "Items: %d / %d" % [collected, loot_count]
	($HUD/ValueLabel as Label).text = "Total value: %d" % collected_value


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
