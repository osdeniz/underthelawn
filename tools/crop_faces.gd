extends SceneTree
## Generates square face thumbnails from the 9:16 character illustrations, so the
## town list can show a face while the dialogue box shows the full figure. Run
## after changing art or GameConfig.PORTRAIT_FACES, then run the editor once so
## Godot imports the new files:
##
##   Godot --headless --path . --script res://tools/crop_faces.gd
##   Godot --headless --editor --quit --path .

const OUT_DIR := "res://textures/portraits/"


func _initialize() -> void:
	var sheet_width := 0
	var images: Array[Image] = []
	for id: String in GameConfig.PORTRAIT_FACES:
		var tex := TextureLibrary.find("portraits/" + id)
		if tex == null:
			print("  %-9s kaynak yok - atlandi" % id)
			continue
		var src := tex.get_image()
		src.decompress()
		src.convert(Image.FORMAT_RGB8)
		var face: Dictionary = GameConfig.PORTRAIT_FACES[id]
		# The crop is square in PIXELS, sized off the shorter edge, so a face
		# never comes out stretched whatever the source aspect is.
		var edge := int(minf(src.get_width(), src.get_height()) * float(face["size"]))
		edge = maxi(edge, 16)
		var cx := int(src.get_width() * float(face["x"]))
		var cy := int(src.get_height() * float(face["y"]))
		var x := clampi(cx - edge / 2, 0, maxi(src.get_width() - edge, 0))
		var y := clampi(cy - edge / 2, 0, maxi(src.get_height() - edge, 0))
		var crop := src.get_region(Rect2i(x, y, edge, edge))
		crop.resize(GameConfig.PORTRAIT_FACE_PX, GameConfig.PORTRAIT_FACE_PX,
			Image.INTERPOLATE_LANCZOS)
		var path := OUT_DIR + "face_" + id + ".png"
		var err := crop.save_png(path)
		print("  face_%s.png %s -> %s" % [id, str(Rect2i(x, y, edge, edge)),
			"ok" if err == OK else "HATA %d" % err])
		images.append(crop)
		sheet_width += GameConfig.PORTRAIT_FACE_PX

	# One contact sheet, so the crops can be judged at a glance.
	if not images.is_empty():
		var sheet := Image.create(sheet_width, GameConfig.PORTRAIT_FACE_PX,
			false, Image.FORMAT_RGB8)
		var i := 0
		for img in images:
			sheet.blit_rect(img,
				Rect2i(0, 0, GameConfig.PORTRAIT_FACE_PX, GameConfig.PORTRAIT_FACE_PX),
				Vector2i(i * GameConfig.PORTRAIT_FACE_PX, 0))
			i += 1
		sheet.save_png("/tmp/faces_sheet.png")
		print("  kontrol sayfasi: /tmp/faces_sheet.png")
	quit()
