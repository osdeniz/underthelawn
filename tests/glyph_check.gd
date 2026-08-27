extends Node
## G16: no colour-emoji codepoint may reach a Label, a Button or a .tscn.
##
## One emoji character makes Godot ask the OS for a font that has it. On this
## platform that is Apple Color Emoji, and loading it costs 184 MB of RAM —
## measured, on a single invisible Label. It was a fifth of the app's whole
## footprint, paid for glyphs iOS draws as blank boxes anyway.
##
## This test is the fence around that fix: scenes are scanned for emoji text,
## and the live HUD is walked after it builds, so neither a hand-edited .tscn
## nor a runtime string can bring the cost back unnoticed.

## Scenes whose text is player-facing.
const SCENES: Array[String] = [
	"res://ui/hud.tscn",
	"res://scenes/Main.tscn",
	"res://scenes/Root.tscn",
]

var _fails := 0


func _ready() -> void:
	_check_guard()
	_check_scene_files()
	await _check_live_hud()
	if _fails > 0:
		push_error("%d GLIF TESTI BASARISIZ" % _fails)
		print("--- %d GLIF TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM GLIF TESTLERI GECTI ---")
	get_tree().quit()


func _check_guard() -> void:
	ck("astral emoji ayiklaniyor",
		GlyphGuard.safe("%s  Radio" % String.chr(0x1F4FB)) == "Radio",
		GlyphGuard.safe("%s  Radio" % String.chr(0x1F4FB)))
	# The variation selector alone is what turns a plain glyph into a colour
	# one, so it has to go even when the base character stays.
	ck("varyasyon secici ayiklaniyor",
		GlyphGuard.safe("%s%s" % [String.chr(0x2699), String.chr(0xFE0F)])
			== String.chr(0x2699), "")
	ck("duz metin degismiyor", GlyphGuard.safe("CONTINUE THE CASE") ==
		"CONTINUE THE CASE", "")
	ck("turkce harfler korunuyor", GlyphGuard.safe("ÇĞİÖŞÜ") == "ÇĞİÖŞÜ", "")
	ck("ok isareti korunuyor", GlyphGuard.safe("Devam →") == "Devam →", "")
	ck("pahali glif taniniyor", GlyphGuard.costly(String.chr(0x1F512)), "")
	ck("ucuz glif pahali sayilmiyor", not GlyphGuard.costly("✓ Devam →"), "")


## Every `text = "..."` in the shipped scenes.
func _check_scene_files() -> void:
	for path in SCENES:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			ck("sahne okunabiliyor: %s" % path, false, "")
			continue
		var found: Array[String] = []
		for line in file.get_as_text().split("\n"):
			if not line.begins_with("text = ") and not line.contains("\"text\""):
				continue
			if GlyphGuard.costly(line):
				found.append(line.strip_edges())
		ck("sahnede emoji yok: %s" % path.get_file(), found.is_empty(),
			", ".join(found))


## The HUD as it actually is a few frames in, self-built pieces included.
func _check_live_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud: Node = load("res://ui/hud.tscn").instantiate()
	layer.add_child(hud)
	for _i in 8:
		await get_tree().process_frame
	var offenders: Array[String] = []
	_walk(hud, offenders)
	ck("canli HUD metinlerinde emoji yok", offenders.is_empty(),
		", ".join(offenders))
	hud.queue_free()
	await get_tree().process_frame


func _walk(node: Node, out: Array[String]) -> void:
	var text := ""
	if node is Label:
		text = (node as Label).text
	elif node is Button:
		text = (node as Button).text
	elif node is RichTextLabel:
		text = (node as RichTextLabel).text
	if text != "" and GlyphGuard.costly(text):
		out.append("%s = %s" % [node.name, text])
	for c in node.get_children():
		_walk(c, out)


func ck(what: String, passed: bool, detail: String) -> void:
	if passed:
		print("  ok   %s" % what)
		return
	_fails += 1
	print("  FAIL %s  %s" % [what, detail])
