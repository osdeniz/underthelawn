class_name PhotoMode
extends Control
## The player's own camera (G47).
##
## The postcard has taken the same overhead shot of every yard since G27, and
## the machinery for it — a camera in a viewport of its own, a parchment mount,
## an album to keep it in — is exactly what a photo mode needs. So the yard
## holds still and the camera is handed over: drag to swing round it, zoom in
## and out, and the shutter puts a card in the same album the automatic ones
## go to.
##
## The yard is paused while this is open. A mower rolling through the frame
## would spoil the shot, and the town should not eat while somebody is
## composing a picture.

signal closed()

const LAYER := 80
const YAW_PER_PIXEL := 0.006
const PITCH_PER_PIXEL := 0.004
const PITCH_LIMIT := Vector2(0.12, 1.35)
const ZOOM_STEP := 0.16
const ZOOM_LIMIT := Vector2(0.45, 1.6)

var _game: Node3D
var _hud: Control
var _camera: Camera3D
var _was_current: Camera3D
var _layer: CanvasLayer
var _note: Label
var _yaw := 0.35
var _pitch := 0.62
var _zoom := 1.0
var _busy := false
var _band_top: ColorRect
var _band_bottom: ColorRect


## Opens over the yard, hiding the interface. Returns the node so a caller (or
## a test) can drive it.
static func open(game: Node3D, hud: Control) -> PhotoMode:
	if game == null:
		return null
	var mode := PhotoMode.new()
	mode.name = "PhotoMode"
	mode._game = game
	mode._hud = hud
	var layer := CanvasLayer.new()
	layer.name = "PhotoLayer"
	layer.layer = LAYER
	game.add_child(layer)
	layer.add_child(mode)
	mode._layer = layer
	return mode


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
	_was_current = _game.get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "PhotoCamera"
	_camera.fov = GameConfig.CAMERA_FOV
	# Same rule as the shutter's camera, so the band drawn on screen is
	# exactly what the card will hold (G47).
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_game.add_child(_camera)
	_camera.current = true
	_place()
	_build()
	get_tree().paused = true


func _build() -> void:
	# The frame: everything outside the card's own 3:2 band is dimmed, so what
	# the player composes is what the card keeps.
	for edge in [true, false]:
		var band := ColorRect.new()
		band.name = "PhotoBandTop" if edge else "PhotoBandBottom"
		band.color = Color(0.02, 0.02, 0.02, 0.72)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(band)
		if edge:
			_band_top = band
		else:
			_band_bottom = band
	_fit_bands()
	get_viewport().size_changed.connect(_fit_bands)

	var hint := Label.new()
	hint.name = "PhotoHint"
	hint.text = tr("PHOTO_HINT")
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 110
	hint.offset_bottom = 170
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 30)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	hint.add_theme_constant_override("shadow_offset_y", 2)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	_note = Label.new()
	_note.name = "PhotoNote"
	_note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_note.offset_left = -420
	_note.offset_right = 420
	_note.offset_top = 200
	_note.offset_bottom = 270
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 34)
	_note.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_note.add_theme_constant_override("shadow_offset_y", 2)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.visible = false
	add_child(_note)

	var bar := HBoxContainer.new()
	bar.name = "PhotoBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -260
	bar.offset_bottom = -120
	bar.offset_left = 60
	bar.offset_right = -60
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 26)
	add_child(bar)
	GameConfig.fit_wide(bar)

	bar.add_child(_round_button("PhotoOut", "−",
		func() -> void: _set_zoom(_zoom + ZOOM_STEP)))
	bar.add_child(_round_button("PhotoShutter", "◉", _shoot))
	bar.add_child(_round_button("PhotoIn", "+",
		func() -> void: _set_zoom(_zoom - ZOOM_STEP)))
	bar.add_child(_round_button("PhotoClose", "✕", close))


## The card is Postcard.PHOTO wide by high; at the screen's width that is a
## band this tall, centred. Above and below it, dimmed.
func _fit_bands() -> void:
	if _band_top == null or not is_instance_valid(_band_top):
		return
	var view := get_viewport_rect().size
	var band := view.x * float(Postcard.PHOTO.y) / float(Postcard.PHOTO.x)
	var top := maxf((view.y - band) * 0.5, 0.0)
	_band_top.position = Vector2.ZERO
	_band_top.size = Vector2(view.x, top)
	_band_bottom.position = Vector2(0.0, top + band)
	_band_bottom.size = Vector2(view.x, maxf(view.y - top - band, 0.0))


func _round_button(node_name: String, glyph: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = glyph
	button.custom_minimum_size = Vector2(
		GameConfig.UI_TAP_MIN + 24, GameConfig.UI_TAP_MIN + 24)
	button.add_theme_font_size_override("font_size", 44)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.10, 0.92)
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(60)
	button.add_theme_stylebox_override("normal", style)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.17, 0.15, 0.11, 0.97)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	button.pressed.connect(func() -> void:
		Haptics.light()
		on_press.call())
	return button


## Where the camera sits for the current yaw, pitch and zoom: on a sphere
## around the middle of the yard, always looking at it.
func _place() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var reach := maxf(GameConfig.HALF_X, GameConfig.HALF_Z) * 2.1 * _zoom
	var flat := cos(_pitch) * reach
	_camera.position = Vector3(sin(_yaw) * flat, sin(_pitch) * reach, cos(_yaw) * flat)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, ZOOM_LIMIT.x, ZOOM_LIMIT.y)
	_place()


## Drag anywhere: sideways swings round the yard, up and down raises and lowers
## the eye. Clamped short of the ground and short of straight down, because
## both of those are pictures of nothing.
func _gui_input(event: InputEvent) -> void:
	var moved := Vector2.ZERO
	var drag := event as InputEventScreenDrag
	if drag != null:
		moved = drag.relative
	var mouse := event as InputEventMouseMotion
	if mouse != null and (mouse.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		moved = mouse.relative
	if moved == Vector2.ZERO:
		return
	accept_event()
	swing(moved)


func swing(by: Vector2) -> void:
	_yaw = wrapf(_yaw - by.x * YAW_PER_PIXEL, -PI, PI)
	_pitch = clampf(_pitch + by.y * PITCH_PER_PIXEL, PITCH_LIMIT.x, PITCH_LIMIT.y)
	_place()


## The shutter: the same card the finished yard makes, from here instead of
## from above, kept in the same album under its own name.
func _shoot() -> void:
	if _busy or _camera == null:
		return
	_busy = true
	var photo: Image = await Postcard.capture_from(_game, _camera.position,
		Vector3.ZERO, _camera.fov, true)
	if photo == null:
		_busy = false
		return
	var subtitle := ""
	if _game.has_method("_postcard_subtitle"):
		subtitle = str(_game.call("_postcard_subtitle"))
	var yard := Postcard.title_for(str(_game.get("variant_id")))
	var card: Image = await Postcard.compose(self, photo, yard, subtitle,
		tr("POSTCARD_PHOTO"))
	if card == null:
		_busy = false
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Postcard.DIR))
	var id := "photo_%d" % Time.get_unix_time_from_system()
	var path := Postcard.path_for(id)
	if card.save_png(path) == OK:
		_note.text = tr("PHOTO_SAVED")
		_note.visible = true
		Haptics.success()
		Analytics.track(AnalyticsEvents.PHOTO_TAKEN, {"chapter": str(_game.get("variant_id"))})
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if is_instance_valid(_note):
				_note.visible = false)
	_busy = false


func close() -> void:
	get_tree().paused = false
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = true
	if _camera != null and is_instance_valid(_camera):
		_camera.queue_free()
	# Hand the view back to whichever camera had it, rather than trusting that
	# freeing this one restores the last.
	if _was_current != null and is_instance_valid(_was_current):
		_was_current.current = true
	closed.emit()
	if _layer != null and is_instance_valid(_layer):
		_layer.queue_free()
