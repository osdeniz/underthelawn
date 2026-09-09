class_name Postcard
extends RefCounted
## A postcard of the finished yard (G27, gamification sprint 1). The stripes
## the player just cut, photographed from above the moment the panel would
## cover them, mounted on parchment with the yard's name and the date, and
## kept in the Journal's album — one per yard, the newest cut replacing the
## last. Nothing is uploaded and no share sheet is opened: the album is the
## collection, and a plugin can add the sheet later (docs/DEVICE_TEST.md).

const DIR := "user://postcards"
## The photograph: 3:2, the card: the photograph plus its mount.
const PHOTO := Vector2i(1200, 800)
const CARD := Vector2i(1296, 1040)
const MOUNT := 48
## The "before" print, tucked into the finished photograph's bottom-left with
## a white edge of its own (G45): a card that shows only the after says the
## yard was tidy, and a card that shows both says the player did it. Kept
## small and in a corner so the album's thumbnails still read as one picture.
const INSET := Vector2i(376, 251)
const INSET_MARGIN := 26
const INSET_EDGE := 8
## From above the road edge, looking up the yard. The distance scales with the
## grid: a fixed camera framed ch06's 24×32 well and left ch01's 16×24 as a
## postage stamp in the middle of the print (measured — see `PostcardShot`).
## `CAM_DISTANCE_ROWS`/`_COLS` turn a half-extent into a camera distance so the
## longer side fills the 3:2 frame; `CAM_RISE` is how much of it is height.
const CAM_DISTANCE_ROWS := 2.1
const CAM_DISTANCE_COLS := 2.4
const CAM_RISE := 0.78
const CAM_FOV := 52.0


## Reads a viewport once it has actually drawn something, and gives up rather
## than waiting for ever (G45).
##
## The obvious `await RenderingServer.frame_post_draw` has two problems. It is
## never emitted when nothing is being drawn — a headless suite, or an app the
## OS has stopped drawing — and awaiting it there hangs the coroutine and
## leaks the viewport with it, which is not a test-only worry: a yard can open
## while the phone is putting the app to sleep. And connecting to it from a
## static function to bound the wait does not work at all: the lambda never
## fires (measured — seen=false after twenty frames in a window that was
## plainly drawing). So this polls the texture instead, and an undrawn
## viewport is a black one, which is the same test the card already had to
## make.
static func drawn_image(tree: SceneTree, vp: SubViewport, frames := 24) -> Image:
	for _i in frames:
		await tree.process_frame
		if not is_instance_valid(vp) or not vp.is_inside_tree():
			return null
		var tex := vp.get_texture()
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null or img.get_width() < 8:
			continue
		var probe := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		if probe.get_luminance() < 0.01 and img.get_pixel(8, 8).get_luminance() < 0.01:
			continue
		return img
	return null


static func path_for(variant_id: String) -> String:
	return "%s/%s.png" % [DIR, variant_id]


static func has(variant_id: String) -> bool:
	return FileAccess.file_exists(path_for(variant_id))


## Every saved card, newest first: [{id, path, modified}].
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		var path := "%s/%s" % [DIR, file]
		out.append({"id": file.trim_suffix(".png"), "path": path,
			"modified": FileAccess.get_modified_time(path)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["modified"]) > int(b["modified"]))
	return out


static func load_texture(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


## The yard's name as the card prints it: the chapter's name, or the field's.
static func title_for(variant_id: String) -> String:
	var entry := ChapterProgress.entry(variant_id)
	if not entry.is_empty():
		return TranslationServer.translate(str(entry.get("name", variant_id)))
	var i := GameConfig.HARVEST_VARIANTS.find(variant_id)
	if i >= 0 and i < GameConfig.HARVEST_NAMES.size():
		return TranslationServer.translate(GameConfig.HARVEST_NAMES[i])
	return variant_id


## Photograph, mount, save. Runs inside the scene (it needs its World3D and a
## few frames), returns the saved path or "" when the render produced nothing.
static func make(game: Node3D, variant_id: String, subtitle := "", stamp := "",
		before: Image = null) -> String:
	var photo := await capture_yard(game)
	if photo == null or not is_instance_valid(game):
		return ""
	var card := await compose(game, photo, title_for(variant_id), subtitle, stamp, before)
	if card == null:
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var path := path_for(variant_id)
	var err := card.save_png(path)
	if err != OK:
		push_warning("Postcard: could not save %s (error %d)" % [path, err])
		return ""
	return path


## The same photograph, shrunk to the inset's size and kept for the end of the
## yard (G45). Full size it would be four megabytes held for a whole session
## for the sake of a print the size of a stamp.
static func capture_before(game: Node3D) -> Image:
	var photo := await capture_yard(game)
	if photo == null:
		return null
	photo.resize(INSET.x, INSET.y, Image.INTERPOLATE_LANCZOS)
	return photo


## The yard from above, in the scene's own world: same light, same sky, same
## grass — a second camera in a viewport of its own, rendered once.
static func capture_yard(game: Node3D) -> Image:
	var vp := SubViewport.new()
	vp.size = PHOTO
	vp.own_world_3d = false
	vp.world_3d = game.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	game.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = CAM_FOV
	cam.current = true
	vp.add_child(cam)
	var d := maxf(GameConfig.HALF_Z * CAM_DISTANCE_ROWS, GameConfig.HALF_X * CAM_DISTANCE_COLS)
	cam.position = Vector3(0.0, d * CAM_RISE, GameConfig.HALF_Z * 0.25 + d * 0.55)
	cam.look_at(Vector3(0.0, 0.0, -GameConfig.HALF_Z * 0.1), Vector3.UP)
	# Two frames: the viewport needs one to exist and one to draw. The scene
	# may be torn down under us (a flow test closing the yard mid-await), so
	# the tree is asked of the engine and the viewport is checked after.
	var tree := Engine.get_main_loop() as SceneTree
	var img: Image = await drawn_image(tree, vp)
	if is_instance_valid(vp):
		vp.queue_free()
	return img


## The mount: parchment, a white photo border, the name, the town, the date
## and a stamp in the corner. Built as controls in a 2D viewport so the text
## is the game's own type, then read back as one image.
static func compose(host: Node, photo: Image, title: String, subtitle: String,
		stamp := "", before: Image = null) -> Image:
	var vp := SubViewport.new()
	vp.size = CARD
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	host.add_child(vp)
	var root := Control.new()
	root.size = Vector2(CARD)
	vp.add_child(root)

	var paper := TextureRect.new()
	paper.texture = MapArt.parchment(512, 2707)
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.size = Vector2(CARD)
	root.add_child(paper)

	# The white border a printed photograph has, and the photograph in it.
	var border := ColorRect.new()
	border.color = Color(0.97, 0.96, 0.92)
	border.position = Vector2(MOUNT - 12, MOUNT - 12)
	border.size = Vector2(PHOTO) + Vector2(24, 24)
	root.add_child(border)
	var shot := TextureRect.new()
	shot.texture = ImageTexture.create_from_image(photo)
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.position = Vector2(MOUNT, MOUNT)
	shot.size = Vector2(PHOTO)
	root.add_child(shot)

	# The "before" print, if the yard was photographed on the way in.
	if before != null and before.get_width() > 8:
		var inset_edge := ColorRect.new()
		inset_edge.color = Color(0.97, 0.96, 0.92)
		inset_edge.position = Vector2(MOUNT + INSET_MARGIN - INSET_EDGE,
			MOUNT + PHOTO.y - INSET_MARGIN - INSET.y - INSET_EDGE)
		inset_edge.size = Vector2(INSET) + Vector2.ONE * INSET_EDGE * 2.0
		root.add_child(inset_edge)
		var inset := TextureRect.new()
		inset.texture = ImageTexture.create_from_image(before)
		inset.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		inset.position = inset_edge.position + Vector2.ONE * INSET_EDGE
		inset.size = Vector2(INSET)
		root.add_child(inset)
		# Inside the little print, not under it: under it the word landed half
		# on the photograph's own white border and half off the card (seen in
		# out/postcard_ch01_aldridge.png).
		var mark := Label.new()
		mark.text = TranslationServer.translate("POSTCARD_BEFORE")
		mark.position = inset.position + Vector2(10.0, 4.0)
		mark.size = Vector2(INSET.x - 20, 40)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		mark.add_theme_font_size_override("font_size", 28)
		mark.add_theme_color_override("font_color", Color(0.97, 0.96, 0.92))
		mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		mark.add_theme_constant_override("shadow_offset_y", 2)
		root.add_child(mark)

	var ink := Color(0.22, 0.16, 0.10)
	var name_label := Label.new()
	name_label.text = title
	name_label.position = Vector2(MOUNT, MOUNT + PHOTO.y + 26)
	name_label.size = Vector2(PHOTO.x - 260, 80)
	name_label.add_theme_font_size_override("font_size", 58)
	name_label.add_theme_color_override("font_color", ink)
	root.add_child(name_label)

	var where := Label.new()
	var town := TranslationServer.translate("POSTCARD_TOWN")
	var date := Time.get_date_string_from_system()
	where.text = "%s · %s" % [town, date] if subtitle == "" \
		else "%s · %s · %s" % [town, subtitle, date]
	where.position = Vector2(MOUNT, MOUNT + PHOTO.y + 100)
	where.size = Vector2(PHOTO.x - 260, 60)
	where.add_theme_font_size_override("font_size", 34)
	where.add_theme_color_override("font_color", ink.lightened(0.25))
	root.add_child(where)

	# The stamp: a square of the case accent on a lighter mount, and a word
	# inside — SEARCHED, or the mowing pattern when there was one (G28).
	var stamp_box := Control.new()
	stamp_box.position = Vector2(CARD.x - MOUNT - 190, MOUNT + PHOTO.y + 22)
	stamp_box.size = Vector2(190, 150)
	root.add_child(stamp_box)
	var stamp_bg := ColorRect.new()
	stamp_bg.color = Color(0.97, 0.96, 0.92)
	stamp_bg.size = stamp_box.size
	stamp_box.add_child(stamp_bg)
	var stamp_in := ColorRect.new()
	stamp_in.color = GameConfig.CASE_ACCENT.darkened(0.15)
	stamp_in.position = Vector2(10, 10)
	stamp_in.size = stamp_box.size - Vector2(20, 20)
	stamp_box.add_child(stamp_in)
	var stamp_text := Label.new()
	stamp_text.text = stamp if stamp != "" else TranslationServer.translate("POSTCARD_STAMP")
	stamp_text.size = stamp_box.size
	stamp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stamp_text.add_theme_font_size_override("font_size", 30)
	stamp_text.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	stamp_box.add_child(stamp_text)

	var tree := Engine.get_main_loop() as SceneTree
	var img: Image = await drawn_image(tree, vp)
	if is_instance_valid(vp):
		vp.queue_free()
	return img
