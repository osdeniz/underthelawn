class_name QuietScene
extends Control
## A scene the player watches rather than plays (G13).
##
## The road between chapters is not a lawn, so it cannot be one. A quiet scene
## stops the mowing, puts a drawn still behind a scripted conversation, lets the
## player choose a TONE rather than an outcome, and then charges whatever the
## scene costs. It is a general template on purpose: The Toll is the first one,
## and there will be others.
##
## What it deliberately does NOT do: branch. Both flavour options reach the same
## place, because a scene that changes the story on a two-word choice is a scene
## the player has to replay to see, and this game does not ask for that.
##
## The scene is DATA. story.json's `quiet_scenes` block names the conversation,
## the backdrop and the consequence; nothing about The Toll is written here.

signal finished()

## Backdrops this template can draw. A scene names one; anything else falls back
## to the plain dusk wash, which reads as "somewhere on the road at evening".
const BACKDROP_ROAD := "road_silhouettes"

var _scene_id := ""
var _spec: Dictionary = {}
var _paid := 0


func play(scene_id: String) -> void:
	_scene_id = scene_id
	_spec = Story.get_value("quiet_scenes." + scene_id, {})
	if not (_spec is Dictionary) or (_spec as Dictionary).is_empty():
		push_warning("[QuietScene] tanimsiz sahne: %s" % scene_id)
		finished.emit()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_backdrop()
	# The charge lands BEFORE the closing line, so the line is about something
	# that already happened rather than a threat.
	_paid = _apply_consequence()
	var lines := Dialogue.conversation(str(_spec.get("dialogue", "")))
	if lines.is_empty():
		finished.emit()
		return
	var box := DialogueBox.new()
	add_child(box)
	box.finished.connect(_on_dialogue_done)
	box.play(lines, str(_spec.get("accept", "")))


func _on_dialogue_done() -> void:
	var after := str(_spec.get("after_dialogue", ""))
	if after != "":
		var lines := Dialogue.conversation(after)
		if not lines.is_empty():
			var box := DialogueBox.new()
			add_child(box)
			box.finished.connect(func() -> void: finished.emit())
			box.play(lines)
			return
	finished.emit()


## What the scene costs. Returns the amount actually taken, so the closing line
## and the analytics agree with the wallet.
func _apply_consequence() -> int:
	match str(_spec.get("consequence", "")):
		"scrap_toll":
			var total := GameState.scrap_total()
			var want := int(round(float(total) * GameConfig.TOLL_SCRAP_SHARE))
			var take := clampi(want, GameConfig.TOLL_SCRAP_MIN,
				GameConfig.TOLL_SCRAP_MAX)
			# Never more than the player has: a toll is a cost, not a debt.
			take = mini(take, total)
			if take > 0:
				GameState.spend_scrap(take)
			Analytics.track(AnalyticsEvents.TOLL_PAID,
				{"scene": _scene_id, "amount": take})
			return take
	return 0


## The still behind the conversation. Drawn rather than modelled: three figures
## at a distance, no faces, no detail — the only human threat this game puts on
## screen, and it works because there is nothing to look at.
func _build_backdrop() -> void:
	var sky := ColorRect.new()
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.color = GameConfig.QUIET_SKY
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	var art := Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	if str(_spec.get("backdrop", "")) == BACKDROP_ROAD:
		art.draw.connect(_draw_road.bind(art))
	else:
		art.draw.connect(_draw_dusk.bind(art))
	art.queue_redraw()


func _draw_dusk(canvas: Control) -> void:
	var size := canvas.size
	canvas.draw_rect(Rect2(Vector2(0.0, size.y * 0.455),
		Vector2(size.x, size.y * 0.545)), GameConfig.QUIET_GROUND)


func _draw_road(canvas: Control) -> void:
	var size := canvas.size
	# High, and to the RIGHT of centre: the speaker's portrait stands bottom
	# left through the whole scene, and the first pass put a figure behind it.
	var horizon := size.y * 0.455
	_draw_dusk(canvas)
	# The road: a shallow wedge running to a vanishing point, so the figures
	# read as standing ON something and therefore as far away rather than small.
	var vanish := Vector2(size.x * 0.5, horizon)
	canvas.draw_colored_polygon(PackedVector2Array([
		vanish + Vector2(-size.x * 0.06, 0.0),
		vanish + Vector2(size.x * 0.06, 0.0),
		Vector2(size.x * 0.94, size.y),
		Vector2(size.x * 0.06, size.y)]), GameConfig.QUIET_ROAD)
	# Three of them, unevenly spaced. Even spacing reads as a formation, and a
	# formation reads as an army; these are people standing in a road.
	var spots: Array[float] = [0.575, 0.665, 0.735]
	var heights: Array[float] = [1.0, 0.92, 1.08]
	for i in spots.size():
		# Small. Three people at the end of a road, not three people in a room:
		# the distance is what makes this the game's only human threat and
		# still not a fight.
		var h := size.y * 0.034 * heights[i]
		var x := size.x * spots[i]
		var foot := horizon + h * 0.16
		var w := h * 0.30
		canvas.draw_rect(Rect2(Vector2(x - w * 0.5, foot - h),
			Vector2(w, h)), GameConfig.QUIET_FIGURE)
		canvas.draw_circle(Vector2(x, foot - h - w * 0.34), w * 0.36,
			GameConfig.QUIET_FIGURE)
