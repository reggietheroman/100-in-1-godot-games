extends Control


func _ready():
	$Layout/StartButton.pressed.connect(_on_start_pressed)
	$Layout/BackButton.pressed.connect(_on_back_pressed)


func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/games/zombie_math/game.tscn")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
