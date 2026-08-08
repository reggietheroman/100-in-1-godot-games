extends CharacterBody3D

@export var move_speed := 3.0
@export var body_color := Color(1.0, 0.2, 0.2)
@export var stop_distance := 0.1

var target := Vector3.ZERO
var reached_rally := false

@onready var mesh_instance: MeshInstance3D = $Body

var gravity := 20.0

signal reached_rally_point


func _ready():
	add_to_group("enemy")
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
