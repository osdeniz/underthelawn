class_name RobotMower
extends MowerController
## Robot input — REFERENCE.md §7 "Robot": autonomous boustrophedon with two
## player overrides.
##
## Route: row by row serpentine (even rows west to east, odd rows east to west),
## one waypoint per mowable cell. A blocked cell is replaced by a detour
## waypoint on the nearest open row in the same column, so the robot walks
## around the pool, the flowerbed and the stone.
##
## Overrides: tapping the ground sends it there, and a swipe of 60 pt or more
## nudges it 3.5 units in the swiped (camera-relative) direction. Either way it
## rejoins the pattern at the nearest pending waypoint.

var route: Array[Vector2i] = []
var route_index := 0

var _override: Vector3 = Vector3.ZERO
var _has_override := false
var _touch_index := -1
var _touch_origin := Vector2.ZERO

var _led_material: StandardMaterial3D
var _led_time := 0.0


func type_index() -> int:
	return GameConfig.MOWER_ROBOT


func _ready() -> void:
	super()
	var led := get_node_or_null("Body/Led") as MeshInstance3D
	if led:
		_led_material = led.material_override as StandardMaterial3D


## Entering robot mode plans the route from the CURRENT lawn state; leaving it
## throws the route away.
func _on_active_changed(value: bool) -> void:
	_touch_index = -1
	_has_override = false
	if value:
		plan_route()
	else:
		route.clear()
		route_index = 0


func _on_reset() -> void:
	_has_override = false
	if is_active:
		plan_route()


# ---------------------------------------------------------------- route (§7)

## Planned from the CURRENT lawn state; see MowerMath.build_robot_route.
func plan_route() -> void:
	route = MowerMath.build_robot_route(model)
	route_index = 0


## Skips waypoints whose cell is already mown and returns the active target,
## or null-ish (has_target=false) when the lawn is finished.
func _current_target() -> Vector3:
	while route_index < route.size():
		var cell := route[route_index]
		if model.is_cut(cell.x, cell.y):
			route_index += 1
			continue
		return LawnModel.cell_center(cell.x, cell.y)
	# Route exhausted: head for the nearest cell still standing.
	var nearest := _nearest_pending()
	if nearest.x < 0:
		return Vector3.INF
	return LawnModel.cell_center(nearest.x, nearest.y)


func _nearest_pending() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := INF
	var here := Vector2(position.x, position.z)
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if not model.is_mowable(col, row) or model.is_cut(col, row):
				continue
			var cc := LawnModel.cell_center(col, row)
			var d := Vector2(cc.x, cc.z).distance_squared_to(here)
			if d < best_distance:
				best_distance = d
				best = Vector2i(col, row)
	return best


# ---------------------------------------------------------------- driving

func _gather_input(_delta: float) -> void:
	if model == null:
		throttle = 0.0
		desired_omega = 0.0
		return

	# G6.7 pace fix: arriving at a waypoint used to zero the throttle, so the
	# 0.4 s acceleration ramp restarted at EVERY cell and the robot averaged
	# ~0.8 u/s instead of its 2.1. Now arrival only advances the cursor and the
	# next target is picked in the SAME tick, so it flows through the route.
	var target := Vector3.INF
	for _guard in 8:
		target = _override if _has_override else _current_target()
		if target == Vector3.INF:
			break
		var reach := Vector2(target.x - position.x, target.z - position.z)
		if reach.length() > GameConfig.ROBOT_ARRIVE_DISTANCE:
			break
		if _has_override:
			# Reached the player's point: rejoin the pattern nearby.
			_has_override = false
			_rejoin_nearest()
		else:
			route_index += 1
		target = Vector3.INF

	if target == Vector3.INF:
		# Nothing in reach this tick (route finished, or several waypoints
		# consumed at once): coast rather than braking hard.
		desired_omega = 0.0
		if not _has_pending():
			throttle = 0.0
		return

	var to_target := Vector2(target.x - position.x, target.z - position.z)
	steer_towards(atan2(to_target.x, -to_target.y))
	throttle = 1.0


## Is there anything left to mow at all? Used to decide between coasting and
## stopping when a tick consumes several waypoints.
func _has_pending() -> bool:
	return _nearest_pending().x >= 0


## Jump the route cursor to the waypoint closest to where we are now.
func _rejoin_nearest() -> void:
	var best := -1
	var best_distance := INF
	var here := Vector2(position.x, position.z)
	for i in route.size():
		var cell := route[i]
		if model.is_cut(cell.x, cell.y):
			continue
		var cc := LawnModel.cell_center(cell.x, cell.y)
		var d := Vector2(cc.x, cc.z).distance_squared_to(here)
		if d < best_distance:
			best_distance = d
			best = i
	if best >= 0:
		route_index = best


# ---------------------------------------------------------------- overrides

func on_touch_pressed(index: int, screen_pos: Vector2) -> void:
	if _touch_index != -1:
		return
	_touch_index = index
	_touch_origin = screen_pos


func on_touch_released(index: int, screen_pos: Vector2) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	var swipe := screen_pos - _touch_origin
	if swipe.length() >= GameConfig.ROBOT_SWIPE_THRESHOLD_PT * GameConfig.POINT_SCALE:
		_nudge(swipe)
	else:
		_go_to(screen_pos)
	Haptics.light()


## Ground tap: drive to that point, clipped inside the lawn (§7).
func _go_to(screen_pos: Vector2) -> void:
	_override = ground_point(screen_pos)
	_has_override = true


## Swipe nudge: the screen direction becomes a world heading through the camera
## yaw (§18 trap 2), then 3.5 units that way.
func _nudge(swipe: Vector2) -> void:
	var heading := camera_yaw + atan2(swipe.x, -swipe.y)
	var dir := Vector3(sin(heading), 0.0, -cos(heading))
	_override = clamp_to_lawn(position + dir * GameConfig.ROBOT_NUDGE_DISTANCE)
	_has_override = true


# ---------------------------------------------------------------- feel

## No engine, so no idle shudder; the LED breathes instead (§6).
func _idle_shake(_delta: float) -> void:
	pass


func _process(delta: float) -> void:
	if _led_material == null:
		return
	_led_time += delta
	var breath := sin(_led_time * TAU / GameConfig.ROBOT_LED_PERIOD) * 0.5 + 0.5
	_led_material.emission_energy_multiplier = lerpf(0.35, 2.2, breath)
