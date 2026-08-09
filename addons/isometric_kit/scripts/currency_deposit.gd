## Currency deposit area that drains a wallet up to a capacity.
##
## An `Area3D` pad the player stands on. It drains currency from the nearest
## wallet in the "wallet" group into the area, up to `capacity`. Transfers are
## not instant: every `transfer_interval` seconds `transfer_amount` units move
## and a small coin flies from the player to the pad, so the wallet and pad
## counts tick up/down with a visible "paying" feel. Each coin landing bumps the
## pad, and filling up plays a punchy pop + flash + label bump. Draining is
## automatic while a player stands on the pad when `auto_activate` is true, or
## requires pressing `activation_action` otherwise. A `Label3D` above the pad
## shows the running total (`Bank 0/10`, then `Bank 10/10` when full). The pad
## highlights while the player stands on it and glows when full. `paused`
## freezes transfers until cleared (used by `build_site` for a post-milestone
## beat).
extends Area3D

const TransferCoinScene := preload("res://addons/isometric_kit/scenes/transfer_coin.tscn")

## Footprint size of the pad (full extents, not half-extents).
@export var area_size := Vector3(2.5, 2.0, 2.5)

## How much currency this area accepts in total.
@export var capacity := 0

## Display name shown in the on-pad label.
@export var display_name := "Deposit"

## When true, drains the wallet automatically while the player stands on the
## pad. When false, requires pressing `activation_action`.
@export var auto_activate := true

## Input action that activates the deposit when `auto_activate` is false.
@export var activation_action := "pickup"

## Units moved per transfer tick.
@export var transfer_amount := 1

## Seconds between transfer ticks (how long each coin flight takes).
@export var transfer_interval := 0.12

## Spawn a flying coin from the player to the pad on each tick.
@export var show_transfer_visuals := true

## Pad tint while a player stands on it.
@export var active_color := Color(0.2, 1.0, 0.2, 0.4)

## Pad tint while empty.
@export var inactive_color := Color(0.5, 0.5, 0.5, 0.4)

## Pad tint once the area is full.
@export var full_color := Color(1.0, 0.8, 0.2, 0.55)

## When true, the pad self-registers in the "deposit" group. Set to false when
## the pad is embedded in a larger component (e.g. `build_site`) so it doesn't
## pollute the group.
@export var register_in_group := true

## Emitted when currency is deposited: current total and the capacity.
signal deposited_changed(deposited: int, capacity: int)

## Currency currently held by this area.
var deposited := 0

## When true, the pad stops draining until unpaused. Used by owning components
## (e.g. `build_site`) to hold payments for a beat after a milestone so the
## collection lands before the next stage starts accepting coins.
var paused := false

var _player_inside := false
var _active := false
var _tick_timer := 0.0
var _pulse_tween: Tween
var _flash_tween: Tween
var _label_tween: Tween

@onready var label: Label3D = $Label
@onready var visual: MeshInstance3D = $Visual
@onready var collision: CollisionShape3D = $CollisionShape3D


func _ready():
	if register_in_group:
		add_to_group("deposit")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_size()
	_set_color(inactive_color)
	_refresh_label()


## Re-apply the label and pad tint from the current state (deposited vs
## capacity, player inside). Call after changing `capacity` or colors so the pad
## doesn't keep a stale "full" tint.
func refresh():
	_refresh_label()
	if deposited >= capacity:
		_set_color(full_color)
	elif _player_inside:
		_set_color(active_color)
	else:
		_set_color(inactive_color)


func _process(delta):
	if paused:
		_tick_timer = 0.0
		return
	if not _player_inside:
		_active = false
		_tick_timer = 0.0
		return
	if auto_activate:
		_active = true
	elif Input.is_action_just_pressed(activation_action):
		_active = true
	if not _active:
		return
	_tick_timer += delta
	while _tick_timer >= transfer_interval:
		_tick_timer -= transfer_interval
		if not _transfer_tick():
			_active = false
			_tick_timer = 0.0
			break


func _transfer_tick() -> bool:
	var wallet := get_tree().get_first_node_in_group("wallet")
	if wallet == null:
		return false
	if deposited >= capacity:
		return false
	var spent: int = wallet.spend_currency(transfer_amount)
	if spent <= 0:
		return false
	deposited += spent
	var collected := deposited >= capacity
	_refresh_label()
	_spawn_transfer_visual()
	if show_transfer_visuals:
		if collected:
			_collect_pulse()
		else:
			_pulse_pad(1.05, 0.12)
	if collected:
		_set_color(full_color)
	deposited_changed.emit(deposited, capacity)
	return true


func _spawn_transfer_visual():
	if not show_transfer_visuals:
		return
	var player := get_tree().get_first_node_in_group("player")
	var parent := get_parent()
	if player == null or parent == null:
		return
	# Coin leaves from above the player and arcs up over the pad, landing at the
	# label height. The arc keeps the flight visible even when the player stands
	# right on the pad (start and end barely move horizontally).
	var start: Vector3 = player.global_position + Vector3(0, 1.2, 0)
	var end: Vector3 = global_position + Vector3(0, 1.3, 0)
	var control: Vector3 = (start + end) * 0.5 + Vector3(0, 1.0, 0)
	var coin: Node3D = TransferCoinScene.instantiate()
	parent.add_child(coin)
	coin.global_position = start
	var tween := coin.create_tween()
	tween.tween_method(
		func(t: float) -> void:
			var a: Vector3 = start.lerp(control, t)
			var b: Vector3 = control.lerp(end, t)
			coin.global_position = a.lerp(b, t),
		0.0, 1.0, transfer_interval)
	tween.parallel().tween_property(coin, "rotation:x", TAU * 1.5, transfer_interval)
	tween.tween_callback(coin.queue_free)


func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		_player_inside = true
		if deposited < capacity:
			_set_color(active_color)


func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		_player_inside = false
		if deposited < capacity:
			_set_color(inactive_color)


func _apply_size():
	if collision != null:
		var shape := collision.shape as BoxShape3D
		if shape != null:
			shape.size = area_size
	if visual != null and visual.mesh is BoxMesh:
		(visual.mesh as BoxMesh).size = Vector3(area_size.x, 0.1, area_size.z)
		visual.position = Vector3(0, 0.05, 0)


func _refresh_label():
	if label == null:
		return
	var prefix := "%s " % display_name if display_name != "" else ""
	label.text = "%s%d/%d" % [prefix, deposited, capacity]


## Small pad bump so each coin landing feels physical. The stronger `_collect_pulse`
## fires instead when the pad fills up.
func _pulse_pad(target: float, duration: float):
	if visual == null:
		return
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = visual.create_tween()
	_pulse_tween.tween_property(visual, "scale", Vector3(target, 1.0, target), duration * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(visual, "scale", Vector3.ONE, duration * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A punchy "collected!" moment when the pad reaches capacity: a big pad pop,
## a white flash settling to the full color, and the counter label bumping.
func _collect_pulse():
	_pulse_pad(1.18, 0.4)
	if visual != null and visual.material_override != null:
		if _flash_tween:
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(visual.material_override, "albedo_color", Color(1, 1, 1, 0.9), 0.06)
		_flash_tween.tween_property(visual.material_override, "albedo_color", full_color, 0.3)
	if label != null:
		if _label_tween:
			_label_tween.kill()
		_label_tween = label.create_tween()
		_label_tween.tween_property(label, "scale", Vector3(1.35, 1.35, 1.35), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_label_tween.tween_property(label, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_color(color: Color):
	if _flash_tween:
		_flash_tween.kill()
	if visual == null:
		return
	if visual.material_override == null:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		visual.material_override = mat
	visual.material_override.albedo_color = color
