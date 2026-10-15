extends Node2D

const DURATION := 0.25

var radius := 80.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var r := radius * (0.4 + 0.6 * k)
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.15, 0.35 * (1.0 - k)))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 0.8, 0.3, 0.8 * (1.0 - k)), 3.0)
