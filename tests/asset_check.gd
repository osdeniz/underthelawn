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
## Above this many pixels a texture must be VRAM compressed. Lossless costs
## w*h*4 bytes of VRAM; the restore layers alone were ~100 MB.
const COMPRESS_ABOVE := 256 * 256


func _ready() -> void:
	var files := _import_files("res://textures")
	ck("doku bulundu", files.size() > 20, "%d dosya" % files.size())

	var uncompressed: Array = []
	var no_mipmap: Array = []
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		var stem := path.get_file().trim_suffix(".import").get_basename()
		var source := path.trim_suffix(".import")
		var image := Image.new()
		if image.load(source) != OK:
			continue
		if image.get_width() * image.get_height() > COMPRESS_ABOVE \
				and not text.contains("compress/mode=2"):
			uncompressed.append("%s (%dx%d)" % [stem, image.get_width(),
				image.get_height()])
		if WORLD_TEXTURES.has(stem) and not text.contains("mipmaps/generate=true"):
			no_mipmap.append(stem)

	ck("buyuk dokular VRAM sikistirmali", uncompressed.is_empty(),
		", ".join(uncompressed))
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

	if _fails > 0:
		push_error("%d VARLIK TESTI BASARISIZ" % _fails)
		print("--- %d VARLIK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM VARLIK TESTLERI GECTI ---")
	get_tree().quit()


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
