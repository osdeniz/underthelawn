extends Control
## The one card that asks for money (G16.6). Shown after the third chapter's
## debrief and whenever a gated chapter is chosen. It says what is left, offers
## the rest for one price, and gets out of the way. No timer, no countdown, no
## second ask on the same screen.

signal finished(bought: bool)

var _closing := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.02, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(980, 0)
	panel.offset_left = -490
	panel.offset_right = 490
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.08, 0.08, 0.07, 0.97)
	skin.set_corner_radius_all(26)
	skin.set_border_width_all(2)
	skin.border_color = Color(GameConfig.CASE_ACCENT, 0.7)
	skin.set_content_margin_all(48)
	panel.add_theme_stylebox_override("panel", skin)
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	panel.add_child(column)

	var title := Label.new()
	title.text = tr("DEMO_TITLE")
	title.add_theme_font_size_override("font_size", GameConfig.fs(GameConfig.UI_HEAD))
	title.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	column.add_child(title)

	var line := Label.new()
	line.text = tr("DEMO_LINE")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", GameConfig.fs(GameConfig.UI_LABEL))
	line.add_theme_color_override("font_color", GameConfig.UI_INK)
	column.add_child(line)

	var buy := Button.new()
	buy.name = "Buy"
	buy.text = tr("DEMO_BUY")
	buy.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	buy.add_theme_font_size_override("font_size", GameConfig.fs(GameConfig.UI_LABEL))
	buy.pressed.connect(_on_buy)
	column.add_child(buy)

	var later := Button.new()
	later.name = "Later"
	later.text = tr("DEMO_LATER")
	later.flat = true
	later.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	later.add_theme_font_size_override("font_size", GameConfig.fs(GameConfig.UI_LABEL))
	later.pressed.connect(_on_later)
	column.add_child(later)

	var restore := Button.new()
	restore.name = "Restore"
	restore.text = tr("DEMO_RESTORE")
	restore.flat = true
	restore.add_theme_font_size_override("font_size", GameConfig.UI_LABEL - 6)
	restore.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	restore.pressed.connect(_on_restore)
	column.add_child(restore)
	# A METHOD, not a lambda: a lambda stays connected after the card is freed
	# and fires into a dead object the next time anyone buys anything.
	Purchases.changed.connect(_on_purchases_changed)


func _on_purchases_changed() -> void:
	if Purchases.is_full():
		_close(true)


func _on_buy() -> void:
	Haptics.medium()
	# Locally this grants at once and `changed` closes the card; with a store
	# provider the card stays until the store confirms.
	Purchases.unlock_full()


func _on_later() -> void:
	_close(false)


func _on_restore() -> void:
	Purchases.restore()
	if Purchases.is_full():
		_close(true)


func _close(bought: bool) -> void:
	if _closing:
		return
	_closing = true
	if Purchases.changed.is_connected(_on_purchases_changed):
		Purchases.changed.disconnect(_on_purchases_changed)
	finished.emit(bought)
	queue_free()
