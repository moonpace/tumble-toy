extends RefCounted

# Generated originals are preserved; sprites are sampled with nearest filtering.
const PATHS = {
	"die":"gameplay/die_body.png", "floor":"gameplay/floor_tile.png",
	"goal":"gameplay/goal_tile.png", "void":"gameplay/void_tile.png",
	"start":"gameplay/start_marker.png", "badge":"ui/prediction_badge.png",
	"background":"backgrounds/toy_room_wall.png", "cloud":"decor/cloud.png",
	"star":"decor/star.png", "blocks":"decor/blocks.png",
	"undo":"ui/icon_undo.png", "restart":"ui/icon_restart.png",
	"perfect":"ui/icon_perfect_star.png", "panel":"ui/panel_9slice.png",
	"button_default":"ui/button_default_9slice.png", "button_primary":"ui/button_primary_9slice.png",
	"button_pressed":"ui/button_pressed_9slice.png", "view_tab":"ui/view_tab_9slice.png",
	"direction":"ui/direction_button.png", "item_slot":"ui/item_slot_9slice.png",
	"menu_hero":"ui/menu_hero.png"
}
var textures: Dictionary = {}

func _init() -> void:
	var regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/visual/regions.json"))
	for key in PATHS:
		var path = "res://assets/visual/" + PATHS[key]
		var texture = load(path) as Texture2D
		if texture == null:
			push_error("Missing visual asset: " + path)
			continue
		if key == "background":
			textures[key] = texture
		else:
			var r = regions.get(PATHS[key], [0, 0, texture.get_width(), texture.get_height()])
			var region = Rect2(r[0],r[1],r[2],r[3])
			var bounds = Rect2(0,0,texture.get_width(),texture.get_height())
			if bounds.encloses(region):
				var atlas = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = region
				textures[key] = atlas
			else:
				# PixelLab 승인본은 명세의 네이티브 캔버스이므로 전체 텍스처를 사용한다.
				textures[key] = texture

func draw(canvas: CanvasItem, key: String, rect: Rect2, tint := Color.WHITE) -> void:
	if textures.has(key): canvas.draw_texture_rect(textures[key],rect,false,tint)

func draw_nine_patch(canvas: CanvasItem, key: String, rect: Rect2, margin: float, tint := Color.WHITE) -> void:
	if not textures.has(key): return
	var style = StyleBoxTexture.new()
	style.texture = textures[key]
	style.modulate_color = tint
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	canvas.draw_style_box(style,rect)
