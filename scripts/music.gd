class_name Music
extends Node
## Musica de fondo: una pista al azar cada cierto tiempo, con silencios largos entre una y otra
## (nunca seguidas, y nunca la misma dos veces). Entra y sale con un fundido.

const TRACKS := [
	"res://assets/audio/music/beneath_the_ashen_sky.mp3",
	"res://assets/audio/music/rain_on_abandoned_glass.mp3",
	"res://assets/audio/music/last_light_on_the_spire.mp3",
	"res://assets/audio/music/the_weeping_hall.mp3",
]
const FIRST_DELAY := 15.0
const GAP_MIN := 15.0       # silencio minimo entre pistas (s)
const GAP_MAX := 40.0
const FADE_IN := 4.0
const FADE_OUT := 6.0
const VOLUME := 0.75        # volumen lineal maximo

var _player := AudioStreamPlayer.new()
var _gap := FIRST_DELAY
var _last := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Sfx.setup_audio()
	_player.bus = "Music"
	_rng.randomize()
	_player.volume_db = -80.0
	add_child(_player)


func _process(delta: float) -> void:
	if _player.playing:
		var len := _player.stream.get_length()
		var pos := _player.get_playback_position()
		var k := minf(clampf(pos / FADE_IN, 0.0, 1.0), clampf((len - pos) / FADE_OUT, 0.0, 1.0))
		_player.volume_db = linear_to_db(maxf(0.0001, VOLUME * k))
		return
	_gap -= delta
	if _gap <= 0.0:
		_play_next()


func _play_next() -> void:
	var i := _rng.randi() % TRACKS.size()
	if i == _last:
		i = (i + 1 + _rng.randi() % (TRACKS.size() - 1)) % TRACKS.size()
	_last = i
	var stream := load(TRACKS[i]) as AudioStream
	if stream == null:
		push_warning("No se pudo cargar la música: " + TRACKS[i])
		_gap = GAP_MIN
		return
	_player.stream = stream
	_player.volume_db = -80.0
	_player.play()
	_gap = _rng.randf_range(GAP_MIN, GAP_MAX)
