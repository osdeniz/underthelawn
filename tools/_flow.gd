extends SceneTree
## Dumps the whole Case 1 text flow, chapter by chapter, so it can be read as
## one story instead of as scattered keys.
const CHANGED := ["EV_CH04_B_LINE", "EV_CH08_B_LINE", "NOTE_CH06", "NOTE_CH08",
	"DLG_TOWN_ELLIE_2B"]

func mark(key: String) -> String:
	return "  <-- DEGISTI" if CHANGED.has(key) else ""

func _initialize() -> void:
	TranslationServer.set_locale("en")
	var pins := Story.list("board.pins")
	var i := 0
	for chapter: Dictionary in ChapterProgress.chapters():
		var vid := str(chapter["variant_id"])
		var v := LevelVariant.of(vid)
		print("\n===== %s — %s" % [vid, tr(str(chapter["name"]))])
		print("  ACILIS: %s / %s" % [tr(v.opening_headline), tr(v.opening_subline)])
		for entry: Dictionary in Dialogue.conversation(str(chapter.get("brief", ""))):
			if entry.has("choice"):
				print("  BRIEF  [secim]")
				continue
			print("  BRIEF  %s: %s" % [entry["speaker"], tr(str(entry["text"]))])
		for slot in 2:
			var spec: Dictionary = v.evidence_defs[slot]
			var line_key := str(spec["flavor_text"])
			print("  KANIT  %s %s — %s%s" % [spec["icon"],
				tr(str(spec["name"])), tr(line_key), mark(line_key)])
		for key in ["debrief_full", "debrief_partial"]:
			for entry: Dictionary in Dialogue.conversation(str(chapter.get(key, ""))):
				print("  %s %s" % [key.to_upper().substr(0, 8), tr(str(entry["text"]))])
		if i < pins.size():
			var note := str((pins[i] as Dictionary).get("note", ""))
			if note != "":
				print("  PANO   %s%s" % [tr(note), mark(note)])
		i += 1
	print("\n===== FINAL")
	for entry: Dictionary in Dialogue.conversation("finale_case01"):
		print("  %s: %s" % [entry["speaker"], tr(str(entry["text"]))])
	print("  KART   %s / %s" % [tr("REUNION_TITLE"), tr("REUNION_LINE")])
	print("  KART   %s — %s" % [tr("CASE_02_UNLOCKED"), tr("CASE_02_TITLE")])
	print("  PANO   %s" % tr(Story.raw("board.final_note")))
	print("\n===== KASABA (B8 sonrasi Ellie)")
	for entry: Dictionary in Dialogue.town_lines("ellie", 8):
		print("  %s: %s%s" % [entry["speaker"], tr(str(entry["text"])),
			mark(str(entry["text"]))])
	quit()
