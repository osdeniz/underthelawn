class_name PressFeel
extends RefCounted
## Every button in the game answers a finger (G41).
##
## Haptics already fired on presses, so a phone buzzed while the screen sat
## perfectly still — nothing moved, dimmed or gave, which on a touch screen is
## the only way a control can say "I felt that". Buttons now sink slightly
## under the finger and come back when it lifts.
##
## Installed ONCE, on the tree's `node_added`, rather than at forty button
## factories: the hub, the map, the workshop, the cards and the panel all make
## their own buttons, several of them lazily, and a helper called by hand at
## each site is a helper that is missed at the forty-first. `BaseButton` covers
## Button, TextureButton and CheckButton, so the postcard thumbnails get it too.
##
## `scale` is a visual property on a Control: nothing about layout, hit areas
## or the container's arithmetic changes.

const SCALE := 0.965
const DOWN_TIME := 0.06
const UP_TIME := 0.12
const META := "press_feel"
const TWEEN_META := "press_feel_tween"


## Hooks the tree so every button ever added gets the behaviour.
static func install(tree: SceneTree) -> void:
	if tree == null or tree.node_added.is_connected(consider):
		return
	tree.node_added.connect(consider)


static func consider(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		apply(button)


static func apply(button: BaseButton) -> void:
	if button == null or button.has_meta(META):
		return
	button.set_meta(META, true)
	button.button_down.connect(func() -> void: press(button, true))
	button.button_up.connect(func() -> void: press(button, false))


static func press(button: BaseButton, down: bool) -> void:
	if button == null or not is_instance_valid(button) or not button.is_inside_tree():
		return
	if GameConfig.reduced_motion:
		return
	# The old tween is killed rather than left to fight the new one: a player
	# drumming on a tile would otherwise stack them and the scale would drift.
	var running: Variant = button.get_meta(TWEEN_META, null)
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	# Set on the press, not at build time: a Control's size is not known until
	# its container has laid it out, and a zero pivot scales from the corner,
	# which reads as a shift rather than a press.
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	# The pause sheet's own buttons must still answer a finger.
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "scale",
		Vector2.ONE * (SCALE if down else 1.0),
		DOWN_TIME if down else UP_TIME).set_trans(Tween.TRANS_SINE)
	button.set_meta(TWEEN_META, tween)
