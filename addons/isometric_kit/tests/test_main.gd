extends SceneTree
## Headless unit tests for the Isometric Kit addon.
##
## Run from the project root:
##     godot --headless --path . --script addons/isometric_kit/tests/test_main.gd
##
## Prints a pass/fail summary and exits nonzero on any failure. Pure logic (grid
## maps, footprint math, spawner wave counts, joystick vectors) is tested
## deterministically; physics-dependent behavior (enemy/player movement,
## projectile collisions) runs real physics frames against the addon's own
## scenes with a ground plane added (Jolt needs a floor to move bodies in
## headless mode).
##
## NOTE: GDScript lambdas capture local variables by value, so signal counters
## below use Arrays (a reference type) instead of reassigned integers.

var _passed := 0
var _failed := 0
var _failures: Array[String] = []

const ENEMY_SCENE := "res://addons/isometric_kit/scenes/enemy.tscn"
const PLAYER_SCENE := "res://addons/isometric_kit/scenes/player.tscn"
const CAMERA_SCENE := "res://addons/isometric_kit/scenes/isometric_camera.tscn"
const JOYSTICK_SCENE := "res://addons/isometric_kit/scenes/joystick.tscn"
const TRIGGER_SCENE := "res://addons/isometric_kit/scenes/trigger_area.tscn"
const PROJECTILE_SCENE := "res://addons/isometric_kit/scenes/projectile.tscn"
const GRID_SCRIPT := "res://addons/isometric_kit/scripts/grid_map.gd"
const SPAWNER_SCRIPT := "res://addons/isometric_kit/scripts/enemy_spawner.gd"


func _initialize():
	_run()


func _check(cond: bool, name: String):
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failures.append(name)
		print("FAIL: ", name)


func _make_floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = Vector3(0, -0.25, 0)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.5, 100)
	col.shape = box
	body.add_child(col)
	return body


func _run() -> void:
	await process_frame
	await process_frame
	await _test_grid_map()
	await _test_visible_footprint()
	await _test_camera()
	await _test_spawner()
	await _test_enemy_mover()
	await _test_trigger_area()
	await _test_projectile()
	await _test_joystick()
	await _test_player()
	print("--------------------------------")
	print("tests passed: %d, failed: %d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _test_grid_map() -> void:
	print("== grid_map ==")
	var grid = load(GRID_SCRIPT).new()
	grid.width = 6
	grid.depth = 8
	grid.build()
	_check(grid.tiles.size() == 48, "grid builds width*depth tiles")
	_check(grid.get_world_size() == Vector2(6, 8), "get_world_size reports width/depth")

	grid.set_wall(2, 3, 1.5)
	grid.build()
	_check(grid.is_wall(2, 3), "set_wall marks the tile")
	_check(not grid.is_wall(0, 0), "unset tiles are not walls")
	_check(grid.wall_bodies.size() == 1, "wall body built")
	var wall_count := 0
	for c in grid.get_children():
		if c.is_in_group("wall"):
			wall_count += 1
	_check(wall_count == 1, "wall body is in the 'wall' group")

	grid.set_wall(2, 3, 0.0)
	grid.build()
	_check(not grid.is_wall(2, 3), "height <= 0 removes a wall")
	_check(grid.wall_bodies.is_empty(), "no wall bodies remain after removal")

	var center = grid.tiles[0].position
	_check(center == Vector3(-2.5, 0, -3.5), "tile (0,0) centers at x-0.5/z-0.5 offset")
	grid.free()


func _test_visible_footprint() -> void:
	print("== visible_footprint ==")
	var cam = load(CAMERA_SCENE).instantiate()
	root.add_child(cam)
	cam.fit_size = Vector2(8, 8)
	cam.setup()

	var pts: Array = VisibleFootprint.ground_footprint(cam)
	_check(pts.size() == 4, "ground_footprint returns 4 corners")
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for p in pts:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.y)
		max_z = maxf(max_z, p.y)
	_check(VisibleFootprint.inside(pts, Vector2.ZERO), "map center is inside the footprint")
	_check(not VisibleFootprint.inside(pts, Vector2(max_x + 10, max_z + 10)), "far point is outside")
	_check(max_x - min_x > 10.0 and max_x - min_x < 30.0, "footprint width in expected range")
	_check(max_z - min_z > 10.0 and max_z - min_z < 30.0, "footprint height in expected range")

	var grid = load(GRID_SCRIPT).new()
	var ring: Array = VisibleFootprint.configure_map(grid, cam, 1, 1.0)
	_check(ring == pts, "configure_map returns the footprint points")
	_check(grid.width >= 4 and grid.depth >= 4, "configure_map sizes the grid")
	grid.build()
	var walls := 0
	var interior_open := false
	for x in grid.width:
		for z in grid.depth:
			if grid.is_wall(x, z):
				walls += 1
			else:
				var cx := int(grid.width / 2)
				var cz := int(grid.depth / 2)
				if x == cx and z == cz and VisibleFootprint.inside(ring, VisibleFootprint.tile_center(grid, x, z)):
					interior_open = true
	_check(walls > 0, "boundary walls are marked")
	_check(interior_open, "grid center stays open (not a wall)")

	var tc := VisibleFootprint.tile_center(grid, 0, 0)
	_check(tc == Vector2(0.5 - grid.width / 2.0, 0.5 - grid.depth / 2.0), "tile_center math")
	grid.free()
	cam.free()


func _test_camera() -> void:
	print("== isometric_camera ==")
	var cam = load(CAMERA_SCENE).instantiate()
	root.add_child(cam)
	cam.fit_size = Vector2(8, 8)
	cam.setup()
	_check(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "setup() applies ortho projection")
	var expected_size = cam.ortho_size_for(Vector2(8, 8))
	_check(absf(cam.size - expected_size) < 0.001, "size equals ortho_size_for(fit_size)")
	_check(cam.distance >= cam.size * 0.9, "distance clamped so frustum clears the ground")
	_check(cam.distance >= 8.0 * 0.9, "distance at least fit size factor")
	_check(absf(cam.global_position.y - cam.distance * sin(deg_to_rad(cam.angle))) < 0.01,
		"camera positioned at angle above target")
	cam.free()


func _test_spawner() -> void:
	print("== enemy_spawner ==")
	var floor := _make_floor()
	root.add_child(floor)
	var enemy_scene = load(ENEMY_SCENE)
	var spawner = load(SPAWNER_SCRIPT).new()
	spawner.enemy_scene = enemy_scene
	spawner.auto_start = false
	spawner.spawn_point = Vector3(0, 0.6, 0)
	spawner.rally_point = Vector3(0, 0.6, 0)
	spawner.wave_interval = 0.05
	spawner.max_waves = 4
	spawner.ramp_enabled = true
	spawner.ramp_start = 1
	spawner.ramp_every = 2
	root.add_child(spawner)

	var counts: Array = []
	var all_reached: Array = []
	var finished: Array = []
	spawner.wave_spawned.connect(func(w, c):
		counts.append([w, c])
		for child in spawner.get_children():
			if child is CharacterBody3D:
				child.stop_distance = 2.0)
	spawner.all_enemies_reached_rally.connect(func(): all_reached.append(true))
	spawner.waves_finished.connect(func(): finished.append(true))

	spawner.start()
	_check(spawner.running, "start() sets running")
	var t0 := Time.get_ticks_msec()
	while (finished.is_empty() or all_reached.is_empty()) and Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	_check(counts == [[1, 1], [2, 1], [3, 2], [4, 2]], "ramp_every=2 growth: wave sizes 1,1,2,2")
	_check(not spawner.running, "spawner stops after max_waves")
	_check(not finished.is_empty(), "waves_finished emitted")
	_check(not all_reached.is_empty(), "all_enemies_reached_rally emitted (enemies reached rally)")
	spawner.free()

	var spawner2 = load(SPAWNER_SCRIPT).new()
	spawner2.enemy_scene = enemy_scene
	spawner2.auto_start = false
	spawner2.spawn_point = Vector3(0, 0.6, 0)
	spawner2.rally_point = Vector3(5, 0.6, 5)
	spawner2.wave_size = 2
	spawner2.wave_interval = 0.06
	spawner2.max_waves = 0
	root.add_child(spawner2)
	var events: Array = []
	spawner2.wave_spawned.connect(func(w, c): events.append([w, c]))
	spawner2.start()
	_check(events.size() == 1 and events[0] == [1, 2], "first run wave 1 spawns 2 enemies")
	spawner2.clear()
	spawner2.start()
	var marker := events.size()
	await create_timer(0.3).timeout
	var tail := events.slice(marker)
	_check(tail.size() > 2, "second run keeps spawning")
	var consecutive := true
	for i in range(1, tail.size()):
		if tail[i][0] != tail[i - 1][0] + 1:
			consecutive = false
	_check(consecutive, "restart discards the old wave timer (consecutive wave numbers)")
	spawner2.free()
	floor.free()


func _test_enemy_mover() -> void:
	print("== enemy_mover ==")
	var floor := _make_floor()
	root.add_child(floor)
	var enemy = load(ENEMY_SCENE).instantiate()
	root.add_child(enemy)
	_check(enemy.is_in_group("enemy"), "enemy is in the 'enemy' group")
	enemy.move_speed = 3.0
	enemy.target = Vector3(5, 0.6, 5)
	var reached: Array = []
	enemy.reached_rally_point.connect(func(): reached.append(true))
	var guard := 0
	while reached.is_empty() and guard < 2000:
		await physics_frame
		guard += 1
	_check(not reached.is_empty(), "enemy reaches its target and emits reached_rally_point")
	_check(absf(enemy.global_position.x - 5.0) < 0.15 and absf(enemy.global_position.z - 5.0) < 0.15,
		"enemy stops at the target (horizontal)")
	await physics_frame
	await physics_frame
	_check(reached.size() == 1, "enemy emits reached_rally_point exactly once")
	enemy.free()
	floor.free()


func _test_trigger_area() -> void:
	print("== trigger_area ==")
	var area = load(TRIGGER_SCENE).instantiate()
	root.add_child(area)
	area.area_size = Vector3(4, 2, 4)

	var player_in: Array = []
	var player_out: Array = []
	var enemy_in: Array = []
	var enemy_out: Array = []
	area.player_entered.connect(func(_a): player_in.append(true))
	area.player_exited.connect(func(_a): player_out.append(true))
	area.enemy_entered.connect(func(_a): enemy_in.append(true))
	area.enemy_exited.connect(func(_a): enemy_out.append(true))

	var player_body := CharacterBody3D.new()
	player_body.add_to_group("player")
	var enemy_body := CharacterBody3D.new()
	enemy_body.add_to_group("enemy")
	var other := CharacterBody3D.new()

	area._on_body_entered(player_body)
	_check(not player_in.is_empty(), "player_entered emitted")
	_check(area._inside.size() == 1, "entering body tracked")
	area._on_body_entered(enemy_body)
	_check(not enemy_in.is_empty(), "enemy_entered emitted")
	var before_p := player_in.size()
	var before_e := enemy_in.size()
	area._on_body_entered(other)
	_check(player_in.size() == before_p and enemy_in.size() == before_e, "untracked bodies ignored")
	area._on_body_exited(player_body)
	_check(not player_out.is_empty(), "player_exited emitted")
	area._on_body_exited(enemy_body)
	_check(not enemy_out.is_empty(), "enemy_exited emitted")
	_check(area._inside.is_empty(), "empty after all leave")

	area._on_body_entered(player_body)
	_check(area.visual.material_override != null, "visual has a material to tint")
	area._on_body_exited(player_body)
	player_body.free()
	enemy_body.free()
	other.free()
	area.free()


func _test_projectile() -> void:
	print("== projectile ==")
	var scene = load(PROJECTILE_SCENE)

	var p = scene.instantiate()
	root.add_child(p)
	var enemy_body := CharacterBody3D.new()
	enemy_body.add_to_group("enemy")
	root.add_child(enemy_body)
	var hit_body: Array = []
	p.hit.connect(func(b): hit_body.append(b))
	p._on_body_entered(enemy_body)
	_check(hit_body.size() == 1 and hit_body[0] == enemy_body, "hit emitted with the enemy body")
	_check(p.is_queued_for_deletion(), "projectile despawns after hitting an enemy")

	var wall_body := CharacterBody3D.new()
	wall_body.add_to_group("wall")
	var pw = scene.instantiate()
	root.add_child(pw)
	pw._on_body_entered(wall_body)
	_check(pw.is_queued_for_deletion(), "projectile despawns on a wall")

	var pl = scene.instantiate()
	root.add_child(pl)
	pl.lifetime = 0.02
	for i in 5:
		await physics_frame
	_check(pl.is_queued_for_deletion(), "projectile despawns after its lifetime")

	var pm = scene.instantiate()
	root.add_child(pm)
	pm.direction = Vector3(1, 0, 0)
	pm.speed = 10.0
	var start_x = pm.global_position.x
	await physics_frame
	_check(pm.global_position.x > start_x + 0.05, "projectile flies along its direction")
	pm.free()
	enemy_body.free()
	wall_body.free()


func _test_joystick() -> void:
	print("== joystick ==")
	var joy = load(JOYSTICK_SCENE).instantiate()
	root.add_child(joy)
	joy.visible_on_desktop = true
	_check(joy.is_in_group("joystick"), "joystick is in the 'joystick' group")

	joy._start(Vector2(100, 100))
	_check(joy.vector == Vector2.ZERO, "vector starts zero")
	joy._update(Vector2(160, 100))
	_check(joy.vector == Vector2(1, 0), "update produces normalized direction")
	joy._update(Vector2(100, 40))
	_check(absf(joy.vector.length() - 1.0) < 0.001, "vector is clamped to unit length")
	joy._stop()
	_check(joy.vector == Vector2.ZERO, "stop resets vector")

	joy.visible = false
	joy._active = false
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(200, 200)
	joy._unhandled_input(ev)
	_check(not joy._active, "hidden joystick ignores input")
	joy.visible = true
	joy._unhandled_input(ev)
	_check(joy._active, "visible joystick accepts input")
	joy.free()


func _test_player() -> void:
	print("== player_controller ==")
	var player = load(PLAYER_SCENE).instantiate()
	root.add_child(player)
	_check(player.is_in_group("player"), "player is in the 'player' group")
	_check(player.mesh_instance.material_override != null, "body color material applied")
	_check(player._read_input() == Vector2.ZERO, "no input, no joystick => zero vector")

	var floor := _make_floor()
	root.add_child(floor)
	var cam = load(CAMERA_SCENE).instantiate()
	root.add_child(cam)
	cam.fit_size = Vector2(12, 12)
	cam.setup()
	cam.make_current()
	var start_x = player.global_position.x
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	Input.action_release("move_right")
	_check(player.global_position.x > start_x + 0.3, "player moves on input")

	var joy = load(JOYSTICK_SCENE).instantiate()
	root.add_child(joy)
	joy._start(Vector2(50, 50))
	joy._update(Vector2(110, 50))
	_check(player._read_input() == Vector2(1, 0), "player reads the joystick vector via group")
	player.free()
	joy.free()
	cam.free()
	floor.free()
