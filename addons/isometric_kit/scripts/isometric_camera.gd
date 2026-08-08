extends Camera3D

@export var map: Node3D
@export var angle := 35.0
@export var yaw := 45.0
@export var distance := 14.0
@export var fit_size := Vector2.ZERO

var target_center := Vector3.ZERO


func _ready():
	setup()


func setup():
	var world_size := _fit_world_size()

	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = ortho_size_for(world_size)
	distance = maxf(size * 0.9, maxf(world_size.x, world_size.y) * 0.9)
	global_position = target_center + _direction() * distance
	look_at(target_center, Vector3.UP)


func _fit_world_size() -> Vector2:
	if fit_size != Vector2.ZERO:
		return fit_size
	if map != null and map.has_method("get_world_size"):
		return map.get_world_size() as Vector2
	return Vector2(20, 20)


func ortho_size_for(world_size: Vector2) -> float:
	var half := maxf(world_size.x, world_size.y) / 2.0
	var diagonal := half * 2.0 * sqrt(2.0)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	return maxf(diagonal, diagonal / aspect) * 1.05


func _direction() -> Vector3:
	var pitch := deg_to_rad(angle)
	var yawn := deg_to_rad(yaw)
	return Vector3(
		cos(pitch) * sin(yawn),
		sin(pitch),
		cos(pitch) * cos(yawn)
	)
