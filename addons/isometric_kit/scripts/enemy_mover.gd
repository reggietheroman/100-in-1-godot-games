## Enemy that walks to a target point and idles there.
##
## A `CharacterBody3D` that moves horizontally toward `target` each physics
## frame and emits `reached_rally_point` when it gets within `stop_distance`.
## Self-registers in the "enemy" group (so trigger areas, projectiles, and
## spawners can find it). Gravity is applied so it falls onto a ground plane.
extends CharacterBody3D

const LootDrop := preload("res://addons/isometric_kit/scripts/loot_drop.gd")

## Horizontal movement speed in units/second.
@export var move_speed := 3.0

## Capsule tint. Enemies share the player model, differentiated by color.
@export var body_color := Color(1.0, 0.2, 0.2)

## Distance at which the target is considered reached.
@export var stop_distance := 0.1

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

@onready var mesh_instance: MeshInstance3D = $Body

var gravity := 20.0


func _ready():
	add_to_group("enemy")
	health = max_health
	_apply_color()


func _physics_process(delta: float):
	if reached_rally:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var flat := target - global_position
	flat.y = 0.0
	if flat.length() <= stop_distance:
		velocity = Vector3.ZERO
		reached_rally = true
		reached_rally_point.emit()
		return

	var dir := flat.normalized()
	var target_vel := Vector3(dir.x * move_speed, velocity.y, dir.z * move_speed)
	velocity = velocity.lerp(target_vel, minf(8.0 * delta, 1.0))
	move_and_slide()


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
