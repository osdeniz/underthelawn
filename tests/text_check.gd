extends Node
## Every text key the DATA points at exists in both languages. A missing key
## renders as the key itself — "DLG_CHAT_HARVEST_1" on a speech bubble — and
## the way it happens in practice is not a typo but a stale import: keys added
## to strings.csv do not reach the .translation resources until the project is
## re-imported, so a run straight after editing the CSV shows raw keys while
## every other test passes. This test fails on exactly that.

var _fails := 0


func _ready() -> void:
	var keys := {}
	_collect(Story.data(), keys)
	_collect(Dialogue.data(), keys)
	for spec: Dictionary in LevelVariant.data().get("variants", {}).values():
		_collect(spec, keys)
	var was := TranslationServer.get_locale()
	for locale: String in ["en", "tr"]:
		TranslationServer.set_locale(locale)
		var missing: Array[String] = []
		for key: String in keys:
			if TranslationServer.translate(key) == key:
				missing.append(key)
		missing.sort()
		ck("%s: veri anahtarlarinin hepsi cevrili (%d anahtar)" % [locale, keys.size()],
			missing.is_empty(), "eksik %d: %s" % [missing.size(), ", ".join(missing.slice(0, 12))])
	TranslationServer.set_locale(was)
	print("  [olcum] veri dosyalarinda %d metin anahtari" % keys.size())
	if _fails > 0:
		push_error("%d METIN TESTI BASARISIZ" % _fails)
		print("--- %d METIN TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM METIN TESTLERI GECTI ---")
	get_tree().quit()


## Walks any JSON value and keeps every string that LOOKS like a key: upper-case
## letters, digits and underscores only, at least one underscore. Paths, ids and
## comments never match that shape; translation keys always do.
func _collect(value: Variant, out: Dictionary) -> void:
	if value is Dictionary:
		for k: Variant in value:
			var name := str(k)
			# Comments, and IDENTIFIERS that happen to be upper-case: palette
			# ids like DRY_GOLD are looked up in GameConfig, not in the CSV.
			if name.begins_with("_") or name.ends_with("_id") or name == "grid_size":
				continue
			_collect(value[k], out)
	elif value is Array:
		for item: Variant in value:
			_collect(item, out)
	elif value is String:
		var text := value as String
		if text.length() < 4 or text.find("_") < 0:
			return
		for ch in text:
			if not (ch == "_" or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")):
				return
		out[text] = true


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
