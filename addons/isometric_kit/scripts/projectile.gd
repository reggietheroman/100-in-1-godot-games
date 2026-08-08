extends Area3D

@export var speed := 18.0
@export var lifetime := 3.0
@export var body_color := Color(1.0, 0.8, 0.2)

var direction := Vector3.FORWARD

signal hit(enemy: Node3D)

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
