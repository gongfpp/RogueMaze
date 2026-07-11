class_name AudioCues
extends Node

const MIX_RATE := 22050
const PLAYER_COUNT := 4

var enabled := true
var players: Array[AudioStreamPlayer] = []
var next_player := 0


func _ready() -> void:
	for index in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		players.append(player)


func play_place() -> void:
	_play_tone(520.0, 0.08, 0.20)


func play_rotate() -> void:
	_play_tone(360.0, 0.055, 0.14)


func play_reward() -> void:
	_play_tone(660.0, 0.13, 0.20)


func play_damage() -> void:
	_play_tone(145.0, 0.18, 0.26)


func play_rock() -> void:
	_play_tone(95.0, 0.24, 0.30)


func play_win() -> void:
	_play_tone(880.0, 0.24, 0.20)


func play_fail() -> void:
	_play_tone(110.0, 0.30, 0.23)


func _play_tone(frequency: float, duration: float, amplitude: float) -> void:
	if not enabled or players.is_empty():
		return
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = build_tone(frequency, duration, amplitude)
	player.volume_db = -7.0
	player.play()


static func build_tone(frequency: float, duration: float, amplitude: float = 0.2) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * MIX_RATE))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / float(MIX_RATE)
		var remaining := 1.0 - float(index) / float(sample_count)
		var envelope := remaining * remaining
		var fundamental := sin(TAU * frequency * time)
		var mechanical_click := sin(TAU * frequency * 2.01 * time) * 0.18
		var sample := int(clampf((fundamental + mechanical_click) * envelope * amplitude, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(index * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
