## Static helper for spawning loot drops on the ground.
##
## `LootDrop.spawn(loot_scene, at, parent)` instantiates a loot scene (usually
## `loot_item.tscn`) and places it on the ground at `at`'s x/z. Used by
## `enemy_mover.die()` to drop an enemy's configured `loot_scene`, and handy for
## games that want to spawn pickups at arbitrary spots.
##
## No instance needed — call the statics directly:
## `var item := LootDrop.spawn(scene, pos, self)`
extends RefCounted

## How high above the ground plane (y=0) loot items rest.
const GROUND_Y := 0.25

## Instantiates `loot_scene` at `at` (x/z kept, y snapped to `GROUND_Y`) under
## `parent`, and returns the new item.
static func spawn(loot_scene: PackedScene, at: Vector3, parent: Node) -> Node3D:
	if loot_scene == null or parent == null:
		return null
	var item: Node3D = loot_scene.instantiate()
	item.position = Vector3(at.x, GROUND_Y, at.z)
	parent.add_child(item)
	return item
