extends Node2D

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ItemScript := preload("res://scripts/item.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")

const MAX_ENEMIES := 350

# 밸런스 조절용 값 (여기만 바꾸면 됨)
const HP_SCALE_SECONDS := 90.0      # 작을수록 적 체력이 빨리 불어남 (90초마다 기본 체력만큼 추가)
const DAMAGE_SCALE_SECONDS := 240.0 # 작을수록 적 공격력이 빨리 오름
const DROP_CHANCE := 0.33           # 일반 적 아이템 드롭 확률
const ELITE_EXTRA_DROP := 0.5       # 덩치 큰 적이 2개째를 줄 확률 (1개는 확정)
const UPGRADE_BASE := 1             # 필요 아이템 수 = 현재 레벨 + 이 값 (1이면 Lv0→1은 1개, Lv1→2는 2개, Lv2→3은 3개...)
const RANGED_CHANCE := 0.1          # 전체 적 중 원거리 적 비율 (20초 이후부터 등장)
const VACUUM_DROP_CHANCE := 0.015   # 적 처치 시 자석 아이템 드롭 확률
const BOMB_DROP_CHANCE := 0.007     # 적 처치 시 폭탄 아이템 드롭 확률

# 특수 아이템 (능력치가 아니라 즉시 효과). 색은 테두리 색
const SPECIAL_ITEMS := {
	"vacuum": {"color": Color(0.75, 0.45, 1.0)},
	"bomb": {"color": Color(1.0, 0.45, 0.1)},
}

# 색상별 능력치 (색 -> 능력치는 여기서 고정). desc는 화면에 표시되는 설명
const ITEM_TYPES := {
	"power": {"name": "공격력", "desc": "빨강 공격력 +5", "color": Color(1.0, 0.35, 0.3), "weight": 30},
	"haste": {"name": "공격속도", "desc": "노랑 공격속도 +15%", "color": Color(1.0, 0.85, 0.2), "weight": 25},
	"boots": {"name": "이동속도", "desc": "초록 이동속도 +20", "color": Color(0.4, 0.9, 0.4), "weight": 20},
	"heart": {"name": "최대체력", "desc": "분홍 최대체력 +25 (회복 포함)", "color": Color(1.0, 0.5, 0.75), "weight": 15},
	"magnet": {"name": "획득범위", "desc": "파랑 획득범위 +35", "color": Color(0.4, 0.6, 1.0), "weight": 8},
	"multi": {"name": "투사체", "desc": "하늘 투사체 +1", "color": Color(0.3, 0.95, 0.95), "weight": 4},
}

var player
var hud: Label
var hp_bar: ProgressBar
var msg: Label

var elapsed := 0.0
var kills := 0
var spawn_acc := 0.0
var game_over := false
var levels := {}    # 색(능력치)별 현재 레벨
var progress := {}  # 색별로 다음 레벨업을 위해 모은 아이템 수
var legend := {}
var notice: Label
var notice_timer := 0.0
var _suppress_drops := false  # 폭탄으로 죽인 적은 아이템을 떨구지 않음


func _ready() -> void:
	randomize()
	_setup_input()

	player = PlayerScript.new()
	player.main = self
	player.died.connect(_on_player_died)
	add_child(player)

	var cam := Camera2D.new()
	player.add_child(cam)

	_build_hud()


func _setup_input() -> void:
	# 물리 키 코드를 써서 한글 자판 상태에서도 WASD가 동작함
	var map := {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_up": KEY_W,
		"move_down": KEY_S,
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = map[action]
			InputMap.action_add_event(action, ev)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(16, 16)
	hp_bar.size = Vector2(260, 22)
	hp_bar.show_percentage = false
	layer.add_child(hp_bar)

	hud = Label.new()
	hud.position = Vector2(16, 46)
	layer.add_child(hud)

	# 색상별 능력치 범례 + 진행도 (현재 개수/필요 개수)
	var y := 100.0
	for k in ITEM_TYPES:
		var box := ColorRect.new()
		box.color = ITEM_TYPES[k]["color"]
		box.position = Vector2(16, y + 4.0)
		box.size = Vector2(14, 14)
		layer.add_child(box)
		var lb := Label.new()
		lb.position = Vector2(38, y)
		layer.add_child(lb)
		legend[k] = lb
		y += 24.0

	notice = Label.new()
	notice.position = Vector2(0, 70)
	notice.size = Vector2(1280, 40)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 22)
	layer.add_child(notice)

	msg = Label.new()
	msg.position = Vector2(0, 280)
	msg.size = Vector2(1280, 160)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 32)
	layer.add_child(msg)


func _process(delta: float) -> void:
	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0:
			notice.text = ""

	elapsed += delta
	spawn_acc += delta
	var interval := maxf(0.2, 0.9 - elapsed * 0.006)
	var count := get_tree().get_nodes_in_group("enemies").size()
	while spawn_acc >= interval:
		spawn_acc -= interval
		if count < MAX_ENEMIES:
			_spawn_enemy()
			count += 1

	_update_hud()
	queue_redraw()


func _spawn_enemy() -> void:
	var e = EnemyScript.new()
	e.main = self
	e.player = player
	e.position = player.position + Vector2.from_angle(randf() * TAU) * randf_range(700.0, 850.0)
	var hp_scale := 1.0 + elapsed / HP_SCALE_SECONDS
	var dmg_scale := 1.0 + elapsed / DAMAGE_SCALE_SECONDS
	e.hp = 18.0 * hp_scale
	e.speed = randf_range(60.0, 100.0) + minf(elapsed * 0.3, 60.0)
	e.contact_damage = 8.0 * dmg_scale
	if randf() < 0.1:
		# 덩치 큰 적: 느리지만 단단하고 아이템을 확정으로 줌
		e.radius = 19.0
		e.hp *= 3.0
		e.speed *= 0.7
		e.contact_damage = 14.0 * dmg_scale
		e.drop_bonus = 1
		e.tint = Color(0.75, 0.2, 0.6)
	elif elapsed > 20.0 and randf() < RANGED_CHANCE / 0.9:
		# 원거리 적: 거리를 유지하며 탄을 쏨. 체력은 낮음
		# (위 10%를 뺀 나머지 90% 중에서 뽑으므로 0.9로 나눠 전체 기준 비율을 맞춤)
		e.is_ranged = true
		e.radius = 11.0
		e.hp *= 0.7
		e.speed *= 0.85
		e.shot_damage = 7.0 * dmg_scale
		e.tint = Color(0.95, 0.6, 0.2)
	add_child(e)


func nearest_enemy(pos: Vector2, max_dist := 700.0):
	var best = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		var d: float = pos.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func on_enemy_killed(e) -> void:
	kills += 1
	if _suppress_drops:
		return
	_roll_special_drop(e.position)
	var n := 0
	if e.drop_bonus > 0:
		n = 1 + (1 if randf() < ELITE_EXTRA_DROP else 0)
	elif randf() < DROP_CHANCE:
		n = 1
	for i in range(n):
		_spawn_item(e.position + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0)))


func _spawn_item(pos: Vector2, special := "") -> void:
	var it = ItemScript.new()
	it.main = self
	it.player = player
	it.position = pos
	if special != "":
		it.type = special
		it.is_special = true
		it.color = SPECIAL_ITEMS[special]["color"]
	else:
		var type := _pick_item_type()
		it.type = type
		it.color = ITEM_TYPES[type]["color"]
	call_deferred("add_child", it)


func _roll_special_drop(pos: Vector2) -> void:
	var r := randf()
	if r < BOMB_DROP_CHANCE:
		_spawn_item(pos, "bomb")
	elif r < BOMB_DROP_CHANCE + VACUUM_DROP_CHANCE:
		_spawn_item(pos, "vacuum")


func _pick_item_type() -> String:
	var total := 0
	for k in ITEM_TYPES:
		total += ITEM_TYPES[k]["weight"]
	var r := randi() % total
	for k in ITEM_TYPES:
		r -= ITEM_TYPES[k]["weight"]
		if r < 0:
			return k
	return "power"


func apply_item(type: String) -> void:
	# 특수 아이템은 즉시 효과만 있고 레벨업 규칙과는 무관함
	if type == "vacuum":
		_use_vacuum()
		return
	if type == "bomb":
		_use_bomb()
		return
	# 같은 색을 (현재 레벨 + UPGRADE_BASE)개 모으면 그 능력치가 1 오르고, 모은 개수는 0으로 돌아감
	var lv: int = levels.get(type, 0)
	progress[type] = progress.get(type, 0) + 1
	if progress[type] < lv + UPGRADE_BASE:
		return
	progress[type] = 0
	levels[type] = lv + 1
	match type:
		"power":
			player.damage += 5.0
		"haste":
			player.attack_interval = maxf(0.12, player.attack_interval * 0.87)
		"boots":
			player.speed += 20.0
		"heart":
			player.max_hp += 25.0
			player.heal(25.0)
		"magnet":
			player.pickup_range += 35.0
		"multi":
			player.projectile_count = mini(8, player.projectile_count + 1)


func _use_vacuum() -> void:
	for it in get_tree().get_nodes_in_group("items"):
		it.attract()
	_show_notice("자석! 맵의 모든 아이템을 끌어당겨요")


func _use_bomb() -> void:
	# 화면(카메라가 보는 영역) 안의 적을 즉사시키고 적 탄도 지움
	var half := get_viewport_rect().size / 2.0
	_suppress_drops = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		var d: Vector2 = e.position - player.position
		if absf(d.x) <= half.x and absf(d.y) <= half.y:
			e.hit(1.0e9)
	_suppress_drops = false
	for s in get_tree().get_nodes_in_group("enemy_shots"):
		s.queue_free()
	_show_notice("폭탄! 화면 안의 적을 모두 제거했어요")


func _show_notice(text: String) -> void:
	notice.text = text
	notice_timer = 2.5


func _update_hud() -> void:
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	var t := int(elapsed)
	var line1 := "시간 %02d:%02d   처치 %d   HP %d/%d" % [t / 60, t % 60, kills, int(player.hp), int(player.max_hp)]
	var line2 := "공격력 %d   공격속도 %.2f/초   이동속도 %d   투사체 %d   획득범위 %d" % [
		int(player.damage), 1.0 / player.attack_interval, int(player.speed),
		player.projectile_count, int(player.pickup_range)
	]
	hud.text = line1 + "\n" + line2
	for k in ITEM_TYPES:
		var lv: int = levels.get(k, 0)
		var have: int = progress.get(k, 0)
		legend[k].text = "%s   %d/%d   (Lv.%d)" % [
			ITEM_TYPES[k]["desc"], have, lv + UPGRADE_BASE, lv
		]


func _on_player_died() -> void:
	game_over = true
	notice.text = ""
	var t := int(elapsed)
	msg.text = "게임 오버\n생존 %02d:%02d / 처치 %d\nR 키로 다시 시작" % [t / 60, t % 60, kills]


func _draw() -> void:
	# 이동하는 느낌을 주기 위한 바닥 격자
	var c: Vector2 = player.position
	var step := 100.0
	var col := Color(1, 1, 1, 0.05)
	var sx := floorf((c.x - 800.0) / step) * step
	var sy := floorf((c.y - 480.0) / step) * step
	for i in range(18):
		var x := sx + i * step
		draw_line(Vector2(x, c.y - 500.0), Vector2(x, c.y + 500.0), col)
	for j in range(11):
		var y := sy + j * step
		draw_line(Vector2(c.x - 820.0, y), Vector2(c.x + 820.0, y), col)
