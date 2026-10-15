extends Node2D

const ExplosionScript := preload("res://scripts/explosion_fx.gd")
const EXPLOSION_RADIUS := 85.0
const EXPLOSION_DAMAGE_RATIO := 0.6  # 폭발은 직격 피해의 이 비율을 주변 적에게 줌

var direction := Vector2.RIGHT
var damage := 10.0
var speed := 520.0
var life := 1.6
var pierce := false     # 관통탄: 적을 맞혀도 사라지지 않고 계속 날아감
var explosive := false  # 폭발탄: 맞은 자리에서 주변 적에게도 피해를 줌

var _hit := {}  # 관통탄이 같은 적을 여러 번 때리지 않도록 이미 맞힌 적을 기록


func _process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		if pierce and _hit.has(e):
			continue
		if position.distance_to(e.position) < e.radius + 5.0:
			e.hit(damage)
			if explosive:
				_explode(e)
			if pierce:
				_hit[e] = true
			else:
				queue_free()
				return


func _explode(origin: Node2D) -> void:
	var pos := origin.position
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == origin or other.is_queued_for_deletion():
			continue
		if pos.distance_to(other.position) < EXPLOSION_RADIUS + other.radius:
			other.hit(damage * EXPLOSION_DAMAGE_RATIO)
	var fx = ExplosionScript.new()
	fx.position = pos
	fx.radius = EXPLOSION_RADIUS
	get_parent().add_child(fx)


func _draw() -> void:
	var col := Color(1.0, 0.9, 0.4)
	if explosive:
		col = Color(1.0, 0.4, 0.15)
	elif pierce:
		col = Color(0.4, 0.9, 1.0)
	draw_circle(Vector2.ZERO, 5.0, col)
	if pierce:
		# 관통탄은 뒤쪽에 꼬리를 그려서 구분
		draw_line(Vector2.ZERO, -direction * 16.0, col, 3.0)
