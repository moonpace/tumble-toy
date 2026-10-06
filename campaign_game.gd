extends "res://game.gd"
const Rules = preload("res://rules.gd")
const Campaign = preload("res://campaign.gd")
const VisualAssets = preload("res://visual_assets.gd")
var visuals: RefCounted
enum ViewMode { TOP, QUARTER, THREE_D }
enum MenuPage { MAIN, STAGES, TUTORIAL, SETTINGS }
const SPLASH_DURATION := 3.0
const TILE_COLORS = {"fragile":"c89159","cracked":"9ed6e8","portal":"9675e8","stairs":"9db7e9",
	"glue":"e7b158","fire":"ed635b","electric":"ebd759","ice":"9bdde9","switch":"85cda0",
	"door":"667888","rotator":"c495da","arrow":"7dbbce","toggle":"82cda0","bridge":"b1a389",
	"star":"f3d260","item":"8ad7bd","wall":"655c78"}
const ITEM_NAMES = {"shield":"방열","boots":"논슬립","insulator":"절연","repair":"수리",
	"key":"숫자 열쇠","rotate":"회전","return":"귀환","solvent":"시간 지우개","undo":"되감기"}
const ITEM_MARKS = {"shield":"F","boots":"I","insulator":"E","repair":"+","key":"K","rotate":"R","return":"B","solvent":"T","undo":"U"}
const BLOCK_HELP = ["목표 숫자와 주사위 윗면을 맞추세요.",
	"색이 다른 칸은 특별한 동작을 합니다.",
	"위험한 칸은 장비로 한 번 막을 수 있습니다.",
	"Undo는 바로 전 행동을 되돌립니다.",
	"힌트는 다음 이동 하나를 알려줍니다."]

var level: Dictionary = {}
var state: Dictionary = {}
var records: Dictionary = {}
var world_page := 0
var view_floor := 0
var overlay := ""
var paused := false
var elapsed := 0.0
var timer_started := false
var assisted := false
var wait_left := 0.0
var extra_undos := 0
var used_undo_pickups: Dictionary = {}
var frames: Array = []
var frame_left := 0.0
var motion: Tween
var help_return := ""
var hint_thread: Thread
var hint_epoch := 0
var epoch := 0
var persist_progress := true
var persist_settings := true
var splash_left := SPLASH_DURATION
var splash_loading_complete := false
var splash_ready_for_input := false
var music_volume := 100
var sfx_volume := 100
var voice_enabled := true
var view_mode := ViewMode.THREE_D
var menu_page := MenuPage.MAIN

func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visuals = VisualAssets.new()
	levels = Campaign.load_levels()
	load_settings()
	setup_audio()
	apply_audio_settings()
	setup_3d()
	camera_3d.keep_aspect = Camera3D.KEEP_HEIGHT
	if FileAccess.file_exists("user://campaign-save-v2.json"):
		var saved = JSON.parse_string(FileAccess.get_file_as_string("user://campaign-save-v2.json"))
		if saved is Dictionary: records = saved
	screen = Screen.SPLASH
	menu_page = MenuPage.MAIN
	set_view_mode(ViewMode.THREE_D)
	var requested_stage := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): requested_stage = int(arg.trim_prefix("--stage="))-1
		elif arg == "--view=top": set_view_mode(ViewMode.TOP)
		elif arg == "--view=quarter": set_view_mode(ViewMode.QUARTER)
		elif arg == "--view=3d": set_view_mode(ViewMode.THREE_D)
	if requested_stage >= 0: load_level(requested_stage)
	splash_loading_complete = true
	queue_redraw()

func _exit_tree() -> void:
	if hint_thread != null and hint_thread.is_started(): hint_thread.wait_to_finish()

func start_game() -> void:
	load_level(first_incomplete_stage())

func first_incomplete_stage() -> int:
	for i in range(levels.size()):
		if not records.get(str(i+1),{}).get("clear",false): return i
	return 0

func completed_stage_count() -> int:
	var total := 0
	for i in range(levels.size()):
		if records.get(str(i+1),{}).get("clear",false): total += 1
	return total

func is_stage_unlocked(index: int) -> bool:
	if index < 0 or index >= levels.size(): return false
	if records.get(str(index+1),{}).get("clear",false): return true
	return index == 0 or records.get(str(index),{}).get("clear",false)

func load_settings() -> void:
	if not persist_settings or not FileAccess.file_exists("user://settings-v1.json"): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://settings-v1.json"))
	if saved is not Dictionary: return
	music_volume = snapped_volume(int(saved.get("music_volume",100)))
	sfx_volume = snapped_volume(int(saved.get("sfx_volume",100)))
	voice_enabled = bool(saved.get("voice_enabled",true))

func snapped_volume(value: int) -> int:
	return clampi(roundi(float(value)/25.0)*25,0,100)

func audio_gain(value: int) -> float:
	return -80.0 if value <= 0 else linear_to_db(float(value)/100.0)

func apply_audio_settings() -> void:
	if music_player == null: return
	music_player.volume_db = -3.0+audio_gain(music_volume)
	jingle_player.volume_db = -10.0+audio_gain(music_volume)
	roll_player.volume_db = -14.0+audio_gain(sfx_volume)
	feedback_player.volume_db = -12.0+audio_gain(sfx_volume)
	voice_player.volume_db = -8.0 if voice_enabled else -80.0
	if not voice_enabled: voice_player.stop()

func save_settings() -> void:
	if not persist_settings: return
	var file = FileAccess.open("user://settings-v1.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"music_volume":music_volume,"sfx_volume":sfx_volume,"voice_enabled":voice_enabled}))

func adjust_music(amount: int) -> void:
	music_volume = snapped_volume(music_volume+amount)
	apply_audio_settings()
	save_settings()

func adjust_sfx(amount: int) -> void:
	sfx_volume = snapped_volume(sfx_volume+amount)
	apply_audio_settings()
	save_settings()

func toggle_voice() -> void:
	voice_enabled = not voice_enabled
	apply_audio_settings()
	save_settings()

func load_level(index: int) -> void:
	epoch += 1
	if motion != null: motion.kill()
	frames.clear()
	is_rolling = false
	if index >= levels.size():
		show_menu()
		return
	level_index = clampi(index,0,levels.size()-1)
	level = levels[level_index]
	state = Rules.initial(level)
	view_floor = 0
	world_page = int(level.world)
	moves = 0
	undo_count = 0
	extra_undos = 0
	used_undo_pickups.clear()
	history.clear()
	completed = false
	perfect_clear = false
	elapsed = 0.0
	timer_started = false
	assisted = false
	wait_left = 0.0
	paused = false
	overlay = ""
	screen = Screen.PLAYING
	sync_view_rendering()
	start_puzzle_bgm()
	goal_face = int(level.face)
	par = int(level.par)
	message = level.hint
	message_time = 7.0
	voice_player.stop()
	voice_player.stream_paused = false
	jingle_player.stop()
	jingle_player.stream_paused = false
	var tutorial = {0:["move","화면의 방향 화살표를 눌러 주사위를 굴려 보세요."],1:["goal","목표 숫자와 윗면 숫자가 같아야 해요."],3:["undo","Undo 버튼을 누르면 한 번의 행동을 되돌릴 수 있어요."],4:["par","목표 입력 수 안에 풀면 완벽 클리어예요."]}
	if tutorial.has(level_index): play_voice_once(tutorial[level_index][0],tutorial[level_index][1])
	refresh()

func show_menu() -> void:
	show_menu_page(MenuPage.STAGES)

func show_title_menu() -> void:
	show_menu_page(MenuPage.MAIN)

func show_menu_page(page: int) -> void:
	voice_player.stop()
	jingle_player.stop()
	start_menu_bgm()
	epoch += 1
	if motion != null: motion.kill()
	frames.clear()
	is_rolling = false
	screen = Screen.HOME
	menu_page = page
	sync_view_rendering()
	overlay = ""
	paused = false

func set_view_mode(mode: int) -> void:
	view_mode = clampi(mode,ViewMode.TOP,ViewMode.THREE_D)
	sync_view_rendering()
	queue_redraw()

func sync_view_rendering() -> void:
	if board_viewport == null or board_texture == null: return
	var show_3d := screen == Screen.PLAYING and view_mode == ViewMode.THREE_D
	board_texture.visible = show_3d
	board_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if show_3d else SubViewport.UPDATE_DISABLED

func refresh() -> void:
	if motion != null: motion.kill()
	pos = Vector2i(int(state.p[0]),int(state.p[1]))
	start = Vector2i(int(level.start[0]),int(level.start[1]))
	goal = Vector2i(int(level.goal[0]),int(level.goal[1])) if int(level.goal[2]) == view_floor else Vector2i(-99,-99)
	orientation = {"top":int(state.o[0]),"bottom":int(state.o[1]),"north":int(state.o[2]),"south":int(state.o[3]),"east":int(state.o[4]),"west":int(state.o[5])}
	grid.clear()
	for y in range(int(level.height)):
		var row = ""
		for x in range(int(level.width)):
			row += "#" if level.tiles.has(Rules.cell([x,y,view_floor])) else "."
		grid.append(row)
	rebuild_3d_board()

func location(p: Array) -> Vector3:
	return Vector3(float(p[0])-(level.width-1)/2.0,0.52,float(p[1])-(level.height-1)/2.0)

func tile_label(k: String, t: Dictionary) -> String:
	match t.kind:
		"fragile": return "D%d" % int(state.hp.get(k,1))
		"cracked": return "I·%d" % int(state.hp.get(k,1))
		"portal": return "P%d >%dF" % [int(t.face),int(t.to[2])+1]
		"stairs": return ">%dF" % (int(t.to[2])+1)
		"glue": return "끈적"
		"fire": return "불"
		"electric": return "전기"
		"ice": return "얼음"
		"switch": return "S%d" % int(t.face)
		"door": return "열림" if state.flags.get(t.get("id","a"),false) else "문"
		"rotator": return "회전"
		"toggle": return "스위치"
		"bridge": return "다리"
		"arrow": return ["↑","↓","←","→"][int(t.direction)]
		"star": return "" if state.taken.has(k) else "별%d" % int(t.face)
		"item": return "" if state.taken.has(k) else "+"+ITEM_MARKS[t.item]
	return ""

func rebuild_3d_board() -> void:
	if board_3d == null or level.is_empty(): return
	for child in board_3d.get_children():
		if child is MeshInstance3D or child is StaticBody3D or child is Label3D:
			board_3d.remove_child(child)
			child.queue_free()
	var theme = Campaign.THEMES[int(level.world)]
	for child in board_3d.get_children():
		if child is WorldEnvironment: child.environment.background_color = Color(theme[2])
	for k in level.tiles:
		var p = Rules.point(k)
		if p[2] != view_floor: continue
		if state.hp.has(k) and int(state.hp[k]) == 0: continue
		var t = level.tiles[k]
		var tile_mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		var tall = t.kind == "wall" or (t.kind == "door" and not state.flags.get(t.get("id","a"),false))
		box.size = Vector3(0.94,0.68 if tall else 0.3,0.94)
		tile_mesh.mesh = box
		var col = Color(TILE_COLORS.get(t.kind,theme[1]))
		if t.kind == "bridge" and not state.flags.get(t.get("id","b"),false): col = Color("50465b")
		if t.kind in ["star","item"] and state.taken.has(k): col = Color(theme[1])
		if p == level.goal: col = PALETTE.goal
		var mat = make_material(col)
		if view_floor == int(state.p[2]) and abs(p[0]-pos.x)+abs(p[1]-pos.y)==1 and not tall:
			mat.emission_enabled = true
			mat.emission = Color("7aaf98")
			mat.emission_energy_multiplier = 0.3
		tile_mesh.material_override = mat
		tile_mesh.position = location(p)-Vector3(0,0.52,0)
		if tall: tile_mesh.position.y = 0.19
		board_3d.add_child(tile_mesh)
		if p == level.goal: add_goal_texture(tile_mesh.position)
		var caption = tile_label(k,t)
		if p == level.start and caption.is_empty(): caption = "출발"
		if not caption.is_empty():
			var label = Label3D.new()
			label.text = caption
			label.font_size = 34 if caption.length()<5 else 24
			label.pixel_size = 0.009
			label.modulate = PALETTE.ink
			label.outline_modulate = Color("fff8e7")
			label.outline_size = 5
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = tile_mesh.position+Vector3(0,0.23 if not tall else 0.6,0)
			board_3d.add_child(label)
		var body = StaticBody3D.new()
		body.set_meta("cell",Vector2i(p[0],p[1]))
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = box.size
		collision.shape = shape
		body.add_child(collision)
		body.position = tile_mesh.position
		board_3d.add_child(body)
	var die_box = BoxMesh.new()
	die_box.size = Vector3(0.72,0.72,0.72)
	die_3d = MeshInstance3D.new()
	die_3d.mesh = die_box
	die_3d.material_override = make_material(PALETTE.die,true)
	board_3d.add_child(die_3d)
	add_die_pips()
	die_3d.position = location(state.p)
	die_3d.quaternion = orientation_quaternion()
	die_3d.visible = view_floor == int(state.p[2])
	fit_camera_to_board(int(level.height),int(level.width))

func fit_camera_to_board(_rows: int, _cols: int) -> void:
	camera_3d.position = Vector3(7,8,7)
	camera_3d.look_at(Vector3.ZERO)
	var low = Vector2(INF,INF)
	var high = Vector2(-INF,-INF)
	for k in level.tiles:
		var p = Rules.point(k)
		if p[2] != view_floor: continue
		var base = location(p)-Vector3(0,0.52,0)
		for x in [-0.5,0.5]:
			for y in [-0.15,1.1]:
				for z in [-0.5,0.5]:
					var q = camera_3d.to_local(base+Vector3(x,y,z))
					low = low.min(Vector2(q.x,q.y))
					high = high.max(Vector2(q.x,q.y))
	var mid = (low+high)/2.0
	var span = high-low
	# Board safe rectangle x18..342 y204..520. KEEP_HEIGHT explicitly set.
	var size_needed = maxf(span.x/(324.0/800.0),span.y/(316.0/800.0))
	camera_3d.size = maxf(5.0,size_needed)
	camera_3d.position += camera_3d.basis.x*mid.x+camera_3d.basis.y*mid.y
	camera_3d.position += camera_3d.basis.y*(-38.0/800.0)*camera_3d.size

func roll(direction: Vector2i) -> void:
	var dirs = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
	var d = dirs.find(direction)
	if d >= 0: perform(Rules.ACTIONS[d])

func perform(action: String) -> void:
	if screen != Screen.PLAYING or paused or is_rolling or completed or state.dead or overlay != "": return
	if view_floor != int(state.p[2]):
		message = "현재 층 버튼으로 돌아온 뒤 이동하세요."
		message_time = 3
		return
	if wait_left > 0:
		message = "찍찍이에서 %.1f초 기다리는 중" % wait_left
		message_time = 1
		return
	var result = Rules.step(level,state,action,true)
	if not result.valid:
		message = "이 방향은 막혔거나 아이템 조건이 맞지 않아요."
		message_time = 2.5
		feedback_player.stream = sfx.blocked
		feedback_player.play()
		return
	epoch += 1
	history.append({"state":state.duplicate(true),"moves":moves,"wait":wait_left})
	moves += 1
	timer_started = true
	frames = result.trace
	is_rolling = true
	next_frame()

func next_frame() -> void:
	if motion != null: motion.kill()
	if frames.is_empty():
		is_rolling = false
		feedback_player.stream = sfx.land
		feedback_player.play()
		wait_left = float(state.wait)
		for k in state.taken:
			if level.tiles[k].kind == "item" and level.tiles[k].item == "undo" and not used_undo_pickups.has(k):
				used_undo_pickups[k] = true
				extra_undos += 1
		finish_turn()
		return
	var old_p = state.p.duplicate()
	var old_q = orientation_quaternion()
	state = frames.pop_front()
	view_floor = int(state.p[2])
	refresh()
	if int(old_p[2]) == view_floor:
		die_3d.position = location(old_p)
		die_3d.quaternion = old_q
		motion = create_tween().set_parallel(true)
		motion.tween_property(die_3d,"position",location(state.p),0.16)
		motion.tween_property(die_3d,"quaternion",orientation_quaternion(),0.16)
	frame_left = 0.18
	roll_player.stream = sfx.roll
	roll_player.play()

func finish_turn() -> void:
	completed = bool(state.won)
	if state.dead:
		message = "게임 오버 · Undo 또는 재시작으로 복구하세요."
		message_time = 99
		feedback_player.stream = sfx.death
		feedback_player.play()
		play_voice_once("safe","위험한 블록에서는 Undo나 재시작으로 돌아올 수 있어요.")
	if completed:
		perfect_clear = moves <= par
		feedback_player.stream = sfx.perfect if perfect_clear else sfx.clear
		feedback_player.play()
		jingle_player.stream = load("res://assets/audio/music/clear_jingle.ogg") as AudioStreamOggVorbis
		jingle_player.play()
		play_voice_once("clear","잘했어요! 다음 퍼즐로 가 볼까요?")
		var id = str(level_index+1)
		var rec = records.get(id,{"moves":99999,"seconds":99999.0,"medal":false,"clear":false})
		rec.clear = true
		rec.moves = mini(int(rec.moves),moves)
		if not assisted: rec.seconds = minf(float(rec.seconds),elapsed)
		rec.medal = bool(rec.medal) or earned_medal()
		records[id] = rec
		if persist_progress:
			var save = FileAccess.open("user://campaign-save-v2.json",FileAccess.WRITE)
			if save: save.store_string(JSON.stringify(records))

func earned_medal() -> bool:
	return float(level.time_limit)>0 and elapsed<=float(level.time_limit) and not assisted

func undo() -> void:
	if paused or is_rolling or history.is_empty() or screen != Screen.PLAYING: return
	if undo_count >= MAX_UNDOS+extra_undos:
		message = "되돌리기를 모두 사용했어요. 재시작할 수 있어요."
		message_time = 3
		return
	var entry = history.pop_back()
	epoch += 1
	state = entry.state
	moves = entry.moves
	wait_left = entry.wait
	view_floor = int(state.p[2])
	undo_count += 1
	completed = false
	perfect_clear = false
	overlay = ""
	refresh()
	message = "블록과 아이템도 이동 전 상태로 복구했어요."
	message_time = 3
	feedback_player.stream = sfx.undo
	feedback_player.play()

func reset_level() -> void:
	load_level(level_index)

func request_hint() -> void:
	if is_rolling or state.dead or completed or hint_thread != null: return
	assisted = true
	message = "현재 블록 상태에서 해법을 찾는 중…"
	message_time = 99
	hint_epoch = epoch
	hint_thread = Thread.new()
	hint_thread.start(Rules.solve.bind(level.duplicate(true),state.duplicate(true),60000))

func _process(delta: float) -> void:
	bob_time += delta
	if screen == Screen.SPLASH:
		splash_left = maxf(0.0,splash_left-delta)
		if splash_loading_complete and splash_left <= 0.0:
			splash_ready_for_input = true
		queue_redraw()
		return
	if hint_thread != null and not hint_thread.is_alive():
		var result = hint_thread.wait_to_finish()
		hint_thread = null
		if hint_epoch == epoch:
			var names = {"up":"↑ 북쪽","down":"↓ 남쪽","left":"← 서쪽","right":"→ 동쪽","rotate":"회전 아이템","repair":"수리 아이템","return":"귀환 아이템"}
			message = "해법의 다음 행동: "+names[result.path[0]] if result.found and not result.path.is_empty() else ("탐색 한도에 도달했어요. Undo/재시작을 이용하세요." if result.get("limited",false) else "현재 상태에서는 막혔어요. Undo/재시작하세요.")
			message_time = 8
	if screen == Screen.PLAYING and not paused:
		message_time = maxf(0,message_time-delta)
		if timer_started and not completed and not state.dead and not is_rolling: elapsed += delta
		if is_rolling:
			frame_left -= delta
			if frame_left <= 0: next_frame()
		else: wait_left = maxf(0,wait_left-delta)
	queue_redraw()

func set_paused(value: bool) -> void:
	paused = value
	voice_player.stream_paused = value
	jingle_player.stream_paused = value
	if motion != null and motion.is_valid():
		if value: motion.pause()
		else: motion.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == Screen.PLAYING: set_paused(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if screen != Screen.PLAYING:
				if menu_page != MenuPage.MAIN:
					show_title_menu()
			elif screen == Screen.PLAYING:
				if overlay == "bag":
					overlay = ""
				elif paused:
					overlay = ""
					set_paused(false)
				else:
					set_paused(true)
			return
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			set_view_mode([KEY_1,KEY_2,KEY_3].find(event.keycode))
			return
		if screen == Screen.SPLASH:
			if event.keycode in [KEY_ENTER,KEY_SPACE]: leave_splash_if_ready()
			return
		if screen != Screen.PLAYING:
			if event.keycode in [KEY_ENTER,KEY_SPACE]:
				if menu_page == MenuPage.MAIN: start_game()
				elif menu_page == MenuPage.TUTORIAL: load_level(0)
				elif menu_page == MenuPage.STAGES and is_stage_unlocked(world_page*10): load_level(world_page*10)
				else: show_title_menu()
			return
		if paused or overlay != "": return
		if event.keycode == KEY_R: reset_level()
		elif event.keycode == KEY_Z: undo()
		elif event.keycode == KEY_H: request_hint()
		elif event.keycode in [KEY_ENTER,KEY_SPACE] and completed: load_level(level_index+1)
		elif event.is_action_pressed("move_up"): roll(Vector2i.UP)
		elif event.is_action_pressed("move_down"): roll(Vector2i.DOWN)
		elif event.is_action_pressed("move_left"): roll(Vector2i.LEFT)
		elif event.is_action_pressed("move_right"): roll(Vector2i.RIGHT)
	elif event is InputEventScreenTouch and event.pressed: handle_touch(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: handle_touch(event.position)

func handle_touch(p: Vector2) -> void:
	if screen == Screen.SPLASH:
		leave_splash_if_ready()
		return
	if screen != Screen.PLAYING:
		if menu_page == MenuPage.TUTORIAL:
			if Rect2(290,42,42,42).has_point(p) or Rect2(60,608,240,48).has_point(p): show_title_menu()
			elif Rect2(48,536,264,54).has_point(p): load_level(0)
			return
		if menu_page == MenuPage.SETTINGS:
			if Rect2(290,42,42,42).has_point(p) or Rect2(60,540,240,48).has_point(p): show_title_menu(); return
			if Rect2(48,218,52,44).has_point(p): adjust_music(-25); return
			if Rect2(260,218,52,44).has_point(p): adjust_music(25); return
			if Rect2(48,326,52,44).has_point(p): adjust_sfx(-25); return
			if Rect2(260,326,52,44).has_point(p): adjust_sfx(25); return
			if Rect2(72,424,216,48).has_point(p): toggle_voice(); return
			return
		if menu_page == MenuPage.MAIN:
			if Rect2(48,432,264,54).has_point(p): start_game(); return
			if Rect2(48,502,126,48).has_point(p): show_menu_page(MenuPage.TUTORIAL); return
			if Rect2(186,502,126,48).has_point(p): show_menu(); return
			if Rect2(48,566,264,48).has_point(p): show_menu_page(MenuPage.SETTINGS); return
			return
		if Rect2(290,42,42,42).has_point(p): show_title_menu(); return
		if Rect2(18,128,48,38).has_point(p): world_page = posmod(world_page-1,10)
		elif Rect2(294,128,48,38).has_point(p): world_page = posmod(world_page+1,10)
		for i in range(10):
			var index := world_page*10+i
			if stage_rect(i).has_point(p) and is_stage_unlocked(index): load_level(index)
		return
	if paused:
		if Rect2(60,400,240,48).has_point(p):
			overlay = ""
			set_paused(false)
		return
	if overlay == "bag":
		if Rect2(72,606,216,44).has_point(p): overlay = ""
		var items = ITEM_NAMES.keys()
		for i in range(items.size()):
			if Rect2(28+(i%3)*103,280+(i/3)*90,96,78).has_point(p):
				var item = items[i]
				overlay = ""
				if item in ["rotate","repair","return"]: perform(item)
				else:
					message = "장비는 해당 블록에서 한 번 자동 사용됩니다."
					message_time = 4
		return
	if Rect2(12,102,66,32).has_point(p): show_menu(); return
	if Rect2(84,102,72,32).has_point(p): set_paused(true); return
	if Rect2(162,102,66,32).has_point(p): overlay = "help"; set_paused(true); return
	if Rect2(234,102,114,32).has_point(p): request_hint(); return
	if Rect2(12,737,104,42).has_point(p): reset_level(); return
	if Rect2(128,737,104,42).has_point(p): undo(); return
	if Rect2(244,737,104,42).has_point(p):
		if not is_rolling: overlay = "bag"
		return
	if is_rolling: return
	if completed:
		if Rect2(40,395,280,48).has_point(p): load_level(level_index+1)
		return
	for i in range(int(level.floors)):
		if Rect2(18+i*76,140,70,30).has_point(p): view_floor = i; refresh(); return
	if Rect2(254,140,88,30).has_point(p): view_floor = int(state.p[2]); refresh(); return
	var dirs = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
	for i in range(4):
		if direction_rect(i).has_point(p): roll(dirs[i]); return
	if p.y >= 204 and p.y <= 520 and view_floor == int(state.p[2]): try_move_to_view_tile(p)

func leave_splash_if_ready() -> void:
	if splash_ready_for_input:
		show_title_menu()

func stage_rect(i: int) -> Rect2:
	return Rect2(20+(i%2)*165,218+(i/2)*90,155,76)

func direction_rect(i: int) -> Rect2:
	return [Rect2(153,625,54,44),Rect2(153,679,54,44),Rect2(88,679,54,44),Rect2(218,679,54,44)][i]

func text_at(at: Vector2, text: String, size := 14, color := Color("302846"), width := 320) -> void:
	draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,width,size,color)

func _draw() -> void:
	if font == null: return
	if screen == Screen.SPLASH:
		draw_splash()
		return
	if screen != Screen.PLAYING:
		if menu_page == MenuPage.MAIN: draw_main_menu()
		elif menu_page == MenuPage.TUTORIAL: draw_tutorial_menu()
		elif menu_page == MenuPage.SETTINGS: draw_settings_menu()
		else: draw_campaign_menu()
		return
	if view_mode != ViewMode.THREE_D: draw_visual_background()
	match view_mode:
		ViewMode.TOP: draw_top_board()
		ViewMode.QUARTER: draw_sprite_board()
	draw_round_panel(Rect2(10,12,340,82),PALETTE.panel,PALETTE.ink)
	text_at(Vector2(22,35),"%03d · %s" % [level_index+1,Campaign.THEMES[int(level.world)][0]],17)
	text_at(Vector2(22,57),"%s · 목표 윗면 %d" % [level.name,goal_face],13)
	text_at(Vector2(22,80),"입력 %d / par %d    윗면 %d" % [moves,par,int(state.o[0])],14)
	if level.time_limit > 0:
		text_at(Vector2(213,80),"%.0f / %ds" % [elapsed,int(level.time_limit)],13,Color("ae4764"),130)
	draw_button(Rect2(12,102,66,32),"목록")
	draw_button(Rect2(84,102,72,32),"일시정지")
	draw_button(Rect2(162,102,66,32),"규칙")
	draw_button(Rect2(234,102,114,32),"힌트" if hint_thread == null else "탐색 중")
	for i in range(int(level.floors)):
		draw_button(Rect2(18+i*76,140,70,30),"%dF%s" % [i+1," ●" if i==view_floor else ""])
	draw_button(Rect2(254,140,88,30),"현재 층")
	draw_round_panel(Rect2(12,527,336,87),PALETTE.panel,PALETTE.ink)
	var guide = message if message_time>0 else level.hint
	if wait_left>0: guide = "찍찍이: %.1f초 후 이동 가능" % wait_left
	if view_floor != int(state.p[2]): guide = "%d층 미리보기 · 주사위는 %d층에 있어요" % [view_floor+1,int(state.p[2])+1]
	# Draw fixed-width wrapped text without truncating Korean help.
	var lines = wrap_text(guide,308,13)
	for i in range(mini(2,lines.size())): text_at(Vector2(24,549+i*18),lines[i],13)
	var bag_parts = []
	for item in state.bag:
		if int(state.bag[item])>0: bag_parts.append("%s%d" % [ITEM_MARKS[item],int(state.bag[item])])
	text_at(Vector2(24,600),"장비: "+("없음" if bag_parts.is_empty() else "  ".join(bag_parts)),12)
	var dirs = [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]
	for i in range(4): draw_direction_button(direction_rect(i),["↑","↓","←","→"][i],dirs[i])
	draw_button(Rect2(12,737,104,42),"   재시작")
	visuals.draw(self,"restart",Rect2(18,746,24,24))
	draw_button(Rect2(128,737,104,42),"   Undo %d" % maxi(0,MAX_UNDOS+extra_undos-undo_count))
	visuals.draw(self,"undo",Rect2(133,746,24,24))
	draw_button(Rect2(244,737,104,42),"가방")
	if completed: draw_campaign_clear()
	if overlay == "bag": draw_bag()
	if paused: draw_pause()

func wrap_text(text: String, width: int, size: int) -> Array:
	var lines = []
	var line = ""
	for ch in text:
		if font.get_string_size(line+ch,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			lines.append(line)
			line = ""
		line += ch
	lines.append(line)
	return lines

func draw_splash() -> void:
	draw_visual_background()
	draw_round_panel(Rect2(18,82,324,126),PALETTE.panel,PALETTE.ink)
	draw_string(font,Vector2(30,116),"DICE PUZZLE",HORIZONTAL_ALIGNMENT_CENTER,300,11,Color("ae4764"))
	draw_string(font,Vector2(32,164),"TUMBLE TOY",HORIZONTAL_ALIGNMENT_CENTER,300,38,Color("e9857f"))
	draw_string(font,Vector2(30,160),"TUMBLE TOY",HORIZONTAL_ALIGNMENT_CENTER,300,38,PALETTE.ink)
	draw_string(font,Vector2(30,191),"ROLL  ·  MATCH  ·  CLEAR",HORIZONTAL_ALIGNMENT_CENTER,300,11,Color("75637f"))
	visuals.draw(self,"star",Rect2(32,102,22,22))
	visuals.draw(self,"star",Rect2(307,170,18,18))
	visuals.draw(self,"menu_hero",Rect2(36,238,288,192))
	draw_round_panel(Rect2(42,530,276,82),PALETTE.panel,PALETTE.ink)
	var loading_label := "준비 완료" if splash_ready_for_input else "불러오는 중"
	draw_string(font,Vector2(58,562),loading_label,HORIZONTAL_ALIGNMENT_CENTER,244,13,Color("75637f"))
	draw_rect(Rect2(66,578,228,8),Color("d9cfb7"))
	var progress := clampf(1.0-splash_left/SPLASH_DURATION,0.0,1.0)
	draw_rect(Rect2(66,578,228.0*progress,8),Color("ff7c7c"))
	if splash_ready_for_input:
		var prompt_color := Color("302846")
		prompt_color.a = 0.35+0.65*(0.5+0.5*sin(bob_time*PI*2.0/1.1))
		draw_string(font,Vector2(48,644),"화면을 터치하세요",HORIZONTAL_ALIGNMENT_CENTER,264,16,prompt_color)
	draw_string(font,Vector2(48,674),"TUMBLE TOY",HORIZONTAL_ALIGNMENT_CENTER,264,12,Color("75637f"))

func draw_main_menu() -> void:
	draw_visual_background()
	draw_round_panel(Rect2(18,20,324,96),PALETTE.panel,PALETTE.ink)
	draw_string(font,Vector2(30,48),"DICE PUZZLE",HORIZONTAL_ALIGNMENT_CENTER,300,11,Color("ae4764"))
	draw_string(font,Vector2(32,88),"TUMBLE TOY",HORIZONTAL_ALIGNMENT_CENTER,300,34,Color("e9857f"))
	draw_string(font,Vector2(30,84),"TUMBLE TOY",HORIZONTAL_ALIGNMENT_CENTER,300,34,PALETTE.ink)
	visuals.draw(self,"star",Rect2(30,46,20,20))
	visuals.draw(self,"star",Rect2(310,78,16,16))
	visuals.draw(self,"menu_hero",Rect2(36,126,288,192))
	draw_round_panel(Rect2(28,330,304,62),PALETTE.panel,PALETTE.ink)
	var cleared := completed_stage_count()
	text_at(Vector2(46,356),"진행도",13,Color("75637f"),70)
	text_at(Vector2(226,359),"%d / 100" % cleared,18,PALETTE.ink,84)
	draw_rect(Rect2(46,371,264,7),Color("d9cfb7"))
	draw_rect(Rect2(46,371,264.0*float(cleared)/100.0,7),Color("ff7c7c"))
	draw_round_panel(Rect2(24,408,312,242),PALETTE.panel,PALETTE.ink)
	var next_stage := first_incomplete_stage()+1
	draw_button_skin(Rect2(48,432,264,54),("새 게임" if cleared==0 else "이어하기")+" · %03d" % next_stage,"button_primary")
	draw_button_skin(Rect2(48,502,126,48),"튜토리얼","button_default")
	draw_button_skin(Rect2(186,502,126,48),"스테이지","button_default")
	draw_button_skin(Rect2(48,566,264,48),"설정","button_default")
	draw_string(font,Vector2(48,636),"ROLL  ·  MATCH  ·  CLEAR",HORIZONTAL_ALIGNMENT_CENTER,264,10,Color("75637f"))

func draw_settings_menu() -> void:
	draw_visual_background()
	draw_round_panel(Rect2(18,24,324,88),PALETTE.panel,PALETTE.ink)
	text_at(Vector2(36,62),"설정",29)
	text_at(Vector2(36,88),"소리와 안내를 조절하세요",12,Color("75637f"))
	draw_button(Rect2(290,42,42,42),"←")
	draw_round_panel(Rect2(24,142,312,350),PALETTE.panel,PALETTE.ink)
	text_at(Vector2(48,190),"배경음악",17)
	draw_button_skin(Rect2(48,218,52,44),"−","button_default")
	draw_round_panel(Rect2(112,218,136,44),PALETTE.panel,PALETTE.ink)
	draw_string(font,Vector2(112,247),"%d%%" % music_volume,HORIZONTAL_ALIGNMENT_CENTER,136,16,PALETTE.ink)
	draw_button_skin(Rect2(260,218,52,44),"+","button_default")
	text_at(Vector2(48,298),"효과음",17)
	draw_button_skin(Rect2(48,326,52,44),"−","button_default")
	draw_round_panel(Rect2(112,326,136,44),PALETTE.panel,PALETTE.ink)
	draw_string(font,Vector2(112,355),"%d%%" % sfx_volume,HORIZONTAL_ALIGNMENT_CENTER,136,16,PALETTE.ink)
	draw_button_skin(Rect2(260,326,52,44),"+","button_default")
	text_at(Vector2(48,406),"안내 음성",17)
	draw_button_skin(Rect2(72,424,216,48),"켜짐" if voice_enabled else "꺼짐","button_primary" if voice_enabled else "button_pressed")
	draw_button_skin(Rect2(60,540,240,48),"완료","button_default")
	draw_string(font,Vector2(48,614),"변경 사항은 자동으로 저장됩니다",HORIZONTAL_ALIGNMENT_CENTER,264,11,Color("75637f"))

func draw_tutorial_menu() -> void:
	draw_visual_background()
	draw_round_panel(Rect2(18,24,324,88),PALETTE.panel,PALETTE.ink)
	text_at(Vector2(36,67),"튜토리얼",30)
	draw_button(Rect2(290,42,42,42),"←")
	var cards = [
		[Rect2(24,154,312,90),"direction","1  굴리기","방향 버튼으로 주사위를 움직입니다."],
		[Rect2(24,264,312,90),"goal","2  숫자 맞추기","목표와 윗면 숫자를 같게 만듭니다."],
		[Rect2(24,374,312,90),"undo","3  되돌리기","Undo로 바로 전 행동을 되돌립니다."]]
	for card in cards:
		draw_round_panel(card[0],PALETTE.panel,PALETTE.ink)
		var icon_rect := Rect2(card[0].position+Vector2(18,20),Vector2(50,50))
		visuals.draw(self,card[1],icon_rect)
		if card[1] == "direction":
			draw_string(font,icon_rect.position+Vector2(0,33),"→",HORIZONTAL_ALIGNMENT_CENTER,icon_rect.size.x,22,PALETTE.ink)
		text_at(card[0].position+Vector2(82,36),card[2],18)
		text_at(card[0].position+Vector2(82,64),card[3],12,Color("75637f"),210)
	draw_button_skin(Rect2(48,536,264,54),"튜토리얼 시작","button_primary")
	draw_button_skin(Rect2(60,608,240,48),"뒤로","button_default")

func draw_campaign_menu() -> void:
	var theme = Campaign.THEMES[world_page]
	draw_visual_background()
	draw_round_panel(Rect2(14,22,332,86),PALETTE.panel,PALETTE.ink)
	draw_string(font,Vector2(30,48),"DICE PUZZLE · 100 STAGES",HORIZONTAL_ALIGNMENT_LEFT,250,10,Color("ae4764"))
	draw_string(font,Vector2(32,84),"TUMBLE TOY",HORIZONTAL_ALIGNMENT_LEFT,250,27,Color("e9857f"))
	draw_string(font,Vector2(30,81),"TUMBLE TOY",HORIZONTAL_ALIGNMENT_LEFT,250,27,PALETTE.ink)
	draw_button(Rect2(290,42,42,42),"←")
	draw_button(Rect2(18,128,48,38),"←")
	draw_button(Rect2(294,128,48,38),"→")
	draw_round_panel(Rect2(72,122,216,46),PALETTE.panel,PALETTE.ink)
	draw_string(font,Vector2(72,153),theme[0],HORIZONTAL_ALIGNMENT_CENTER,216,21,PALETTE.ink)
	for i in range(10):
		var index = world_page*10+i
		var r = stage_rect(i)
		var rec = records.get(str(index+1),{})
		var unlocked := is_stage_unlocked(index)
		visuals.draw_nine_patch(self,"panel",r,8,Color.WHITE if unlocked else Color("aab3bf"))
		var ink := PALETTE.ink if unlocked else Color("687181")
		var status := "완료" if rec.get("clear",false) else ("도전" if unlocked else "잠김")
		text_at(r.position+Vector2(12,27),"%03d  %s" % [index+1,status],18,ink)
		text_at(r.position+Vector2(12,51),TITLES_SAFE(i) if unlocked else "이전 스테이지 완료 필요",12,ink)
		text_at(r.position+Vector2(12,68),("TIME MEDAL" if rec.get("medal",false) else ("시간 도전" if i==9 else "숫자를 맞춰요")) if unlocked else "LOCKED",10,ink)
	draw_round_panel(Rect2(14,691,332,97),PALETTE.panel,PALETTE.ink)
	var cleared := 0
	for i in range(10):
		if records.get(str(world_page*10+i+1),{}).get("clear",false): cleared += 1
	text_at(Vector2(28,732),"%s · 클리어 %d/10" % [theme[0],cleared],16)
	text_at(Vector2(28,764),"스테이지를 선택하세요.",12,Color("75637f"))

func TITLES_SAFE(i: int) -> String:
	return levels[world_page*10+i].name

func draw_campaign_clear() -> void:
	draw_rect(Rect2(Vector2.ZERO,VIEW),Color(0.15,0.1,0.24,0.7))
	draw_round_panel(Rect2(24,220,312,246),PALETTE.panel,PALETTE.ink)
	if perfect_clear: visuals.draw(self,"perfect",Rect2(277,239,32,32))
	text_at(Vector2(44,263),"PERFECT!" if perfect_clear else "CLEAR!",28)
	text_at(Vector2(44,302),"%d회 입력 · %.1f초" % [moves,elapsed],18)
	var subtitle = "다음 퍼즐로 떠나볼까요?"
	if level.time_limit>0: subtitle = "TIME MEDAL 획득!" if earned_medal() else "일반 클리어! 시간 메달에 다시 도전해요."
	if assisted: subtitle = "힌트 사용 · 시간 메달은 다음 도전에!"
	if voice_player.playing: subtitle = message
	text_at(Vector2(44,345),subtitle,13,PALETTE.ink,275)
	draw_button(Rect2(40,395,280,48),"100 스테이지 완주! 목록으로" if level_index==99 else "다음 스테이지")

func draw_bag() -> void:
	draw_rect(Rect2(Vector2.ZERO,VIEW),Color(0.15,0.1,0.24,0.85))
	draw_round_panel(Rect2(16,215,328,450),PALETTE.panel,PALETTE.ink)
	text_at(Vector2(32,247),"아이템 가방",22)
	var items = ITEM_NAMES.keys()
	for i in range(items.size()):
		var item = items[i]
		var r = Rect2(28+(i%3)*103,280+(i/3)*90,96,78)
		var slot_tint := Color.WHITE if int(state.bag.get(item,0))>0 else Color("b9bec7")
		visuals.draw_nine_patch(self,"item_slot",r,6,slot_tint)
		text_at(r.position+Vector2(8,28),ITEM_NAMES[item],13)
		text_at(r.position+Vector2(8,52),"%d개" % int(state.bag.get(item,0)),16)
		text_at(r.position+Vector2(8,69),"탭하여 사용" if item in ["rotate","repair","return"] else "자동 사용",10)
	text_at(Vector2(32,574),"아이템을 선택해 사용하세요.",12)
	draw_button(Rect2(72,606,216,44),"닫기")

func draw_pause() -> void:
	# The generated background is opaque, preventing study of the paused board.
	draw_visual_background()
	draw_rect(Rect2(Vector2.ZERO,VIEW),Color(0.19,0.15,0.28,0.38))
	if overlay == "help":
		draw_round_panel(Rect2(20,164,320,308),PALETTE.panel,PALETTE.ink)
		visuals.draw(self,"star",Rect2(286,184,32,32))
		text_at(Vector2(40,215),"빠른 도움",25)
		for i in range(BLOCK_HELP.size()): text_at(Vector2(40,258+i*28),BLOCK_HELP[i],13)
	else:
		draw_round_panel(Rect2(24,246,312,226),PALETTE.panel,PALETTE.ink)
		visuals.draw(self,"cloud",Rect2(44,267,48,32))
		visuals.draw(self,"star",Rect2(274,267,32,32))
		draw_string(font,Vector2(48,322),"PAUSE",HORIZONTAL_ALIGNMENT_CENTER,264,14,Color("75637f"))
		draw_string(font,Vector2(48,356),"잠시 쉬어가세요",HORIZONTAL_ALIGNMENT_CENTER,264,26,PALETTE.ink)
		draw_string(font,Vector2(48,383),"시간 측정과 이동을 멈췄습니다.",HORIZONTAL_ALIGNMENT_CENTER,264,14,PALETTE.ink)
	draw_button(Rect2(60,400,240,48),"계속하기")

func draw_visual_background() -> void:
	draw_rect(Rect2(Vector2.ZERO,VIEW),Color(Campaign.THEMES[world_page][2]))
	visuals.draw(self,"background",Rect2(0,112,360,410),Color(1,1,1,0.42))
	visuals.draw(self,"cloud",Rect2(8,181,48,32),Color(1,1,1,0.65))
	visuals.draw(self,"star",Rect2(316,199,32,32),Color(1,1,1,0.65))
	visuals.draw(self,"blocks",Rect2(290,474,64,48),Color(1,1,1,0.6))

func top_board_metrics() -> Dictionary:
	var safe := Rect2(18,207,324,310)
	var cell := minf(42.0,minf(310.0/float(level.width),300.0/float(level.height)))
	var board_size := Vector2(level.width*cell,level.height*cell)
	return {"cell":cell,"origin":safe.position+(safe.size-board_size)/2.0,"safe":safe}

func top_cell_center(p: Array) -> Vector2:
	var metrics = top_board_metrics()
	return metrics.origin+Vector2((float(p[0])+0.5)*metrics.cell,(float(p[1])+0.5)*metrics.cell)

func draw_top_board() -> void:
	var metrics = top_board_metrics()
	var cell: float = metrics.cell
	var theme = Campaign.THEMES[int(level.world)]
	draw_round_panel(metrics.safe,Color(theme[2],0.52),Color(PALETTE.ink,0.35))
	for k in level.tiles:
		var p = Rules.point(k)
		if p[2] != view_floor: continue
		var center = top_cell_center(p)
		var rect = Rect2(center-Vector2.ONE*cell*0.46,Vector2.ONE*cell*0.92)
		if state.hp.has(k) and int(state.hp[k]) == 0:
			draw_rect(rect,PALETTE.hole)
			draw_line(rect.position,rect.end,Color("cdbde1"),2)
			draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y),Color("cdbde1"),2)
			continue
		var t = level.tiles[k]
		var color = Color(TILE_COLORS.get(t.kind,theme[1])).lightened(0.18) if TILE_COLORS.has(t.kind) else Color(theme[1])
		if t.kind in ["star","item"] and state.taken.has(k): color = Color(theme[1])
		if t.kind == "bridge" and not state.flags.get(t.get("id","b"),false): color = Color("61546f")
		if view_floor == int(state.p[2]) and abs(p[0]-pos.x)+abs(p[1]-pos.y)==1:
			color = color.lerp(PALETTE.mint,0.42)
		draw_rect(Rect2(rect.position+Vector2(0,3),rect.size),Color(PALETTE.ink,0.28))
		draw_rect(rect,color)
		draw_rect(rect,PALETTE.ink,false,1.5)
		if t.kind == "wall" or (t.kind == "door" and not state.flags.get(t.get("id","a"),false)):
			draw_rect(rect.grow(-cell*0.18),Color("655c78"))
		if p == level.start:
			draw_circle(center,cell*0.22,PALETTE.mint,false,2)
			draw_circle(center,cell*0.07,PALETTE.mint)
		if p == level.goal:
			draw_rect(rect.grow(-cell*0.11),PALETTE.goal)
			draw_rect(rect.grow(-cell*0.2),Color("ffd7af"))
			draw_string(font,center+Vector2(-cell*0.24,cell*0.16),str(goal_face),HORIZONTAL_ALIGNMENT_CENTER,cell*0.48,maxi(10,int(cell*0.38)),PALETTE.goal_dark)
		var caption = tile_label(k,t)
		if not caption.is_empty() and p != level.goal:
			var size = maxi(7,mini(10,int(cell*0.25)))
			draw_string(font,center+Vector2(-cell*0.44,size*0.35),caption,HORIZONTAL_ALIGNMENT_CENTER,cell*0.88,size,PALETTE.ink)
	if view_floor == int(state.p[2]):
		var center = top_cell_center(state.p)
		var die_size = cell*0.72
		var die_rect = Rect2(center-Vector2.ONE*die_size/2.0,Vector2.ONE*die_size)
		draw_rect(Rect2(die_rect.position+Vector2(2,3),die_rect.size),Color(PALETTE.ink,0.3))
		draw_style_box(make_panel_style(Color("ffb7b7") if state.dead else PALETTE.die,PALETTE.ink),die_rect)
		draw_string(font,die_rect.position+Vector2(0,die_size*0.66),str(state.o[0]),HORIZONTAL_ALIGNMENT_CENTER,die_size,maxi(12,int(die_size*0.5)),PALETTE.ink)
		if die_size >= 25:
			draw_string(font,die_rect.position+Vector2(0,9),str(state.o[2]),HORIZONTAL_ALIGNMENT_CENTER,die_size,8,Color("75637f"))
			draw_string(font,die_rect.position+Vector2(0,die_size-2),str(state.o[3]),HORIZONTAL_ALIGNMENT_CENTER,die_size,8,Color("75637f"))

func try_move_to_view_tile(point: Vector2) -> bool:
	if view_mode != ViewMode.TOP: return try_move_to_touched_tile(point)
	var metrics = top_board_metrics()
	var local = point-metrics.origin
	if local.x < 0 or local.y < 0: return false
	var cell = Vector2i(floori(local.x/metrics.cell),floori(local.y/metrics.cell))
	if cell.x < 0 or cell.y < 0 or cell.x >= int(level.width) or cell.y >= int(level.height): return false
	var direction = cell-pos
	if abs(direction.x)+abs(direction.y) != 1 or not is_floor(cell): return false
	roll(direction)
	return true

func sprite_cell(p: Array) -> Vector2:
	return camera_3d.unproject_position(location(p)-Vector3(0,0.37,0))

func draw_sprite_board() -> void:
	var cells: Array = []
	for k in level.tiles:
		var p = Rules.point(k)
		if p[2] == view_floor: cells.append(p)
	cells.sort_custom(func(a,b): return a[0]+a[1] < b[0]+b[1])
	var origin = sprite_cell([0,0,view_floor])
	var step = sprite_cell([1,0,view_floor])-origin
	var tile_width = absf(step.x)*2.0
	var tile_height = absf(step.y)*2.0
	for p in cells:
		var k = Rules.cell(p)
		var t = level.tiles[k]
		var center = sprite_cell(p)
		var rect = Rect2(center-Vector2(tile_width/2,tile_height/2),Vector2(tile_width,tile_height+tile_width*0.17))
		if state.hp.has(k) and int(state.hp[k])==0:
			visuals.draw(self,"void",Rect2(center-Vector2(tile_width,tile_height)/2,Vector2(tile_width,tile_height)))
			continue
		var tint = Color.WHITE
		if TILE_COLORS.has(t.kind): tint = Color(TILE_COLORS[t.kind]).lightened(0.2)
		if t.kind in ["star","item"] and state.taken.has(k): tint = Color.WHITE
		if t.kind == "bridge" and not state.flags.get(t.get("id","b"),false): tint = Color("61546f")
		visuals.draw(self,"floor",rect,tint)
		if t.kind == "wall" or (t.kind == "door" and not state.flags.get(t.get("id","a"),false)):
			visuals.draw(self,"floor",Rect2(rect.position-Vector2(0,tile_width*0.2),rect.size),tint)
		if p == level.start: visuals.draw(self,"start",Rect2(center-Vector2(tile_width,tile_height)*0.4,Vector2(tile_width,tile_height)*0.8))
		if p == level.goal:
			visuals.draw(self,"goal",Rect2(center-Vector2(tile_width,tile_height)*0.43,Vector2(tile_width,tile_height)*0.86))
			draw_string(font,center+Vector2(-10,4),str(goal_face),HORIZONTAL_ALIGNMENT_CENTER,20,12,PALETTE.ink)
		var caption = tile_label(k,t)
		if not caption.is_empty():
			var size = 10 if tile_width>=35 else 8
			var extent = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size)
			draw_style_box(make_panel_style(Color("fff8e7"),Color("75637f")),Rect2(center-extent/2-Vector2(2,2),extent+Vector2(4,4)))
			draw_string(font,center+Vector2(-extent.x/2,extent.y/3),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size,PALETTE.ink)
	if view_floor == int(state.p[2]):
		var center = camera_3d.unproject_position(die_3d.position)
		var width = tile_width*0.78
		var rect = Rect2(center-Vector2(width/2,width*0.66),Vector2(width,width))
		visuals.draw(self,"die",rect,Color("ffaaaa") if state.dead else Color.WHITE)
		draw_string(font,rect.position+Vector2(0,width*0.35),str(state.o[0]),HORIZONTAL_ALIGNMENT_CENTER,width,maxi(10,int(width*0.3)),PALETTE.ink)
		draw_string(font,rect.position+Vector2(width*0.10,width*0.72),str(state.o[3]),HORIZONTAL_ALIGNMENT_CENTER,width*0.35,maxi(8,int(width*0.20)),PALETTE.ink)
		draw_string(font,rect.position+Vector2(width*0.56,width*0.72),str(state.o[4]),HORIZONTAL_ALIGNMENT_CENTER,width*0.35,maxi(8,int(width*0.20)),PALETTE.ink)

func draw_direction_button(rect: Rect2, arrow: String, direction: Vector2i) -> void:
	visuals.draw(self,"direction",rect)
	draw_string(font,rect.position+Vector2(0,rect.size.y/2+7),arrow,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,20,PALETTE.ink)
	if completed or not is_floor(pos+direction): return
	var next_top = rolled_orientation(orientation,direction).top
	var at = rect.position+Vector2(rect.size.x-19,0)
	visuals.draw(self,"badge",Rect2(at,Vector2(20,20)))
	draw_string(font,at+Vector2(0,14),str(next_top),HORIZONTAL_ALIGNMENT_CENTER,20,11,PALETTE.ink)

func draw_button(rect: Rect2, text: String, disabled := false) -> void:
	var key := "button_pressed" if disabled else ("button_primary" if rect.size.x >= 200.0 else "button_default")
	var tint := Color("b9bec7") if disabled else Color.WHITE
	draw_button_skin(rect,text,key,tint)

func draw_button_skin(rect: Rect2, text: String, key: String, tint := Color.WHITE) -> void:
	visuals.draw_nine_patch(self,key,rect,6,tint)
	draw_string(font,rect.position+Vector2(0,rect.size.y/2+6),text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,15,PALETTE.ink)

func draw_round_panel(rect: Rect2, _fill: Color, _outline: Color) -> void:
	visuals.draw_nine_patch(self,"panel",rect,8)


func play_voice_once(id: String, subtitle: String) -> void:
	if played_voice.has(id): return
	played_voice[id] = true
	message = subtitle
	message_time = 3.5
	if not voice_enabled: return
	voice_player.stream = voice[id]
	voice_player.play()
	message_time = maxf(3.5,voice_player.stream.get_length()+0.3)
