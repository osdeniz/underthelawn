class_name HubScreen
extends Control
## G8 community hub: the screen the player returns to between searches.
##
## 2D only — no 3D navigation. A full-screen portrait illustration with three
## tappable cards over it, plus two panels that slide in over the same
## background: the case board (chapter selection) and the town (NPC chatter).
##
## Chapter selection emits `chapter_chosen(variant_id)`. It deliberately carries
## an ID, never a scene path: G9 builds every chapter from ONE game scene plus
## variant data, so "one .tscn per chapter" must never become an assumption
## anywhere in this flow.

## The player picked a chapter to search; the argument is a story.json
## chapters[].variant_id.
signal chapter_chosen(variant_id: String)
## Replay the opening cards (the STORY button moved here from the game HUD).
signal replay_intro_requested()

const PANEL_FADE := 0.22


## Shared button styles for every hub-family page (workshop, board): filled
## accent for the one action that spends or progresses, dark card for the rest.
static func style_primary(button: Button) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.72, 0.58, 0.24)
	base.set_corner_radius_all(20)
	base.set_content_margin_all(22)
	button.add_theme_stylebox_override("normal", base)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.88, 0.72, 0.34)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", base)
	for state in ["font_color", "font_pressed_color", "font_hover_color"]:
		button.add_theme_color_override(state, Color(0.08, 0.07, 0.05))


## A tab always states its own name clearly; only its GROUND changes. Styling
## the inactive tab as a dark card made its label unreadable over the artwork.
static func _style_tab(tab: Button, active: bool) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.76, 0.62, 0.26) if active \
		else Color(0.16, 0.16, 0.15, 0.95)
	base.set_corner_radius_all(18)
	base.set_content_margin_all(18)
	base.border_color = Color(GameConfig.CASE_ACCENT, 0.9 if active else 0.35)
	base.set_border_width_all(3)
	for state in ["normal", "hover", "pressed", "focus"]:
		tab.add_theme_stylebox_override(state, base)
	var ink := Color(0.08, 0.07, 0.05) if active else Color(0.94, 0.92, 0.86)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		tab.add_theme_color_override(state, ink)


static func style_secondary(button: Button) -> void:
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

var _background: TextureRect
## The live 3D town behind the cards. Uses stay guarded because the scene could
## fail to load, not because there is another mode to fall back to.
var _diorama: TownDiorama
## How far the parked diorama viewport shrinks while a chapter is on screen.
## Anything past ~32 costs nothing; this leaves a 36x79 target rather than 0,
## because a zero-sized viewport is an error rather than a saving.
const DIORAMA_PARKED_SHRINK := 32

var _diorama_view: SubViewport
## The container owning that viewport. stretch = true means IT decides the
## render size, so releasing the town's framebuffer goes through stretch_shrink
## here rather than through _diorama_view.size (G16).
var _diorama_frame: SubViewportContainer
var _diorama_tick := 0
## Which restore card is being held down, if any (G13.5).
var _peek_wanted := ""
var _tiles_page: Control
## The Case screen's entry view (UI/UX redesign): a summary rather than the
## raw corkboard — current lead, area progress, discoveries — with the full
## board one tap deeper for anyone who wants it. Built on first use like the
## board itself, and for the same reason: it renders an evidence preview per
## found item, which is not free.
## The hub's own top-bar case name. Kept, because it was written once at build
## time from story.json's "case" block and never updated — so a player deep in
## Case 02 read "KAYIP KIZ" over "VAKA 02 · 9/10", two different cases stacked
## in three lines of the same header.
var _journal: JournalScreen
var _case_name_label: Label
var _case_summary_page: Control
var _case_lead_label: Label
var _case_areas_row: HBoxContainer
var _case_discoveries_label: Label
var _case_next_button: Button
var _board_page: Control
var _town_page: Control
var _workshop_page: WorkshopPage
var _board_view: EvidenceBoard
var _board_scroll: ScrollContainer
var _board_tab_places: Button
## The two-layer case map (G13.5), which replaced the PLACES list.
var _map: TownMap
var _board_tab_evidence: Button
var _scrap_label: Label
var _restore_page: Control
var _echoes_page: Control
var _objectives_page: Control
var _objectives_button: Button
var _objective_list: VBoxContainer
var _restore_list: VBoxContainer
var _echo_list: VBoxContainer
var _restore_note: Label
var _tier2_announced := false
var _progress_label: Label
## "TOWN RECLAIMED %N" — chapters finished, not projects bought (G13.4).
var _reclaim_label: Label
var _dialogue: DialogueBox


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_top_bar()
	_tiles_page = _build_tiles()
	# The board is built on FIRST USE, not here (G13). It is the most expensive
	# page the hub owns — sixteen evidence cards, each rendering its object in
	# its own little 3D world, measured at 14.4 MB and sixteen draw calls a
	# frame — and a player who never opens it should not pay for it. Building it
	# costs 9.2 ms and its previews have pixels one frame later, both of which
	# disappear under the fade _show_page already runs.
	_town_page = _build_town()
	_workshop_page = _build_workshop()
	_restore_page = _build_restore()
	_echoes_page = _build_echoes()
	_objectives_page = _build_objectives()
	add_child(_tiles_page)
	add_child(_town_page)
	add_child(_workshop_page)
	add_child(_restore_page)
	add_child(_echoes_page)
	add_child(_objectives_page)
	_show_page(_tiles_page)


# ---------------------------------------------------------------- chrome

## The hub's backdrop is the live 3D town, and only that. The 2D collage it
## replaced, the hub_mode switch that chose between them, and the layer art the
## collage painted onto itself are all gone (G13.8) — the diorama earned it.
func _build_background() -> void:
	_build_diorama_background()


## The warm gradient the collage used as its ground. Still built: it sits behind
## the SubViewport and shows through if the 3D scene has not drawn yet.
func _build_ground_gradient() -> void:
	# Warm gradient ground, used as the fallback and as the letterbox behind an
	# illustration that does not match the screen aspect.
	var ground := TextureRect.new()
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.32, 0.22, 0.14))
	grad.set_color(1, Color(0.10, 0.09, 0.08))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	ground.texture = grad_tex
	add_child(ground)

	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := Story.raw("hub.background", "hub/town_square")
	var tex := TextureLibrary.find(art)
	_background.texture = tex
	_background.visible = tex != null
	if tex == null:
		TextureLibrary.warn_missing(art, "hub arkaplani = sicak degrade")
	add_child(_background)

	# Darkens the top and bottom so the bar and the cards stay readable over art.
	var scrim := TextureRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	# Light touch: the illustration already has its own vignette, and stacking a
	# heavy scrim on top turned the whole square muddy.
	sg.colors = PackedColorArray([
		Color(0, 0, 0, 0.46), Color(0, 0, 0, 0.06), Color(0, 0, 0, 0.62)])
	var sg_tex := GradientTexture2D.new()
	sg_tex.gradient = sg
	sg_tex.fill_from = Vector2(0.0, 0.0)
	sg_tex.fill_to = Vector2(0.0, 1.0)
	scrim.texture = sg_tex
	add_child(scrim)


## Two columns, not three stacked rows: the case identity on the left, the
## wallet as its own chip on the right. Stacking title + progress + money
## overflowed the panel, because three lines of that type simply do not fit a
## bar this tall — and growing the bar would eat the artwork instead.
func _build_top_bar() -> void:
	# PanelContainer, NOT Panel: a plain Panel does not lay out its children, so
	# the row collapsed to its own width and the wallet clung to the title.
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = 76
	panel.offset_bottom = 236
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.04, 0.70)
	panel_style.set_corner_radius_all(26)
	panel_style.content_margin_left = 30.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(columns)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 4)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(identity)

	_case_name_label = Label.new()
	var title := _case_name_label
	title.add_theme_font_size_override("font_size", GameConfig.UI_TITLE)
	title.add_theme_color_override("font_color", GameConfig.UI_INK)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(title)

	_reclaim_label = Label.new()
	_reclaim_label.add_theme_font_size_override("font_size", 26)
	_reclaim_label.add_theme_color_override("font_color", GameConfig.UI_GREEN)
	_reclaim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 30)
	_progress_label.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_progress_label)
	identity.add_child(_reclaim_label)

	# One chip, three readings: what the town has to spend, to eat, and to feed.
	#
	# Three separate chips was the first shape and it pushed the objectives
	# button off the bar — the scrap number alone runs to five digits. Grouping
	# them admits what they are: not three unrelated stats but one line about
	# the state of the place, which is also why they share a border instead of
	# each having their own.
	var wallet := PanelContainer.new()
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.09, 0.16, 0.09, 0.92)
	chip.set_corner_radius_all(18)
	chip.content_margin_left = 22.0
	chip.content_margin_right = 22.0
	chip.content_margin_top = 12.0
	chip.content_margin_bottom = 12.0
	chip.border_color = Color(0.40, 0.78, 0.42, 0.55)
	chip.set_border_width_all(2)
	wallet.add_theme_stylebox_override("panel", chip)
	columns.add_child(wallet)

	# PanelContainer holds one child, so the icon and the amount share a row.
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 8)
	wallet_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_child(wallet_row)

	var wallet_icon := TextureRect.new()
	wallet_icon.texture = UiIcons.money()
	wallet_icon.custom_minimum_size = Vector2(38, 38)
	wallet_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wallet_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wallet_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_row.add_child(wallet_icon)

	_scrap_label = Label.new()
	_scrap_label.add_theme_font_size_override("font_size", 40)
	_scrap_label.add_theme_color_override("font_color", GameConfig.UI_GREEN)
	_scrap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scrap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_row.add_child(_scrap_label)

	# Food and population. Both are placeholders for now (GameConfig says so);
	# they are here because the bar is where the player will look for them, and
	# adding the readout later would move everything else on the row.
	_add_stat(wallet_row, UiIcons.food(), GameConfig.TOWN_FOOD_PLACEHOLDER)
	_add_stat(wallet_row, UiIcons.people(), GameConfig.TOWN_PEOPLE_PLACEHOLDER)

	# The objectives door. A chip like the wallet, but pressable, with the
	# number of open objectives on it (G14.2).
	_objectives_button = Button.new()
	_objectives_button.name = "ObjectivesButton"
	# Wide enough for the icon AND the count: at 104 the two fought for room and
	# the icon lost, leaving a bare number in a dark chip.
	_objectives_button.custom_minimum_size = Vector2(150, 86)
	_objectives_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_objectives_button.icon = UiIcons.objectives()
	_objectives_button.expand_icon = false
	_objectives_button.tooltip_text = tr("OBJ_TITLE")
	var obj_chip := StyleBoxFlat.new()
	obj_chip.bg_color = Color(0.10, 0.12, 0.16, 0.92)
	obj_chip.set_corner_radius_all(18)
	obj_chip.set_content_margin_all(10)
	obj_chip.border_color = Color(0.55, 0.62, 0.74, 0.55)
	obj_chip.set_border_width_all(2)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		_objectives_button.add_theme_stylebox_override(state, obj_chip)
	_objectives_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objectives_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_objectives_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objectives_button.add_theme_constant_override("h_separation", 10)
	_objectives_button.add_theme_font_size_override("font_size", 34)
	_objectives_button.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_objectives_button.pressed.connect(func() -> void:
		Haptics.light()
		Analytics.track(AnalyticsEvents.OBJECTIVE_VIEWED, {})
		_show_page(_objectives_page))
	columns.add_child(_objectives_button)

	_refresh_progress()


## The badge is the count of what is still open. It is text on the button
## rather than a separate node: one label that can never drift out of place.
func _refresh_objectives_badge() -> void:
	if _objectives_button == null or not is_instance_valid(_objectives_button):
		return
	var open := Objectives.active_count()
	_objectives_button.text = "" if open <= 0 else str(open)


func _refresh_progress() -> void:
	# Per CASE, not per game: done_count() counts every chapter the player has
	# ever finished, which is the right number for the town but the wrong one
	# for a line that names one case (G13).
	var case_list := ChapterProgress.active_case_chapters()
	var case_id := "case_02.id" if ChapterProgress.active_case_is_two() \
		else "case.id"
	_progress_label.text = Story.text("hub.progress").format({
		"case": Story.text(case_id),
		"done": ChapterProgress.done_in(case_list),
		"total": case_list.size()})
	if _case_name_label != null and is_instance_valid(_case_name_label):
		_case_name_label.text = Story.text(
			"case_02.title" if ChapterProgress.active_case_is_two()
			else "case.title")
	_scrap_label.text = "%d" % GameState.scrap_total()
	if _reclaim_label != null and is_instance_valid(_reclaim_label):
		# Deliberately NOT tied to money: this is the measure of work done, and
		# the whole point of G13.4 is that mowing shows up in the town.
		# Clamped: the reclaim runs out at RECLAIM_STEPS, and with Case 02 on
		# the board done_count() goes past it (G13).
		var percent := clampi(int(round(100.0 * float(ChapterProgress.done_count())
			/ maxf(1.0, float(GameConfig.RECLAIM_STEPS)))), 0, 100)
		_reclaim_label.text = tr("HUB_RECLAIMED").format({"percent": percent})


# ---------------------------------------------------------------- pages

func _new_page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return page


func _show_page(page: Control) -> void:
	# Every page this screen owns, not a list someone has to remember to add to:
	# the objectives page was added in G14.2 and the hardcoded list did not
	# include it, so once opened it never closed again and drew on top of
	# whatever came next.
	for candidate in _pages():
		candidate.visible = candidate == page
	if page != _tiles_page:
		page.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(page, "modulate:a", 1.0, PANEL_FADE)
	_refresh_progress()


## Every full-screen page, in no particular order.
## The board page, building it the first time somebody asks. Every entry point
## to the board goes through this — the hub tile, the chapter-end "view case
## board" button, and the map — so there is no path that can reach a page that
## does not exist yet.
func _ensure_board_page() -> Control:
	if _board_page != null and is_instance_valid(_board_page):
		return _board_page
	_board_page = _build_board()
	_board_page.visible = false
	# Appended, like every other page. An earlier version moved it to index 2 to
	# "match _ready's order" and buried it behind the background and the
	# diorama, where it drew but could not be seen — the pages built in _ready
	# come AFTER the background and the top bar, not before them.
	add_child(_board_page)
	return _board_page


## Same lazy pattern as the board: nothing here is built until the player
## actually opens Case.
func _ensure_case_summary_page() -> Control:
	if _case_summary_page != null and is_instance_valid(_case_summary_page):
		return _case_summary_page
	_case_summary_page = _build_case_summary()
	_case_summary_page.visible = false
	add_child(_case_summary_page)
	return _case_summary_page


## The Case screen (UI/UX redesign). Where the old "VAKA PANOSU" tile opened
## straight onto a wall of eighteen chapter cards, this answers the three
## questions in order: what do I know, where do I stand, what do I do next.
## The full corkboard is one tap away for anyone who wants the detail — this
## is not a replacement for it, it is what used to be missing IN FRONT of it.
func _build_case_summary() -> Control:
	var page := _new_page()

	# A panel sized to its CONTENT, not to the screen. The first version used
	# the shared full-height backdrop and a case with a handful of areas left
	# two thirds of a lit rectangle empty underneath the last row — the single
	# most "unfinished" thing in the redesign.
	var card := PanelContainer.new()
	card.name = "CaseCard"
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 40
	card.offset_right = -40
	card.offset_top = 300
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.05, 0.05, 0.045, 0.90)
	skin.set_corner_radius_all(26)
	skin.border_color = Color(GameConfig.CASE_ACCENT, 0.22)
	skin.set_border_width_all(2)
	skin.set_content_margin_all(GameConfig.UI_GAP_WIDE)
	skin.shadow_color = Color(0, 0, 0, 0.45)
	skin.shadow_size = 12
	card.add_theme_stylebox_override("panel", skin)
	page.add_child(card)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", GameConfig.UI_GAP)
	card.add_child(rows)

	# NO case title here. The hub's top bar names the case two lines above this
	# card, in the same accent — printing it again made the screen open by
	# telling the player something they had just read, and pushed the lead (the
	# reason they opened it) further down.
	var case_objective := Label.new()
	case_objective.name = "CaseObjective"
	case_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	case_objective.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	case_objective.add_theme_color_override("font_color", GameConfig.UI_INK)
	rows.add_child(case_objective)

	rows.add_child(_case_divider())

	rows.add_child(_case_section_label("CASE_LEAD_LABEL"))
	_case_lead_label = Label.new()
	_case_lead_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_case_lead_label.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	_case_lead_label.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	rows.add_child(_case_lead_label)

	rows.add_child(_case_divider())

	rows.add_child(_case_section_label("CASE_AREAS_LABEL"))
	_case_areas_row = HBoxContainer.new()
	_case_areas_row.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
	var areas_wrap := ScrollContainer.new()
	areas_wrap.custom_minimum_size = Vector2(0, 60)
	areas_wrap.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	areas_wrap.add_child(_case_areas_row)
	rows.add_child(areas_wrap)

	rows.add_child(_case_divider())

	rows.add_child(_case_section_label("CASE_DISCOVERIES_LABEL"))
	_case_discoveries_label = Label.new()
	_case_discoveries_label.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	_case_discoveries_label.add_theme_color_override("font_color",
		GameConfig.UI_INK_SOFT)
	rows.add_child(_case_discoveries_label)

	rows.add_child(_case_divider())

	_case_next_button = Button.new()
	_case_next_button.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	_case_next_button.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	style_primary(_case_next_button)
	_case_next_button.pressed.connect(func() -> void:
		Haptics.medium()
		open_map_at(ChapterProgress.current_variant_id()))
	rows.add_child(_case_next_button)

	var full_file := Button.new()
	full_file.text = tr("CASE_OPEN_FULL_FILE")
	full_file.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	full_file.flat = true
	full_file.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	full_file.add_theme_color_override("font_color", GameConfig.CASE_MUTED)
	full_file.add_theme_color_override("font_hover_color", GameConfig.CASE_ACCENT)
	full_file.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	full_file.pressed.connect(func() -> void:
		Haptics.light()
		open_evidence_board())
	rows.add_child(full_file)

	page.add_child(_back_button())
	return page


func _case_divider() -> HSeparator:
	var line := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(GameConfig.CASE_ACCENT, 0.18)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	line.add_theme_stylebox_override("separator", style)
	return line


func _case_section_label(key: String) -> Label:
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	label.add_theme_color_override("font_color", Color(GameConfig.CASE_ACCENT, 0.9))
	return label


## Rebuilt on every visit — nothing here is cached, so a chapter finished
## elsewhere in the session always shows current.
func _refresh_case_summary() -> void:
	if _case_summary_page == null or not is_instance_valid(_case_summary_page):
		return
	var is_two := ChapterProgress.active_case_is_two()
	var case_path := "case_02" if is_two else "case"
	var chapters := ChapterProgress.active_case_chapters()

	var objective_label := _case_summary_page.find_child("CaseObjective", true,
		false) as Label
	if objective_label != null:
		objective_label.text = Story.text(case_path + ".objective")

	var next_id := ChapterProgress.current_variant_id()
	# done_in() against the case's OWN list, not a comparison against
	# current_variant_id()'s fallback: once every chapter is finished that
	# fallback returns the FIRST chapter again (so a replay is always on
	# offer), which made "is the last one done" compare the wrong two ids and
	# never detect a fully closed case.
	var all_done := ChapterProgress.done_in(chapters) >= chapters.size() \
		and not chapters.is_empty()
	if all_done:
		_case_lead_label.text = "\"%s\"" % tr("CASE_LEAD_CLOSED")
	else:
		var lead := LevelVariant.of(next_id).opening_subline
		_case_lead_label.text = "\"%s\"" % (tr(lead) if lead != "" else
			tr("CASE_LEAD_EMPTY"))

	for child in _case_areas_row.get_children():
		child.queue_free()
	for chapter: Dictionary in chapters:
		_case_areas_row.add_child(_case_area_dot(
			str(chapter.get("variant_id", "")), next_id))

	var found := 0
	var total := 0
	for chapter: Dictionary in chapters:
		var vid := str(chapter.get("variant_id", ""))
		# Clamped per chapter: evidence_found can briefly exceed a total that
		# was re-authored after a save recorded a higher count against the old
		# one. The gameplay number is unaffected; this only keeps the summary
		# from ever printing a count bigger than the whole it is part of.
		var chapter_total := ChapterProgress.evidence_total(vid)
		total += chapter_total
		found += mini(ChapterProgress.evidence_found(vid), chapter_total)
	_case_discoveries_label.text = tr("CASE_DISCOVERIES_COUNT").format(
		{"found": found, "total": total})

	if all_done:
		_case_next_button.text = tr("CASE_ALL_SEARCHED")
		_case_next_button.disabled = true
	else:
		_case_next_button.disabled = false
		_case_next_button.text = "%s: %s" % [tr("CASE_CONTINUE"),
			tr(str(ChapterProgress.entry(next_id).get("name", "")))]


## One area: a filled ring for a finished chapter, a pulsing amber ring for the
## one to go to next, a hollow ring for the rest. Colour never carries the
## state alone — a done ring also gets a check mark, so the distinction reads
## for a colour-blind player too.
func _case_area_dot(variant_id: String, next_id: String) -> Control:
	var done := ChapterProgress.is_done(variant_id)
	var is_next := variant_id == next_id
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(60, 60)
	dot.tooltip_text = tr(str(ChapterProgress.entry(variant_id).get("name", "")))
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(30)
	style.set_border_width_all(3)
	if done:
		style.bg_color = Color(0.30, 0.52, 0.30, 0.9)
		style.border_color = Color(0.52, 0.78, 0.48)
	elif is_next:
		style.bg_color = Color(GameConfig.CASE_ACCENT, 0.34)
		style.border_color = GameConfig.CASE_ACCENT
		style.set_border_width_all(5)
	else:
		style.bg_color = Color(0.12, 0.12, 0.11, 0.7)
		style.border_color = Color(0.4, 0.4, 0.38, 0.6)
	dot.add_theme_stylebox_override("panel", style)
	var mark := Label.new()
	mark.text = "✓" if done else ("●" if is_next else "○")
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	mark.add_theme_color_override("font_color",
		Color(0.94, 0.98, 0.92) if done else
		(GameConfig.CASE_ACCENT if is_next else Color(0.6, 0.6, 0.56)))
	dot.add_child(mark)
	return dot


func _pages() -> Array:
	var list: Array = []
	for candidate in [_tiles_page, _case_summary_page, _board_page, _town_page,
			_workshop_page, _restore_page, _echoes_page, _objectives_page]:
		if candidate != null and is_instance_valid(candidate):
			list.append(candidate)
	return list


## The three hub cards. A locked card is still shown and still responds, because
## One reading inside the resource chip: a hairline, an icon, a number.
##
## The divider is drawn rather than left as a gap because three numbers spaced
## evenly apart read as one long number at a glance; a rule between them says
## where each one stops.
func _add_stat(row: HBoxContainer, art: Texture2D, value: int) -> void:
	var rule := ColorRect.new()
	rule.color = GameConfig.UI_LINE
	rule.custom_minimum_size = Vector2(2, 34)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rule)

	var icon := TextureRect.new()
	icon.texture = art
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.text = str(value)
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", GameConfig.UI_INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)


## a visible locked door tells the player the game is bigger than this screen.
func _build_tiles() -> Control:
	var page := _new_page()
	# The column scrolls. It used to be a bare VBox, and the moment a tile was
	# added to it — the harvest door — the last card fell off the bottom of the
	# screen with no way to reach it.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_right = -60
	# Low on the screen: the art's subject is mid-frame, and cards parked over it
	# hid the whole square.
	scroll.anchor_top = 0.52
	scroll.offset_top = 0
	scroll.offset_bottom = -110
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 28)
	scroll.add_child(column)

	# ONE primary action, then a compact list — not five equal cards.
	#
	# The hub used to stack every system as a 190px card with an icon and two
	# lines of copy, which said they all mattered the same amount and answered
	# none of "what should I be doing". The lead card answers that; everything
	# else is a place you can go, and places you can go are a list.
	column.add_child(_build_lead_card())
	for tile: Dictionary in Story.list("hub.tiles"):
		column.add_child(_make_tile(tile))
	page.set_meta("column", column)
	_add_harvest_tile(column)
	_add_case_two_tile(column)

	var story := Button.new()
	story.text = tr("UI_STORY")
	story.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	story.flat = true
	story.alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	story.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
	story.add_theme_color_override("font_hover_color", GameConfig.CASE_ACCENT)
	story.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	story.pressed.connect(func() -> void:
		Haptics.light()
		replay_intro_requested.emit())
	column.add_child(story)
	return page


## The one thing the hub is for: where the player left off, and the button that
## resumes it. Everything under this is navigation.
func _build_lead_card() -> Control:
	var card := PanelContainer.new()
	card.name = "LeadCard"
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.05, 0.05, 0.045, 0.92)
	skin.set_corner_radius_all(24)
	skin.set_content_margin_all(GameConfig.UI_GAP_WIDE)
	skin.border_color = Color(GameConfig.CASE_ACCENT, 0.45)
	skin.set_border_width_all(2)
	skin.shadow_color = Color(0, 0, 0, 0.5)
	skin.shadow_size = 14
	card.add_theme_stylebox_override("panel", skin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
	card.add_child(rows)

	var eyebrow := Label.new()
	eyebrow.name = "LeadEyebrow"
	eyebrow.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	eyebrow.add_theme_color_override("font_color",
		Color(GameConfig.CASE_ACCENT, 0.9))
	rows.add_child(eyebrow)

	var place := Label.new()
	place.name = "LeadPlace"
	place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	place.add_theme_color_override("font_color", GameConfig.UI_INK)
	rows.add_child(place)

	var lead := Label.new()
	lead.name = "LeadLine"
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	lead.add_theme_color_override("font_color", GameConfig.CASE_MUTED)
	rows.add_child(lead)

	var go := Button.new()
	go.name = "LeadGo"
	go.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	go.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	style_primary(go)
	go.pressed.connect(func() -> void:
		Haptics.medium()
		open_map_at(ChapterProgress.current_variant_id()))
	rows.add_child(go)
	return card


## Fills the lead card from current progress. Derived on read like everything
## else on this screen, so a chapter finished in this session is reflected the
## moment the hub comes back.
func _refresh_lead_card() -> void:
	var card := _tiles_page.find_child("LeadCard", true, false) if _tiles_page \
		else null
	if card == null or not is_instance_valid(card):
		return
	var vid := ChapterProgress.current_variant_id()
	var case_list := ChapterProgress.active_case_chapters()
	var all_done := ChapterProgress.done_in(case_list) >= case_list.size() \
		and not case_list.is_empty()
	var eyebrow := card.find_child("LeadEyebrow", true, false) as Label
	var place := card.find_child("LeadPlace", true, false) as Label
	var lead := card.find_child("LeadLine", true, false) as Label
	var go := card.find_child("LeadGo", true, false) as Button
	if all_done:
		eyebrow.text = tr("HUB_LEAD_DONE_LABEL")
		place.text = Story.text("case_02.title"
			if ChapterProgress.active_case_is_two() else "case.title")
		lead.text = tr("CASE_LEAD_CLOSED")
		go.text = tr("CASE_ALL_SEARCHED")
		go.disabled = true
		return
	go.disabled = false
	eyebrow.text = tr("HUB_LEAD_LABEL")
	place.text = tr(str(ChapterProgress.entry(vid).get("name", "")))
	var subline := LevelVariant.of(vid).opening_subline
	lead.text = tr(subline) if subline != "" else tr("CASE_LEAD_EMPTY")
	go.text = tr("CASE_CONTINUE")


## The harvest's door on the hub itself. Gus's radio card says it once and
## fades; the map badge is two screens in. An open invitation needs somewhere
## it can always be found, so it sits with the other tiles in its own gold
## (G13.6). Removed again the moment the field has been brought in.
func _add_harvest_tile(column: VBoxContainer) -> void:
	# is_available, not is_offered: the door, not the invitation. The field used
	# to appear only on the cadence and vanish again once it had been worked,
	# so the game's one repeatable job was only takeable when the game felt
	# like offering it (G13).
	if not HarvestLog.is_available():
		return
	var tile := Button.new()
	tile.name = "HarvestTile"
	tile.custom_minimum_size = Vector2(0, 190)
	tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_theme_font_size_override("font_size", 46)
	tile.add_theme_color_override("font_color", GameConfig.UI_ON_BRASS)
	tile.text = "%s\n%s" % [tr("HARVEST_TAB"), tr("HARVEST_PLACE")]
	var skin := StyleBoxFlat.new()
	skin.bg_color = GameConfig.HARVEST_GOLD
	skin.set_corner_radius_all(20)
	skin.set_content_margin_all(22)
	skin.border_color = Color(0.42, 0.30, 0.08)
	skin.set_border_width_all(3)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		tile.add_theme_stylebox_override(state, skin)
	tile.pressed.connect(func() -> void:
		Haptics.light()
		open_map_at(GameConfig.HARVEST_VARIANT))
	column.add_child(tile)
	column.move_child(tile, 0)


## Case 02, at the top of the hub, from the moment Case 01 closes.
##
## THE BUG THIS FIXES. Case 01's ending card promised "CASE 02 UNLOCKED" and
## then Case 02 appeared precisely nowhere, because it also needs the town
## rebuilt and nothing anywhere said so. The player finished a case and was left
## looking for a door that had not been drawn.
##
## So the door is drawn either way. Locked, it is not a dead tile: it carries
## the live count of what it is waiting for, which is the whole reason the
## restore board earns anything — Ellie's line said he would come back when the
## town was ready, and this is where the player watches that happen (G13).
func _add_case_two_tile(column: VBoxContainer) -> void:
	# The chapters, not the flag. A save that says the ending was seen but has
	# no finished chapters behind it — a reset, a dev run — used to show Case 02
	# over a board reading 0/8.
	if not ChapterProgress.case_one_finished():
		return
	var ready := ChapterProgress.case_two_open()
	# Once the case is OPEN this tile has nothing left to say. The top bar
	# names the case, the lead card names its next chapter and carries the
	# button that goes there — a third gold panel repeating the case title
	# above the primary action just outranked it (UI/UX redesign).
	#
	# Locked, it is the opposite: the live "waiting for the town" counter has
	# no other home, and watching that number move is the whole reason the
	# restore board earns anything.
	if ready:
		return
	var progress := RestoreBoard.town_ready_progress()
	# Not a locked sign — a counter. The player can see the number move.
	var tile := Button.new()
	tile.name = "CaseTwoTile"
	tile.custom_minimum_size = Vector2(0, 170)
	tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	tile.text = "%s · %s\n%s" % [Story.text("case_02.id"),
		Story.text("case_02.title"),
		tr("CASE_02_WAITING").format({"done": progress.x, "total": progress.y})]
	tile.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	_style_nav_row(tile, true)
	# Tapping it goes where the counter is moved: the restore board.
	tile.pressed.connect(func() -> void:
		Haptics.light()
		_on_tile("restore", false))
	column.add_child(tile)
	column.move_child(tile, 0)


## Buttons over an illustration need an explicit ground: the default theme's
## button is nearly transparent and reads as a smudge rather than a card.
func _style_card(button: Button, dim := false) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.07, 0.07, 0.065, 0.90 if not dim else 0.80)
	base.set_corner_radius_all(24)
	base.set_content_margin_all(26)
	base.border_color = Color(GameConfig.CASE_ACCENT, 0.42 if not dim else 0.18)
	base.set_border_width_all(3)
	base.shadow_color = Color(0, 0, 0, 0.45)
	base.shadow_size = 10
	button.add_theme_stylebox_override("normal", base)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.13, 0.12, 0.10, 0.95)
	pressed.border_color = Color(GameConfig.CASE_ACCENT, 0.75)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", base)


func _make_tile(tile: Dictionary) -> Button:
	var locked := bool(tile.get("locked", false))
	var button := Button.new()
	# A row, not a 190px card. These are places you can go; the lead card above
	# them is the thing you DO, and it can only read as primary if the rest
	# stop competing with it.
	button.custom_minimum_size = Vector2(0, 116)
	button.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The tile dictionary carries the keys directly, so translate them here.
	var hint := tr(str(tile.get("hint", ""))) if not locked \
		else Story.text("hub.locked_note")
	var label := tr(str(tile.get("label", "")))
	var icon_id := str(tile.get("id", ""))
	# G12.7: once the station is built, the case screens live in it and the card
	# says so. Grouping, not a new screen — the chapter list and the corkboard
	# are already two tabs behind this one door.
	if str(tile.get("id", "")) == "case_board" and RestoreBoard.station_built():
		label = tr("HUB_STATION")
		hint = tr("HUB_STATION_HINT")
		icon_id = "station"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Drawn icon, not an emoji glyph: iOS renders those as a blank box that
	# still takes its width (G12.10).
	var art := UiIcons.for_tile(icon_id)
	if art != null:
		button.icon = art
		button.expand_icon = false
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("h_separation", 20)
	# The hint line is gone from the row itself. Five rows of "label + sentence"
	# is what made the hub read as a dashboard; the sentence survives as the
	# tooltip, where it explains without shouting.
	button.text = label
	button.tooltip_text = hint
	if locked:
		button.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
	_style_nav_row(button, locked)
	var id := str(tile.get("id", ""))
	button.pressed.connect(_on_tile.bind(id, locked, button))
	return button


## The secondary rows. Flatter and darker than _style_card: no shadow, a
## hairline border, and a ground that sits back rather than floating.
func _style_nav_row(button: Button, dim := false) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.06, 0.06, 0.055, 0.86 if not dim else 0.62)
	base.set_corner_radius_all(16)
	base.set_content_margin_all(GameConfig.UI_GAP_WIDE)
	base.border_color = Color(GameConfig.CASE_ACCENT, 0.16 if not dim else 0.08)
	base.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", base)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.11, 0.09, 0.94)
	pressed.border_color = Color(GameConfig.CASE_ACCENT, 0.5)
	for state in ["pressed", "hover"]:
		button.add_theme_stylebox_override(state, pressed)
	button.add_theme_stylebox_override("focus", pressed)


## `button` is only used to shake a locked tile, so callers that are not a tile
## press pass nothing. It used to be required, and the diorama shortcut handed
## it a throwaway `Button.new()` that was never added to the tree and never
## freed — one leaked CanvasItem per tap (G13.4).
func _on_tile(id: String, locked: bool, button: Button = null) -> void:
	if locked:
		Haptics.light()
		if button != null:
			_shake(button)
		return
	Haptics.light()
	match id:
		"case_board":
			_show_page(_ensure_case_summary_page())
			_refresh_case_summary()
		"map":
			open_map()
		"town":
			_rebuild_town()
			_show_page(_town_page)
		"workshop":
			_workshop_page.refresh()
			_show_page(_workshop_page)
		"restore":
			_refresh_restore()
			_show_page(_restore_page)
		"echoes":
			open_journal()
		_:
			_shake(button)


func _shake(control: Control) -> void:
	var home := control.position
	var tw := create_tween()
	for offset: float in [16.0, -12.0, 8.0, -4.0, 0.0]:
		tw.tween_property(control, "position", home + Vector2(offset, 0.0), 0.055)
	tw.tween_callback(func() -> void: control.position = home)


# ---------------------------------------------------------------- restore (G12.6)

## What the money is FOR once the workshop has what it needs. Deliberately a
## separate screen from the workshop: mixing "the tool I need" with "the thing I
## give back" would let one crowd out the other.
func _build_restore() -> Control:
	var page := _new_page()
	page.add_child(_list_backdrop(280.0))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 300
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	_restore_list = VBoxContainer.new()
	_restore_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restore_list.add_theme_constant_override("separation", 20)
	scroll.add_child(_restore_list)
	page.add_child(_back_button())
	return page


func _refresh_restore() -> void:
	for child in _restore_list.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = Story.text("restore.title")
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_restore_list.add_child(heading)
	_restore_note = Label.new()
	_restore_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_restore_note.add_theme_font_size_override("font_size", 30)
	_restore_note.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	_restore_list.add_child(_restore_note)
	var tier2_shown := false
	for project: Dictionary in RestoreBoard.projects():
		if int(project.get("tier", 1)) >= 2 and not tier2_shown:
			tier2_shown = true
			var header := Label.new()
			header.text = tr("RESTORE_TIER2")
			header.add_theme_font_size_override("font_size", 34)
			header.add_theme_color_override("font_color",
				Color(0.86, 0.84, 0.78))
			_restore_list.add_child(header)
		_restore_list.add_child(_make_project_row(project))


func _make_project_row(project: Dictionary) -> Button:
	var id := str(project.get("id", ""))
	var built := RestoreBoard.is_built(id)
	var locked := RestoreBoard.is_locked(id)
	var cost := int(project.get("cost", 0))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 190)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 38)
	var tail := tr("RESTORE_DONE") if built \
		else tr("RESTORE_BUY").format({"cost": cost})
	if locked and not built:
		# Locked doors stay priced and visible: that is what makes them a goal.
		tail = "%s   ·   %s" % [RestoreBoard.lock_reason(id),
			tr("RESTORE_BUY").format({"cost": cost})]
	# Projects that pay out in the CASE rather than in money say so on the card.
	if bool(project.get("serves_case", false)):
		var badge := Label.new()
		badge.text = tr("RESTORE_CASE_BADGE")
		badge.add_theme_font_size_override("font_size", 22)
		badge.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -260.0
		badge.offset_right = -22.0
		badge.offset_top = 16.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)

	var bonus := str(project.get("bonus_text", ""))
	if bonus == "":
		bonus = str(project.get("effect_text", ""))
	var extra := "\n%s" % tr(bonus) if bonus != "" else ""
	button.text = "%s\n%s%s\n%s" % [tr(str(project.get("name", ""))),
		tr(str(project.get("desc", ""))), extra, tail]
	if built:
		button.add_theme_color_override("font_color", GameConfig.UI_GREEN)
		_style_card(button, true)
	elif locked:
		button.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
		_style_card(button, true)
	else:
		_style_card(button)
	button.pressed.connect(_on_project.bind(id, built or locked, button))
	# Hold a card and the town shows you where that project would go, BEFORE
	# any money changes hands (G13.5).
	button.button_down.connect(_start_peek.bind(id))
	button.button_up.connect(_stop_peek)
	return button


func _on_project(project_id: String, built: bool, source: Button) -> void:
	Haptics.light()
	if built:
		return
	if RestoreBoard.is_locked(project_id):
		_restore_note.text = RestoreBoard.lock_reason(project_id)
		_shake(source)
		return
	var project := RestoreBoard.of(project_id)
	if GameState.scrap_total() < int(project.get("cost", 0)):
		_restore_note.text = Story.text("restore.locked_note")
		_shake(source)
		return
	if RestoreBoard.buy(project_id):
		AudioDirector.play_scrap()
		Haptics.success()
		_restore_note.text = tr(str(project.get("crumb", "")))
		if RestoreBoard.tier2_open() and not _tier2_announced:
			_tier2_announced = true
			Analytics.track(AnalyticsEvents.RESTORE_TIER2_UNLOCKED, {})
		_refresh_restore()
		_refresh_progress()
		_refresh_tiles()
		if _diorama != null and _diorama.has_building(project_id):
			await _play_restore_scene(project_id)


## The live model of the town, rendered into the page behind the cards.
func _build_diorama_background() -> void:
	# Under everything: the 3D scene does not draw on the first frame, and a
	# hub that flashes black on entry looks broken.
	_build_ground_gradient()

	var frame := SubViewportContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.stretch = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_diorama_frame = frame

	_diorama_view = SubViewport.new()
	_diorama_view.size = Vector2i(get_viewport_rect().size)
	_diorama_view.own_world_3d = true
	_diorama_view.world_3d = World3D.new()
	_diorama_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	# The hub is menus over a still model: half the yard's frame rate is plenty,
	# and it is the whole reason this can sit behind every page.
	_diorama_view.physics_object_picking = true
	frame.add_child(_diorama_view)

	set_process(true)
	_diorama = load("res://scenes/TownDiorama.tscn").instantiate()
	_diorama.building_pressed.connect(_on_diorama_building)
	_diorama_view.add_child(_diorama)

	# The yard's screen overlay: warm gradient plus a vignette. Same shader the
	# HUD runs, so the hub and the game are graded alike (G13.1).
	var grade := ColorRect.new()
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade_mat := ShaderMaterial.new()
	grade_mat.shader = load("res://shaders/screen_overlay.gdshader")
	grade_mat.set_shader_parameter("vignette_strength", 0.22)
	grade_mat.set_shader_parameter("warm_strength", 0.13)
	grade_mat.set_shader_parameter("cool_strength", 0.07)
	grade.material = grade_mat
	add_child(grade)

	# The same darkening the collage gets, so cards stay readable over it. This
	# is a gradient, so it is a TextureRect — an earlier ColorRect was left here
	# unparented when it changed, and leaked on every hub (G13.4).
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.06, 0.05, 0.55))
	grad.set_color(1, Color(0.05, 0.06, 0.05, 0.05))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 1.0)
	grad_tex.fill_to = Vector2(0.0, 0.35)
	var wash := TextureRect.new()
	wash.texture = grad_tex
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)


## The hub is menus over a still model, so the 3D half runs at half rate: the
## SubViewport is told to draw one frame, then left alone until the next tick.
## UPDATE_ALWAYS would redraw the whole town every frame of a 60 fps menu.
func _process(_delta: float) -> void:
	if _diorama_view == null:
		return
	_diorama_tick += 1
	if _diorama_tick % 2 == 0:
		_diorama_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## Stops the town rendering while a chapter is being played, and starts it again
## on the way back. The hub node stays alive (root only hides it), so without
## this the diorama would keep drawing behind the yard (G13 §4).
func set_diorama_active(active: bool) -> void:
	set_process(active and _diorama_view != null)
	# The case map is the hub's other animated surface — a hand-drawn Control
	# that repaints the whole town every frame for the breathing pin and the
	# cloud shadow. root only HIDES the hub layer, so without this it kept
	# painting for the entire chapter, behind a black screen (G16).
	if _map != null and is_instance_valid(_map):
		_map.set_process(active)
	if active and GameConfig.PERF_LOG:
		_log_perf()
	if active and _diorama != null and is_instance_valid(_diorama):
		_settle_reclaim()
	if _diorama_view == null:
		return
	_diorama_view.render_target_update_mode = (SubViewport.UPDATE_ONCE if active
		else SubViewport.UPDATE_DISABLED)
	# UPDATE_DISABLED stops the DRAWING but keeps the framebuffer: a full
	# 1170x2532 colour+depth target, ~70 MB, held for the whole chapter next to
	# the yard's own. Shrinking the container frees it, and the town is rebuilt
	# from UPDATE_ONCE above on the way back — which the hub's fade-in covers.
	if _diorama_frame != null and is_instance_valid(_diorama_frame):
		_diorama_frame.stretch_shrink = 1 if active else DIORAMA_PARKED_SHRINK
	if _diorama != null:
		_diorama.process_mode = (Node.PROCESS_MODE_INHERIT if active
			else Node.PROCESS_MODE_DISABLED)
		if active:
			_diorama.refresh_state()


## Plays the weed band stepping back, if finishing a chapter earned one. The
## band is what a cleared lawn LOOKS like from the hub (G13.4).
func _settle_reclaim() -> void:
	if not _diorama.reclaim_owed():
		return
	for _i in 8:
		await get_tree().process_frame
	await _diorama.play_reclaim_step()
	_refresh_progress()


## Draw calls, triangles and frame rate on hub entry, so the diorama's cost is
## visible on a real device instead of inferred (GameConfig.PERF_LOG, G13.6).
## Waits a few frames: the numbers on the first frame after a scene change are
## the change, not the steady state.
func _log_perf() -> void:
	for _i in 6:
		await get_tree().process_frame
	var draws := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tris := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("[hub] cizim=%d ucgen=%d fps=%d bina=%d/%d" % [draws, tris,
		Engine.get_frames_per_second(), RestoreBoard.built_count(),
		RestoreBoard.projects().size()])


## A restored building is a shortcut to the screen it stands for (G13 §4).
func _on_diorama_building(project_id: String) -> void:
	if not RestoreBoard.is_built(project_id):
		return
	Haptics.light()
	match project_id:
		"station":
			open_evidence_board()
		"homes":
			_on_tile("town", false)
		"watchtower":
			# What the Marshal sees from up there — the first thread of the
			# next case (G13.4).
			_restore_note.text = tr("HUB_TOWER_LINE")


## Completed projects add a layer to the hub art; without the art file they add
## a small badge instead, so progress is always visible.
## A held restore card asks the diorama to glance at that plot. The hold has to
## outlast a tap, or every purchase would fire a glance on its way through.
func _start_peek(project_id: String) -> void:
	if _diorama == null or not _diorama.has_building(project_id):
		return
	_peek_wanted = project_id
	var timer := get_tree().create_timer(GameConfig.DIORAMA_PEEK_HOLD)
	await timer.timeout
	if _peek_wanted == project_id and _diorama != null \
			and is_instance_valid(_diorama):
		_diorama.peek_at(project_id)


func _stop_peek() -> void:
	_peek_wanted = ""
	if _diorama != null and is_instance_valid(_diorama):
		_diorama.end_peek()


## Hands the screen to the diorama while it rebuilds, then gives it back. The
## cards fade out so the model is unobstructed, and a tap anywhere skips.
func _play_restore_scene(project_id: String) -> void:
	var skipper := Button.new()
	skipper.name = "RestoreSkip"
	skipper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skipper.flat = true
	skipper.pressed.connect(_diorama.skip)
	add_child(skipper)

	var pages: Array = []
	for child in get_children():
		var page := child as Control
		if page == null or page == skipper or not page.visible:
			continue
		if page is SubViewportContainer:
			continue
		# The Restore_* badges are rebuilt on every purchase, so they will be
		# gone before this animation ends. Fading them is pointless and holding
		# a reference to them is what used to break the hub.
		if page.name.begins_with("Restore_"):
			continue
		pages.append(page)
		page.modulate.a = 0.0

	await _diorama.play_restore(project_id)

	# The skip button comes off FIRST and unconditionally. It covers the whole
	# screen and is invisible, so if anything below throws and leaves it there,
	# every touch after that lands on it and the hub looks frozen — which is
	# exactly what happened when a faded page was freed mid-animation (G13.2).
	skipper.queue_free()
	for page_any: Variant in pages:
		# is_instance_valid BEFORE the cast: casting a freed object throws in
		# GDScript, so a guard written after the cast never runs.
		if not is_instance_valid(page_any):
			continue
		(page_any as Control).modulate.a = 1.0

# ---------------------------------------------------------------- echoes (G12.6)

func _build_echoes() -> Control:
	var page := _new_page()
	page.add_child(_list_backdrop(280.0))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 300
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_echo_list = VBoxContainer.new()
	_echo_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_echo_list.add_theme_constant_override("separation", 18)
	scroll.add_child(_echo_list)
	page.add_child(_back_button())
	return page


# ---------------------------------------------------------------- objectives

## The mission compass (G14.2). One screen that answers "what does this town
## want from me", with every condition ticked or not so the player can see what
## is missing rather than guess at it.
func _build_objectives() -> Control:
	var page := _new_page()
	page.add_child(_list_backdrop(280.0))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 300
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_objective_list = VBoxContainer.new()
	_objective_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objective_list.add_theme_constant_override("separation", 22)
	scroll.add_child(_objective_list)
	page.add_child(_back_button())
	return page


## Open objectives first, finished ones dimmed underneath. Rebuilt on every
## visit because every line of it is derived — there is no cached state here
## that could go stale.
func _refresh_objectives() -> void:
	if _objective_list == null:
		return
	for child in _objective_list.get_children():
		child.queue_free()

	var heading := Label.new()
	heading.text = tr("OBJ_TITLE")
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_objective_list.add_child(heading)
	var sub := Label.new()
	sub.text = tr("OBJ_HINT")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	_objective_list.add_child(sub)

	var open: Array = []
	var closed: Array = []
	for any: Variant in Objectives.all():
		var spec: Dictionary = any
		# "case" objectives live in the Case screen now (UI/UX redesign): its
		# lead/areas/discoveries ARE that content, reframed. This list keeps the
		# ones that are not about a case — the town and the harvest — which have
		# nowhere else to be seen yet. Objectives.collect() still pays every
		# type's reward regardless of what is shown here.
		if str(spec.get("type", "")) == "case":
			continue
		if Objectives.is_paid(str(spec.get("id", ""))):
			closed.append(spec)
		else:
			open.append(spec)

	if open.is_empty():
		var none := Label.new()
		none.text = tr("OBJ_EMPTY")
		none.add_theme_font_size_override("font_size", 32)
		none.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
		_objective_list.add_child(none)
	for spec_any: Variant in open:
		_objective_list.add_child(_objective_card(spec_any as Dictionary, false))
	if not closed.is_empty():
		var done_header := Label.new()
		done_header.text = tr("OBJ_DONE_HEADER")
		done_header.add_theme_font_size_override("font_size", 32)
		done_header.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
		_objective_list.add_child(done_header)
		for spec_any2: Variant in closed:
			_objective_list.add_child(_objective_card(spec_any2 as Dictionary, true))


## One objective: title, one line of why, then its conditions with a tick or an
## empty circle each. A counted condition also shows how far along it is, so
## "three cases" is never a mystery.
func _objective_card(spec: Dictionary, dim: bool) -> Control:
	var id := str(spec.get("id", ""))
	var state := Objectives.state(id)
	var card := PanelContainer.new()
	card.name = "Objective_" + id
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.07, 0.08, 0.07, 0.55 if dim else 0.88)
	skin.set_corner_radius_all(18)
	skin.set_content_margin_all(22)
	skin.set_border_width_all(2)
	# A ready objective is the one thing on this screen that wants to be acted
	# on right now, so it gets the harvest's own gold.
	skin.border_color = GameConfig.HARVEST_GOLD if state["ready"] \
		else Color(0.42, 0.44, 0.40, 0.55)
	card.add_theme_stylebox_override("panel", skin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	card.add_child(rows)

	var title := Label.new()
	title.text = tr(str(spec.get("title", "")))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color",
		Color(0.60, 0.62, 0.58) if dim else GameConfig.HARVEST_GOLD \
		if state["ready"] else Color(0.95, 0.94, 0.90))
	rows.add_child(title)

	var desc := Label.new()
	desc.text = tr(str(spec.get("desc", "")))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 28)
	desc.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	rows.add_child(desc)

	for step_any: Variant in state["steps"]:
		var step: Dictionary = step_any
		var line := Label.new()
		var mark := "\u2713" if step["done"] else "\u25cb"
		var tail: String = str(step["progress"])
		line.text = "%s  %s%s" % [mark, step["text"],
			"   %s" % tail if tail != "" else ""]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 28)
		line.add_theme_color_override("font_color",
			GameConfig.UI_GREEN if step["done"] else Color(0.78, 0.78, 0.74))
		rows.add_child(line)

	var reward := int(spec.get("reward_scrap", 0))
	if reward > 0 and not dim:
		var pay := Label.new()
		pay.text = "%s: %d" % [tr("OBJ_REWARD"), reward]
		pay.add_theme_font_size_override("font_size", 26)
		pay.add_theme_color_override("font_color", GameConfig.UI_GREEN)
		rows.add_child(pay)

	# The harvest objective is a third door to the same panel the gold tile and
	# Gus's radio card open (G13.6): three doors, one destination.
	if str(spec.get("opens", "")) == "harvest" and state["ready"]:
		var go := Button.new()
		go.text = tr("HARVEST_START")
		go.custom_minimum_size = Vector2(0, 92)
		go.add_theme_font_size_override("font_size", 32)
		HubScreen.style_primary(go)
		go.pressed.connect(func() -> void:
			Haptics.light()
			open_map_at(GameConfig.HARVEST_VARIANT))
		rows.add_child(go)
	return card


## Found echoes are readable; the rest are blank slots, so the collection shows
## its own size without spoiling what is in it.
func _refresh_echoes() -> void:
	for child in _echo_list.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = "%s   %d/%d" % [Story.text("echoes.title"),
		EchoLog.found_count(), EchoLog.total()]
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_echo_list.add_child(heading)
	var sub := Label.new()
	sub.text = Story.text("echoes.header")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	_echo_list.add_child(sub)

	if EchoLog.found_count() == 0:
		var empty := Label.new()
		empty.text = Story.text("echoes.empty")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 34)
		empty.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
		_echo_list.add_child(empty)

	for chapter: Dictionary in ChapterProgress.chapters():
		var vid := str(chapter.get("variant_id", ""))
		var info := LevelVariant.of(vid).echo_info()
		if info.is_empty():
			continue
		var found := EchoLog.is_found(vid)
		var row := Label.new()
		row.custom_minimum_size = Vector2(0, 110)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 34)
		if found:
			# GlyphGuard, not the raw icon: an emoji here pulled in the OS
			# colour-emoji font, 184 MB, for a blank box on iOS (G16).
			row.text = GlyphGuard.safe("%s  %s\n%s" % [info["emoji"],
				info["name"], info["line"]])
			row.add_theme_color_override("font_color", GameConfig.UI_INK)
		else:
			row.text = "·  ———"
			row.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
		_echo_list.add_child(row)


# ---------------------------------------------------------------- workshop

func _build_workshop() -> Control:
	var page := WorkshopPage.new()
	page.visible = false
	page.purchased.connect(_refresh_progress)
	page.add_child(_back_button())
	return page


# ---------------------------------------------------------------- case board

func _build_board() -> Control:
	var page := _new_page()
	# A calm ground behind the list: eight card rows straight over the
	# illustration left the art showing through every gap and read as noise.
	page.add_child(_list_backdrop())

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 376
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 22)
	column.name = "Chapters"
	scroll.add_child(column)

	var heading := Label.new()
	heading.text = Story.text("case_board.title")
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	column.add_child(heading)

	# G10: the detective corkboard lives behind a tab pair on the same page.
	# The corkboard is taller than the screen, so it scrolls (G12.10).
	_board_scroll = ScrollContainer.new()
	_board_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_scroll.offset_top = 366
	_board_scroll.offset_bottom = -190
	_board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_board_scroll.visible = false
	page.add_child(_board_scroll)
	_board_view = EvidenceBoard.new()
	_board_scroll.add_child(_board_view)

	var tabs := HBoxContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_left = 50
	tabs.offset_right = -50
	tabs.offset_top = 272
	tabs.offset_bottom = 356
	tabs.add_theme_constant_override("separation", 18)
	page.add_child(tabs)
	_board_tab_places = Button.new()
	# Was BOARD_TAB_CHAPTERS, a list of eight rows. It is a map now (G13.5).
	_board_tab_places.text = tr("MAP_TAB")
	_board_tab_evidence = Button.new()
	_board_tab_evidence.text = tr("BOARD_TAB_EVIDENCE")
	for tab: Button in [_board_tab_places, _board_tab_evidence]:
		tab.add_theme_font_size_override("font_size", 34)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 84)
		tabs.add_child(tab)
	_board_tab_places.pressed.connect(func() -> void: _show_board_tab(false))
	_board_tab_evidence.pressed.connect(func() -> void: _show_board_tab(true))
	# The two-layer map: the case screen's default view.
	_map = TownMap.new()
	_map.name = "CaseMap"
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.offset_top = 366
	_map.offset_bottom = -170
	_map.place_chosen.connect(_on_map_place)
	_map.shortcut_chosen.connect(_on_map_shortcut)
	page.add_child(_map)

	# The old chapter list is kept in the tree but never shown: it is the
	# fallback if the map has to be pulled, and deleting it would take the
	# chapter-row styling with it.
	scroll.visible = false
	page.set_meta("scroll", scroll)

	page.add_child(_back_button())
	page.set_meta("column", column)
	return page


## A pin's SEARCH button. Goes through the same signal the chapter rows used, so
## the briefing and the chapter-start path are unchanged (G13.5).
func _on_map_place(variant_id: String) -> void:
	chapter_chosen.emit(variant_id)


## A restored building on the map is a shortcut to its screen.
func _on_map_shortcut(page_id: String) -> void:
	if page_id == "case_board":
		_show_board_tab(true)
		return
	_on_tile(page_id, false)


## Opens the case screen on the map, focused on one place. Used by the
## chapter-end "next" button so a finished search leads back to the journey.
func open_map_at(variant_id: String) -> void:
	_show_page(_ensure_board_page())
	_show_board_tab(false)
	if _map != null and is_instance_valid(_map):
		_map.focus_place(variant_id)


## Swaps between the chapter list and the corkboard, restyling the tab pair so
## the active one reads pressed.
func _show_board_tab(evidence: bool) -> void:
	# Same rule as _refresh_board: refresh() calls this on every hub entry.
	if _board_page == null or not is_instance_valid(_board_page):
		return
	Haptics.light()
	_board_scroll.visible = evidence
	if _map != null and is_instance_valid(_map):
		_map.visible = not evidence
		if not evidence:
			_map.refresh()
	if evidence:
		_board_view.refresh()
	if _board_tab_evidence != null:
		_style_tab(_board_tab_places, not evidence)
		_style_tab(_board_tab_evidence, evidence)


## Opens the Journal. Replaces the old flat "echoes" page, whose name told the
## player nothing about what was behind it and which held one undifferentiated
## list; the Journal names its three kinds of thing (UI/UX redesign).
##
## An overlay rather than a hub page, so the main menu can open the same screen
## without a hub existing at all.
func open_journal() -> void:
	if _journal != null and is_instance_valid(_journal):
		return
	_journal = JournalScreen.new()
	add_child(_journal)
	_journal.closed.connect(func() -> void:
		_journal.queue_free()
		_journal = null)


## Kept for the main menu, which asks for the Journal by an older name.
func open_echoes() -> void:
	open_journal()


## Opens the case board page directly on the corkboard (the case-notes button).
## The map, straight from the hub menu.
##
## It already existed as the first tab of the case board, which put the one
## screen that answers "where do I mow next" three taps deep behind a door
## named after a building. Same page, same map, reached directly.
func open_map() -> void:
	_show_page(_ensure_board_page())
	_refresh_board()
	_show_board_tab(false)


func open_evidence_board() -> void:
	_show_page(_ensure_board_page())
	_refresh_board()
	_show_board_tab(true)


## Rebuilt on every entry, so a chapter finished in this session shows as done
## without a hub reload.
func _refresh_board() -> void:
	# NOT _ensure_board_page(): refresh() runs on every return to the hub, and
	# building the board here would defeat the whole point of building it late.
	# Nothing needs refreshing until it exists — it is built from current state.
	if _board_page == null or not is_instance_valid(_board_page):
		return
	var column: VBoxContainer = _board_page.get_meta("column")
	for child in column.get_children():
		if child is Button:
			child.queue_free()
	var current := ChapterProgress.current_variant_id()
	for chapter: Dictionary in ChapterProgress.chapters():
		column.add_child(_make_chapter_row(chapter, current))


func _make_chapter_row(chapter: Dictionary, current: String) -> Button:
	var id := str(chapter.get("variant_id", ""))
	var playable := bool(chapter.get("playable", false))
	var done := ChapterProgress.is_done(id)
	# A padlock emoji here was a blank box on iOS; the tick and the play mark
	# are plain glyphs the default font carries, so only the lock became art.
	var mark := ""
	var locked_art := true
	var state := Story.text("case_board.locked")
	if done:
		mark = "✓"
		locked_art = false
		state = Story.text("case_board.done")
	elif playable and id == current:
		mark = "▶"
		locked_art = false
		state = Story.text("case_board.active")
	elif playable:
		locked_art = false

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 162)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 40)
	var evidence := Story.text("case_board.evidence").format({
		"found": ChapterProgress.evidence_found(id),
		"total": ChapterProgress.evidence_total(id)})
	var head: String = "%s  " % mark if mark != "" else ""
	button.text = "%s%s\n%s · %s" % [head, tr(str(chapter.get("name", ""))),
		state, evidence]
	if locked_art:
		button.icon = UiIcons.lock()
		button.expand_icon = false
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("h_separation", 18)
	if not playable:
		button.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
	elif done:
		button.add_theme_color_override("font_color", GameConfig.UI_GREEN)
	_style_card(button, not playable)
	button.pressed.connect(_on_chapter.bind(id, playable, button))
	return button


func _on_chapter(variant_id: String, playable: bool, button: Button) -> void:
	Haptics.light()
	if not playable:
		_shake(button)
		return
	chapter_chosen.emit(variant_id)


# ---------------------------------------------------------------- town

func _build_town() -> Control:
	var page := _new_page()
	page.add_child(_list_backdrop(280.0))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 300
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 20)
	scroll.add_child(column)

	var heading := Label.new()
	heading.text = Story.text("town.title")
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	column.add_child(heading)

	page.set_meta("column", column)
	page.add_child(_back_button())
	_town_page = page
	_rebuild_town()
	return page


## Rebuilt per visit: who is in town changes as the case moves.
func _rebuild_town() -> void:
	if _town_page == null:
		return
	var column: VBoxContainer = _town_page.get_meta("column")
	for child in column.get_children():
		if child is Button or child is PanelContainer:
			child.queue_free()
	# Ellie heads the page until she is found. She is not someone you can talk
	# to, so she is a poster rather than a person row — putting a missing child
	# in the list of neighbours to chat with read wrong (G12.10).
	if ChapterProgress.done_count() < GameConfig.ELLIE_FOUND_AFTER:
		column.add_child(_make_missing_card())
	for person: Dictionary in Story.list("town.people"):
		if ChapterProgress.done_count() < int(person.get("requires_done", 0)):
			continue
		column.add_child(_make_person_row(person))


## The MISSING poster for the town page: portrait, name, and how long she has
## been gone. Deliberately not a Button — there is nothing to press.
func _make_missing_card() -> PanelContainer:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.POSTER_BG
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	frame.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	frame.add_child(row)

	var face := TextureLibrary.find("portraits/face_ellie")
	if face != null:
		var picture := TextureRect.new()
		picture.texture = face
		picture.custom_minimum_size = Vector2(190, 190)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		row.add_child(picture)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	for line: Array in [[tr("POSTER_MISSING"), 46, GameConfig.CASE_ACCENT],
			[tr("POSTER_NAME"), 52, Color.WHITE],
			[tr("POSTER_SINCE"), 34, GameConfig.CASE_MUTED]]:
		var label := Label.new()
		label.text = str(line[0])
		label.add_theme_font_size_override("font_size", int(line[1]))
		label.add_theme_color_override("font_color", line[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(label)
	return frame


func _make_person_row(person: Dictionary) -> Button:
	var id := str(person.get("id", ""))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 168)
	# Portrait left, name and role left-aligned beside it: a centred label next
	# to a left-hand portrait reads as two unrelated elements.
	var face := TextureLibrary.find("portraits/face_" + id)
	if face != null:
		button.icon = face
		button.expand_icon = true
		button.add_theme_constant_override("h_separation", 30)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# A badge per finished project for this person: whose life changed, at a
	# glance, without a second screen (G12.7).
	# One drawn house per finished project, laid in a row beside the name; this
	# was a string of emoji, which is a row of blank boxes on iOS (G12.10).
	var projects: Array = RestoreBoard.projects_for(id)
	button.text = "%s\n%s" % [tr(str(person.get("name", ""))),
		tr(str(person.get("role", "")))]
	if not projects.is_empty():
		var marks := HBoxContainer.new()
		marks.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		marks.offset_left = -40.0 - 44.0 * projects.size()
		marks.offset_right = -20.0
		marks.offset_top = 22.0
		marks.add_theme_constant_override("separation", 6)
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for _project in projects:
			var mark_icon := TextureRect.new()
			mark_icon.texture = UiIcons.house()
			mark_icon.custom_minimum_size = Vector2(38, 38)
			mark_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			marks.add_child(mark_icon)
		button.add_child(marks)
	button.add_theme_font_size_override("font_size", 40)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_card(button)
	button.pressed.connect(_on_person.bind(id))
	return button


func _on_person(person_id: String) -> void:
	if _dialogue != null and is_instance_valid(_dialogue):
		return
	Haptics.light()
	var lines := Dialogue.town_lines(person_id, ChapterProgress.done_count())
	# A finished project earns a permanent thank-you, appended after whatever
	# this character normally says (G12.6).
	var project := RestoreBoard.thanks_for(person_id)
	if not project.is_empty():
		lines = lines.duplicate()
		lines.append({"speaker": person_id,
			"text": str(project.get("thanks", ""))})
		lines.append({"speaker": person_id,
			"text": str(project.get("crumb", ""))})
	if lines.is_empty():
		return
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(func() -> void: _dialogue = null)
	_dialogue.play(lines)


# ---------------------------------------------------------------- shared

## Dark rounded ground covering the list area, so a long list of rows reads as
## one panel instead of stripes over the artwork.
func _list_backdrop(top := 346.0) -> Panel:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = top
	panel.offset_bottom = -170
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.045, 0.82)
	style.set_corner_radius_all(30)
	style.border_color = Color(GameConfig.CASE_ACCENT, 0.22)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _back_button() -> Button:
	var back := Button.new()
	back.text = tr("UI_BACK")
	back.add_theme_font_size_override("font_size", 40)
	_style_card(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	back.offset_left = 60
	back.offset_right = -60
	back.offset_top = -160
	back.offset_bottom = -60
	back.pressed.connect(func() -> void:
		Haptics.light()
		_show_page(_tiles_page))
	return back


## Called by the flow controller when the hub becomes visible again, so progress
## made in a chapter shows up immediately.
func refresh() -> void:
	_refresh_progress()
	_refresh_lead_card()
	_refresh_board()
	_refresh_objectives()
	_refresh_objectives_badge()
	_show_board_tab(false)
	_show_page(_tiles_page)
	_harvest_call()
	# Anything finished while the player was out in a yard is paid for here, on
	# the way back in — the hub is the only screen that can afford a toast.
	_announce_objectives(Objectives.collect())


## One line sliding down from the top per completed objective, the reward in the
## wallet behind it. Deliberately the same shape as Gus's radio card: this is
## the town telling you something, not a system congratulating you.
func _announce_objectives(earned: Array) -> void:
	if earned.is_empty():
		return
	_refresh_objectives()
	_refresh_objectives_badge()
	_refresh_progress()
	AudioDirector.play_discovery()
	Haptics.medium()
	var index := 0
	for any: Variant in earned:
		var spec: Dictionary = any
		_objective_toast(spec, float(index) * 0.35)
		index += 1


func _objective_toast(spec: Dictionary, delay: float) -> void:
	var card := PanelContainer.new()
	card.name = "ObjectiveToast"
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 40
	card.offset_right = -40
	card.offset_top = 250
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.09, 0.14, 0.09, 0.96)
	skin.set_corner_radius_all(20)
	skin.set_content_margin_all(22)
	skin.border_color = GameConfig.HARVEST_GOLD
	skin.set_border_width_all(3)
	card.add_theme_stylebox_override("panel", skin)
	add_child(card)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rows)
	for line: Array in [
			[tr("OBJ_COMPLETED_TOAST"), 26, GameConfig.HARVEST_GOLD],
			[tr(str(spec.get("title", ""))), 38, GameConfig.UI_INK],
			[tr(str(spec.get("done_dialogue", ""))), 27, Color(0.78, 0.78, 0.74)]]:
		var label := Label.new()
		label.text = str(line[0])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", int(line[1]))
		label.add_theme_color_override("font_color", line[2])
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(label)
	var reward := int(spec.get("reward_scrap", 0))
	if reward > 0:
		var pay := Label.new()
		pay.text = "+%d" % reward
		pay.add_theme_font_size_override("font_size", 34)
		pay.add_theme_color_override("font_color", GameConfig.UI_GREEN)
		pay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(pay)

	card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(card, "modulate:a", 1.0, 0.3)
	tween.tween_interval(4.2)
	tween.tween_property(card, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func() -> void:
		if is_instance_valid(card):
			card.queue_free())


## Gus on the radio, once per open invitation: the field is ready. Tapping it
## goes to the map, where the gold pin is already waiting (G13.6). Keyed by the
## chapter count so a NEW invitation calls again and the same one does not.
func _harvest_call() -> void:
	if not HarvestLog.is_offered():
		return
	var stamp := ChapterProgress.done_count()
	if int(GameState.get_setting("harvest", "called_at", -1)) == stamp:
		return
	GameState.set_setting("harvest", "called_at", stamp)

	var card := Button.new()
	card.name = "HarvestCall"
	card.text = tr("HARVEST_CALL")
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.custom_minimum_size = Vector2(0, 132)
	card.add_theme_font_size_override("font_size", 30)
	card.add_theme_color_override("font_color", GameConfig.UI_ON_BRASS)
	var skin := StyleBoxFlat.new()
	skin.bg_color = GameConfig.HARVEST_GOLD
	skin.set_corner_radius_all(18)
	skin.set_content_margin_all(20)
	skin.border_color = Color(0.42, 0.30, 0.08)
	skin.set_border_width_all(3)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, skin)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	card.offset_top = 300.0
	card.offset_left = 40.0
	card.offset_right = -40.0
	card.offset_bottom = 432.0
	card.modulate.a = 0.0
	add_child(card)
	card.pressed.connect(func() -> void:
		Haptics.light()
		card.queue_free()
		open_map_at(GameConfig.HARVEST_VARIANT))
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.35)
	tween.tween_interval(6.0)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void:
		if is_instance_valid(card):
			card.queue_free())


## Rebuilt when a project lands, so the STATION card renames itself the moment
## the station is finished rather than on the next hub visit.
func _refresh_tiles() -> void:
	if _tiles_page == null:
		return
	var column: VBoxContainer = _tiles_page.get_meta("column")
	for child in column.get_children():
		child.queue_free()
	for tile: Dictionary in Story.list("hub.tiles"):
		column.add_child(_make_tile(tile))
	_add_harvest_tile(column)
	_add_case_two_tile(column)
	var story := Button.new()
	story.text = tr("UI_STORY")
	story.custom_minimum_size = Vector2(0, 110)
	story.add_theme_font_size_override("font_size", 34)
	story.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	_style_card(story, true)
	story.pressed.connect(func() -> void:
		Haptics.light()
		replay_intro_requested.emit())
	column.add_child(story)
