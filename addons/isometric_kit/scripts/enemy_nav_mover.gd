## Enemy that pathfinds to a target over a navigation mesh.
##
## A `CharacterBody3D` that follows a `NavigationAgent3D` path toward `target`
## each physics frame and emits `reached_rally_point` when the path is done.
## Its public surface matches `enemy_mover.gd` (group "enemy", `take_damage()`,
## `die()`, optional loot drop), so spawners, towers, and trigger areas treat it
## identically — the only difference is that movement follows the navmesh
## instead of walking in a straight line.
##
## Set `target` before adding to the tree (the agent picks it up in `_ready`).
## The navmesh (and its region) must be inside the same `World3D`; the agent
## uses the world's default navigation map. See `navmesh_baker.gd` for baking a
## navmesh from a `grid_map.gd`.
##
## Collision: this enemy sits on collision layer 2 with mask 1 (the world on
## layer 1) — so it still collides with the floor, walls, and player, but walks
## through other enemies. `enemy_mover.gd` (layer 1) does not, and enemies that
## collide with each other pile up on the final path segment and block the
## navmesh finish check. Projectiles use mask 3 so they still hit layer-2
## enemies.
extends CharacterBody3D

const LootDrop := preload("res://addons/isometric_kit/scripts/loot_drop.gd")

## Horizontal movement speed in units/second.
@export var move_speed := 3.0

## Capsule tint. Enemies share the player model, differentiated by color.
@export var body_color := Color(1.0, 0.5, 0.2)

## Distance at which the final target is considered reached.
@export var stop_distance := 0.2

## Loot scene dropped when this enemy dies (see `die()`). Leave unset for
## enemies that drop nothing.
@export var loot_scene: PackedScene

## Health pool. `take_damage()` reduces it; reaching zero calls `die()`. The
## default (1) keeps the classic one-shot behavior.
@export var max_health := 1

## Emitted once the enemy gets within `stop_distance` of `target`.
signal reached_rally_point

## Emitted whenever the enemy takes damage (after `health` is reduced).
signal damaged(amount: int, health: int)

## Emitted exactly once when the enemy dies (with the enemy itself).
signal died(enemy: Node3D)

## Current health. Initialized to `max_health` in `_ready()`.
var health := 1

## Point to walk to. Set this before the node starts processing (e.g. in the
## spawner or right after instantiation).
var target := Vector3.ZERO

var reached_rally := false

var _dead := false

@onready var nav_agent: NavigationAgent3D = $NavAgent
@onready var mesh_instance: MeshInstance3D = $Body

var gravity := 20.0


func _ready():
	add_to_group("enemy")
	health = max_health
	_apply_color()
	nav_agent.path_desired_distance = 0.3
	nav_agent.target_desired_distance = stop_distance
	nav_agent.target_position = target


func _physics_process(delta):
	if reached_rally:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		reached_rally = true
		reached_rally_point.emit()
		return

	var next := _next_waypoint()
	var flat := next - global_position
	flat.y = 0.0
	if flat.length() <= 0.01:
		velocity = Vector3.ZERO
		return

	var dir := flat.normalized()
	var target_vel := Vector3(dir.x * move_speed, velocity.y, dir.z * move_speed)
	velocity = velocity.lerp(target_vel, minf(8.0 * delta, 1.0))
	move_and_slide()


## The next path waypoint ahead of this enemy, tracked with a persistent index.
## A navmesh path always starts at the projected start point, which can sit
## exactly on the enemy's XZ — naive `get_next_path_position()` progression then
## never moves off it. The index only ever moves forward, so once a waypoint is
## passed it is never targeted again (a distance-only scan would pick up
## waypoints left behind and oscillate).
const WAYPOINT_SKIP := 0.3

var _waypoints: PackedVector3Array = []
var _waypoint_index := 0


func _next_waypoint() -> Vector3:
	var path := nav_agent.get_current_navigation_path()
	if path.is_empty():
		return nav_agent.get_next_path_position()
	if path != _waypoints:
		_waypoints = path
		_waypoint_index = 0
	var pos := global_position
	while _waypoint_index < _waypoints.size() - 1:
		var wp := _waypoints[_waypoint_index]
		var to_wp := Vector3(wp.x - pos.x, 0.0, wp.z - pos.z)
		if to_wp.length() > WAYPOINT_SKIP:
			break
		_waypoint_index += 1
	return _waypoints[_waypoint_index]


func _apply_color():
	if mesh_instance == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mesh_instance.material_override = mat


## Reduces health by `amount`, emitting `damaged`, and kills the enemy when
## health reaches zero. Ignored once the enemy is dead.
func take_damage(amount: int):
	if _dead or amount <= 0:
		return
	health -= amount
	damaged.emit(amount, health)
	if health <= 0:
		die()


## Kills the enemy: drops its configured `loot_scene` at its position (if set)
## and removes it from the scene. Call this instead of `queue_free()` when the
## enemy should leave loot behind. Safe to call more than once (idempotent).
func die():
	if _dead:
		return
	_dead = true
	died.emit(self)
	var parent := get_parent()
	if loot_scene != null and parent != null:
		LootDrop.spawn(loot_scene, global_position, parent)
	queue_free()
