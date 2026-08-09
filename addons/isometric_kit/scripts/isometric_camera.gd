## Orthographic isometric camera that auto-fits a map.
##
## Call `setup()` (also done in `_ready()`) to apply orthographic projection and
## position the camera above `target_center` at the configured `angle`/`yaw`.
## The frustum size fits either the referenced `map`'s world size or `fit_size`.
##
## Note: `distance` only affects near-plane clipping, not the image. It is
## clamped so the frustum's bottom stays above the ground plane, avoiding a
## clear-color band along the bottom of the view.
extends Camera3D

## Map node whose `get_world_size()` is used for auto-fit (ignored if `fit_size` is set).
@export var map: Node3D

## Elevation of the camera above the ground plane, in degrees.
@export var angle := 35.0

## Rotation of the camera around the vertical axis, in degrees (45 = classic iso).
@export var yaw := 45.0

## Distance from `target_center` to the camera. `setup()` overrides this.
@export var distance := 14.0

## World size to fit instead of `map`'s size. `Vector2.ZERO` = use the map.
@export var fit_size := Vector2.ZERO

var target_center := Vector3.ZERO
## The world point the camera looks at.


func _ready():
	setup()


## Apply ortho projection, compute the frustum size, and position the camera.
## Call this after changing `fit_size`/`map`/`angle`/`yaw`/`target_center`.
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


## Frustum height (`size`) that fits `world_size` at this viewport's aspect
## ratio, with 5% margin.
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
