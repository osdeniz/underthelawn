extends Node
## G10.1: evidence is a world object you drive over, not a tap target.
##
## Tap-collection was removed because it fought the drag pad for the same touch
## — the "sometimes it doesn't pick up" bug. These assertions pin the new rule.

var _fails := 0


func _ready() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var model: LawnModel = game.model

	# Mowing a secret cell must reveal a real prop in the world.
	ck("baslangicta kanit propu yok", game._evidence_props.is_empty(), "")
	var cell: Vector2i = model.secret_cells[0]
	model.mow(cell.x, cell.y, 0)
	await get_tree().process_frame
	ck("bicince kanit propu belirdi", game._evidence_props.size() == 1,
		str(game._evidence_props.size()))

	# Standing far away collects nothing.
	game.mower.position = Vector3(0.0, 0.0, GameConfig.HALF_Z - 1.0)
	await get_tree().physics_frame
	await get_tree().process_frame
	ck("uzaktayken toplanmiyor", game._evidence_props.size() == 1,
		str(game._evidence_props.size()))

	# Driving onto it collects it, with no tap involved.
	var at := LawnModel.cell_center(cell.x, cell.y)
	game.mower.position = at
	await get_tree().process_frame
	await get_tree().process_frame
	ck("ustune gelince toplandi", game._evidence_props.is_empty(),
		str(game._evidence_props.size()))
	ck("kanit sayildi", game._collected.size() == 1, str(game._collected.size()))
	ck("sirt yigininda kanit var", game.carry != null and game.carry._items.size() == 1,
		str(game.carry._items.size() if game.carry else -1))

	# The reach is generous but not unlimited: a piece one cell diagonally away
	# must still count, because "I drove over it" and "it counted" have to agree.
	var second: Vector2i = model.secret_cells[1]
	model.mow(second.x, second.y, 0)
	await get_tree().process_frame
	var near := LawnModel.cell_center(second.x, second.y) \
		+ Vector3(game.mower.deck_radius() * 0.9, 0.0, 0.0)
	game.mower.position = near
	await get_tree().process_frame
	await get_tree().process_frame
	ck("deck kenarindan da toplaniyor", game._evidence_props.is_empty(),
		str(game._evidence_props.size()))

	# Money rides the stack too.
	var before: int = game.carry._bills.size()
	var money_cells: Array = game.scrap_field.cells()
	if money_cells.size() > 0:
		var mc: Vector2i = money_cells[0]
		var value: int = game.scrap_field.take(mc.x, mc.y)
		game._on_scrap_found(mc.x, mc.y, value)
		ck("para sirta bindi", game.carry._bills.size() == before + 1,
			str(game.carry._bills.size()))

	game.queue_free()
	if _fails > 0:
		push_error("%d TOPLAMA TESTI BASARISIZ" % _fails)
		print("--- %d TOPLAMA TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM TOPLAMA TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
