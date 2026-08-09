## Floating touch/mouse joystick.
##
## Captures screen touches (or mouse when `visible_on_desktop` is true) and
## exposes a normalized movement vector in `vector` (length ≤ 1). Add the
## `joystick.tscn` scene to a HUD `CanvasLayer`; the player controller picks it
## up automatically via the "joystick" group. When hidden on desktop the
## joystick stops consuming input entirely.
extends Control

## Max distance from the start point; input is clamped to this radius.
@export var radius := 60.0

## Visual size of the knob.
@export var knob_radius := 30.0

## Show the joystick on desktop too (normally mouse users drive with WASD).
@export var visible_on_desktop := false

## Normalized movement vector, updated while active and reset on release.
var vector := Vector2.ZERO

var _active := false
var _base_pos := Vector2.ZERO
var _touch_index := -1

@onready var base_panel: Panel = $Base
@onready var knob_panel: Panel = $Knob


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("joystick")
	base_panel.visible = false
	knob_panel.visible = false
	if not visible_on_desktop and not DisplayServer.get_name().contains("mobile"):
		visible = false


func _unhandled_input(event):
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		if not _active:
			_start(event.position)
			_touch_index = event.index
	else:
		if _active and _touch_index == event.index:
			_stop()


func _handle_drag(event: InputEventScreenDrag):
	if _active and _touch_index == event.index:
		_update(event.position)


func _handle_mouse(event: InputEventMouseButton):
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if not _active:
			_start(event.position)
			_touch_index = -1
	else:
		if _active and _touch_index == -1:
			_stop()


func _handle_mouse_motion(event: InputEventMouseMotion):
	if _active and _touch_index == -1:
		_update(event.position)


func _start(pos: Vector2):
	_active = true
	_base_pos = pos
	base_panel.visible = true
	knob_panel.visible = true
	base_panel.position = pos - Vector2(radius, radius)
	knob_panel.position = pos - Vector2(knob_radius, knob_radius)
	vector = Vector2.ZERO


func _update(pos: Vector2):
	var delta := pos - _base_pos
	var len := delta.length()
	if len > radius:
		delta = delta / len * radius
	vector = delta / radius
	knob_panel.position = _base_pos + delta - Vector2(knob_radius, knob_radius)


func _stop():
	_active = false
	vector = Vector2.ZERO
	base_panel.visible = false
	knob_panel.visible = false
