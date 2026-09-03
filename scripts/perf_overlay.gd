extends CanvasLayer
## PerfOverlay autoload (G16.3): fps, draw calls and triangles in the corner of
## EVERY screen, when the player has turned it on in settings.
##
## For the device checklist (docs/DEVICE_TEST.md). Every performance number in
## this project so far came from a desktop; this is how the same numbers are
## read off a phone without a cable. Off by default, remembered in the save,
## and it costs one Label update a second when on — nothing when off.

const SECTION := "display"
const KEY := "perf_overlay"

var _label: Label
var _low := 999
var _since := 0.0


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -520
	_label.offset_top = 210
	_label.offset_right = -24
	_label.offset_bottom = 300
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_enabled(bool(GameState.get_setting(SECTION, KEY, false)))


func enabled() -> bool:
	return visible


func set_enabled(on: bool) -> void:
	visible = on
	set_process(on)
	GameState.set_setting(SECTION, KEY, on)
	_low = 999


func _process(delta: float) -> void:
	# The LOWEST fps in the last second is what a phone actually feels; the
	# average hides the hitch.
	var fps := int(Engine.get_frames_per_second())
	_low = mini(_low, fps)
	_since += delta
	if _since < 1.0:
		return
	_since = 0.0
	_label.text = "%d fps (min %d)\n%d cizim  %s ucgen\n%d MB" % [fps, _low,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		_short(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)]
	_low = 999


func _short(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 1000:
		return "%dk" % (n / 1000)
	return str(n)
