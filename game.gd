extends Node2D

const VIEW := Vector2i(360, 800)
const MAX_UNDOS := 3
const TILE := 36
const BOARD_ORIGIN := Vector2i(180, 220)
enum Screen { SPLASH, HOME, PLAYING }
const PALETTE := {
	"ink": Color("302846"), "sky": Color("9edcf2"), "cloud": Color("eaf7ff"),
	"tile": Color("ffd884"), "tile_edge": Color("e5a75f"), "tile_line": Color("f6bd6b"),
	"hole": Color("5c536f"), "goal": Color("ff8f9f"), "goal_dark": Color("d95e7c"),
	"die": Color("fff8e7"), "die_shadow": Color("b9a780"), "pip": Color("51415f"),
	"mint": Color("8ed8bd"), "mint_dark": Color("55a68e"), "panel": Color("fff2cb")
}

var levels := [
	{"name":"첫 굴림", "map":[".....", ".###.", ".###.", ".###.", "....."], "start":Vector2i(1, 1), "goal":Vector2i(3, 3), "face":1, "par":4, "hint":"화면의 방향 화살표를 눌러 주사위를 굴려 보세요."},
	{"name":"숫자를 맞춰요", "map":["......", ".####.", ".####.", ".####.", "......"], "start":Vector2i(1, 2), "goal":Vector2i(4, 2), "face":4, "par":5, "hint":"목표 숫자와 윗면 숫자가 같아야 해요."},
	{"name":"장난감 다리", "map":[".......", ".#####.", ".#####.", ".#####.", "......."], "start":Vector2i(1, 1), "goal":Vector2i(5, 3), "face":6, "par":6, "hint":"넓은 바닥에서 주사위 방향이 맞는 길을 찾아보세요."},
	{"name":"블록 미로", "map":[".......", ".#####.", ".#####.", ".#####.", ".#####.", ".#####.", "......."], "start":Vector2i(1, 1), "goal":Vector2i(5, 5), "face":1, "par":8, "hint":"넓은 보드에서 목표로 가는 길을 골라 보세요."},
	{"name":"장난감 방의 끝", "map":["........", ".######.", ".######.", ".######.", ".######.", ".######.", "........", "........"], "start":Vector2i(1, 1), "goal":Vector2i(5, 5), "face":1, "par":10, "hint":"목표 이동 수 안에 풀면 완벽 클리어예요."},
	{"name":"네모 길", "map":[".......", ".#####.", ".#####.", ".#####.", ".#####.", ".#####.", "......."], "start":Vector2i(1, 1), "goal":Vector2i(5, 5), "face":1, "par":8, "hint":"여러 경로의 주사위 방향을 비교해 보세요."},
	{"name":"넓은 길", "map":["........", ".######.", ".######.", ".######.", ".######.", ".######.", "........"], "start":Vector2i(1, 1), "goal":Vector2i(5, 5), "face":1, "par":8, "hint":"짧은 길과 돌아가는 길의 주사위 방향을 비교해 보세요."},
	{"name":"내려가는 길", "map":[".........", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", "........."], "start":Vector2i(1, 1), "goal":Vector2i(7, 7), "face":1, "par":12, "hint":"넓은 보드를 지나 목표 숫자를 맞춰 보세요."},
	{"name":"고리 정원", "map":[".........", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", ".#######.", "........."], "start":Vector2i(1, 1), "goal":Vector2i(7, 7), "face":1, "par":12, "hint":"갈림길에서 윗면 숫자가 맞는 쪽을 고르세요."},
	{"name":"마지막 방향", "map":["........", ".######.", ".######.", ".######.", ".######.", ".######.", ".######.", ".######."], "start":Vector2i(1, 1), "goal":Vector2i(6, 7), "face":4, "par":11, "hint":"넓은 보드에서 마지막 윗면 4를 맞추세요!"}
]

var level_index := 0
var grid: Array = []
var pos := Vector2i.ZERO
var start := Vector2i.ZERO
var goal := Vector2i.ZERO
var goal_face := 1
var par := 0
var moves := 0
var undo_count := 0
var orientation := {}
var history: Array = []
var message := ""
var message_time := 0.0
var completed := false
var perfect_clear := false
var bob_time := 0.0
var shake_time := 0.0
var font: Font
var screen := Screen.SPLASH
var roll_player: AudioStreamPlayer
var feedback_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var current_music := ""
var jingle_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var played_voice := {}
var sfx := {}
var voice := {}
var board_viewport: SubViewport
var board_texture: TextureRect
var board_3d: Node3D
var die_3d: MeshInstance3D
var camera_3d: Camera3D
var is_rolling := false
var block_surface_texture: Texture2D
var die_surface_texture: Texture2D

func _ready() -> void:
	font = ThemeDB.fallback_font
	setup_audio()
	setup_3d()
	queue_redraw()

func start_game() -> void:
	screen = Screen.PLAYING
	board_texture.visible = true
	load_level(0)

func setup_3d() -> void:
	block_surface_texture = load("res://assets/visual/3d/toy_block_surface.png") as Texture2D
	die_surface_texture = load("res://assets/visual/3d/die_surface.png") as Texture2D
	board_viewport = SubViewport.new()
	board_viewport.size = VIEW
	board_viewport.transparent_bg = false
	board_viewport.world_3d = World3D.new()
	board_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(board_viewport)
	board_texture = TextureRect.new()
	board_texture.texture = board_viewport.get_texture()
	board_texture.size = VIEW
	board_texture.z_index = -1
	board_texture.visible = false
	add_child(board_texture)
	board_3d = Node3D.new()
	board_viewport.add_child(board_3d)
	camera_3d = Camera3D.new()
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.current = true
	camera_3d.size = 10.0
	camera_3d.position = Vector3(7, 8, 7)
	board_3d.add_child(camera_3d)
	camera_3d.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.4
	board_3d.add_child(light)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = PALETTE.sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dcefff")
	env.ambient_light_energy = 0.8
	environment.environment = env
	board_3d.add_child(environment)

func make_material(color: Color, die_surface := false) -> StandardMaterial3D:
	var surface_material := StandardMaterial3D.new()
	surface_material.albedo_color = color
	surface_material.albedo_texture = die_surface_texture if die_surface else block_surface_texture
	surface_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	surface_material.roughness = 0.9
	surface_material.metallic = 0.0
	return surface_material

func rebuild_3d_board() -> void:
	for child in board_3d.get_children():
		if child is MeshInstance3D or child is StaticBody3D:
			child.queue_free()
	var rows := grid.size()
	var cols := 0
	for row in grid: cols = max(cols, row.length())
	fit_camera_to_board(rows, cols)
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			if row[x] != "#": continue
			var tile := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.92, 0.3, 0.92)
			tile.mesh = box
			var active: bool = abs(x - pos.x) + abs(y - pos.y) == 1
			var tile_material := make_material(PALETTE.goal if Vector2i(x, y) == goal else PALETTE.tile)
			if active:
				tile_material.emission_enabled = true
				tile_material.emission = PALETTE.mint
				tile_material.emission_energy_multiplier = 1.4
			tile.material_override = tile_material
			tile.position = Vector3(x - (cols - 1) / 2.0, 0, y - (rows - 1) / 2.0)
			board_3d.add_child(tile)
			if Vector2i(x, y) == goal:
				add_goal_texture(tile.position)
			var body := StaticBody3D.new()
			body.set_meta("cell", Vector2i(x, y))
			var shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(0.92, 0.3, 0.92)
			shape.shape = box_shape
			body.add_child(shape)
			body.position = tile.position
			board_3d.add_child(body)
	var die_box := BoxMesh.new()
	die_box.size = Vector3(0.72, 0.72, 0.72)
	die_3d = MeshInstance3D.new()
	die_3d.mesh = die_box
	die_3d.material_override = make_material(PALETTE.die,true)
	board_3d.add_child(die_3d)
	add_die_pips()
	sync_3d_die()

func fit_camera_to_board(rows: int, cols: int) -> void:
	# 세로형 화면에서도 모든 바닥 타일과 주사위가 보이도록, 현재 맵의
	# 카메라 좌표상 범위를 기준으로 직교 카메라 배율을 정한다.
	var max_x := 0.0
	var max_y := 0.0
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			if row[x] != "#":
				continue
			var tile_center := Vector3(x - (cols - 1) / 2.0, 0.0, y - (rows - 1) / 2.0)
			for offset_x in [-0.5, 0.5]:
				for offset_y in [0.0, 0.9]:
					for offset_z in [-0.5, 0.5]:
						var camera_point := camera_3d.to_local(tile_center + Vector3(offset_x, offset_y, offset_z))
						max_x = maxf(max_x, absf(camera_point.x))
						max_y = maxf(max_y, absf(camera_point.y))
	var aspect := float(VIEW.x) / float(VIEW.y)
	# 가로 90%, 세로 56%만 사용해 HUD와 하단 조작 영역을 침범하지 않는다.
	var width_size := max_x / (aspect * 0.45)
	var height_size := max_y / 0.28
	camera_3d.size = maxf(10.0, maxf(width_size, height_size))

func pip_points(value: int, spacing: float) -> Array[Vector2]:
	match value:
		1: return [Vector2.ZERO]
		2: return [Vector2(-spacing, -spacing), Vector2(spacing, spacing)]
		3: return [Vector2(-spacing, -spacing), Vector2.ZERO, Vector2(spacing, spacing)]
		4: return [Vector2(-spacing, -spacing), Vector2(spacing, -spacing), Vector2(-spacing, spacing), Vector2(spacing, spacing)]
		5: return [Vector2(-spacing, -spacing), Vector2(spacing, -spacing), Vector2.ZERO, Vector2(-spacing, spacing), Vector2(spacing, spacing)]
		6: return [Vector2(-spacing, -spacing), Vector2(spacing, -spacing), Vector2(-spacing, 0), Vector2(spacing, 0), Vector2(-spacing, spacing), Vector2(spacing, spacing)]
	return []

func add_goal_texture(tile_position: Vector3) -> void:
	var goal_texture := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.72, 0.72)
	plane.material = make_pip_texture_material(goal_face, Color(0, 0, 0, 0), PALETTE.goal_dark)
	goal_texture.mesh = plane
	goal_texture.position = tile_position + Vector3(0, 0.156, 0)
	board_3d.add_child(goal_texture)

func add_die_pips() -> void:
	var faces := {1: Vector3.UP, 6: Vector3.DOWN, 2: Vector3(0, 0, -1), 5: Vector3(0, 0, 1), 3: Vector3(1, 0, 0), 4: Vector3(-1, 0, 0)}
	var rotations := {1: Vector3.ZERO, 6: Vector3(PI, 0, 0), 2: Vector3(PI / 2.0, 0, 0), 5: Vector3(-PI / 2.0, 0, 0), 3: Vector3(0, 0, -PI / 2.0), 4: Vector3(0, 0, PI / 2.0)}
	for value in faces:
		var face := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.66, 0.66)
		var is_goal_face: bool = value == goal_face
		plane.material = make_pip_texture_material(value, PALETTE.goal if is_goal_face else Color(0, 0, 0, 0), PALETTE.goal_dark if is_goal_face else PALETTE.pip)
		face.mesh = plane
		face.position = faces[value] * 0.366
		face.rotation = rotations[value]
		die_3d.add_child(face)

func make_pip_texture_material(value: int, background: Color, dot_color: Color) -> StandardMaterial3D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(background)
	for point in pip_points(value, 0.18):
		var center := Vector2i(64 + roundi(point.x * 220.0), 64 + roundi(point.y * 220.0))
		for y in range(center.y - 12, center.y + 13):
			for x in range(center.x - 12, center.x + 13):
				if Vector2i(x, y).distance_squared_to(center) <= 144:
					image.set_pixel(x, y, dot_color)
	var pip_material := StandardMaterial3D.new()
	pip_material.albedo_texture = ImageTexture.create_from_image(image)
	pip_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pip_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	pip_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return pip_material

func sync_3d_die() -> void:
	if die_3d == null: return
	var rows := grid.size()
	var cols := 0
	for row in grid: cols = max(cols, row.length())
	die_3d.position = Vector3(pos.x - (cols - 1) / 2.0, 0.52, pos.y - (rows - 1) / 2.0)
	die_3d.quaternion = orientation_quaternion()

func orientation_quaternion() -> Quaternion:
	# 로컬 주사위 면(동=3, 위=1, 남=5)을 현재 규칙 상태의 월드 방향에 맞춘다.
	return Basis(
		world_direction_for_face(3),
		world_direction_for_face(1),
		world_direction_for_face(5)
	).get_rotation_quaternion()

func world_direction_for_face(face: int) -> Vector3:
	if orientation.top == face: return Vector3.UP
	if orientation.bottom == face: return Vector3.DOWN
	if orientation.north == face: return Vector3(0, 0, -1)
	if orientation.south == face: return Vector3(0, 0, 1)
	if orientation.east == face: return Vector3.RIGHT
	return Vector3.LEFT

func animate_die_roll(direction: Vector2i) -> void:
	var rows := grid.size()
	var cols := 0
	for row in grid: cols = max(cols, row.length())
	var target := Vector3(pos.x - (cols - 1) / 2.0, 0.52, pos.y - (rows - 1) / 2.0)
	var axis := Vector3(0, 0, 1) if direction.x != 0 else Vector3(1, 0, 0)
	var angle := -direction.x * 90.0 if direction.x != 0 else direction.y * 90.0
	var target_quaternion := (Quaternion(axis, deg_to_rad(angle)) * die_3d.quaternion).normalized()
	is_rolling = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(die_3d, "position", target, 0.22)
	tween.tween_property(die_3d, "quaternion", target_quaternion, 0.22)
	tween.finished.connect(func() -> void:
		is_rolling = false
		feedback_player.stream = sfx.land
		feedback_player.play()
		rebuild_3d_board()
	)

func animate_die_undo() -> void:
	var rows := grid.size()
	var cols := 0
	for row in grid: cols = max(cols, row.length())
	var target := Vector3(pos.x - (cols - 1) / 2.0, 0.52, pos.y - (rows - 1) / 2.0)
	is_rolling = true
	roll_player.stream = sfx.roll
	roll_player.play()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(die_3d, "position", target, 0.22)
	tween.tween_property(die_3d, "quaternion", orientation_quaternion(), 0.22)
	tween.finished.connect(func() -> void:
		is_rolling = false
		feedback_player.stream = sfx.undo
		feedback_player.play()
		rebuild_3d_board()
	)

func setup_audio() -> void:
	roll_player = make_audio_player(-14.0)
	feedback_player = make_audio_player(-12.0)
	music_player = make_audio_player(-3.0)
	jingle_player = make_audio_player(-10.0)
	voice_player = make_audio_player(-8.0)
	sfx = {"roll": wav("dice_roll"), "land": wav("dice_land"), "blocked": wav("blocked"), "undo": wav("undo"), "clear": wav("clear"), "perfect": wav("perfect_clear"), "death": wav("death")}
	voice = {"move": voice_wav("tutorial_move"), "goal": voice_wav("tutorial_goal"), "safe": voice_wav("tutorial_safe"), "undo": voice_wav("tutorial_undo"), "par": voice_wav("tutorial_par"), "clear": voice_wav("tutorial_clear")}
	start_menu_bgm()

func start_menu_bgm() -> void:
	start_bgm("menu","res://assets/audio/music/menu_loop.wav")

func start_puzzle_bgm() -> void:
	start_bgm("puzzle","res://assets/audio/music/puzzle_loop.wav")

func start_bgm(id: String, bgm_path: String) -> void:
	if current_music == id and music_player.playing: return
	var source := load(bgm_path) as AudioStreamWAV
	if source == null:
		push_error("BGM could not be loaded: %s" % bgm_path)
		return
	var bgm := source.duplicate() as AudioStreamWAV
	bgm.loop_begin = 0
	bgm.loop_end = roundi(bgm.get_length()*float(bgm.mix_rate))
	bgm.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_player.stop()
	music_player.stream = bgm
	music_player.play()
	current_music = id
	print("BGM %s playing: %s" % [id,ProjectSettings.globalize_path(bgm_path)])

func wav(asset_name: String) -> AudioStreamWAV:
	return load("res://assets/audio/sfx/%s.wav" % asset_name) as AudioStreamWAV

func voice_wav(asset_name: String) -> AudioStreamWAV:
	return load("res://assets/audio/voice/%s.wav" % asset_name) as AudioStreamWAV

func make_audio_player(volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.volume_db = volume
	add_child(player)
	return player

func play_voice_once(id: String, subtitle: String) -> void:
	if played_voice.has(id):
		return
	played_voice[id] = true
	voice_player.stream = voice[id]
	voice_player.play()
	message = subtitle
	message_time = 3.5

func standard_die() -> Dictionary:
	# 북/남, 동/서는 각각 서로 마주 보는 표준 주사위 면입니다.
	return {"top": 1, "bottom": 6, "north": 2, "south": 5, "east": 3, "west": 4}

func load_level(index: int) -> void:
	level_index = index % levels.size()
	var data: Dictionary = levels[level_index]
	grid = data.map
	start = data.start
	goal = data.goal
	goal_face = data.face
	par = data.par
	pos = start
	moves = 0
	undo_count = 0
	orientation = standard_die()
	history.clear()
	completed = false
	perfect_clear = false
	message = data.hint
	message_time = 4.0
	var tutorial := {0: ["move", "화면의 방향 화살표를 눌러 주사위를 굴려 보세요."], 1: ["goal", "목표 숫자와 윗면 숫자가 같아야 해요."], 3: ["undo", "Undo 버튼을 누르면 한 번의 행동을 되돌릴 수 있어요."], 4: ["par", "목표 입력 수 안에 풀면 완벽 클리어예요."]}
	if tutorial.has(level_index):
		var line: Array = tutorial[level_index]
		play_voice_once(line[0], line[1])
	rebuild_3d_board()
	queue_redraw()

func _process(delta: float) -> void:
	bob_time += delta
	message_time = maxf(0.0, message_time - delta)
	shake_time = maxf(0.0, shake_time - delta)
	queue_redraw()

func roll(direction: Vector2i) -> void:
	if screen != Screen.PLAYING or completed or is_rolling:
		return
	var next := pos + direction
	if not is_floor(next):
		feedback_player.stream = sfx.blocked
		feedback_player.play()
		shake_time = 0.25
		play_voice_once("safe", "블록 밖으로 가면 마지막 안전한 곳으로 돌아와요.")
		if message_time <= 0.0:
			message = "블록 밖이에요. 마지막 안전한 곳에 머물렀어요."
			message_time = 2.2
		return
	roll_player.stream = sfx.roll
	roll_player.play()
	history.append({"pos": pos, "orientation": orientation.duplicate(true), "moves": moves})
	orientation = rolled_orientation(orientation, direction)
	pos = next
	animate_die_roll(direction)
	moves += 1
	if pos == goal:
		if orientation.top == goal_face:
			completed = true
			perfect_clear = moves <= par
			feedback_player.stream = sfx.perfect if perfect_clear else sfx.clear
			feedback_player.play()
			jingle_player.stream = load("res://assets/audio/music/clear_jingle.ogg") as AudioStreamOggVorbis
			jingle_player.play()
			message = "완벽해요!" if perfect_clear else "클리어! 다음엔 목표 이동 수도 맞춰볼까요?"
			message_time = 99.0
			play_voice_once("clear", "잘했어요! 다음 퍼즐로 가 볼까요?")
		else:
			message = "도착했지만 윗면이 %d예요. 목표는 %d!" % [orientation.top, goal_face]
			message_time = 2.4
	queue_redraw()

func rolled_orientation(die: Dictionary, direction: Vector2i) -> Dictionary:
	var result := die.duplicate(true)
	if direction == Vector2i.RIGHT:
		result.top = die.west; result.bottom = die.east; result.east = die.top; result.west = die.bottom
	elif direction == Vector2i.LEFT:
		result.top = die.east; result.bottom = die.west; result.east = die.bottom; result.west = die.top
	elif direction == Vector2i.UP:
		result.top = die.south; result.bottom = die.north; result.north = die.top; result.south = die.bottom
	elif direction == Vector2i.DOWN:
		result.top = die.north; result.bottom = die.south; result.north = die.bottom; result.south = die.top
	return result

func undo() -> void:
	if completed or is_rolling:
		return
	if undo_count >= MAX_UNDOS:
		message = "이 레벨의 Undo를 모두 사용했어요."
		message_time = 1.8
		return
	if history.is_empty():
		return
	var state: Dictionary = history.pop_back()
	pos = state.pos
	orientation = state.orientation
	moves = state.moves
	undo_count += 1
	animate_die_undo()
	message = "한 칸 되돌렸어요."
	message_time = 1.3

func reset_level() -> void:
	load_level(level_index)

func is_floor(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= grid.size():
		return false
	var row: String = grid[cell.y]
	return cell.x >= 0 and cell.x < row.length() and row[cell.x] == "#"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if screen == Screen.SPLASH and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			screen = Screen.HOME
			queue_redraw()
			return
		if screen == Screen.HOME and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			start_game()
			return
		if screen != Screen.PLAYING:
			return
		if completed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			load_level(level_index + 1)
			return
		if event.is_action_pressed("move_up"): roll(Vector2i.UP)
		elif event.is_action_pressed("move_down"): roll(Vector2i.DOWN)
		elif event.is_action_pressed("move_left"): roll(Vector2i.LEFT)
		elif event.is_action_pressed("move_right"): roll(Vector2i.RIGHT)
		elif event.is_action_pressed("undo"): undo()
		elif event.is_action_pressed("reset"): reset_level()
	elif event is InputEventScreenTouch and event.pressed:
		if screen == Screen.SPLASH:
			screen = Screen.HOME
			queue_redraw()
		else:
			handle_touch(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if screen == Screen.SPLASH:
			screen = Screen.HOME
			queue_redraw()
		else:
			handle_touch(event.position)

func handle_touch(point: Vector2) -> void:
	if screen == Screen.HOME:
		if Rect2(54, 390, 252, 56).has_point(point):
			start_game()
		return
	if screen == Screen.PLAYING and try_move_to_touched_tile(point):
		return
	if Rect2(Vector2(8, 666), Vector2(46, 44)).has_point(point):
		get_tree().quit()
		return
	if Rect2(Vector2(58, 666), Vector2(54, 44)).has_point(point):
		reset_level()
		return
	if completed:
		if Rect2(25, 200, 310, 260).has_point(point):
			load_level(level_index + 1)
		return
	elif Rect2(Vector2(116, 666), Vector2(54, 44)).has_point(point): undo()

func try_move_to_touched_tile(point: Vector2) -> bool:
	if is_rolling or camera_3d == null: return false
	var from := camera_3d.project_ray_origin(point)
	var to := from + camera_3d.project_ray_normal(point) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := board_viewport.world_3d.direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("cell"): return false
	var cell: Vector2i = hit.collider.get_meta("cell")
	var direction := cell - pos
	if abs(direction.x) + abs(direction.y) != 1 or not is_floor(cell): return false
	roll(direction)
	return true

func board_cell_to_screen(cell: Vector2i) -> Vector2:
	var rows := grid.size()
	var cols := 0
	for row in grid: cols = max(cols, row.length())
	var local_x := cell.x - (cols - 1) / 2.0
	var local_y := cell.y - (rows - 1) / 2.0
	return Vector2(VIEW.x / 2.0 + (local_x - local_y) * TILE * 0.55, VIEW.y / 2.0 + (local_x + local_y) * TILE * 0.28)

func _draw() -> void:
	if screen == Screen.SPLASH:
		draw_splash()
		return
	if screen == Screen.HOME:
		draw_home()
		return
	draw_background()
	draw_header()
	draw_board()
	draw_bottom_ui()
	if completed:
		draw_win_card()

func draw_splash() -> void:
	draw_background()
	draw_round_panel(Rect2(28, 198, 304, 280), PALETTE.panel, PALETTE.ink)
	draw_string(font, Vector2(28, 267), "TUMBLE", HORIZONTAL_ALIGNMENT_CENTER, 304, 38, PALETTE.ink)
	draw_string(font, Vector2(28, 305), "TOY", HORIZONTAL_ALIGNMENT_CENTER, 304, 38, PALETTE.mint_dark)
	draw_die(Vector2(180, 362), 1)
	draw_string(font, Vector2(28, 445), "화면을 탭하여 계속", HORIZONTAL_ALIGNMENT_CENTER, 304, 15, Color("765c71"))

func draw_home() -> void:
	draw_background()
	draw_round_panel(Rect2(28, 160, 304, 324), PALETTE.panel, PALETTE.ink)
	draw_string(font, Vector2(28, 218), "TUMBLE TOY", HORIZONTAL_ALIGNMENT_CENTER, 304, 27, PALETTE.ink)
	draw_string(font, Vector2(48, 261), "주사위를 굴려 목표 숫자를 맞춰요.", HORIZONTAL_ALIGNMENT_CENTER, 264, 15, Color("765c71"))
	draw_string(font, Vector2(48, 289), "경로와 윗면을 함께 생각해 보세요!", HORIZONTAL_ALIGNMENT_CENTER, 264, 14, Color("765c71"))
	draw_button(Rect2(54, 390, 252, 56), "시작하기")
	draw_string(font, Vector2(28, 468), "시작 버튼을 눌러 게임 시작", HORIZONTAL_ALIGNMENT_CENTER, 304, 12, PALETTE.mint_dark)

func draw_background() -> void:
	if screen == Screen.PLAYING:
		return
	draw_rect(Rect2(Vector2.ZERO, VIEW), PALETTE.sky)
	# 벽지 점무늬
	for y in range(18, 402, 28):
		for x in range(18, 360, 28):
			draw_circle(Vector2(x, y), 1.4, Color("7dc7e1"))
	# 구름 같은 장난감 벽 장식
	for cloud_pos in [Vector2(32, 104), Vector2(260, 148), Vector2(220, 82)]:
		draw_circle(cloud_pos, 18, PALETTE.cloud)
		draw_circle(cloud_pos + Vector2(22, -5), 23, PALETTE.cloud)
		draw_circle(cloud_pos + Vector2(47, 2), 16, PALETTE.cloud)
		draw_rect(Rect2(cloud_pos + Vector2(-5, 4), Vector2(60, 18)), PALETTE.cloud)

func draw_header() -> void:
	draw_round_panel(Rect2(16, 14, 328, 76), PALETTE.panel, PALETTE.ink)
	draw_string(font, Vector2(28, 40), "TUMBLE TOY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PALETTE.ink)
	draw_string(font, Vector2(28, 63), "Level %02d · %s" % [level_index + 1, levels[level_index].name], HORIZONTAL_ALIGNMENT_LEFT, 155, 12, Color("765c71"))
	draw_stat(Vector2(188, 29), "이동", str(moves))
	draw_stat(Vector2(240, 29), "목표", str(par))
	draw_stat(Vector2(292, 29), "윗면", str(orientation.top))

func draw_stat(at: Vector2, label: String, value: String) -> void:
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 50, 11, Color("765c71"))
	draw_string(font, at + Vector2(0, 22), value, HORIZONTAL_ALIGNMENT_CENTER, 50, 18, PALETTE.ink)

func draw_board() -> void:
	if screen == Screen.PLAYING:
		return
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			if row[x] == "#": draw_tile(board_cell_to_screen(Vector2i(x, y)), Vector2i(x, y))
	# 목표를 주사위보다 먼저 그립니다.
	draw_start_marker(board_cell_to_screen(start))
	draw_goal(board_cell_to_screen(goal))
	var offset := Vector2.ZERO
	if shake_time > 0.0: offset.x = sin(bob_time * 90.0) * 4.0
	draw_die(board_cell_to_screen(pos) + offset + Vector2(0, sin(bob_time * 4.0) * 2.0), orientation.top)

func draw_tile(at: Vector2, _cell: Vector2i) -> void:
	var half_width := TILE * 0.55
	var half_height := TILE * 0.28
	var depth := 10.0
	var top := PackedVector2Array([at + Vector2(0, -half_height), at + Vector2(half_width, 0), at + Vector2(0, half_height), at + Vector2(-half_width, 0)])
	var left := PackedVector2Array([at + Vector2(-half_width, 0), at + Vector2(0, half_height), at + Vector2(0, half_height + depth), at + Vector2(-half_width, depth)])
	var right := PackedVector2Array([at + Vector2(0, half_height), at + Vector2(half_width, 0), at + Vector2(half_width, depth), at + Vector2(0, half_height + depth)])
	draw_colored_polygon(left, PALETTE.tile_edge)
	draw_colored_polygon(right, Color("d99058"))
	draw_colored_polygon(top, PALETTE.tile)
	draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), PALETTE.ink, 1.5)
	draw_line(at + Vector2(-half_width * 0.35, 0), at + Vector2(0, half_height * 0.35), PALETTE.tile_line, 1.5)

func draw_goal(at: Vector2) -> void:
	draw_circle(at + Vector2(0, 4), 16, PALETTE.goal_dark)
	draw_circle(at, 16, PALETTE.goal)
	draw_circle(at, 11, Color("ffd7af"))
	draw_string(font, at + Vector2(-14, 6), str(goal_face), HORIZONTAL_ALIGNMENT_CENTER, 28, 18, PALETTE.goal_dark)

func draw_start_marker(at: Vector2) -> void:
	var color := PALETTE.mint_dark
	draw_circle(at, 13, Color(PALETTE.mint, 0.72), false, 2)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var outer: Vector2 = at + direction * 14.0
		var inner: Vector2 = at + direction * 8.0
		draw_line(outer, inner, color, 2)
		draw_circle(inner, 2.5, color)

func draw_die(at: Vector2, top: int) -> void:
	var half_width := 17.0
	var half_height := 9.0
	var depth := 13.0
	draw_circle(at + Vector2(3, 13), 12, Color(PALETTE.die_shadow, 0.65))
	var top_face := PackedVector2Array([at + Vector2(0, -half_height), at + Vector2(half_width, 0), at + Vector2(0, half_height), at + Vector2(-half_width, 0)])
	var left_face := PackedVector2Array([at + Vector2(-half_width, 0), at + Vector2(0, half_height), at + Vector2(0, half_height + depth), at + Vector2(-half_width, depth)])
	var right_face := PackedVector2Array([at + Vector2(0, half_height), at + Vector2(half_width, 0), at + Vector2(half_width, depth), at + Vector2(0, half_height + depth)])
	draw_colored_polygon(left_face, Color("e3d7bb"))
	draw_colored_polygon(right_face, Color("d1c19f"))
	draw_colored_polygon(top_face, PALETTE.die)
	draw_polyline(PackedVector2Array([top_face[0], top_face[1], top_face[2], top_face[3], top_face[0]]), PALETTE.ink, 1.5)
	var pips := {
		1:[Vector2(0,0)], 2:[Vector2(-8,-8),Vector2(8,8)], 3:[Vector2(-8,-8),Vector2(0,0),Vector2(8,8)],
		4:[Vector2(-8,-8),Vector2(8,-8),Vector2(-8,8),Vector2(8,8)],
		5:[Vector2(-8,-8),Vector2(8,-8),Vector2(0,0),Vector2(-8,8),Vector2(8,8)],
		6:[Vector2(-8,-9),Vector2(8,-9),Vector2(-8,0),Vector2(8,0),Vector2(-8,9),Vector2(8,9)]}
	for pip in pips[top]: draw_circle(at + pip * Vector2(0.8, 0.55), 2.3, PALETTE.pip)

func draw_bottom_ui() -> void:
	var guide := message if message_time > 0.0 else "목표 숫자 %d가 위로 오게 굴려 보세요." % goal_face
	draw_string(font, Vector2(24, 555), guide, HORIZONTAL_ALIGNMENT_LEFT, 312, 12, PALETTE.ink)
	draw_string(font, Vector2(20, 579), "목표: %d  ·  완벽 %d회 이하  ·  Undo %d/%d" % [goal_face, par, undo_count, MAX_UNDOS], HORIZONTAL_ALIGNMENT_CENTER, 320, 13, PALETTE.ink)
	# 좌측 명령과 우측 십자 방향 컨트롤
	draw_button(Rect2(8, 666, 46, 44), "종료")
	draw_button(Rect2(58, 666, 54, 44), "재시작")
	draw_button(Rect2(116, 666, 54, 44), "Undo", undo_count >= MAX_UNDOS)

func draw_button(rect: Rect2, text: String, disabled := false) -> void:
	var face_color: Color = Color("c8ced8") if disabled else PALETTE.mint
	var shadow_color: Color = Color("8993a3") if disabled else PALETTE.mint_dark
	draw_rect(Rect2(rect.position + Vector2(0, 3), rect.size), shadow_color)
	draw_rect(rect, face_color)
	draw_rect(rect, PALETTE.ink, false, 2)
	draw_string(font, rect.position + Vector2(0, rect.size.y / 2 + 6), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 15, PALETTE.ink)

func draw_direction_button(rect: Rect2, arrow: String, direction: Vector2i) -> void:
	draw_button(rect, arrow)
	if completed or not is_floor(pos + direction):
		return
	var next_top: int = rolled_orientation(orientation, direction).top
	var badge_center: Vector2 = rect.position + Vector2(rect.size.x - 9, 10)
	draw_circle(badge_center, 9, Color("fff8e7"))
	draw_circle(badge_center, 9, PALETTE.mint_dark, false, 1)
	draw_string(font, badge_center + Vector2(-7, 4), str(next_top), HORIZONTAL_ALIGNMENT_CENTER, 14, 11, PALETTE.mint_dark)

func draw_round_panel(rect: Rect2, fill: Color, outline: Color) -> void:
	draw_style_box(make_panel_style(fill, outline), rect)

func make_panel_style(fill: Color, outline: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10; style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10; style.corner_radius_bottom_right = 10
	return style

func draw_win_card() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.19, 0.15, 0.28, 0.45))
	var card := Rect2(25, 200, 310, 260)
	draw_round_panel(card, PALETTE.panel, PALETTE.ink)
	var title := "PERFECT CLEAR!" if perfect_clear else "LEVEL CLEAR!"
	draw_string(font, Vector2(25, 260), title, HORIZONTAL_ALIGNMENT_CENTER, 310, 28, PALETTE.ink)
	draw_string(font, Vector2(25, 300), "목표 숫자 %d를 맞췄어요!" % goal_face, HORIZONTAL_ALIGNMENT_CENTER, 310, 18, PALETTE.mint_dark)
	draw_string(font, Vector2(25, 336), "%d회 이동  ·  목표 %d회" % [moves, par], HORIZONTAL_ALIGNMENT_CENTER, 310, 17, PALETTE.ink)
	draw_string(font, Vector2(25, 392), "카드를 터치하거나 Enter를 눌러 다음 레벨", HORIZONTAL_ALIGNMENT_CENTER, 310, 14, Color("765c71"))
