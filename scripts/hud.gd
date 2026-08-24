class_name Hud
extends Control
## HUD for sprints G1 + G2 (§16).
##
## G1: mown percentage, green capsule, mute button, LAWN COMPLETE panel.
## G2: secret counter, the discovery card that flies into the counter,
## collection slots, the "you missed something" line, screen dressing and the
## completion flash.
## G7: the case framing on top of all of it — case title line, the briefing box,
## the opening title, and the evidence/case-notes wording. Every string comes
## from data/story.json via Story; none of it is hard-coded here.
##
## The root ignores input; only the buttons and the completion backdrop stop
## events, so touches meant for the lawn reach the 3D scene.

signal restart_pressed()
## RETURN TO TOWN on the case-notes panel (G8).
signal return_requested()
## CONTINUE THE CASE on the all-evidence card, or the badge that replaces it (G9).
signal exit_confirmed()
## The STORY button was tapped: replay the opening (G7).
signal replay_intro_requested()

@onready var _percent_label: Label = %PercentLabel
@onready var _secret_counter: Label = %SecretCounter
@onready var _progress: ProgressBar = %Progress
@onready var _mute_button: Button = %MuteButton
@onready var _secret_card: PanelContainer = %SecretCard
@onready var _card_title: Label = %CardTitle
@onready var _card_line: Label = %CardLine
@onready var _complete_panel: Control = %CompletePanel
@onready var _complete_stats: Label = %CompleteStats
@onready var _complete_title: Label = %Title
@onready var _collection: HBoxContainer = %Collection
@onready var _missed_label: Label = %MissedLabel
@onready var _flash: ColorRect = %Flash
@onready var joystick: TractorJoystick = %Joystick
@onready var selector: MowerSelector = %Selector
@onready var _case_line: Label = %CaseLine
@onready var _story_button: Button = %StoryButton
@onready var _card_header: Label = %CardHeader
@onready var _opening: VBoxContainer = %OpeningTitle
@onready var _opening_headline: Label = %OpeningHeadline
@onready var _opening_subline: Label = %OpeningSubline
@onready var _notes_header: Label = %NotesHeader
@onready var _notes_list: VBoxContainer = %NotesList
@onready var _notes_progress: Label = %NotesProgress
@onready var _teaser: Button = %Teaser
@onready var _teaser_locked: Label = %TeaserLocked
@onready var _return_button: Button = %ReturnButton
@onready var _scrap_label: Label = %ScrapLabel
@onready var _exit_card: PanelContainer = %ExitCard
@onready var _exit_title: Label = %ExitTitle
@onready var _exit_continue: Button = %ExitContinue
@onready var _exit_keep: Button = %ExitKeep
@onready var _exit_badge: Button = %ExitBadge
@onready var _payout_list: VBoxContainer = %PayoutList

var _shown_percent := 0.0
var _target_percent := 0.0
var _card_home := Vector2.ZERO
var _card_tween: Tween
var _counter_tween: Tween
var _opening_tween: Tween


func _ready() -> void:
	# Before any label draws: registers the wide-glyph fallback font if one is
	# present, so a non-Latin language does not render as boxes.
	LocaleSupport.apply()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_complete_panel.visible = false
	_secret_card.visible = false
	_missed_label.visible = false
	_flash.modulate.a = 0.0
	joystick.visible = false
	_mute_button.pressed.connect(_on_mute_pressed)
	(%RestartButton as Button).pressed.connect(func() -> void: restart_pressed.emit())
	_refresh_mute_label()
	(%RestartButton as Button).text = tr("UI_RESTART")
	_story_button.text = tr("UI_STORY")
	_style_case_panels()
	_apply_story_text()
	_opening.modulate.a = 0.0
	_teaser_locked.visible = false
	_return_button.pressed.connect(func() -> void: return_requested.emit())
	_exit_card.visible = false
	_exit_badge.visible = false
	_exit_continue.pressed.connect(_on_exit_continue)
	_exit_keep.pressed.connect(_on_exit_keep)
	_exit_badge.pressed.connect(_on_exit_continue)
	_story_button.pressed.connect(func() -> void: replay_intro_requested.emit())
	_teaser.pressed.connect(_on_teaser_pressed)
	set_progress(0.0)
	set_secret_count(0, GameConfig.SECRET_TOTAL)


# ---------------------------------------------------------------- progress

func set_progress(ratio: float) -> void:
	_target_percent = clampf(ratio, 0.0, 1.0) * 100.0


func _process(delta: float) -> void:
	if absf(_target_percent - _shown_percent) > 0.01:
		_shown_percent = lerpf(_shown_percent, _target_percent,
			clampf(delta * 9.0, 0.0, 1.0))
		_apply_percent()


func _apply_percent() -> void:
	_percent_label.text = tr("UI_PERCENT_MOWED").format(
		{"pct": int(round(_shown_percent))})
	_progress.value = _shown_percent


# ---------------------------------------------------------------- secrets

func set_secret_count(found: int, total: int) -> void:
	# G7: evidence, not secrets — "📋 Evidence 1/2".
	_secret_counter.text = tr("UI_EVIDENCE_COUNTER").format({
		"icon": Story.raw("evidence.counter_icon", "📋"),
		"found": found, "total": total})


func bump_secret_counter() -> void:
	if _counter_tween and _counter_tween.is_valid():
		_counter_tween.kill()
	_secret_counter.pivot_offset = _secret_counter.size * 0.5
	_secret_counter.scale = Vector2(1.35, 1.35)
	_counter_tween = create_tween()
	_counter_tween.tween_property(_secret_counter, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows the discovery card, then shrinks it into the secret counter (§16).
## `on_landed` fires when it reaches the counter, so the count updates then.
func show_secret_card(emoji: String, item_name: String, line: String,
		on_landed: Callable) -> void:
	_card_header.text = Story.text("evidence.card_header", "EVIDENCE FOUND")
	_card_title.text = "%s %s" % [emoji, item_name]
	_card_line.text = line

	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()
	# Remember the resting place so repeat cards start from the same spot.
	if _card_home == Vector2.ZERO:
		_card_home = _secret_card.position
	_secret_card.position = _card_home
	_secret_card.pivot_offset = _secret_card.size * 0.5
	_secret_card.scale = Vector2(0.8, 0.8)
	_secret_card.modulate.a = 0.0
	_secret_card.visible = true

	var target := _secret_counter.get_global_rect().get_center() \
		- _secret_card.size * 0.5

	_card_tween = create_tween()
	_card_tween.tween_property(_secret_card, "modulate:a", 1.0, 0.2)
	_card_tween.parallel().tween_property(_secret_card, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.tween_interval(GameConfig.CARD_SHOW_TIME)
	_card_tween.tween_property(_secret_card, "position", target,
		GameConfig.CARD_FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_card_tween.parallel().tween_property(_secret_card, "scale", Vector2(0.12, 0.12),
		GameConfig.CARD_FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_card_tween.parallel().tween_property(_secret_card, "modulate:a", 0.0,
		GameConfig.CARD_FLY_TIME).set_delay(GameConfig.CARD_FLY_TIME * 0.55)
	_card_tween.tween_callback(func() -> void:
		_secret_card.visible = false
		_secret_card.position = _card_home
		_secret_card.scale = Vector2.ONE
		bump_secret_counter()
		if on_landed.is_valid():
			on_landed.call())


# ---------------------------------------------------------------- completion

## The joystick only exists for the tractor (§7); the selector hides once the
## lawn is finished (§16).
func set_joystick_visible(value: bool) -> void:
	joystick.visible = value


func set_selector_visible(value: bool) -> void:
	selector.visible = value


## `collected` holds one entry per found item: { emoji, name }.
func show_complete(cells: int, elapsed: String, collected: Array,
		total_secrets: int, payout := {}) -> void:
	_shown_percent = 100.0
	_apply_percent()
	_complete_stats.text = tr("UI_STATS").format(
		{"cells": cells, "time": elapsed})

	for child in _collection.get_children():
		child.queue_free()
	for i in total_secrets:
		var slot := Label.new()
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 40)
		if i < collected.size():
			var entry: Dictionary = collected[i]
			slot.text = "%s\n%s" % [entry.get("emoji", "?"), entry.get("name", "")]
			slot.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
		else:
			slot.text = "?\n" + tr("UI_EMPTY_SLOT")
			slot.add_theme_color_override("font_color", Color(0.55, 0.58, 0.52))
		_collection.add_child(slot)

	_clear_opening_title()
	_exit_card.visible = false
	_exit_badge.visible = false
	_build_case_notes(collected, total_secrets)
	_build_payout(payout)
	_missed_label.visible = collected.size() < total_secrets
	_complete_panel.visible = true
	# The picker and the joystick go away once the lawn is done (§16).
	selector.visible = false
	joystick.visible = false

	# Spring pop on the title (§16).
	_complete_title.pivot_offset = _complete_title.size * 0.5
	_complete_title.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(_complete_title, "scale", Vector2.ONE, 0.8) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func hide_complete() -> void:
	_complete_panel.visible = false
	_teaser_locked.visible = false
	selector.visible = true
	_missed_label.visible = false
	_shown_percent = 0.0
	_target_percent = 0.0
	_apply_percent()


## Brief white bloom for the 100% moment.
func flash(strength := 0.5, duration := 0.9) -> void:
	_flash.modulate.a = clampf(strength, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- mute

func _on_mute_pressed() -> void:
	AudioDirector.toggle_mute()
	Haptics.light()
	_refresh_mute_label()


func _refresh_mute_label() -> void:
	_mute_button.text = "🔇" if AudioDirector.muted else "🔊"


# ---------------------------------------------------------------- case framing (G7/G8)

## Kept as the styling hook; the panels it used to style moved into DialogueBox
## when the briefing became a conversation (G8).
func _style_case_panels() -> void:
	# The default theme's PanelContainer and Button are nearly transparent, so
	# anything laid over the lawn reads as a smudge rather than a card.
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.06, 0.06, 0.055, 0.94)
	card.set_corner_radius_all(28)
	card.set_content_margin_all(40)
	card.border_color = Color(GameConfig.CASE_ACCENT, 0.42)
	card.set_border_width_all(3)
	card.shadow_color = Color(0, 0, 0, 0.5)
	card.shadow_size = 12
	_exit_card.add_theme_stylebox_override("panel", card)
	for button: Button in [_exit_continue, _exit_keep, _exit_badge]:
		_style_button(button)


## Same treatment for a button that sits over the 3D scene.
func _style_button(button: Button) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.10, 0.10, 0.09, 0.94)
	base.set_corner_radius_all(20)
	base.set_content_margin_all(22)
	base.border_color = Color(GameConfig.CASE_ACCENT, 0.40)
	base.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", base)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.17, 0.15, 0.11, 0.97)
	pressed.border_color = Color(GameConfig.CASE_ACCENT, 0.8)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", base)


## Pulls every fixed string out of data/story.json. Called once at _ready, so a
## story-file edit needs no scene edit.
func _apply_story_text() -> void:
	_case_line.text = Story.text("case.hud_line")
	_complete_title.text = Story.text("complete.title", "AREA SEARCHED")
	_missed_label.text = Story.text("complete.incomplete",
		"The search feels incomplete...")
	_notes_header.text = Story.text("complete.notes_header", "CASE NOTES")
	_teaser.text = "%s\n%s" % [
		Story.text("complete.teaser_title"),
		Story.text("complete.teaser_line")]
	_teaser_locked.text = Story.text("complete.teaser_locked", "Coming soon")
	_opening_headline.text = Story.text("opening.headline")
	_opening_subline.text = Story.text("opening.subline")
	_card_header.text = Story.text("evidence.card_header", "EVIDENCE FOUND")
	_return_button.text = tr("UI_RETURN_TOWN")
	_exit_title.text = tr("EXIT_ALL_FOUND")
	_exit_continue.text = tr("EXIT_CONTINUE")
	_exit_keep.text = tr("EXIT_KEEP_MOWING")
	_exit_badge.text = tr("EXIT_BADGE")


## The "LAST MOWED" title: holds while the camera settles onto the lawn, then
## fades. Kept from G1 but tied to the case — the second line is the new part.
func show_opening_title() -> void:
	_opening.modulate.a = 0.0
	if _opening_tween and _opening_tween.is_valid():
		_opening_tween.kill()
	_opening_tween = create_tween()
	_opening_tween.tween_property(_opening, "modulate:a", 1.0, 0.7)
	_opening_tween.tween_interval(GameConfig.OPENING_TITLE_HOLD)
	_opening_tween.tween_property(_opening, "modulate:a", 0.0,
		GameConfig.OPENING_TITLE_FADE)


## The opening title sits above the completion panel in the tree, so a very fast
## finish would print it across the case notes.
func _clear_opening_title() -> void:
	if _opening_tween and _opening_tween.is_valid():
		_opening_tween.kill()
	_opening.modulate.a = 0.0


## One line per recovered piece of evidence, then the case-progress sentence.
## `collected` holds { emoji, name } entries, same as the collection slots.
func _build_case_notes(collected: Array, total: int) -> void:
	for child in _notes_list.get_children():
		child.queue_free()
	for entry: Dictionary in collected:
		var row := Label.new()
		row.text = "· %s  %s" % [entry.get("emoji", "?"), entry.get("name", "")]
		row.add_theme_font_size_override("font_size", 36)
		row.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
		_notes_list.add_child(row)
	if collected.is_empty():
		var none := Label.new()
		none.text = "· " + tr("UI_NOTHING_RECOVERED")
		none.add_theme_font_size_override("font_size", 36)
		none.add_theme_color_override("font_color", Color(0.6, 0.62, 0.58))
		_notes_list.add_child(none)
	_notes_progress.text = Story.text("complete.notes_full") if collected.size() >= total \
		else Story.text("complete.notes_partial")


## Locked: a short shake and the "Coming soon" line, no navigation.
func _on_teaser_pressed() -> void:
	Haptics.light()
	_teaser_locked.visible = true
	var home := _teaser.position
	var tw := create_tween()
	for offset: float in [14.0, -11.0, 7.0, -4.0, 0.0]:
		tw.tween_property(_teaser, "position",
			home + Vector2(offset, 0.0), 0.055)
	tw.tween_callback(func() -> void: _teaser.position = home)


# ---------------------------------------------------------------- G9 economy

func set_scrap(total: int) -> void:
	_scrap_label.text = "%s %d" % [GameConfig.SCRAP_ICON, total]


## A value flies from the pickup's screen position to the counter, so the number
## going up is visibly caused by the thing on the ground.
func fly_scrap(amount: int, from_screen: Vector2) -> void:
	var label := Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.62))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = from_screen
	var target := _scrap_label.get_global_rect().get_center()
	var tw := create_tween()
	tw.tween_property(label, "position", target, GameConfig.SCRAP_FLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(label, "scale", Vector2(0.6, 0.6),
		GameConfig.SCRAP_FLY_TIME)
	tw.parallel().tween_property(label, "modulate:a", 0.0,
		GameConfig.SCRAP_FLY_TIME * 0.5).set_delay(GameConfig.SCRAP_FLY_TIME * 0.5)
	tw.tween_callback(func() -> void:
		label.queue_free()
		_pulse(_scrap_label))


func _pulse(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(control, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- G9 early exit

## All evidence found. The player decides whether the chapter is over; KEEP
## MOWING leaves a small badge so the offer is never lost.
func show_exit_offer() -> void:
	_exit_card.visible = true
	_exit_badge.visible = false
	_exit_card.modulate.a = 0.0
	_exit_card.pivot_offset = _exit_card.size * 0.5
	_exit_card.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.tween_property(_exit_card, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_exit_card, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_exit_continue() -> void:
	Haptics.medium()
	_exit_card.visible = false
	_exit_badge.visible = false
	exit_confirmed.emit()


func _on_exit_keep() -> void:
	Haptics.light()
	var tw := create_tween()
	tw.tween_property(_exit_card, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func() -> void:
		_exit_card.visible = false
		_exit_badge.visible = true)


## Scrap breakdown on the case-notes panel: ground haul, completion bonus, and
## the thorough-search line only when it was earned.
func _build_payout(payout: Dictionary) -> void:
	for child in _payout_list.get_children():
		child.queue_free()
	if payout.is_empty():
		return
	var rows := [
		[tr("PAYOUT_GROUND"), int(payout.get("ground", 0)), false],
		[tr("PAYOUT_BONUS").format(
			{"pct": int(round(float(payout.get("ratio", 0.0)) * 100.0))}),
			int(payout.get("bonus", 0)), false],
	]
	if int(payout.get("thorough", 0)) > 0:
		rows.append([tr("PAYOUT_THOROUGH").format(
			{"pct": int(round(GameConfig.SCRAP_THOROUGH_BONUS * 100.0))}),
			int(payout.get("thorough", 0)), true])
	rows.append([tr("PAYOUT_TOTAL"), int(payout.get("total", 0)), true])
	for row: Array in rows:
		var line := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = str(row[0])
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 34)
		var value_label := Label.new()
		value_label.text = "%s %d" % [GameConfig.SCRAP_ICON, int(row[1])]
		value_label.add_theme_font_size_override("font_size", 34)
		if bool(row[2]):
			for label in [name_label, value_label]:
				label.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
		line.add_child(name_label)
		line.add_child(value_label)
		_payout_list.add_child(line)
