extends Node
## G12.10: nothing on the corkboard may sit on top of anything else.
##
## The Marshal's notes are free-positioned Labels that wrap to as many lines as
## the sentence needs, so a long one grows downward into the chapter below it.
## Nothing in the layout code noticed; the player saw stacked text.

var _fails := 0


func _ready() -> void:
	for chapter: Dictionary in Story.list("chapters"):
		ChapterProgress.record(str(chapter.get("variant_id", "")), 3, 3)
	var board := EvidenceBoard.new()
	board.size = Vector2(1170, 2532 * EvidenceBoard.BOARD_SCALE)
	add_child(board)
	for _i in 4:
		await get_tree().process_frame

	var boxes: Array = []
	# Only the pinned things. The cork sheet underneath overlaps everything by
	# design, and pin heads are meant to sit on their own card.
	for node in board.get_node("Cards").get_children():
		var c := node as Control
		if c == null or c is ColorRect or c.size.x <= 0.0:
			continue
		boxes.append({"name": c.name, "rect": Rect2(c.position, c.size),
			"text": (c as Label).text.left(30) if c is Label else "[kart]"})

	var clashes := 0
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Rect2 = boxes[i]["rect"]
			var b: Rect2 = boxes[j]["rect"]
			var hit := a.intersection(b)
			# Pin heads deliberately sit on their card; only real text-on-text
			# overlap counts.
			if hit.get_area() < 400.0:
				continue
			clashes += 1
			if clashes <= 6:
				print("  CAKISMA %s '%s' x %s '%s'  alan=%.0f (%.1f x %.1f px)"
					% [boxes[i]["name"], boxes[i]["text"], boxes[j]["name"],
						boxes[j]["text"], hit.get_area(), hit.size.x, hit.size.y])
	ck("panoda ust uste binen yazi yok", clashes == 0, "%d cakisma" % clashes)

	# Pushing things down to clear each other must not push them off the board.
	var spill := 0
	var worst := 0.0
	for box: Dictionary in boxes:
		var r: Rect2 = box["rect"]
		if r.end.y > board.size.y or r.end.x > 1170.0 or r.position.x < 0.0:
			spill += 1
			worst = maxf(worst, maxf(r.end.y - board.size.y, r.end.x - 1170.0))
	ck("her sey pano icinde", spill == 0, "%d tasma, en fazla %.0f px" % [spill, worst])

	board.queue_free()
	if _fails > 0:
		push_error("%d PANO TESTI BASARISIZ" % _fails)
		print("--- %d PANO TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM PANO TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
