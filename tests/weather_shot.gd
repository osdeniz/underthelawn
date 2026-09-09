extends TestBase
## G49: one wet yard three times — dry, the light gone flat with no drops yet,
## and the front fully over it.

func run() -> void:
	suite = "HAVA CEKIM"
	min_checks = 3
	Rain.hold = false
	var game := await open("ch02_neighbor")
	await settle(1.4)
	ck("bolum yagmurlu", Rain.is_wet(), "")
	await _shot(game, "out/weather_1_dry.png")
	game._search_seconds = GameConfig.RAIN_WAIT + GameConfig.RAIN_ARRIVE * 0.3
	game._tick_weather()
	await settle(0.5)
	ck("isik degisti, damla yok", not (game.find_child("Rain", true, false) as Rain).emitting, "")
	await _shot(game, "out/weather_2_coming.png")
	game._search_seconds = GameConfig.RAIN_WAIT + GameConfig.RAIN_ARRIVE + 2.0
	game._tick_weather()
	await settle(1.0)
	ck("tam yagmur", (game.find_child("Rain", true, false) as Rain).emitting, "")
	await _shot(game, "out/weather_3_rain.png")
	print("[cekim] out/weather_1_dry.png, _2_coming.png ve _3_rain.png yazildi")
	close(game)
	Rain.hold = true
	Rain.set_wetness(1.0)
	finish()


func _shot(game: Node, path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://" + path)
