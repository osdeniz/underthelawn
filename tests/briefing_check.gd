extends TestBase
## The briefing plays over the yard it is about (G54), not over the last one
## the player mowed.

func run() -> void:
	suite = "BRIFING"
	var root: Node = load("res://scenes/Root.tscn").instantiate()
	add_child(root)
	await settle(0.8)
	ChapterProgress.reset()

	# The chapter the board would offer, and its briefing.
	var vid := "ch01_aldridge"
	var brief := str(ChapterProgress.entry(vid).get("brief", ""))
	ck("bolumun brifingi var", not Dialogue.conversation(brief).is_empty(), brief)

	root._on_chapter_chosen(vid)
	await settle(1.2)
	# The yard is built and standing behind the dialogue…
	var game: Node = root.get("_game")
	ck("bahce brifingden ONCE kuruldu", game != null and is_instance_valid(game), "")
	ck("brifing ekranda", root.get("_dialogue") != null, "")
	if game == null:
		root.queue_free()
		finish()
		return
	ck("dogru bahce kuruldu", str(game.get("variant_id")) == vid, str(game.get("variant_id")))
	# …and it is held at the gate: no search, no clock, no opening title.
	ck("arama henuz baslamadi", not bool(game.get("_search_started")), "")
	ck("brifing sirasinda otomatik baslamaz", not bool(game.get("autostart_search")), "")

	# The briefing ends; the search begins in the yard already on screen.
	# End it the way the last tap does: the box reports finished and the flow
	# takes it from there.
	var box: Node = root.get("_dialogue")
	if box != null and is_instance_valid(box):
		box.emit_signal("finished")
	await settle(1.4)
	ck("brifing bitince arama baslar", bool(game.get("_search_started")), "")
	root.queue_free()
	await frames(3)
	finish()
