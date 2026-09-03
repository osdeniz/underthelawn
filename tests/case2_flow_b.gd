## Case2Flow, second half (G16.5). The whole flow took over two minutes in one
## process, which is past any sane limiter; the first half (gate, board,
## chapter, map) stays in case2_flow.gd and this runs the rest. Same code, same
## helpers, two verdicts.
extends "res://tests/case2_flow.gd"


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("story", "intro_seen", true)
	ChapterProgress.reset()
	RestoreBoard.reset()
	GameState.set_setting("story", "case01_closed", false)
	GameState.set_setting("story", "case02_closed", false)

	await _check_warm_up_leaves_no_trace()
	await _check_the_door()
	await _check_panel_clears_back()
	await _check_warm_up_survives_a_road_chapter()
	await _check_board_is_built_late()
	await _check_every_way_home_unparks_the_town()
	if _fails > 0:
		push_error("%d VAKA 02 AKIS TESTI BASARISIZ" % _fails)
		print("--- %d VAKA 02 AKIS TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM VAKA 02 AKIS (B) TESTLERI GECTI ---")
	get_tree().quit()
