class_name ForestAudio
extends Node
## Quiet, self-contained forest ambience and interaction sounds.
## Muting this node never changes the project's shared audio buses.

const AMBIENCE: AudioStreamWAV = preload("res://assets/audio/v2/forest_night.wav")
const CUES: Dictionary[String, AudioStreamWAV] = {
	"plant": preload("res://assets/audio/v2/plant.wav"),
	"harvest_moon": preload("res://assets/audio/v2/harvest_moon.wav"),
	"harvest_bell": preload("res://assets/audio/v2/harvest_bell.wav"),
	"nourish": preload("res://assets/audio/v2/nourish.wav"),
	"clear": preload("res://assets/audio/v2/clear.wav"),
	"seed_select": preload("res://assets/audio/v2/seed_select.wav"),
	"lamp_on": preload("res://assets/audio/v2/lamp_on.wav"),
	"lamp_off": preload("res://assets/audio/v2/lamp_off.wav"),
	"restore": preload("res://assets/audio/v2/restore.wav"),
	"complete": preload("res://assets/audio/v2/complete.wav"),
	"denied": preload("res://assets/audio/v2/denied.wav"),
	"overlay": preload("res://assets/audio/v2/overlay.wav"),
	"pause": preload("res://assets/audio/v2/pause.wav"),
	"resume": preload("res://assets/audio/v2/resume.wav"),
	"footstep_01": preload("res://assets/audio/v2/footstep_01.wav"),
	"footstep_02": preload("res://assets/audio/v2/footstep_02.wav"),
	"footstep_03": preload("res://assets/audio/v2/footstep_03.wav"),
}
const LEGACY_CUE_NAMES: Dictionary[String, String] = {"harvest": "harvest_moon", "toggle": "lamp_on", "error": "denied"}
const CUE_OFFSETS_DB: Dictionary[String, float] = {
	"denied": -5.0, "seed_select": -6.0, "overlay": -7.0,
	"pause": -6.0, "resume": -6.0, "complete": -1.5,
}
const VOICE_COUNT: int = 6
const AMBIENCE_VOLUME_DB: float = -19.0
const CUE_VOLUME_DB: float = -12.0
const FOOTSTEP_VOLUME_DB: float = -23.0
const STEP_SPACING: float = 23.0

var _muted: bool = false
var _headless: bool = false
var _ambience_player: AudioStreamPlayer
var _footstep_player: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_step_position := Vector2.ZERO
var _has_step_position := false
var _step_distance := STEP_SPACING * 0.5
var _step_clock := 0.0
var _stationary_clock := 0.0
var _step_variant := 0


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

	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer.new()
		voice.name = "CueVoice%d" % index
		voice.volume_db = CUE_VOLUME_DB
		add_child(voice)
		_voices.append(voice)
	# Footfalls cannot steal the tail of a harvest or restoration cue.
	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.name = "MossFootsteps"
	_footstep_player.volume_db = FOOTSTEP_VOLUME_DB
	add_child(_footstep_player)


func play_cue(kind: String) -> void:
	kind = LEGACY_CUE_NAMES.get(kind, kind)
	if _muted or _headless or _voices.is_empty() or not CUES.has(kind):
		return
	if kind.begins_with("footstep_"):
		_footstep_player.stream = CUES[kind]
		_footstep_player.play()
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
	voice.volume_db = CUE_VOLUME_DB + float(CUE_OFFSETS_DB.get(kind, 0.0))
	voice.play()


func update_footsteps(world_position: Vector2, delta: float) -> void:
	# Call only during ordinary unpaused play, using actual movement after collision.
	# Position deltas avoid footsteps when holding a direction against a wall.
	if not _has_step_position:
		_last_step_position = world_position
		_has_step_position = true
		return
	var distance := world_position.distance_to(_last_step_position)
	_last_step_position = world_position
	_step_clock += delta
	if distance > 32.0 or delta > 0.3 or _muted:
		_step_distance = STEP_SPACING * 0.5
		return
	if distance < 0.01:
		_stationary_clock += delta
		# Rendering may run faster than physics; a single still frame is not a stop.
		if _stationary_clock > 0.12:
			_step_distance = STEP_SPACING * 0.5
		return
	_stationary_clock = 0.0
	_step_distance += distance
	if _step_distance >= STEP_SPACING and _step_clock >= 0.19:
		_step_distance = fmod(_step_distance, STEP_SPACING)
		_step_clock = 0.0
		_step_variant = (_step_variant % 3) + 1
		play_cue("footstep_%02d" % _step_variant)


func set_muted(value: bool) -> void:
	_muted = value
	if is_instance_valid(_ambience_player):
		_ambience_player.stream_paused = value
	if value:
		for voice in _voices:
			voice.stop()
		if is_instance_valid(_footstep_player):
			_footstep_player.stop()


func is_muted() -> bool:
	return _muted
