extends Node2D

const PLAYER_RADIUS := 14.0

var player
var direction := Vector2.RIGHT
var damage := 7.0
var speed := 260.0
var life := 3.5


func _ready() -> void:
	add_to_group("enemy_shots")


func _process(delta: float) -> void:
	if player == null or player.dead:
		queue_free()
		return

	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return

	if position.distance_to(player.position) < PLAYER_RADIUS + 5.0:
		player.take_damage(damage)
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.55, 0.1))
	draw_arc(Vector2.ZERO, 6.0, 0.0, TAU, 16, Color(0.5, 0.2, 0.0), 1.5)
