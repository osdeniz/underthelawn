extends Node
## AudioDirector autoload.
##
## Per the sprint brief: NO runtime synthesis. The four files below are loaded
## from res://audio/ if present; a missing file is a console warning and the game
## continues silently so the audio pass can land later.
##
## Mixing follows REFERENCE.md §14: engine volume 0.28 idle <-> 0.45 moving,
## pitch 0.82 <-> 1.0 with up to +0.12 while turning, ~4/s lerp; cut sound at
## 0.6 with three pitch variants over a three-voice pool; ambient at 0.18.

## Base names; any of AUDIO_EXTENSIONS is accepted, so a real .ogg recording
## dropped in later silently replaces the generated .wav placeholder.
const PATHS := {
	"engine": "res://audio/mower_engine_loop",
	"cut": "res://audio/grass_cut",
	"discovery": "res://audio/discovery_chime",
	"scrap": "res://audio/scrap_pickup",
	"ambient": "res://audio/ambient_birds_loop",
	"theme": "res://audio/theme_town",
}
const AUDIO_EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]

const CUT_VOICES := GameConfig.CUT_VOICES

var muted: bool = false:
	set(value):
		muted = value
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value or _suspended)
		GameState.set_setting("audio", "muted", value)

var _streams := {}
var _engine_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _one_shot: AudioStreamPlayer
var _cut_players: Array[AudioStreamPlayer] = []
var _cut_index := 0
var _engine_target := 0.0
var _engine_mix := 0.0
var _turn_amount := 0.0
var _profile: Dictionary = GameConfig.ENGINE_PROFILES[GameConfig.MOWER_PUSH]
var _cut_frame := -1
var _suspended := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_streams()
	_build_players()
	muted = bool(GameState.get_setting("audio", "muted", false))
	# Optional G6 stream: no warning when absent, the pitched loop covers it.
	for ext in AUDIO_EXTENSIONS:
		if ResourceLoader.exists("res://audio/blade_spin" + ext):
			var stream := load("res://audio/blade_spin" + ext) as AudioStream
			if stream != null:
				_streams["blade_spin"] = stream
				break


func _load_streams() -> void:
	var missing: Array[String] = []
	for key in PATHS:
		var base: String = PATHS[key]
		var found := false
		for ext in AUDIO_EXTENSIONS:
			if not ResourceLoader.exists(base + ext):
				continue
			var stream := load(base + ext) as AudioStream
			if stream != null:
				_streams[key] = stream
				found = true
				break
		if not found:
			missing.append(base.get_file() + ".ogg")
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
		if looping:
			_force_loop(p.stream)
	add_child(p)
	return p


## The generated placeholders are .wav files with no loop metadata, so looping
## is set on the resource here rather than relying on the import settings.
static func _force_loop(stream: AudioStream) -> void:
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
		return
	var wav := stream as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# NOT data.size() / 2: Godot's WAV importer compresses (QOA/IMA-ADPCM),
		# so the byte count is not the frame count. get_length() is correct for
		# every format, and a short loop_end would loop a fragment.
		wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
		return
	var mp3 := stream as AudioStreamMP3
	if mp3 != null:
		mp3.loop = true


# ---------------------------------------------------------------- public API

func toggle_mute() -> bool:
	muted = not muted
	return muted


func start_ambient() -> void:
	if _ambient_player.stream != null and not _ambient_player.playing:
		_ambient_player.volume_db = GameConfig.linear_to_db_safe(GameConfig.AMBIENT_GAIN)
		_ambient_player.play()


## Swaps the engine mix when the player changes mower: push and tractor share
## the loop at different pitches, the robot uses it as a quiet high whine (§14).
func set_engine_profile(type_index: int) -> void:
	_profile = GameConfig.ENGINE_PROFILES[clampi(type_index, 0,
		GameConfig.ENGINE_PROFILES.size() - 1)]
	# G6: a real blade_spin recording is preferred over the loop at pitch 2.6.
	if _engine_player == null:
		return
	var want: AudioStream = _streams.get("engine")
	if type_index == GameConfig.MOWER_BLADE and _streams.has("blade_spin"):
		want = _streams["blade_spin"]
	if want != null and _engine_player.stream != want:
		_engine_player.stream = want
		_force_loop(want)
		_engine_player.play()


## speed_fraction 0 = idle, 1 = full speed. turn_amount 0..1 adds the pitch
## boost the spec asks for while cornering (§14).
func set_engine_state(speed_fraction: float, turn_amount: float = 0.0) -> void:
	_engine_target = clampf(speed_fraction, 0.0, 1.0)
	_turn_amount = clampf(turn_amount, 0.0, 1.0)
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
	p.pitch_scale = GameConfig.CUT_PITCH_VARIANTS[
		_rng.randi_range(0, GameConfig.CUT_PITCH_VARIANTS.size() - 1)]
	p.volume_db = GameConfig.linear_to_db_safe(GameConfig.CUT_GAIN)
	p.play()


## The metallic "tink" of a salvage pickup (G9). Silent if the file is missing,
## like every other cue here.
func play_scrap() -> void:
	if not _streams.has("scrap"):
		return
	_one_shot.stream = _streams["scrap"]
	_one_shot.pitch_scale = randf_range(0.94, 1.08)
	_one_shot.play()


## Town theme, faded in over the hub and the opening cards (G9.2) and faded out
## when a chapter starts. Silent if the file is missing, like everything here.
var _music: AudioStreamPlayer
var _music_tween: Tween


func play_theme() -> void:
	if not _streams.has("theme"):
		return
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = "Master"
		add_child(_music)
	if _music.playing and _music.stream == _streams["theme"]:
		return
	_music.stream = _streams["theme"]
	_music.volume_db = GameConfig.linear_to_db_safe(0.0001)
	_music.play()
	_fade_music(GameConfig.THEME_GAIN, 1.2)


func stop_theme() -> void:
	if _music == null or not _music.playing:
		return
	_fade_music(0.0001, 0.8)
	_music_tween.tween_callback(func() -> void: _music.stop())


func _fade_music(target_linear: float, duration: float) -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db",
		GameConfig.linear_to_db_safe(target_linear), duration)


func play_discovery() -> void:
	if not _streams.has("discovery"):
		return
	_one_shot.stream = _streams["discovery"]
	_one_shot.pitch_scale = 1.0
	_one_shot.play()


## Suspends the whole audio bus while the app is backgrounded (§14).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_set_suspended(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_set_suspended(false)


func _set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value or muted)
	if _engine_player:
		_engine_player.stream_paused = value
	if _ambient_player:
		_ambient_player.stream_paused = value


func _process(delta: float) -> void:
	if _engine_player == null or _engine_player.stream == null:
		return
	_engine_mix = lerpf(_engine_mix, _engine_target,
		clampf(delta * GameConfig.ENGINE_MIX_LERP, 0.0, 1.0))
	_engine_player.volume_db = GameConfig.linear_to_db_safe(
		lerpf(_profile["idle_gain"], _profile["move_gain"], _engine_mix))
	_engine_player.pitch_scale = lerpf(
		_profile["idle_pitch"], _profile["move_pitch"], _engine_mix) \
		+ float(_profile["turn"]) * _turn_amount
