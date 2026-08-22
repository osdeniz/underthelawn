class_name MowerMath
extends RefCounted
## Pure mower logic with no scene or autoload dependencies, so it can be unit
## tested directly: the tractor's input mapping (§7) and the robot's
## boustrophedon route planner (§7).


## §7 tractor rules. Returns (throttle, desiredOmega). Reverse runs at `reverse`
## speed and flips the steering sign, the way backing up a real vehicle behaves.
static func tractor_input(stick: Vector2, turn_limit: float, reverse: float,
		current_speed: float) -> Vector2:
	var throttle := stick.y if stick.y >= 0.0 else stick.y * reverse
	var steer_sign := -1.0 if current_speed < -0.01 else 1.0
	return Vector2(throttle, stick.x * turn_limit * steer_sign)


## Row-by-row serpentine: even rows west to east, odd rows east to west, one
## waypoint per mowable cell. A blocked cell is replaced by a detour waypoint on
## the nearest open row in the same column, so the robot walks around the pool,
## the flowerbed and the stone rather than into them (§7).
static func build_robot_route(model: LawnModel) -> Array[Vector2i]:
	var route: Array[Vector2i] = []
	if model == null:
		return route
	for row in GameConfig.GRID_ROWS:
		var columns: Array[int] = []
		if row % 2 == 0:
			for col in GameConfig.GRID_COLS:
				columns.append(col)
		else:
			for i in GameConfig.GRID_COLS:
				columns.append(GameConfig.GRID_COLS - 1 - i)
		for col in columns:
			if model.is_mowable(col, row):
				route.append(Vector2i(col, row))
				continue
			var detour := robot_detour(model, col, row)
			if detour.x >= 0:
				route.append(detour)
	return route


## Nearest open row in the same column, searching +/-1..ROBOT_DETOUR_RANGE (§7).
static func robot_detour(model: LawnModel, col: int, row: int) -> Vector2i:
	for offset in range(1, GameConfig.ROBOT_DETOUR_RANGE + 1):
		if model.is_mowable(col, row - offset):
			return Vector2i(col, row - offset)
		if model.is_mowable(col, row + offset):
			return Vector2i(col, row + offset)
	return Vector2i(-1, -1)
