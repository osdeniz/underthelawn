extends TestBase
## The settings row and the bar button must drive the SAME setting; the two
## level sliders must drive their buses (G19.11); the desktop gets a
## fullscreen row and the phone does not.

func run() -> void:
	suite = "AYAR"
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	var screen := SettingsScreen.new()
	add_child(screen)
	await frames(20)
	var rows := screen.find_children("*", "Button", true, false)
	var light: Button = null
	for any: Variant in rows:
		var b := any as Button
		for child in b.find_children("*", "Label", true, false):
			if (child as Label).text == tr("SETTINGS_LIGHT"):
				light = b
	ck("ayarlarda isik satiri var", light != null, "")
	if light != null:
		var before := SkyTime.mode()
		light.pressed.emit()
		await frames(6)
		ck("satir modu degistiriyor", SkyTime.mode() != before,
			"%s -> %s" % [before, SkyTime.mode()])
	for k: String in GameConfig.SKY_MODES:
		ck("deger metni var: %s" % k,
			tr("SKY_VALUE_" + k.to_upper()) != "SKY_VALUE_" + k.to_upper(), k)
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)

	# The sliders: music and effects each move their own bus, and nothing else.
	var music: HSlider = screen.find_child("Slider_" + tr("SETTINGS_MUSIC"), true, false)
	var sfx: HSlider = screen.find_child("Slider_" + tr("SETTINGS_SFX"), true, false)
	ck("muzik ve efekt kaydiricilari var", music != null and sfx != null, "")
	var mi := AudioServer.get_bus_index(AudioDirector.BUS_MUSIC)
	var si := AudioServer.get_bus_index(AudioDirector.BUS_SFX)
	ck("iki bus var", mi >= 0 and si >= 0, "%d %d" % [mi, si])
	if music != null and sfx != null and mi >= 0 and si >= 0:
		var sfx_before := AudioServer.get_bus_volume_db(si)
		music.value = 0.5
		await frames(2)
		ck("muzik kaydiricisi muzik busini kisiyor",
			absf(AudioServer.get_bus_volume_db(mi) - linear_to_db(0.5)) < 0.01,
			"%.2f dB" % AudioServer.get_bus_volume_db(mi))
		ck("efekt busi yerinde kaldi", is_equal_approx(AudioServer.get_bus_volume_db(si), sfx_before), "")
		ck("muzik seviyesi kaydedildi",
			is_equal_approx(float(GameState.get_setting("audio", "music", 1.0)), 0.5), "")
		music.value = 0.0
		await frames(2)
		ck("sifirda bus susuyor", AudioServer.is_bus_mute(mi), "")
		music.value = 1.0
		await frames(2)
		ck("geri acilinca bus acik", not AudioServer.is_bus_mute(mi), "")
	# Fullscreen: a row on the desktop, none on a phone.
	var has_fullscreen := false
	for any2: Variant in screen.find_children("*", "Label", true, false):
		if (any2 as Label).text == tr("SETTINGS_FULLSCREEN"):
			has_fullscreen = true
	ck("tam ekran satiri masaustunde var, telefonda yok",
		has_fullscreen == (not OS.has_feature("mobile")), str(has_fullscreen))
	# Every player sits on one of the two buses; Master carries nothing directly.
	var stray := 0
	for any3: Variant in AudioDirector.find_children("*", "AudioStreamPlayer", true, false):
		var pl := any3 as AudioStreamPlayer
		if pl.bus != AudioDirector.BUS_MUSIC and pl.bus != AudioDirector.BUS_SFX:
			stray += 1
	ck("her ses oynatici bir busta", stray == 0, "%d Master'da" % stray)
	print("  [olcum] buslar: %s=%d %s=%d" % [AudioDirector.BUS_MUSIC, mi, AudioDirector.BUS_SFX, si])
	screen.queue_free()
