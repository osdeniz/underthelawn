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
var _glows: Array[SecretGlow] = []
var _collected: Array = []
var _complete_shown := false
## G7: the case has to be accepted before the search starts. While this is
## false the lawn ignores touches and the run clock has not begun.
var _search_started := false
## Which chapter this run is. Set by RootFlow before _ready; G9 builds the lawn
## from variant data keyed on it. A chapter is an ID, never a scene.
var variant_id := "ch01_aldridge"
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


## The variant has to be applied before ANY child _ready runs: EnvironmentBuilder
## builds the house and landmark in its own _ready, and child _ready always
## precedes the parent's. _enter_tree is the only hook early enough, and
## variant_id is already set by then because RootFlow assigns it before
## add_child().
func _enter_tree() -> void:
	variant = LevelVariant.of(variant_id)
	variant.apply()


func _ready() -> void:
	model = LawnModel.new(variant.decor_seed)
	scrap_field = ScrapField.new()
	scrap_field.name = "ScrapField"
	add_child(scrap_field)
	scrap_field.setup(model, variant.scrap_budget, variant.decor_seed)
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

	model.completed.connect(_on_completed)
	model.secret_revealed.connect(_on_secret_uncovered)
	hud.restart_pressed.connect(_restart)
	hud.selector.mower_chosen.connect(select_mower)

	hud.set_progress(0.0)
	hud.set_secret_count(0, GameConfig.SECRET_TOTAL)

	hud.return_requested.connect(_return_to_hub)
	hud.exit_confirmed.connect(_confirm_exit)
	hud.next_chapter_requested.connect(_next_chapter)

	_apply_quality()
	_activate(GameConfig.MOWER_PUSH, true)
	AudioDirector.start_ambient()

	# G8: the briefing moved to RootFlow's DialogueBox, so by the time this
	# scene exists the case has already been accepted.
	if autostart_search:
		_begin_search()


func _process(_delta: float) -> void:
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
		print("[Game] sahnede eksik mower koddan eklendi: %s" % GameConfig.MOWER_TYPES[i]["id"])
		_mower_root.add_child(built)
		built.model = model
		built.tuft_field = lawn.tuft_field
		built.cells_mown.connect(_on_cells_mown)
		built.set_active(false)
		_mowers.insert(i, built)


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


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	# The intro cards and the briefing are modal: the lawn hears nothing.
	if not _search_started:
		return
	if mower == null:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			# A tap on a shimmer collects it instead of commanding the mower.
			var glow := _pick_glow(touch.position)
			if glow != null:
				_collect(glow)
				return
			mower.on_touch_pressed(touch.index, touch.position)
		else:
			mower.on_touch_released(touch.index, touch.position)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		mower.on_touch_dragged(drag.index, drag.position)


## Ray/sphere test against every live shimmer (§16 uses camera.project_ray).
func _pick_glow(screen_pos: Vector2) -> SecretGlow:
	if _glows.is_empty():
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var best: SecretGlow = null
	var best_distance := INF
	for glow in _glows:
		if glow == null or glow.is_taken:
			continue
		var radius := glow.tap_radius()
		var oc := origin - glow.global_position
		var b := oc.dot(dir)
		var c := oc.dot(oc) - radius * radius
		var disc := b * b - c
		if disc < 0.0:
			continue
		var hit := -b - sqrt(disc)
		if hit < 0.0:
			hit = -b + sqrt(disc)
		if hit < 0.0 or hit >= best_distance:
			continue
		best_distance = hit
		best = glow
	return best


# ---------------------------------------------------------------- secrets

func _on_secret_uncovered(col: int, row: int) -> void:
	var kind := model.secret_cells.find(Vector2i(col, row))
	if kind < 0:
		kind = 0
	var glow := SecretGlow.new()
	glow.name = "SecretGlow_%d_%d" % [col, row]
	_fx_root.add_child(glow)
	glow.setup(Vector2i(col, row), kind, LawnModel.cell_center(col, row))
	_glows.append(glow)
	Haptics.medium()


func _collect(glow: SecretGlow) -> void:
	var ground := Vector3(glow.global_position.x, 0.0, glow.global_position.z)
	var kind := glow.kind
	_glows.erase(glow)
	glow.take()

	DigBurst.spawn(_fx_root, ground)

	var item := SecretItem.new()
	item.name = "SecretItem_%d" % kind
	_fx_root.add_child(item)
	item.setup(kind, ground)

	AudioDirector.play_discovery()
	Haptics.success()

	var info := variant.evidence_info(kind) if variant != null else {}
	if info.is_empty():
		info = SecretItem.info_for(kind)
	_collected.append({ "emoji": info["emoji"], "name": info["name"] })
	hud.show_secret_card(info["emoji"], info["name"], info["line"],
		func() -> void:
			hud.set_secret_count(_collected.size(), _evidence_total())
			if _collected.size() >= _evidence_total():
				_offer_exit())


# ---------------------------------------------------------------- progress

func _on_cells_mown(_count: int) -> void:
	hud.set_progress(model.completion_ratio())


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
		hud.show_complete(model.mowed_count, GameState.format_elapsed(),
			_collected, _evidence_total(), payout, _next_chapter_name()))


## Restart: model reset (secrets redistributed), tint map cleared, tufts back
## up, shimmers and items cleared, back to the push mower.
func _restart() -> void:
	for glow in _glows:
		if glow != null and is_instance_valid(glow):
			glow.queue_free()
	_glows.clear()
	for child in _fx_root.get_children():
		child.queue_free()
	_collected.clear()
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
	cam.descend_to(GameConfig.MOWER_CAMERA[_active_index], 2.4)
	hud.show_opening_title()
	hud.show_drive_hint()
	GameState.start_run()


# ---------------------------------------------------------------- G9 economy

## How many pieces of evidence this chapter hides. From the variant, so a future
## chapter can carry a different number without touching the HUD.
func _evidence_total() -> int:
	if variant != null and variant.evidence_count() > 0:
		return variant.evidence_count()
	return GameConfig.SECRET_TOTAL


func _on_scrap_found(col: int, row: int, value: int) -> void:
	_scrap_banked += value
	var at := LawnModel.cell_center(col, row)
	ScrapPop.spawn(_fx_root, at)
	hud.fly_scrap(value, cam.unproject_position(at + Vector3.UP * 0.6))
	hud.set_scrap(GameState.scrap_total() + _scrap_banked)
	AudioDirector.play_scrap()
	Haptics.light()


## The end-of-chapter scrap breakdown.
func _payout() -> Dictionary:
	var budget := variant.scrap_budget if variant != null else 9
	return ScrapField.payout(_scrap_banked, model.completion_ratio(), budget)


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
