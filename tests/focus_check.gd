extends TestBase
## Menus without a touch screen (G43): the first key press opens a focus ring,
## the arrows move it, ui_accept presses what it is on, and the first touch
## puts everything back exactly as it was.

func run() -> void:
	suite = "ODAK"
	var focus := KeyboardFocus.install(self)
	await frames(2)
	ck("odak katmani kurulur", focus != null, "")
	ck("iki kez kurulmaz", KeyboardFocus.install(self) == focus, "")
	ck("basta klavye kipi kapali", not focus.keyboard_mode(), "")

	# A screen whose buttons are deliberately unfocusable, as the game's are.
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var pressed := [0]
	var rows: Array[Button] = []
	for i in 3:
		var row := Button.new()
		row.text = "Satir %d" % i
		row.custom_minimum_size = Vector2(400, 110)
		row.focus_mode = Control.FOCUS_NONE
		row.pressed.connect(func() -> void: pressed[0] += 1)
		page.add_child(row)
		rows.append(row)
	await frames(3)
	ck("dokunmatik icin dugmeler odaklanamaz",
		rows[0].focus_mode == Control.FOCUS_NONE, "")

	# A key press opens the mode.
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	focus._input(key)
	await frames(3)
	ck("tusa basinca klavye kipi acilir", focus.keyboard_mode(), "")
	ck("kipte dugmeler odaklanabilir", rows[0].focus_mode == Control.FOCUS_ALL, "")
	ck("odak ilk satirda", rows[0].has_focus(), "")
	ck("halka gorunur", focus._ring.visible, "")
	var ring_at := focus._ring.position
	ck("halka odagi sariyor",
		focus._ring.size.x > rows[0].size.x and focus._ring.size.y > rows[0].size.y,
		"%s / %s" % [focus._ring.size, rows[0].size])

	# The arrows move it, and accept presses what it is on.
	rows[1].grab_focus()
	await frames(2)
	ck("halka odagi takip eder", focus._ring.position != ring_at,
		"%s -> %s" % [ring_at, focus._ring.position])
	rows[1].pressed.emit()
	ck("odaktaki dugme basilabilir", pressed[0] == 1, str(pressed[0]))

	# A touch closes it and leaves no trace.
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	focus._input(touch)
	await frames(2)
	ck("dokunusla kip kapanir", not focus.keyboard_mode(), "")
	ck("halka gizlenir", not focus._ring.visible, "")
	ck("dugmeler eski haline doner",
		rows[0].focus_mode == Control.FOCUS_NONE
		and rows[1].focus_mode == Control.FOCUS_NONE, "")
	ck("odak birakildi", get_viewport().gui_get_focus_owner() == null, "")

	# The screen changing under the focus does not leave the ring behind.
	focus._input(key)
	await frames(3)
	ck("kip yeniden acilir", focus.keyboard_mode() and focus._ring.visible, "")
	page.visible = false
	await frames(4)
	ck("ekran degisince halka bosluga bakmaz",
		not focus._ring.visible or get_viewport().gui_get_focus_owner() != null, "")
	focus.set_keyboard_mode(false)
	page.queue_free()
	await frames(2)
	finish()
