class_name Bottle
extends RefCounted

var layers: Array
var max_layers: int
var rect: Rect2
var sealed: bool

func _init(p_max: int, w: int):
	max_layers = p_max
	rect = Rect2(Vector2.ZERO, Vector2(w, SandsConstants.BOTTLE_H))
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
