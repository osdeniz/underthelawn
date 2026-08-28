extends Node
## G14.1: the blade's spark check must survive every obstacle layout.
##
## It used to read collision_rects[1] directly, which threw on the layouts that
## have no obstacles at all ("open" — the playground and the harvest field) and
## measured a sunbed on the pool layout.

var _fails := 0


func _ready() -> void:
	for layout: String in LawnModel.OBSTACLE_LAYOUTS:
		LawnModel.layout_id = layout
		var model := LawnModel.new(4242)
		var blade := BladeMower.new()
		blade.model = model
		add_child(blade)
		blade.speed = 4.0
		# Straight through the middle of the yard: whatever is in the way, the
		# check must survive the whole crossing.
		for step in 40:
			blade.position = Vector3(
				lerpf(-GameConfig.HALF_X, GameConfig.HALF_X, float(step) / 39.0),
				0.0,
				lerpf(-GameConfig.HALF_Z, GameConfig.HALF_Z, float(step) / 39.0))
			blade._check_spark(0.016)
		var stones := 0
		for ob: Dictionary in model.obstacles:
			if str(ob.get("name", "")) == "stone":
				stones += 1
		ck("%s tas sayisi eslesiyor" % layout, blade._stone_rects.size() == stones,
			"%d / %d" % [blade._stone_rects.size(), stones])
		blade.queue_free()
	LawnModel.layout_id = "beds"
	if _fails > 0:
		push_error("%d KIVILCIM TESTI BASARISIZ" % _fails)
		print("--- %d KIVILCIM TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM KIVILCIM TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
