class_name WorkshopPage
extends Control
## Gus's workshop (G10, rebuilt in the UI/UX redesign).
##
## It used to be four identical dark cards stacked in a scroll, each with a
## title, a state line, an effect line and its own full-width button. That is
## the exact "black card + title + description + button" shape the redesign
## brief rules out, and it had the failure that shape always has: nothing on
## the screen was more important than anything else, four buttons competed to
## be the primary action, and the machines themselves — the entire subject of
## the screen — were 52px badges.
##
## It is now a shop. One machine is in front of you at a time, drawn large,
## with its numbers and ONE action; the other three are a row of chips along
## the bottom that switches between them. The chip row is deliberately the
## same shape as the mower selector in the gameplay HUD, so the gesture for
## "choose a machine" is already learned before the player gets here.
##
## Prices and effects still come from GameConfig, state still lives in Garage,
## and buying still goes through Garage.buy_unlock / buy_upgrade — none of the
## economy moved.

signal back_requested()
## A purchase went through: the hub's money counter must follow the deduction.
signal purchased()

## How big the machine is drawn in the hero panel. MowerIcons renders at 96px;
## this is a deliberate upscale, and it is nearest-neighbour, so the drawn
## silhouette stays crisp instead of going soft.
const HERO_ART := 260.0

var _gus_line: Label
var _hero: PanelContainer
var _chips: HBoxContainer
var _larder: Button
var _selected := 0
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
	who.offset_top = 250
	who.offset_bottom = 400
	who.add_theme_constant_override("separation", 26)
	add_child(who)

	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(132, 132)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.texture = TextureLibrary.find("portraits/face_gus")
	who.add_child(face)

	_gus_line = Label.new()
	_gus_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gus_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gus_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gus_line.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	_gus_line.add_theme_color_override("font_color", GameConfig.UI_INK)
	who.add_child(_gus_line)

	# The machine on show. Content is rebuilt by _fill_hero on every change.
	_hero = PanelContainer.new()
	_hero.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hero.offset_left = 50
	_hero.offset_right = -50
	_hero.offset_top = 430
	# Height is set from the content in _fill_hero: a fixed box left a slab of
	# empty panel under the button on the shorter machines.
	_hero.offset_bottom = 1400
	add_child(_hero)

	# The picker. Same shape as the gameplay selector, at the bottom of the
	# screen where the thumb already is.
	_chips = HBoxContainer.new()
	_chips.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_chips.offset_left = 50
	_chips.offset_right = -50
	# Clear of the hub's own BACK button, which occupies the last 160px of the
	# screen. The chips are 160 tall plus their margins, so parking them at
	# -320 put their bottom edge inside it.
	_chips.offset_top = -396.0
	_chips.offset_bottom = -200.0
	_chips.add_theme_constant_override("separation", 14)
	add_child(_chips)
	_build_larder()

	_build_confirm()


## A sack of food, for sale, in the one screen that already sells things
## (G14.13). Food had to be buyable: a bad run with an empty larder is
## otherwise a dead end, and money is the resource the player has most of.
func _build_larder() -> void:
	_larder = Button.new()
	_larder.name = "BuyFood"
	_larder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_larder.offset_left = 50
	_larder.offset_right = -50
	_larder.offset_top = -560.0
	_larder.offset_bottom = -412.0
	_larder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_larder.add_theme_font_size_override("font_size", 30)
	HubScreen.style_secondary(_larder)
	_larder.pressed.connect(func() -> void:
		Haptics.light()
		if GameState.scrap_total() < GameConfig.FOOD_SACK_COST:
			HubScreen.shake(_larder)
			return
		GameState.spend_scrap(GameConfig.FOOD_SACK_COST)
		TownStats.add_food(GameConfig.FOOD_SACK)
		Analytics.track("food_bought", {"cost": GameConfig.FOOD_SACK_COST})
		purchased.emit()
		_refresh_larder())
	add_child(_larder)
	_refresh_larder()


func _refresh_larder() -> void:
	if _larder == null or not is_instance_valid(_larder):
		return
	var afford := GameState.scrap_total() >= GameConfig.FOOD_SACK_COST
	_larder.text = "%s  ·  %d\n%s" % [tr("SHOP_FOOD"), GameConfig.FOOD_SACK_COST,
		tr("SHOP_FOOD_HINT").format({"n": GameConfig.FOOD_SACK}) if afford
		else tr("SHOP_POOR")]
	_larder.modulate.a = 1.0 if afford else 0.6


func _build_confirm() -> void:
	_confirm = PanelContainer.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_confirm.offset_left = -450
	_confirm.offset_right = 450
	_confirm.offset_top = -270
	_confirm.offset_bottom = 270
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.UI_SURFACE
	style.set_corner_radius_all(24)
	style.set_content_margin_all(44)
	style.border_color = GameConfig.UI_BRASS
	style.set_border_width_all(3)
	_confirm.add_theme_stylebox_override("panel", style)
	_confirm.visible = false
	add_child(_confirm)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", GameConfig.UI_GAP_WIDE)
	_confirm.add_child(rows)
	_confirm_text = Label.new()
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	_confirm_text.add_theme_color_override("font_color", GameConfig.UI_INK)
	rows.add_child(_confirm_text)
	_confirm_buy = Button.new()
	_confirm_buy.text = tr("WS_BUY")
	_confirm_buy.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	_confirm_buy.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	HubScreen.style_primary(_confirm_buy)
	_confirm_buy.pressed.connect(_on_buy)
	rows.add_child(_confirm_buy)
	var cancel := Button.new()
	cancel.text = tr("WS_CANCEL")
	cancel.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	cancel.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	HubScreen.style_secondary(cancel)
	cancel.pressed.connect(func() -> void: _confirm.visible = false)
	rows.add_child(cancel)


## Rebuilt on every hub visit, so purchases show immediately.
func refresh() -> void:
	_refresh_larder()
	var done := ChapterProgress.done_count()
	var line := "DLG_WS_GUS_0"
	for variant: Dictionary in Dialogue.data().get("workshop", []):
		if int(variant.get("min_done", 0)) <= done:
			line = str(variant.get("text", line))
	_gus_line.text = tr(line)
	_fill_hero()
	_fill_chips()


func _select(index: int) -> void:
	if index == _selected:
		return
	Haptics.light()
	_selected = index
	_fill_hero()
	_fill_chips()


# ------------------------------------------------------------------ the hero

## The machine on show: its picture, its name, what it does, and the one thing
## you can do about it. Everything the old card carried is still here — it is
## carried once, at a size you can read, instead of four times at 30px.
func _fill_hero() -> void:
	for child in _hero.get_children():
		_hero.remove_child(child)
		child.queue_free()

	var index := _selected
	var info: Dictionary = GameConfig.MOWER_TYPES[index]
	var unlocked := Garage.is_unlocked(index)

	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.UI_SURFACE
	style.set_corner_radius_all(20)
	style.set_content_margin_all(GameConfig.UI_GAP_SECTION)
	style.border_color = GameConfig.UI_BRASS if unlocked else GameConfig.UI_LINE
	style.set_border_width_all(2)
	_hero.add_theme_stylebox_override("panel", style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", GameConfig.UI_GAP)
	_hero.add_child(rows)

	# The machine, drawn big. A locked one is shown in silhouette rather than
	# hidden: you cannot want a thing you have not seen.
	var art := TextureRect.new()
	art.texture = MowerIcons.icon_for(index)
	art.custom_minimum_size = Vector2(0, HERO_ART)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.modulate = Color.WHITE if unlocked else Color(0.34, 0.32, 0.30)
	rows.add_child(art)

	var name_label := Label.new()
	name_label.text = tr(str(info["label"]))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", GameConfig.UI_TITLE)
	name_label.add_theme_color_override("font_color",
		GameConfig.UI_INK if unlocked else GameConfig.UI_INK_FAINT)
	rows.add_child(name_label)

	var state := Label.new()
	state.text = tr("WS_ACTIVE") if unlocked else tr("WS_LOCKED")
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	state.add_theme_color_override("font_color",
		GameConfig.UI_GREEN if unlocked else GameConfig.UI_INK_FAINT)
	rows.add_child(state)

	var rule := ColorRect.new()
	rule.color = GameConfig.UI_LINE
	rule.custom_minimum_size = Vector2(0, 2)
	rows.add_child(rule)

	# The numbers. Speed and cut width come straight from MOWER_TYPES, so the
	# shop cannot promise something the machine does not do.
	rows.add_child(_stat(tr("WS_STAT_SPEED"),
		"%.1f" % (float(info["speed"]) * Garage.speed_multiplier(index))))
	rows.add_child(_stat(tr("WS_STAT_CUT"), "%.2f" % float(info["deck"])))
	rows.add_child(_stat(tr("WS_STAT_TIER"), _pips(index)))

	if unlocked:
		_fill_owned_action(rows, index)
	else:
		_fill_locked_action(rows, index)

	# Shrink to what was actually put in. Deferred because the labels have to
	# lay out once before their minimum height is real.
	_size_hero.call_deferred()


func _size_hero() -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	var wanted := _hero.get_combined_minimum_size().y
	_hero.offset_bottom = _hero.offset_top + maxf(wanted, 520.0)


## One "label ......... value" line. The label is faint and the value is ink,
## because the eye is here for the number.
func _stat(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 56)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	label.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	value.add_theme_color_override("font_color", GameConfig.UI_INK)
	row.add_child(value)
	return row


## Upgrade tiers as filled and empty marks. Text rather than colour, so the
## count survives any colour vision — and it is the same ●/○ the cards used.
func _pips(index: int) -> String:
	var tier := Garage.tier(index)
	var out := ""
	for step in GameConfig.UPGRADE_MAX_TIER:
		out += "●" if step < tier else "○"
	return out


func _fill_owned_action(rows: VBoxContainer, index: int) -> void:
	var cost := Garage.next_upgrade_cost(index)
	if cost < 0:
		var maxed := Label.new()
		maxed.text = tr("WS_MAXED")
		maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		maxed.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
		maxed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		maxed.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
		maxed.add_theme_color_override("font_color", GameConfig.UI_BRASS)
		rows.add_child(maxed)
		return
	var effect := Label.new()
	effect.text = _effect_text(index)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	effect.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	rows.add_child(effect)
	rows.add_child(_price_button(
		tr("WS_UPGRADE").format({"cost": cost}), cost, index, false))


func _fill_locked_action(rows: VBoxContainer, index: int) -> void:
	var pitch := Label.new()
	pitch.text = tr(_pitch_key(index))
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pitch.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	pitch.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	rows.add_child(pitch)
	var cost := Garage.unlock_cost(index)
	rows.add_child(_price_button(
		tr("WS_UNLOCK").format({"cost": cost}), cost, index, true))


## The screen's one action.
##
## Whether you can afford it is said twice on purpose: the button goes quiet
## and a line appears under it saying why. Price alone, greyed, is the kind of
## thing a player reads as "broken" rather than as "too expensive".
func _price_button(label_text: String, cost: int, index: int,
		is_unlock: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
	var button := Button.new()
	button.text = label_text
	button.icon = UiIcons.salvage()
	button.expand_icon = false
	button.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	button.add_theme_constant_override("h_separation", 14)
	button.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	var affordable := GameState.scrap_total() >= cost
	if affordable:
		HubScreen.style_primary(button)
	else:
		HubScreen.style_secondary(button)
		button.modulate = Color(1, 1, 1, 0.7)
	button.pressed.connect(_ask.bind(index, is_unlock, button))
	box.add_child(button)
	if not affordable:
		var why := Label.new()
		why.text = tr("WS_NOT_ENOUGH")
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		why.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
		why.add_theme_color_override("font_color", GameConfig.UI_RED)
		box.add_child(why)
	return box


# ----------------------------------------------------------------- the picker

func _fill_chips() -> void:
	for child in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	for i in GameConfig.MOWER_TYPES.size():
		_chips.add_child(_make_chip(i))


func _make_chip(index: int) -> Button:
	var unlocked := Garage.is_unlocked(index)
	var chosen := index == _selected
	var button := Button.new()
	button.name = "Chip_%d" % index
	button.text = tr(str(GameConfig.MOWER_TYPES[index]["label"]))
	button.icon = UiIcons.lock() if not unlocked else MowerIcons.icon_for(index)
	button.expand_icon = false
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 160)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.UI_SURFACE_RAISED if chosen else GameConfig.UI_SURFACE
	style.set_corner_radius_all(16)
	style.set_content_margin_all(12)
	# The selected chip is the only one with a brass edge, and it is a THICK
	# edge — selection that is only a shade of background does not survive a
	# sunlit phone screen.
	style.border_color = GameConfig.UI_BRASS if chosen else GameConfig.UI_LINE
	style.set_border_width_all(4 if chosen else 1)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color",
		GameConfig.UI_INK if unlocked else GameConfig.UI_INK_FAINT)
	button.add_theme_color_override("font_hover_color", GameConfig.UI_INK)
	button.add_theme_color_override("font_pressed_color", GameConfig.UI_INK)
	button.modulate = Color.WHITE if unlocked else Color(0.8, 0.8, 0.8)
	button.pressed.connect(_select.bind(index))
	return button


# ---------------------------------------------------------------- the economy
# Unchanged from the card version: same keys, same Garage calls, same signal.

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
		source.add_theme_color_override("font_color", GameConfig.UI_RED)
		var home := source.position
		# The tween is created ON the button, not on this page: refresh()
		# rebuilds the hero and frees the button, and a tween owned by the page
		# outlived it and then wrote position onto a freed object. The guard
		# covers the same race arriving one frame later.
		var tw := source.create_tween()
		for offset: float in [12.0, -9.0, 6.0, -3.0, 0.0]:
			tw.tween_property(source, "position", home + Vector2(offset, 0), 0.05)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(source):
				return
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
