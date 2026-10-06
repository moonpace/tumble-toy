extends SceneTree
const Assets = preload("res://visual_assets.gd")

func _initialize() -> void:
	var assets = Assets.new()
	var failures = 0
	var transparent_corner_assets := ["die","floor","goal","void","start","cloud","star","blocks","undo","restart","perfect","menu_hero"]
	for key in Assets.PATHS:
		if not assets.textures.has(key):
			failures += 1
			continue
		var texture = load("res://assets/visual/"+Assets.PATHS[key]) as Texture2D
		var image = texture.get_image()
		var used = image.get_used_rect()
		if used.size.x == 0 or used.size.y == 0:
			push_error("Empty asset: "+key)
			failures += 1
		if key in transparent_corner_assets and not image.is_invisible() and image.get_pixel(0,0).a > 0.01:
			push_error("Sprite corner must be transparent: "+key)
			failures += 1
		print("ASSET ",key," ",image.get_size()," used=",used)
	var expected := Assets.PATHS.size()
	print("PASS: %d imported visual assets, nonempty content and transparent sprite corners" % expected if failures==0 and assets.textures.size()==expected else "FAIL: visual asset audit")
	quit(0 if failures==0 and assets.textures.size()==expected else 1)
