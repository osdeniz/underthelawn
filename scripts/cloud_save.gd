extends Node
## CloudSave autoload (G16.2): the seam a platform save provider plugs into.
##
## Locally this does nothing and says so. The point of having it now is that
## GameState already calls push() after every write and pull() before its first
## read, so wiring iCloud or Play Games later is a PROVIDER, not a refactor:
##
##   iOS  — a plugin exposing NSUbiquitousKeyValueStore (the 1 MB key-value
##          store; this save is ~60 KB) or CloudKit. Set `provider` to an object
##          with `push(text: String) -> void` and `pull() -> String`.
##   Android — Play Games Services v2 "Saved Games" (snapshots) through the
##          godot-play-game-services plugin; same two methods.
##
## Conflict rule when both sides have data: the one whose "progress/done"
## count is higher wins; on a tie, local. Kept in GameState, not here, because
## it is a rule about the GAME's data and this node knows nothing about that.

var provider: Object = null


func available() -> bool:
	return provider != null and provider.has_method("push") and provider.has_method("pull")


func push(text: String) -> void:
	if available():
		provider.call("push", text)


func pull() -> String:
	if available():
		var got: Variant = provider.call("pull")
		return str(got) if got != null else ""
	return ""
