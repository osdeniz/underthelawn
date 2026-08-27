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


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)

	if GameConfig.STORY_ALWAYS_REPLAY_INTRO or not _intro_seen():
		# Birdsong belongs to the opening cards ONLY (G9.4): under gameplay it
		# read as an untraceable background noise. The theme carries the rest.
		AudioDirector.start_ambient()
		AudioDirector.play_theme()
		_play_intro()
	else:
		_open_hub()


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
	# Harvest has its own completion event (game.gd's "harvest_completed",
	# with the scrap payout); this is the case-chapter funnel's bottom.
	if not LevelVariant.of(_pending_variant).is_harvest():
		Analytics.track("chapter_completed", {"chapter": _pending_variant,
			"evidence": evidence, "total": total, "full": evidence >= total})
	# G11: the last chapter ends the CASE, not just a search — Ellie speaks, then
	# the reunion card. A partial finish still gets the ordinary nudge.
	var is_finale := _is_last_chapter(_pending_variant) and evidence >= total
	if is_finale:
		Analytics.track("case_completed", {"chapter": _pending_variant})
		_play_dialogue(Dialogue.conversation("finale_case01"), "",
			func() -> void: _show_reunion())
		return
	var key := "debrief_full" if evidence >= total else "debrief_partial"
	var lines := Dialogue.conversation(str(chapter.get(key, "")))
	if lines.is_empty():
		return
	_play_dialogue(lines, "", func() -> void: pass)


func _is_last_chapter(variant_id: String) -> bool:
	var chapters := ChapterProgress.chapters()
	if chapters.is_empty():
		return false
	return str((chapters.back() as Dictionary).get("variant_id", "")) == variant_id


## The warm close: Ellie home, the board complete, and the door to Case 02.
func _show_reunion() -> void:
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
		_clear_game()
		if _hub == null or not is_instance_valid(_hub):
			_open_hub()
		else:
			_hub.get_parent().visible = true
			_hub.refresh()
			AudioDirector.play_theme()
			_fade_in()
		_hub.open_evidence_board()
		AudioDirector.play_pin())


func _clear_game() -> void:
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = null
