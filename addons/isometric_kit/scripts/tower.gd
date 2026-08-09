## Defensive tower that automatically shoots enemies in range.
##
## A `Node3D` that finds the nearest "enemy"-group body within `range` (2D
## horizontal distance), rotates its `turret` child to aim at it, and fires
## `projectile_scene` from the `muzzle` child every `fire_interval` seconds.
## Each shot inherits the tower's `damage` and `splash_radius`, so one scene
## can be configured into many tower types (rapid, cannon, sniper, ...). The
## turret is only a visual aim; projectiles fly from the muzzle toward the
## target horizontally.
##
## Works standalone (drop it in a scene and place enemies nearby) or as a
## `build_site` structure: `apply_level(n)` upgrades the base stats from
## `level_stats`, so a site's tower gets stronger with each paid stage. Grouped
## "tower".
extends Node3D

const DEFAULT_PROJECTILE_SCENE := "res://addons/isometric_kit/scenes/projectile.tscn"

## Seconds between shots.
@export var fire_interval := 0.6

## Max horizontal distance to an enemy the tower will engage.
@export var range := 5.0

## Damage each shot deals to the primary enemy (and, with `splash_radius`, to
## enemies nearby).
@export var damage := 1

## Radius of area damage around the impact point. 0 = single target.
@export var splash_radius := 0.0

## Speed the projectiles fly at.
@export var projectile_speed := 18.0

## Scene to fire. Must expose `speed`/`direction`/`damage`/`splash_radius` and
## the `hit` signal (see `projectile.gd`).
@export var projectile_scene: PackedScene

## Group the tower targets (the "enemy" group by default).
@export var enemy_group := "enemy"

## Tint of the tower body.
@export var body_color := Color(0.4, 0.6, 1.0)

## Radians per second the turret turns while tracking a target.
@export var aim_speed := 8.0

## Per-level stat overrides, indexed `level - 1`. Each entry may override any
## of `fire_interval`/`range`/`damage`/`splash_radius`; a later level overrides
## the base (or the previous level's) values. Empty uses the base stats at
## every level.
@export var level_stats: Array[Dictionary] = []

## Optional per-level tint, indexed `level - 1`. Empty keeps `body_color`.
@export var level_colors: Array[Color] = []

## Fired (with the target) whenever the tower shoots.
signal fired(enemy: Node3D)

## Fired (with the enemy) when an enemy shot by this tower dies.
signal enemy_killed(enemy: Node3D)

## Current tower level (0 = base stats). Set by `apply_level()`.
var level := 0

## Rough height of the tower's visual, used by `build_site` to place
## celebrations above it.
var visual_height := 0.8

@onready var turret: Node3D = $Turret
@onready var muzzle: Node3D = $Turret/Muzzle

var _cooldown := 0.0
var _watched_ids: Dictionary = {}


func _ready():
	add_to_group("tower")
	if projectile_scene == null:
		projectile_scene = load(DEFAULT_PROJECTILE_SCENE)
	_apply_color()


## Disconnect from any enemies we watch so a freed tower never leaves dangling
## signal connections behind.
func _exit_tree():
	for tid in _watched_ids.keys():
		var target = instance_from_id(tid)
		if is_instance_valid(target) and target.has_signal("died") \
				and target.is_connected("died", _on_target_died):
			target.died.disconnect(_on_target_died)
	_watched_ids.clear()


func _physics_process(delta: float):
	if scale == Vector3.ZERO:
		return
	_cooldown -= delta
	var target := _acquire_target()
	if target == null:
		return
	_aim_at(target, delta)
	if _cooldown <= 0.0:
		_fire(target)
		_cooldown = fire_interval


## The nearest live "enemy"-group body within `range`, or null if none.
func _acquire_target() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	var pos := global_position
	for enemy in get_tree().get_nodes_in_group(enemy_group):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var flat: Vector3 = enemy.global_position - pos
		flat.y = 0.0
		var dist: float = flat.length()
		if dist <= range and dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _aim_at(target: Node3D, delta: float):
	if turret == null:
		return
	var dir := target.global_position - turret.global_position
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	var target_yaw := atan2(dir.x, dir.z)
	turret.rotation.y = lerp_angle(turret.rotation.y, target_yaw, minf(1.0, aim_speed * delta))


func _fire(target: Node3D):
	if projectile_scene == null or muzzle == null:
		return
	var projectile := projectile_scene.instantiate()
	var origin := muzzle.global_position
	get_parent().add_child(projectile)
	projectile.global_position = origin
	projectile.speed = projectile_speed
	projectile.damage = damage
	projectile.splash_radius = splash_radius
	var dir := target.global_position - origin
	dir.y = 0.0
	projectile.direction = dir.normalized()
	if target.has_signal("died") and not _watched_ids.has(target.get_instance_id()):
		target.died.connect(_on_target_died)
		_watched_ids[target.get_instance_id()] = true
	fired.emit(target)


## Applies the given level's stats and tint. `stats` may be empty to fall back
## on `level_stats`; either way a level's entry overrides the base stats.
func apply_level(target_level: int, stats: Dictionary = {}):
	level = target_level
	if stats.is_empty() and not level_stats.is_empty():
		stats = level_stats[mini(target_level - 1, level_stats.size() - 1)]
	if stats.has("fire_interval"):
		fire_interval = stats["fire_interval"]
	if stats.has("range"):
		range = stats["range"]
	if stats.has("damage"):
		damage = stats["damage"]
	if stats.has("splash_radius"):
		splash_radius = stats["splash_radius"]
	_apply_color()


func _on_target_died(enemy: Node3D):
	enemy_killed.emit(enemy)


func _apply_color():
	var color := body_color
	if level > 0 and not level_colors.is_empty():
		color = level_colors[mini(level - 1, level_colors.size() - 1)]
	var body := get_node_or_null("Body")
	if body is MeshInstance3D:
		body.material_override = _make_material(color)
	var barrel := get_node_or_null("Turret/Barrel")
	if barrel is MeshInstance3D:
		barrel.material_override = _make_material(color.darkened(0.35))


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color.darkened(0.2)
	return mat
