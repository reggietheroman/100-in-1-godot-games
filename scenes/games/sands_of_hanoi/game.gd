extends Node2D

const COLORS := {
	"red": Color(0.90, 0.18, 0.15),
	"blue": Color(0.15, 0.42, 0.92),
	"green": Color(0.12, 0.82, 0.28),
	"yellow": Color(0.96, 0.86, 0.08),
	"orange": Color(0.96, 0.54, 0.08),
	"purple": Color(0.72, 0.18, 0.88),
	"pink": Color(0.96, 0.38, 0.64),
	"cyan": Color(0.08, 0.82, 0.92),
}
const COLOR_NAMES := ["red", "blue", "green", "yellow", "orange", "purple", "pink", "cyan"]

const BOTTLE_W := 56
const BOTTLE_H := 160
const LAYER_GAP := 1
const COL_GAP := 14
const ROW_GAP := 30
const PAD := 4
const SMALL_COLS := 4


class Bottle:
	var layers: Array
	var max_layers: int
	var rect: Rect2
	var sealed: bool

	func _init(p_max: int, w: int):
		max_layers = p_max
		rect = Rect2(Vector2.ZERO, Vector2(w, BOTTLE_H))
		layers = []
		sealed = false

	func top_color() -> String:
		return "" if layers.is_empty() else layers[-1]

	func is_full() -> bool:
		return layers.size() >= max_layers

	func is_empty() -> bool:
		return layers.is_empty()

	func check_seal():
		if not is_full():
			return
		var first = layers[0]
		for l in layers:
			if l != first:
				return
		sealed = true


var bottles: Array
var selected := -1
var moves := 0
var won := false

@onready var back_btn: Button = $CanvasLayer/BackButton
@onready var move_lbl: Label = $CanvasLayer/MoveLabel
@onready var win_lbl: Label = $CanvasLayer/WinLabel
@onready var tap_lbl: Label = $CanvasLayer/TapLabel


func _ready():
	_generate()
	_layout()
	queue_redraw()
	back_btn.pressed.connect(_on_back)


func _generate():
	bottles.clear()

	for i in 9:
		var max_layers = 5 if i < 8 else 10
		var w = BOTTLE_W if i < 8 else BOTTLE_W + 8
		bottles.append(Bottle.new(max_layers, w))

	var colors := COLOR_NAMES.duplicate()
	colors.shuffle()
	var rng := RandomNumberGenerator.new()

	for pair in 4:
		var a = colors[pair * 2]
		var b = colors[pair * 2 + 1]
		var n = rng.randi_range(1, 4)

		for _i in n:
			bottles[pair * 2].layers.append(a)
		for _i in (5 - n):
			bottles[pair * 2].layers.append(b)

		for _i in n:
			bottles[pair * 2 + 1].layers.append(b)
		for _i in (5 - n):
			bottles[pair * 2 + 1].layers.append(a)

	for i in 8:
		bottles[i].check_seal()


func _layout():
	var vp := get_viewport_rect().size
	var grid_w := SMALL_COLS * BOTTLE_W + (SMALL_COLS - 1) * COL_GAP
	var rows_h := 2 * BOTTLE_H + ROW_GAP
	var total_h := rows_h + ROW_GAP + BOTTLE_H

	var ox := maxf(0.0, (vp.x - grid_w) / 2)
	var oy := maxf(0.0, (vp.y - total_h) / 2)

	for row in 2:
		for col in SMALL_COLS:
			var i := row * SMALL_COLS + col
			bottles[i].rect.position = Vector2(
				ox + col * (BOTTLE_W + COL_GAP),
				oy + row * (BOTTLE_H + ROW_GAP)
			)

	var big = bottles[8]
	big.rect.position = Vector2(
		(vp.x - big.rect.size.x) / 2,
		oy + rows_h + ROW_GAP
	)


func _draw():
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.08, 0.08, 0.11))
	for i in bottles.size():
		_draw_bottle(i)


func _draw_bottle(i: int):
	var b := bottles[i] as Bottle
	var r := b.rect

	draw_rect(r, Color(0.75, 0.70, 0.60))

	var inner := Rect2(
		r.position.x + PAD, r.position.y + PAD,
		r.size.x - PAD * 2.0, r.size.y - PAD * 2.0
	)
	draw_rect(inner, Color(0.12, 0.12, 0.15))

	var layer_h := (inner.size.y - (b.max_layers - 1.0) * LAYER_GAP) / b.max_layers
	for j in b.layers.size():
		var c = COLORS[b.layers[j]]
		var ly := inner.position.y + inner.size.y - (j + 1.0) * (layer_h + LAYER_GAP) + LAYER_GAP
		draw_rect(Rect2(inner.position.x, ly, inner.size.x, layer_h), c)

	if b.sealed:
		draw_rect(r, Color(0, 1, 0, 0.12))

	if i == selected:
		draw_rect(r, Color(1, 1, 0, 0.45), false, 3.0)


func _unhandled_input(event):
	if won:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)
	if event is InputEventScreenTouch and event.pressed:
		_click(event.position)


func _click(pos: Vector2):
	var hit := -1
	for i in bottles.size():
		if bottles[i].rect.has_point(pos):
			hit = i
			break

	if hit == -1:
		selected = -1
		queue_redraw()
		return

	if selected == -1:
		if not bottles[hit].is_empty() and not bottles[hit].sealed:
			selected = hit
			queue_redraw()
		return

	if hit == selected:
		selected = -1
		queue_redraw()
		return

	if _pour(selected, hit):
		moves += 1
		move_lbl.text = "Moves: " + str(moves)
		_check_win()

	selected = -1
	queue_redraw()


func _pour(from: int, to: int, seal: bool = true) -> bool:
	var src := bottles[from] as Bottle
	var dst := bottles[to] as Bottle

	if src.is_empty() or src.sealed:
		return false
	if dst.is_full() or dst.sealed:
		return false
	if not dst.is_empty() and src.top_color() != dst.top_color():
		return false

	var color := src.top_color()
	var count := 0
	for i in range(src.layers.size() - 1, -1, -1):
		if src.layers[i] == color:
			count += 1
		else:
			break

	count = min(count, dst.max_layers - dst.layers.size())
	if count == 0:
		return false

	for _i in range(count):
		dst.layers.append(src.layers.pop_back())

	if seal:
		dst.check_seal()
	return true


func _check_win():
	for i in 8:
		if not bottles[i].sealed:
			return
	won = true
	tap_lbl.visible = false
	win_lbl.visible = true


func _on_back():
	get_tree().change_scene_to_file("res://scenes/menu/menu.tscn")
