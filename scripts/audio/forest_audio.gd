class_name ForestAudio
extends Node
## Quiet, self-contained forest ambience and interaction sounds.
## Muting this node never changes the project's shared audio buses.

const AMBIENCE: AudioStreamWAV = preload("res://assets/audio/forest_ambience.wav")
const COMPANION: AudioStreamWAV = preload("res://assets/audio/under_lamp.wav")
const CUES: Dictionary[String, AudioStreamWAV] = {
	"plant": preload("res://assets/audio/plant.wav"),
	"harvest": preload("res://assets/audio/harvest.wav"),
	"restore": preload("res://assets/audio/restore.wav"),
	"toggle": preload("res://assets/audio/toggle.wav"),
	"clear": preload("res://assets/audio/clear.wav"),
	"error": preload("res://assets/audio/error.wav"),
}
const VOICE_COUNT: int = 5
const AMBIENCE_VOLUME_DB: float = -19.0
const CUE_VOLUME_DB: float = -12.0

var _muted: bool = false
var _headless: bool = false
var _ambience_player: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _companion_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		return

	# Duplicate the resource so loop settings stay local to this audio instance.
	var ambience_stream := AMBIENCE.duplicate() as AudioStreamWAV
	ambience_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambience_stream.loop_begin = 0
	ambience_stream.loop_end = int(ambience_stream.get_length() * ambience_stream.mix_rate)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "ForestAmbience"
	_ambience_player.stream = ambience_stream
	_ambience_player.volume_db = -60.0
	add_child(_ambience_player)
	_ambience_player.play()
	_ambience_player.stream_paused = _muted
	create_tween().tween_property(_ambience_player, "volume_db", AMBIENCE_VOLUME_DB, 1.6)
	_companion_player = AudioStreamPlayer.new()
	_companion_player.name = "LampLullaby"
	var song := COMPANION.duplicate() as AudioStreamWAV
	song.loop_mode = AudioStreamWAV.LOOP_FORWARD
	song.loop_end = int(song.get_length() * song.mix_rate)
	_companion_player.stream = song
	_companion_player.volume_db = -20.0
	add_child(_companion_player)

	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "CueVoice%d" % index
		voice.volume_db = CUE_VOLUME_DB
		add_child(voice)
		_voices.append(voice)


func play_cue(kind: String) -> void:
	if _muted or _headless or _voices.is_empty() or not CUES.has(kind):
		return

	# Reuse an idle player where possible; cap overlap during rapid interaction.
	var voice: AudioStreamPlayer = _voices[_next_voice]
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	voice.stop()
	voice.stream = CUES[kind]
	voice.volume_db = CUE_VOLUME_DB - (3.0 if kind == "error" else 0.0)
	voice.play()


func set_muted(value: bool) -> void:
	_muted = value
	if is_instance_valid(_ambience_player):
		_ambience_player.stream_paused = value
	if is_instance_valid(_companion_player):
		_companion_player.stream_paused = value
	if value:
		for voice in _voices:
			voice.stop()


func is_muted() -> bool:
	return _muted


func set_companion(active: bool) -> void:
	if not is_instance_valid(_companion_player):
		return
	if active:
		_companion_player.play()
		_companion_player.stream_paused = _muted
	else:
		_companion_player.stop()
