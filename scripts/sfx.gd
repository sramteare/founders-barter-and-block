class_name Sfx
extends Node

# Tiny storybook sound bank. No audio files: every clip is a short PCM tone
# generated in code (16-bit mono, 22050 Hz) with a soft attack and exponential
# decay so nothing clicks.

const SAMPLE_RATE: int = 22050
const PEAK: float = 0.25

# Counts every play() call, even when muted or headless, so tests can verify.
static var play_count: Dictionary = {}

var _clips: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	_build_clips()
	for i in range(4):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func _exit_tree() -> void:
	for p in _players:
		if p != null and p.playing:
			p.stop()
		if p != null:
			p.stream = null

func play(name: String) -> void:
	play_count[name] = int(play_count.get(name, 0)) + 1
	if not _clips.has(name) or AudioServer.is_bus_mute(0):
		return
	if DisplayServer.get_name() == "headless":
		return
	for p in _players:
		if not p.playing:
			p.stream = _clips[name]
			p.play()
			return
	_players[0].stream = _clips[name]
	_players[0].play()

func clip_names() -> Array:
	return _clips.keys()

func clip_length(name: String) -> float:
	if not _clips.has(name):
		return 0.0
	var w: AudioStreamWAV = _clips[name]
	return float(w.data.size()) / (2.0 * float(SAMPLE_RATE))

func _build_clips() -> void:
	_clips["roll"] = _wav(_mix([
		_note(0.0, 0.05, 175.0, 60.0, 1),
		_note(0.075, 0.05, 150.0, 60.0, 1),
		_note(0.15, 0.06, 165.0, 55.0, 1),
	]))
	_clips["build"] = _wav(_mix([
		_note(0.0, 0.18, 110.0, 16.0, 1),
		_note(0.0, 0.09, 220.0, 40.0, 1),
	]))
	_clips["trade"] = _wav(_mix([
		_note(0.0, 0.12, 523.25, 9.0, 0),
		_note(0.1, 0.16, 659.25, 8.0, 0),
	]))
	_clips["turn"] = _wav(_mix([
		_note(0.0, 0.55, 880.0, 6.0, 0),
		_note(0.0, 0.35, 1760.0, 12.0, 0, 0.25),
	]))
	_clips["seven"] = _wav(_mix([
		_note(0.0, 0.18, 220.0, 10.0, 1),
		_note(0.17, 0.22, 174.6, 8.0, 1),
	]))
	_clips["win"] = _wav(_mix([
		_note(0.0, 0.14, 523.25, 7.0, 0),
		_note(0.12, 0.14, 659.25, 7.0, 0),
		_note(0.24, 0.14, 783.99, 7.0, 0),
		_note(0.36, 0.3, 1046.5, 6.0, 0),
	]))
	_clips["click"] = _wav(_mix([
		_note(0.0, 0.025, 1200.0, 220.0, 1),
	]))

func _note(at: float, dur: float, freq: float, decay: float, wave: int, amp: float = 1.0) -> Dictionary:
	return {"at": at, "dur": dur, "freq": freq, "decay": decay, "wave": wave, "amp": amp}

func _mix(notes: Array) -> PackedFloat32Array:
	var total := 0.0
	for n in notes:
		total = maxf(total, float(n["at"]) + float(n["dur"]))
	var out := PackedFloat32Array()
	out.resize(int(ceilf((total + 0.005) * SAMPLE_RATE)))
	for n in notes:
		_add_tone(
			out,
			int(float(n["at"]) * SAMPLE_RATE),
			int(float(n["dur"]) * SAMPLE_RATE),
			float(n["freq"]),
			float(n["decay"]),
			int(n["wave"]),
			float(n["amp"])
		)
	return out

func _add_tone(buf: PackedFloat32Array, start: int, count: int, freq: float, decay: float, wave: int, amp: float) -> void:
	var attack := maxi(1, int(0.006 * SAMPLE_RATE))
	for i in range(count):
		var idx := start + i
		if idx >= buf.size():
			break
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-decay * t) * amp
		if i < attack:
			env *= float(i) / float(attack)
		var tail := count - i
		if tail < attack:
			env *= float(tail) / float(attack)
		var v := 0.0
		if wave == 0:
			v = sin(TAU * freq * t)
		else:
			var ph := fmod(freq * t, 1.0)
			v = 4.0 * absf(ph - 0.5) - 1.0
		buf[idx] = clampf(buf[idx] + PEAK * env * v, -1.0, 1.0)

func _wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in range(buf.size()):
		bytes.encode_s16(i * 2, int(round(clampf(buf[i], -1.0, 1.0) * 32767.0)))
	wav.data = bytes
	return wav
