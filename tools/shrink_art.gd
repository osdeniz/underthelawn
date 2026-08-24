extends SceneTree
## Resizes the illustration sources down to what the game actually DISPLAYS, so
## neither the shipped PCK nor VRAM pays for pixels nobody sees. Run after adding
## or replacing art, then run the editor once to reimport.
##
## Masters are NOT kept in the repo: copy them somewhere outside res:// before
## running this, because it overwrites in place.
##
## Targets are derived, not guessed:
##   * full-screen art (intro, hub): the viewport is 1170x2532 and these are
##     drawn KEEP_ASPECT_COVERED. The sources are relatively wider than the
##     screen, so height is the binding dimension.
##   * intro only: the Ken Burns push to 1.06 needs that much headroom.
##   * portraits: the dialogue card is DIALOGUE_PORTRAIT_SIZE (430x764), so 2x
##     is already generous for a phone.

const VIEWPORT_H := 2532.0
const PORTRAIT_SCALE := 2.0
const JPEG_QUALITY := 0.88


func _initialize() -> void:
	var total_before := 0
	var total_after := 0
	for job in _jobs():
		var path: String = job["path"]
		var img := Image.new()
		if img.load(path) != OK:
			print("  %s okunamadi" % path)
			continue
		var before := _size_of(path)
		var target_h: int = int(job["height"])
		if img.get_height() <= target_h:
			print("  %-34s %s zaten kucuk - atlandi" % [
				path.get_file(), str(img.get_size())])
			total_before += before
			total_after += before
			continue
		var target_w := int(round(float(img.get_width()) * float(target_h)
			/ float(img.get_height())))
		var was := img.get_size()
		img.resize(target_w, target_h, Image.INTERPOLATE_LANCZOS)
		# Always write JPEG for photographic illustration: lossless PNG of a
		# painted image is many times larger for no visible gain. The extension
		# has to match the data or Godot's importer refuses it, so a .png source
		# is replaced by a .jpg and the old file removed.
		var out := path.get_basename() + ".jpg"
		var err := img.save_jpg(out, JPEG_QUALITY)
		if err != OK:
			print("  %s yazilamadi (%d)" % [out, err])
			continue
		if out != path:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path(path + ".import"))
		var after := _size_of(out)
		total_before += before
		total_after += after
		print("  %-34s %s -> %s   %d KB -> %d KB" % [out.get_file(),
			str(was), str(img.get_size()), before / 1024, after / 1024])
	print("  TOPLAM %d KB -> %d KB" % [total_before / 1024, total_after / 1024])
	quit()


## One entry per source file, with the height it is actually drawn at.
func _jobs() -> Array:
	var jobs: Array = []
	# Ken Burns pushes to 1.06, so the intro cards need that much extra.
	var intro_h := int(ceil(VIEWPORT_H * GameConfig.INTRO_KEN_BURNS_TO))
	for i in [1, 2, 3]:
		jobs.append({ "path": "res://textures/intro/intro_%d.jpg" % i,
			"height": intro_h })
	# The hub never zooms.
	jobs.append({ "path": "res://textures/hub/town_square.jpg",
		"height": int(VIEWPORT_H) })
	var portrait_h := int(ceil(GameConfig.DIALOGUE_PORTRAIT_SIZE.y
		* PORTRAIT_SCALE))
	for id in ["marshal", "sarah", "gus", "cole", "ellie", "stranger"]:
		for ext in ["png", "jpg"]:
			var path := "res://textures/portraits/%s.%s" % [id, ext]
			if FileAccess.file_exists(path):
				jobs.append({ "path": path, "height": portrait_h })
	return jobs


func _size_of(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var length := file.get_length()
	file.close()
	return int(length)
