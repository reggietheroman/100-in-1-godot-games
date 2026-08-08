extends Node2D

var bottles: Array
var selected := -1
var moves := 0
var won := false

@onready var back_btn: Button = $CanvasLayer/BackButton
@onready var reset_btn: Button = $CanvasLayer/ResetButton
@onready var move_lbl: Label = $CanvasLayer/MoveLabel
@onready var win_lbl: Label = $CanvasLayer/WinLabel
@onready var tap_lbl: Label = $CanvasLayer/TapLabel


func _ready():
	bottles = SandsPuzzleGenerator.generate()
	_layout()
	queue_redraw()
	back_btn.pressed.connect(_on_back)
	reset_btn.pressed.connect(_on_reset)


func _layout():
	var vp := get_viewport_rect().size
	var grid_w := SandsConstants.SMALL_COLS * SandsConstants.BOTTLE_W + (SandsConstants.SMALL_COLS - 1) * SandsConstants.COL_GAP
	var total_h := 2 * SandsConstants.BOTTLE_H + SandsConstants.ROW_GAP

	var ox := maxf(0.0, (vp.x - grid_w) / 2)
	var oy := maxf(0.0, (vp.y - total_h) / 2)

	for row in 2:
		for col in SandsConstants.SMALL_COLS:
			var i := row * SandsConstants.SMALL_COLS + col
			bottles[i].rect.position = Vector2(
				ox + col * (SandsConstants.BOTTLE_W + SandsConstants.COL_GAP),
				oy + row * (SandsConstants.BOTTLE_H + SandsConstants.ROW_GAP)
			)


func _draw():
	var vp := get_viewport_rect().size
	SandsDrawer.draw_background(self, vp)
	for i in bottles.size():
		SandsDrawer.draw_bottle(self, bottles[i] as Bottle, i, selected)


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
	for i in 7:
		if not bottles[i].sealed:
			return
	won = true
	tap_lbl.visible = false
	win_lbl.visible = true


func _on_back():
	get_tree().change_scene_to_file("res://scenes/games/sands_of_hanoi/title.tscn")


func _on_reset():
	selected = -1
	moves = 0
	won = false
	move_lbl.text = "Moves: 0"
	tap_lbl.visible = true
	win_lbl.visible = false
	bottles = SandsPuzzleGenerator.generate()
	_layout()
	queue_redraw()
