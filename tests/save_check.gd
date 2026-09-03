extends Node
## G16.2: the save survives what used to wipe it. Every claim is made against
## SCRATCH files, so the real save is never touched.

var _fails := 0
var _p := {}


func _ready() -> void:
	_p = {"PATH": SaveStore.PATH, "BACKUP": SaveStore.BACKUP, "TMP": SaveStore.TMP,
		"LEGACY": SaveStore.LEGACY}
	SaveStore.PATH = "user://_test_save.json"
	SaveStore.BACKUP = "user://_test_save.json.bak"
	SaveStore.TMP = "user://_test_save.json.tmp"
	SaveStore.LEGACY = "user://_test_settings.cfg"
	_wipe()

	# --- legacy migration keeps values AND types
	var cfg := ConfigFile.new()
	cfg.set_value("economy", "scrap", 1234)
	cfg.set_value("story", "intro_seen", true)
	cfg.set_value("meta", "locale", "tr")
	cfg.set_value("progress", "done", ["ch01_aldridge", "ch02_neighbor"])
	cfg.set_value("garage", "ratio", 0.68)
	cfg.save(SaveStore.LEGACY)
	var store := SaveStore.new()
	ck("eski cfg yukleniyor", store.load() == OK, "")
	ck("kaynak: legacy", store.loaded_from == "legacy", store.loaded_from)
	ck("int int kaliyor", store.get_value("economy", "scrap", 0) is int
		and store.get_value("economy", "scrap", 0) == 1234, str(store.get_value("economy", "scrap", 0)))
	ck("bool kaliyor", store.get_value("story", "intro_seen", false) == true, "")
	ck("string kaliyor", store.get_value("meta", "locale", "") == "tr", "")
	ck("dizi kaliyor", (store.get_value("progress", "done", []) as Array).size() == 2, "")
	ck("float kaliyor", is_equal_approx(float(store.get_value("garage", "ratio", 0.0)), 0.68), "")
	ck("gocten sonra json var", FileAccess.file_exists(SaveStore.PATH), "")
	ck("tmp kalmadi", not FileAccess.file_exists(SaveStore.TMP), "")

	# --- a second save makes a backup; the file is valid JSON
	store.set_value("economy", "scrap", 1500)
	ck("kayit basarili", store.save() == OK, "")
	ck("yedek var", FileAccess.file_exists(SaveStore.BACKUP), "")
	var text := FileAccess.get_file_as_string(SaveStore.PATH)
	ck("dosya gecerli JSON", JSON.parse_string(text) is Dictionary, "")
	ck("format damgali", int((JSON.parse_string(text) as Dictionary).get("format", 0)) == SaveStore.FORMAT, "")

	# --- the primary is destroyed mid-write: recovery from the backup
	var f := FileAccess.open(SaveStore.PATH, FileAccess.WRITE)
	f.store_string("{\"format\": 2, \"sections\": {\"econ")
	f.close()
	var again := SaveStore.new()
	ck("bozuk dosya yedekten kurtariliyor", again.load() == OK and again.loaded_from == "backup",
		again.loaded_from)
	ck("yedek onceki degeri tasiyor", again.get_value("economy", "scrap", 0) == 1234,
		str(again.get_value("economy", "scrap", 0)))
	ck("kurtarma birincili yeniden yaziyor",
		JSON.parse_string(FileAccess.get_file_as_string(SaveStore.PATH)) is Dictionary, "")

	# --- nothing at all: fresh, not an error
	_wipe()
	var fresh := SaveStore.new()
	ck("hic dosya yokken temiz baslar", fresh.load() == OK and fresh.loaded_from == "fresh",
		fresh.loaded_from)

	# --- erase removes every file
	fresh.set_value("a", "b", 1)
	fresh.save()
	fresh.save()
	fresh.erase()
	ck("silme hepsini kaldiriyor", not FileAccess.file_exists(SaveStore.PATH)
		and not FileAccess.file_exists(SaveStore.BACKUP), "")

	# --- and the live GameState round-trips through the new store
	var probe := randi()
	GameState.set_setting("_test", "probe", probe)
	ck("GameState yeni depoyla okuyor", int(GameState.get_setting("_test", "probe", -1)) == probe, "")
	ck("GameState surumu 2", GameState.save_version() == 2, str(GameState.save_version()))

	_wipe()
	SaveStore.PATH = _p["PATH"]; SaveStore.BACKUP = _p["BACKUP"]
	SaveStore.TMP = _p["TMP"]; SaveStore.LEGACY = _p["LEGACY"]
	if _fails > 0:
		push_error("%d KAYIT TESTI BASARISIZ" % _fails)
		print("--- %d KAYIT TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM KAYIT TESTLERI GECTI ---")
	get_tree().quit()


func _wipe() -> void:
	for path: String in [SaveStore.PATH, SaveStore.BACKUP, SaveStore.TMP, SaveStore.LEGACY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
