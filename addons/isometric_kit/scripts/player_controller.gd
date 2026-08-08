extends CharacterBody3D

@export var move_speed := 4.0
@export var acceleration := 12.0
@export var body_color := Color(0.2, 0.45, 1.0)
@export var joystick: Control

@onready var mesh_instance: MeshInstance3D = $Body

var gravity := 20.0


func _ready():
	add_to_group("player")
	_apply_color()


func _physics_process(delta: float):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input := _read_input()
	var cam := get_viewport().get_camera_3d()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var dir := (right * input.x - fwd * input.y)
	if dir.length_squared() > 0.0:
		dir = dir.normalized()

	var target := Vector3(dir.x * move_speed, velocity.y, dir.z * move_speed)
	velocity = velocity.lerp(target, minf(acceleration * delta, 1.0))
	move_and_slide()


func _read_input() -> Vector2:
	if joystick == null:
		joystick = get_tree().get_first_node_in_group("joystick")
	if joystick != null and joystick.get("vector") != Vector2.ZERO:
		return joystick.vector
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _apply_color():
	if mesh_instance == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mesh_instance.material_override = mat
