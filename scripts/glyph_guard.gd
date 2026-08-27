class_name GlyphGuard
extends RefCounted
## Keeps colour-emoji codepoints out of every string that becomes UI text.
##
## WHY THIS EXISTS (G16 performance audit). Godot resolves a glyph the theme
## font lacks by asking the OS for a font that has it. For one emoji character
## that answer is Apple Color Emoji, and loading it costs **184 MB of RAM** —
## measured, on one Label, with the node still invisible. It is a one-time cost
## shared by every emoji in the build, so a single 🔊 left in a .tscn was paying
## the whole bill: it was 20% of the app's 939 MB footprint.
##
## The game already knew emoji were a dead end on the phone — iOS renders them
## as a blank box, which is why UiIcons draws the wallet and the clipboard
## instead (G12.10). So nothing visible is lost here: these characters were
## already invisible on device. Only the 184 MB goes.
##
## Call safe() at the boundary where data becomes text. Data files keep their
## emoji: they read well in a diff, and stripping at the edge means a new icon
## added to levels.json can never re-introduce the cost.

## Variation Selector-16: the character that turns ⚙ into ⚙️, and a plain glyph
## request into a colour-font request. Stripping it alone saves the 184 MB.
const VARIATION_SELECTOR_16 := 0xFE0F
const ZERO_WIDTH_JOINER := 0x200D
## Everything from U+1F000 up is emoji, pictographs and their modifiers. The
## BMP symbols below it (✓, →, ⚙) resolve to an ordinary system face that costs
## about 3 MB, so they are deliberately left alone.
const ASTRAL_EMOJI_START := 0x1F000


## `text` with every colour-emoji codepoint removed, and the whitespace the
## removal leaves behind tidied up.
static func safe(text: String) -> String:
	if text.is_empty():
		return text
	var out := ""
	var changed := false
	for i in text.length():
		var c := text.unicode_at(i)
		if c == VARIATION_SELECTOR_16 or c == ZERO_WIDTH_JOINER \
				or c >= ASTRAL_EMOJI_START:
			changed = true
			continue
		out += text[i]
	if not changed:
		return text
	# "🧸  Ellie's Toy" would otherwise start with the two spaces that separated
	# it from the icon.
	return out.strip_edges()


## True if `text` carries a codepoint that would pull in the colour-emoji font.
## Used by the guard test, so a future .tscn cannot quietly bring the cost back.
static func costly(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c == VARIATION_SELECTOR_16 or c == ZERO_WIDTH_JOINER \
				or c >= ASTRAL_EMOJI_START:
			return true
	return false
