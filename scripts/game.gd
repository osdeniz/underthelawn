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
## Which mid-chapter conversations have already played this run (G13).
var _mid_chat_done: Dictionary = {}
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
var _food_banked := 0
## Seconds actually spent searching, which is what the town is billed for.
var _search_seconds := 0.0
var _walker: Walker
var _animals: Animals
## G15.5: pieces driven over instead of uncovered, read by RootFlow to pick the
## debrief; and whether the two one-time hints have shown.
var crushed_count := 0
var _walk_hint_shown := false
## G15.6: the figure on the ridge at the listening post, and whether he has gone.
var _observer: Node3D
var _observer_gone := false
var _harvest_settler: Node3D
var _look_hold := 0.0
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
		controller.food_found.connect(_on_food_found)
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
	model.secret_crushed.connect(_on_secret_crushed)
	_build_reeds()
	_observer = find_child("Observer", true, false) as Node3D
	_build_harvest_settler()
	hud.restart_pressed.connect(_restart)
	hud.selector.mower_chosen.connect(select_mower)

	hud.set_progress(0.0)
	hud.set_secret_count(0, GameConfig.SECRET_TOTAL)
	if variant != null and variant.is_harvest():
		hud.apply_harvest_mode()
	elif variant != null and variant.is_road():
		hud.apply_road_mode()
	elif variant != null and not variant.time_lapse.is_empty():
		hud.apply_lapse_mode()

	hud.return_requested.connect(_return_to_hub)
	hud.main_menu_requested.connect(_return_to_main_menu)
	hud.walk_toggled.connect(toggle_walk)
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
	# The swarm and the far windows belong to the hour too, and the HUD is what
	# knows how to reach them (G14.6).
	hud.refresh_sky()
	# Things that live in the grass (G14.25). Built here rather than in the
	# Neighborhood because every one of them reads the LAWN — the rabbit needs
	# uncut ground to sit in and the birds need cut ground to land on — and the
	# model belongs to this node.
	_animals = Animals.build(_fx_root, model, variant.decor_seed,
		variant.is_harvest(), variant.vignette)
	_activate(GameConfig.MOWER_PUSH, true)
	# The yard's own sound (G16.1): a bed for the hour instead of the hub theme
	# running on, rain when it is wet, crickets after dark, the lamp on the
	# prologue's gate. Birds stay out of play (G9.4).
	var hour := SkyTime.resolve(variant.time_of_day)
	AudioDirector.set_scene(hour, Rain.is_wet(), variant.is_road())
	AudioDirector.play_bed(hour)

	# G8: the briefing moved to RootFlow's DialogueBox, so by the time this
	# scene exists the case has already been accepted.
	if variant != null and variant.signal_layers:
		AudioDirector.start_signal()

	if autostart_search:
		_begin_search()


## The first time a resource is ever picked up, say what it is for (G14.23).
## Once per resource, ever, recorded in the save — and it does not pause the
## game: the mower keeps rolling behind the card.
func _first_pickup_tip(key: String, title: String, line: String) -> void:
	if bool(GameState.get_setting("tips", key, false)):
		return
	GameState.set_setting("tips", key, true)
	hud.show_resource_tip(tr(title), tr(line))
	Analytics.track("resource_tip", {"kind": key})


## What the driver has noticed, refreshed a few times a second rather than
## every frame: the nearest thing still lying in the grass, and nothing at all
## when there is none in range (G14.22). Held for a moment once chosen, or the
## head snaps between two equidistant crates every frame.
func _update_look_target(delta: float) -> void:
	if character == null or not is_instance_valid(character):
		return
	_look_hold = maxf(_look_hold - delta, 0.0)
	if _look_hold > 0.0:
		return
	var eye := character.global_position
	var best := Vector3.ZERO
	var best_distance := GameConfig.LOOK_RANGE
	var found := false
	if scrap_field != null and is_instance_valid(scrap_field):
		for any: Variant in scrap_field.pending_cells():
			var cell: Vector2i = any
			var at := LawnModel.cell_center(cell.x, cell.y)
			var d := eye.distance_to(at)
			if d < GameConfig.LOOK_MIN or d >= best_distance:
				continue
			best_distance = d
			best = at + Vector3.UP * 0.5
			found = true
	character.look_has = found
	if found:
		character.look_target = best
	_look_hold = GameConfig.LOOK_HOLD


## Where the animals think the player is. It is the MACHINE that startles them
## when one is being driven and the man when he is on foot — a robot mower is
## exactly as alarming to a rabbit as a person is, and the blade more so.
func _update_animals() -> void:
	if _animals == null or not is_instance_valid(_animals):
		return
	if _walker != null and is_instance_valid(_walker) and _walker.visible:
		_animals.player_at = _walker.global_position
		_animals.player_on = true
	elif mower != null and is_instance_valid(mower) and mower.visible:
		_animals.player_at = mower.global_position
		_animals.player_on = true
	else:
		_animals.player_on = false


func _process(delta: float) -> void:
	# The town's clock runs while the search does — not while the app is open,
	# and not while it is closed (G14.13).
	if not _complete_shown:
		_search_seconds += delta
	_update_look_target(delta)
	_update_animals()
	_tick_lapse()
	_check_walk_only()
	_check_observer()
	_sway_settler(delta)
	_tick_orientation(delta)
	_check_pickups()
	if mower != null and hud != null:
		hud.set_pad_state(mower.pad_engaged(), mower._pad_origin, mower._pad_now)
	if mower == null:
		return
	# Steering and swipes are camera-relative, so every mower needs the yaw —
	# and so does the walker, which reads the same stick (G14.16).
	mower.camera_yaw = cam.yaw
	if _walker != null and is_instance_valid(_walker):
		_walker.camera_yaw = cam.yaw
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
		built.food_found.connect(_on_food_found)
		built.scrap_field = scrap_field
		built.set_active(false)
		_mowers.insert(i, built)


## Counts down to the first-run hint, then stops. Driven from _process rather
## than a timer so pausing the game pauses the countdown too.
##
## G14.23: the SHEET is gone. It paused the tree four seconds into a player's
## very first lawn — the exact moment they had just started mowing — and read
## as an interruption rather than as help. What it was actually for (a first-run
## player knowing what "search" means) is done by the half that never blocked:
## the two buried finds are marked, once, and the Marshal still speaks early.
func _tick_orientation(delta: float) -> void:
	if _orientation_due <= 0.0:
		return
	_orientation_due -= delta
	if _orientation_due > 0.0:
		return
	_orientation_due = 0.0
	GameState.mark_orientation_done()
	Analytics.track(AnalyticsEvents.ORIENTATION_SHOWN, {"chapter": variant_id})
	_on_orientation_closed()


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


## The chapters on the east road are a journey, and a journey has conversations
## in the middle of it (G13). A chapter can name `mid_chat` in levels.json and
## get a short scripted exchange partway through — the dialogue box, not a
## toast, because these lines are people talking rather than the game hinting.
##
## The mow pauses under it for the same reason the briefing does: a line worth
## reading is worth not driving through.
func _check_mid_chat(ratio: float) -> void:
	if variant == null or _complete_shown:
		return
	var marks: Array = variant.mid_chat_marks()
	for i in marks.size():
		if _mid_chat_done.has(i):
			continue
		if ratio < float(marks[i]):
			continue
		_mid_chat_done[i] = true
		var key := variant.mid_chat_key(i)
		var lines := Dialogue.conversation(key)
		if lines.is_empty():
			return
		# The harvest chat is ABOUT a settler, so it needs one (G15.6).
		if key == GameConfig.HARVEST_CHAT_KEY:
			if Settlers.accepted().is_empty():
				return
			lines = _settler_lines(lines)
		_play_mid_chat(lines)
		return


func _play_mid_chat(lines: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var box := DialogueBox.new()
	layer.add_child(box)
	get_tree().paused = true
	box.finished.connect(func() -> void:
		get_tree().paused = false
		layer.queue_free())
	box.play(lines)


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
	# Changing machine while on foot would leave the walker holding a mower
	# that is no longer the one being driven.
	if _walker != null and is_instance_valid(_walker):
		_walker.queue_free()
		_walker = null
		hud.set_walking(false, false)
		cam.target = null
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


# ---------------------------------------------------------------- on foot

## Step down and walk (G14.16).
##
## For the push mower and the tractor the machine stops where it is: nothing is
## cut on foot, and that is the point — walking is for reaching a crate the
## tractor cannot turn into and for being in the yard rather than driving over
## it. For the robot and the blade the machine KEEPS WORKING, because both were
## already doing it themselves and the driver was already standing at the edge
## watching; stepping down there just moves the camera to the person who was
## always there.
func toggle_walk() -> void:
	if _walker != null and is_instance_valid(_walker):
		_remount()
		return
	_dismount()


func walking() -> bool:
	return _walker != null and is_instance_valid(_walker)


func _dismount() -> void:
	if mower == null or _complete_shown:
		return
	var autonomous := _active_index == GameConfig.MOWER_ROBOT \
		or _active_index == GameConfig.MOWER_BLADE
	# Only a driven machine stops — and it PARKS rather than deactivating, so it
	# is still standing in the yard to walk back to.
	if not autonomous:
		mower.set_parked(true)
	_walker = Walker.new()
	_walker.name = "Walker"
	add_child(_walker)
	# Step off to the side of the machine, not into it.
	var beside := mower.position + Vector3(cos(mower.yaw + PI * 0.5), 0.0,
		sin(mower.yaw + PI * 0.5)) * 1.1
	_walker.setup(mower, character, beside)
	_walker.camera_yaw = cam.yaw
	cam.target = _walker
	cam.set_preset(GameConfig.WALK_CAMERA, 0.0)
	hud.set_walking(true, autonomous)
	if not autonomous:
		AudioDirector.stop_engine()
	Analytics.track("walk_started", {"mower": _active_index})


func _remount() -> void:
	if _walker == null or not is_instance_valid(_walker):
		return
	# Too far from the machine and the button says so rather than teleporting
	# the player back into a seat across the yard.
	if not _walker.in_reach():
		hud.nudge_remount()
		return
	_walker.queue_free()
	_walker = null
	cam.target = mower
	var gain := GameConfig.TRACTOR_LOOKAHEAD_GAIN \
		if _active_index == GameConfig.MOWER_TRACTOR else 0.0
	cam.set_preset(GameConfig.MOWER_CAMERA[_active_index], gain)
	mower.set_parked(false)
	AudioDirector.set_engine_profile(_active_index)
	_place_character(_active_index)
	hud.set_walking(false, false)


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
## The man on the ridge (G15.6). Once the machine — or the man on foot — is
## within range he is gone, and the Marshal says so. Not a chase and not a
## reveal: the whole point is that he was there and now is not.
func _check_observer() -> void:
	if _observer == null or _observer_gone or not _search_started:
		return
	var who: Node3D = _walker if _walker != null and is_instance_valid(_walker) else mower
	if who == null or not is_instance_valid(who):
		return
	if who.global_position.distance_to(_observer.global_position) \
			> GameConfig.OBSERVER_VANISH_RANGE:
		return
	_observer_gone = true
	_observer.visible = false
	var lines := Dialogue.conversation("chat_ch14_observer")
	if not lines.is_empty():
		_play_mid_chat(lines)


## The newest settler, by the barn, while the field is cut (G15.6). Only once
## somebody has actually been taken in: a harvest before that is still work
## with nobody at it, which is the truth of it.
func _build_harvest_settler() -> void:
	if variant == null or not variant.is_harvest():
		return
	var accepted := Settlers.accepted()
	if accepted.is_empty():
		return
	# accepted() returns the SPECS, not ids. The first pass wrapped one in str()
	# and looked it up by that, got {} back, and dressed and named nobody.
	var spec: Dictionary = accepted[accepted.size() - 1]
	var figure := Node3D.new()
	figure.name = "HarvestSettler"
	# Just past the north fence, to one side of the barn door: rendered at
	# house_pos_z() + 3.6 the figure stood INSIDE the barn's footprint and the
	# shot showed a red wall and nobody. Here it is against the wheat, head and
	# shoulders above the crop from the player's low camera.
	# INSIDE the fence, on the bare strip between the crop and the posts: past
	# the fence is the barn's footprint (it is deep), and two renders in a row
	# showed a red wall and nobody.
	# BESIDE the barn, not in front of it. Probed: the barn's box runs to z -18.0
	# on the harvest grid — a unit past the lawn edge — so every spot in front
	# of its door is inside it, which is why three renders showed a red wall.
	# Its half-width is 5.7; the figure stands clear of that on the fence strip.
	figure.position = Vector3(7.6, 0.0, GameConfig.fence_north_z() + 0.5)
	# Facing the field (+Z), which the model does by turning its -Z round.
	figure.rotation.y = PI
	_fx_root.add_child(figure)
	var kit: Dictionary = GameConfig.CHAR_OUTFITS[
		absi(str(spec.get("id", "")).hash()) % GameConfig.CHAR_OUTFITS.size()]
	var coat := StandardMaterial3D.new()
	coat.albedo_color = kit["shirt"]
	var jeans := StandardMaterial3D.new()
	jeans.albedo_color = kit["jeans"]
	var hat := StandardMaterial3D.new()
	hat.albedo_color = kit["hat"]
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.78, 0.62, 0.50)
	_prim(figure, BoxMesh.new(), Vector3(0.48, 0.70, 0.28), coat, Vector3(0.0, 1.05, 0.0))
	_prim(figure, SphereMesh.new(), Vector3(0.32, 0.32, 0.32), skin, Vector3(0.0, 1.56, 0.0))
	_prim(figure, CylinderMesh.new(), Vector3(0.42, 0.05, 0.42), hat, Vector3(0.0, 1.72, 0.0))
	for side: float in [-1.0, 1.0]:
		_prim(figure, BoxMesh.new(), Vector3(0.15, 0.70, 0.15), jeans,
			Vector3(side * 0.12, 0.35, 0.0))
	_harvest_settler = figure


## One primitive on `parent`, sized through scale so the same call builds a box,
## a ball or a disc.
func _prim(parent: Node3D, mesh: Mesh, size: Vector3, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x * 0.5
		(mesh as SphereMesh).height = size.x
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x * 0.5
		(mesh as CylinderMesh).bottom_radius = size.x * 0.5
		(mesh as CylinderMesh).height = size.y
	parent.add_child(mi)


## A figure that stands perfectly still is a post; this one breathes.
func _sway_settler(delta: float) -> void:
	if _harvest_settler == null or not is_instance_valid(_harvest_settler):
		return
	_harvest_settler.rotation.z = sin(_search_seconds * 0.9) * 0.02
	_harvest_settler.position.y = absf(sin(_search_seconds * 1.7)) * 0.01


## The lines of a mid-chat with the newest settler's NAME written in (G15.6).
## Dialogue keys are translated by the box; a line handed to it already
## translated passes through unchanged, which is what lets one key serve every
## settler. `{settler}` is the placeholder.
func _settler_lines(lines: Array) -> Array:
	var accepted := Settlers.accepted()
	if accepted.is_empty():
		return lines
	var spec: Dictionary = accepted[accepted.size() - 1]
	var who := tr(str(spec.get("name", "")))
	var out: Array = []
	for any: Variant in lines:
		var line: Dictionary = (any as Dictionary).duplicate()
		if line.has("text"):
			line["text"] = tr(str(line["text"])).replace("{settler}", who)
		out.append(line)
	return out


## The fragile piece was driven over (G15.5): it is still found, and it is not
## whole. The prop lies tilted and half in the ground, the debrief says so, and
## Cole's note for it changes.
func _on_secret_crushed(col: int, row: int) -> void:
	crushed_count += 1
	Haptics.medium()
	# Remembered against the piece, so the corkboard reads Cole's torn-copy note
	# for it from now on (LevelVariant.evidence_info).
	if variant != null:
		var kind := model.secret_cells.find(Vector2i(col, row))
		var info := variant.evidence_info(maxi(kind, 0))
		GameState.set_setting("evidence_crushed",
			"%s/%s" % [variant.id, str(info.get("id", ""))], true)
	for prop in _evidence_props:
		if prop != null and is_instance_valid(prop) \
				and prop.name == "Evidence_%d_%d" % [col, row]:
			prop.set_meta("crushed", true)
			prop.rotation = Vector3(0.42, 0.6, -0.35)
			prop.position.y -= 0.08


## The one piece behind the reeds is found on FOOT (G15.5): the walker steps into
## the ring and it is uncovered. On the machine, the first time the player comes
## up against the reeds, one card says why the mower is not the answer here.
func _check_walk_only() -> void:
	if model == null or model.walk_only_cell.x < 0 or not _search_started:
		return
	var cell := model.walk_only_cell
	if model.states[LawnModel.index_of(cell.x, cell.y)] != LawnModel.CellState.SECRET:
		return
	var at := LawnModel.cell_center(cell.x, cell.y)
	if _walker != null and is_instance_valid(_walker):
		if Vector2(_walker.position.x - at.x, _walker.position.z - at.z).length() \
				<= GameConfig.WALK_ONLY_REACH:
			model.reveal(cell.x, cell.y)
			if lawn != null and lawn.tuft_field != null:
				lawn.tuft_field.refresh_all()
		return
	if not _walk_hint_shown and mower != null and is_instance_valid(mower) \
			and Vector2(mower.position.x - at.x, mower.position.z - at.z).length() \
			<= GameConfig.WALK_ONLY_HINT_RANGE:
		_walk_hint_shown = true
		hud.show_resource_tip(tr("HUD_WALK_TIP_T"), tr("HUD_WALK_TIP_L"))


## Reeds around the walk-only piece, built here rather than in the Neighborhood
## because only the MODEL knows where the secret landed, and the Neighborhood
## is ready before the model exists (G15.5).
func _build_reeds() -> void:
	if model == null or model.walk_only_cell.x < 0:
		return
	var cell := model.walk_only_cell
	var root := Node3D.new()
	root.name = "Reeds"
	_fx_root.add_child(root)
	var stalk := StandardMaterial3D.new()
	stalk.albedo_color = GameConfig.REED_COLOUR
	stalk.roughness = 0.9
	var head := StandardMaterial3D.new()
	head.albedo_color = GameConfig.REED_HEAD_COLOUR
	head.roughness = 0.95
	var rng := RandomNumberGenerator.new()
	rng.seed = variant.decor_seed + 4411 if variant != null else 4411
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if dr == 0 and dc == 0:
				continue
			var centre := LawnModel.cell_center(cell.x + dc, cell.y + dr)
			for _i in GameConfig.REEDS_PER_CELL:
				var height := rng.randf_range(GameConfig.REED_HEIGHT.x, GameConfig.REED_HEIGHT.y)
				var pivot := Node3D.new()
				pivot.position = centre + Vector3(rng.randf_range(-0.42, 0.42), 0.0,
					rng.randf_range(-0.42, 0.42))
				pivot.rotation = Vector3(rng.randf_range(-0.08, 0.08), 0.0,
					rng.randf_range(-0.08, 0.08))
				root.add_child(pivot)
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.018
				mesh.bottom_radius = 0.03
				mesh.height = height
				mesh.radial_segments = 5
				mesh.rings = 1
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = stalk
				mi.position.y = height * 0.5
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				pivot.add_child(mi)
				var tip := CylinderMesh.new()
				tip.top_radius = 0.03
				tip.bottom_radius = 0.05
				tip.height = 0.22
				tip.radial_segments = 5
				tip.rings = 1
				var ti := MeshInstance3D.new()
				ti.mesh = tip
				ti.material_override = head
				ti.position.y = height + 0.1
				ti.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				pivot.add_child(ti)


## The one chapter whose light moves (G15.5): from its hour to the next over
## the length of the search. No fail state — an unfinished yard is finished
## in the dark — but the dark is not free (G18.1): the machine slows once
## night falls, and a slow yard eats more of the town's food.
var _lapse_bucket := ""
func _tick_lapse() -> void:
	if variant == null or variant.time_lapse.is_empty() or not _search_started \
			or _complete_shown:
		return
	var seconds := maxf(float(variant.time_lapse.get("seconds", 150.0)), 1.0)
	var t := clampf(_search_seconds / seconds, 0.0, 1.0)
	var from := str(variant.time_lapse.get("from", variant.time_of_day))
	var to := str(variant.time_lapse.get("to", variant.time_of_day))
	SkyTime.blend($WorldEnvironment as WorldEnvironment, $Sun as DirectionalLight3D,
		from, to, t)
	# The penalty: top speed follows the light down. Every frame, because the
	# slide is continuous; the mower reads it on its next max_speed() call.
	if mower != null:
		mower.speed_scale = GameConfig.dark_speed_scale(t)
	# The hour-bucketed things (fireflies, far windows, moth clippings) switch
	# once, at the onset, rather than every frame.
	var bucket := from if t < GameConfig.DARK_ONSET else to
	if bucket != _lapse_bucket:
		_lapse_bucket = bucket
		variant.time_of_day = bucket
		hud.refresh_sky()
		if bucket == to:
			hud.apply_dark_mode()
		# The sound follows the light: crickets come in with the dark, and the
		# bed changes if the hour crosses into the evening set.
		AudioDirector.set_scene(SkyTime.resolve(bucket), Rain.is_wet(), false)
		AudioDirector.play_bed(SkyTime.resolve(bucket))


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
	_check_mid_chat(model.completion_ratio())
	# The listening post's radio tunes itself as the ground opens (G13).
	if variant != null and variant.signal_layers:
		AudioDirector.set_signal_clarity(model.completion_ratio())
	# The echo is revealed by cutting its cell, same as evidence — but silently,
	# with no marker until it is actually picked up.
	if _echo_cell.x >= 0 and model.is_cut(_echo_cell.x, _echo_cell.y):
		_check_echo(_echo_cell.x, _echo_cell.y)


func _on_completed() -> void:
	if _complete_shown:
		return
	_complete_shown = true
	GameState.finish_run()
	# The run is over, so the machine is too. stop_engine only ran in
	# _exit_tree, when the scene is destroyed — but the reward shot and the
	# results panel both play while the scene is still ALIVE, so the mower went
	# on idling underneath "area searched" for as long as the player read it
	# (G13). set_engine_profile clears the latch when the next chapter starts.
	AudioDirector.stop_engine()
	# And it stops being driven: the panel covers the controls but the mower was
	# still simulated under it, so a finger left on the pad kept it moving.
	if mower != null and is_instance_valid(mower):
		mower.set_active(false)
	cam.set_bird_view(true)
	hud.flash()
	Haptics.success()
	# Let the bird's-eye reward land before the panel covers it.
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(func() -> void:
		if variant != null and variant.is_road():
			# The prologue pays nothing and was searching for nothing, so it
			# gets no payout, no meals and no results panel: "area searched,
			# 0 evidence, 0 scrap" over a road would be a lie told by a
			# template. The flow takes it from here (G15.1).
			search_finished.emit(0, 0)
			return
		var payout := _payout()
		GameState.add_scrap(int(payout["total"]))
		hud.set_scrap(GameState.scrap_total())
		# Food is banked and the town's share is eaten in the same breath, so
		# the panel can show both and the arithmetic is never split across two
		# screens (G14.12). A harvest FEEDS the town and does not cost it a
		# day's meals — that is the whole point of the field.
		TownStats.add_food(_food_banked)
		# The town ate for as long as this search actually took (G14.13), which
		# is why the clock is the LEVEL's, not the wall's: a player reading the
		# case board is not costing anyone a meal.
		var eaten := 0
		if variant == null or not variant.is_harvest():
			var before := TownStats.food()
			TownStats.eat(_days_elapsed())
			eaten = before - TownStats.food()
		payout["food"] = _food_banked
		payout["food_eaten"] = eaten
		payout["food_left"] = TownStats.food()
		hud.set_food(TownStats.food())
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
	_mid_chat_done.clear()
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
## Out of the level and out of the game, in one tap. The flow above owns the
## menu, so this only asks (G14.9).
func _return_to_main_menu() -> void:
	var root := get_parent()
	if root != null and root.has_method("return_to_main_menu"):
		root.return_to_main_menu()


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
	# The fallback below exists for the bare scene run with no variant data.
	# A road is not that: it has data, and the data says there is nothing to
	# find (G15.2).
	if variant != null and (variant.is_road() or variant.is_harvest()):
		return 0
	return GameConfig.SECRET_TOTAL


func _on_scrap_found(col: int, row: int, value: int) -> void:
	_scrap_banked += value
	_first_pickup_tip("money", "TIP_MONEY_TITLE", "TIP_MONEY_LINE")
	if carry != null:
		carry.add_salvage()
	var at := LawnModel.cell_center(col, row)
	hud.fly_scrap(value, cam.unproject_position(at + Vector3.UP * 0.6))
	hud.set_scrap(GameState.scrap_total() + _scrap_banked)
	AudioDirector.play_scrap()
	Haptics.light()


## Food comes out of the grass the same way money does, and is banked the same
## way: held until the chapter ends, so quitting a level mid-run cannot farm it
## (G14.12).
func _on_food_found(col: int, row: int, value: int) -> void:
	_food_banked += value
	_first_pickup_tip("food", "TIP_FOOD_TITLE", "TIP_FOOD_LINE")
	var at := LawnModel.cell_center(col, row)
	hud.fly_food(value, cam.unproject_position(at + Vector3.UP * 0.6))
	hud.set_food(TownStats.food() + _food_banked)
	AudioDirector.play_food()
	Haptics.light()


## How many town-days this search took. Fractional on purpose: a fast run is
## cheaper than a slow one, which is the only pressure this resource applies.
func _days_elapsed() -> float:
	return maxf(_search_seconds / GameConfig.FOOD_DAY_SECONDS, 0.25)


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
	# And the chapter's own weighting on top (G13). Case 02 buries as much as
	# Case 01 does — the yards would feel empty otherwise — but what it PAYS is
	# scaled rather than what it hides.
	#
	# That scale was 0.32, on the belief that Case 02 lands in an economy with
	# nothing left to buy. Measured, the opposite was true: 14 410 of sinks
	# against 10 779 of income, with 5 560 of workshop upgrades that nothing
	# else funds. Ten bigger yards were the poorest hours in the game and full
	# completion quietly required farming two harvests. It is 0.68 now, which
	# puts the eighteen chapters at 1.04x of everything the game sells — see
	# tests/EconomyCheck.tscn, which measures this through these same
	# functions rather than restating them.
	if variant != null:
		multiplier *= variant.scrap_multiplier
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
## on spinning over the hub (G12.9). The listening post's signal pair is the
## same rule: it belongs to one chapter (G13).
func _exit_tree() -> void:
	AudioDirector.stop_engine()
	AudioDirector.stop_signal()
	# The yard's weather, night and bed leave with the yard (G16.1).
	AudioDirector.set_scene("", false, false)
	AudioDirector.stop_bed()
