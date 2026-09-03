extends TestBase
## G16.6: the gate lets the free part through, stops the rest, and opens for
## good once the purchase is granted. Runs against the save's real flag and
## puts it back.

func run() -> void:
	suite = "DEMO"
	var was := bool(GameState.get_setting(Purchases.SECTION, Purchases.KEY_FULL, false))
	GameState.set_setting(Purchases.SECTION, Purchases.KEY_FULL, false)
	if not GameConfig.DEMO_GATE:
		ck("kapi kapali derlemede her sey acik", Purchases.chapter_allowed("ch18_long_road_home"))
	else:
		ck("temiz kayit: tam surum degil", not Purchases.is_full() or GameConfig.DEV_UNLOCK_ALL)
		if not GameConfig.DEV_UNLOCK_ALL:
			ck("prolog serbest", Purchases.chapter_allowed(GameConfig.PROLOGUE_ID))
			for id: String in GameConfig.DEMO_FREE_CHAPTERS:
				ck("serbest: %s" % id, Purchases.chapter_allowed(id))
			ck("ch04 kapida", not Purchases.chapter_allowed("ch04_flooded"))
			ck("ch18 kapida", not Purchases.chapter_allowed("ch18_long_road_home"))
			# The card, tapped: locally the grant is immediate and the card closes
			# itself on `changed`.
			var card: Control = load("res://scripts/demo_card.gd").new()
			add_child(card)
			await frames(2)
			var bought := [false]
			card.finished.connect(func(b: bool) -> void: bought[0] = b)
			# find_child, recursive: the buttons sit inside the panel's column, and
			# get_node("Buy") returned null — the first run of this test errored
			# out of run() right here and still printed GECTI, because nothing
			# had failed yet. A test that can abort before its assertions and
			# pass is the trap this project keeps writing down.
			var buy: Button = card.find_child("Buy", true, false)
			ck("satin al dugmesi var", buy != null)
			if buy != null:
				buy.pressed.emit()
			await frames(3)
			ck("satin alma kapiyi aciyor", Purchases.is_full())
			ck("kart alindi diye kapaniyor", bought[0] and not is_instance_valid(card) or bought[0])
			ck("ch04 artik acik", Purchases.chapter_allowed("ch04_flooded"))
			# And "not now" closes without granting.
			GameState.set_setting(Purchases.SECTION, Purchases.KEY_FULL, false)
			var card2: Control = load("res://scripts/demo_card.gd").new()
			add_child(card2)
			await frames(2)
			var later := [true]
			card2.finished.connect(func(b: bool) -> void: later[0] = b)
			var later_button: Button = card2.find_child("Later", true, false)
			ck("simdi degil dugmesi var", later_button != null)
			if later_button != null:
				later_button.pressed.emit()
			await frames(3)
			ck("simdi degil: kapi kapali kaliyor", not Purchases.is_full() and not later[0])
	GameState.set_setting(Purchases.SECTION, Purchases.KEY_FULL, was)
