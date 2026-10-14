extends Node2D

const EnemyProjectileScript := preload("res://scripts/enemy_projectile.gd")

var main
var player
var hp := 20.0
var speed := 80.0
var radius := 12.0
var contact_damage := 8.0
var drop_bonus := 0
var tint := Color(0.9, 0.3, 0.3)

# 원거리 적 설정
var is_ranged := false
var shot_damage := 7.0
var shot_interval := 3.6
var keep_far := 320.0   # 이 거리보다 멀면 다가감
var keep_near := 200.0  # 이 거리보다 가까우면 물러남
var shoot_range := 480.0

var _dying := false
var _shoot_timer := randf_range(2.0, 3.6)


func _ready() -> void:
	add_to_group("enemies")


func _process(delta: float) -> void:
	if player == null or player.dead:
		return
	var d: Vector2 = player.position - position
	var dist := d.length()
	if is_ranged:
		# 일정 거리를 유지하며 사격
		if dist > keep_far:
			position += d.normalized() * speed * delta
		elif dist < keep_near:
			position -= d.normalized() * speed * 0.6 * delta
		_shoot_timer -= delta
		if _shoot_timer <= 0.0 and dist < shoot_range:
			_shoot_timer = shot_interval
			_shoot(d.normalized())
	elif dist > 1.0:
		position += d.normalized() * speed * delta
	queue_redraw()


func hit(amount: float) -> void:
	if _dying:
		return
	hp -= amount
	if hp <= 0.0:
		_dying = true
		main.on_enemy_killed(self)
		queue_free()


func _shoot(dir: Vector2) -> void:
	var p = EnemyProjectileScript.new()
	p.position = position
	p.direction = dir
	p.damage = shot_damage
	p.player = player
	main.add_child(p)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, tint)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, tint.darkened(0.5), 2.0)
	if is_ranged:
		# 원거리 적은 가운데 밝은 점으로 구분
		draw_circle(Vector2.ZERO, radius * 0.4, Color(1.0, 0.9, 0.5))
