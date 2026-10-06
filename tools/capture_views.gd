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
	game.records.clear()
	game.load_level(9)
	DirAccess.make_dir_recursive_absolute("res://artifacts/views")
	var names = ["01-top","02-quarter","03-3d"]
	for mode in range(3):
		game.set_view_mode(mode)
		game.overlay = ""
		game.set_paused(false)
		await process_frame
		game.set_paused(false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/views/%s.png" % names[mode])
	game.show_menu()
	game.records.clear()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/views/00-stage-select.png")
	game.queue_free()
	await process_frame
	quit()
