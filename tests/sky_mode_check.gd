extends Node
## G14.3: the light switch. Three modes, one of which changes nothing.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)

	# --- the modes themselves
	ck("varsayilan oto", SkyTime.mode() == GameConfig.SKY_MODE_AUTO,
		SkyTime.mode())
	ck("oto bolumun saatini birakir",
		SkyTime.resolve("dawn") == "dawn", SkyTime.resolve("dawn"))
	var dusk_preset := str(GameConfig.SKY_MODE_PRESET[GameConfig.SKY_MODE_DUSK])
	var day_preset := str(GameConfig.SKY_MODE_PRESET[GameConfig.SKY_MODE_DAY])
	SkyTime.set_mode(GameConfig.SKY_MODE_DUSK)
	ck("gun batimi her saati ezer",
		SkyTime.resolve("dawn") == dusk_preset
		and SkyTime.resolve("midday") == dusk_preset,
		SkyTime.resolve("dawn"))
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	ck("gunduz her saati ezer",
		SkyTime.resolve("dusk") == day_preset, SkyTime.resolve("dusk"))
	# Cycling has to come back round, or the button is a one-way door.
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	var seen := {}
	for _i in GameConfig.SKY_MODES.size():
		seen[SkyTime.mode()] = true
		SkyTime.set_mode(SkyTime.next_mode())
	ck("dongu her modu geziyor", seen.size() == GameConfig.SKY_MODES.size(),
		"%d mod" % seen.size())
	ck("dongu basa doner", SkyTime.mode() == GameConfig.SKY_MODE_AUTO,
		SkyTime.mode())
	# A garbage value in the save must not leave the world unlit.
	GameState.set_setting(SkyTime.SECTION, SkyTime.KEY, "gece_yarisi")
	ck("bilinmeyen mod otoya duser",
		SkyTime.mode() == GameConfig.SKY_MODE_AUTO, SkyTime.mode())
	# There is no night: every mode a player can pick stays playable.
	for id: String in GameConfig.SKY_MODE_PRESET.values():
		var preset: Dictionary = GameConfig.TIME_OF_DAY[id]
		ck("%s oynanabilir" % id,
			float(preset["ambient_energy"]) >= 0.40, str(preset["ambient_energy"]))

	# --- it actually reaches the scene
	SkyTime.set_mode(GameConfig.SKY_MODE_DUSK)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 12:
		await get_tree().process_frame
	var sun: DirectionalLight3D = game.get_node("Sun")
	var dusk: Dictionary = GameConfig.TIME_OF_DAY[
		str(GameConfig.SKY_MODE_PRESET[GameConfig.SKY_MODE_DUSK])]
	ck("gun batimi bahceye ulasti",
		is_equal_approx(sun.rotation_degrees.x, -float(dusk["elev"])),
		"%.1f" % sun.rotation_degrees.x)
	ck("dugme barda",
		game.hud.find_children("SkyButton", "", true, false).size() == 1, "")
	# Switching relights without a reload.
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	game.hud.refresh_sky()
	await get_tree().process_frame
	var noon: Dictionary = GameConfig.TIME_OF_DAY[
		str(GameConfig.SKY_MODE_PRESET[GameConfig.SKY_MODE_DAY])]
	ck("aninda yeniden isiklaniyor",
		is_equal_approx(sun.rotation_degrees.x, -float(noon["elev"])),
		"%.1f" % sun.rotation_degrees.x)
	game.queue_free()

	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	if _fails > 0:
		push_error("%d ISIK TESTI BASARISIZ" % _fails)
		print("--- %d ISIK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM ISIK TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
