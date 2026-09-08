class_name KeyboardFocus
extends CanvasLayer
## Menus reachable without a touch screen (G43).
##
## Driving has been on the keyboard and the pad since §7, but the menus were
## touch-only: nearly every button in the game is built with
## `focus_mode = FOCUS_NONE` or with its focus box overridden away, because a
## focus ring that appears under a thumb looks like a bug. So a keyboard could
## start the game and then not press a single button in it, and a pad could
## mow a lawn and not open the hub.
##
## Two ideas make it work without touching forty button factories:
##
## 1. **A mode, not a state.** The first key or pad press turns keyboard mode
##    on; the first touch or click turns it off again. Only in keyboard mode
##    do buttons become focusable, so a phone never shows a ring.
## 2. **One ring, drawn over the top.** Rather than restyling every button's
##    focus box — several of them deliberately empty — a single panel on its
##    own layer follows whatever holds focus. Nothing about any button's look
##    changes, and leaving the mode leaves no trace.

const RING_LAYER := 90
const RING_PAD := 6.0
const WAS_NONE := "focus_was_none"

var _keyboard := false
var _ring: Panel


static func install(root: Node) -> KeyboardFocus:
	if root == null:
		return null
	var existing := root.get_node_or_null("KeyboardFocus") as KeyboardFocus
	if existing != null:
		return existing
	var node := KeyboardFocus.new()
	node.name = "KeyboardFocus"
	root.add_child(node)
	return node


func _ready() -> void:
	layer = RING_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ring = Panel.new()
	_ring.name = "FocusRing"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	_ring.add_theme_stylebox_override("panel", style)
	add_child(_ring)


func keyboard_mode() -> bool:
	return _keyboard


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventJoypadMotion:
		# Movement keys drive the mower too; that is fine, the mode only adds
		# a way to reach buttons and never takes input away from anything.
		if not _keyboard:
			set_keyboard_mode(true)
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		if _keyboard:
			set_keyboard_mode(false)


func set_keyboard_mode(on: bool) -> void:
	if on == _keyboard:
		return
	_keyboard = on
	if on:
		_open_focus()
	else:
		_close_focus()


## Makes every visible button focusable, remembering the ones that were not so
## the mode can be left exactly as it was found, then puts focus on the first.
func _open_focus() -> void:
	var buttons := _visible_buttons()
	for button in buttons:
		if button.focus_mode == Control.FOCUS_NONE:
			button.set_meta(WAS_NONE, true)
			button.focus_mode = Control.FOCUS_ALL
	if buttons.is_empty():
		return
	var held := get_viewport().gui_get_focus_owner()
	if held == null or not held.is_visible_in_tree():
		buttons[0].grab_focus()


func _close_focus() -> void:
	for button in _visible_buttons():
		if button.has_meta(WAS_NONE):
			button.remove_meta(WAS_NONE)
			button.focus_mode = Control.FOCUS_NONE
	var held := get_viewport().gui_get_focus_owner()
	if held != null:
		held.release_focus()
	_ring.visible = false


## Every button a player can actually see, in tree order — which is the order
## the eye reads them in, and the order Godot's own focus arrows follow.
func _visible_buttons() -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	_collect(get_tree().root, out)
	return out


func _collect(node: Node, into: Array[BaseButton]) -> void:
	var button := node as BaseButton
	if button != null and button.is_visible_in_tree() and not button.disabled:
		into.append(button)
	for child in node.get_children():
		_collect(child, into)


func _process(_delta: float) -> void:
	if not _keyboard:
		return
	var held := get_viewport().gui_get_focus_owner()
	if held == null or not held.is_visible_in_tree():
		# The screen changed under the focus — a page turned, a card closed.
		# Rather than leave the ring pointing at nothing, take the first
		# button of whatever is there now.
		_ring.visible = false
		var buttons := _visible_buttons()
		if not buttons.is_empty():
			for button in buttons:
				if button.focus_mode == Control.FOCUS_NONE:
					button.set_meta(WAS_NONE, true)
					button.focus_mode = Control.FOCUS_ALL
			buttons[0].grab_focus()
		return
	var rect := held.get_global_rect()
	_ring.position = rect.position - Vector2(RING_PAD, RING_PAD)
	_ring.size = rect.size + Vector2(RING_PAD, RING_PAD) * 2.0
	_ring.visible = true
