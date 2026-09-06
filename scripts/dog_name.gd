class_name DogName
extends RefCounted
## The dog's name (G26). The man on the road refused to name it (PRO_ROAD_3A);
## Ellie names it the evening she comes home, and after that the game says the
## name wherever it used to say "the dog". Until then, and if the player skips
## the question, it stays "the dog" — the fallback is a real sentence, not an
## empty string.

const SECTION := "story"
const KEY := "dog_name"
const MAX_CHARS := 14
const SUGGESTION_KEYS: Array[String] = ["DOG_SUGGEST_1", "DOG_SUGGEST_2", "DOG_SUGGEST_3"]


static func has_name() -> bool:
	return str(GameState.get_setting(SECTION, KEY, "")).strip_edges() != ""


## The saved name, or the localised "the dog". Not get_name/set_name: a
## class_name resolves to its Script resource, whose native get_name/set_name
## win over the static ones — measured: the name "saved" to the resource and
## the file never changed (G26).
static func current() -> String:
	var saved := str(GameState.get_setting(SECTION, KEY, "")).strip_edges()
	return saved if saved != "" else TranslationServer.translate("DOG_UNNAMED")


## Trims, clips to MAX_CHARS, drops line breaks. An empty result clears the name.
static func store(raw: String) -> void:
	var clean := clean_name(raw)
	GameState.set_setting(SECTION, KEY, clean)


static func clean_name(raw: String) -> String:
	var clean := raw.replace("\n", " ").replace("\r", " ").strip_edges()
	if clean.length() > MAX_CHARS:
		clean = clean.substr(0, MAX_CHARS).strip_edges()
	return clean


## Three names in the player's language, for the chips under the box.
static func suggestions() -> Array[String]:
	var out: Array[String] = []
	for key in SUGGESTION_KEYS:
		out.append(TranslationServer.translate(key))
	return out


## Replaces {dog} with the name and {Dog} with the name capitalised for the
## start of a sentence ("Köpek durdu." / "Pilot durdu."). Cheap when there is
## nothing to replace, so callers can run every line through it.
static func fill(text: String) -> String:
	if text.find("{dog}") < 0 and text.find("{Dog}") < 0:
		return text
	var name := current()
	var cap := name.substr(0, 1).to_upper() + name.substr(1)
	return text.replace("{dog}", name).replace("{Dog}", cap)
