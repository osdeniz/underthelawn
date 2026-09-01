extends Node
## G14.6: the town shows what has been rebuilt, without a counter.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	RestoreBoard.reset()
	SkyTime.set_mode(GameConfig.SKY_MODE_NIGHT)
	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	for _i in 20:
		await get_tree().process_frame

	var life := town.get_node_or_null("TownLife")
	ck("hayat belirtileri kuruldu", life != null, "")
	if life == null:
		_finish()
		return

	# Nothing rebuilt: no smoke, no windows. A ruin must never look lived in.
	var smoking := _smoking(life)
	ck("yikik kasaba tutmuyor", smoking == 0, "%d baca" % smoking)
	var windows := life.get_node_or_null("Windows") as MeshInstance3D
	ck("yikik kasabada isik yok",
		windows == null or not windows.visible or windows.mesh == null, "")

	# Rebuild two of them and the town says so by itself.
	for id: String in ["homes", "station"]:
		GameState.set_setting("restore", id, true)
		town.set_built(id, true, false)
	for _i in 6:
		await get_tree().process_frame
	ck("onarilan ev tutuyor", _smoking(life) == 2, "%d baca" % _smoking(life))
	windows = life.get_node_or_null("Windows") as MeshInstance3D
	ck("gece pencereler yaniyor",
		windows != null and windows.visible and windows.mesh != null, "")
	# Every window in the town is ONE mesh, whatever the count.
	if windows != null and windows.mesh != null:
		ck("pencereler tek mesh", windows.mesh.get_surface_count() == 1,
			str(windows.mesh.get_surface_count()))

	# Daylight puts them out again, but leaves the chimneys alight.
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	town.apply_sky_mode()
	for _i in 4:
		await get_tree().process_frame
	windows = life.get_node_or_null("Windows") as MeshInstance3D
	ck("gunduz pencereler sonuk",
		windows == null or not windows.visible, "")
	ck("gunduz bacalar yanmaya devam", _smoking(life) == 2,
		"%d baca" % _smoking(life))

	# The far silhouettes follow the same hour.
	SkyTime.set_mode(GameConfig.SKY_MODE_NIGHT)
	town.apply_sky_mode()
	for _i in 4:
		await get_tree().process_frame
	var far := town.find_children("FarWindows", "", true, false)
	ck("uzak evler de yaniyor",
		far.size() == 1 and (far[0] as MeshInstance3D).visible,
		"%d dugum" % far.size())

	# Back to Story: the town must return to the light it was BUILT with, not
	# stay lit by whatever was chosen last.
	var env: Environment = (town.get_node("DioramaEnvironment") as WorldEnvironment).environment
	var night_ambient := env.ambient_light_color
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	town.apply_sky_mode()
	for _i in 4:
		await get_tree().process_frame
	ck("hikaye moduna donunce isik geri geliyor",
		env.ambient_light_color != night_ambient
		and env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY,
		str(env.ambient_light_color))

	town.queue_free()
	_finish()


func _smoking(life: Node) -> int:
	var count := 0
	for child in life.get_children():
		var puff := child as GPUParticles3D
		if puff != null and puff.emitting:
			count += 1
	return count


func _finish() -> void:
	RestoreBoard.reset()
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	if _fails > 0:
		push_error("%d KASABA HAYATI TESTI BASARISIZ" % _fails)
		print("--- %d KASABA HAYATI TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM KASABA HAYATI TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
