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
	"pin": "res://audio/pin",
	# B14's two signal layers (G13). Both are optional: with neither file
	# present the crossfade simply never starts and the chapter is silent on
	# this axis rather than broken.
	"signal_static": "res://audio/signal_static_loop",
	"signal_clear": "res://audio/signal_clear_loop",
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
var _engine_off := false
var _ambient_player: AudioStreamPlayer
var _one_shot: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _cut_players: Array[AudioStreamPlayer] = []
var _cut_index := 0
## B14's two-layer signal (G13): a static loop that thins out and a clear tone
## that comes up as the ground around the listening post is cut.
var _signal_static: AudioStreamPlayer
var _signal_clear: AudioStreamPlayer
var _signal_active := false
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
	_signal_static = _make_player("SignalStatic", "signal_static", true)
	_signal_clear = _make_player("SignalClear", "signal_clear", true)
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


func stop_ambient() -> void:
	if _ambient_player != null and _ambient_player.playing:
		_ambient_player.stop()


func start_ambient() -> void:
	if _ambient_player.stream != null and not _ambient_player.playing:
		_ambient_player.volume_db = GameConfig.linear_to_db_safe(GameConfig.AMBIENT_GAIN)
		_ambient_player.play()


## Swaps the engine mix when the player changes mower: push and tractor share
## the loop at different pitches, the robot uses it as a quiet high whine (§14).
func set_engine_profile(type_index: int) -> void:
	# A new chapter is starting, so the engine is wanted again.
	_engine_off = false
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


## Silences the engine when a chapter ends. set_engine_state restarts a stopped
## player on its own, so this also has to latch: without the flag the next
## set_engine_state call from a dying scene would start it again (G12.9).
func stop_engine() -> void:
	_engine_off = true
	if _engine_player != null:
		_engine_player.stop()


## speed_fraction 0 = idle, 1 = full speed. turn_amount 0..1 adds the pitch
## boost the spec asks for while cornering (§14).
func set_engine_state(speed_fraction: float, turn_amount: float = 0.0) -> void:
	if _engine_off:
		return
	_engine_target = clampf(speed_fraction, 0.0, 1.0)
	_turn_amount = clampf(turn_amount, 0.0, 1.0)
	if _engine_player.stream != null and not _engine_player.playing:
		_engine_player.play()


## The dedicated recording for the active plant, or null when there is none.
## Looked up on disk exactly as PATHS entries are, so dropping
## audio/cut_reed.ogg into the project is the whole installation step.
var _plant_cut_cache := {}

func _plant_cut_stream() -> AudioStream:
	var name := str(GameConfig.plant("cut_sound", ""))
	if name == "":
		return null
	if _plant_cut_cache.has(name):
		return _plant_cut_cache[name]
	var found: AudioStream = null
	for ext in AUDIO_EXTENSIONS:
		var path := "res://audio/%s%s" % [name, ext]
		if ResourceLoader.exists(path):
			found = load(path) as AudioStream
			break
	_plant_cut_cache[name] = found
	return found


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
	# A reed hisses and corn cracks. If a recording for this plant exists it is
	# used; if not, the shared cut is pitched to suggest it, which is enough for
	# the ear to hear a different plant (G13).
	var plant_stream := _plant_cut_stream()
	p.stream = plant_stream if plant_stream != null else _streams["cut"]
	p.pitch_scale = GameConfig.CUT_PITCH_VARIANTS[
		_rng.randi_range(0, GameConfig.CUT_PITCH_VARIANTS.size() - 1)] \
		* (1.0 if plant_stream != null else float(GameConfig.plant("cut_pitch", 1.0)))
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


## The corkboard pin thunk (G10).
## Radio static under the Marshal's hint (G13.4). Reuses the blade-hit player
## rather than adding a bus: it is a one-shot, and it must not cut the engine.
func play_static() -> void:
	play_scrap()


## Starts the signal pair. Called by a chapter that has one; silently does
## nothing when neither recording is in the project.
func start_signal() -> void:
	if _signal_static == null or _signal_static.stream == null:
		return
	_signal_active = true
	set_signal_clarity(0.0)
	_signal_static.play()
	if _signal_clear != null and _signal_clear.stream != null:
		_signal_clear.play()


## `clarity` 0 = all static, 1 = the signal comes through. Driven by how much of
## the yard has been cut: the mowing IS the tuning, which is the one moment in
## the game where clearing ground and hearing something are the same act (G13).
func set_signal_clarity(clarity: float) -> void:
	if not _signal_active:
		return
	var t := clampf(clarity, 0.0, 1.0)
	if _signal_static != null:
		_signal_static.volume_db = GameConfig.linear_to_db_safe(
			GameConfig.SIGNAL_STATIC_GAIN * (1.0 - t))
	if _signal_clear != null:
		_signal_clear.volume_db = GameConfig.linear_to_db_safe(
			GameConfig.SIGNAL_CLEAR_GAIN * t)


func stop_signal() -> void:
	_signal_active = false
	if _signal_static != null:
		_signal_static.stop()
	if _signal_clear != null:
		_signal_clear.stop()


func play_pin() -> void:
	if not _streams.has("pin"):
		return
	_one_shot.stream = _streams["pin"]
	_one_shot.pitch_scale = randf_range(0.96, 1.05)
	_one_shot.play()


# ---------------------------------------------------------------- voice

## One recorded line, looked up by its TRANSLATION KEY: audio/voice/<KEY>.ogg,
## and per language when a localised recording exists —
## audio/voice/<locale>/<KEY>.ogg wins over the shared one (G14.23).
##
## Nothing here generates speech. A missing file is silence and not a warning,
## because for now every file is missing and the game is meant to play exactly
## as it does today.
func play_voice(text_key: String) -> void:
	var locale := TranslationServer.get_locale().substr(0, 2)
	var stream: AudioStream = null
	for base: String in ["res://audio/voice/%s/%s" % [locale, text_key],
			"res://audio/voice/%s" % text_key]:
		for ext: String in AUDIO_EXTENSIONS:
			if ResourceLoader.exists(base + ext):
				stream = load(base + ext) as AudioStream
				break
		if stream != null:
			break
	if stream == null:
		return
	if _voice == null or not is_instance_valid(_voice):
		_voice = AudioStreamPlayer.new()
		_voice.bus = "Master"
		add_child(_voice)
	_voice.stream = stream
	_voice.play()


## Cuts the current line short, for when the player taps through.
func stop_voice() -> void:
	if _voice != null and is_instance_valid(_voice):
		_voice.stop()


## Whether a recording exists for a key — used by the test that proves the
## lookup is wired without shipping any audio.
func has_voice(text_key: String) -> bool:
	for base: String in ["res://audio/voice/%s" % text_key]:
		for ext: String in AUDIO_EXTENSIONS:
			if ResourceLoader.exists(base + ext):
				return true
	return false


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
