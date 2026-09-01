class_name RootFlow
extends Node
## G8 flow controller and the project's main scene.
##
##   intro cards (first launch) -> HUB -> case board -> briefing dialogue
##      -> game scene -> debrief dialogue + case notes -> HUB
##
## The game scene (scenes/Main.tscn) is untouched and still runs standalone —
## every test instantiates it directly — so it must never depend on this node.
## It is handed a `variant_id` and reports back with `search_finished`; if
## nobody is listening it just keeps playing.
##
## ARCHITECTURE: a chapter is an ID, never a scene. G9 builds all eight chapters
## from this one game scene plus LevelVariant data, so nothing here may grow a
## per-chapter scene path.

const GAME_SCENE := "res://scenes/Main.tscn"

var _layer: CanvasLayer
var _fade: ColorRect
var _hub: HubScreen
var _game: Node
var _intro: IntroSequence
var _dialogue: DialogueBox
var _pending_variant := ""
## Set once the yard's shaders have been compiled, so a replayed intro does not
## pay for it a second time.
var _shaders_warmed := false
## Save key holding the build the yard's shaders were last compiled for.
const WARMED_FOR := "shaders_warmed_for"


func _ready() -> void:
	# Before any screen exists, so the first label already draws in the
	# player's chosen language rather than flipping after the menu appears.
	LocaleSupport.restore()
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	_fade.color.a = 0.0
	_show_main_menu()


# ---------------------------------------------------------------- main menu

## The app's front door (UI/UX redesign). Nothing used to stand here: the game
## went straight into the intro cards on every cold launch, with no CONTINUE,
## no deliberate way to start over, and no home for Settings. This is that
## screen, shown before anything else, every launch.
func _show_main_menu() -> void:
	# The theme starts HERE, on the first thing the player sees, not after they
	# have chosen something. It used to begin in _begin_after_menu, so the menu
	# — the screen carrying the cover art — was the one silent screen in the
	# game. play_theme is idempotent: it returns early if the same stream is
	# already playing, so the later call on the way into a chapter is a no-op
	# and the music runs unbroken across the transition.
	AudioDirector.play_theme()
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	var menu := MainMenu.new()
	layer.add_child(menu)
	menu.continue_pressed.connect(func() -> void:
		layer.queue_free()
		_begin_after_menu())
	menu.new_game_pressed.connect(func() -> void:
		GameState.erase_save()
		layer.queue_free()
		_begin_after_menu())
	menu.journal_pressed.connect(func() -> void:
		# Opened over the menu, not through the hub: the Journal reads only
		# saved progress, so it needs no game flow behind it and the player
		# keeps their place in the menu when they close it.
		var journal := JournalScreen.new()
		layer.add_child(journal)
		journal.closed.connect(func() -> void: journal.queue_free()))
	menu.settings_pressed.connect(func() -> void:
		var settings := SettingsScreen.new()
		layer.add_child(settings)
		settings.closed.connect(func() -> void: settings.queue_free()))


## Test seam. A test that instantiates Root through code rather than through a
## tap needs to get past the main menu the same way a player's CONTINUE tap
## does, without synthesizing input events. Every test that builds Root
## directly (MemoryCheck, Case2Flow) calls this once, right after add_child.
func dismiss_main_menu() -> void:
	for child in get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 45:
			child.queue_free()
	await _begin_after_menu()


## Everything that used to run unconditionally in _ready, now run once the
## player has chosen CONTINUE or NEW GAME rather than the instant the app
## opens.
func _begin_after_menu(skip_fade_in := false) -> void:
	if not skip_fade_in:
		_fade.color.a = 1.0
	if GameConfig.STORY_ALWAYS_REPLAY_INTRO or not _intro_seen():
		# Birdsong belongs to the opening cards ONLY (G9.4): under gameplay it
		# read as an untraceable background noise. The theme carries the rest.
		AudioDirector.start_ambient()
		AudioDirector.play_theme()
		_play_intro()
	else:
		# A returning player has no intro to hide the shader bill behind, and
		# the hub -> yard transition is only a 0.35 s fade — far too short to
		# cover a cold compile, which is where the wait would otherwise land.
		# So it is paid here instead, at launch, on the black the fade is
		# already holding, with one line saying what is happening. On a warm
		# cache (every launch after the first) this returns immediately and
		# nothing is drawn.
		await _warm_chapter_shaders(true)
		_open_hub()


## Back out to the front door. The menu is REBUILT rather than kept alive
## behind everything: it is freed on CONTINUE, and a screen that only exists at
## launch is cheaper than one parked under the whole game for a trip that most
## players make once (G14.9).
##
## The hub is hidden and its town stopped first — a live diorama rendering
## behind a full-screen menu is a framebuffer nobody is looking at.
## Public seam for the level's pause sheet, which reaches the flow by name.
func return_to_main_menu() -> void:
	_return_to_main_menu()


func _return_to_main_menu() -> void:
	_clear_game()
	if _hub != null and is_instance_valid(_hub):
		_hub.set_diorama_active(false)
		_hub.get_parent().visible = false
	_show_main_menu()


# ---------------------------------------------------------------- intro

func _intro_seen() -> bool:
	return bool(GameState.get_setting("story", "intro_seen", false))


func _play_intro() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_intro = IntroSequence.new()
	_intro.name = "Intro"
	layer.add_child(_intro)
	_fade.color.a = 0.0
	# The cards are opaque and the player is reading them: the best moment in
	# the whole game to pay the shader bill. See _warm_chapter_shaders.
	_warm_chapter_shaders(false)
	_intro.finished.connect(func() -> void:
		_intro = null
		layer.queue_free()
		var first_run := not _intro_seen()
		GameState.set_setting("story", "intro_seen", true)
		AudioDirector.stop_ambient()
		# G10.1: a first-time player goes straight from the cards into the
		# grass. The hub is a place you EARN — showing a menu of screens before
		# anyone has mown a single cell buries the game under its own furniture.
		if first_run:
			_on_chapter_chosen(ChapterProgress.current_variant_id())
		else:
			_open_hub())


## Builds a throwaway yard behind the intro cards so the first real chapter does
## not have to.
##
## THE PROBLEM. A yard's shaders are compiled the first time the yard is drawn,
## and only then. Measured cold on a desktop: 1.4 s inside _ready and another
## 0.8 s on the first drawn frame. On a phone that was five to six seconds of
## black before the player's first lawn — and only ever the first, because the
## pipeline cache is kept from then on, which is exactly why every later garden
## opened instantly and this looked like a mystery.
##
## THE FIX. The cost cannot be removed, so it is moved to where it is free. The
## intro's ground is a full-rect opaque ColorRect, so nothing built behind it is
## ever seen; the player is reading a card while this runs. Afterwards the real
## chapter builds from a warm cache — measured 670 ms -> 93 ms within one
## process, a seven-fold drop.
##
## The copy is built with autostart_search off, so it fires no analytics event,
## starts no run clock and arms no orientation countdown. It is freed as soon as
## it has been drawn; what survives is the compiled pipelines, which is the
## whole point.
## `announce` puts a line on the black while it works. The intro path passes
## false — it has a full screen of art to hide behind, and a loading notice over
## a story card would be worse than the wait it describes. The hub path passes
## true, because there the only cover is the fade itself, and an unexplained
## still frame is what "broken" looks like.
func _warm_chapter_shaders(announce: bool) -> void:
	if _shaders_warmed:
		return
	_shaders_warmed = true
	# The notice is for a WAIT, not for the warm-up. On every launch after the
	# first the cache is already full, the whole thing takes about eighty
	# milliseconds, and a line that flashes for five frames reads as a glitch.
	var notice: Label = null
	if announce and _shader_cache_cold():
		notice = _build_warm_notice()
	# The throwaway chapter applies its variant, and a variant is GLOBAL state:
	# palette, plant profile, obstacle layout and grid. Left set, the hub's
	# diorama grew the yard's grass instead of the town's — blue-green on first
	# launch. Snapshot before, restore after (G13).
	var world := LevelVariant.snapshot()
	var warm: Node = load(GAME_SCENE).instantiate()
	warm.set("variant_id", ChapterProgress.current_variant_id())
	warm.set("autostart_search", false)
	add_child(warm)
	# DRAWN, not merely built: compilation happens when the frame is rendered,
	# so building it and freeing it in the same breath would warm nothing.
	#
	# Except where there is nothing to draw with. Under --headless the display
	# driver is a stub and RenderingServer.frame_post_draw NEVER fires — not
	# late, not once: never. Awaiting it there is an unconditional deadlock,
	# and it silently hung every headless test that reached this function.
	# There are no shaders to warm on a stub renderer anyway, so the frame
	# counter is both the correct wait and a harmless one.
	var headless := DisplayServer.get_name() == "headless"
	for _i in 4:
		if headless:
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
	if is_instance_valid(warm):
		# STOP it before restoring, and wait for it to actually leave.
		#
		# queue_free() is deferred: the scene lives to the end of the frame and
		# its mower keeps mowing. Restoring the grid first left a LawnModel
		# built for one grid being indexed against another, which is an
		# out-of-bounds crash — and it only appeared once a player had
		# progressed far enough that the warmed chapter was the ROAD (9x34)
		# rather than a medium yard, because until then the two grids matched
		# by luck (G13).
		warm.process_mode = Node.PROCESS_MODE_DISABLED
		warm.queue_free()
		# Polled with a ceiling, NOT `await warm.tree_exited`. A bare signal
		# await has no timeout, so any path where the signal does not arrive is
		# a permanent hang rather than a slow frame — and this one hung
		# intermittently, taking the whole launch with it. Waiting on the
		# condition cannot hang; at worst it gives up and the grid is restored
		# a few frames later than ideal, which is survivable. Nothing else here
		# is.
		var waited := 0
		while waited < 120 and is_instance_valid(warm):
			await get_tree().process_frame
			waited += 1
	LevelVariant.restore(world)
	if notice != null and is_instance_valid(notice):
		notice.queue_free()
	GameState.set_setting("meta", WARMED_FOR, _build_stamp())


## True when this build has never compiled the yard's shaders on this install —
## the only case slow enough to be worth explaining.
##
## Inspecting user://shader_cache does not answer this: Godot creates that
## folder and starts filling it with the engine's own shaders before _ready
## runs, so it is never empty by the time anyone can look. So the answer is
## recorded instead, and recorded AGAINST THE BUILD VERSION — a new binary
## invalidates the compiled pipelines, and the first launch after an update
## deserves the same line the first launch after an install gets.
func _shader_cache_cold() -> bool:
	return str(GameState.get_setting("meta", WARMED_FOR, "")) != _build_stamp()


func _build_stamp() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return version if version != "" else "0"


## One quiet line on the black, for the one path with nothing to hide behind.
## It lives on the fade layer, above everything, and is gone within the frame
## the warm-up ends. On a warm cache it is never built at all.
func _build_warm_notice() -> Label:
	var label := Label.new()
	label.text = tr("UI_PREPARING")
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.62, 0.60, 0.55))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(label)
	return label


# ---------------------------------------------------------------- hub

func _open_hub() -> void:
	_clear_game()
	if _hub == null or not is_instance_valid(_hub):
		var layer := CanvasLayer.new()
		layer.layer = 10
		layer.name = "HubLayer"
		add_child(layer)
		_hub = HubScreen.new()
		_hub.name = "Hub"
		layer.add_child(_hub)
		_hub.chapter_chosen.connect(_on_chapter_chosen)
		_hub.replay_intro_requested.connect(_play_intro)
		_hub.main_menu_requested.connect(_return_to_main_menu)
	_hub.get_parent().visible = true
	_hub.set_diorama_active(true)
	_hub.refresh()
	AudioDirector.play_theme()
	_fade_in()


func _fade_in() -> void:
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


## Runs `action` behind a black screen, so no swap is ever seen mid-frame.
func _fade_out_then(action: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(action)


# ---------------------------------------------------------------- chapter

func _on_chapter_chosen(variant_id: String) -> void:
	_pending_variant = variant_id
	var chapter := ChapterProgress.entry(variant_id)
	var brief_id := str(chapter.get("brief", ""))
	var lines := Dialogue.conversation(brief_id)
	if lines.is_empty():
		# No briefing written for this chapter yet: go straight in rather than
		# stranding the player on the board.
		_start_chapter()
		return
	_play_dialogue(lines, Dialogue.accept_key(brief_id), _start_chapter)


func _play_dialogue(lines: Array, accept_key: String, then: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_dialogue = DialogueBox.new()
	layer.add_child(_dialogue)
	_dialogue.finished.connect(func() -> void:
		_dialogue = null
		layer.queue_free()
		then.call())
	_dialogue.play(lines, accept_key)


func _start_chapter() -> void:
	_fade_out_then(func() -> void:
		_clear_game()
		if _hub != null and is_instance_valid(_hub):
			_hub.set_diorama_active(false)
			_hub.get_parent().visible = false
		_game = load(GAME_SCENE).instantiate()
		# Handed the id BEFORE _ready, so the scene can build from it in G9.
		_game.set("variant_id", _pending_variant)
		_game.set("autostart_search", true)
		add_child(_game)
		_game.connect("search_finished", _on_search_finished)
		_fade_in())


## The game scene reports the result; the hub records it and the player returns.
func _on_search_finished(evidence: int, total: int) -> void:
	ChapterProgress.record(_pending_variant, evidence, total)
	var chapter := ChapterProgress.entry(_pending_variant)
	# Harvest has its own completion event (game.gd's HARVEST_COMPLETED, with
	# the scrap payout); this is the case-chapter funnel's bottom.
	if not LevelVariant.of(_pending_variant).is_harvest():
		Analytics.track(AnalyticsEvents.CHAPTER_COMPLETED, {"chapter": _pending_variant,
			"evidence": evidence, "total": total, "full": evidence >= total})
	# G11: the last chapter ends the CASE, not just a search — Ellie speaks, then
	# the reunion card. A partial finish still gets the ordinary nudge.
	var is_finale := _is_last_chapter(_pending_variant) and evidence >= total
	if is_finale:
		Analytics.track(AnalyticsEvents.CASE_COMPLETED, {"chapter": _pending_variant})
		# Which case just closed decides which ending plays. Case 01 ends warm
		# and then cold — Ellie home, then the question of what she saw. Case 02
		# ends the same shape: the town in sight, then the lights on the road
		# behind it (G13).
		if _in_case_two(_pending_variant):
			_play_dialogue(Dialogue.conversation("debrief_ch18_full"), "",
				func() -> void: _show_convoy())
		else:
			_play_dialogue(Dialogue.conversation("finale_case01"), "",
				func() -> void: _show_reunion())
		return
	var key := "debrief_full" if evidence >= total else "debrief_partial"
	var lines := Dialogue.conversation(str(chapter.get(key, "")))
	# A chapter can be followed by a scene rather than by silence: the road east
	# has one, and it is charged whether or not the debrief had anything to say
	# (G13).
	var scene := str(chapter.get("quiet_scene", ""))
	if lines.is_empty():
		if scene != "":
			_play_quiet_scene(scene)
		return
	_play_dialogue(lines, "", func() -> void:
		if scene != "":
			_play_quiet_scene(scene))


## A scene the player watches, over its own drawn still, between chapters.
func _play_quiet_scene(scene_id: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 65
	add_child(layer)
	var scene := QuietScene.new()
	layer.add_child(scene)
	scene.finished.connect(func() -> void: layer.queue_free())
	scene.play(scene_id)


## Last of ITS OWN case, not of the game. Once Case 02's chapters joined the
## board this asked the wrong question and Case 01's ending stopped firing: the
## cellar is no longer the final entry in the list, only the final entry in the
## case it belongs to (G13).
func _is_last_chapter(variant_id: String) -> bool:
	var chapters := ChapterProgress.case_of(variant_id)
	if chapters.is_empty():
		return false
	return str((chapters.back() as Dictionary).get("variant_id", "")) == variant_id


func _in_case_two(variant_id: String) -> bool:
	for chapter: Dictionary in Story.list("case_02.chapters"):
		if str(chapter.get("variant_id", "")) == variant_id:
			return true
	return false


## Case 02's close: two weeks of road behind, and headlights on it.
func _show_convoy() -> void:
	# The chapter goes FIRST. Its HUD is still on screen otherwise, and the
	# results panel underneath is a full-screen Control that takes the tap at
	# the GUI stage — before _unhandled_input, which is how these cards listen.
	# So the card drew, and every tap on it went to a panel nobody could see:
	# the ending sat there and "continue" did nothing (G13).
	_clear_game()
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var card := ConvoyCard.new()
	layer.add_child(card)
	card.finished.connect(func() -> void:
		layer.queue_free()
		GameState.set_setting("story", "case02_closed", true)
		return_to_board())


## The warm close: Ellie home, the board complete, and the door to Case 02.
func _show_reunion() -> void:
	# The chapter goes FIRST. Its HUD is still on screen otherwise, and the
	# results panel underneath is a full-screen Control that takes the tap at
	# the GUI stage — before _unhandled_input, which is how these cards listen.
	# So the card drew, and every tap on it went to a panel nobody could see:
	# the ending sat there and "continue" did nothing (G13).
	_clear_game()
	var layer := CanvasLayer.new()
	layer.layer = 70
	add_child(layer)
	var card := ReunionCard.new()
	layer.add_child(card)
	card.finished.connect(func() -> void:
		layer.queue_free()
		GameState.set_setting("story", "case01_closed", true)
		# Straight onto the finished board: the pins ARE the ending.
		return_to_board())


## Called by the case-notes NEXT button: brief and start the chapter after
## `current_id`, exactly as if it had been picked on the board.
## The chapter-end NEXT button. It used to drop the player straight into the
## following search; it now returns to the case map with that place focused, so
## the case reads as a journey across the town rather than a queue of levels
## (G13.5). One more tap to start, and the map is what earns it.
func start_next_chapter(current_id: String) -> void:
	var chapters := ChapterProgress.chapters()
	for i in chapters.size():
		if str(chapters[i].get("variant_id", "")) != current_id:
			continue
		if i + 1 >= chapters.size():
			_open_hub()
			return
		var next_id := str(chapters[i + 1].get("variant_id", ""))
		_fade_out_then(func() -> void:
			_open_hub()
			if _hub != null and is_instance_valid(_hub):
				_hub.open_map_at(next_id))
		return


## Called by the game scene's RETURN TO TOWN button.
func return_to_hub() -> void:
	_fade_out_then(_open_hub)


## VIEW CASE BOARD from the case-notes panel: hub, opened straight onto the
## corkboard, with the pin thunk as the new evidence lands (G10).
func return_to_board() -> void:
	_fade_out_then(func() -> void:
		# _open_hub(), not a hand-written copy of it. This branch used to re-show
		# the hub itself and left out set_diorama_active(true), so the town came
		# back still PARKED — rendered at 1/32 scale for the chapter and then
		# stretched across the whole screen. It read as heavy shimmering, and it
		# only happened on this one route home (G13).
		_open_hub()
		_hub.open_evidence_board()
		AudioDirector.play_pin())


func _clear_game() -> void:
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = null
