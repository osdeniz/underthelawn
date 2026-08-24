extends Node
## Builds every chapter in turn and saves one screenshot each, so the variation
## system can be judged side by side. Run windowed (NOT headless — it reads the
## rendered viewport):
##
##   Godot --path . --resolution 585x1266 res://tools/ChapterPreviews.tscn
##
## Writes /tmp/chapter_<id>.png.

const SETTLE_FRAMES := 26
const MOW_FRACTION := 0.45


func _ready() -> void:
	for variant_id: String in LevelVariant.ids():
		await _shoot(variant_id)
	print("[Previews] bitti")
	get_tree().quit()


func _shoot(variant_id: String) -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.set("variant_id", variant_id)
	add_child(game)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	# Cut part of the lawn so both the tall grass and the mown stripes of this
	# palette are visible in one frame — that pair is what a palette IS.
	var model: LawnModel = game.model
	var rows := int(GameConfig.GRID_ROWS * MOW_FRACTION)
	for row in range(GameConfig.GRID_ROWS - rows, GameConfig.GRID_ROWS):
		for col in GameConfig.GRID_COLS:
			model.mow(col, row, (row / 2) % 4)
	game.lawn.tuft_field.refresh_all()
	# Looking north from the south edge: the yard AND whatever stands at the far
	# end (house or landmark) are both in frame, which is what a chapter's sense
	# of place actually comes from.
	# Standing at the NORTH end looking north: the camera follows the mower, so
	# parking it up here is what puts the house or landmark in frame together
	# with the yard, whatever the grid size is.
	game.mower.position = Vector3(0.0, 0.0, -GameConfig.HALF_Z + 3.0)
	game.mower.yaw = 0.0
	game.cam.set_preset(Vector3(13.0, 9.0, 7.0), 0.0)
	game.cam.snap_to_target()
	game.hud._clear_opening_title()
	for _i in 34:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/chapter_%s.png" % variant_id)
	print("[Previews] %s -> %s" % [variant_id, str(img.get_size())])
	game.queue_free()
	await get_tree().process_frame
