## Projectile that flies toward a target and reports hits.
##
## An `Area3D` that moves along `direction` at `speed`. Emits `hit(enemy)` when
## it touches an "enemy"-group body (and despawns), and despawns on "wall"-group
## bodies or after `lifetime` seconds. Add the `projectile.tscn` scene at the
## muzzle position, set `direction`, and connect to `hit`.
extends Area3D

## Movement speed in units/second.
@export var speed := 18.0

## Max lifespan in seconds before the projectile despawns.
@export var lifetime := 3.0

## Tint of the projectile mesh.
@export var body_color := Color(1.0, 0.8, 0.2)

## Fired (with the enemy body) when the projectile touches an "enemy"-group body.
signal hit(enemy: Node3D)

## Unit direction to fly in. Set after instantiation.
var direction := Vector3.FORWARD

@onready var mesh_instance: MeshInstance3D = $Mesh

var _elapsed := 0.0


func _ready():
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
		queue_free()
	elif body.is_in_group("wall"):
		queue_free()


func _apply_color():
	if mesh_instance == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mesh_instance.material_override = mat
