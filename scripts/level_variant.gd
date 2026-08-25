class_name LevelVariant
extends RefCounted
## One chapter's yard, described by data/levels.json (G9).
##
## ONE game scene builds all eight chapters. `apply()` is the single place a
## variant reaches into the engine, and it runs BEFORE LawnModel is constructed,
## because the grid size it sets is what the model, the view, the tuft field, the
## camera bounds, the robot's route planner and the completion percentage all
## derive from.
##
## Nothing here is a scene path, and nothing may become one.

const PATH := "res://data/levels.json"

static var _data: Dictionary = {}
static var _warned := false
## The variant the current chapter is running. Set by apply(), read by nodes
## whose _ready fires before the game scene's own (EnvironmentBuilder), since
## child _ready always precedes parent _ready.
static var current: LevelVariant

var id := ""
var palette_id := "GREEN"
var grid_size := "medium"
var obstacle_layout_id := "beds"
var house_variant := "house_v1"
var landmark_id := ""
var decor_seed := 0
var scrap_budget := 9
var vignette := false
var evidence_defs: Array = []
## Per-chapter opening title keys; "" falls back to story.json's default.
var opening_headline := ""
var opening_subline := ""
## One optional world-history find per chapter, separate from the case evidence
## (G12.6). It never advances the case; it only says what the dead years left.
var echo_def: Dictionary = {}


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		_warn("data/levels.json yok - varsayilan bahce kullanilacak")
		return _data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		_warn("data/levels.json cozumlenemedi")
	return _data


## The variant for a chapter id. An unknown id returns defaults rather than
## failing, so a chapter listed on the board but not yet authored still plays.
static func of(variant_id: String) -> LevelVariant:
	var variant := LevelVariant.new()
	variant.id = variant_id
	var all: Variant = data().get("variants", {})
	if not (all is Dictionary) or not (all as Dictionary).has(variant_id):
		_warn("varyant tanimsiz: %s - varsayilan kullanildi" % variant_id)
		return variant
	var spec: Dictionary = (all as Dictionary)[variant_id]
	variant.palette_id = str(spec.get("palette_id", variant.palette_id))
	variant.grid_size = str(spec.get("grid_size", variant.grid_size))
	variant.obstacle_layout_id = str(spec.get("obstacle_layout_id",
		variant.obstacle_layout_id))
	variant.house_variant = str(spec.get("house_variant", variant.house_variant))
	variant.landmark_id = str(spec.get("landmark_id", ""))
	variant.decor_seed = int(spec.get("decor_seed", 0))
	variant.scrap_budget = int(spec.get("scrap_budget", variant.scrap_budget))
	variant.vignette = bool(spec.get("vignette", false))
	variant.evidence_defs = spec.get("evidence_defs", [])
	var echo: Variant = spec.get("echo_def", {})
	if echo is Dictionary:
		variant.echo_def = echo
	var opening: Variant = spec.get("opening", {})
	if opening is Dictionary:
		variant.opening_headline = str((opening as Dictionary).get("headline", ""))
		variant.opening_subline = str((opening as Dictionary).get("subline", ""))
	return variant


static func ids() -> Array:
	var all: Variant = data().get("variants", {})
	return (all as Dictionary).keys() if all is Dictionary else []


## Pushes this variant into the engine. MUST run before LawnModel is built.
func apply() -> void:
	current = self
	GameConfig.set_grid_named(grid_size)
	GameConfig.active_grass_palette = palette_id
	LawnModel.layout_id = obstacle_layout_id


func evidence_count() -> int:
	return evidence_defs.size()


## Display data for evidence slot `index`, in the same shape SecretItem.info_for
## returns, so the reveal card and the case notes need no special case.
func evidence_info(index: int) -> Dictionary:
	if index < 0 or index >= evidence_defs.size():
		return {}
	var entry: Dictionary = evidence_defs[index]
	return {
		"emoji": str(entry.get("icon", "?")),
		"name": TranslationServer.translate(str(entry.get("name", ""))),
		"line": TranslationServer.translate(str(entry.get("flavor_text", ""))),
		"id": str(entry.get("id", "")),
		"where": TranslationServer.translate(str(entry.get("location_tag", ""))),
	}


## The chapter's echo in the same shape, or {} if it has none.
func echo_info() -> Dictionary:
	if echo_def.is_empty():
		return {}
	return {
		"emoji": str(echo_def.get("icon", "?")),
		"name": TranslationServer.translate(str(echo_def.get("name", ""))),
		"line": TranslationServer.translate(str(echo_def.get("flavor_text", ""))),
		"id": str(echo_def.get("id", "")),
	}


static func _warn(message: String) -> void:
	if _warned:
		return
	_warned = true
	push_warning("[LevelVariant] " + message)
	print("[LevelVariant] " + message)
