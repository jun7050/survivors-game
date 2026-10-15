extends Node2D

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ItemScript := preload("res://scripts/item.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")

const MAX_ENEMIES := 350

# 밸런스 조절용 값 (여기만 바꾸면 됨)
const HP_SCALE_SECONDS := 90.0      # 작을수록 적 체력이 빨리 불어남 (90초마다 기본 체력만큼 추가)
const DAMAGE_SCALE_SECONDS := 240.0 # 작을수록 적 공격력이 빨리 오름
const DROP_CHANCE := 0.45           # 일반 적 능력치 아이템 드롭 확률
const ELITE_EXTRA_DROP := 0.5       # 덩치 큰 적이 2개째를 줄 확률 (1개는 확정)
const UPGRADE_BASE := 1             # 필요 아이템 수 = 현재 레벨 + 이 값 (1이면 Lv0→1은 1개, Lv1→2는 2개, Lv2→3은 3개...)
const RANGED_CHANCE := 0.1          # 전체 적 중 원거리 적 비율 (20초 이후부터 등장)
const VACUUM_DROP_CHANCE := 0.015   # 적 처치 시 자석 아이템 드롭 확률 (능력치 아이템만 끌어당김)
const BOMB_DROP_CHANCE := 0.007     # 적 처치 시 폭탄 아이템 드롭 확률
const PIERCE_DROP_CHANCE := 0.005   # 적 처치 시 관통탄 아이템 드롭 확률
const EXPLOSIVE_DROP_CHANCE := 0.005 # 적 처치 시 폭발탄 아이템 드롭 확률
const AMMO_DURATION := 12.0         # 관통탄/폭발탄 지속 시간(초)

# 보스 (여기 값으로 난이도 조절)
const BOSS_TIME := 300.0            # 구조 비행기 도착 = 보스 등장 시각(초). 테스트할 때는 30 정도로 낮추면 빨리 볼 수 있음
const BOSS_HP := 8000.0             # 보스 체력. 너무 오래 걸리면 낮추고, 너무 빨리 죽으면 올릴 것
const BOMB_BOSS_RATIO := 0.1        # 폭탄이 보스에게 주는 피해 (보스 최대 체력의 비율)

# 스토리 문구
const INTRO_TEXT := "도시는 사흘 전에 무너졌다.\n\n감염된 사람들이 거리를 가득 메웠고,\n당신은 한 건물의 옥상까지 올라와 문을 막았다.\n\n무전기에서 마지막 교신이 흘러나온다.\n“구조 비행기가 옥상으로 간다. 그때까지 버텨라.”\n\n계단을 타고 올라오는 소리는 멈추지 않는다.\n비행기가 도착할 때까지, 살아남아라."
const ENDING_TEXT := "굉음과 함께 구조 비행기가 옥상에 내려앉는다.\n당신은 거대한 변이체의 시체를 넘어 달려간다.\n\n문이 닫히고, 비행기는 불 꺼진 도시 위로 떠오른다.\n\n안도감 속에서 문득 깨닫는다.\n붕대 아래 팔뚝이 욱신거리기 시작했다는 것을."

# 구조대 무전 (비행기 도착까지 남은 초, 대사). 남은 시간이 큰 순서로 적을 것
const RADIO_LINES := [
	[285.0, "[무전] 신호 확인. 구조 비행기가 이륙을 준비 중이다. 버텨라."],
	[240.0, "[무전] 감염자들이 건물 안으로 몰려들고 있다. 계속 움직여라."],
	[180.0, "[무전] 비행기가 출발했다. 도착까지 3분."],
	[120.0, "[무전] 2분 남았다. 연료가 부족해서 한 번에 착륙해야 한다."],
	[60.0, "[무전] 1분! 착륙할 자리를 확보해라. 덩치 큰 놈이 올라오고 있다."],
	[30.0, "[무전] 엔진 소리 들리나? 거의 다 왔다. 30초!"],
	[10.0, "[무전] 10초…! 하늘을 봐라!"],
]

# 특수 아이템 (능력치가 아니라 즉시 효과). 색은 테두리 색, glyph는 가운데 글자, chance는 드롭 확률
const SPECIAL_ITEMS := {
	"bomb": {"color": Color(1.0, 0.45, 0.1), "glyph": "B", "chance": BOMB_DROP_CHANCE},
	"pierce": {"color": Color(0.3, 0.85, 1.0), "glyph": "P", "chance": PIERCE_DROP_CHANCE},
	"explosive": {"color": Color(1.0, 0.25, 0.25), "glyph": "E", "chance": EXPLOSIVE_DROP_CHANCE},
	"vacuum": {"color": Color(0.75, 0.45, 1.0), "glyph": "M", "chance": VACUUM_DROP_CHANCE},
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
var pierce_time := 0.0     # 관통탄 남은 시간(초)
var explosive_time := 0.0  # 폭발탄 남은 시간(초)
var buff_label: Label
var _suppress_drops := false  # 폭탄으로 죽인 적은 아이템을 떨구지 않음

# 스토리/보스 상태. intro_seen은 static이라 R로 재시작해도 인트로를 다시 보여주지 않음
static var intro_seen := false
var started := false
var intro_layer: CanvasLayer
var boss
var boss_spawned := false
var boss_bar: ProgressBar
var boss_label: Label
var radio_label: Label
var radio_timer := 0.0
var radio_next := 0       # 다음에 나올 무전 대사 번호
var boss_half_said := false


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

	# 처음 실행할 때만 인트로를 보여주고, 키를 누를 때까지 게임을 멈춰 둠
	started = intro_seen
	intro_layer.visible = not started
	if not started:
		player.set_process(false)


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

	# 관통탄/폭발탄 남은 시간 표시 (능력치 범례 바로 아래)
	buff_label = Label.new()
	buff_label.position = Vector2(16, y + 8.0)
	layer.add_child(buff_label)

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

	# 구조대 무전 대사 (화면 아래 가운데)
	radio_label = Label.new()
	radio_label.position = Vector2(0, 640)
	radio_label.size = Vector2(1280, 40)
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_label.add_theme_font_size_override("font_size", 20)
	radio_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	layer.add_child(radio_label)

	# 보스 체력바 (보스가 나타나기 전에는 숨김)
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(340, 16)
	boss_bar.size = Vector2(600, 20)
	boss_bar.show_percentage = false
	boss_bar.visible = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.1, 0.15)
	boss_bar.add_theme_stylebox_override("fill", fill)
	layer.add_child(boss_bar)

	boss_label = Label.new()
	boss_label.position = Vector2(340, 38)
	boss_label.size = Vector2(600, 26)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.text = "거대 변이체"
	boss_label.visible = false
	layer.add_child(boss_label)

	# 인트로 화면 (다른 UI 위에 덮음)
	intro_layer = CanvasLayer.new()
	intro_layer.layer = 10
	add_child(intro_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.9)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	intro_layer.add_child(bg)

	var intro := Label.new()
	intro.position = Vector2(140, 130)
	intro.size = Vector2(1000, 400)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_size_override("font_size", 26)
	intro.text = INTRO_TEXT
	intro_layer.add_child(intro)

	var hint := Label.new()
	hint.position = Vector2(0, 600)
	hint.size = Vector2(1280, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "아무 키나 눌러 시작   (WASD 이동 / 공격은 자동)"
	intro_layer.add_child(hint)


func _process(delta: float) -> void:
	if not started:
		if Input.is_anything_pressed():
			started = true
			intro_seen = true
			intro_layer.visible = false
			player.set_process(true)
		return

	if game_over:
		if Input.is_physical_key_pressed(KEY_R):
			get_tree().reload_current_scene()
		return

	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0:
			notice.text = ""

	if radio_timer > 0.0:
		radio_timer -= delta
		if radio_timer <= 0.0:
			radio_label.text = ""

	pierce_time = maxf(0.0, pierce_time - delta)
	explosive_time = maxf(0.0, explosive_time - delta)

	elapsed += delta
	if not boss_spawned and elapsed >= BOSS_TIME:
		_spawn_boss()

	# 비행기 도착까지 남은 시간에 맞춰 무전 대사 출력 (BOSS_TIME보다 큰 값의 대사는 건너뜀)
	var time_left := BOSS_TIME - elapsed
	while radio_next < RADIO_LINES.size() and time_left <= RADIO_LINES[radio_next][0]:
		if RADIO_LINES[radio_next][0] < BOSS_TIME:
			_show_radio(RADIO_LINES[radio_next][1])
		radio_next += 1

	if is_instance_valid(boss) and not boss_half_said and boss.hp < boss.max_hp * 0.5:
		boss_half_said = true
		_show_radio("[무전] 착륙을 시도한다! 놈을 쓰러뜨려라!")
	spawn_acc += delta
	var interval := maxf(0.2, 0.9 - elapsed * 0.006)
	if is_instance_valid(boss):
		interval *= 2.0  # 보스전에는 잡몹 스폰을 절반으로 줄임
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
	if e.is_boss:
		_on_boss_defeated()
		return
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
		it.glyph = SPECIAL_ITEMS[special]["glyph"]
	else:
		var type := _pick_item_type()
		it.type = type
		it.color = ITEM_TYPES[type]["color"]
	call_deferred("add_child", it)


func _roll_special_drop(pos: Vector2) -> void:
	# 특수 아이템 확률을 차례로 누적해서, 한 번의 처치에서 최대 1개만 나오게 함
	var r := randf()
	var acc := 0.0
	for k in SPECIAL_ITEMS:
		acc += SPECIAL_ITEMS[k]["chance"]
		if r < acc:
			_spawn_item(pos, k)
			return


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
	if game_over:
		return
	# 특수 아이템은 즉시 효과만 있고 레벨업 규칙과는 무관함
	if type == "vacuum":
		_use_vacuum()
		return
	if type == "bomb":
		_use_bomb()
		return
	if type == "pierce":
		pierce_time = AMMO_DURATION
		_show_notice("관통탄! %d초 동안 탄이 적을 뚫고 날아가요" % int(AMMO_DURATION))
		return
	if type == "explosive":
		explosive_time = AMMO_DURATION
		_show_notice("폭발탄! %d초 동안 탄이 맞은 자리에서 폭발해요" % int(AMMO_DURATION))
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


func _spawn_boss() -> void:
	boss_spawned = true
	var dmg_scale := 1.0 + elapsed / DAMAGE_SCALE_SECONDS
	var e = EnemyScript.new()
	e.main = self
	e.player = player
	e.is_boss = true
	e.radius = 44.0
	e.hp = BOSS_HP
	e.max_hp = BOSS_HP
	e.speed = 55.0
	e.contact_damage = 15.0 * dmg_scale
	e.shot_damage = 8.0 * dmg_scale
	e.tint = Color(0.25, 0.4, 0.15)
	e.position = player.position + Vector2.from_angle(randf() * TAU) * 650.0
	add_child(e)
	boss = e

	boss_bar.max_value = BOSS_HP
	boss_bar.value = BOSS_HP
	boss_bar.visible = true
	boss_label.visible = true
	_show_notice("구조 비행기가 다가온다! 거대 변이체가 옥상으로 올라온다", 4.0)


func _on_boss_defeated() -> void:
	game_over = true
	boss_bar.visible = false
	boss_label.visible = false
	notice.text = ""
	radio_label.text = ""
	# 남은 적과 적 탄을 모두 정리 (보스 자신은 hit()에서 곧 제거됨)
	for en in get_tree().get_nodes_in_group("enemies"):
		if not en.is_boss:
			en.queue_free()
	for s in get_tree().get_nodes_in_group("enemy_shots"):
		s.queue_free()
	player.set_process(false)

	var t := int(elapsed)
	msg.position = Vector2(0, 170)
	msg.text = ENDING_TEXT + "\n\n- 엔딩 -\n생존 %02d:%02d / 처치 %d\nR 키로 다시 시작" % [t / 60, t % 60, kills]


func _use_vacuum() -> void:
	for it in get_tree().get_nodes_in_group("items"):
		it.attract()
	_show_notice("자석! 맵의 능력치 아이템을 모두 끌어당겨요")


func _use_bomb() -> void:
	# 화면(카메라가 보는 영역) 안의 적을 즉사시키고 적 탄도 지움
	var half := get_viewport_rect().size / 2.0
	_suppress_drops = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_queued_for_deletion():
			continue
		var d: Vector2 = e.position - player.position
		if absf(d.x) <= half.x and absf(d.y) <= half.y:
			if e.is_boss:
				e.hit(e.max_hp * BOMB_BOSS_RATIO)  # 보스는 즉사하지 않고 체력 일부만 깎임
			else:
				e.hit(1.0e9)
	_suppress_drops = false
	if game_over:
		return  # 이 폭탄으로 보스가 죽었다면 엔딩 화면을 덮지 않음
	for s in get_tree().get_nodes_in_group("enemy_shots"):
		s.queue_free()
	_show_notice("폭탄! 화면 안의 적을 모두 제거했어요")


func _show_radio(text: String, duration := 5.0) -> void:
	radio_label.text = text
	radio_timer = duration


func _show_notice(text: String, duration := 2.5) -> void:
	notice.text = text
	notice_timer = duration


func _update_hud() -> void:
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	var t := int(elapsed)
	var line1 := "시간 %02d:%02d   처치 %d   HP %d/%d" % [t / 60, t % 60, kills, int(player.hp), int(player.max_hp)]
	if not boss_spawned:
		var left := maxi(0, int(BOSS_TIME - elapsed))
		line1 += "   구조 비행기 도착까지 %02d:%02d" % [left / 60, left % 60]
	var line2 := "공격력 %d   공격속도 %.2f/초   이동속도 %d   투사체 %d   획득범위 %d" % [
		int(player.damage), 1.0 / player.attack_interval, int(player.speed),
		player.projectile_count, int(player.pickup_range)
	]
	hud.text = line1 + "\n" + line2
	if is_instance_valid(boss):
		boss_bar.value = boss.hp

	var buffs: Array[String] = []
	if pierce_time > 0.0:
		buffs.append("관통탄 %.1f초" % pierce_time)
	if explosive_time > 0.0:
		buffs.append("폭발탄 %.1f초" % explosive_time)
	buff_label.text = "   ".join(buffs)
	for k in ITEM_TYPES:
		var lv: int = levels.get(k, 0)
		var have: int = progress.get(k, 0)
		legend[k].text = "%s   %d/%d   (Lv.%d)" % [
			ITEM_TYPES[k]["desc"], have, lv + UPGRADE_BASE, lv
		]


func _on_player_died() -> void:
	game_over = true
	notice.text = ""
	radio_label.text = ""
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
