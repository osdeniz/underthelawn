extends Node
## G13: the diorama slice, and the promise that legacy still works.
##
## The point of the slice is that it can be REJECTED, so the legacy hub has to
## stay wired. That is the first thing this checks.

var _fails := 0


func _ready() -> void:
	await _check_scene()
	await _check_legacy()
	await _check_diorama_hub()
	await _check_transition()
	await _check_purchase_screen()

	if _fails > 0:
		push_error("%d DIYORAMA TESTI BASARISIZ" % _fails)
		print("--- %d DIYORAMA TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM DIYORAMA TESTLERI GECTI ---")
	get_tree().quit()


func _check_scene() -> void:
	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame

	ck("uc bina da sahnede", GameConfig.DIORAMA_BUILDINGS.size() == 3,
		str(GameConfig.DIORAMA_BUILDINGS.size()))
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		ck("bina var: %s" % id, town.has_building(id), "")
		# Every restorable project in the slice must exist in projects.json, or
		# the building could never be bought.
		ck("proje tanimli: %s" % id, not RestoreBoard.of(id).is_empty(), "")

	# Ruined and restored are mutually exclusive, always.
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		town.set_built(id, false, false)
		var pair := _forms(town, id)
		ck("%s yikik halde" % id,
			pair[0].visible and not pair[1].visible, "")
		town.set_built(id, true, false)
		ck("%s onarilmis halde" % id,
			pair[1].visible and not pair[0].visible, "")
		# Parts must be at rest, not left in the air by a skipped transition.
		var adrift := 0
		for child in pair[1].get_children():
			var node := child as Node3D
			if node != null and node.has_meta(TownDiorama.PART_META) \
					and node.position.distance_to(node.get_meta(TownDiorama.PART_META)) > 0.01:
				adrift += 1
		ck("%s parcalari yerinde" % id, adrift == 0, "%d parca havada" % adrift)

	# Everything has to stand ON the plate, or the model has bits off its edge.
	var half := GameConfig.DIORAMA_PLATE * 0.5
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		var at: Vector3 = GameConfig.DIORAMA_BUILDINGS[id]["pos"]
		ck("%s plaka icinde" % id,
			absf(at.x) < half.x - 2.0 and absf(at.z) < half.y - 2.0,
			"%v vs %v" % [at, half])
	town.queue_free()
	await get_tree().process_frame


## Legacy mode must build a hub with NO diorama in it, and must not error.
func _check_legacy() -> void:
	var before := GameConfig.hub_mode
	GameConfig.hub_mode = GameConfig.HUB_MODE_LEGACY
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	# Search for the diorama itself, NOT for SubViewports: the hub is already
	# full of them (every evidence card is an ItemPreview).
	ck("legacy modda diyorama yok",
		hub.find_children("*", "TownDiorama", true, false).is_empty(), "")
	ck("legacy modda kolaj arkaplani var", _has_texture_rect(hub), "")
	# set_diorama_active must be safe to call in legacy mode: root calls it on
	# every hub entry and exit without knowing which mode is on.
	hub.set_diorama_active(false)
	hub.set_diorama_active(true)
	hub.queue_free()
	await get_tree().process_frame
	GameConfig.hub_mode = before


func _check_diorama_hub() -> void:
	GameConfig.hub_mode = GameConfig.HUB_MODE_DIORAMA
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	var towns := hub.find_children("*", "TownDiorama", true, false)
	ck("diyorama modda canli sahne var", towns.size() == 1, "%d" % towns.size())
	if towns.size() == 1:
		var view := (towns[0] as Node).get_parent() as SubViewport
		ck("kendi dunyasinda", view.own_world_3d, "")
		hub.set_diorama_active(false)
		ck("bolume girerken cizim duruyor",
			view.render_target_update_mode == SubViewport.UPDATE_DISABLED,
			str(view.render_target_update_mode))
		hub.set_diorama_active(true)
		ck("hub'a donunce cizim basliyor",
			view.render_target_update_mode != SubViewport.UPDATE_DISABLED, "")
	hub.queue_free()
	await get_tree().process_frame


## The transition has to leave the building standing even when it is skipped
## partway - a half-built town is the one outcome that must not happen.
func _check_transition() -> void:
	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	town.set_built("station", false, false)
	town.play_restore.call("station")
	await get_tree().create_timer(0.8).timeout
	town.skip()
	await get_tree().create_timer(0.5).timeout
	var pair := _forms(town, "station")
	ck("atlandiginda bina ayakta", pair[1].visible and not pair[0].visible, "")
	var adrift := 0
	for child in pair[1].get_children():
		var node := child as Node3D
		if node != null and node.has_meta(TownDiorama.PART_META) \
				and node.position.distance_to(node.get_meta(TownDiorama.PART_META)) > 0.01:
			adrift += 1
	ck("atlandiginda parcalar yerinde", adrift == 0, "%d parca havada" % adrift)
	ck("kamera hub cercevesine dondu",
		absf(town.camera.v_offset - GameConfig.DIORAMA_V_OFFSET) < 0.2,
		"%.2f" % town.camera.v_offset)
	town.queue_free()
	await get_tree().process_frame


## Buying a project must hand the screen back afterwards.
##
## It did not: _apply_restore_layers queue_frees the hub's Restore_* badges the
## moment a project is bought, those nodes were still in the "pages to fade
## back in" list, and by the time the 4-second animation ended they were gone.
## The cast threw, the full-screen skip button was never freed, and every touch
## after that landed on an invisible button - the hub looked frozen.
func _check_purchase_screen() -> void:
	GameConfig.hub_mode = GameConfig.HUB_MODE_DIORAMA
	RestoreBoard.reset()
	GameState.set_setting("economy", "scrap", 90000)
	# station is tier 2, so tier 1 has to be open first.
	for opener: String in ["swing", "lantern", "greenhouse"]:
		RestoreBoard.buy(opener)
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	hub._on_tile("restore", false)
	await get_tree().process_frame

	# Buy a building that IS in the diorama, so the transition runs.
	hub._on_project("station", false, null)
	await get_tree().process_frame
	# THE FAILURE: a node that was on screen when the transition started is gone
	# before it ends. _apply_restore_layers queue_frees the Restore_* badges the
	# instant a project is bought, and queue_free lands a frame later - long
	# before a four-second animation is over.
	for child in hub.get_children():
		var doomed := child as Control
		if doomed != null and doomed.visible and doomed is ColorRect:
			doomed.queue_free()
			break
	# Long enough for the whole transition plus its tail.
	await get_tree().create_timer(6.5).timeout

	var blockers := 0
	var faded := 0
	for child in hub.get_children():
		var control := child as Control
		if control == null or not is_instance_valid(control):
			continue
		# The skip button covers the screen and is flat, so it is invisible: if
		# one survives, the hub is unusable even though it looks fine.
		if control is Button and control.size.x >= hub.size.x - 1.0:
			blockers += 1
		if control.visible and control.modulate.a < 0.99:
			faded += 1
	ck("satin alma sonrasi ekrani kapatan buton kalmadi", blockers == 0,
		"%d buton" % blockers)
	ck("satin alma sonrasi sayfalar geri geldi", faded == 0,
		"%d sayfa soluk kaldi" % faded)
	ck("bina onarilmis sayiliyor", RestoreBoard.is_built("station"), "")
	hub.queue_free()
	await get_tree().process_frame
	RestoreBoard.reset()


func _forms(town: TownDiorama, id: String) -> Array:
	var plot := town.get_node_or_null(NodePath(id.capitalize()))
	return [plot.get_node("Ruined"), plot.get_node("Restored")]


func _has_texture_rect(node: Node) -> bool:
	return not node.find_children("*", "TextureRect", true, false).is_empty()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
