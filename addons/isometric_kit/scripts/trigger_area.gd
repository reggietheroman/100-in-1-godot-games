## Trigger zone that reports player/enemy enter and exit events.
##
## An `Area3D` that watches bodies in the "player" and/or "enemy" groups and
## emits a signal each time one enters or exits. Also draws a translucent box
## that highlights while anything tracked is inside (use `inactive_color` /
## `active_color`).
extends Area3D

## Emit enter/exit signals for "player"-group bodies.
@export var track_player := true

## Emit enter/exit signals for "enemy"-group bodies.
@export var track_enemies := true

## Footprint size of the zone (full extents, not half-extents).
@export var area_size := Vector3(2.0, 2.0, 2.0)

## Visual color while at least one tracked body is inside.
@export var active_color := Color(0.3, 1.0, 0.3, 0.35)

## Visual color while empty.
@export var inactive_color := Color(0.5, 0.5, 0.5, 0.35)

## A "player"-group body entered the zone.
signal player_entered(area: Area3D)

## A "player"-group body left the zone.
signal player_exited(area: Area3D)

## An "enemy"-group body entered the zone.
signal enemy_entered(area: Area3D)

## An "enemy"-group body left the zone.
signal enemy_exited(area: Area3D)

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var visual: MeshInstance3D = $Visual

var _inside: Array = []


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_size()
	_set_color(inactive_color)


func _apply_size():
	if collision != null:
		var shape := collision.shape as BoxShape3D
		if shape != null:
			shape.size = area_size
	if visual != null and visual.mesh is BoxMesh:
		(visual.mesh as BoxMesh).size = Vector3(area_size.x, 0.1, area_size.z)
		visual.position = Vector3(0, 0.05, 0)


func _on_body_entered(body: Node3D):
	var tracked := false
	if track_player and body.is_in_group("player"):
		player_entered.emit(self)
		tracked = true
	if track_enemies and body.is_in_group("enemy"):
		enemy_entered.emit(self)
		tracked = true
	if tracked:
		_inside.append(body)
		_set_color(active_color)


func _on_body_exited(body: Node3D):
	var tracked := false
	if track_player and body.is_in_group("player"):
		player_exited.emit(self)
		tracked = true
	if track_enemies and body.is_in_group("enemy"):
		enemy_exited.emit(self)
		tracked = true
	if tracked:
		_inside.erase(body)
		if _inside.is_empty():
			_set_color(inactive_color)


func _set_color(color: Color):
	if visual == null:
		return
	if visual.material_override == null:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		visual.material_override = mat
	visual.material_override.albedo_color = color


func get_center() -> Vector3:
	return global_position
