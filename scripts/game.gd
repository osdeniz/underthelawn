class_name Game
extends Node3D
## Sprints G1-G3 wiring: model -> view -> the selected mower -> camera -> HUD,
## the secret discovery flow (§9, §16) and the three-way mower picker.
##
## All three mowers live under Mowers; only one is visible and simulated. Touch
## input arrives through _unhandled_input (so HUD taps never reach the lawn),
## is offered to the secret shimmers first, and otherwise goes to the active
## mower, which interprets it according to its own control scheme (§7).

## Emitted when the lawn is finished: (evidence_found, evidence_total). RootFlow
## records it against this run's variant_id; nothing breaks if nobody listens.
signal search_finished(evidence: int, total: int)

@onready var lawn: LawnView = $Lawn
@onready var cam: CameraRig = $Camera3D
@onready var hud: Hud = $UI/HUD
@onready var _fx_root: Node3D = $Effects
@onready var _mower_root: Node3D = $Mowers

var model: LawnModel
var mower: MowerController
var character: Character

var _mowers: Array[MowerController] = []
var _active_index := GameConfig.MOWER_PUSH
var _collected: Array = []
## Which scent moments have already fired this chapter (G13.4).
var _scent_done: Dictionary = {}
## First-run orientation (G15): whether this search is the player's first, and
## the countdown to the sheet. Zero means "not pending".
var _first_run := false
var _orientation_due := 0.0
var _complete_shown := false
## G7: the case has to be accepted before the search starts. While this is
## false the lawn ignores touches and the run clock has not begun.
var _search_started := false
## Which chapter this run is. Set by RootFlow before _ready; G9 builds the lawn
## from variant data keyed on it. A chapter is an ID, never a scene.
@export var variant_id := "ch01_aldridge"
## RootFlow runs the briefing itself, so it starts the search immediately.
## Standalone (every test instantiates Main.tscn directly) this is also true, so
## the scene is playable on its own.
var autostart_search := true
## The resolved chapter data. Read by the HUD, the evidence flow and the scrap
## economy; never a scene.
var variant: LevelVariant
## This chapter's buried salvage, and the running ground haul.
var scrap_field: ScrapField
var _scrap_banked := 0
## Set once both pieces of evidence are in hand and the player chose to keep
## mowing, so the "Continue" badge stays available.
var _exit_offered := false
## Evidence lying in the grass, waiting to be driven over (G10.1).
var _evidence_props: Array = []
## The haul riding on the driver's back / the machine's deck.
var carry: CarryStack
## The chapter's echo: one buried world-history find, no glow, no hint — the
## surprise is the point (G12.6).
var _echo_prop: Node3D
var _echo_cell := Vector2i(-1, -1)


## The variant has to be applied before ANY child _ready runs: EnvironmentBuilder
## builds the house and landmark in its own _ready, and child _ready always
## precedes the parent's. _enter_tree is the only hook early enough, and
## variant_id is already set by then because RootFlow assigns it before
## add_child().
func _enter_tree() -> void:
	# The blade's disk size is a garage stat and everything derives from
	# BLADE_SCALE at build time, so it must be set before any child builds.
	Garage.apply_blade_scale()
	variant = LevelVariant.of(variant_id)
	variant.apply()


func _ready() -> void:
	model = LawnModel.new(variant.decor_seed)
	scrap_field = ScrapField.new()
	scrap_field.name = "ScrapField"
	add_child(scrap_field)
	# A finished clinic puts one more salvage point in every yard (G12.6).
	scrap_field.setup(model, variant.scrap_budget + RestoreBoard.scrap_bonus(),
		variant.decor_seed)
	_place_echo()
	var hint := RemainderHint.new()
	hint.name = "RemainderHint"
	add_child(hint)
	hint.setup(model)
	lawn.setup(model)

	for child in _mower_root.get_children():
		var controller := child as MowerController
		if controller == null:
			continue
		controller.model = model
		controller.tuft_field = lawn.tuft_field
		controller.cells_mown.connect(_on_cells_mown)
		controller.scrap_found.connect(_on_scrap_found)
		controller.scrap_field = scrap_field
		controller.set_active(false)
		_mowers.append(controller)
	_mowers.sort_custom(func(a: MowerController, b: MowerController) -> bool:
		return a.type_index() < b.type_index())
	_ensure_all_mowers()

	var tractor := _mowers[GameConfig.MOWER_TRACTOR] as TractorMower
	if tractor:
		tractor.joystick = hud.joystick

	# The driver (§8): walks behind the push mower, rides the tractor, and sits
	# at the lawn edge watching the robot.
	character = Character.new()
	character.name = "Driver"
	add_child(character)

	carry = CarryStack.new()
	carry.name = "Carry"
	add_child(carry)

	model.completed.connect(_on_completed)
	model.secret_revealed.connect(_on_secret_uncovered)
	hud.restart_pressed.connect(_restart)
	hud.selector.mower_chosen.connect(select_mower)

	hud.set_progress(0.0)
	hud.set_secret_count(0, GameConfig.SECRET_TOTAL)
	if variant != null and variant.is_harvest():
		hud.apply_harvest_mode()

	hud.return_requested.connect(_return_to_hub)
	hud.exit_confirmed.connect(_confirm_exit)
	hud.next_chapter_requested.connect(_next_chapter)
	hud.board_requested.connect(func() -> void:
		var root := get_parent()
		if root != null and root.has_method("return_to_board"):
			root.return_to_board())

	_apply_quality()
	# The chapter's hour, before the first frame is drawn (G14.2).
	SkyTime.apply($WorldEnvironment as WorldEnvironment,
		$Sun as DirectionalLight3D, variant.time_of_day)
	_activate(GameConfig.MOWER_PUSH, true)
	# G9.4: no birds in play — the theme runs instead (RootFlow keeps it going).
	# Standalone (tests, direct scene run) start it here so the scene sounds
	# the same without the flow above it.
	AudioDirector.play_theme()

	# G8: the briefing moved to RootFlow's DialogueBox, so by the time this
	# scene exists the case has already been accepted.
	if autostart_search:
		_begin_search()


func _process(delta: float) -> void:
	_tick_orientation(delta)
	_check_pickups()
	if mower != null and hud != null:
		hud.set_pad_state(mower.pad_engaged(), mower._pad_origin, mower._pad_now)
	if mower == null:
		return
	# Steering and swipes are camera-relative, so every mower needs the yaw.
	mower.camera_yaw = cam.yaw
	mower.camera = cam
	var turn := clampf(absf(mower.omega) / mower.max_turn(), 0.0, 1.0)
	AudioDirector.set_engine_state(mower.speed_fraction(), turn)


## The scene is the editor's territory and it has eaten externally-added nodes
## before (the Blade node vanished exactly that way, silently degrading ⚙️ to
## the robot via clampi). Any GameConfig mower type missing from the scene is
## spawned from code here, with a console note, so the picker always matches.
func _ensure_all_mowers() -> void:
	for i in GameConfig.MOWER_TYPES.size():
		if i < _mowers.size() and _mowers[i].type_index() == i:
			continue
		var built: MowerController = null
		match i:
			GameConfig.MOWER_BLADE:
				built = BladeMower.new()
				built.name = "Blade"
			GameConfig.MOWER_PUSH:
				built = (load("res://scenes/PushMower.tscn") as PackedScene).instantiate()
			GameConfig.MOWER_TRACTOR:
				built = (load("res://scenes/Tractor.tscn") as PackedScene).instantiate()
			GameConfig.MOWER_ROBOT:
				built = (load("res://scenes/Robot.tscn") as PackedScene).instantiate()
		if built == null:
			continue
		# The blade has no .tscn — it is built entirely in code — so it is ALWAYS
		# spawned here and that is not worth a line in the console every launch.
		# The other three do have scenes, so one of those missing is a real
		# problem (the editor has silently eaten a node before).
		if i != GameConfig.MOWER_BLADE:
			push_warning("[Game] sahnede eksik mower koddan eklendi: %s"
				% GameConfig.MOWER_TYPES[i]["id"])
		_mower_root.add_child(built)
		built.model = model
		built.tuft_field = lawn.tuft_field
		built.cells_mown.connect(_on_cells_mown)
		# The same wiring the scene's own mowers get in _ready. Without these two
		# lines a code-spawned mower drives over money and nothing happens —
		# which was every mower except the push one.
		built.scrap_found.connect(_on_scrap_found)
		built.scrap_field = scrap_field
		built.set_active(false)
		_mowers.insert(i, built)


## Counts down to the orientation sheet on a first run, then stops. Driven from
## _process rather than a timer so pausing the game pauses the countdown too.
func _tick_orientation(delta: float) -> void:
	if _orientation_due <= 0.0:
		return
	_orientation_due -= delta
	if _orientation_due > 0.0:
		return
	_orientation_due = 0.0
	GameState.mark_orientation_done()
	Analytics.track(AnalyticsEvents.ORIENTATION_SHOWN, {"chapter": variant_id})
	hud.show_orientation(_on_orientation_closed)


## Closing the sheet marks BOTH buried finds, once. This is the only place in
## the game that points at evidence rather than at a region — it is the price of
## a first-run player knowing what "search" means, and it never happens again.
func _on_orientation_closed() -> void:
	for cell_any: Variant in model.secret_cells:
		var cell: Vector2i = cell_any
		if model.is_cut(cell.x, cell.y):
			continue
		lawn.tint_hint(cell, GameConfig.FIRST_RUN_HINT_CELLS)
	Analytics.track(AnalyticsEvents.ORIENTATION_HINT_MARKED, {"chapter": variant_id})


## The Marshal on the radio at set points in a search, plus the faintest tint on
## the ground near the evidence he is talking about (G13.4).
##
## It does NOT say where the evidence is. It names a region — "that corner by
## the oak" — and tints two or three cells AROUND the find, so the player is
## drawn to an area and still has to work it. That is the difference between a
## hint and a waypoint.
func _check_scent(ratio: float) -> void:
	if not GameConfig.hint_moments or variant == null:
		return
	# A first run hears him almost immediately; after that, at the usual points.
	var marks: Array = GameConfig.FIRST_RUN_SCENT_AT if _first_run \
		else GameConfig.SCENT_AT
	for i in marks.size():
		if _scent_done.has(i):
			continue
		if ratio < float(marks[i]):
			continue
		_scent_done[i] = true
		var target := _scent_target(i)
		if target == Vector2i(-1, -1):
			continue
		hud.show_scent(_scent_line(target))
		AudioDirector.play_static()
		lawn.tint_hint(target, GameConfig.SCENT_TINT_CELLS)
		Analytics.track(AnalyticsEvents.SCENT_SHOWN, {"chapter": variant_id, "at": ratio})
		return


## The cell of an evidence item that is still buried. Evidence only becomes a
## node once its cell is mown, so the MODEL is what knows where they are.
func _scent_target(index: int) -> Vector2i:
	var wanted := index
	for cell_any: Variant in model.secret_cells:
		var cell: Vector2i = cell_any
		if model.is_cut(cell.x, cell.y):
			continue
		if wanted > 0:
			wanted -= 1
			continue
		return cell
	return Vector2i(-1, -1)


## Which of the Marshal's four lines fits where the find is on the lawn.
func _scent_line(cell: Vector2i) -> String:
	var cols := GameConfig.GRID_COLS
	var rows := GameConfig.GRID_ROWS
	if cell.y < rows / 3:
		return "SCENT_BACK"
	if cell.x < cols / 4 or cell.x > cols * 3 / 4:
		return "SCENT_FENCE"
	if cell.y > rows * 2 / 3:
		return "SCENT_OAK"
	return "SCENT_NEAR"


## G6 quality switches (game_config): shadow atlas size, subtle bloom.
func _apply_quality() -> void:
	RenderingServer.directional_shadow_atlas_set_size(
		2048 if GameConfig.SHADOW_MAP_2048 else 1024, true)
	var env := ($WorldEnvironment as WorldEnvironment).environment
	env.glow_enabled = GameConfig.GLOW_ENABLED
	if GameConfig.GLOW_ENABLED:
		env.glow_intensity = GameConfig.GLOW_INTENSITY
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = GameConfig.GLOW_HDR_THRESHOLD
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE


# ---------------------------------------------------------------- mower switching

## Switches type in place: the new mower inherits position and heading, speed
## resets, the camera keeps lerping, and the robot replans from the current lawn.
func select_mower(index: int) -> void:
	if index == _active_index and mower != null:
		return
	_activate(index, false)
	Haptics.light()


func _activate(index: int, initial: bool) -> void:
	if index >= _mowers.size() or _mowers[index].type_index() != index:
		push_warning("Game: mower %d sahnede yok, secim yok sayildi" % index)
		return
	var previous := mower
	var carry_position := Vector3(GameConfig.mower_start().x, 0.0, GameConfig.mower_start().y)
	var carry_yaw := 0.0
	if previous != null:
		carry_position = previous.position
		carry_yaw = previous.yaw
		previous.set_active(false)

	_active_index = index
	mower = _mowers[index]
	mower.camera_yaw = cam.yaw
	mower.camera = cam
	if initial:
		mower.reset_to_start()
	else:
		mower.adopt_state(carry_position, carry_yaw)
	mower.set_active(true)

	cam.target = mower
	var gain := GameConfig.TRACTOR_LOOKAHEAD_GAIN if index == GameConfig.MOWER_TRACTOR else 0.0
	cam.set_preset(GameConfig.MOWER_CAMERA[index], gain)
	if initial:
		cam.snap_to_target()

	AudioDirector.set_engine_profile(index)
	hud.set_joystick_visible(index == GameConfig.MOWER_TRACTOR)
	hud.selector.set_current(index)
	_place_character(index)


## §8 integration: the driver follows the mower choice.
func _place_character(index: int) -> void:
	if character == null:
		return
	match index:
		GameConfig.MOWER_PUSH:
			character.set_mode(Character.Mode.PUSH, mower, mower)
		GameConfig.MOWER_TRACTOR:
			character.set_mode(Character.Mode.TRACTOR, mower, mower)
		GameConfig.MOWER_ROBOT, GameConfig.MOWER_BLADE:
			# Nothing to push or ride: the driver watches from the porch.
			character.set_mode(Character.Mode.SIT, null, self)
	_reparent_carry(index)


## The haul follows whoever is actually working: the walking driver's back for
## the push mower and the tractor seat, the machine's own deck when the driver
## is sitting this one out (G10.1).
func _reparent_carry(index: int) -> void:
	if carry == null:
		return
	var host: Node3D = mower
	var offset := GameConfig.CARRY_DECK_OFFSET
	if index == GameConfig.MOWER_PUSH:
		host = character
		offset = GameConfig.CARRY_BACK_OFFSET
	elif index == GameConfig.MOWER_TRACTOR:
		# A seated driver cannot carry a stack on their back, so the tractor's
		# load goes in its bed (G12.9).
		var anchor: Node3D = mower.get("carry_anchor")
		if anchor != null:
			host = anchor
			offset = Vector3.ZERO
	if carry.get_parent() != host:
		if carry.get_parent() != null:
			carry.get_parent().remove_child(carry)
		host.add_child(carry)
	carry.position = offset


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	# The intro cards and the briefing are modal: the lawn hears nothing.
	if not _search_started:
		return
	# Desktop keyboard shortcuts (G14). A touch build never fires these.
	if not event.is_echo():
		if event.is_action_pressed("ui_pause"):
			hud.toggle_pause()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("mower_next"):
			_cycle_mower()
			get_viewport().set_input_as_handled()
			return
	if mower == null:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			mower.on_touch_pressed(touch.index, touch.position)
		else:
			mower.on_touch_released(touch.index, touch.position)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		mower.on_touch_dragged(drag.index, drag.position)


## Ray/sphere test against every live shimmer (§16 uses camera.project_ray).
func _on_secret_uncovered(col: int, row: int) -> void:
	var kind := model.secret_cells.find(Vector2i(col, row))
	if kind < 0:
		kind = 0
	# G10.1: the object itself is revealed, not an abstract orb — the player has
	# to be able to see WHAT they found from across the lawn.
	var prop := SecretItem.new()
	prop.name = "Evidence_%d_%d" % [col, row]
	_fx_root.add_child(prop)
	var reveal_info := variant.evidence_info(kind) if variant != null else {}
	var evidence_id := str(reveal_info.get("id", ""))
	prop.setup_by_id(evidence_id, LawnModel.cell_center(col, row))
	prop.set_meta("kind", kind)
	prop.set_meta("evidence_id", evidence_id)
	_evidence_props.append(prop)
	AudioDirector.play_discovery()
	Haptics.medium()


## Anything the mower drives near is taken. One reach for both evidence and
## cash, so "it looked like I touched it" and "it counted" are the same rule.
func _check_pickups() -> void:
	if mower == null or not _search_started or _complete_shown:
		return
	var reach := mower.deck_radius() + GameConfig.PICKUP_REACH
	var here := Vector2(mower.position.x, mower.position.z)
	for prop in _evidence_props.duplicate():
		if prop == null or not is_instance_valid(prop):
			_evidence_props.erase(prop)
			continue
		var at := Vector2(prop.global_position.x, prop.global_position.z)
		if here.distance_to(at) <= reach:
			_evidence_props.erase(prop)
			_collect_evidence(prop)


func _collect_evidence(prop: Node3D) -> void:
	var kind := int(prop.get_meta("kind", 0))
	var ground := Vector3(prop.global_position.x, 0.0, prop.global_position.z)
	prop.queue_free()

	DigBurst.spawn(_fx_root, ground)
	# The find leaves a permanent mark, so the lawn remembers where it paid out.
	FindMarker.spawn(_fx_root, ground, str(prop.get_meta("evidence_id", "")))
	AudioDirector.play_discovery()
	Haptics.success()
	if carry != null:
		carry.add_evidence(str(prop.get_meta("evidence_id", "")))

	var info := variant.evidence_info(kind) if variant != null else {}
	if info.is_empty():
		info = SecretItem.info_for(kind)
	# id travels with the entry so the completion screen can render the object
	# rather than an emoji (G12.10).
	_collected.append({ "emoji": info["emoji"], "name": info["name"],
		"where": info.get("where", ""), "id": str(info.get("id", "")) })
	Analytics.track(AnalyticsEvents.EVIDENCE_FOUND, {"chapter": variant_id,
		"id": str(info.get("id", "")), "count": _collected.size(),
		"total": _evidence_total()})
	hud.show_secret_card(info["emoji"], info["name"], info["line"],
		func() -> void:
			hud.set_secret_count(_collected.size(), _evidence_total())
			_glance_at(ground)
			if _collected.size() >= _evidence_total():
				_offer_exit(),
		str(info.get("id", "")))


## A short look back at the spot once the card clears: spatial memory, cheaply.
func _glance_at(at: Vector3) -> void:
	if not GameConfig.FIND_PAN_ENABLED or cam == null:
		return
	Analytics.track(AnalyticsEvents.EVIDENCE_LOCATION_PANNED, {"chapter": variant_id})
	cam.glance_at(at, GameConfig.FIND_PAN_TIME)


## Backgrounding the app pauses the search (G14.1).
##
## Audio already suspended itself here, but the LAWN kept being mown: a phone
## call, a locked screen or an alt-tab left the mower driving with nobody
## watching. The same notification covers both platforms — iOS sends
## APPLICATION_PAUSED, a desktop window sends WM_WINDOW_FOCUS_OUT.
##
## Resuming does NOT unpause: the sheet stays up and the player chooses when to
## go back in, which is what every mobile game does and the only safe thing to
## do when you cannot know how long they were gone.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if _search_started and hud != null and is_instance_valid(hud):
				hud.pause_for_background()


## Tab / Space: the next machine the player actually owns.
func _cycle_mower() -> void:
	var count := GameConfig.MOWER_TYPES.size()
	for step in range(1, count + 1):
		var next := (_active_index + step) % count
		if Garage.is_unlocked(next):
			select_mower(next)
			return


func _on_cells_mown(_count: int) -> void:
	hud.set_progress(model.completion_ratio())
	_check_scent(model.completion_ratio())
	# The echo is revealed by cutting its cell, same as evidence — but silently,
	# with no marker until it is actually picked up.
	if _echo_cell.x >= 0 and model.is_cut(_echo_cell.x, _echo_cell.y):
		_check_echo(_echo_cell.x, _echo_cell.y)


func _on_completed() -> void:
	if _complete_shown:
		return
	_complete_shown = true
	GameState.finish_run()
	cam.set_bird_view(true)
	hud.flash()
	Haptics.success()
	# Let the bird's-eye reward land before the panel covers it.
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(func() -> void:
		var payout := _payout()
		GameState.add_scrap(int(payout["total"]))
		hud.set_scrap(GameState.scrap_total())
		search_finished.emit(_collected.size(), _evidence_total())
		if variant != null and variant.is_harvest():
			HarvestLog.record()
			Analytics.track(AnalyticsEvents.HARVEST_COMPLETED,
				{"scrap": int(payout["total"]), "run": HarvestLog.count()})
		hud.show_complete(model.mowed_count, GameState.format_elapsed(),
			_collected, _evidence_total(), payout, _next_chapter_name()))


## Restart: model reset (secrets redistributed), tint map cleared, tufts back
## up, shimmers and items cleared, back to the push mower.
func _restart() -> void:
	for prop in _evidence_props:
		if prop != null and is_instance_valid(prop):
			prop.queue_free()
	_evidence_props.clear()
	if carry != null:
		carry.clear_all()
	for child in _fx_root.get_children():
		child.queue_free()
	_collected.clear()
	_scent_done.clear()
	_complete_shown = false

	model.reset()
	lawn.on_model_reset()
	cam.set_bird_view(false)
	_activate(GameConfig.MOWER_PUSH, true)
	hud.hide_complete()
	hud.set_progress(0.0)
	hud.set_secret_count(0, _evidence_total())
	GameState.start_run()


# ---------------------------------------------------------------- flow (G8)

## RETURN TO TOWN. Standalone (tests, or running Main.tscn directly) there is no
## hub to go back to, so this restarts instead of dead-ending.
func _return_to_hub() -> void:
	var root := get_parent()
	if root != null and root.has_method("return_to_hub"):
		root.return_to_hub()
		return
	_restart()


## The briefing was accepted (or there is none): drop the camera onto the
## property, hold the opening title, and start the clock.
func _begin_search() -> void:
	if _search_started:
		return
	_search_started = true
	# The one-time orientation, on a first run only (G15).
	_first_run = GameState.is_first_run()
	if _first_run:
		hud.pulse_poster(GameConfig.FIRST_RUN_POSTER_PULSE)
		_orientation_due = GameConfig.FIRST_RUN_MODAL_AFTER
	# A harvest opens from higher and slower: the crop rings the plot, and from
	# the play camera's usual height a six-metre sunflower on the far fence is
	# simply off screen. The descent is what introduces the field (G13.6).
	var harvest := variant != null and variant.is_harvest()
	cam.descend_to(GameConfig.MOWER_CAMERA[_active_index],
		4.2 if harvest else 2.4, 62.0 if harvest else 26.0,
		14.0 if harvest else 3.0)
	hud.show_opening_title(variant.opening_headline, variant.opening_subline)
	hud.show_drive_hint()
	GameState.start_run()
	# Harvest has its own start event (town_map.gd, fired when the invitation is
	# accepted); this is the case-chapter funnel's top of the mouth.
	if not harvest:
		Analytics.track(AnalyticsEvents.CHAPTER_STARTED, {"chapter": variant_id})


# ---------------------------------------------------------------- G9 economy

## How many pieces of evidence this chapter hides. From the variant, so a future
## chapter can carry a different number without touching the HUD.
func _evidence_total() -> int:
	if variant != null and variant.evidence_count() > 0:
		return variant.evidence_count()
	return GameConfig.SECRET_TOTAL


func _on_scrap_found(col: int, row: int, value: int) -> void:
	_scrap_banked += value
	if carry != null:
		carry.add_money()
	var at := LawnModel.cell_center(col, row)
	hud.fly_scrap(value, cam.unproject_position(at + Vector3.UP * 0.6))
	hud.set_scrap(GameState.scrap_total() + _scrap_banked)
	AudioDirector.play_scrap()
	Haptics.light()


## The end-of-chapter scrap breakdown.
func _payout() -> Dictionary:
	var budget := variant.scrap_budget if variant != null else 9
	var payout := ScrapField.payout(_scrap_banked, model.completion_ratio(), budget)
	# A harvest is the paying job, and the multiplier is applied HERE rather
	# than in ScrapField so ScrapField's own math stays a pure, unit-tested
	# function (G13.6). The search multiplier below follows the same pattern
	# (G14.3): it closes the gate where the harvest loop paid less than it
	# cost to reach.
	var multiplier := GameConfig.SEARCH_SCRAP_MULTIPLIER
	if variant != null and variant.is_harvest():
		multiplier = GameConfig.HARVEST_SCRAP_MULTIPLIER
	for key: String in payout:
		# "ratio" is completion (0-1), not a scrap amount - multiplying it
		# made a full harvest report "200% mowed" on the completion panel.
		if key == "ratio":
			continue
		payout[key] = int(round(float(payout[key]) * multiplier))
	return payout


# ---------------------------------------------------------------- G9 early exit

## Both pieces of evidence are in hand: offer to close the chapter now. The
## player can also keep mowing, and a small badge keeps the offer available.
func _offer_exit() -> void:
	if _exit_offered or _complete_shown:
		return
	_exit_offered = true
	hud.show_exit_offer()


## CONTINUE THE CASE: finish the chapter on the player's terms rather than
## requiring a full mow.
func _confirm_exit() -> void:
	if _complete_shown:
		return
	_on_completed()


## Display name of the chapter after this one, or "" when there is none or when
## the scene runs standalone (tests) with no flow above it to serve it.
func _next_chapter_name() -> String:
	var root := get_parent()
	if root == null or not root.has_method("start_next_chapter"):
		return ""
	var chapters := ChapterProgress.chapters()
	for i in chapters.size():
		if str(chapters[i].get("variant_id", "")) == variant_id:
			if i + 1 < chapters.size():
				return tr(str(chapters[i + 1].get("name", "")))
			return ""
	return ""


func _next_chapter() -> void:
	var root := get_parent()
	if root != null and root.has_method("start_next_chapter"):
		root.start_next_chapter(variant_id)


# ---------------------------------------------------------------- echoes (G12.6)

## Buries the chapter's echo on a mowable cell that holds nothing else. Seeded
## from decor_seed, so a yard's echo is always in the same place.
func _place_echo() -> void:
	if variant == null or variant.echo_def.is_empty():
		return
	if EchoLog.is_found(variant_id):
		# Already collected in a previous run: a collectible found twice is not
		# a collectible.
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = variant.decor_seed + 7717
	for _try in 300:
		var col := rng.randi_range(1, GameConfig.GRID_COLS - 2)
		var row := rng.randi_range(1, GameConfig.GRID_ROWS - 2)
		if not model.is_mowable(col, row):
			continue
		if model.secret_cells.has(Vector2i(col, row)):
			continue
		_echo_cell = Vector2i(col, row)
		return


func _check_echo(col: int, row: int) -> void:
	if _echo_cell.x < 0 or Vector2i(col, row) != _echo_cell:
		return
	_echo_cell = Vector2i(-1, -1)
	var info := variant.echo_info()
	if info.is_empty():
		return
	var at := LawnModel.cell_center(col, row)
	EchoLog.mark_found(variant_id)
	FindMarker.spawn(_fx_root, at, str(info.get("id", "")))
	AudioDirector.play_discovery()
	Haptics.light()
	Analytics.track(AnalyticsEvents.ECHO_FOUND,
		{"chapter": variant_id, "echo": info.get("id", "")})
	hud.show_echo_card(str(info["emoji"]), str(info["name"]), str(info["line"]),
		str(info.get("id", "")))


## Audio lives on the AudioDirector autoload, which outlives this scene, so a
## chapter has to hand back the engine when it leaves — otherwise the blade goes
## on spinning over the hub (G12.9).
func _exit_tree() -> void:
	AudioDirector.stop_engine()
