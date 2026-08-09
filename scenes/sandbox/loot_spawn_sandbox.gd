extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")
const LootItem := preload("res://addons/isometric_kit/scripts/loot_item.gd")
const LOOT_SCENE := "res://addons/isometric_kit/scenes/loot_item.tscn"

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var player_move_speed := 4.0
@export var player_start := Vector3(0, 0.6, 0)

const BOUNDARY_WALL_H := 1.5
const ITEM_Y := 0.25
const LIFETIME_CHOICES := [0.5, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 30.0, 60.0, 0.0]
const PRESETS := [
	{"name": "Gold", "color": Color(1.0, 0.8, 0.2), "value": 1},
	{"name": "Emerald", "color": Color(0.2, 1.0, 0.4), "value": 2},
	{"name": "Ruby", "color": Color(1.0, 0.25, 0.25), "value": 3},
	{"name": "Heart", "color": Color(1.0, 0.4, 0.6), "value": 5},
]

var lifetime_index := 5
var preset_index := 0
var pickup_mode := 0
var on_ground := 0

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
	$HUD/BackButton.pressed.connect(_on_back_pressed)
	$HUD/Panel/Controls/ClearButton.pressed.connect(_on_clear_pressed)
	$HUD/Panel/Controls/ModeButton.pressed.connect(_on_mode_pressed)
	$HUD/Panel/Controls/LifetimeSelector/LifetimePrev.pressed.connect(_on_lifetime_prev)
	$HUD/Panel/Controls/LifetimeSelector/LifetimeNext.pressed.connect(_on_lifetime_next)
	$HUD/Panel/Controls/TypeSelector/TypePrev.pressed.connect(_on_type_prev)
	$HUD/Panel/Controls/TypeSelector/TypeNext.pressed.connect(_on_type_next)
	_refresh_ui()
	_set_status("Click a tile to spawn a loot item — watch it blink before despawning")


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_spawn_at_click(event.position)
		get_viewport().set_input_as_handled()


func _spawn_at_click(screen_pos: Vector2):
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var t := -from.y / dir.y if dir.y < -0.0001 else -1.0
	if t < 0.0:
		return
	var world := from + dir * t
	var snapped := Vector3(
		clampi(roundi(world.x), -grid.width / 2, grid.width / 2 - 1) + 0.5,
		ITEM_Y,
		clampi(roundi(world.z), -grid.depth / 2, grid.depth / 2 - 1) + 0.5
	)
	var item = load(LOOT_SCENE).instantiate()
	var p: Dictionary = PRESETS[preset_index]
	item.item_name = p.name
	item.body_color = p.color
	item.value = p.value
	item.pickup_mode = pickup_mode
	item.lifetime = LIFETIME_CHOICES[lifetime_index]
	item.position = snapped
	add_child(item)
	item.picked_up.connect(_on_item_picked_up)
	on_ground += 1
	_refresh_ui()
	_set_status("Spawned %s — despawns in %s" % [p.name, _lifetime_label()])


func _on_item_picked_up(_item: Node3D):
	on_ground -= 1
	_refresh_ui()
	_set_status("Picked up an item")


func _on_clear_pressed():
	for item in get_tree().get_nodes_in_group("loot"):
		item.queue_free()
	on_ground = 0
	_refresh_ui()
	_set_status("Cleared all items")


func _on_mode_pressed():
	pickup_mode = 1 - pickup_mode
	_refresh_ui()


func _on_lifetime_prev():
	lifetime_index = (lifetime_index - 1 + LIFETIME_CHOICES.size()) % LIFETIME_CHOICES.size()
	_refresh_ui()


func _on_lifetime_next():
	lifetime_index = (lifetime_index + 1) % LIFETIME_CHOICES.size()
	_refresh_ui()


func _on_type_prev():
	preset_index = (preset_index - 1 + PRESETS.size()) % PRESETS.size()
	_refresh_ui()


func _on_type_next():
	preset_index = (preset_index + 1) % PRESETS.size()
	_refresh_ui()


func _lifetime_label() -> String:
	var l: float = LIFETIME_CHOICES[lifetime_index]
	return "never" if l <= 0.0 else "%.1fs" % l


func _refresh_ui():
	($HUD/Panel/Controls/LifetimeSelector/LifetimeValue as Label).text = _lifetime_label()
	($HUD/Panel/Controls/TypeSelector/TypeValue as Label).text = PRESETS[preset_index].name
	($HUD/Panel/Controls/ModeButton as Button).text = "Pickup: Auto" if pickup_mode == 0 else "Pickup: Key (E)"
	($HUD/OnGroundLabel as Label).text = "On ground: %d" % on_ground


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
