extends TestBase
## G24: the sand. A cut cell far behind the machine and open long enough goes
## back to cover; one near the machine does not; the yard still counts as
## finished by cells cut once; the pay reads what is open now; the tuft
## stands again.

func run() -> void:
	suite = "KUM"
	var game: Node = await open("ch18_long_road_home")
	var model: LawnModel = game.model
	ck("ch18 geri orten bahce", model.recovering and not game.variant.recover.is_empty())
	ck("palet SAND", GameConfig.active_grass_palette == "SAND", GameConfig.active_grass_palette)
	ck("HUD kum satiri", game.hud._case_line.text == tr("HUD_SAND_LINE"), game.hud._case_line.text)
	var here := LawnModel.cell_at(game.mower.position)
	var far := Vector2i(here.x, maxi(here.y - 9, 1))
	var near := Vector2i(here.x, maxi(here.y - 2, 1))
	while not model.is_mowable(far.x, far.y):
		far.x += 1
	while not model.is_mowable(near.x, near.y):
		near.x += 1
	model.mow(far.x, far.y, 0)
	model.mow(near.x, near.y, 0)
	await frames(2)
	var ratio_before := model.completion_ratio()
	var now_before := model.cut_now_ratio()
	ck("iki hucre acik", model.is_cut(far.x, far.y) and model.is_cut(near.x, near.y))
	# Age both cuts past the wind's patience; only the far one may go.
	for key: int in game._cut_at.keys():
		game._cut_at[key] = Time.get_ticks_msec() - 60000
	game._recover_clock = 10.0
	game._tick_recover(0.6)
	await frames(2)
	ck("uzaktaki hucre yeniden ortuldu", not model.is_cut(far.x, far.y))
	ck("yakindaki hucre acik kaldi", model.is_cut(near.x, near.y))
	ck("tamamlanma orani dusmedi (bir kez acildi sayilir)",
		is_equal_approx(model.completion_ratio(), ratio_before),
		"%.4f -> %.4f" % [ratio_before, model.completion_ratio()])
	ck("su an acik orani dustu (odeme bunu okur)", model.cut_now_ratio() < now_before,
		"%.4f -> %.4f" % [now_before, model.cut_now_ratio()])
	var tufts: TuftField = game.lawn.tuft_field
	var i := LawnModel.index_of(far.x, far.y)
	var slot: int = tufts._cell_slot[i]
	var v: int = tufts._cell_variant[i]
	var scale := (tufts._meshes[v] as MultiMesh).get_instance_transform(slot).basis.get_scale().x
	ck("tutam yeniden ayakta", scale > 0.5, "%.2f" % scale)
	# An evidence cell, once open, stays open.
	if not model.secret_cells.is_empty():
		var s: Vector2i = model.secret_cells[0]
		model.mow(s.x, s.y, 0)
		ck("kanit hucresi geri ortulmez", not model.recover(s.x, s.y))
	print("  [olcum] kum: after=%s s, behind=%s hucre, tik basina %d" % [
		str(game.variant.recover.get("after")), str(game.variant.recover.get("behind")),
		GameConfig.SAND_RECOVER_PER_TICK])
	await close(game)
