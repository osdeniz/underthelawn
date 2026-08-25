extends Control
## G12.10: the hub wallet chip and the workshop's priced buttons, both of which
## used to carry a banknote emoji.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame

