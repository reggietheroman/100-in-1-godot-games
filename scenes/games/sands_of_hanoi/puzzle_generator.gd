class_name SandsPuzzleGenerator
extends RefCounted

const BIBD := [
	[3, 4, 5, 6],
	[1, 2, 5, 6],
	[1, 2, 3, 4],
	[0, 2, 4, 6],
	[0, 2, 3, 5],
	[0, 1, 4, 5],
	[0, 1, 3, 6],
]

static func generate() -> Array:
	var bottles: Array = []
	for i in 8:
		bottles.append(Bottle.new(SandsConstants.SMALL_CAPACITY, SandsConstants.BOTTLE_W))

	var color_pool := SandsConstants.COLOR_NAMES.slice(0, SandsConstants.USE_COLORS)
	var indices := []
	for u in SandsConstants.USE_COLORS:
		indices.append(u)
	indices.shuffle()

	var order := []
	for u in 7:
		order.append(u)
	order.shuffle()

	for bi in 7:
		var block = BIBD[order[bi]]
		var layers := []
		for c in block:
			layers.append(color_pool[indices[c]])
		layers.shuffle()
		bottles[bi].layers = layers
		bottles[bi].check_seal()

	return bottles
