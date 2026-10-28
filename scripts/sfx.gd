class_name Sfx
extends Node
## Banco de efectos de sonido. Los archivos viven en assets/audio/sfx/<nombre>.wav
## (generados con tools/gen_sfx.py). Para usar tus propios sonidos basta con
## reemplazar el archivo con el mismo nombre (wav u ogg).
## Uso: Sfx.play("pickup"), Sfx.play_at("zombie_hurt", pos), Sfx.pick("step", 4)

const DIR := "res://assets/audio/sfx/"
const POOL := 12
const POOL_2D := 16

static var _inst: Sfx = null
static var _cache := {}

var _pool: Array[AudioStreamPlayer] = []
var _pool2d: Array[AudioStreamPlayer2D] = []
var _loops := {}


static func ensure(tree: SceneTree) -> Sfx:
	if _inst == null or not is_instance_valid(_inst):
		_inst = Sfx.new()
		_inst.name = "SfxBank"
		_inst.process_mode = Node.PROCESS_MODE_ALWAYS
		tree.root.add_child.call_deferred(_inst)
	return _inst


static func _stream(n: String) -> AudioStream:
	if _cache.has(n):
		return _cache[n]
	var s: AudioStream = null
	for ext in ["ogg", "wav"]:
		var p: String = DIR + n + "." + ext
		if ResourceLoader.exists(p):
			s = load(p)
			break
	_cache[n] = s
	return s


## Sonido sin posicion (UI, jugador). vol en dB.
static func play(n: String, vol := 0.0, pitch_var := 0.05) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	var s := _stream(n)
	if s == null:
		return
	for p in _inst._pool:
		if not p.playing:
			p.stream = s
			p.volume_db = vol
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


## Sonido en el mundo: se atenua con la distancia al jugador/camara.
static func play_at(n: String, pos: Vector2, vol := 0.0, pitch_var := 0.08) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	var s := _stream(n)
	if s == null:
		return
	for p in _inst._pool2d:
		if not p.playing:
			p.stream = s
			p.global_position = pos
			p.volume_db = vol
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


## Reproduce una variante al azar: pick("step", 4) -> step_0..step_3.
static func pick(base: String, count: int, vol := 0.0) -> void:
	play("%s_%d" % [base, randi() % count], vol)


static func pick_at(base: String, count: int, pos: Vector2, vol := 0.0) -> void:
	play_at("%s_%d" % [base, randi() % count], pos, vol)


## Bucle continuo (lluvia, viento). Se enciende/apaga con fundido.
static func loop(n: String, on: bool, vol := -6.0) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	_inst._set_loop(n, on, vol)


func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in POOL_2D:
		var q := AudioStreamPlayer2D.new()
		q.max_distance = 260.0
		q.attenuation = 1.6
		add_child(q)
		_pool2d.append(q)


func _set_loop(n: String, on: bool, vol: float) -> void:
	var p: AudioStreamPlayer = _loops.get(n)
	if p == null:
		var s := Sfx._stream(n)
		if s == null:
			return
		if s is AudioStreamWAV:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = s.data.size() / 2
		p = AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = -60.0
		add_child(p)
		_loops[n] = p
	var tw := create_tween()
	if on:
		if not p.playing:
			p.play()
		tw.tween_property(p, "volume_db", vol, 1.2)
	else:
		tw.tween_property(p, "volume_db", -60.0, 1.2)
		tw.tween_callback(p.stop)
