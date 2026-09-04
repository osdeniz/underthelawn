extends TestBase
## G19.1: salvage lies at ground level and stays hidden until the grass beside
## it is cut. The contract is checked cell by cell against the model, not by
## counting: every prop with no cut cell within one of it must be hidden, and
## every prop with one must be visible.

func run() -> void:
	suite = "HURDA"
	var game: Node = await open("ch01_aldridge")
	var field: ScrapField = game.scrap_field
	var model: LawnModel = game.model
	ck("bahcede hurda var", field._props.size() > 0, str(field._props.size()))
	ck("bahcede yiyecek var", field._food_props.size() > 0)
	_check_contract(field, model, "acilis")
	var hidden := 0
	for prop in field._props.values():
		if not prop.visible:
			hidden += 1
	ck("acilista hurdanin cogu gizli", hidden >= field._props.size() - 2,
		"%d/%d gizli" % [hidden, field._props.size()])

	# Pick a hidden prop and cut one cell beside it.
	var key := -1
	for k: int in field._props:
		if not (field._props[k] as SalvageProp).visible:
			key = k
			break
	ck("gizli bir hurda bulundu", key >= 0)
	if key >= 0:
		var col := key % GameConfig.GRID_COLS
		var row := key / GameConfig.GRID_COLS
		var n := Vector2i(col + 1, row) if model.is_mowable(col + 1, row) else Vector2i(col - 1, row)
		model.mow(n.x, n.y, 0)
		await frames(2)
		var prop: SalvageProp = field._props[key]
		ck("komsu kesilince hurda gorunur", prop.visible)
		ck("kendisi toplanmadi", field._props.has(key))
		await settle(0.6)
		ck("hurda yerde, havada degil",
			absf(prop.position.y - GameConfig.PROP_GROUND_Y) < 0.02, "%.2f" % prop.position.y)
		_check_contract(field, model, "komsu kesildi")
		# Then cut its own cell: pays out and goes.
		model.mow(col, row, 0)
		var value := field.take(col, row)
		ck("kesilen hucre hurda oder", value > 0, str(value))
		ck("prop kaldirildi", not field._props.has(key))
	# A prop cut before any neighbour still pays and is not stuck hidden.
	var other := -1
	for k2: int in field._props:
		if not (field._props[k2] as SalvageProp).visible:
			other = k2
			break
	if other >= 0:
		var c2 := other % GameConfig.GRID_COLS
		var r2 := other / GameConfig.GRID_COLS
		var prop2: SalvageProp = field._props[other]
		model.mow(c2, r2, 0)
		var v2 := field.take(c2, r2)
		ck("gizliyken kesilen de oder", v2 > 0)
		ck("gizliyken toplanan gorunur oldu (pop)", prop2.visible)
	print("  [olcum] hurda %d, yiyecek %d, yer seviyesi %.2f" % [
		field._points.size(), field._food.size(), GameConfig.PROP_GROUND_Y])
	await close(game)


func _check_contract(field: ScrapField, model: LawnModel, label: String) -> void:
	var wrong := 0
	for k: int in field._props:
		var col := k % GameConfig.GRID_COLS
		var row := k / GameConfig.GRID_COLS
		var near_cut := false
		for dz: int in [-1, 0, 1]:
			for dx: int in [-1, 0, 1]:
				if model.in_bounds(col + dx, row + dz) and model.is_cut(col + dx, row + dz):
					near_cut = true
		var prop: SalvageProp = field._props[k]
		if prop.visible != near_cut:
			wrong += 1
	ck("gizlilik sozlesmesi (%s)" % label, wrong == 0, "%d hucre yanlis" % wrong)
