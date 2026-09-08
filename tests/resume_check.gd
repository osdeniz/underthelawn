extends TestBase
## The yard you were in the middle of (G42): a run used to live only in memory,
## so a phone call threw away every cut. Now it is written down and put back.

func run() -> void:
	suite = "DEVAM"
	YardSave.clear()
	ck("basta devam edilecek bahce yok", not YardSave.has_snapshot(), "")

	var game := await open("ch01_aldridge")
	await settle(0.5)
	# Cut a third of the yard, bank something, move the machine.
	var cut := 0
	for row in GameConfig.GRID_ROWS / 3:
		for col in GameConfig.GRID_COLS:
			if game.model.is_mowable(col, row) and not game.model.is_cut(col, row):
				game.model.mow(col, row, 1)
				cut += 1
	game.mower.position = Vector3(1.5, game.mower.position.y, -2.5)
	game.mower.yaw = 0.8
	await frames(2)
	# Set with no frame in between: the cutting above uncovers salvage, and a
	# frame of picking it up moves the counter under the test's feet.
	game._scrap_banked = 7
	game._food_banked = 2

	var snap: Dictionary = game.snapshot()
	ck("anlik goruntu bu bahceyi adiyla soyler", str(snap.get("variant", "")) == "ch01_aldridge",
		str(snap.get("variant", "")))
	ck("izgara olcusu yazili",
		int(snap.get("cols", 0)) == GameConfig.GRID_COLS
		and int(snap.get("rows", 0)) == GameConfig.GRID_ROWS, "")
	ck("kesim haritasi tasiniyor", str(snap.get("states", "")).length() > 100,
		str(str(snap.get("states", "")).length()))
	ck("gomuler tasiniyor",
		(snap.get("secrets", []) as Array).size() == game.model.secret_cells.size() * 2,
		str((snap.get("secrets", []) as Array).size()))
	ck("hurda ve yiyecek tasiniyor",
		int(snap.get("scrap", 0)) == 7 and int(snap.get("food", 0)) == 2, "")
	var mowed: int = game.model.mowed_count
	var secrets: Array = game.model.secret_cells.duplicate()
	close(game)

	# It survives a round trip through the save file.
	YardSave.store(snap)
	ck("kayda yazilir", YardSave.has_snapshot(), "")
	ck("hangi bahce oldugunu bilir", YardSave.variant_id() == "ch01_aldridge",
		YardSave.variant_id())
	var loaded: Dictionary = YardSave.load_snapshot()
	ck("geri okunur", not loaded.is_empty(), "")

	# A fresh scene of the same chapter takes it back.
	var again := await open("ch01_aldridge")
	await settle(0.5)
	ck("yeni sahne bos basliyor", again.model.mowed_count < mowed,
		"%d < %d" % [again.model.mowed_count, mowed])
	ck("anlik goruntu uygulanir", again.restore_snapshot(loaded), "")
	ck("kesim geri geldi", again.model.mowed_count == mowed,
		"%d / %d" % [again.model.mowed_count, mowed])
	ck("sayaclar yeniden kuruldu",
		again.model.mowable_cells > 0 and again.model.completion_ratio() > 0.1,
		"%.2f" % again.model.completion_ratio())
	var same := true
	for i in secrets.size():
		if again.model.secret_cells[i] != secrets[i]:
			same = false
	ck("gomuler ayni hucrelerde", same and again.model.secret_cells.size() == secrets.size(), "")
	ck("hurda geri geldi", again._scrap_banked == 7 and again._food_banked == 2, "")
	ck("saat kaldigi yerden", GameState.elapsed > 0.0, "%.2f" % GameState.elapsed)
	ck("makine yerine kondu",
		absf(again.mower.position.x - 1.5) < 0.35 and absf(again.mower.yaw - 0.8) < 0.05,
		"%.2f / %.2f" % [again.mower.position.x, again.mower.yaw])
	ck("ilerleme cubugu de biliyor", again.hud._target_percent > 10.0,
		"%.1f" % again.hud._target_percent)

	# What it refuses.
	var wrong := loaded.duplicate(true)
	wrong["variant"] = "ch03_playground"
	ck("baska bahcenin kaydini almaz", not again.restore_snapshot(wrong), "")
	var bad_grid := loaded.duplicate(true)
	bad_grid["cols"] = 999
	ck("baska olcunun kaydini almaz", not again.restore_snapshot(bad_grid), "")
	var truncated := loaded.duplicate(true)
	truncated["states"] = "AAAA"
	ck("bozuk haritayi almaz", not again.restore_snapshot(truncated), "")

	# Finishing clears it, and so does walking out.
	again._restart()
	ck("yeniden baslamak kaydi siler", not YardSave.has_snapshot(), "")

	# The timer writes it down on its own. The suites keep this off (a
	# snapshot left behind would resume a yard nobody asked for), so this is
	# the one check that turns it on.
	OS.set_environment("UTL_NO_BG_PAUSE", "")
	again._save_due = 0.05
	await settle(0.5)
	OS.set_environment("UTL_NO_BG_PAUSE", "1")
	ck("acik bahce kendini yazar", YardSave.has_snapshot(), "")
	close(again)
	YardSave.clear()
	ck("temiz birakildi", not YardSave.has_snapshot(), "")
	finish()
