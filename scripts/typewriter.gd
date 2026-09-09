class_name Typewriter
extends RefCounted
## Words that arrive letter by letter (G37). The dialogue box has typed its
## lines since G6; the story cards showed theirs whole, so the game had two
## voices — one that spoke and one that appeared. This is the one machine both
## use now.
##
## The caller sets each label's text the way it always did and then hands the
## labels over: `play()` hides every character and reveals them again in
## order, one label finishing before the next begins. So a card's wording
## stays in the card and nothing is duplicated to be typed.
##
## It reveals with `visible_characters`, not by slicing `text`. Slicing
## re-wraps the label on every letter, so a line that will end up two rows
## tall starts one row tall and the whole block jumps the moment a word
## crosses the margin — on a bottom-aligned card that jump is the text
## sliding up under the reader. `VC_CHARS_AFTER_SHAPING` lays the full line
## out first and then draws a prefix of it, so nothing moves. It also means
## `label.text` always holds the whole line, which is what the rest of the
## game and its tests read.
##
## The host drives it from its own `_process` (`advance`), completes it on the
## first tap (`finish`), and asks whether to show its "tap to continue" hint
## (`typing`). Turned off in settings, `play()` simply leaves the text alone.

var _queue: Array[Dictionary] = []
var _at := 0
var _shown := 0.0
var _delay := 0.0


## `delay` holds the first letter back — a card applies its text under a black
## fade, and typing that nobody can see is typing that never happened.
func play(labels: Array, delay := 0.0) -> void:
	_queue.clear()
	_at = 0
	_shown = 0.0
	_delay = delay
	for any: Variant in labels:
		var label := any as Label
		# An empty label is not a line: the gate's last page blanks its prose
		# to make room for the two choices.
		if label == null or not is_instance_valid(label) or label.text == "":
			continue
		label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		_queue.append({"label": label, "full": label.text})
	if GameConfig.text_instant:
		finish()
		return
	for entry: Dictionary in _queue:
		(entry["label"] as Label).visible_characters = 0


func typing() -> bool:
	return _at < _queue.size()


func advance(delta: float) -> void:
	if not typing():
		return
	if _delay > 0.0:
		_delay -= delta
		if _delay > 0.0:
			return
		# The step that ends the delay keeps whatever is left of it, or a card
		# loses one whole frame of typing to the changeover.
		delta = -_delay
		_delay = 0.0
	var entry: Dictionary = _queue[_at]
	# is_instance_valid on the raw value, BEFORE the cast: `as Label` on an
	# object that has already been freed is itself the error (G56 — a coach
	# note whose page is closed mid-sentence takes its label with it).
	var label := _label_of(entry)
	if label == null:
		_at += 1
		_shown = 0.0
		return
	var full := str(entry["full"])
	_shown += GameConfig.TEXT_CPS * delta
	# visible_characters counts CHARACTERS, not bytes, so "ğ" and "ş" arrive
	# whole rather than as half a letter.
	var count := mini(int(_shown), full.length())
	label.visible_characters = count
	if count >= full.length():
		label.visible_characters = -1
		_at += 1
		_shown = 0.0


## Forget the queue: the host is taking its labels away rather than reading
## them out. finish() would write to nodes on their way out of the tree.
func stop() -> void:
	_queue.clear()
	_at = 0
	_shown = 0.0
	_delay = 0.0


## Every line at once: the first tap on a card, or a player who reads faster
## than any machine types.
func finish() -> void:
	for entry: Dictionary in _queue:
		var label := _label_of(entry)
		if label != null:
			label.visible_characters = -1
	_at = _queue.size()
	_shown = 0.0
	_delay = 0.0


## The entry's label, or null if it has since been freed.
func _label_of(entry: Dictionary) -> Label:
	var any: Variant = entry.get("label")
	if any == null or not is_instance_valid(any):
		return null
	return any as Label
