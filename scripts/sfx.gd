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
const AUDIO_CONFIG := "user://audio_settings.cfg"
static var sfx_level := 1.0
static var music_level := 1.0

var _pool: Array[AudioStreamPlayer] = []
var _pool2d: Array[AudioStreamPlayer2D] = []
var _loops := {}


static func setup_audio() -> void:
	var cfg := ConfigFile.new()
	cfg.load(AUDIO_CONFIG)
	sfx_level = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	music_level = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)


## Aplica y guarda un volumen: kind = "master" | "music" | "sfx" (0..1).
static func set_volume(kind: String, value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	match kind:
		"master":
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(0, v <= 0.001)
		"music":
			music_level = v
		"sfx":
			sfx_level = v
	var cfg := ConfigFile.new()
	cfg.load(AUDIO_CONFIG)
	cfg.set_value("audio", kind, v)
	cfg.save(AUDIO_CONFIG)


static func get_volume(kind: String) -> float:
	match kind:
		"music":
			return music_level
		"sfx":
			return sfx_level
	var cfg := ConfigFile.new()
	cfg.load(AUDIO_CONFIG)
	return clampf(float(cfg.get_value("audio", "master", 0.8)), 0.0, 1.0)


static func set_bus_level(name: String, value: float) -> void:
	if name == "Music":
		music_level = clampf(value, 0.0, 1.0)
	elif name == "SFX":
		sfx_level = clampf(value, 0.0, 1.0)


static func ensure(tree: SceneTree) -> Sfx:
	if _inst == null or not is_instance_valid(_inst):
		setup_audio()
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
			p.bus = "Master"
			p.stream = s
			p.volume_db = vol + linear_to_db(maxf(sfx_level, 0.0001))
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
			p.bus = "Master"
			p.global_position = pos
			p.volume_db = vol + linear_to_db(maxf(sfx_level, 0.0001))
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
		p.bus = "Master"
		_pool.append(p)
	for i in POOL_2D:
		var q := AudioStreamPlayer2D.new()
		q.max_distance = 260.0
		q.attenuation = 1.6
		add_child(q)
		q.bus = "Master"
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
		p.bus = "Master"
		p.volume_db = -60.0
		add_child(p)
		_loops[n] = p
	var tw := create_tween()
	if on:
		if not p.playing:
			p.play()
		tw.tween_property(p, "volume_db", vol + linear_to_db(maxf(sfx_level, 0.0001)), 1.2)
	else:
		tw.tween_property(p, "volume_db", -60.0, 1.2)
		tw.tween_callback(p.stop)
