## Projectile that flies toward a target and reports hits.
##
## An `Area3D` that moves along `direction` at `speed`. Emits `hit(enemy)` when
## it touches an "enemy"-group body (and despawns), and despawns on "wall"-group
## bodies or after `lifetime` seconds. On an enemy hit it also applies `damage`
## to that enemy (via `take_damage`, if present) and, when `splash_radius` is
## set, to every other enemy within that radius of the impact point — so a
## shooter can configure both single-target and area damage. Add the
## `projectile.tscn` scene at the muzzle position, set `direction`, and connect
## to `hit`.
extends Area3D

## Movement speed in units/second.
@export var speed := 18.0

## Max lifespan in seconds before the projectile despawns.
@export var lifetime := 3.0

## Tint of the projectile mesh.
@export var body_color := Color(1.0, 0.8, 0.2)

## Damage dealt to the hit enemy (and, with `splash_radius`, to enemies nearby).
@export var damage := 1

## Radius of area damage around the impact point. 0 = single target only.
@export var splash_radius := 0.0

## Fired (with the enemy body) when the projectile touches an "enemy"-group body.
signal hit(enemy: Node3D)

## Unit direction to fly in. Set after instantiation.
var direction := Vector3.FORWARD

@onready var mesh_instance: MeshInstance3D = $Mesh

var _elapsed := 0.0


func _ready():
	add_to_group("projectile")
	body_entered.connect(_on_body_entered)
	_apply_color()


func _physics_process(delta: float):
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta


func _on_body_entered(body: Node3D):
	if body.is_in_group("enemy"):
		hit.emit(body)
		_apply_damage(body)
		queue_free()
	elif body.is_in_group("wall"):
		queue_free()


## Applies `damage` to the hit enemy and, with a splash radius, to every enemy
## within that radius of the impact point (the hit enemy is not double-counted).
func _apply_damage(enemy: Node3D):
	if not _can_damage(enemy):
		return
	enemy.take_damage(damage)
	if splash_radius > 0.0:
		var impact := global_position
		for node in get_tree().get_nodes_in_group("enemy"):
			if node == enemy or not _can_damage(node):
				continue
			if node.global_position.distance_to(impact) <= splash_radius:
				node.take_damage(damage)


func _can_damage(enemy: Node3D) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("take_damage")


func _apply_color():
	if mesh_instance == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mesh_instance.material_override = mat
