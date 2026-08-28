extends Node
## G14.2: the asset rules that were broken once and must not drift back.
##
## Every one of these was a real finding on a real audit, not a hypothetical.

var _fails := 0
## Textures sampled in 3D. Without mipmaps the GPU reads full resolution at
## every pixel however far the surface is: it shimmers AND wastes bandwidth.
const WORLD_TEXTURES := ["grass_albedo", "grass_normal", "dirt_albedo",
	"asphalt_albedo", "siding_albedo", "roof_shingles_albedo", "wood_albedo",
	"bark_albedo"]
## Photographic art — faces, story cards, the maps — stays LOSSLESS: VRAM
## compression shows on skin and on smooth gradients before anywhere else, and
## that is most of what these pictures are. They pay for it by being no larger
## than they are drawn, which is the cheaper half of the same trade.
const SCREEN_LONGEST := 2100
## Tiling world textures are a different case: compression is invisible on them
## and they are sampled constantly, so they must be compressed.
const WORLD_MUST_COMPRESS := true


func _ready() -> void:
	var files := _import_files("res://textures")
	ck("doku bulundu", files.size() > 20, "%d dosya" % files.size())

	var uncompressed: Array = []
	var oversize: Array = []
	var no_mipmap: Array = []
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		var stem := path.get_file().trim_suffix(".import").get_basename()
		var source := path.trim_suffix(".import")
		var image := Image.new()
		if image.load(source) != OK:
			continue
		var longest := maxi(image.get_width(), image.get_height())
		# A picture larger than it is ever drawn is VRAM spent on pixels nobody
		# sees — the story cards were 1536x2752 on a 1170-wide screen.
		if longest > SCREEN_LONGEST:
			oversize.append("%s (%dx%d)" % [stem, image.get_width(),
				image.get_height()])
		if WORLD_TEXTURES.has(stem) and not text.contains("compress/mode=2"):
			uncompressed.append(stem)
		if WORLD_TEXTURES.has(stem) and not text.contains("mipmaps/generate=true"):
			no_mipmap.append(stem)

	ck("3B dokular VRAM sikistirmali", uncompressed.is_empty(),
		", ".join(uncompressed))
	ck("hicbir gorsel ekrandan buyuk degil", oversize.is_empty(),
		", ".join(oversize))
	ck("3B dokularda mipmap var", no_mipmap.is_empty(), ", ".join(no_mipmap))

	# The same picture in two formats ships both and only the first is ever
	# loaded — TextureLibrary tries .png before .jpg.
	var stems: Dictionary = {}
	var twins: Array = []
	for path: String in files:
		var source := path.trim_suffix(".import")
		var key := source.get_basename()
		if stems.has(key):
			twins.append(key.get_file())
		stems[key] = true
	ck("ayni isimde iki format yok", twins.is_empty(), ", ".join(twins))

	# Orphans are REPORTED, not failed: some files are legitimately loaded by a
	# name the code builds at runtime ("portraits/face_" + id), and a few are
	# kept on purpose. A list is what is wanted here, not a veto (G13.8).
	var sources := _all_source_text()
	var orphans: Array = []
	for path: String in files:
		var stem := path.get_file().trim_suffix(".import").get_basename()
		if sources.contains(stem):
			continue
		orphans.append(stem)
	if orphans.is_empty():
		print("  [orphan] referanssiz doku yok")
	else:
		print("  [orphan] %d doku hicbir yerde adiyla gecmiyor:" % orphans.size())
		for name: String in orphans:
			print("      %s" % name)

	if _fails > 0:
		push_error("%d VARLIK TESTI BASARISIZ" % _fails)
		print("--- %d VARLIK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM VARLIK TESTLERI GECTI ---")
	get_tree().quit()


## Every script, scene and data file, concatenated — what a texture name would
## have to appear in somewhere to be reachable.
func _all_source_text() -> String:
	var text := ""
	for dir_path: String in ["res://scripts", "res://data", "res://scenes",
			"res://ui", "res://tests", "res://i18n"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir():
				text += FileAccess.get_file_as_string(dir_path.path_join(name))
			name = dir.get_next()
		dir.list_dir_end()
	return text


func _import_files(dir_path: String) -> Array:
	var found: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			found.append_array(_import_files(full))
		elif name.ends_with(".import"):
			found.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return found


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
