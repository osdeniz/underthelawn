class_name Game
extends Node3D
## Sprints G1-G3 wiring: model -> view -> the selected mower -> camera -> HUD,
## the secret discovery flow (§9, §16) and the three-way mower picker.
##
## All three mowers live under Mowers; only one is visible and simulated. Touch
## input arrives through _unhandled_input (so HUD taps never reach the lawn),
## is offered to the secret shimmers first, and otherwise goes to the active
## mower, which interprets it according to its own control scheme (§7).

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
var _intro: IntroSequence


func _ready() -> void:
	model = LawnModel.new()
	lawn.setup(model)

	for child in _mower_root.get_children():
		var controller := child as MowerController
		if controller == null:
			continue
		controller.model = model
		controller.tuft_field = lawn.tuft_field
		controller.cells_mown.connect(_on_cells_mown)
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

	hud.briefing_accepted.connect(_begin_search)
	hud.replay_intro_requested.connect(_play_intro)

	_apply_quality()
	_activate(GameConfig.MOWER_PUSH, true)
	AudioDirector.start_ambient()

	# G7: opening cards on the very first launch, then the briefing. The clock
	# and the lawn stay untouched until the player accepts the case.
	if GameConfig.STORY_ALWAYS_REPLAY_INTRO or not _intro_seen():
		_play_intro()
	else:
		hud.show_briefing()


func _process(_delta: float) -> void:
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
	var carry_position := Vector3(GameConfig.MOWER_START.x, 0.0, GameConfig.MOWER_START.y)
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

	var info := SecretItem.info_for(kind)
	_collected.append({ "emoji": info["emoji"], "name": info["name"] })
	hud.show_secret_card(info["emoji"], info["name"], info["line"],
		func() -> void: hud.set_secret_count(_collected.size(), GameConfig.SECRET_TOTAL))


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
		hud.show_complete(model.mowed_count, GameState.format_elapsed(),
			_collected, GameConfig.SECRET_TOTAL))


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
	hud.set_secret_count(0, GameConfig.SECRET_TOTAL)
	GameState.start_run()


# ---------------------------------------------------------------- story (G7)

## Whether the opening has already been watched, persisted in settings.cfg.
func _intro_seen() -> bool:
	return bool(GameState.get_setting("story", "intro_seen", false))


func _play_intro() -> void:
	if _intro != null and is_instance_valid(_intro):
		return
	# Replaying from the STORY button: put the search back on hold so the
	# briefing runs again after the cards, exactly like a first launch.
	_search_started = false
	hud.hide_briefing()
	_intro = IntroSequence.new()
	_intro.name = "Intro"
	$UI.add_child(_intro)
	_intro.finished.connect(func() -> void:
		_intro = null
		GameState.set_setting("story", "intro_seen", true)
		hud.show_briefing())


## The briefing was accepted: drop the camera onto the property, hold the
## opening title, and start the clock.
func _begin_search() -> void:
	if _search_started:
		return
	_search_started = true
	cam.descend_to(GameConfig.MOWER_CAMERA[_active_index], 2.4)
	hud.show_opening_title()
	GameState.start_run()
