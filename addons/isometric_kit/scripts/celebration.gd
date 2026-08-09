## Celebration: a brief, self-freeing popup for a win/upgrade moment. Plays a
## billboarded `Label3D` message that pops in, floats up and fades out, plus a
## confetti burst in the given color. Add it to the tree, then call
## `celebrate(text, color)`; the node frees itself when the animation ends.
##
## Owned by a parent component (e.g. `build_site` plays one above the structure
## on every level-up) or dropped into any scene that wants a burst of
## positivity.
extends Node3D

## How far the message floats up before fading out.
@export var rise := 1.6

## Seconds the message holds at its peak before fading.
@export var hold_time := 0.55

## The billboarded message label.
@onready var label: Label3D = $Label

## The confetti burst.
@onready var particles: CPUParticles3D = $Confetti

var _tween: Tween


func _ready():
	label.modulate.a = 0.0
	label.scale = Vector3.ZERO
	particles.emitting = false


## Play the celebration with `text` tinted `color`. Calling again restarts it.
func celebrate(text: String, color: Color):
	if _tween:
		_tween.kill()
	label.text = text
	label.modulate = Color(color.r, color.g, color.b, 0.0)
	label.scale = Vector3.ZERO
	label.position.y = -0.4
	particles.color = color
	particles.restart()
	particles.emitting = true

	_tween = create_tween()
	_tween.tween_property(label, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(label, "modulate:a", 1.0, 0.18)
	_tween.parallel().tween_property(label, "position:y", rise, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	_tween.parallel().tween_property(label, "scale", Vector3(1.2, 1.2, 1.2), 0.5)
	_tween.tween_callback(queue_free)
