extends SceneTree
## Renders the project's icon.svg at 1024 and 512 for the store presets (G19.11).
## Run: godot --headless --path . -s tools/make_icon.gd
## A PLACEHOLDER until the artist's icon lands; it keeps every export from
## failing on an empty icon field.
func _init() -> void:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	for size: int in [1024, 512, 192]:
		var img := Image.new()
		var err := img.load_svg_from_string(svg, float(size) / 128.0)
		if err != OK:
			push_error("svg yuklenemedi: %d" % err)
			quit(1)
			return
		img.save_png("res://icon_%d.png" % size)
		print("[ikon] icon_%d.png yazildi (%dx%d)" % [size, img.get_width(), img.get_height()])
	quit()
