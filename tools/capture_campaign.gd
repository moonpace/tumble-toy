extends SceneTree
const Game = preload("res://campaign_game.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = Game.new()
	game.persist_progress = false
	root.add_child(game)
	root.size = Vector2i(360,800)
	await process_frame
	game._process(game.SPLASH_DURATION+0.01)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/splash.png")
	game.records.clear()
	DirAccess.make_dir_recursive_absolute("res://artifacts/campaign")
	game.show_title_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/main-menu.png")
	game.show_menu_page(game.MenuPage.SETTINGS)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/settings-menu.png")
	game.show_menu_page(game.MenuPage.TUTORIAL)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/tutorial-menu.png")
	for index in [-1,0,1,2,3,4,5,6,7,8,9,19,29,49,59,69,79,89,99]:
		if index<0: game.show_menu()
		else: game.load_level(index)
		game.paused = false
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/campaign/stage-%03d.png" % (index+1))
	game.records["1"] = {"clear":true,"moves":8,"seconds":12.0,"medal":false}
	game.show_menu()
	game.world_page = 0
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/stage-unlocked.png")
	game.records.clear()
	game.load_level(0)
	game.completed = true
	game.perfect_clear = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/perfect.png")
	game.completed = false
	for k in game.level.tiles:
		if game.Rules.point(k) != game.level.start:
			game.state.hp[k] = 0
			break
	game.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/void.png")
	game.load_level(99)
	game.overlay = ""
	game.set_paused(true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/pause.png")
	game.set_paused(false)
	game.overlay = "bag"
	game.paused = false
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/bag.png")
	game.overlay = "help"
	game.paused = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/campaign/help.png")
	game.queue_free()
	await process_frame
	quit()
