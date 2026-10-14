extends Node2D

var direction := Vector2.RIGHT
var damage := 10.0
var speed := 520.0
var life := 1.6


func _process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		if position.distance_to(e.position) < e.radius + 5.0:
			e.hit(damage)
			queue_free()
			return


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.9, 0.4))
