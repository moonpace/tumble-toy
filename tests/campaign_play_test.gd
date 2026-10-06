extends SceneTree
const Game = preload("res://campaign_game.gd")
var failures: Array[String] = []
var game

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, why: String) -> void:
	if not ok: failures.append(why)

func settle() -> void:
	for _i in range(300):
		if not game.is_rolling: break
		game._process(0.2)
	if game.motion != null: game.motion.kill()
	game.wait_left = 0.0

func load_fixture(kind: String) -> void:
	var l = game.levels[0].duplicate(true)
	l.tiles = {}
	l.width = 5
	l.height = 3
	l.floors = 1
	l.start = [0,1,0]
	l.goal = [4,2,0]
	l.face = 6
	for y in range(3):
		for x in range(5): game.Campaign.put(l,x,y,0,"floor")
	game.Campaign.put(l,2 if kind=="fire" else 1,1,0,kind,{"hp":1})
	game.levels[0] = l
	game.load_level(0)

func run() -> void:
	game = Game.new()
	game.persist_progress = false
	game.persist_settings = false
	root.add_child(game)
	game.set_process(false)
	await process_frame
	expect(game.view_mode==game.ViewMode.THREE_D,"Fresh launch uses the final 3D view")
	expect(game.music_player.playing and game.music_player.stream.loop_end>0 and game.current_music=="menu","Menu BGM starts with a valid full-length loop")
	expect(game.sfx.values().all(func(stream): return stream != null) and game.voice.values().all(func(stream): return stream != null),"SFX and voice resources load through Godot resources")
	expect(game.screen==game.Screen.SPLASH,"Fresh launch opens splash")
	game.handle_touch(Vector2(180,459))
	expect(game.screen==game.Screen.SPLASH,"Splash blocks touch input")
	game._process(2.9)
	expect(game.screen==game.Screen.SPLASH,"Splash remains visible before 3 seconds")
	game._process(0.11)
	expect(game.screen==game.Screen.SPLASH and game.splash_ready_for_input,"Splash waits for input after loading and 3 seconds")
	game.handle_touch(Vector2(180,644))
	expect(game.screen==game.Screen.HOME and game.menu_page==game.MenuPage.MAIN,"Ready splash touch opens main menu")
	game.records.clear()
	expect(game.screen==game.Screen.HOME and game.menu_page==game.MenuPage.MAIN,"Fresh launch opens main menu")
	expect(game.is_stage_unlocked(0) and not game.is_stage_unlocked(1),"Fresh progress unlocks only stage 1")
	game.show_menu()
	game.handle_touch(game.stage_rect(1).get_center())
	expect(game.screen==game.Screen.HOME,"Locked stage ignores touch")
	game.records["1"] = {"clear":true}
	expect(game.is_stage_unlocked(0) and game.is_stage_unlocked(1) and not game.is_stage_unlocked(2),"Clear unlocks replay and next stage only")
	game.records.clear()
	game.show_title_menu()
	game.handle_touch(Vector2(249,526))
	expect(game.menu_page==game.MenuPage.STAGES,"Main menu opens stage select")
	expect(game.current_music=="menu","Menu pages keep menu BGM")
	game.handle_touch(Vector2(310,62))
	expect(game.menu_page==game.MenuPage.MAIN,"Stage select back button returns to main menu")
	game.handle_touch(Vector2(111,526))
	expect(game.menu_page==game.MenuPage.TUTORIAL,"Main menu opens tutorial")
	game.handle_touch(Vector2(180,632))
	expect(game.menu_page==game.MenuPage.MAIN,"Tutorial back button returns to main menu")
	game.handle_touch(Vector2(180,590))
	expect(game.menu_page==game.MenuPage.SETTINGS,"Main menu opens settings")
	game.music_volume = 100
	game.sfx_volume = 100
	game.voice_enabled = true
	game.handle_touch(Vector2(74,240))
	game.handle_touch(Vector2(74,348))
	game.handle_touch(Vector2(180,448))
	expect(game.music_volume==75 and game.sfx_volume==75 and not game.voice_enabled,"Settings controls update audio options")
	expect(game.music_player.volume_db < -3.0 and game.roll_player.volume_db < -14.0 and not game.voice_player.playing,"Settings apply to active audio players")
	game.handle_touch(Vector2(180,564))
	expect(game.menu_page==game.MenuPage.MAIN,"Settings completion returns to main menu")
	game.handle_touch(Vector2(180,459))
	expect(game.screen==game.Screen.PLAYING and game.level_index==0,"Main menu starts first incomplete stage")
	expect(game.current_music=="puzzle" and game.music_player.playing,"Stage starts puzzle BGM")
	game.load_level(0)
	game.perform(game.level.solution[0])
	settle()
	var view_snapshot = {
		"state":game.state.duplicate(true),"moves":game.moves,"history":game.history.duplicate(true),
		"elapsed":game.elapsed,"bag":game.state.bag.duplicate(true)
	}
	for mode in [game.ViewMode.TOP,game.ViewMode.QUARTER,game.ViewMode.THREE_D,game.ViewMode.TOP]:
		game.set_view_mode(mode)
		expect(game.state==view_snapshot.state and game.moves==view_snapshot.moves,"View switch preserves rule state")
		expect(game.history==view_snapshot.history and game.elapsed==view_snapshot.elapsed,"View switch preserves Undo and timer")
		expect(game.state.bag==view_snapshot.bag,"View switch preserves inventory")
		expect(game.board_texture.visible==(mode==game.ViewMode.THREE_D),"Only 3D mode displays existing 3D viewport")
		expect((game.board_viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS)==(mode==game.ViewMode.THREE_D),"Only 3D mode renders 3D viewport")
	var count = 0
	for index in range(100):
		game.load_level(index)
		for z in range(int(game.level.floors)):
			game.view_floor = z
			game.refresh()
			for k in game.level.tiles:
				var p = game.Rules.point(k)
				if p[2] != z: continue
				expect(Rect2(18,207,324,310).has_point(game.top_cell_center(p)),"Stage %d top view clips a tile" % (index+1))
				for x in [-0.5,0.5]:
					for y in [-0.15,1.1]:
						for zz in [-0.5,0.5]:
							var pixel = game.camera_3d.unproject_position(game.location(p)-Vector3(0,0.52,0)+Vector3(x,y,zz))
							expect(Rect2(17,173,326,348).has_point(pixel),"Stage %d floor %d camera clips %s" % [index+1,z+1,pixel])
		game.view_floor = 0
		game.refresh()
		for a in game.level.solution:
			game.perform(a)
			settle()
			count += 1
			await process_frame
		expect(game.completed and not game.state.dead,"Actual game replay %d" % (index+1))
		expect(game.moves==game.level.solution.size(),"Input counting %d" % (index+1))
		game.undo()
		expect(not game.completed,"Undo clear state")
		game.perform(game.level.solution.back())
		settle()
		expect(game.completed,"Replay after Undo %d" % (index+1))
		if index%10==9: print("PLAY VERIFIED %d stages" % (index+1))
	# Realtime wait, full snapshots, death recovery and timer gates.
	load_fixture("glue")
	game.perform("right")
	settle()
	game.wait_left = 3.0
	var moves = game.moves
	game.perform("right")
	expect(game.moves==moves,"Sticky must block player input")
	game._process(1.0)
	expect(game.wait_left==2.0 and game.elapsed>=1.0,"Sticky counts toward timer")
	game.set_paused(true)
	var seconds = game.elapsed
	game._process(1.0)
	expect(game.elapsed==seconds and game.wait_left==2.0,"Pause freezes clock and glue")
	game.set_paused(false)
	load_fixture("fragile")
	game.perform("right")
	settle()
	var snapshot = game.state.duplicate(true)
	game.perform("right")
	settle()
	expect(game.state.hp["1,1,0"]==0,"Runtime fragile destroyed")
	game.undo()
	expect(game.state==snapshot,"Runtime Undo restores full state")
	load_fixture("fire")
	game.perform("right")
	settle()
	game.perform("right")
	settle()
	expect(game.state.dead,"Runtime fire fails")
	game.undo()
	expect(not game.state.dead,"Runtime Undo revives")
	game.load_level(9)
	game.elapsed = game.level.time_limit+1
	expect(not game.earned_medal(),"Timeout no medal")
	game.elapsed = 1
	game.assisted = true
	expect(not game.earned_medal(),"Hint no time medal")
	game.assisted = false
	expect(game.earned_medal(),"Valid time earns medal")
	game.request_hint()
	while game.hint_thread != null:
		game._process(0)
		await process_frame
	expect(game.message.begins_with("해법의 다음 행동"),"Threaded hint returns a valid action")
	game.show_menu()
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: %d actual inputs across 100 stages; all floors fit; Undo/death/glue/pause/time/hint verified" % count)
	else:
		for failure in failures.slice(0,20): push_error(failure)
	quit(0 if failures.is_empty() else 1)
