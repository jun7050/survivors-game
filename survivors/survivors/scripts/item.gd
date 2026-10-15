extends Node2D

const MAGNET_SPEED := 420.0

var main
var player
var type := "power"
var color := Color.WHITE
var is_special := false  # 폭탄/관통탄/폭발탄 같은 특수 아이템
var glyph := ""          # 특수 아이템 가운데에 표시할 글자 (종류 구분용)

var _t := 0.0
var _magnet := false


func _ready() -> void:
	_t = randf() * TAU
	add_to_group("items")


# 자석 아이템 효과: 능력치 아이템만 거리와 상관없이 끌려옴 (폭탄/관통탄/폭발탄/자석 같은 특수 아이템은 제외)
func attract() -> void:
	if is_special:
		return
	_magnet = true


func _process(delta: float) -> void:
	_t += delta * 4.0
	if player != null and not player.dead:
		var dist: float = position.distance_to(player.position)
		if dist < player.pickup_range:
			_magnet = true
		if _magnet:
			position = position.move_toward(player.position, MAGNET_SPEED * delta)
		if dist < 16.0:
			main.apply_item(type)
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t) * 2.5
	var c := Vector2(0, bob)
	if is_special:
		# 특수 아이템은 일반 아이템(마름모)보다 크고, 흰 원 + 색 테두리로 구분됨
		draw_circle(c, 11.0, Color(1, 1, 1))
		draw_arc(c, 11.0, 0.0, TAU, 24, color, 4.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-5.0, 5.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.1, 0.1, 0.1))
		return
	var pts := PackedVector2Array([
		c + Vector2(0, -9), c + Vector2(8, 0), c + Vector2(0, 9), c + Vector2(-8, 0)
	])
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, color.darkened(0.5), 1.5)
