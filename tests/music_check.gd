extends TestBase
## Which music plays where (G54): the theme carries the opening, and the
## hourly beds take over once the first yard is behind the player.

func run() -> void:
	suite = "MUZIK"
	ck("gunun ve aksamin yataklari ayri",
		AudioDirector.bed_for("midday") != AudioDirector.bed_for("dusk"),
		"%s / %s" % [AudioDirector.bed_for("midday"), AudioDirector.bed_for("dusk")])

	# Nothing finished yet: the theme, whatever hour a yard asks for.
	ChapterProgress.reset()
	ck("basta hicbir bolum bitmemis", ChapterProgress.done_count() == 0,
		str(ChapterProgress.done_count()))
	AudioDirector.stop_bed()
	AudioDirector.play_bed("midday")
	await frames(2)
	ck("ilk bolumde tema calar", AudioDirector._music != null
		and AudioDirector._music.playing, "")
	ck("ilk bolumde yatak calmaz", AudioDirector._bed == null
		or not AudioDirector._bed.playing, "")

	# One yard finished: the beds take over, and the theme steps aside.
	var first := str((Story.list("chapters")[0] as Dictionary).get("variant_id", ""))
	ChapterProgress.record(first, 2, 2)
	ck("bir bolum bitti", ChapterProgress.done_count() == 1,
		str(ChapterProgress.done_count()))
	AudioDirector.play_bed("midday")
	await settle(GameConfig.BED_FADE + 0.4)
	ck("sonrasinda yatak calar", AudioDirector._bed != null
		and AudioDirector._bed.playing, "")
	ck("yatak dogru olan", AudioDirector._bed_key == AudioDirector.bed_for("midday"),
		AudioDirector._bed_key)
	ck("tema durdu", AudioDirector._music == null or not AudioDirector._music.playing, "")

	# And the hour still chooses between them.
	AudioDirector.play_bed("dusk")
	await settle(GameConfig.BED_FADE + 0.4)
	ck("saat yatagi secer", AudioDirector._bed_key == AudioDirector.bed_for("dusk"),
		AudioDirector._bed_key)
	AudioDirector.stop_bed()
	ChapterProgress.reset()
	finish()
