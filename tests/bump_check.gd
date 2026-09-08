extends TestBase
## Driving into something (G38): the solver has always pushed the machine back
## out in silence. Now contact reports itself once, scaled by what the wall
## took, and the camera lurches.

func run() -> void:
	suite = "CARPMA"
	var game := await open("ch01_aldridge")
	await settle(0.4)
	var rects: Array = game.model.collision_rects
	ck("bahcede engel var", rects.size() > 0, str(rects.size()))
	var rect: Rect2 = rects[0]
	var m: MowerController = game.mower
	var hits: Array = []
	m.bumped.connect(func(strength: float, _dir: Vector3) -> void: hits.append(strength))

	# Just south of the obstacle, facing north: yaw 0 means forward is -z.
	m.position = Vector3(rect.position.x + rect.size.x * 0.5, m.position.y,
		rect.end.y + m.body_radius() + 1.2)
	m.yaw = 0.0
	m.speed = 0.0
	var start_z := m.position.z
	Input.action_press("move_forward")
	await settle(1.6)
	ck("engele girince bir kez bildirilir", hits.size() == 1, str(hits.size()))
	ck("carpma gucu esigin uzerinde",
		hits.size() > 0 and float(hits[0]) >= GameConfig.BUMP_MIN_IMPACT, str(hits))
	ck("makine engelin onunde durdu", m.position.z < start_z and m.position.z > rect.end.y,
		"%.2f (engel %.2f)" % [m.position.z, rect.end.y])
	# Still pressed against it: nothing more is reported.
	await settle(1.0)
	ck("yaslanirken tekrar bildirmez", hits.size() == 1, str(hits.size()))

	# Back off and go in again: contact is a new event.
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await settle(1.2)
	Input.action_release("move_back")
	Input.action_press("move_forward")
	await settle(1.8)
	Input.action_release("move_forward")
	ck("geri cekilip tekrar girince yeniden bildirir", hits.size() == 2, str(hits.size()))

	# Crawling into it is not a crash.
	hits.clear()
	m.position = Vector3(rect.position.x + rect.size.x * 0.5, m.position.y,
		rect.end.y + m.body_radius() + 0.02)
	m.speed = 0.0
	m._touching = false
	m._bump_cool = 0.0
	await settle(0.6)
	ck("duran makine carpmaz", hits.is_empty(), str(hits.size()))

	# The answer to a bump: a camera lurch that decays, and a sound that exists.
	game.cam._kick = Vector3.ZERO
	game._on_bumped(GameConfig.BUMP_HARD_IMPACT, Vector3.FORWARD)
	ck("carpma kamerayi iter", game.cam._kick.length() > 0.01,
		"%.3f" % game.cam._kick.length())
	await settle(0.8)
	ck("itme sonunmez degil: geri oturur", game.cam._kick.length() < 0.01,
		"%.3f" % game.cam._kick.length())
	ck("carpma sesi var", AudioDirector._streams.has("bump"), "")
	var quiet := 0.0
	var loud := 0.0
	AudioDirector.play_bump(0.15)
	quiet = AudioDirector._bump_player.pitch_scale
	AudioDirector.play_bump(1.0)
	loud = AudioDirector._bump_player.pitch_scale
	ck("sert carpma daha kalin duyulur", loud < quiet, "%.2f < %.2f" % [loud, quiet])
	close(game)
	finish()
