extends Node
## G16.1: the world's sounds exist, load, and switch with the hour and the
## weather. Nothing here plays audio for a listener; it asks the players.

var _fails := 0


func _ready() -> void:
	# Every key in the table resolves to a file on disk.
	var missing: Array[String] = []
	for key: String in AudioDirector.PATHS:
		if not AudioDirector._streams.has(key):
			missing.append(key)
	ck("her ses anahtari yukleniyor", missing.is_empty(), ", ".join(missing))

	# The scene switches: night brings crickets, rain brings rain, and "" is off.
	AudioDirector.set_scene("night", false, false)
	ck("gece: cirlar caliyor", AudioDirector._night.playing, "")
	ck("gece kuru: yagmur yok", not AudioDirector._rain.playing, "")
	AudioDirector.set_scene("midday", true, false)
	ck("ogle yagmurlu: yagmur caliyor", AudioDirector._rain.playing, "")
	ck("ogle: cirlar sustu", not AudioDirector._night.playing, "")
	AudioDirector.set_scene("golden", false, true)
	ck("prolog: lamba ugulduyor", AudioDirector._lamp.playing, "")
	AudioDirector.set_scene("", false, false)
	ck("bahce terk edilince hepsi susuyor",
		not AudioDirector._rain.playing and not AudioDirector._night.playing
		and not AudioDirector._lamp.playing, "")

	# The bed follows the hour, and only changes when the class changes.
	ck("gunduz yatagi", AudioDirector.bed_for("morning") == "bed_day", AudioDirector.bed_for("morning"))
	ck("aksam yatagi", AudioDirector.bed_for("dusk") == "bed_evening", AudioDirector.bed_for("dusk"))
	AudioDirector.play_bed("morning")
	await get_tree().create_timer(0.3).timeout
	var first: String = AudioDirector._bed_key
	AudioDirector.play_bed("afternoon")
	ck("ayni sinifta yatak degismiyor", AudioDirector._bed_key == first, AudioDirector._bed_key)
	AudioDirector.play_bed("night")
	ck("gece yatak degisiyor", AudioDirector._bed_key == "bed_evening", AudioDirector._bed_key)
	AudioDirector.stop_bed()

	# One-shots never throw, with or without files.
	AudioDirector.step(false)
	AudioDirector.step(true)
	AudioDirector.play_food()
	AudioDirector.play_settler()
	AudioDirector.play_rabbit()
	AudioDirector.play_bird_takeoff()
	AudioDirector.play_dog_huff()
	AudioDirector.gust()
	var saved: Dictionary = AudioDirector._streams.duplicate()
	AudioDirector._streams.clear()
	AudioDirector.play_food()
	AudioDirector.step()
	AudioDirector.play_bed("night")
	AudioDirector._streams = saved
	ck("dosyasiz cagri sessiz, hatasiz", true, "")
	print("  [olcum] %d ses anahtari" % AudioDirector.PATHS.size())

	if _fails > 0:
		push_error("%d SES TESTI BASARISIZ" % _fails)
		print("--- %d SES TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM SES TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
