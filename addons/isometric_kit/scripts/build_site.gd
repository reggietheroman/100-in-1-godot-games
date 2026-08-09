## Build site: a predefined area where the player pays currency to construct a
## structure that levels up in stages.
##
## The payment pad is an embedded `currency_deposit`, so paying reuses the
## verified ticked-drain behavior: stand on the pad and the wallet drains in
## flying coins. Each entry in `stages` is the cost of one level, paid in
## sequence — when the pad reaches a stage's amount, a block pops onto the tower
## beside the pad, the pad counter resets, and the next stage becomes the target
## (`0/25` after finishing `0/10`). Each finished stage plays a celebration
## popup + confetti burst above the structure (the final one reads
## "{display_name} Complete!"), and the pad pauses for a beat after the first
## level so the milestone lands. Once the final stage is paid, the payment pad
## is removed and only the completed structure remains.
##
## The structure visual is one instance of `structure_scene` per level when set
## (any 3D asset: `.glb`, `.tscn`, ...); otherwise a stack of `BoxMesh` blocks is
## used. `structure_colors` tints the structure per level when non-empty (leave
## empty to keep an asset's own materials). The dev configures which structure a
## site builds and how much each level costs (`stages`); players can only pay
## what's required by standing on the pad.
extends Node3D

const DEPOSIT_SCENE := "res://addons/isometric_kit/scenes/currency_deposit.tscn"
const CELEBRATION_SCENE := "res://addons/isometric_kit/scenes/celebration.tscn"

## Name shown on the payment pad's label.
@export var display_name := "Build Site"

## Cost of each structure level, paid in sequence. The pad shows the current
## stage's progress and resets to `0/{next}` when a stage is paid.
## e.g. [10, 25, 50] = pay 10 for level 1, then 25 for level 2, then 50 for max.
@export var stages: Array[int] = [10, 25, 50]

## Footprint size of the payment pad (full extents).
@export var payment_area_size := Vector3(2.5, 2.0, 2.5)

## Where the structure sits relative to the payment pad center.
@export var structure_offset := Vector3(3.5, 0, 0)

## Optional 3D asset to use for the structure. One instance is placed on the
## tower per level and pops in when its stage is paid. When unset, the default
## stacked `BoxMesh` blocks are used.
@export var structure_scene: PackedScene

## Tint per level (index `level - 1`). The whole tower recolors to the current
## level's color. When empty, box segments stay gray and a custom
## `structure_scene` keeps its own materials.
@export var structure_colors: Array[Color] = [
	Color(0.45, 0.9, 0.45),
	Color(1.0, 0.7, 0.2),
	Color(1.0, 0.4, 0.35),
]

## Drains the wallet automatically while the player stands on the pad.
@export var auto_activate := true

## Units moved per transfer tick.
@export var transfer_amount := 1

## Seconds between transfer ticks (each coin flight).
@export var transfer_interval := 0.07

## Spawn flying coins from the player to the pad on each tick.
@export var show_transfer_visuals := true

## Play a celebration popup ("{display_name} Level N!" / "{display_name}
## Complete!") with a confetti burst above the structure on every level-up.
@export var celebration_enabled := true

## Seconds the payment pad pauses after the FIRST level is collected, letting
## the milestone (structure pop-in + celebration) land before it accepts the
## next stage. 0 disables the pause.
@export var first_level_pause := 0.6

## Emitted when the structure reaches a new level (1-based).
signal leveled_up(level: int)

## Emitted when the final stage is paid and the payment pad is removed.
signal completed

## Current structure level (0 = nothing paid yet).
var level := 0

@onready var pad: Area3D = $PaymentPad
@onready var structure: Node3D = $Structure

var _segments: Array[Node3D] = []


func _ready():
	add_to_group("build_site")
	pad.display_name = display_name
	pad.area_size = payment_area_size
	pad.auto_activate = auto_activate
	pad.transfer_amount = transfer_amount
	pad.transfer_interval = transfer_interval
	pad.show_transfer_visuals = show_transfer_visuals
	pad.capacity = _target_for_level(0)
	pad.deposited_changed.connect(_on_deposited_changed)
	structure.position = structure_offset
	_build_structure()
	pad.refresh()


## The amount of currency the player must pay to reach the given level
## (0 = the first stage's cost).
func _target_for_level(target_level: int) -> int:
	if target_level >= stages.size():
		return stages[-1]
	return stages[target_level]


func _build_structure():
	_segments.clear()
	for i in stages.size():
		var seg := _make_segment()
		seg.position = Vector3(0, 0.2 + i * 1.0, 0)
		seg.scale = Vector3.ZERO
		structure.add_child(seg)
		_segments.append(seg)


func _make_segment() -> Node3D:
	if structure_scene != null:
		var inst := structure_scene.instantiate()
		if inst is Node3D:
			return inst
	return _make_box_segment()


func _make_box_segment() -> MeshInstance3D:
	var seg := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.5, 1.0, 1.5)
	seg.mesh = mesh
	return seg


func _color_for_level(target_level: int) -> Color:
	if structure_colors.is_empty():
		return Color(0.8, 0.8, 0.8)
	return structure_colors[(target_level - 1) % structure_colors.size()]


## Pop a celebration above the newest structure segment so every finished stage
## (including the final one) feels like a win. The final stage reads
## "{display_name} Complete!", earlier ones "{display_name} Level N!".
func _celebrate(target_level: int):
	if not celebration_enabled:
		return
	var celebration = load(CELEBRATION_SCENE).instantiate()
	var top := 0.2 + (target_level - 1) * 1.0
	celebration.position = Vector3(0, top + 1.1, 0)
	structure.add_child(celebration)
	var final := target_level >= stages.size()
	celebration.celebrate(
		"%s %s!" % [display_name, "Complete" if final else "Level %d" % target_level],
		_color_for_level(target_level))


func _on_deposited_changed(deposited: int, capacity: int):
	if deposited < capacity or level >= stages.size():
		return
	level += 1
	_show_level(level)
	_celebrate(level)
	leveled_up.emit(level)
	if level >= stages.size():
		_finish()
		return
	if level == 1 and first_level_pause > 0.0:
		pad.paused = true
		var pad_ref := pad
		get_tree().create_timer(first_level_pause).timeout.connect(
			func():
				if is_instance_valid(pad_ref):
					pad_ref.paused = false)
	pad.deposited = deposited - capacity
	pad.capacity = _target_for_level(level)
	pad.refresh()


func _show_level(target_level: int):
	for i in _segments.size():
		var seg := _segments[i]
		if i < target_level:
			if not structure_colors.is_empty() or structure_scene == null:
				_tint_node(seg, _color_for_level(target_level))
			if seg.scale != Vector3.ONE:
				var tween := seg.create_tween()
				tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(seg, "scale", Vector3.ONE, 0.25)
		else:
			seg.scale = Vector3.ZERO


## Override every `MeshInstance3D` in `node` (recursively) with a flat material
## of `color`. Box segments always tint; custom scenes only when the dev set
## `structure_colors`.
func _tint_node(node: Node3D, color: Color):
	if node is MeshInstance3D:
		node.material_override = _make_material(color)
	for child in node.get_children():
		_tint_node(child, color)


func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _finish():
	pad.queue_free()
	completed.emit()
