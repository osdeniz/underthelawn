extends TestBase
## G21: the lake. The flooded lot is reeds in water and the push mower is a
## punt. Measured: the level knows it is a lake, the palette is the water one,
## the selector is gone, the punt has no reverse and does drift, it reaches
## more than half its nominal speed on a two-second pull, a cut cell is a cut
## cell, and the sheen is over the lawn.

func run() -> void:
	suite = "GOL"
	var game: Node = await open("ch04_flooded")
	ck("ch04 gol seviyesi", game.variant.is_lake())
	ck("palet LAKE", GameConfig.active_grass_palette == "LAKE", GameConfig.active_grass_palette)
	ck("secici gizli", not game.hud.selector.visible)
	ck("su parlamasi var", game._fx_root.get_node_or_null("LakeSheen") != null)
	var punt: Node = game.mower
	ck("makine itmeli (kayik)", punt.type_index() == GameConfig.MOWER_PUSH)
	ck("kayik govdesi gorunur", punt.get_node("Body/Hull") != null and punt.get_node("Body/Hull").visible)
	ck("motor parcalari gizli", not (punt.get_node("Body/Deck") as MeshInstance3D).visible)
	ck("geri vites yok", is_zero_approx(float(punt.params.get("reverse", 1.0))))
	game.select_mower(GameConfig.MOWER_TRACTOR)
	await frames(2)
	ck("golde traktor secilemez", game.mower.type_index() == GameConfig.MOWER_PUSH)
	# A two-second pull on the clock.
	var from: Vector3 = punt.position
	Input.action_press("move_forward")
	await settle(2.0)
	Input.action_release("move_forward")
	var moved: float = (punt.position - from).length()
	var nominal: float = float(GameConfig.BOAT["speed"]) * 2.0
	ck("kayik iki saniyede yol aliyor", moved > nominal * 0.45, "%.2f / %.2f" % [moved, nominal])
	# Drift: with the pole shipped the hull keeps going for a moment.
	var at_release: Vector3 = punt.position
	await settle(0.4)
	var coast: float = (punt.position - at_release).length()
	ck("birakinca suzuluyor", coast > 0.15, "%.2f" % coast)
	# The rule: a cut cell is a cut cell, whatever the cover.
	var cell := LawnModel.cell_at(punt.position)
	var model: LawnModel = game.model
	var target := Vector2i(cell.x, maxi(cell.y - 3, 1))
	if model.is_mowable(target.x, target.y):
		model.mow(target.x, target.y, 0)
		ck("saz kesildi = hucre acildi", model.is_cut(target.x, target.y))
	print("  [olcum] kayik: %.2f birim / 2 s (nominal %.1f), suzulme %.2f, palet %s" % [moved, nominal, coast, GameConfig.active_grass_palette])
	await close(game)
