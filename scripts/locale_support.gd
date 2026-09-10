class_name LocaleSupport
extends RefCounted
## Everything a new language needs beyond its column in i18n/strings.csv.
##
## Two things break when you add a language and change nothing else:
##
## 1. GLYPHS. The default theme font covers Latin and little else. Arabic,
##    Hebrew, Chinese, Japanese, Korean, Hindi and Thai render as boxes until a
##    font containing those ranges is registered as a fallback. Drop one in
##    fonts/ (see FALLBACK_PATHS) and this installs it; no code change.
## 2. DIRECTION. Arabic and Hebrew need the whole layout mirrored, not just the
##    text runs reversed. That is project.godot's
##    rendering/root_node_layout_direction=2 ("based on locale"), already set.
##
## Locale starts as the one Godot picks from the OS, which is the right default
## on a phone. It is no longer the last word, though: a player who wants the
## other language can choose it in Settings, and `restore()` reapplies that
## choice on every launch.

## Checked in order; the first that exists is installed. A single font with wide
## coverage (Noto Sans is the usual answer) is enough for all of these.
const FALLBACK_PATHS: Array[String] = [
	"res://fonts/i18n_fallback.ttf",
	"res://fonts/i18n_fallback.otf",
	"res://fonts/i18n_fallback.ttc",
]

## The languages this build actually ships, in menu order, each labelled in
## ITSELF — a player looking for Turkish is looking for "Turkce", not for
## "Turkish" spelled out in a language they do not read.
const SHIPPED: Array[Dictionary] = [
	{"code": "en", "name": "English"},
	{"code": "tr", "name": "Turkce"},
]

## Language codes whose glyphs the default font does NOT cover.
const NEEDS_EXTENDED_GLYPHS: Array[String] = [
	"ar", "he", "fa", "ur", "zh", "ja", "ko", "hi", "th", "bn", "ta",
]

static var _installed := false


## The language in use, reduced to a code this build ships. TranslationServer
## reports full locales ("tr_TR", "en_GB"), so compare on the language part.
static func current() -> String:
	var language := TranslationServer.get_locale().split("_")[0].to_lower()
	for entry in SHIPPED:
		if str(entry["code"]) == language:
			return language
	return "en"


## Proper names that keep their own spelling when a heading is shouted, even in
## Turkish (G67). The i -> İ pass is right for Turkish words and wrong for a
## foreign name: Ellie is ELLIE, not ELLİE. Author's call, and the reason this
## is a list rather than one hard-coded name is that the next name will want the
## same treatment. Matched case-insensitively; written back in plain uppercase.
const KEEP_CASE: Array[String] = ["Ellie"]


## Uppercase, in the language actually being read (G67).
##
## Turkish does not share everyone else's case map: dotted i pairs with dotted
## İ, and dotless ı pairs with I. String.to_upper() knows neither pair, so every
## heading this game shouts came out wrong in Turkish — "TELSIZ ODASI" for
## Telsiz Odası, "HENÜZ DEĞIL" for Henüz değil, "ÇIZIMLERI" for çizimleri, which
## is the one that finally got noticed. Headings go through here instead.
static func upper(text: String) -> String:
	if current() != "tr":
		return text.to_upper()
	# The names come out of the Turkish pass untouched, so the pass cannot reach
	# inside them. Walked left to right rather than replaced in place, because a
	# placeholder would have to survive to_upper() to be put back.
	var out := ""
	var rest := text
	while rest != "":
		var at := -1
		var name := ""
		for candidate in KEEP_CASE:
			var where := rest.findn(candidate)
			if where >= 0 and (at < 0 or where < at):
				at = where
				name = candidate
		if at < 0:
			out += _upper_tr(rest)
			break
		out += _upper_tr(rest.substr(0, at)) + name.to_upper()
		rest = rest.substr(at + name.length())
	return out


static func _upper_tr(text: String) -> String:
	return text.replace("i", "İ").replace("ı", "I").to_upper()


## The self-name of `code`, for display.
static func name_of(code: String) -> String:
	for entry in SHIPPED:
		if str(entry["code"]) == code:
			return str(entry["name"])
	return code.to_upper()


## The next shipped language after the current one, wrapping. With two
## languages this is a toggle; with five it is still one predictable tap.
static func next_of(code: String) -> String:
	for i in SHIPPED.size():
		if str(SHIPPED[i]["code"]) == code:
			return str(SHIPPED[(i + 1) % SHIPPED.size()]["code"])
	return str(SHIPPED[0]["code"])


## Switch language and remember it. Labels already on screen do NOT retranslate
## themselves — every screen in this game builds its text in _ready and keeps
## it — so the caller is responsible for rebuilding whatever is visible.
static func select(code: String) -> void:
	TranslationServer.set_locale(code)
	GameState.set_setting("meta", "locale", code)
	apply()


## Reapply the player's saved choice. Called at startup, before the first
## screen builds its labels; does nothing when they never chose, which leaves
## the OS locale in charge exactly as before.
static func restore() -> void:
	var saved := str(GameState.get_setting("meta", "locale", ""))
	if saved == "":
		return
	for entry in SHIPPED:
		if str(entry["code"]) == saved:
			TranslationServer.set_locale(saved)
			return


## Called once from Hud._ready, before any label draws.
static func apply() -> void:
	if _installed:
		return
	_installed = true
	var font := _load_fallback()
	if font != null:
		_install(font)
		print("[Locale] yazi tipi geri donusu kuruldu: %s" % font.resource_path)
		return
	# Only complain when the ACTIVE language actually needs the extra glyphs;
	# an English-only build has nothing to warn about.
	if needs_extended_glyphs(TranslationServer.get_locale()):
		var message := "[Locale] '%s' icin genis glif seti gerekiyor ama %s yok - harfler kutu gorunecek" % [
			TranslationServer.get_locale(), FALLBACK_PATHS[0]]
		print(message)
		push_warning(message)


## True if `locale` needs glyphs the default theme font lacks.
static func needs_extended_glyphs(locale: String) -> bool:
	var language := locale.split("_")[0].split("-")[0].to_lower()
	return NEEDS_EXTENDED_GLYPHS.has(language)


## True if `locale` reads right to left, so the layout must mirror.
static func is_rtl(locale: String) -> bool:
	var language := locale.split("_")[0].split("-")[0].to_lower()
	return ["ar", "he", "fa", "ur"].has(language)


static func _load_fallback() -> Font:
	for path in FALLBACK_PATHS:
		if ResourceLoader.exists(path):
			var font := load(path) as Font
			if font != null:
				return font
	return null


## Appends to the theme's fallback font rather than replacing it, so the Latin
## look of the existing UI is unchanged and only missing glyphs come from the
## new file.
static func _install(font: Font) -> void:
	var base := ThemeDB.fallback_font
	if base == null:
		ThemeDB.fallback_font = font
		return
	var chain := base.duplicate() as Font
	var fallbacks := chain.fallbacks.duplicate()
	fallbacks.append(font)
	chain.fallbacks = fallbacks
	ThemeDB.fallback_font = chain
