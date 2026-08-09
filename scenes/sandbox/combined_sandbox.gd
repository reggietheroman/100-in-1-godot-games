extends Node3D

const VisibleFootprint := preload("res://addons/isometric_kit/scripts/visible_footprint.gd")
const LOOT_SCENE := "res://addons/isometric_kit/scenes/loot_coin.tscn"
const BUILD_SITE_SCENE := "res://addons/isometric_kit/scenes/build_site.tscn"
const TOWER_SCENE := "res://addons/isometric_kit/scenes/tower.tscn"

@export var play_width := 11.31
@export var play_depth := 11.31
@export var map_padding := 3
@export var player_move_speed := 4.0
@export var player_start := Vector3(0, 0.6, 0)
@export var spawn_point := Vector3(5, 0.6, 5)
@export var rally_point := Vector3(-5, 0.6, -5)
@export var projectile_speed := 18.0
@export var fire_interval := 0.4
@export var projectile_scene: PackedScene
@export var enemy_scene: PackedScene
@export var starting_currency := 0

## Four pre-defined Rapid tower build areas, one per map corner. Each pad's
## structure points toward the center so the towers cover the spawn → rally
## diagonal the enemies walk.
@export var site_configs := [
	{
		"name": "Rapid Tower",
		"stages": [15, 30, 50],
		"offset": Vector3(-3, 0, -3),
		"structure_offset": Vector3(2.5, 0, 2.5),
		"tower_level_stats": [
			{"fire_interval": 0.3, "range": 4.5, "damage": 1},
			{"fire_interval": 0.24, "range": 5.5, "damage": 2},
			{"fire_interval": 0.18, "range": 6.5, "damage": 3},
		],
	},
	{
		"name": "Rapid Tower",
		"stages": [15, 30, 50],
		"offset": Vector3(3, 0, -3),
		"structure_offset": Vector3(-2.5, 0, 2.5),
		"tower_level_stats": [
			{"fire_interval": 0.3, "range": 4.5, "damage": 1},
			{"fire_interval": 0.24, "range": 5.5, "damage": 2},
			{"fire_interval": 0.18, "range": 6.5, "damage": 3},
		],
	},
	{
		"name": "Rapid Tower",
		"stages": [15, 30, 50],
		"offset": Vector3(-3, 0, 3),
		"structure_offset": Vector3(2.5, 0, -2.5),
		"tower_level_stats": [
			{"fire_interval": 0.3, "range": 4.5, "damage": 1},
			{"fire_interval": 0.24, "range": 5.5, "damage": 2},
			{"fire_interval": 0.18, "range": 6.5, "damage": 3},
		],
	},
	{
		"name": "Rapid Tower",
		"stages": [15, 30, 50],
		"offset": Vector3(3, 0, 3),
		"structure_offset": Vector3(-2.5, 0, -2.5),
		"tower_level_stats": [
			{"fire_interval": 0.3, "range": 4.5, "damage": 1},
			{"fire_interval": 0.24, "range": 5.5, "damage": 2},
			{"fire_interval": 0.18, "range": 6.5, "damage": 3},
		],
	},
]

const WAVE_CHOICES := [1, 2, 3, 4, 5, 0]
const ENEMY_CHOICES := [1, 2, 3, 4, 5, 0]
const RAMP_EVERY_MIN := 1
const RAMP_EVERY_MAX := 10
const FIRE_RATE_MIN := 0.1
const FIRE_RATE_MAX := 3.0
const FIRE_RATE_STEP := 0.1
const BOUNDARY_WALL_H := 1.5

var wave_count_index := 4
var enemy_count_index := 4
var ramp_every := 3
var picking: String = ""
var hits := 0
var auto_fire := false
var _cooldown := 0.0

@onready var grid: Node3D = $GridMap
@onready var camera: Camera3D = $Camera
@onready var player: CharacterBody3D = $Player
@onready var wallet: Node3D = $Player/CurrencyWallet
@onready var spawner: Node3D = $Spawner
@onready var hud: CanvasLayer = $HUD
@onready var start_button: Button = $HUD/Panel/Controls/StartButton

var spawn_marker: Node3D
var rally_marker: Node3D


func _ready():
	camera.fit_size = Vector2(play_width, play_depth)
	camera.setup()
	VisibleFootprint.configure_map(grid, camera, map_padding, BOUNDARY_WALL_H)
	grid.build()

	player.move_speed = player_move_speed
	player.position = player_start
	wallet.currency = starting_currency

	spawner.spawn_point = spawn_point
	spawner.rally_point = rally_point

	spawner.wave_spawned.connect(_on_wave_spawned)
	spawner.all_enemies_reached_rally.connect(_on_all_reached)
	spawner.waves_finished.connect(_on_waves_finished)

	for cfg in site_configs:
		var site = load(BUILD_SITE_SCENE).instantiate()
		site.name = "Site_%s" % cfg["name"]
		site.display_name = cfg["name"]
		var stages: Array[int] = []
		for v in cfg["stages"]:
			stages.append(v)
		site.stages = stages
		site.tower_scene = load(TOWER_SCENE)
		var level_stats: Array[Dictionary] = []
		for s in cfg["tower_level_stats"]:
			level_stats.append(s)
		site.tower_level_stats = level_stats
		site.structure_offset = cfg["structure_offset"]
		site.position = cfg["offset"]
		add_child(site)
		site.leveled_up.connect(_on_leveled_up.bind(cfg["name"]))
		site.completed.connect(_on_completed.bind(cfg["name"]))

	$HUD/BackButton.pressed.connect(_on_back_pressed)
	$HUD/Panel/Controls/StartButton.pressed.connect(_on_start_pressed)
	$HUD/Panel/Controls/ResetButton.pressed.connect(_on_reset_pressed)
	$HUD/Panel/Controls/SetSpawnButton.pressed.connect(_on_set_spawn_pressed)
	$HUD/Panel/Controls/SetRallyButton.pressed.connect(_on_set_rally_pressed)
	$HUD/Panel/Controls/WaveCountSelector/WaveCountPrev.pressed.connect(_on_wave_count_prev)
	$HUD/Panel/Controls/WaveCountSelector/WaveCountNext.pressed.connect(_on_wave_count_next)
	$HUD/Panel/Controls/EnemyCountSelector/EnemyCountPrev.pressed.connect(_on_enemy_count_prev)
	$HUD/Panel/Controls/EnemyCountSelector/EnemyCountNext.pressed.connect(_on_enemy_count_next)
	$HUD/Panel/Controls/RampEverySelector/RampEveryPrev.pressed.connect(_on_ramp_every_prev)
	$HUD/Panel/Controls/RampEverySelector/RampEveryNext.pressed.connect(_on_ramp_every_next)
	$HUD/FireButton.pressed.connect(_fire)
	$HUD/Panel/Controls/AutoFireButton.pressed.connect(_on_auto_fire_pressed)
	$HUD/Panel/Controls/FireRateSelector/FireRatePrev.pressed.connect(_on_fire_rate_prev)
	$HUD/Panel/Controls/FireRateSelector/FireRateNext.pressed.connect(_on_fire_rate_next)
	get_tree().node_added.connect(_on_node_added)

	_refresh_count_labels()
	_set_markers()
	_refresh_hud()
	_refresh_fire_ui()
	wallet.currency_changed.connect(_on_currency_changed)
	_set_status("Configure, click Start Waves, then shoot enemies with Space/Fire — collect coins, stand on a pad to build a Rapid tower")


func _process(delta):
	_cooldown = maxf(_cooldown - delta, 0.0)
	if auto_fire and _cooldown <= 0.0 and _nearest_enemy() != null:
		_fire(true)


func _unhandled_input(event):
	if picking != "":
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_pick_point(event.position)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("shoot"):
		_fire()


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/sandbox_menu.tscn")


func _on_start_pressed():
	if spawner.running:
		spawner.stop()
		_set_running_ui(false)
		_set_status("Stopped after wave %d" % spawner.wave_number)
		return
	_reset_waves()
	var enemy_choice: int = ENEMY_CHOICES[enemy_count_index]
	spawner.max_waves = WAVE_CHOICES[wave_count_index]
	spawner.ramp_enabled = enemy_choice == 0
	if spawner.ramp_enabled:
		spawner.ramp_start = 1
		spawner.ramp_every = ramp_every
		spawner.wave_size = 1
	else:
		spawner.wave_size = enemy_choice
	spawner.start()
	_set_running_ui(true)
	if spawner.ramp_enabled:
		_set_status("Started: %s waves, ∞ enemies (ramp +1 every %d waves)" % [_wave_label(), ramp_every])
	else:
		_set_status("Started: %s waves, %d enemies/wave" % [_wave_label(), enemy_choice])


func _on_reset_pressed():
	_reset_waves()
	_set_status("Waves stopped, enemies cleared")


func _on_set_spawn_pressed():
	_reset_waves()
	picking = "spawn"
	_set_status("Click a tile to set the spawn point")


func _on_set_rally_pressed():
	_reset_waves()
	picking = "rally"
	_set_status("Click a tile to set the rally point")


func _on_wave_count_prev():
	wave_count_index = (wave_count_index - 1 + WAVE_CHOICES.size()) % WAVE_CHOICES.size()
	_refresh_count_labels()


func _on_wave_count_next():
	wave_count_index = (wave_count_index + 1) % WAVE_CHOICES.size()
	_refresh_count_labels()


func _on_enemy_count_prev():
	enemy_count_index = (enemy_count_index - 1 + ENEMY_CHOICES.size()) % ENEMY_CHOICES.size()
	_refresh_count_labels()


func _on_enemy_count_next():
	enemy_count_index = (enemy_count_index + 1) % ENEMY_CHOICES.size()
	_refresh_count_labels()


func _on_ramp_every_prev():
	ramp_every = maxi(ramp_every - 1, RAMP_EVERY_MIN)
	_refresh_count_labels()


func _on_ramp_every_next():
	ramp_every = mini(ramp_every + 1, RAMP_EVERY_MAX)
	_refresh_count_labels()


func _refresh_count_labels():
	var wave_label := _wave_label()
	var enemy_label := _enemy_label()
	($HUD/Panel/Controls/WaveCountSelector/WaveCountValue as Label).text = wave_label
	($HUD/Panel/Controls/WaveCountLabel as Label).text = "Waves: " + wave_label
	($HUD/Panel/Controls/EnemyCountSelector/EnemyCountValue as Label).text = enemy_label
	($HUD/Panel/Controls/EnemyCountLabel as Label).text = "Enemies / wave: " + enemy_label
	($HUD/Panel/Controls/RampEverySelector/RampEveryValue as Label).text = str(ramp_every)
	($HUD/Panel/Controls/RampEveryLabel as Label).text = "Ramp +1 every: %d waves" % ramp_every
	_refresh_ramp_ui()


func _wave_label() -> String:
	return "∞" if WAVE_CHOICES[wave_count_index] == 0 else str(WAVE_CHOICES[wave_count_index])


func _enemy_label() -> String:
	return "∞" if ENEMY_CHOICES[enemy_count_index] == 0 else str(ENEMY_CHOICES[enemy_count_index])


func _refresh_ramp_ui():
	var infinite: bool = ENEMY_CHOICES[enemy_count_index] == 0
	($HUD/Panel/Controls/RampEveryLabel as Label).modulate = Color(1, 1, 1) if infinite else Color(1, 1, 1, 0.4)
	($HUD/Panel/Controls/RampEverySelector/RampEveryPrev as Button).disabled = not infinite
	($HUD/Panel/Controls/RampEverySelector/RampEveryNext as Button).disabled = not infinite


func _pick_point(screen_pos: Vector2):
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var t := -from.y / dir.y if dir.y < -0.0001 else -1.0
	if t < 0.0:
		return
	var world := from + dir * t
	var snapped := _snap_to_tile(world)
	if picking == "spawn":
		spawn_point = snapped
		spawner.spawn_point = snapped
		_update_marker(spawn_marker, snapped)
		_set_status("Spawn point set to (%d, %d)" % [snapped.x, snapped.z])
	elif picking == "rally":
		rally_point = snapped
		spawner.rally_point = snapped
		_update_marker(rally_marker, snapped)
		_set_status("Rally point set to (%d, %d)" % [snapped.x, snapped.z])
	picking = ""


func _snap_to_tile(world: Vector3) -> Vector3:
	var cx := clampi(roundi(world.x), -grid.width / 2, grid.width / 2 - 1)
	var cz := clampi(roundi(world.z), -grid.depth / 2, grid.depth / 2 - 1)
	return Vector3(cx + 0.5, 0.6, cz + 0.5)


func _reset_waves():
	spawner.clear()
	_set_running_ui(false)


func _set_running_ui(running: bool):
	start_button.text = "Stop Waves" if running else "Start Waves"


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


func _fire(quiet := false):
	if _cooldown > 0.0:
		return
	var enemy := _nearest_enemy()
	if enemy == null:
		if not quiet:
			_set_status("No enemies to target")
		return
	var from := player.global_position + Vector3(0, 0.4, 0)
	var dir := enemy.global_position - from
	dir.y = 0.0
	dir = dir.normalized()

	var projectile := projectile_scene.instantiate()
	projectile.speed = projectile_speed
	projectile.direction = dir
	projectile.position = from
	add_child(projectile)
	projectile.hit.connect(_on_projectile_hit)
	_cooldown = fire_interval
	if not quiet:
		_set_status("Fired at %s" % enemy.name)


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d: float = enemy.global_position.distance_squared_to(player.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func _on_projectile_hit(enemy: Node3D):
	hits += 1
	enemy.die()
	_refresh_hud()
	_set_status("Hit! %d total hits" % hits)


func _on_node_added(node: Node):
	if node.has_method("die") and node.loot_scene == null:
		node.loot_scene = load(LOOT_SCENE)
	if node.get("pickup_mode") != null and not node.picked_up.is_connected(_on_loot_picked_up):
		node.picked_up.connect(_on_loot_picked_up)


func _on_loot_picked_up(item: Node3D):
	var value: int = item.value if item.get("value") != null else 1
	wallet.add_currency(value)
	_refresh_hud()
	_set_status("Collected %+d currency" % value)


func _on_auto_fire_pressed():
	auto_fire = not auto_fire
	_refresh_fire_ui()


func _on_fire_rate_prev():
	fire_interval = maxf(fire_interval - FIRE_RATE_STEP, FIRE_RATE_MIN)
	_refresh_fire_ui()


func _on_fire_rate_next():
	fire_interval = minf(fire_interval + FIRE_RATE_STEP, FIRE_RATE_MAX)
	_refresh_fire_ui()


func _refresh_fire_ui():
	($HUD/Panel/Controls/AutoFireButton as Button).text = "Auto-Fire: ON" if auto_fire else "Auto-Fire: OFF"
	($HUD/Panel/Controls/FireRateLabel as Label).text = "Fire rate: %.1fs" % fire_interval
	($HUD/Panel/Controls/FireRateSelector/FireRateValue as Label).text = "%.1fs" % fire_interval


func _refresh_hud():
	($HUD/HitLabel as Label).text = "Hits: %d" % hits
	($HUD/CurrencyLabel as Label).text = "Currency: %d" % wallet.currency


func _on_currency_changed(_amount: int):
	_refresh_hud()


func _on_leveled_up(level: int, site_name: String):
	_set_status("%s grew to level %d" % [site_name, level])


func _on_completed(site_name: String):
	_set_status("%s complete — its payment pad was removed" % site_name)


func _on_wave_spawned(wave: int, count: int):
	_set_status("Wave %d spawned (%d enemies) — walking to rally point" % [wave, count])


func _on_all_reached():
	_set_status("All enemies reached the rally point")


func _on_waves_finished():
	_set_running_ui(false)
	_set_status("All %s waves finished" % [_wave_label()])


func _set_status(text: String):
	($HUD/StatusLabel as Label).text = text
