extends Control


func _ready():
	$Layout/ZombieMathButton.pressed.connect(_on_zombie_math_pressed)
	$Layout/SandsOfHanoiButton.pressed.connect(_on_sands_of_hanoi_pressed)
	$Layout/SnowSurvivalButton.pressed.connect(_on_snow_survival_pressed)
	$Layout/PinPuzzlesButton.pressed.connect(_on_pin_puzzles_pressed)
	$Layout/ThroneDefenderButton.pressed.connect(_on_throne_defender_pressed)
	$Layout/SandboxPlayerButton.pressed.connect(_on_sandbox_player_pressed)
	$Layout/SandboxSpawnerButton.pressed.connect(_on_sandbox_spawner_pressed)
	$Layout/SandboxTriggersButton.pressed.connect(_on_sandbox_triggers_pressed)
	$Layout/SandboxCombinedButton.pressed.connect(_on_sandbox_combined_pressed)
	$Layout/SandboxShootingButton.pressed.connect(_on_sandbox_shooting_pressed)


func _on_zombie_math_pressed():
	get_tree().change_scene_to_file("res://scenes/games/zombie_math/title.tscn")


func _on_sands_of_hanoi_pressed():
	get_tree().change_scene_to_file("res://scenes/games/sands_of_hanoi/title.tscn")


func _on_snow_survival_pressed():
	get_tree().change_scene_to_file("res://scenes/games/snow_survival/title.tscn")


func _on_pin_puzzles_pressed():
	get_tree().change_scene_to_file("res://scenes/games/pin_puzzles/title.tscn")


func _on_throne_defender_pressed():
	get_tree().change_scene_to_file("res://scenes/games/throne_defender/title.tscn")


func _on_sandbox_player_pressed():
	get_tree().change_scene_to_file("res://scenes/sandbox/player_sandbox.tscn")


func _on_sandbox_spawner_pressed():
	get_tree().change_scene_to_file("res://scenes/sandbox/spawner_sandbox.tscn")


func _on_sandbox_triggers_pressed():
	get_tree().change_scene_to_file("res://scenes/sandbox/trigger_sandbox.tscn")


func _on_sandbox_combined_pressed():
	get_tree().change_scene_to_file("res://scenes/sandbox/combined_sandbox.tscn")


func _on_sandbox_shooting_pressed():
	get_tree().change_scene_to_file("res://scenes/sandbox/shooting_sandbox.tscn")
