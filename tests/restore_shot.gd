extends Node
## G13: the restore transition, captured at named moments. Saving from inside
## the scene beats --write-movie here: the movie's frame numbering did not line
## up with the animation's own clock, which made it easy to read the wrong frame.

func _ready() -> void:
	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	var id := OS.get_environment("UTL_PROJECT")
	if id == "":
		id = "station"
	for other: String in GameConfig.DIORAMA_BUILDINGS:
		town.set_built(other, false, false)
	for _i in 4:
		await get_tree().process_frame

	await _shoot("00_ruined")
	# The transition runs alongside; the capture list owns the clock, so a
	# transition that ends early cannot cut the last frames off.
	town.play_restore.call(id)
	await _capture()
	await _shoot("05_done")
	get_tree().quit()


## Saves a frame at each stage while the transition runs alongside.
func _capture() -> void:
	await get_tree().create_timer(0.9).timeout
	await _shoot("01_zoomed")
	await get_tree().create_timer(0.5).timeout
	await _shoot("02_collapsed")
	await get_tree().create_timer(0.7).timeout
	await _shoot("03_rising")
	await get_tree().create_timer(0.9).timeout
	await _shoot("04_landed")
	await get_tree().create_timer(1.6).timeout


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://out/g13_%s.png" % label)
