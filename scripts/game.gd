class_name Game
extends Node3D
## Sprint G1 + G2 wiring: model -> view -> mower -> camera -> HUD, plus the
## secret discovery flow (§9, §16).
##
## Touch input arrives through _unhandled_input, so anything the HUD swallows
## never reaches the lawn. A press first tests the secret glows; only if it
## misses does it become a mower command.

@onready var lawn: LawnView = $Lawn
@onready var mower: Mower = $Mower
@onready var cam: CameraRig = $Camera3D
@onready var hud: Hud = $UI/HUD
@onready var _fx_root: Node3D = $Effects

var model: LawnModel

var _glows: Array[SecretGlow] = []
## One { emoji, name } per collected item, in collection order.
var _collected: Array = []
var _complete_shown := false


func _ready() -> void:
	model = LawnModel.new()
	lawn.setup(model)

	mower.model = model
	mower.tuft_field = lawn.tuft_field
	mower.reset_to_start()

	cam.target = mower
	cam.snap_to_target()

	model.completed.connect(_on_completed)
	mower.cells_mown.connect(_on_cells_mown)
	mower.secret_uncovered.connect(_on_secret_uncovered)
	hud.restart_pressed.connect(_restart)

	hud.set_progress(0.0)
	hud.set_secret_count(0, GameConfig.SECRET_TOTAL)
	GameState.start_run()
	AudioDirector.start_ambient()


func _process(_delta: float) -> void:
	# Steering is camera-relative, so the mower needs the camera's yaw.
	mower.camera_yaw = cam.yaw
	var turn := clampf(absf(mower.omega) / GameConfig.PUSH_MAX_TURN, 0.0, 1.0)
	AudioDirector.set_engine_state(mower.speed_fraction(), turn)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			# A tap on a shimmer collects it instead of driving the mower.
			var glow := _pick_glow(touch.position)
			if glow != null:
				_collect(glow)
				return
			mower.touch_pressed(touch.index, touch.position)
		else:
			mower.touch_released(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		mower.touch_dragged(drag.index, drag.position)


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
## up, shimmers and items cleared.
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
	mower.reset_to_start()
	cam.set_bird_view(false)
	cam.snap_to_target()
	hud.hide_complete()
	hud.set_progress(0.0)
	hud.set_secret_count(0, GameConfig.SECRET_TOTAL)
	GameState.start_run()
