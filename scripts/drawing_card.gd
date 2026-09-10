class_name DrawingCard
extends Control
## One of Ellie's drawings, held up over whatever is behind it (G67).
##
## Used twice: once by itself when the chapter that earns it is finished, and
## again whenever the player taps it in the journal. Same node both times, so
## there is one place where a drawing is presented and one look to get right.
##
## The picture is a photograph of paper on a table, 4:3, and it is NOT veiled:
## the words go under it on the card's own dark ground instead of over it. A
## scrim heavy enough to carry white type over drawing_04 (a night scene, 79
## average against 130-136 for the daylight three) would have put the drawing
## itself out — the same trap G61 measured on the reunion card and G65 on the
## convoy.

signal finished()

var _index := -1
var _paper: TextureRect
var _column: VBoxContainer


## Sized from the VIEWPORT, which a node outside the tree does not have — the
## bug G59 found in the postcard view, where the card came out 639x0 on a real
## device because setup() ran before add_child(). Sized here, on _ready, and
## again whenever the viewport changes.
func _ready() -> void:
	_size_paper()
	get_viewport().size_changed.connect(_size_paper)


func _size_paper() -> void:
	if _paper == null or not is_instance_valid(_paper) or not is_inside_tree():
		return
	var view := get_viewport_rect().size
	if view.x < 240.0:
		return
	# Width first, then give back whatever does not fit in height: a 4:3 sheet
	# is short and wide, so on a phone the width decides and on a rotated
	# window or a desktop the height does.
	var wide := minf(GameConfig.UI_MAX_WIDTH - 80.0, view.x - 80.0)
	wide = minf(wide, (view.y - 520.0) * GameConfig.DRAWING_ASPECT)
	wide = maxf(wide, 240.0)
	_paper.custom_minimum_size = Vector2(wide, wide / GameConfig.DRAWING_ASPECT)
	# The words wrap at the picture's own width rather than the window's, so the
	# note reads as a caption under the sheet and not as a paragraph beside it.
	if _column != null and is_instance_valid(_column):
		_column.custom_minimum_size.x = wide


func play(index: int) -> void:
	_index = index
	var tex := Drawings.texture(index)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, GameConfig.DRAWING_SCRIM)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	# Centred by a container that owns the whole frame rather than by
	# PRESET_CENTER. Both centre correctly here (measured: the block spans 27%
	# to 73% of the phone frame, dead centre) — what this buys is the column
	# inside it, which is exactly as wide as the picture, so the note wraps to
	# the sheet and reads as its caption instead of running the full window.
	var rows := VBoxContainer.new()
	rows.name = "DrawingRows"
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)

	_column = VBoxContainer.new()
	_column.name = "DrawingColumn"
	_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_theme_constant_override("separation", GameConfig.UI_GAP_WIDE)
	rows.add_child(_column)

	_paper = TextureRect.new()
	_paper.name = "DrawingPaper"
	_paper.texture = tex
	_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The photograph is already of a sheet lying askew on a table; the tilt is
	# small, just enough that it reads as put down rather than pasted in.
	_paper.rotation = deg_to_rad(-1.0)
	_column.add_child(_paper)
	_size_paper()

	var title := Label.new()
	title.name = "DrawingTitle"
	title.text = Drawings.title(index)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	title.add_theme_color_override("font_color", GameConfig.UI_BRASS)
	_column.add_child(title)

	var line := Label.new()
	line.name = "DrawingLine"
	line.text = Drawings.line(index)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(0, 0)
	line.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	line.add_theme_color_override("font_color", GameConfig.UI_INK)
	line.add_theme_constant_override("line_spacing", 10)
	_column.add_child(line)

	var close := Button.new()
	close.name = "DrawingClose"
	close.text = TranslationServer.translate("POSTCARD_CLOSE")
	close.custom_minimum_size = Vector2(300, GameConfig.UI_TAP_MIN)
	close.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	close.pressed.connect(_close)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_child(close)
	_column.add_child(buttons)

	if tex == null:
		# Never on a shipped build (Drawings.pending_for checks first, and the
		# journal only lists what loaded), but a missing file must not leave a
		# card the player cannot get out of.
		TextureLibrary.warn_missing("story/" + Drawings.id_of(index),
			"cizim kartinda bos kagit")


func _gui_input(event: InputEvent) -> void:
	var touched := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if touched or clicked:
		accept_event()
		_close()


func _close() -> void:
	# Marked here rather than when the card is built: a drawing counts as shown
	# once the player has actually put it down.
	if _index >= 0:
		Drawings.mark_seen(_index)
	finished.emit()
	queue_free()
