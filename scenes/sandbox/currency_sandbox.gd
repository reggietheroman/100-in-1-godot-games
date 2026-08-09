extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")
const ENEMY_SCENE := "res://addons/isometric_kit/scenes/enemy.tscn"
const LOOT_SCENE := "res://addons/isometric_kit/scenes/loot_item.tscn"
const PROJECTILE_SCENE := "res://addons/isometric_kit/scenes/projectile.tscn"
const DEPOSIT_SCENE := "res://addons/isometric_kit/scenes/currency_deposit.tscn"

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var player_move_speed := 4.0
@export var wave_size := 5
@export var wave_interval := 8.0
@export var max_waves := 0
@export var projectile_speed := 18.0
@export var fire_interval := 0.4

@export var area_capacities := [10, 25, 50]
@export var deposit_offsets := [
	Vector3(-3.2, 0, -3.2),
	Vector3(3.2, 0, -3.2),
	Vector3(0, 0, 3.2),
]
@export var spawn_offset := Vector3(-4.2, 0, 3.2)
@export var rally_offset := Vector3(-4.2, 0, 1.0)

const BOUNDARY_WALL_H := 1.5
const TILE_Y := 0.6

var kills := 0
var loot_collected := 0
var _cooldown := 0.0
var _map_center := Vector3.ZERO

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var player: CharacterBody3D = $Player
@onready var spawner: Node3D = $Spawner
@onready var wallet: Node3D = $Player/CurrencyWallet


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	grid.build()
	_map_center = _compute_map_center()

	player.move_speed = player_move_speed
	player.position = _map_center

	spawner.enemy_scene = load(ENEMY_SCENE)
	spawner.spawn_point = _map_center + spawn_offset
	spawner.rally_point = _map_center + rally_offset
	spawner.wave_size = wave_size
	spawner.wave_interval = wave_interval
	spawner.max_waves = max_waves

	for i in area_capacities.size():
		var area = load(DEPOSIT_SCENE).instantiate()
		area.name = "DepositArea%d" % (i + 1)
		area.display_name = "Bank"
		area.capacity = area_capacities[i]
		area.position = _map_center + deposit_offsets[i]
		add_child(area)
		area.deposited_changed.connect(_on_deposited_changed)

	$HUD/BackButton.pressed.connect(_on_back_pressed)
	get_tree().node_added.connect(_on_node_added)
	spawner.start()
	_refresh_hud()
	_set_status("Shoot/click enemies for loot, then stand on a bank to deposit your currency")


func _process(delta):
	_cooldown = maxf(_cooldown - delta, 0.0)


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
	_refresh_hud()


func _on_node_added(node: Node):
	if node.has_method("die") and node.loot_scene == null:
		node.loot_scene = load(LOOT_SCENE)
	if node.get("pickup_mode") != null and not node.picked_up.is_connected(_on_loot_picked_up):
		node.picked_up.connect(_on_loot_picked_up)


func _on_loot_picked_up(item: Node3D):
	var value: int = item.value if item.get("value") != null else 1
	loot_collected += 1
	wallet.add_currency(value)
	_refresh_hud()
	_set_status("Collected %+d currency" % value)


func _on_deposited_changed(deposited: int, capacity: int):
	_refresh_hud()
	if deposited >= capacity:
		_set_status("Bank full (%d/%d)" % [deposited, capacity])


func _refresh_hud():
	($HUD/CurrencyLabel as Label).text = "Currency: %d" % wallet.currency
	($HUD/KillsLabel as Label).text = "Kills: %d" % kills
	($HUD/LootLabel as Label).text = "Loot collected: %d" % loot_collected


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/sandbox_menu.tscn")


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
