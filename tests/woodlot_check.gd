extends TestBase
## G25: the woodlot. A harvest that pays timber: one lot per cut, the next
## restoration bought is TIMBER_DISCOUNT cheaper and spends the lot; the sheet
## says what the field is for; the HUD names the work.

func run() -> void:
	suite = "KORU"
	RestoreBoard.reset()
	Settlers.reset()
	var v := LevelVariant.of("harvest_woodlot")
	ck("koru bir hasat", v.is_harvest() and v.pays_timber)
	ck("rotasyonda", GameConfig.HARVEST_VARIANTS.has("harvest_woodlot")
		and GameConfig.HARVEST_NAMES.size() == GameConfig.HARVEST_VARIANTS.size())
	var pid := str((RestoreBoard.projects()[0] as Dictionary).get("id", ""))
	var full := RestoreBoard.price(pid)
	RestoreBoard.add_timber(1)
	var cheaper := RestoreBoard.price(pid)
	ck("kereste fiyati dusuruyor", cheaper < full, "%d -> %d" % [full, cheaper])
	ck("indirim orani dogru", absf(float(full - cheaper) / maxf(float(full), 1.0) - GameConfig.TIMBER_DISCOUNT) < 0.02,
		"%.2f" % (float(full - cheaper) / maxf(float(full), 1.0)))
	GameState.add_scrap(full * 2)
	ck("satin alma keresteyi harcar", RestoreBoard.buy(pid) and RestoreBoard.timber() == 0, str(RestoreBoard.timber()))
	var map := TownMap.new()
	add_child(map)
	await frames(1)
	ck("ciftlik sayfasi kereste diyor", map._field_note("harvest_woodlot").find(tr("HARVEST_PAYS_TIMBER")) >= 0,
		map._field_note("harvest_woodlot"))
	map.queue_free()
	var game: Node = await open("harvest_woodlot")
	ck("HUD koru satiri", game.hud._case_line.text == tr("HUD_WOODLOT_LINE"), game.hud._case_line.text)
	ck("palet WOODLOT", GameConfig.active_grass_palette == "WOODLOT")
	ck("govdeler engel", game.model.collision_rects.size() >= 5, str(game.model.collision_rects.size()))
	print("  [olcum] koru: fiyat %d -> %d, kereste indirimi %.0f%%" % [full, cheaper, GameConfig.TIMBER_DISCOUNT * 100.0])
	await close(game)
	RestoreBoard.reset()
