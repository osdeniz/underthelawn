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
## The NEXT: <chapter> button on the case-notes panel (G9.2). All chapters are
## playable since G9, so the locked teaser became a real door.
signal next_chapter_requested()
## VIEW CASE BOARD on the case-notes panel (G10).
signal board_requested()

## Render sizes for the evidence thumbnails on the completion screen (G12.10).
const SLOT_VIEW := Vector2i(190, 190)
const NOTE_VIEW := Vector2i(120, 120)

@onready var _percent_label: Label = %PercentLabel
@onready var _secret_counter: Label = %SecretCounter
@onready var _progress: ProgressBar = %Progress
@onready var _mute_button: Button = %MuteButton
@onready var _secret_card: PanelContainer = %SecretCard
@onready var _card_title: Label = %CardTitle
@onready var _card_line: Label = %CardLine
@onready var _card_art: Label = %CardArt
## Live 3D preview of the found object, replacing the emoji the phone cannot
## render (G12.8).
var _card_preview: ItemPreview
## The missing-person poster pinned to the mowing HUD (G12.8): the reason the
## player is out here, kept on screen so leaving costs something.
var _poster: Control
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
@onready var _wallet_icon: TextureRect = %WalletIcon
@onready var _evidence_icon: TextureRect = %EvidenceIcon
@onready var _evidence_chip: HBoxContainer = %EvidenceChip
@onready var _exit_card: PanelContainer = %ExitCard
@onready var _exit_title: Label = %ExitTitle
@onready var _exit_continue: Button = %ExitContinue
@onready var _exit_keep: Button = %ExitKeep
@onready var _exit_badge: Button = %ExitBadge
@onready var _payout_list: VBoxContainer = %PayoutList
@onready var _board_button: Button = %BoardButton

var _shown_percent := 0.0
## The Marshal's radio line, if one is on screen (G13.4).
var _scent_toast: PanelContainer
var _target_percent := 0.0
var _card_home := Vector2.ZERO
var _card_tween: Tween
var _counter_tween: Tween
var _opening_tween: Tween
# Shared drag pad indicator (G9.2): origin ring + current-drag dot.
var _pad_ring: Control
var _pad_active := false
var _pad_origin := Vector2.ZERO
var _pad_now := Vector2.ZERO
var _drive_hint: Label
# Pause overlay (G9.3): the game's first player-initiated stop.
## How long the scrap chip stays up after it changes.
const WALLET_HOLD := 2.6

@onready var _wallet_chip: PanelContainer = %WalletChip
var _wallet_ready := false
var _wallet_tween: Tween
var _pause_layer: Control
var _pause_button: Button


func _ready() -> void:
	# Before any label draws: registers the wide-glyph fallback font if one is
	# present, so a non-Latin language does not render as boxes.
	LocaleSupport.apply()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Deferred: the pause button, the home button and the poster are all built
	# further down _ready, so running now would find none of them (G14).
	_centre_for_wide_screens.call_deferred()
	get_viewport().size_changed.connect(_centre_for_wide_screens)
	# Drawn, not emoji: iOS renders an emoji glyph as a blank box (G12.10).
	_build_top_scrim()
	_wallet_icon.texture = UiIcons.money()
	_evidence_icon.texture = UiIcons.evidence()
	_complete_panel.visible = false
	_secret_card.visible = false
	_missed_label.visible = false
	_flash.modulate.a = 0.0
	joystick.visible = false
	_mute_button.pressed.connect(_on_mute_pressed)
	(%RestartButton as Button).pressed.connect(func() -> void: restart_pressed.emit())
	_refresh_mute_label()
	(%RestartButton as Button).text = tr("UI_RESTART")
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
	_board_button.pressed.connect(func() -> void: board_requested.emit())
	# G9.3: STORY belongs to the hub; in the game HUD it was a dead button whose
	# signal nothing had listened to since G8 moved the intro to RootFlow.
	_story_button.visible = false
	_teaser.pressed.connect(_on_teaser_pressed)
	_build_pad_ring()
	_build_pause()
	_build_card_preview()
	_build_poster()
	set_progress(0.0)
	set_secret_count(0, GameConfig.SECRET_TOTAL)


## What replaces the top bar's slab.
##
## The bar used to sit on an opaque rounded panel 1110x212 — a sixth of the
## screen, painted over the yard, with a hard edge all the way round. It read
## as a control panel bolted on top of the game, which is the single loudest
## reason the HUD looked like an application rather than a game.
##
## A gradient does the same job without the box: it is strongest where the text
## is and gone by the time it reaches the grass, so there is no edge to notice.
## Same technique as the main menu, where the rows over the illustration
## measured 5-8:1 against the art behind them.
func _build_top_scrim() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.04, 0.03, 0.82))
	grad.add_point(0.55, Color(0.03, 0.04, 0.03, 0.55))
	grad.set_color(grad.get_point_count() - 1, Color(0.03, 0.04, 0.03, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	var scrim := TextureRect.new()
	scrim.name = "TopScrim"
	scrim.texture = tex
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	scrim.offset_bottom = 400.0
	add_child(scrim)
	# Behind every readout, including the ones the scene file already placed.
	move_child(scrim, 1)


# ---------------------------------------------------------------- progress

func set_progress(ratio: float) -> void:
	_target_percent = clampf(ratio, 0.0, 1.0) * 100.0


func _process(delta: float) -> void:
	if absf(_target_percent - _shown_percent) > 0.01:
		_shown_percent = lerpf(_shown_percent, _target_percent,
			clampf(delta * 9.0, 0.0, 1.0))
		_apply_percent()


## The bar and the number are one object now, so the number no longer repeats
## what the bar is measuring — "37%" beside a mowing bar does not need the word
## "mowed" after it, and the long form was the second of two elements saying
## one fact.
func _apply_percent() -> void:
	_percent_label.text = tr("UI_PERCENT_SHORT").format(
		{"pct": int(round(_shown_percent))})
	_progress.value = _shown_percent


# ---------------------------------------------------------------- secrets

func set_secret_count(found: int, total: int) -> void:
	# G7: evidence, not secrets. The clipboard beside it is a drawn icon node
	# now, not a glyph in this string (G12.10).
	_secret_counter.text = tr("UI_EVIDENCE_COUNTER").format({
		"found": found, "total": total})


func bump_secret_counter() -> void:
	if _counter_tween and _counter_tween.is_valid():
		_counter_tween.kill()
	_evidence_chip.pivot_offset = _evidence_chip.size * 0.5
	_evidence_chip.scale = Vector2(1.35, 1.35)
	_counter_tween = create_tween()
	_counter_tween.tween_property(_evidence_chip, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows the discovery card, then shrinks it into the secret counter (§16).
## `on_landed` fires when it reaches the counter, so the count updates then.
func show_secret_card(emoji: String, item_name: String, line: String,
		on_landed: Callable, evidence_id := "") -> void:
	_card_header.text = Story.text("evidence.card_header", "EVIDENCE FOUND")
	_show_card_art(emoji, evidence_id)
	_card_title.text = item_name
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
		total_secrets: int, payout := {}, next_name := "") -> void:
	_shown_percent = 100.0
	_apply_percent()
	# A harvest was cut, not searched, and the panel has to stop saying
	# otherwise: title, stats line and the pay row all have their own wording
	# (G13.6). The panel is built once, so this runs before any of them.
	var is_harvest := LevelVariant.current != null and LevelVariant.current.is_harvest()
	_complete_title.text = tr("HARVEST_DONE_TITLE") if is_harvest \
		else Story.text("complete.title", "AREA SEARCHED")
	_complete_stats.text = (tr("HARVEST_STATS") if is_harvest else tr("UI_STATS")) \
		.format({"cells": cells, "time": elapsed})

	for child in _collection.get_children():
		child.queue_free()
	for i in total_secrets:
		# The object itself above its name. This was an emoji, which is a blank
		# box on iOS - the default font carries no emoji glyphs (G12.10).
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 4)
		# Wide enough for a two-word name to wrap on words. At the preview's own
		# 96 px the captions broke mid-syllable.
		slot.custom_minimum_size = Vector2(200, 0)
		var caption := Label.new()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", 30)
		if i < collected.size():
			var entry: Dictionary = collected[i]
			var preview := ItemPreview.new()
			preview.view_size = SLOT_VIEW
			preview.spin = false
			preview.custom_minimum_size = Vector2(0, 96)
			slot.add_child(preview)
			preview.show_item(str(entry.get("id", "")))
			caption.text = str(entry.get("name", ""))
			caption.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
		else:
			var empty := Label.new()
			empty.text = "?"
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.custom_minimum_size = Vector2(0, 96)
			empty.add_theme_font_size_override("font_size", 52)
			empty.add_theme_color_override("font_color", Color(0.55, 0.58, 0.52))
			slot.add_child(empty)
			caption.text = tr("UI_EMPTY_SLOT")
			caption.add_theme_color_override("font_color", Color(0.55, 0.58, 0.52))
		slot.add_child(caption)
		_collection.add_child(slot)

	_clear_opening_title()
	set_poster_visible(false)
	_exit_card.visible = false
	_exit_badge.visible = false
	_build_case_notes(collected, total_secrets)
	_build_payout(payout)
	# A real door when a next chapter exists; hidden when there is none (last
	# chapter, or the scene is running standalone with no flow above it).
	_teaser.visible = next_name != ""
	if next_name != "":
		_teaser.text = tr("UI_NEXT_CHAPTER").format({"name": next_name})
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


## The one-time orientation sheet (G15). Shown a few seconds into the FIRST
## search, never again. It repeats what the intro said, on purpose: by now the
## player has their hands on the mower and the sentence lands differently.
##
## Pauses the tree while it is up, so nothing is being mown behind it.
func show_orientation(on_closed: Callable) -> void:
	var dim := ColorRect.new()
	dim.name = "OrientationDim"
	dim.color = Color(0.03, 0.04, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var sheet := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.10, 0.09, 0.98)
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(34)
	sheet.add_theme_stylebox_override("panel", style)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sheet.offset_left = -470.0
	sheet.offset_right = 470.0
	sheet.offset_top = -520.0
	sheet.offset_bottom = 520.0
	dim.add_child(sheet)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 22)
	sheet.add_child(rows)

	var face := TextureLibrary.find("portraits/face_ellie")
	if face != null:
		var picture := TextureRect.new()
		picture.texture = face
		picture.custom_minimum_size = Vector2(0, 300)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rows.add_child(picture)

	for spec: Array in [["FIRST_TITLE", 46, GameConfig.CASE_ACCENT],
			["FIRST_L1", 34, Color(0.95, 0.93, 0.88)],
			["FIRST_L2", 30, GameConfig.CASE_MUTED],
			["FIRST_L3", 30, GameConfig.CASE_MUTED]]:
		var line := Label.new()
		line.text = tr(str(spec[0]))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", int(spec[1]))
		line.add_theme_color_override("font_color", spec[2])
		rows.add_child(line)

	var go := Button.new()
	go.text = tr("FIRST_OK")
	go.custom_minimum_size = Vector2(0, 112)
	go.add_theme_font_size_override("font_size", 38)
	_style_primary(go)
	rows.add_child(go)
	go.pressed.connect(func() -> void:
		Haptics.medium()
		get_tree().paused = false
		dim.queue_free()
		on_closed.call())

	get_tree().paused = true
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.modulate.a = 0.0
	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(dim, "modulate:a", 1.0, 0.3)


## Draws attention to Ellie's poster for a few seconds at the start of a first
## run: a slow pulse, no interruption (G15).
func pulse_poster(seconds: float) -> void:
	if _poster == null or not is_instance_valid(_poster):
		return
	var beat := create_tween()
	beat.set_loops(int(seconds / 1.4))
	beat.tween_property(_poster, "modulate",
		Color(1.35, 1.28, 1.12), 0.7).set_trans(Tween.TRANS_SINE)
	beat.tween_property(_poster, "modulate", Color.WHITE, 0.7) \
		.set_trans(Tween.TRANS_SINE)


## A short line from the Marshal over the radio (G13.4). One at a time: a
## second one replaces the first rather than stacking.
func show_scent(key: String) -> void:
	if _scent_toast != null and is_instance_valid(_scent_toast):
		_scent_toast.queue_free()
	var toast := PanelContainer.new()
	toast.name = "ScentToast"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.10, 0.92)
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	toast.add_theme_stylebox_override("panel", style)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	# Below the MISSING poster, which lives in the top right: at 340 the two
	# overlapped (G13.4).
	toast.offset_left = -420.0
	toast.offset_right = 420.0
	toast.offset_top = 530.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	toast.add_child(row)
	var mark := Label.new()
	mark.text = "//"
	mark.add_theme_font_size_override("font_size", 30)
	mark.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	row.add_child(mark)
	var line := Label.new()
	line.text = tr(key)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_font_size_override("font_size", 30)
	line.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
	row.add_child(line)
	add_child(toast)
	_scent_toast = toast
	toast.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(toast, "modulate:a", 1.0, 0.25)
	fade.tween_interval(GameConfig.SCENT_TOAST_SECONDS)
	fade.tween_property(toast, "modulate:a", 0.0, 0.45)
	fade.tween_callback(toast.queue_free)


## Holds the full-width interface strips to UI_MAX_WIDTH and centres them, so a
## desktop window does not stretch the top bar across the whole monitor with a
## hole in the middle (G14). On a phone the margin is zero and nothing moves.
func _centre_for_wide_screens() -> void:
	var wide := get_viewport_rect().size.x
	var margin := maxf(0.0, (wide - GameConfig.UI_MAX_WIDTH) * 0.5)
	for entry: Array in [["TopBarPanel", 30.0], ["TopBar", 56.0],
			["CompletePanel", 0.0], ["OpeningTitle", 0.0]]:
		var node := get_node_or_null(NodePath(entry[0])) as Control
		if node == null:
			continue
		node.offset_left = margin + float(entry[1])
		node.offset_right = -margin - float(entry[1])
	# Controls pinned to the right edge — pause, home, the MISSING poster — are
	# pulled in by the same margin, so they stay beside the bar instead of
	# drifting to the far corner of a wide monitor.
	for child in get_children():
		var control := child as Control
		if control == null or not control.get_meta("hug_right", false):
			continue
		if not control.has_meta("edge_offsets"):
			control.set_meta("edge_offsets",
				Vector2(control.offset_left, control.offset_right))
		var kept: Vector2 = control.get_meta("edge_offsets")
		control.offset_left = kept.x - margin
		control.offset_right = kept.y - margin


func _refresh_mute_label() -> void:
	# Drawn speaker, not an emoji glyph (G12.10).
	_mute_button.text = ""
	_mute_button.icon = UiIcons.sound(not AudioDirector.muted)
	_mute_button.expand_icon = false


# ---------------------------------------------------------------- case framing (G7/G8)

## Kept as the styling hook; the panels it used to style moved into DialogueBox
## when the briefing became a conversation (G8).
## Primary: filled accent, for the action that moves the story forward.
func _style_primary(button: Button) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.72, 0.58, 0.24)
	base.set_corner_radius_all(22)
	base.set_content_margin_all(24)
	base.shadow_color = Color(0, 0, 0, 0.45)
	base.shadow_size = 8
	button.add_theme_stylebox_override("normal", base)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.88, 0.72, 0.34)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", base)
	button.add_theme_color_override("font_color", Color(0.08, 0.07, 0.05))
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.07, 0.05))
	button.add_theme_color_override("font_hover_color", Color(0.08, 0.07, 0.05))


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
	# Hierarchy: continuing the case is the primary action everywhere.
	# One primary per screen: NEXT owns the case-notes panel, CONTINUE owns the
	# exit card. Everything else is secondary, so the eye lands on the door.
	_style_primary(_exit_continue)
	_style_primary(_teaser)
	_style_primary(_exit_badge)
	for button: Button in [_exit_keep, _return_button, _board_button,
			%RestartButton as Button]:
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


## True if this chapter id is one of Case 02's. Asked of the story data rather
## than of ChapterProgress, because the HUD must name the right case even while
## the case is still locked on the board (a replay, or a dev run).
func _belongs_to_case_two(variant_id: String) -> bool:
	for chapter: Dictionary in Story.list("case_02.chapters"):
		if str(chapter.get("variant_id", "")) == variant_id:
			return true
	return false


## Pulls every fixed string out of data/story.json. Called once at _ready, so a
## story-file edit needs no scene edit.
func _apply_story_text() -> void:
	# A harvest is not a case: the bar says what this level actually is (G13.6).
	# And a Case 02 chapter is not Case 01: the bar names the case the chapter
	# belongs to, or it spent the whole eastern road claiming to be looking for
	# a girl who was found in the first act (G13).
	var variant := LevelVariant.current
	if variant != null and variant.is_harvest():
		_case_line.text = tr("HARVEST_HUD_LINE")
	else:
		var case_path := "case.hud_line"
		if variant != null and _belongs_to_case_two(variant.id):
			case_path = "case_02.hud_line"
		_case_line.text = Story.text(case_path)
	_complete_title.text = Story.text("complete.title", "AREA SEARCHED")
	_missed_label.text = Story.text("complete.incomplete",
		"The search feels incomplete...")
	_notes_header.text = Story.text("complete.notes_header", "CASE NOTES")

	_teaser_locked.visible = false
	_opening_headline.text = Story.text("opening.headline")
	_opening_subline.text = Story.text("opening.subline")
	_card_header.text = Story.text("evidence.card_header", "EVIDENCE FOUND")
	_return_button.text = tr("UI_RETURN_TOWN")
	_board_button.text = tr("BOARD_VIEW")
	_exit_title.text = tr("EXIT_ALL_FOUND")
	_exit_continue.text = tr("EXIT_CONTINUE")
	_exit_keep.text = tr("EXIT_KEEP_MOWING")
	_exit_badge.text = tr("EXIT_BADGE")


## The "LAST MOWED" title: holds while the camera settles onto the lawn, then
## fades. Kept from G1 but tied to the case — the second line is the new part.
func show_opening_title(headline_key := "", subline_key := "") -> void:
	# Per-chapter openers (G9.3): the 847-days line belonged to ONE house, and
	# every other site deserves its own condition report.
	if headline_key != "":
		_opening_headline.text = tr(headline_key)
	if subline_key != "":
		_opening_subline.text = tr(subline_key)
	_opening.modulate.a = 0.0
	if _opening_tween and _opening_tween.is_valid():
		_opening_tween.kill()
	_opening_tween = create_tween()
	_opening_tween.tween_property(_opening, "modulate:a", 1.0, 0.7)
	_opening_tween.tween_interval(GameConfig.OPENING_TITLE_HOLD)
	_opening_tween.tween_property(_opening, "modulate:a", 0.0,
		GameConfig.OPENING_TITLE_FADE)
	# The case line has served its purpose once the title is gone: objectives
	# parked over play are noise (the PowerWash lesson), and the hub repeats it.
	var line_tween := create_tween()
	line_tween.tween_interval(GameConfig.CASE_LINE_HOLD)
	line_tween.tween_property(_case_line, "modulate:a", 0.0, 1.2)


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
		# A thumbnail of the object where the bullet's emoji used to be.
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var thumb := ItemPreview.new()
		thumb.view_size = NOTE_VIEW
		thumb.spin = false
		thumb.custom_minimum_size = Vector2(56, 56)
		# Centred against a note that may wrap to two lines.
		thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(thumb)
		thumb.show_item(str(entry.get("id", "")))
		var row := Label.new()
		var where := str(entry.get("where", ""))
		row.text = str(entry.get("name", ""))
		if where != "":
			# Where it turned up: the case notes should read like notes, and a
			# place is what makes a line of evidence a memory.
			row.text += "  —  %s" % where
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 36)
		row.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
		line.add_child(row)
		_notes_list.add_child(line)
	if collected.is_empty() and not (LevelVariant.current != null \
			and LevelVariant.current.is_harvest()):
		var none := Label.new()
		none.text = "· " + tr("UI_NOTHING_RECOVERED")
		none.add_theme_font_size_override("font_size", 36)
		none.add_theme_color_override("font_color", Color(0.6, 0.62, 0.58))
		_notes_list.add_child(none)
	var harvest := LevelVariant.current != null and LevelVariant.current.is_harvest()
	if harvest:
		# No evidence, no case progress: the panel says what was actually
		# achieved and gets out of the way.
		_notes_progress.text = tr(HarvestLog.crumb_key())
		_notes_header.text = tr("HARVEST_COMPLETE")
		return
	_notes_progress.text = Story.text("complete.notes_full") if collected.size() >= total \
		else Story.text("complete.notes_partial")
	# What this search did to the TOWN, not to the case. The theme of G13.4 in
	# one line: every lawn you clear, the town breathes a little easier.
	var variant := LevelVariant.current
	if variant != null and variant.reclaim_line != "":
		var reclaimed := Label.new()
		reclaimed.text = "+ " + tr(variant.reclaim_line)
		reclaimed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reclaimed.add_theme_font_size_override("font_size", 32)
		reclaimed.add_theme_color_override("font_color", Color(0.62, 0.86, 0.54))
		_notes_list.add_child(reclaimed)


func _on_teaser_pressed() -> void:
	Haptics.medium()
	next_chapter_requested.emit()


# ---------------------------------------------------------------- G9 economy

## The scrap total is not something the player acts on while driving — it is
## paid out at the end of the run, and a five-digit number parked in the corner
## for the whole chapter is furniture. What matters is the MOMENT it changes,
## so the chip now appears when it does and leaves again afterwards.
##
## The first call comes from setup, before the run starts; that one must not
## flash the chip, hence _wallet_ready.
func set_scrap(total: int) -> void:
	_scrap_label.text = "%d" % total
	if _wallet_ready:
		show_wallet()
	_wallet_ready = true


## Brings the chip in, holds it, and takes it away again. Called on every
## change and by fly_scrap when a pickup lands.
func show_wallet() -> void:
	if _wallet_chip == null or not is_instance_valid(_wallet_chip):
		return
	if _wallet_tween != null and _wallet_tween.is_valid():
		_wallet_tween.kill()
	_wallet_chip.visible = true
	_wallet_chip.modulate.a = 1.0
	_wallet_tween = create_tween()
	_wallet_tween.tween_interval(WALLET_HOLD)
	_wallet_tween.tween_property(_wallet_chip, "modulate:a", 0.0, 0.5)
	_wallet_tween.tween_callback(func() -> void:
		if is_instance_valid(_wallet_chip):
			_wallet_chip.visible = false)


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
	# The chip has to be on screen before the value can fly to it, or the
	# target would be the rect of a hidden control.
	show_wallet()
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
	var bonus_key := "HARVEST_PAYOUT_BONUS" if LevelVariant.current != null \
		and LevelVariant.current.is_harvest() else "PAYOUT_BONUS"
	var rows := [
		[tr("PAYOUT_GROUND"), int(payout.get("ground", 0)), false],
		[tr(bonus_key).format(
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
		var coin := TextureRect.new()
		coin.texture = UiIcons.money()
		coin.custom_minimum_size = Vector2(34, 34)
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var value_label := Label.new()
		value_label.text = "%d" % int(row[1])
		value_label.add_theme_font_size_override("font_size", 34)
		if bool(row[2]):
			for label in [name_label, value_label]:
				label.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
		line.add_theme_constant_override("separation", 8)
		line.add_child(name_label)
		line.add_child(coin)
		line.add_child(value_label)
		_payout_list.add_child(line)


# ---------------------------------------------------------------- pad ring (G9.2)

## The drag pad had no visual body, so players never learned the system exists.
## A soft ring appears where the finger lands and a dot tracks the drag — the
## ghost-joystick every mobile driver uses.
func _build_pad_ring() -> void:
	_pad_ring = Control.new()
	_pad_ring.name = "PadRing"
	_pad_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad_ring.draw.connect(_draw_pad_ring)
	# On top of the whole HUD: it was first tried at index 0 and the Overlay
	# vignette swallowed it. The pad only engages on lawn touches, so it can
	# never draw over an open panel anyway.
	add_child(_pad_ring)

	_drive_hint = Label.new()
	_drive_hint.text = tr("HINT_DRIVE")
	_drive_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drive_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# Below the evidence card, which grew in G10.2 and now reaches 0.74.
	_drive_hint.anchor_top = 0.83
	_drive_hint.anchor_bottom = 0.83
	_drive_hint.offset_left = -520
	_drive_hint.offset_right = 520
	_drive_hint.add_theme_font_size_override("font_size", 44)
	_drive_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_drive_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_drive_hint.add_theme_constant_override("shadow_offset_y", 4)
	_drive_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drive_hint.visible = false
	add_child(_drive_hint)


## Fed every frame by Game with the active mower's pad state.
func set_pad_state(active: bool, origin: Vector2, now: Vector2) -> void:
	if active != _pad_active or (active and now != _pad_now):
		_pad_active = active
		_pad_origin = origin
		_pad_now = now
		_pad_ring.queue_redraw()
	if active and _drive_hint.visible \
			and origin.distance_to(now) > GameConfig.DRAG_THRESHOLD_PT * GameConfig.POINT_SCALE:
		# A real drag happened: the hint has done its job, forever.
		_drive_hint.visible = false
		GameState.set_setting("hints", GameConfig.HINT_DRIVE_KEY, true)


## Shown by Game when the search starts, once per install.
func show_drive_hint() -> void:
	if bool(GameState.get_setting("hints", GameConfig.HINT_DRIVE_KEY, false)):
		return
	_drive_hint.visible = true
	_drive_hint.modulate.a = 0.0
	var tw := create_tween().set_loops()
	tw.tween_property(_drive_hint, "modulate:a", 1.0, 0.8)
	tw.tween_property(_drive_hint, "modulate:a", 0.45, 0.8)


func _draw_pad_ring() -> void:
	if not _pad_active:
		return
	_pad_ring.draw_circle(_pad_origin, 74.0, Color(1, 1, 1, 0.10))
	_pad_ring.draw_arc(_pad_origin, 74.0, 0.0, TAU, 40, Color(1, 1, 1, 0.32), 4.0)
	# The dot is clamped to the ring so a long sweep still reads as a stick.
	var to := _pad_now - _pad_origin
	if to.length() > 66.0:
		to = to.normalized() * 66.0
	_pad_ring.draw_circle(_pad_origin + to, 22.0, Color(1, 1, 1, 0.45))


# ---------------------------------------------------------------- pause (G9.3)

## A small ⏸ where STORY used to sit, opening a minimal sheet: resume, sound,
## return to town, restart. Runs on PROCESS_MODE_ALWAYS so it works while the
## tree is paused; everything else (mowers, tweens, engine audio) freezes with
## get_tree().paused, which is exactly the point.
func _build_pause() -> void:
	_pause_button = Button.new()
	_pause_button.text = "⏸"
	_pause_button.add_theme_font_size_override("font_size", 44)
	# Right end of the new top bar, aligned with the percentage row.
	_pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause_button.set_meta("hug_right", true)
	_pause_button.offset_left = -152
	_pause_button.offset_right = -48
	_pause_button.offset_top = 94
	_pause_button.offset_bottom = 178
	_style_button(_pause_button)
	_pause_button.pressed.connect(_open_pause)
	add_child(_pause_button)

	# Going back to town was buried one tap inside the pause sheet, so players
	# reported there was no way out at all. This is that exit, on the bar.
	var home := Button.new()
	home.text = "⌂"
	home.add_theme_font_size_override("font_size", 46)
	home.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	home.set_meta("hug_right", true)
	home.offset_left = -278
	home.offset_right = -174
	home.offset_top = 94
	home.offset_bottom = 178
	_style_button(home)
	home.pressed.connect(func() -> void:
		Haptics.light()
		return_requested.emit())
	add_child(home)

	_pause_layer = Control.new()
	_pause_layer.name = "PausePanel"
	_pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.visible = false
	add_child(_pause_layer)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.6)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(scrim)

	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -400
	card.offset_right = 400
	card.offset_top = -330
	card.offset_bottom = 330
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.CASE_PANEL
	style.set_corner_radius_all(28)
	style.set_content_margin_all(44)
	style.border_color = Color(GameConfig.CASE_ACCENT, 0.4)
	style.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", style)
	_pause_layer.add_child(card)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	card.add_child(rows)

	var resume := Button.new()
	resume.text = tr("UI_RESUME")
	resume.add_theme_font_size_override("font_size", 46)
	_style_primary(resume)
	resume.pressed.connect(_close_pause)
	rows.add_child(resume)

	var sound := Button.new()
	sound.add_theme_font_size_override("font_size", 42)
	_style_button(sound)
	var refresh_sound := func() -> void:
		sound.text = ""
		sound.icon = UiIcons.sound(not AudioDirector.muted)
		sound.expand_icon = false
	refresh_sound.call()
	sound.pressed.connect(func() -> void:
		AudioDirector.muted = not AudioDirector.muted
		refresh_sound.call()
		_refresh_mute_label())
	rows.add_child(sound)

	var town := Button.new()
	town.text = tr("UI_RETURN_TOWN")
	town.add_theme_font_size_override("font_size", 42)
	_style_button(town)
	town.pressed.connect(func() -> void:
		_close_pause()
		return_requested.emit())
	rows.add_child(town)

	# Balance testing only: ships disabled, so it costs nothing at runtime.
	if GameConfig.DEV_GRANT_SCRAP:
		var grant := Button.new()
		grant.text = "DEV +%d" % GameConfig.DEV_GRANT_AMOUNT
		grant.add_theme_font_size_override("font_size", 38)
		_style_button(grant)
		grant.pressed.connect(func() -> void:
			GameState.add_scrap(GameConfig.DEV_GRANT_AMOUNT)
			set_scrap(GameState.scrap_total()))
		rows.add_child(grant)

	var restart := Button.new()
	restart.text = tr("UI_RESTART")
	restart.add_theme_font_size_override("font_size", 42)
	_style_button(restart)
	restart.pressed.connect(func() -> void:
		_close_pause()
		restart_pressed.emit())
	rows.add_child(restart)


## Opens the pause sheet because the app lost focus, never closes it. Silent —
## no haptic, no click — since the player is not looking (G14.1).
func pause_for_background() -> void:
	if _pause_layer == null or _pause_layer.visible:
		return
	_pause_layer.visible = true
	get_tree().paused = true


## Escape on the desktop build: opens the sheet, or closes it if it is already
## open, which is what a keyboard player expects from that key (G14).
func toggle_pause() -> void:
	if _pause_layer != null and _pause_layer.visible:
		_close_pause()
	else:
		_open_pause()


func _open_pause() -> void:
	Haptics.light()
	_pause_layer.visible = true
	get_tree().paused = true


func _close_pause() -> void:
	_pause_layer.visible = false
	get_tree().paused = false


# ---------------------------------------------------------------- echoes (G12.6)

## The echo card reuses the evidence card's body but says ECHO and drops the
## fly-to-counter flourish: a world-history find is a quiet aside, not a beat in
## the case, and dressing it like one would lie about its importance.
func show_echo_card(emoji: String, item_name: String, line: String,
		evidence_id := "") -> void:
	_card_header.text = tr("ECHO_HEADER")
	_card_header.add_theme_color_override("font_color", Color(0.70, 0.78, 0.88))
	_show_card_art(emoji, evidence_id)
	_card_title.text = item_name
	_card_line.text = line

	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()
	if _card_home == Vector2.ZERO:
		_card_home = _secret_card.position
	_secret_card.position = _card_home
	_secret_card.pivot_offset = _secret_card.size * 0.5
	_secret_card.scale = Vector2(0.9, 0.9)
	_secret_card.modulate.a = 0.0
	_secret_card.visible = true

	_card_tween = create_tween()
	_card_tween.tween_property(_secret_card, "modulate:a", 1.0, 0.25)
	_card_tween.parallel().tween_property(_secret_card, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.tween_interval(GameConfig.CARD_SHOW_TIME)
	_card_tween.tween_property(_secret_card, "modulate:a", 0.0, 0.35)
	_card_tween.tween_callback(func() -> void:
		_secret_card.visible = false
		# Put the header back the way the evidence card expects to find it.
		_card_header.add_theme_color_override("font_color",
			GameConfig.CASE_ACCENT))


## The card's object view. The emoji label stays as the fallback for anything
## with no mesh, but on device it renders blank, so the 3D preview is what the
## player actually sees.
func _build_card_preview() -> void:
	_card_preview = ItemPreview.new()
	_card_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_art.add_child(_card_preview)


func _show_card_art(emoji: String, evidence_id: String) -> void:
	if evidence_id != "":
		_card_art.text = ""
		_card_preview.visible = true
		_card_preview.show_item(evidence_id)
		return
	_card_preview.visible = false
	# Stripped, not shown: one emoji on screen loads the OS colour-emoji font
	# and 184 MB with it, for a glyph iOS draws as a blank box anyway (G16).
	_card_art.text = GlyphGuard.safe(emoji)


## A small MISSING poster under the top bar. It is the only piece of HUD that
## exists purely to be looked at rather than read for state — the case's face,
## so the search never becomes an abstract percentage.
func _build_poster() -> void:
	_poster = PanelContainer.new()
	_poster.name = "MissingPoster"
	_poster.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_poster.set_meta("hug_right", true)
	_poster.offset_left = -250
	_poster.offset_right = -40
	_poster.offset_top = 306
	# Room for the caption line under the date (G14.1).
	_poster.offset_bottom = 626
	_poster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.90, 0.80, 0.94)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	style.border_color = Color(0.35, 0.28, 0.20, 0.9)
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	_poster.add_theme_stylebox_override("panel", style)
	add_child(_poster)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poster.add_child(rows)

	var heading := Label.new()
	heading.text = tr("POSTER_MISSING")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.55, 0.12, 0.10))
	rows.add_child(heading)

	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(0, 150)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture = TextureLibrary.find("portraits/face_ellie")
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(face)

	var name_label := Label.new()
	name_label.text = tr("POSTER_NAME")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color(0.18, 0.15, 0.12))
	rows.add_child(name_label)

	var since := Label.new()
	since.text = tr("POSTER_SINCE")
	since.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	since.add_theme_font_size_override("font_size", 20)
	since.add_theme_color_override("font_color", Color(0.34, 0.30, 0.26))
	rows.add_child(since)

	# The photograph's own caption. It dates the picture to hours ago, which is
	# the whole reason the poster is unbearable to look at (G14.1).
	var taken := Label.new()
	taken.text = tr("POSTER_TAKEN")
	taken.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	taken.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	taken.add_theme_font_size_override("font_size", 17)
	taken.add_theme_color_override("font_color", Color(0.42, 0.36, 0.30))
	rows.add_child(taken)


## A harvest is a job, not a search: no evidence counter, no missing poster, and
## the bar names the errand. Called from Game._ready, because the HUD's own
## _ready runs before the variant is applied (G13.6).
func apply_harvest_mode() -> void:
	_case_line.text = tr("HARVEST_HUD_LINE")
	_evidence_chip.visible = false
	set_poster_visible(false)


## Hidden once the search is over, so it never sits behind the results panel.
func set_poster_visible(value: bool) -> void:
	if _poster != null:
		_poster.visible = value
