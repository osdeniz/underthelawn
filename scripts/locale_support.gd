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
## Locale itself is never forced here: Godot picks the OS locale and falls back
## to `en`, which is the correct behaviour on a phone.

## Checked in order; the first that exists is installed. A single font with wide
## coverage (Noto Sans is the usual answer) is enough for all of these.
const FALLBACK_PATHS: Array[String] = [
	"res://fonts/i18n_fallback.ttf",
	"res://fonts/i18n_fallback.otf",
	"res://fonts/i18n_fallback.ttc",
]

## Language codes whose glyphs the default font does NOT cover.
const NEEDS_EXTENDED_GLYPHS: Array[String] = [
	"ar", "he", "fa", "ur", "zh", "ja", "ko", "hi", "th", "bn", "ta",
]

static var _installed := false


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
