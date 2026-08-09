extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")
const ENEMY_SCENE := "res://addons/isometric_kit/scenes/enemy.tscn"
const LOOT_SCENE := "res://addons/isometric_kit/scenes/loot_item.tscn"
const PROJECTILE_SCENE := "res://addons/isometric_kit/scenes/projectile.tscn"

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var player_move_speed := 4.0
@export var player_start := Vector3(0, 0.6, 0)
@export var enemy_count := 4
@export var projectile_speed := 18.0
@export var fire_interval := 0.4

const BOUNDARY_WALL_H := 1.5
const TILE_Y := 0.6
const MIN_PLAYER_DIST := 2.0

var kills := 0
var loot_collected := 0
var _cooldown := 0.0
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
	get_tree().node_added.connect(_on_node_added)
	for i in enemy_count:
		_spawn_enemy()
	_refresh_hud()
	_set_status("Click or shoot (Space) an enemy to kill it — loot drops where it fell")


func _process(delta):
	_cooldown = maxf(_cooldown - delta, 0.0)


func _spawn_enemy():
	var enemy = load(ENEMY_SCENE).instantiate()
	enemy.position = _random_free_tile()
	enemy.loot_scene = load(LOOT_SCENE)
	add_child(enemy)
	enemy.target = enemy.global_position


func _random_free_tile() -> Vector3:
	for attempt in 1000:
		var x := randi_range(0, grid.width - 1)
		var z := randi_range(0, grid.depth - 1)
		if grid.is_wall(x, z):
			continue
		var c := VisibleFootprint.tile_center(grid, x, z)
		if not VisibleFootprint.inside(_boundary_pts, c):
			continue
		var pos := Vector3(c.x, TILE_Y, c.y)
		if pos.distance_to(player.global_position) < MIN_PLAYER_DIST:
			continue
		return pos
	return Vector3(0, TILE_Y, 0)


func _unhandled_input(event):
	if event.is_action_pressed("shoot"):
		_fire()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_kill_at_click(event.position)
		get_viewport().set_input_as_handled()


func _fire():
	if _cooldown > 0.0:
		return
	var enemy := _nearest_enemy()
	if enemy == null:
		_set_status("No enemies to target")
		return
	var from := player.global_position + Vector3(0, 0.4, 0)
	var dir := enemy.global_position - from
	dir.y = 0.0
	dir = dir.normalized()
	var projectile = load(PROJECTILE_SCENE).instantiate()
	projectile.speed = projectile_speed
	projectile.direction = dir
	projectile.position = from
	add_child(projectile)
	projectile.hit.connect(_on_projectile_hit)
	_cooldown = fire_interval
	_set_status("Fired at %s" % enemy.name)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d: float = enemy.global_position.distance_squared_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _on_projectile_hit(enemy: Node3D):
	_kill(enemy)
	_set_status("Shot an enemy — loot dropped")


func _kill_at_click(screen_pos: Vector2):
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var params := PhysicsRayQueryParameters3D.create(from, from + dir * 100.0)
	var result := get_world_3d().direct_space_state.intersect_ray(params)
	if result.is_empty():
		_set_status("Click an enemy")
		return
	var collider = result.collider
	if collider == null or not collider.is_in_group("enemy"):
		_set_status("That's not an enemy — click a red capsule")
		return
	_kill(collider)
	_set_status("Enemy killed — loot dropped")


func _kill(enemy: Node3D):
	kills += 1
	enemy.die()
	_spawn_enemy()
	_refresh_hud()


func _on_node_added(node: Node):
	if node.get("pickup_mode") == null:
		return
	if not node.picked_up.is_connected(_on_loot_picked_up):
		node.picked_up.connect(_on_loot_picked_up)


func _on_loot_picked_up(_item: Node3D):
	loot_collected += 1
	_refresh_hud()
	_set_status("Collected the dropped loot")


func _refresh_hud():
	($HUD/KillsLabel as Label).text = "Kills: %d" % kills
	($HUD/LootLabel as Label).text = "Loot collected: %d" % loot_collected


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
