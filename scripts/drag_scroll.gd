class_name DragScroll
extends Node
## Drag anywhere on the page to scroll it (G53).
##
## Godot's ScrollContainer scrolls a touch drag by itself, but only one that
## starts on the container and is not swallowed by a child; and with a mouse it
## does not scroll at all — the wheel does. On a phone-first game whose rows are
## all buttons, that adds up to pages the player cannot move: the settings list
## ran off the bottom of the screen with no way to reach the language row.
##
## This listens on `_unhandled_input`, which is where a drag ends up after
## every button has declined it (a button consumes presses, not motion), so a
## drag started anywhere over the page scrolls it — including over a row.

const WHEEL_STEP := 90


var _scroll: ScrollContainer
var _dragging := false


static func attach(host: Node, scroll: ScrollContainer) -> DragScroll:
	if host == null or scroll == null:
		return null
	var node := DragScroll.new()
	node.name = "DragScroll"
	node._scroll = scroll
	# Touch drags that DO reach the container should still work the way Godot
	# means them to; the deadzone keeps a tap on a row from scrolling it.
	scroll.scroll_deadzone = 12
	host.add_child(node)
	return node


func _unhandled_input(event: InputEvent) -> void:
	if _scroll == null or not is_instance_valid(_scroll) \
			or not _scroll.is_visible_in_tree():
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		_by(drag.relative.y)
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_by(motion.relative.y)


func _by(amount: float) -> void:
	if is_zero_approx(amount):
		return
	_scroll.scroll_vertical -= int(amount)
	get_viewport().set_input_as_handled()
