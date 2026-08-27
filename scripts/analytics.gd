class_name Analytics
extends RefCounted
## Event sink (G12.6, backend wired in G14.4, moved off Statsig onto our own
## Postgres in G14.5). Events are buffered in memory and printed locally for
## debugging, and fired at the ingestion endpoint
## (under-the-lawn-analytics.vercel.app -> Neon Postgres) so they're visible
## outside the device too, via that project's own dashboard.
##
## Keeping this static and dependency-free is the point — an analytics call must
## never be able to break gameplay. The network send is fire-and-forget: no
## await, no retry, no error surfaced to the caller. Offline or a dead endpoint
## degrades to exactly the old print-only behaviour.

## The shared key is embedded in the client, which makes it readable by anyone
## who decompiles the game. That is fine — it exists to keep casual noise off
## a free-tier endpoint, not to gate access to anything sensitive. Real auth
## would need a backend the client can't be, which analytics pings don't
## warrant.
const _ENDPOINT := "https://under-the-lawn-analytics.vercel.app/api/track"
const _KEY := "eecc17fb55440b58aeb9689a921cf477a411a8e90bee6a5c"

static var _events: Array = []
static var enabled := true


static func track(event: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var entry := {"event": event, "data": data}
	_events.append(entry)
	print("[analytics] %s %s" % [event, str(data)])
	_send(event, data)


static func _send(event: String, data: Dictionary) -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var tree := loop as SceneTree
	# The 39 tests/*.tscn scenes drive real gameplay code (they instance
	# Main.tscn/Root.tscn directly), so this can't tell real play from a test
	# by scene type. It CAN tell by which scene the engine was launched with:
	# whatever scene *_check.gd/*_shot.gd is running from is always
	# current_scene, even once it adds the real game as a child. A test suite
	# has no business phoning fake events home.
	var current := tree.current_scene
	if current != null:
		var script: Script = current.get_script()
		if script != null and str(script.resource_path).begins_with("res://tests/"):
			return
	var root := tree.root
	if root == null:
		return
	var req := HTTPRequest.new()
	req.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray,
			_b: PackedByteArray) -> void:
		req.queue_free(), CONNECT_ONE_SHOT)
	var body := JSON.stringify({
		"event": event,
		"user_id": GameState.install_id(),
		"platform": OS.get_name(),
		"props": data,
	})
	# track() commonly fires from inside a scene's own _ready() chain (e.g.
	# Game._begin_search(), called from Game._ready() via autostart_search) —
	# exactly when the tree is still busy attaching that scene's children, so
	# an immediate root.add_child() here throws "Parent node is busy setting
	# up children" and the request never goes out. Deferring both the attach
	# and the request sidesteps that, same as the engine's own error message
	# recommends.
	root.add_child.call_deferred(req)
	(func() -> void:
		if not is_instance_valid(req) or not req.is_inside_tree():
			return
		var err := req.request(_ENDPOINT, [
			"Content-Type: application/json",
			"x-analytics-key: " + _KEY,
		], HTTPClient.METHOD_POST, body)
		if err != OK:
			req.queue_free()
	).call_deferred()


## Everything recorded this session, for tests and for a future upload.
static func events() -> Array:
	return _events


static func clear() -> void:
	_events.clear()
