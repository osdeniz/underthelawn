class_name WorkshopPage
extends Control
## Gus's workshop (G10): the four mower cards, each with an unlock or a
## three-tier upgrade line. All prices and effects come from GameConfig; state
## lives in Garage. Built in code like the rest of the hub pages.

signal back_requested()
## A purchase went through: the hub's money counter must follow the deduction.
signal purchased()

var _gus_line: Label
var _cards: VBoxContainer
var _confirm: PanelContainer
var _confirm_text: Label
var _confirm_buy: Button
var _pending_index := -1
var _pending_is_unlock := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	refresh()


func _build() -> void:
	# Gus's greeting: face + one line, picked by case progress.
	var who := HBoxContainer.new()
	who.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	who.offset_left = 60
	who.offset_right = -60
	who.offset_top = 260
	who.offset_bottom = 420
	who.add_theme_constant_override("separation", 28)
	add_child(who)

	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(140, 140)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture = TextureLibrary.find("portraits/face_gus")
	who.add_child(face)

	_gus_line = Label.new()
	_gus_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gus_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gus_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gus_line.add_theme_font_size_override("font_size", 36)
	_gus_line.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	who.add_child(_gus_line)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 440
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 22)
	scroll.add_child(_cards)

	# Confirm sheet, hidden until a purchase is tapped.
	_confirm = PanelContainer.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_confirm.offset_left = -440
	_confirm.offset_right = 440
	_confirm.offset_top = -240
	_confirm.offset_bottom = 240
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.CASE_PANEL
	style.set_corner_radius_all(28)
	style.set_content_margin_all(44)
	style.border_color = Color(GameConfig.CASE_ACCENT, 0.5)
	style.set_border_width_all(3)
	_confirm.add_theme_stylebox_override("panel", style)
	_confirm.visible = false
	add_child(_confirm)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 28)
	_confirm.add_child(rows)
	_confirm_text = Label.new()
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.add_theme_font_size_override("font_size", 42)
	rows.add_child(_confirm_text)
	_confirm_buy = Button.new()
	_confirm_buy.text = tr("WS_BUY")
	_confirm_buy.add_theme_font_size_override("font_size", 44)
	HubScreen.style_primary(_confirm_buy)
	_confirm_buy.pressed.connect(_on_buy)
	rows.add_child(_confirm_buy)
	var cancel := Button.new()
	cancel.text = tr("WS_CANCEL")
	cancel.add_theme_font_size_override("font_size", 38)
	HubScreen.style_secondary(cancel)
	cancel.pressed.connect(func() -> void: _confirm.visible = false)
	rows.add_child(cancel)


## Rebuilt on every hub visit, so purchases show immediately.
func refresh() -> void:
	var done := ChapterProgress.done_count()
	var line := "DLG_WS_GUS_0"
	for variant: Dictionary in Dialogue.data().get("workshop", []):
		if int(variant.get("min_done", 0)) <= done:
			line = str(variant.get("text", line))
	_gus_line.text = tr(line)
	for child in _cards.get_children():
		child.queue_free()
	for i in GameConfig.MOWER_TYPES.size():
		_cards.add_child(_make_card(i))


func _make_card(index: int) -> PanelContainer:
	var info: Dictionary = GameConfig.MOWER_TYPES[index]
	var unlocked := Garage.is_unlocked(index)
	var tier := Garage.tier(index)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.065, 0.92)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(30)
	style.border_color = Color(GameConfig.CASE_ACCENT, 0.42 if unlocked else 0.16)
	style.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	card.add_child(rows)

	# The machine's drawn silhouette, not its emoji: the picker already learned
	# that an emoji is a blank box on iOS (G12.9), and these cards kept one.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	rows.add_child(head)
	var badge := TextureRect.new()
	badge.texture = MowerIcons.icon_for(index)
	badge.custom_minimum_size = Vector2(52, 52)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.modulate = Color.WHITE if unlocked else Color(0.62, 0.62, 0.60)
	head.add_child(badge)

	var title := Label.new()
	var pips := ""
	for step in GameConfig.UPGRADE_MAX_TIER:
		pips += "●" if step < tier else "○"
	title.text = "%s   %s" % [tr(str(info["label"])), pips]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color",
		Color(0.95, 0.94, 0.9) if unlocked else Color(0.6, 0.6, 0.56))
	head.add_child(title)

	var state := Label.new()
	state.add_theme_font_size_override("font_size", 30)
	rows.add_child(state)

	if not unlocked:
		state.text = tr("WS_LOCKED")
		state.add_theme_color_override("font_color", Color(0.62, 0.6, 0.56))
		# Gus's sales pitch for the locked machine.
		var pitch := Label.new()
		pitch.text = tr(_pitch_key(index))
		pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pitch.add_theme_font_size_override("font_size", 30)
		pitch.add_theme_color_override("font_color", Color(0.72, 0.7, 0.62))
		rows.add_child(pitch)
		var buy := Button.new()
		buy.text = tr("WS_UNLOCK").format({"cost": Garage.unlock_cost(index)})
		# The price used to carry a banknote emoji, which is a blank box on iOS.
		buy.icon = UiIcons.money()
		buy.expand_icon = false
		buy.add_theme_constant_override("h_separation", 12)
		buy.add_theme_font_size_override("font_size", 38)
		HubScreen.style_primary(buy)
		buy.pressed.connect(_ask.bind(index, true, buy))
		rows.add_child(buy)
	else:
		state.text = tr("WS_ACTIVE")
		state.add_theme_color_override("font_color", Color(0.55, 0.8, 0.45))
		var cost := Garage.next_upgrade_cost(index)
		if cost < 0:
			var maxed := Label.new()
			maxed.text = tr("WS_MAXED")
			maxed.add_theme_font_size_override("font_size", 32)
			maxed.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
			rows.add_child(maxed)
		else:
			var effect := Label.new()
			effect.text = _effect_text(index)
			effect.add_theme_font_size_override("font_size", 30)
			effect.add_theme_color_override("font_color", Color(0.72, 0.74, 0.68))
			rows.add_child(effect)
			var up := Button.new()
			up.text = tr("WS_UPGRADE").format({"cost": cost})
			up.icon = UiIcons.money()
			up.expand_icon = false
			up.add_theme_constant_override("h_separation", 12)
			up.add_theme_font_size_override("font_size", 38)
			HubScreen.style_secondary(up)
			up.pressed.connect(_ask.bind(index, false, up))
			rows.add_child(up)
	return card


func _pitch_key(index: int) -> String:
	match Garage.mower_id(index):
		"tractor": return "DLG_WS_GUS_TRACTOR"
		"robot": return "DLG_WS_GUS_ROBOT"
		"blade": return "DLG_WS_GUS_BLADE"
	return "DLG_WS_GUS_0"


func _effect_text(index: int) -> String:
	var id := Garage.mower_id(index)
	if id == "blade":
		return tr("WS_EFFECT_BLADE")
	var bonus := float(GameConfig.UPGRADE_SPEED_BONUS.get(id, 0.0))
	return tr("WS_EFFECT_SPEED").format({"pct": int(round(bonus * 100.0))})


func _ask(index: int, is_unlock: bool, source: Button) -> void:
	Haptics.light()
	var cost := Garage.unlock_cost(index) if is_unlock \
		else Garage.next_upgrade_cost(index)
	if GameState.scrap_total() < cost:
		# Not enough: the price shakes red and Gus has a line for it.
		_gus_line.text = tr("DLG_WS_GUS_POOR")
		source.add_theme_color_override("font_color", Color(0.95, 0.3, 0.25))
		var home := source.position
		var tw := create_tween()
		for offset: float in [12.0, -9.0, 6.0, -3.0, 0.0]:
			tw.tween_property(source, "position", home + Vector2(offset, 0), 0.05)
		tw.tween_callback(func() -> void:
			source.position = home
			source.remove_theme_color_override("font_color"))
		return
	_pending_index = index
	_pending_is_unlock = is_unlock
	var name := tr(str(GameConfig.MOWER_TYPES[index]["label"]))
	var key := "WS_CONFIRM_UNLOCK" if is_unlock else "WS_CONFIRM_UPGRADE"
	_confirm_text.text = tr(key).format({"name": name, "cost": cost}) \
		+ "\n" + _effect_text(index)
	_confirm.visible = true


func _on_buy() -> void:
	_confirm.visible = false
	var bought := Garage.buy_unlock(_pending_index) if _pending_is_unlock \
		else Garage.buy_upgrade(_pending_index)
	if not bought:
		return
	AudioDirector.play_scrap()
	Haptics.success()
	refresh()
	purchased.emit()
