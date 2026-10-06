extends SceneTree
const Game = preload("res://campaign_game.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = Game.new()
	game.persist_progress = false
	game.persist_settings = false
	root.add_child(game)
	root.size = Vector2i(360,800)
	await process_frame
	game._process(game.SPLASH_DURATION+0.01)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/campaign")
	root.get_texture().get_image().save_png("res://artifacts/campaign/splash.png")
	game.queue_free()
	await process_frame
	quit()
