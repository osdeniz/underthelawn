class_name Analytics
extends RefCounted
## Event sink (G12.6). Nothing leaves the device: events are buffered in memory
## and printed, so the shape of the funnel is visible now and a real backend is
## a change in ONE function later.
##
## Keeping this static and dependency-free is the point — an analytics call must
## never be able to break gameplay.

static var _events: Array = []
static var enabled := true


static func track(event: String, data: Dictionary = {}) -> void:
	if not enabled:
		return
	var entry := {"event": event, "data": data}
	_events.append(entry)
	print("[analytics] %s %s" % [event, str(data)])


## Everything recorded this session, for tests and for a future upload.
static func events() -> Array:
	return _events


static func clear() -> void:
	_events.clear()
