extends Node

## AudioDirector (autoload, progresion-10): floor music on the "Music" bus and
## one-shot SFX on the "SFX" bus. Paths are ready even when the files are not:
## a missing file plays silence and is logged once (list in docs/CREDITOS.md).
## A path also matches the same name with .wav/.mp3. Fetch via ManagerLocator.get_audio().

const SFX_PATHS := {
	&"door": "res://assets/audio/sfx/door.ogg",
	&"chest": "res://assets/audio/sfx/chest.ogg",
	&"hit": "res://assets/audio/sfx/hit.ogg",
	&"tower": "res://assets/audio/sfx/tower.ogg",
	&"victory": "res://assets/audio/sfx/victory.ogg",
	&"defeat": "res://assets/audio/sfx/defeat.ogg",
	&"light": "res://assets/audio/sfx/light.ogg",
	&"build": "res://assets/audio/sfx/build.ogg",
	&"relic": "res://assets/audio/sfx/relic.ogg",
	&"alert": "res://assets/audio/sfx/alert.ogg",
}
## audio-18: menu + intro, and the extraction theme (same for every floor).
const MUSIC_MENU := "res://assets/audio/music/menu.ogg"
const MUSIC_EXTRACTION := "res://assets/audio/music/extraction.ogg"
## audio-18: keys whose event only happens on the host (door, chest, combat, build...).
## Online the host plays them and relays them (NetSync "sfx"); a client drops its own
## calls (a RunState apply rebuilding a building must not play it again) and plays
## only the relayed one. The other keys (victory, defeat, alert) already run on every peer.
const HOST_KEYS: Array[StringName] = [&"door", &"chest", &"hit", &"tower", &"light", &"build", &"relic"]
## Same key again within this many ms is dropped (a melee brawl = many hits).
const SFX_MIN_GAP_MSEC := 80
const SFX_VOICES := 6
const MUSIC_FADE_SEC := 1.0
const MUSIC_DB := -6.0

var music_path: String = ""
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary = {}
var _cache: Dictionary = {}
var _warned: Dictionary = {}
var _music_tween: Tween
## audio-18: key -> times it passed the throttle (played or silent if the file is missing). Tests/logs.
var fired: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = &"Music"
	add_child(_music)
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "Sfx%d" % i
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)


## Plays `key` (SFX_PATHS). False when throttled, dropped (client, HOST_KEYS) or the file is missing.
## `from_net` = relayed by the host (NetSync "sfx").
func play_sfx(key: StringName, from_net: bool = false) -> bool:
	if key in HOST_KEYS and Net.is_online() and not Net.is_authority() and not from_net:
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(key, -SFX_MIN_GAP_MSEC)) < SFX_MIN_GAP_MSEC:
		return false
	_last_played[key] = now
	fired[key] = int(fired.get(key, 0)) + 1
	QuestLogger.debug(QuestLogger.Category.GENERAL, "AudioDirector: sfx '%s'%s." % [key, " (host)" if from_net else ""])
	if key in HOST_KEYS:
		NetSync.broadcast("sfx", {"key": String(key)})
	var stream := load_stream(SFX_PATHS.get(key, ""))
	if stream == null:
		return false
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.play()
	return true


## Fades to `path` (loops). Same path = no restart; "" or missing = fade out.
func play_music(path: String) -> void:
	if path == music_path and (_music.playing or path == ""):
		return
	music_path = path
	QuestLogger.debug(QuestLogger.Category.GENERAL, "AudioDirector: music '%s'." % path)
	var stream := load_stream(path)
	if _music_tween:
		_music_tween.kill()  # a second change mid-fade must not leave two tweens fighting
	# the tactical pause sets time_scale 0: a fade must still finish
	var tween := create_tween().set_ignore_time_scale()
	_music_tween = tween
	if _music.playing:
		tween.tween_property(_music, "volume_db", -40.0, MUSIC_FADE_SEC * 0.5)
	tween.tween_callback(func() -> void:
		_music.stop()
		if stream == null:
			return
		if "loop" in stream:
			stream.loop = true
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	if stream:
		tween.tween_property(_music, "volume_db", MUSIC_DB, MUSIC_FADE_SEC * 0.5)


func stop_music() -> void:
	play_music("")


## True if `key` has a file (else play_sfx is silent).
func has_sfx(key: StringName) -> bool:
	return load_stream(SFX_PATHS.get(key, "")) != null


## The stream at `path` (or the same name as .wav/.mp3); null if none exists.
func load_stream(path: String) -> AudioStream:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = null
	for candidate in [path, path.get_basename() + ".wav", path.get_basename() + ".mp3"]:
		if ResourceLoader.exists(candidate):
			stream = load(candidate) as AudioStream
			break
	if stream == null and not _warned.has(path):
		_warned[path] = true
		# calidad-13: info, not warn: the audio packs are optional placeholders (docs/CREDITOS.md)
		QuestLogger.info(QuestLogger.Category.GENERAL, "AudioDirector: missing audio '%s' (silence; see docs/CREDITOS.md)." % path)
	_cache[path] = stream
	return stream
