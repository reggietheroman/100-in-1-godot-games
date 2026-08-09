extends Control


func _ready():
	$Scroll/Layout/BackButton.pressed.connect(func(): _open("res://scenes/menu/menu.tscn"))
	_open_for("SandboxPlayerButton", "res://scenes/sandbox/player_sandbox.tscn")
	_open_for("SandboxSpawnerButton", "res://scenes/sandbox/spawner_sandbox.tscn")
	_open_for("SandboxTriggersButton", "res://scenes/sandbox/trigger_sandbox.tscn")
	_open_for("SandboxCombinedButton", "res://scenes/sandbox/combined_sandbox.tscn")
	_open_for("SandboxShootingButton", "res://scenes/sandbox/shooting_sandbox.tscn")
	_open_for("SandboxLootPickupButton", "res://scenes/sandbox/pickup_sandbox.tscn")
	_open_for("SandboxLootSpawnerButton", "res://scenes/sandbox/loot_spawn_sandbox.tscn")
	_open_for("SandboxLootDropButton", "res://scenes/sandbox/loot_drop_sandbox.tscn")
	_open_for("SandboxCurrencyButton", "res://scenes/sandbox/currency_sandbox.tscn")


func _open_for(button: String, scene: String):
	$Scroll/Layout.get_node(button).pressed.connect(func(): _open(scene))


func _open(scene: String):
	get_tree().change_scene_to_file(scene)
