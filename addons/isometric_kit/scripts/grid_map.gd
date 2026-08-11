## Checkerboard grid map with optional blocking walls.
##
## Builds a flat checkerboard of `width` × `depth` square tiles (1 unit each by
## default). Tiles are `StaticBody3D` boxes so they act as a floor. Set walls
## with `set_wall(x, z, height)` before calling `build()`. `build()` (re)creates
## all tiles and walls; call it whenever you change `width`/`depth` or the wall
## map. `get_world_size()` reports the map extents for the camera to auto-fit.
##
## Coordinates: tile (x, z) centers on `(x - width/2 + 0.5, z - depth/2 + 0.5)`.
extends Node3D

## Number of tiles along X.
@export var width := 12

## Number of tiles along Z.
@export var depth := 12

## Tile edge length in world units. Player/enemies expect 1.0.
@export var tile_size := 1.0

## Tile slab thickness (how high the floor boxes are).
@export var tile_height := 0.1

## Color of "light" checkerboard tiles.
@export var color_a := Color(0.85, 0.85, 0.85)

## Color of "dark" checkerboard tiles.
@export var color_b := Color(0.55, 0.55, 0.6)

## Color of wall boxes.
@export var wall_color := Color(0.45, 0.35, 0.3)

var tiles: Array[StaticBody3D] = []

## Wall bodies currently in the scene (rebuilt by `build()`).
var wall_bodies: Array[StaticBody3D] = []

## The wall map: `Vector2i(x, z)` → height. Set with `set_wall()` / `clear_walls()`.
var walls: Dictionary = {}


func _ready():
	build()


func build():
	for t in tiles:
		t.queue_free()
	tiles.clear()
	for w in wall_bodies:
		w.queue_free()
	wall_bodies.clear()

	for z in depth:
		for x in width:
			var checker := (x + z) % 2 == 0

			var body := StaticBody3D.new()
			var tile := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(tile_size, tile_height, tile_size)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = color_a if checker else color_b
			mesh.material = mat
			tile.mesh = mesh

			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(tile_size, tile_height, tile_size)
			shape.shape = box

			var pos := Vector3(
				(x - width / 2.0 + 0.5) * tile_size,
				0.0,
				(z - depth / 2.0 + 0.5) * tile_size
			)
			body.position = pos
			tile.position = Vector3(0, tile_height / 2.0, 0)
			shape.position = Vector3(0, tile_height / 2.0, 0)

			body.add_child(tile)
			body.add_child(shape)
			add_child(body)
			tiles.append(body)

	_build_walls()


## Mark tile (x, z) as a wall of the given height. Use `height <= 0` to remove.
func set_wall(x: int, z: int, height: float):
	var key := Vector2i(x, z)
	if height <= 0.0:
		walls.erase(key)
	else:
		walls[key] = height


## Remove every wall from the map.
func clear_walls():
	walls.clear()


## Rebuild only the wall bodies after `set_wall()` / `clear_walls()` changes,
## without recreating the floor tiles. Use `build()` when `width`/`depth`
## change too.
func rebuild_walls():
	for w in wall_bodies:
		w.queue_free()
	wall_bodies.clear()
	_build_walls()


## Whether tile (x, z) is currently a wall.
func is_wall(x: int, z: int) -> bool:
	return walls.has(Vector2i(x, z))


func _build_walls():
	for key in walls:
		var h := walls[key] as float
		var body := StaticBody3D.new()
		body.add_to_group("wall")
		var wall := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(tile_size, h, tile_size)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = wall_color
		mesh.material = mat
		wall.mesh = mesh

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(tile_size, h, tile_size)
		shape.shape = box

		body.position = Vector3(
			(key.x - width / 2.0 + 0.5) * tile_size,
			tile_height + h / 2.0,
			(key.y - depth / 2.0 + 0.5) * tile_size
		)
		body.add_child(wall)
		body.add_child(shape)
		add_child(body)
		wall_bodies.append(body)


## World-space map extents as `(width, depth) * tile_size`.
func get_world_size() -> Vector2:
	return Vector2(width, depth) * tile_size


func get_center() -> Vector3:
	return Vector3.ZERO
