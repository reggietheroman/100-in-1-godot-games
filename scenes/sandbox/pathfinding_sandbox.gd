extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")
const NavmeshBaker := preload("res://addons/isometric_kit/scripts/navmesh_baker.gd")

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var spawn_point := Vector3(-4.5, 0.6, 4.5)
@export var rally_point := Vector3(4.5, 0.6, -4.5)
@export var enemy_count := 5
@export var wall_height := 1.5
@export var agent_radius := 0.4

## Extra walls in the middle of the map, in tile coordinates (x, z). Leave
## empty for the default pattern centered on the map (a wall line with a gap
## plus two blocks that force a detour). Boundary walls around the play area
## are always added regardless.
@export var middle_walls: Array[Vector2i] = []

const ENEMY_MIN := 1
const ENEMY_MAX := 20
const BOUNDARY_WALL_H := 1.5

var picking: String = ""

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var nav_region: NavigationRegion3D = $GridMap/NavRegion
@onready var spawner: Node3D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var start_button: Button = $HUD/Panel/Controls/StartButton

var spawn_marker: Node3D
var rally_marker: Node3D


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	_apply_middle_walls()
	grid.build()
	_rebake_navmesh()

	# Snap the exported defaults to the actual tile grid (the map size is
	# computed from the camera footprint, so dev-authored coordinates that
	# assumed a 12x12 grid can land on tile corners, which the eroded navmesh
	# doesn't cover and a nav agent can never finish on).
	spawn_point = _snap_to_tile(spawn_point)
	rally_point = _snap_to_tile(rally_point)

	spawner.spawn_point = spawn_point
	spawner.rally_point = rally_point
	spawner.wave_size = enemy_count
	spawner.max_waves = 1
	spawner.wave_interval = 0.0

	spawner.wave_spawned.connect(_on_wave_spawned)
	spawner.all_enemies_reached_rally.connect(_on_all_reached)
	spawner.waves_finished.connect(_on_waves_finished)

	$HUD/BackButton.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	$HUD/Panel/Controls/ResetButton.pressed.connect(_on_reset_pressed)
	$HUD/Panel/Controls/SetSpawnButton.pressed.connect(_on_set_spawn_pressed)
	$HUD/Panel/Controls/SetRallyButton.pressed.connect(_on_set_rally_pressed)
	$HUD/Panel/Controls/SetWallsButton.pressed.connect(_on_set_walls_pressed)
	$HUD/Panel/Controls/EnemyCountSelector/EnemyCountPrev.pressed.connect(_on_enemy_count_prev)
	$HUD/Panel/Controls/EnemyCountSelector/EnemyCountNext.pressed.connect(_on_enemy_count_next)

	_refresh_count_labels()
	_set_markers()
	_set_status("Set spawn / rally / walls, then click Spawn Enemies")


func _unhandled_input(event):
	if picking == "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_point(event.position)
		get_viewport().set_input_as_handled()


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/sandbox_menu.tscn")


func _on_start_pressed():
	picking = ""
	spawner.clear()
	spawner.wave_size = enemy_count
	spawner.start()
	_set_status("Spawned %d enemies — pathfinding to the rally point" % enemy_count)


func _on_reset_pressed():
	picking = ""
	spawner.clear()
	_set_status("Enemies cleared")


func _on_set_spawn_pressed():
	_reset_picking()
	picking = "spawn"
	_set_status("Click a tile to set the spawn point")


func _on_set_rally_pressed():
	_reset_picking()
	picking = "rally"
	_set_status("Click a tile to set the rally point")


func _on_set_walls_pressed():
	if picking == "walls":
		picking = ""
		_set_status("Wall editing off")
		return
	_reset_picking()
	picking = "walls"
	_set_status("Click tiles to toggle walls — navmesh rebakes live (click Set Walls to stop)")


func _on_enemy_count_prev():
	enemy_count = maxi(enemy_count - 1, ENEMY_MIN)
	_refresh_count_labels()


func _on_enemy_count_next():
	enemy_count = mini(enemy_count + 1, ENEMY_MAX)
	_refresh_count_labels()


func _refresh_count_labels():
	($HUD/Panel/Controls/EnemyCountSelector/EnemyCountValue as Label).text = str(enemy_count)
	($HUD/Panel/Controls/EnemyCountLabel as Label).text = "Enemies: " + str(enemy_count)


func _pick_point(screen_pos: Vector2):
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var t := -from.y / dir.y if dir.y < -0.0001 else -1.0
	if t < 0.0:
		return
	var world := from + dir * t
	var snapped := _snap_to_tile(world)
	var tile := _world_to_tile(world)
	if picking == "spawn":
		if grid.is_wall(tile.x, tile.y):
			_set_status("Can't place the spawn point on a wall")
			picking = ""
			return
		spawn_point = snapped
		spawner.spawn_point = snapped
		_update_marker(spawn_marker, snapped)
		_set_status("Spawn point set to (%d, %d)" % [snapped.x, snapped.z])
		picking = ""
	elif picking == "rally":
		if grid.is_wall(tile.x, tile.y):
			_set_status("Can't place the rally point on a wall")
			picking = ""
			return
		rally_point = snapped
		spawner.rally_point = snapped
		_update_marker(rally_marker, snapped)
		_set_status("Rally point set to (%d, %d)" % [snapped.x, snapped.z])
		picking = ""
	elif picking == "walls":
		_toggle_wall(tile)
		_set_status("Toggled wall at (%d, %d)" % [tile.x, tile.y])


func _world_to_tile(world: Vector3) -> Vector2i:
	var x := clampi(roundi(world.x + grid.width / 2.0 - 0.5), 0, grid.width - 1)
	var z := clampi(roundi(world.z + grid.depth / 2.0 - 0.5), 0, grid.depth - 1)
	return Vector2i(x, z)


func _snap_to_tile(world: Vector3) -> Vector3:
	var tile := _world_to_tile(world)
	return Vector3(tile.x - grid.width / 2.0 + 0.5, 0.6, tile.y - grid.depth / 2.0 + 0.5)


func _toggle_wall(tile: Vector2i):
	if grid.is_wall(tile.x, tile.y):
		grid.set_wall(tile.x, tile.y, 0.0)
	else:
		grid.set_wall(tile.x, tile.y, wall_height)
	grid.rebuild_walls()
	_rebake_navmesh()


func _reset_picking():
	picking = ""
	spawner.clear()


## Places the configured middle walls. Empty list = default centered pattern:
## a wall line with a gap at the center plus two blocks that make the spawn →
## rally route detour around them.
func _apply_middle_walls():
	if middle_walls.is_empty():
		var cx: int = grid.width / 2
		var cz: int = grid.depth / 2
		for dz in [-5, -4, -3, 3, 4, 5]:
			grid.set_wall(cx, cz + dz, wall_height)
		grid.set_wall(cx - 4, cz, wall_height)
		grid.set_wall(cx + 4, cz, wall_height)
		return
	for tile in middle_walls:
		if tile.x >= 0 and tile.x < grid.width and tile.y >= 0 and tile.y < grid.depth:
			grid.set_wall(tile.x, tile.y, wall_height)


## Bakes the grid's floor + walls into a fresh navmesh and assigns it to the
## region. The grid must be inside the tree (it is — we're past `_ready`).
func _rebake_navmesh():
	nav_region.navigation_mesh = NavmeshBaker.bake_from_grid(grid, agent_radius)


func _reset_waves():
	spawner.clear()


func _set_markers():
	spawn_marker = _make_circle_marker(Color(0, 1, 1, 0.35))
	add_child(spawn_marker)
	rally_marker = _make_circle_marker(Color(1, 1, 0, 0.35))
	add_child(rally_marker)
	_update_marker(spawn_marker, spawn_point)
	_update_marker(rally_marker, rally_point)


func _update_marker(marker: Node3D, point: Vector3):
	marker.position = Vector3(point.x, 0.08, point.z)


func _make_circle_marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	marker.mesh = mesh
	return marker


func _on_wave_spawned(wave: int, count: int):
	_set_status("Wave %d spawned (%d enemies) — walking to rally point" % [wave, count])


func _on_all_reached():
	_set_status("All enemies reached the rally point")


func _on_waves_finished():
	_set_status("Wave finished")


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
