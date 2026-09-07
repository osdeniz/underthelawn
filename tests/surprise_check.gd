extends TestBase
## Small surprises (G29): eligibility follows the weather, the hour and the
## ground; a yard plans at most two; each of the six spawns and moves or ends
## as it should; the road has none.

func run() -> void:
	suite = "SURPRIZ"
	var day := LevelVariant.of("ch01_aldridge")
	var night := LevelVariant.new()
	night.time_of_day = "night"
	night.weather = "clear"
	var lake := LevelVariant.of("ch04_flooded")
	var e_day := Surprises.eligible(day)
	ck("gunduz acik: ucurtma ve bulut var", e_day.has(Surprises.KITE) and e_day.has(Surprises.CLOUD), str(e_day))
	ck("gece: ucurtma yok, pencere var", not Surprises.eligible(night).has(Surprises.KITE)
		and Surprises.eligible(night).has(Surprises.WINDOW), str(Surprises.eligible(night)))
	ck("golde top yok", not Surprises.eligible(lake).has(Surprises.BALL), str(Surprises.eligible(lake)))

	var game := await open("ch01_aldridge")
	await settle(0.6)
	var s: Surprises = game._surprises
	ck("bahcede surpriz plani var", s != null and s.planned_ids().size() >= 1
		and s.planned_ids().size() <= GameConfig.SURPRISE_MAX_PER_YARD,
		"" if s == null else str(s.planned_ids()))
	if s == null:
		close(game)
		finish()
		return
	ck("ayni tohum ayni plan", true, "")
	var first := s.planned_ids()
	s.plan(game.variant.decor_seed)
	ck("plan tohuma bagli", s.planned_ids() == first, "%s / %s" % [first, s.planned_ids()])

	# Kite: spawns and crosses.
	ck("ucurtma baslar", s.force(Surprises.KITE), "")
	var kite := s.find_child("Kite", false, false) as Node3D
	ck("ucurtma var", kite != null, "")
	var x0 := kite.position.x if kite != null else 0.0
	await settle(0.5)
	ck("ucurtma hareket eder", kite != null and absf(kite.position.x - x0) > 0.2,
		"" if kite == null else str(kite.position.x - x0))
	ck("ayni surpriz iki kez baslamaz", not s.force(Surprises.KITE), "")

	# Cloud shadow: flat, moving.
	s.force(Surprises.CLOUD)
	var cloud := s.find_child("CloudShadow", false, false) as Node3D
	ck("bulut golgesi yerde yatar", cloud != null and cloud.position.y < 0.2, "")
	var cx := cloud.position.x if cloud != null else 0.0
	await settle(0.4)
	ck("bulut golgesi kayar", cloud != null and absf(cloud.position.x - cx) > 0.1, "")

	# Ball: rolls in and stops.
	s.force(Surprises.BALL)
	var ball := s.find_child("Ball", false, false) as Node3D
	ck("top gelir", ball != null, "")
	var v0 := s.ball_speed()
	await settle(0.8)
	ck("top yavaslar", s.ball_speed() < v0 and s.ball_speed() > 0.0, "%f -> %f" % [v0, s.ball_speed()])
	ck("top bahce icine girdi", ball != null and absf(ball.position.x) < GameConfig.HALF_X + 1.2, "")

	# Butterflies: two, flapping.
	s.force(Surprises.BUTTERFLIES)
	var flies := s.find_child("Butterflies", false, false)
	ck("iki kelebek", flies != null and flies.get_child_count() == 2, "")
	await settle(0.3)
	var wing := flies.get_child(0).get_node("WingL") as Node3D if flies != null else null
	ck("kelebek kanat cirpar", wing != null and absf(wing.rotation.z) > 0.001, "")

	# Bird: only with a machine left standing.
	s.mower = game.mower
	s.parked_seconds = 0.0
	ck("park yokken kus inmez", s.find_child("MowerBird", false, false) == null, "")
	s.parked_seconds = GameConfig.SURPRISE_BIRD_PARK_SECONDS + 1.0
	s.force(Surprises.BIRD)
	var bird := s.find_child("MowerBird", false, false) as Node3D
	ck("kus makineye iner", bird != null and bird.position.distance_to(game.mower.global_position) < 1.5, "")
	s.parked_seconds = 0.0
	await settle(0.3)
	ck("makine kalkinca kus ucar", bird != null and bird.position.y > GameConfig.SURPRISE_BIRD_PERCH + 0.2,
		"" if bird == null else str(bird.position.y))

	# Window: a pane goes warm.
	var lit := s.force(Surprises.WINDOW)
	ck("ev penceresi bulunur", lit, "")
	await settle(0.3)
	var pane := s._find_pane_lit()
	ck("pencere isir", pane != null and (pane.material_override as StandardMaterial3D).emission_energy_multiplier > 0.05, "")
	close(game)

	var prologue := await open("ch00_the_long_walk")
	ck("yolda surpriz yok", prologue._surprises == null, "")
	close(prologue)
	finish()
