## Static helpers for building a grid map that fills the camera's view.
##
## These functions compute the camera's visible ground footprint (the polygon
## where the viewport corners project onto the y=0 plane) and configure a
## `grid_map.gd` to cover it, marking boundary tiles as walls so the play area
## fills the whole screen. No instance needed — call the statics directly:
## `VisibleFootprint.configure_map(grid, camera, padding, wall_height)` before
## `grid.build()`.
##
## Important: Godot 4's `camera.size` is the *full* ortho frustum height, so the
## true half-height is `size / 2`. Using `size` as a half-extent is the classic
## mistake this helper avoids.
class_name VisibleFootprint
extends RefCounted

const DEFAULT_WALL_HEIGHT := 1.5

## Sizes the grid to cover the camera's visible ground footprint (the
## projection of the viewport onto the y=0 plane) plus padding, then marks
## boundary tiles around that footprint as walls. Call before grid.build().
## Returns the footprint polygon points.
static func configure_map(grid: Node, camera: Camera3D, padding: int, wall_height: float = DEFAULT_WALL_HEIGHT) -> Array:
	var pts := ground_footprint(camera)
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p: Vector2 in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.y)
		max_z = maxf(max_z, p.y)
	var half_x := maxf(-min_x, max_x) + float(padding)
	var half_z := maxf(-min_z, max_z) + float(padding)
	grid.width = maxi(4, int(ceil(half_x * 2.0)))
	grid.depth = maxi(4, int(ceil(half_z * 2.0)))
	grid.clear_walls()
	for x in grid.width:
		for z in grid.depth:
			if is_boundary_wall(grid, pts, x, z):
				grid.set_wall(x, z, wall_height)
	return pts


## The four ground points (as Vector2 x/z) where the viewport corners project
## onto the y=0 plane. camera.size is the full ortho frustum height in Godot 4,
## so the true half-height is size / 2.
static func ground_footprint(camera: Camera3D) -> Array:
	var fwd: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	var cam_up: Vector3 = camera.global_transform.basis.y
	var half_h: float = camera.size * 0.5
	var half_w: float = camera.size * 0.5 * camera.get_viewport().get_visible_rect().size.aspect()
	var cam_pos: Vector3 = camera.global_position
	var offsets := [
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
		Vector2(half_w, half_h), Vector2(-half_w, half_h),
	]
	var pts := []
	for off: Vector2 in offsets:
		var origin: Vector3 = cam_pos + right * off.x + cam_up * off.y
		var t: float = (0.0 - origin.y) / fwd.y
		var g: Vector3 = origin + fwd * t
		pts.append(Vector2(g.x, g.z))
	return pts


## Winding-consistent point-in-convex-polygon test for the footprint.
static func inside(points: Array, p: Vector2) -> bool:
	var sign_val := 0.0
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var cross: float = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
		if absf(cross) < 0.001:
			continue
		if sign_val == 0.0:
			sign_val = cross
		elif (cross > 0.0) != (sign_val > 0.0):
			return false
	return true


## World position (as Vector2 x/z) of the center of tile (x, z) on the grid.
static func tile_center(grid: Node, x: int, z: int) -> Vector2:
	return Vector2(x - grid.width / 2.0 + 0.5, z - grid.depth / 2.0 + 0.5)


## True for a tile inside the footprint that touches a tile outside it
## (or the grid edge), i.e. a ring hugging the visible footprint boundary.
static func is_boundary_wall(grid: Node, points: Array, x: int, z: int) -> bool:
	var center := tile_center(grid, x, z)
	if not inside(points, center):
		return false
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var nx := x + dx
			var nz := z + dz
			if nx < 0 or nx >= grid.width or nz < 0 or nz >= grid.depth:
				return true
			if not inside(points, tile_center(grid, nx, nz)):
				return true
	return false
