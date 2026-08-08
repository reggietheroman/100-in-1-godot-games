class_name SandsDrawer
extends RefCounted

static func draw_background(canvas: Node2D, vp: Vector2):
	canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.08, 0.08, 0.11))

static func draw_bottle(canvas: Node2D, b: Bottle, index: int, selected: int):
	var r := b.rect

	canvas.draw_rect(r, Color(0.75, 0.70, 0.60))

	var inner := Rect2(
		r.position.x + SandsConstants.PAD, r.position.y + SandsConstants.PAD,
		r.size.x - SandsConstants.PAD * 2.0, r.size.y - SandsConstants.PAD * 2.0
	)
	canvas.draw_rect(inner, Color(0.12, 0.12, 0.15))

	var layer_h := (inner.size.y - (b.max_layers - 1.0) * SandsConstants.LAYER_GAP) / b.max_layers
	for j in b.layers.size():
		var c = SandsConstants.COLORS[b.layers[j]]
		var ly := inner.position.y + inner.size.y - (j + 1.0) * (layer_h + SandsConstants.LAYER_GAP) + SandsConstants.LAYER_GAP
		canvas.draw_rect(Rect2(inner.position.x, ly, inner.size.x, layer_h), c)

	if b.sealed:
		canvas.draw_rect(r, Color(0, 1, 0, 0.12))

	if index == SandsConstants.WORKSPACE:
		canvas.draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)

	if index == selected:
		canvas.draw_rect(r, Color(1, 1, 0, 0.45), false, 3.0)
