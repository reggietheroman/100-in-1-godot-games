extends Control


func _ready():
	$Layout/ZombieMathButton.pressed.connect(_on_zombie_math_pressed)
	$Layout/SandsOfHanoiButton.pressed.connect(_on_sands_of_hanoi_pressed)
	$Layout/SnowSurvivalButton.pressed.connect(_on_snow_survival_pressed)
	$Layout/PinPuzzlesButton.pressed.connect(_on_pin_puzzles_pressed)


func _on_zombie_math_pressed():
	get_tree().change_scene_to_file("res://scenes/games/zombie_math/title.tscn")


func _on_sands_of_hanoi_pressed():
	get_tree().change_scene_to_file("res://scenes/games/sands_of_hanoi/title.tscn")


func _on_snow_survival_pressed():
	get_tree().change_scene_to_file("res://scenes/games/snow_survival/title.tscn")


func _on_pin_puzzles_pressed():
	get_tree().change_scene_to_file("res://scenes/games/pin_puzzles/title.tscn")
