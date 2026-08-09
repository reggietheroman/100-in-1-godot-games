## Pickup-able loot item that despawns after a configurable lifetime.
##
## A small `Node3D` (gem mesh) that sits on the ground. The player collects it
## by walking within `pickup_radius` when `pickup_mode` is AUTO, or by pressing
## the "pickup" input action while nearby when it's KEY. Collected items are
## removed (treated as despawned). On pickup the item emits `picked_up(item)`
## and plays one-shot indicators: a particle burst, a floating "+N Name" label,
## and a quick fly-to-player animation.
##
## Items self-despawn after `lifetime` seconds (0 = never), blinking then
## fading out near the end so the countdown is visible. Instantiate the
## `loot_item.tscn` scene and set the exported name / color / value / mode /
## lifetime; games can spawn drops via `loot_drop.gd`.
extends Node3D

## AUTO = collected on contact within `pickup_radius`; KEY = also requires the
## "pickup" input action.
enum PickupMode { AUTO, KEY }

## Display name shown in the pickup label.
@export var item_name := "Gem"

## Tint of the gem mesh (typed items are distinguished by color).
@export var body_color := Color(1.0, 0.8, 0.2)

## Score value of this item (sandbox HUDs sum these).
@export var value := 1

## Pickup trigger mode: Auto or Key (press E).
@export_enum("Auto", "Key") var pickup_mode := 0

## Seconds until the item despawns (0 = never).
@export var lifetime := 30.0

## Seconds of blinking just before the despawn fade.
@export var blink_duration := 1.5

## Seconds of fading out right before despawn.
@export var fade_duration := 0.4

## Horizontal distance the player must be within to collect the item.
@export var pickup_radius := 1.4

## Play a one-shot particle burst on pickup.
@export var show_particle_burst := true

## Show a floating "+N Name" label on pickup.
@export var show_floating_label := true

## Fly toward the player and shrink before despawning.
@export var show_fly_anim := true

## Emitted (with the item) when the player picks it up.
signal picked_up(item: Node3D)

const BLINK_INTERVAL := 0.15
const IDLE_SPIN_SPEED := 2.0
const IDLE_BOB_SPEED := 3.0
const IDLE_BOB_AMPLITUDE := 0.03

var collected := false

var _elapsed := 0.0
var _blink_timer := 0.0
var _base_y := 0.0
var _material: StandardMaterial3D

@onready var visual: MeshInstance3D = $Visual


func _ready():
	add_to_group("loot")
	_apply_color()
	_base_y = visual.position.y if visual != null else 0.0


func _process(delta: float):
	if collected:
		return
	_elapsed += delta
	if visual != null:
		visual.rotate_y(delta * IDLE_SPIN_SPEED)
		visual.position.y = _base_y + sin(_elapsed * IDLE_BOB_SPEED) * IDLE_BOB_AMPLITUDE
	if lifetime > 0.0:
		_tick_despawn(delta)
	_check_pickup()


func _tick_despawn(delta: float):
	var remaining := lifetime - _elapsed
	if remaining <= 0.0:
		queue_free()
		return
	if remaining <= fade_duration:
		_set_alpha(maxf(remaining / fade_duration, 0.0))
	elif remaining <= blink_duration:
		_blink_timer += delta
		if _blink_timer >= BLINK_INTERVAL:
			_blink_timer = 0.0
			if visual != null:
				visual.visible = not visual.visible


func _check_pickup():
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) > pickup_radius:
		return
	if pickup_mode == PickupMode.AUTO:
		_collect()
	elif pickup_mode == PickupMode.KEY and (
		Input.is_action_just_pressed("pickup") or Input.is_action_pressed("pickup")
	):
		_collect()


func _collect():
	if collected:
		return
	collected = true
	_spawn_burst()
	_spawn_label()
	picked_up.emit(self)
	if show_fly_anim:
		_play_fly_anim()
	else:
		queue_free()


func _play_fly_anim():
	var player := get_tree().get_first_node_in_group("player")
	var tween := create_tween()
	if player != null:
		tween.tween_property(self, "global_position", player.global_position, 0.2)
		tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.2)
	else:
		tween.tween_property(self, "scale", Vector3.ZERO, 0.2)
	tween.tween_callback(queue_free)


func _spawn_burst():
	if not show_particle_burst:
		return
	var parent := get_parent()
	if parent == null:
		return
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 12
	burst.lifetime = 0.5
	burst.explosiveness = 1.0
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 60.0
	burst.gravity = Vector3(0, -6, 0)
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 2.5
	burst.scale_amount_min = 0.05
	burst.scale_amount_max = 0.12
	burst.position = global_position
	parent.add_child(burst)
	get_tree().create_timer(burst.lifetime + 0.1).timeout.connect(burst.queue_free)


func _spawn_label():
	if not show_floating_label:
		return
	var parent := get_parent()
	if parent == null:
		return
	var label := Label3D.new()
	label.text = "+%d %s" % [value, item_name]
	label.font_size = 48
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.6)
	label.modulate = Color(1, 1, 1, 1)
	label.position = global_position + Vector3(0, 0.7, 0)
	parent.add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)


func _apply_color():
	if visual == null:
		return
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visual.material_override = _material


func _set_alpha(a: float):
	if _material != null:
		_material.albedo_color.a = a
