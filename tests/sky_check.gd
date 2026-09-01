extends Node
## G14.2: the eight chapters are one day, and every hour of it stays playable.

const ORDER := ["dawn", "morning", "midday", "afternoon", "golden", "sunset",
	"dusk", "night"]
const CHAPTERS := ["ch01_aldridge", "ch02_neighbor", "ch03_playground",
	"ch04_flooded", "ch05_greenhouse", "ch06_watertower", "ch07_mill",
	"ch08_cellar"]

var _fails := 0


func _ready() -> void:
	var keys := ["elev", "azim", "sun", "sun_energy", "sky_top", "sky_horizon",
		"ground", "ambient", "ambient_energy", "fog"]
	for id: String in GameConfig.TIME_OF_DAY:
		var spec: Dictionary = GameConfig.TIME_OF_DAY[id]
		for key: String in keys:
			ck("%s icinde %s var" % [id, key], spec.has(key), "")
		# The lesson from the first pass: a low sun must be paid for with
		# ambient, not with darkness. Under this floor the tall grass and the
		# cut stripe stop being telling apart.
		ck("%s oynanabilir kaliyor" % id,
			float(spec.get("ambient_energy", 0.0)) >= 0.40,
			str(spec.get("ambient_energy", 0.0)))
		# The floor is about flat lighting, not darkness — that is what
		# ambient_energy above guards. The switch's own sunset deliberately
		# sits at 9 degrees: the long raking shadow is the whole effect.
		ck("%s gunes acisi ufkun uzerinde" % id,
			float(spec.get("elev", 0.0)) >= 8.0, str(spec.get("elev", 0.0)))
	# Every hour of the day exists. Presets that are NOT part of the day (the
	# light switch's own sunset) are allowed and checked above like the rest.
	for id: String in ORDER:
		ck("gunun saati tanimli: %s" % id, GameConfig.TIME_OF_DAY.has(id), id)

	# The day only runs forwards.
	var clock := -1
	var used := {}
	for id: String in CHAPTERS:
		var variant := LevelVariant.of(id)
		var at := ORDER.find(variant.time_of_day)
		ck("%s saati tanimli: %s" % [id, variant.time_of_day], at >= 0,
			variant.time_of_day)
		ck("%s gun geri sarmiyor" % id, at >= clock,
			"%s < %s" % [variant.time_of_day, ORDER[maxi(clock, 0)]])
		clock = maxi(clock, at)
		used[variant.time_of_day] = true
	ck("gun sabah baslar", LevelVariant.of(CHAPTERS[0]).time_of_day == "dawn",
		LevelVariant.of(CHAPTERS[0]).time_of_day)
	ck("gun gece biter",
		LevelVariant.of(CHAPTERS[7]).time_of_day == "night",
		LevelVariant.of(CHAPTERS[7]).time_of_day)
	# Four hours or more, or the day reads as one flat afternoon.
	ck("gun gercekten geciyor", used.size() >= 4, "%d saat" % used.size())

	# An unknown hour must fall back rather than leave the scene unlit.
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var sun: DirectionalLight3D = game.get_node("Sun")
	SkyTime.apply(game.get_node("WorldEnvironment") as WorldEnvironment,
		sun, "hicboyle_saat_yok")
	var noon: Dictionary = GameConfig.TIME_OF_DAY[GameConfig.TIME_OF_DAY_DEFAULT]
	ck("bilinmeyen saat ogleye duser",
		is_equal_approx(sun.light_energy, float(noon["sun_energy"])),
		str(sun.light_energy))
	game.queue_free()

	if _fails > 0:
		push_error("%d GOKYUZU TESTI BASARISIZ" % _fails)
		print("--- %d GOKYUZU TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM GOKYUZU TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
