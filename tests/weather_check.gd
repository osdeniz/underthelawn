extends TestBase
## Weather you can hear coming (G49): a wet chapter starts dry, the light goes
## before the drops do, thunder rolls on the way in, and a resumed yard is as
## wet as its clock says it is.

func run() -> void:
	suite = "HAVA"
	# Every other suite holds the weather full on so it is never measuring a
	# dry yard by accident; this is the one whose claim is the arrival.
	var kept_hold := Rain.hold
	Rain.hold = false

	# --- the weight itself
	Rain.set_wetness(0.0)
	ck("basta hicbir sey dusmuyor", is_equal_approx(Rain.fall_ratio(), 0.0),
		"%.2f" % Rain.fall_ratio())
	Rain.set_wetness(GameConfig.RAIN_FALL_AT * 0.9)
	ck("isik degisirken hala damla yok", is_equal_approx(Rain.fall_ratio(), 0.0),
		"%.2f" % Rain.fall_ratio())
	Rain.set_wetness(1.0)
	ck("tam gelince tam duser", is_equal_approx(Rain.fall_ratio(), 1.0),
		"%.2f" % Rain.fall_ratio())
	Rain.set_wetness(0.5 + GameConfig.RAIN_FALL_AT * 0.5)
	ck("arada kismen duser", Rain.fall_ratio() > 0.0 and Rain.fall_ratio() < 1.0,
		"%.2f" % Rain.fall_ratio())
	Rain.hold = true
	Rain.set_wetness(0.0)
	ck("tutulunca gelis atlanir", is_equal_approx(Rain.wetness, 1.0),
		"%.2f" % Rain.wetness)
	Rain.hold = false

	# --- a wet yard opens dry, and its sky is the dry sky
	var game := await open("ch02_neighbor")
	await settle(0.6)
	ck("bolum yagmurlu", Rain.is_wet(), "")
	ck("bahce kuru basliyor", Rain.wetness < 0.01, "%.2f" % Rain.wetness)
	var rain: Rain = game.find_child("Rain", true, false)
	ck("damlalar kapali", rain != null and not rain.emitting, "")
	var sun: DirectionalLight3D = game.find_child("Sun", true, false)
	var dry_energy := sun.light_energy
	ck("gunes tam gucunde",
		dry_energy > float(GameConfig.TIME_OF_DAY["morning"]["sun_energy"])
			* GameConfig.RAIN_SUN_ENERGY + 0.01,
		"%.2f" % dry_energy)

	# --- the front comes over: the light first, then the drops
	game._search_seconds = GameConfig.RAIN_WAIT + GameConfig.RAIN_ARRIVE * 0.2
	game._tick_weather()
	await frames(2)
	ck("once isik degisir", sun.light_energy < dry_energy - 0.005,
		"%.3f -> %.3f" % [dry_energy, sun.light_energy])
	ck("isik degisirken damla yok", not rain.emitting, "")
	ck("ilk gok gurultusu duyuldu", game._thunder_done.has(0), "")

	game._search_seconds = GameConfig.RAIN_WAIT + GameConfig.RAIN_ARRIVE * 0.75
	game._tick_weather()
	await frames(2)
	ck("sonra damlalar baslar", rain.emitting, "")
	ck("damlalar once soluk", rain._mat.albedo_color.a < GameConfig.RAIN_COLOUR.a - 0.01,
		"%.2f" % rain._mat.albedo_color.a)
	ck("ikinci gurultu de duyuldu", game._thunder_done.has(1), "")

	game._search_seconds = GameConfig.RAIN_WAIT + GameConfig.RAIN_ARRIVE + 5.0
	game._tick_weather()
	await frames(2)
	ck("sonunda tam yagmur", is_equal_approx(Rain.wetness, 1.0), "%.2f" % Rain.wetness)
	ck("damlalar tam gorunur",
		is_equal_approx(rain._mat.albedo_color.a, GameConfig.RAIN_COLOUR.a),
		"%.2f" % rain._mat.albedo_color.a)
	ck("gunes olculmus yagmur degerinde",
		absf(sun.light_energy - float(GameConfig.TIME_OF_DAY["morning"]["sun_energy"])
			* GameConfig.RAIN_SUN_ENERGY) < 0.02, "%.3f" % sun.light_energy)
	ck("gok gurultusu iki kez, daha fazla degil", game._thunder_done.size() == 2,
		str(game._thunder_done.size()))
	close(game)

	# --- a dry chapter gets none of it
	var dry := await open("ch01_aldridge")
	await settle(0.4)
	ck("kuru bolumde hava gelmez", not Rain.is_wet(), "")
	dry._search_seconds = GameConfig.RAIN_WAIT + GameConfig.RAIN_ARRIVE * 2.0
	dry._tick_weather()
	await frames(2)
	ck("kuru bolumde gurultu yok", dry._thunder_done.is_empty(), "")
	close(dry)

	# --- a resumed yard is already wet, because the clock says so
	var back := await open("ch02_neighbor")
	back._search_seconds = GameConfig.RAIN_WAIT + GameConfig.RAIN_ARRIVE + 60.0
	back._tick_weather()
	await frames(2)
	ck("devam edilen bahce zaten yagmurlu", is_equal_approx(Rain.wetness, 1.0),
		"%.2f" % Rain.wetness)
	close(back)

	Rain.hold = kept_hold
	Rain.set_wetness(1.0)
	finish()
