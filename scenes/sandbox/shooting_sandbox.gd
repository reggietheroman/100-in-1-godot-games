extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var player_move_speed := 4.0
@export var player_start := Vector3(0, 0.6, 0)
@export var enemy_count := 5
@export var projectile_speed := 18.0
@export var fire_interval := 0.4
@export var projectile_scene: PackedScene
@export var enemy_scene: PackedScene

const TILE_Y := 0.6
const MIN_TARGET_DIST := 2.5
const FIRE_RATE_MIN := 0.1
const FIRE_RATE_MAX := 3.0
const FIRE_RATE_STEP := 0.1
const BOUNDARY_WALL_H := 1.5

var hits := 0
var auto_fire := false
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
	$HUD/FireButton.pressed.connect(_fire)
	$HUD/ShootPanel/ShootControls/AutoFireButton.pressed.connect(_on_auto_fire_pressed)
	$HUD/ShootPanel/ShootControls/FireRateSelector/FireRatePrev.pressed.connect(_on_fire_rate_prev)
	$HUD/ShootPanel/ShootControls/FireRateSelector/FireRateNext.pressed.connect(_on_fire_rate_next)

	_spawn_enemies()
	_refresh_hud()
	_refresh_fire_ui()
	_set_status("Move with WASD/joystick — Space or Fire to shoot — walls block projectiles")


func _process(delta):
	_cooldown = maxf(_cooldown - delta, 0.0)
	if auto_fire and _cooldown <= 0.0 and _nearest_enemy() != null:
		_fire(true)


func _unhandled_input(event):
	if event.is_action_pressed("shoot"):
		_fire()


func _fire(quiet := false):
	if _cooldown > 0.0:
		return
	var enemy := _nearest_enemy()
	if enemy == null:
		if not quiet:
			_set_status("No enemies to target")
		return
	var from := player.global_position + Vector3(0, 0.4, 0)
	var dir := enemy.global_position - from
	dir.y = 0.0
	dir = dir.normalized()

	var projectile := projectile_scene.instantiate()
	projectile.speed = projectile_speed
	projectile.direction = dir
	projectile.position = from
	add_child(projectile)
	projectile.hit.connect(_on_projectile_hit)
	_cooldown = fire_interval
	if not quiet:
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
	hits += 1
	enemy.queue_free()
	_spawn_enemy()
	_refresh_hud()
	_set_status("Hit! %d total hits" % hits)


func _on_auto_fire_pressed():
	auto_fire = not auto_fire
	_refresh_fire_ui()


func _on_fire_rate_prev():
	fire_interval = maxf(fire_interval - FIRE_RATE_STEP, FIRE_RATE_MIN)
	_refresh_fire_ui()


func _on_fire_rate_next():
	fire_interval = minf(fire_interval + FIRE_RATE_STEP, FIRE_RATE_MAX)
	_refresh_fire_ui()


func _refresh_fire_ui():
	($HUD/ShootPanel/ShootControls/AutoFireButton as Button).text = "Auto-Fire: ON" if auto_fire else "Auto-Fire: OFF"
	($HUD/ShootPanel/ShootControls/FireRateLabel as Label).text = "Fire rate: %.1fs" % fire_interval
	($HUD/ShootPanel/ShootControls/FireRateSelector/FireRateValue as Label).text = "%.1fs" % fire_interval


func _tile_center(x: int, z: int) -> Vector2:
	return VisibleFootprint.tile_center(grid, x, z)


func _inside_footprint(p: Vector2) -> bool:
	return VisibleFootprint.inside(_boundary_pts, p)


func _spawn_enemies():
	for i in enemy_count:
		_spawn_enemy()


func _spawn_enemy():
	var enemy := enemy_scene.instantiate()
	enemy.position = _random_free_tile()
	add_child(enemy)
	enemy.target = enemy.global_position


func _random_free_tile() -> Vector3:
	for attempt in 1000:
		var x := randi_range(0, grid.width - 1)
		var z := randi_range(0, grid.depth - 1)
		if grid.is_wall(x, z):
			continue
		var center := _tile_center(x, z)
		if not _inside_footprint(center):
			continue
		var pos := Vector3(center.x, TILE_Y, center.y)
		if pos.distance_to(player.global_position) < MIN_TARGET_DIST:
			continue
		var blocked := false
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy.global_position.distance_to(pos) < 1.0:
				blocked = true
				break
		if not blocked:
			return pos
	return player_start


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")


func _refresh_hud():
	($HUD/HitLabel as Label).text = "Hits: %d" % hits


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
