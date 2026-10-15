extends Node2D

signal died

const ProjectileScript := preload("res://scripts/projectile.gd")
const RADIUS := 14.0

var main
var speed := 230.0
var max_hp := 100.0
var hp := 100.0
var damage := 12.0
var attack_interval := 0.7
var projectile_count := 1
var pickup_range := 100.0
var dead := false

var _attack_timer := 0.0
var _invuln := 0.0


func _process(delta: float) -> void:
	if dead:
		return

	# WASD 이동 (main.gd에서 move_* 액션을 등록함)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += dir * speed * delta

	_invuln = maxf(0.0, _invuln - delta)

	# 자동 공격: 가장 가까운 적에게 발사
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		var target = main.nearest_enemy(position)
		if target != null:
			_fire(target)
			_attack_timer = attack_interval

	# 접촉 피해
	if _invuln <= 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if position.distance_to(e.position) < RADIUS + e.radius:
				take_damage(e.contact_damage)
				break

	queue_redraw()


func _fire(target: Node2D) -> void:
	var base_dir := (target.position - position).normalized()
	for i in range(projectile_count):
		var offset := (i - (projectile_count - 1) / 2.0) * 0.16
		var p = ProjectileScript.new()
		p.position = position
		p.direction = base_dir.rotated(offset)
		p.damage = damage
		p.pierce = main.pierce_time > 0.0
		p.explosive = main.explosive_time > 0.0
		main.add_child(p)


func take_damage(amount: float) -> void:
	if dead or _invuln > 0.0:
		return
	hp -= amount
	_invuln = 0.5
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func _draw() -> void:
	var col := Color(0.35, 0.7, 1.0)
	if _invuln > 0.0 and int(_invuln * 20.0) % 2 == 0:
		col = Color(1, 1, 1)
	draw_circle(Vector2.ZERO, RADIUS, col)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(0.1, 0.2, 0.4), 2.0)
	# 획득 범위를 옅게 표시
	draw_arc(Vector2.ZERO, pickup_range, 0.0, TAU, 64, Color(0.4, 0.6, 1.0, 0.12), 1.0)
