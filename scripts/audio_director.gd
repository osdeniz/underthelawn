extends Node
## AudioDirector autoload.
##
## Per the sprint brief: NO runtime synthesis. The four files below are loaded
## from res://audio/ if present; a missing file is a console warning and the game
## continues silently so the audio pass can land later.
##
## Mixing behaviour (engine idle/moving lerp, cut pitch variance) is
## REFERENCE.md §14. The mechanism is here; the numbers marked TODO §14 are
## placeholders and must be replaced from the spec.

const PATHS := {
	"engine": "res://audio/mower_engine_loop.ogg",
	"cut": "res://audio/grass_cut.ogg",
	"discovery": "res://audio/discovery_chime.ogg",
	"ambient": "res://audio/ambient_birds_loop.ogg",
}

const CUT_VOICES := 4

# TODO §14 — placeholders, not from the spec.
const ENGINE_IDLE_DB := -14.0
const ENGINE_MOVING_DB := -6.0
const ENGINE_IDLE_PITCH := 0.9
const ENGINE_MOVING_PITCH := 1.12
const ENGINE_LERP := 5.0
const CUT_PITCH_MIN := 0.92
const CUT_PITCH_MAX := 1.10

var muted: bool = false:
	set(value):
		muted = value
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)
		GameState.set_setting("audio", "muted", value)

var _streams := {}
var _engine_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _one_shot: AudioStreamPlayer
var _cut_players: Array[AudioStreamPlayer] = []
var _cut_index := 0
var _engine_target := 0.0
var _engine_mix := 0.0
var _cut_frame := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_streams()
	_build_players()
	muted = bool(GameState.get_setting("audio", "muted", false))


func _load_streams() -> void:
	var missing: Array[String] = []
	for key in PATHS:
		var path: String = PATHS[key]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				_streams[key] = stream
				continue
		missing.append(path.get_file())
	if not missing.is_empty():
		push_warning("AudioDirector: audio/ dosyalari eksik, sessiz devam: %s"
			% ", ".join(missing))
		print("[AudioDirector] eksik ses dosyalari: ", ", ".join(missing))


func _build_players() -> void:
	_engine_player = _make_player("EngineLoop", "engine", true)
	_ambient_player = _make_player("Ambient", "ambient", true)
	_one_shot = _make_player("OneShot", "", false)
	for i in CUT_VOICES:
		_cut_players.append(_make_player("Cut%d" % i, "cut", false))


func _make_player(node_name: String, key: String, looping: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	if key != "" and _streams.has(key):
		p.stream = _streams[key]
		var ogg := p.stream as AudioStreamOggVorbis
		if ogg != null and looping:
			ogg.loop = true
	add_child(p)
	return p


# ---------------------------------------------------------------- public API

func toggle_mute() -> bool:
	muted = not muted
	return muted


func start_ambient() -> void:
	if _ambient_player.stream != null and not _ambient_player.playing:
		_ambient_player.play()


## 0.0 = idle, 1.0 = mowing at full speed. Smoothed in _process.
func set_engine_throttle(value: float) -> void:
	_engine_target = clampf(value, 0.0, 1.0)
	if _engine_player.stream != null and not _engine_player.playing:
		_engine_player.play()


## One cut sound per frame maximum, matching the haptics rule.
func play_cut() -> void:
	if _streams.is_empty() or not _streams.has("cut"):
		return
	var frame := Engine.get_process_frames()
	if frame == _cut_frame:
		return
	_cut_frame = frame
	var p := _cut_players[_cut_index]
	_cut_index = (_cut_index + 1) % _cut_players.size()
	p.pitch_scale = _rng.randf_range(CUT_PITCH_MIN, CUT_PITCH_MAX)
	p.play()


func play_discovery() -> void:
	if not _streams.has("discovery"):
		return
	_one_shot.stream = _streams["discovery"]
	_one_shot.pitch_scale = 1.0
	_one_shot.play()


func _process(delta: float) -> void:
	if _engine_player == null or _engine_player.stream == null:
		return
	_engine_mix = lerpf(_engine_mix, _engine_target, clampf(delta * ENGINE_LERP, 0.0, 1.0))
	_engine_player.volume_db = lerpf(ENGINE_IDLE_DB, ENGINE_MOVING_DB, _engine_mix)
	_engine_player.pitch_scale = lerpf(ENGINE_IDLE_PITCH, ENGINE_MOVING_PITCH, _engine_mix)
