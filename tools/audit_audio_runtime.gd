extends SceneTree
const Game = preload("res://campaign_game.gd")

func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	var game = Game.new()
	game.persist_progress = false
	game.persist_settings = false
	root.add_child(game)
	await create_timer(0.75).timeout
	print("AUDIO driver=%s rate=%s" % [AudioServer.get_driver_name(),AudioServer.get_mix_rate()])
	print("AUDIO master mute=%s volume_db=%.2f" % [AudioServer.is_bus_mute(0),AudioServer.get_bus_volume_db(0)])
	print("AUDIO %s playing=%s position=%.3f volume_db=%.2f length=%.3f loop=%d..%d" % [game.current_music,game.music_player.playing,game.music_player.get_playback_position(),game.music_player.volume_db,game.music_player.stream.get_length(),game.music_player.stream.loop_begin,game.music_player.stream.loop_end])
	game.load_level(0)
	await create_timer(0.5).timeout
	print("AUDIO %s playing=%s position=%.3f length=%.3f" % [game.current_music,game.music_player.playing,game.music_player.get_playback_position(),game.music_player.stream.get_length()])
	game.show_menu()
	await create_timer(0.5).timeout
	print("AUDIO %s playing=%s position=%.3f length=%.3f" % [game.current_music,game.music_player.playing,game.music_player.get_playback_position(),game.music_player.stream.get_length()])
	game.queue_free()
	await process_frame
	quit()
