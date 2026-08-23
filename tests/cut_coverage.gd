extends Node
## G6.12 regression: the CUT radius must cover what the mower visibly covers.
##
## The blade's chakram plate reaches BLADE_ARM_REACH (~1.02) but its deck was
## 0.55, so grass under the outer half of the visible disk was never cut — the
## mower looked like it drove straight over a patch and left it standing. Any
## mower whose deck is much smaller than its own footprint has the same defect,
## and a deck under 0.708 (half a cell diagonal) can additionally sit on a cell
## corner and reach no cell centre at all.

## World radius each type visibly covers, to compare against its cut radius.
const VISIBLE_REACH: Dictionary = {
	"push": 0.75, "tractor": 1.1, "robot": 0.7,
	"blade": GameConfig.BLADE_ARM_REACH * GameConfig.BLADE_SCALE,
}
## A deck may fall this far short of the visible footprint before it reads as a
## missed patch. The blade's horns are spikes, so it does not need all of it.
const REACH_TOLERANCE := 0.12
## Half a cell diagonal: below this a deck can straddle a corner and cut nothing.
const MIN_DECK := 0.7072

const FAIL_LIMIT := 0


func _ready() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var failures := 0
	for type_index in GameConfig.MOWER_TYPES.size():
		failures += await _check(game, type_index)
	if failures > FAIL_LIMIT:
		push_error("KAPSAMA TESTI BASARISIZ: %d arac bosluk birakti" % failures)
		print("--- KAPSAMA TESTI BASARISIZ ---")
	else:
		print("--- KAPSAMA TESTI GECTI ---")
	get_tree().quit()


## Two checks, both on the real configured values: the deck must cover a cell
## corner, and it must cover what the player sees the mower drive over.
func _check(game: Node, type_index: int) -> int:
	var model: LawnModel = game.model
	game.select_mower(type_index)
	var mower: MowerController = game.mower
	var id: String = GameConfig.MOWER_TYPES[type_index]["id"]
	var radius := mower.deck_radius()
	var reach: float = VISIBLE_REACH[id]

	var problems: Array[String] = []
	if radius < MIN_DECK:
		problems.append("kesme yaricapi %.3f < hucre kosesi %.3f" % [radius, MIN_DECK])
	if radius < reach - REACH_TOLERANCE:
		problems.append("gorunen %.2f, kesen %.2f" % [reach, radius])

	# And prove it on the lawn: sweep a straight line and count cells left
	# standing inside the VISIBLE footprint, which is what the player notices.
	var start := Vector3(-4.3, 0.0, -5.7)
	var finish := Vector3(4.3, 0.0, -5.7)
	mower.position = start
	mower._mow_valid = false
	var steps := int(start.distance_to(finish) / 0.35)
	for i in steps + 1:
		mower.position = start.lerp(finish, float(i) / float(steps))
		mower._mow(1.0 / 60.0)

	var a := Vector2(start.x, start.z)
	var b := Vector2(finish.x, finish.z)
	var missed := 0
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if not model.is_mowable(col, row):
				continue
			var cc := LawnModel.cell_center(col, row)
			var d := MowerController._segment_distance(Vector2(cc.x, cc.z), a, b)
			if d > reach - REACH_TOLERANCE:
				continue
			if not model.is_cut(col, row):
				missed += 1
	if missed > 0:
		problems.append("%d hucre gorunur ayak izi altinda bicilmedi" % missed)

	if problems.is_empty():
		print("  ok   %-8s kesen=%.2f gorunen=%.2f" % [id, radius, reach])
		return 0
	print("  HATA %-8s %s" % [id, ", ".join(problems)])
	return 1
