class_name Weather
extends Control
## Efectos climaticos en pantalla: lluvia acida y niebla toxica.
## Main controla `rain` y `fog` (0..1); este nodo solo dibuja.

var rain := 0.0
var fog := 0.15

var _drops: Array = []     # cada gota: [x, y, profundidad, y_de_impacto, fase]
var _blobs: Array = []
var _splashes: Array = []  # cada salpicadura: [posicion, vida, vida_total, escala]
var _drop_texture: Texture2D
var _splash_texture: Texture2D
var _t := 0.0

const DROP_COUNT := 50
const SPLASH_LIFE := 0.25


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_drop_texture = load("res://assets/weather/gota.png") if ResourceLoader.exists("res://assets/weather/gota.png") else null
	_splash_texture = load("res://assets/weather/got_salpicadura.png") if ResourceLoader.exists("res://assets/weather/got_salpicadura.png") else null
	var vs := get_viewport_rect().size
	for i in DROP_COUNT:
		_drops.append(_new_drop(vs, true))
	for i in 7:
		_blobs.append(Vector3(randf() * vs.x, randf() * vs.y, randf_range(70.0, 130.0)))


## Cada gota cae desde arriba hasta un punto de impacto elegido en CUALQUIER parte de la
## pantalla (cesped, calle...). Las lejanas son pequenas, lentas y tenues; las cercanas, al reves.
func _new_drop(vs: Vector2, anywhere: bool) -> Array:
	var z := randf_range(0.25, 1.0)
	var target := randf_range(vs.y * 0.05, vs.y)
	var y := randf_range(-40.0, target) if anywhere else randf_range(-60.0, -6.0)
	return [randf() * (vs.x + 140.0) - 20.0, y, z, target, randf() * TAU]


func _wind() -> float:
	# racha de viento: mezcla de ondas lentas para que la inclinacion no sea constante
	return -45.0 + sin(_t * 0.7) * 30.0 + sin(_t * 1.9 + 1.3) * 14.0


func _process(delta: float) -> void:
	var vs := get_viewport_rect().size
	_t += delta
	if rain > 0.01:
		var wind := _wind()
		for i in _drops.size():
			var d: Array = _drops[i]
			var z: float = d[2]
			var fall := 300.0 + 340.0 * z
			d[0] += (wind * (0.5 + z) + sin(_t * 3.0 + float(d[4])) * 9.0) * delta
			d[1] += fall * delta
			if d[1] >= d[3]:
				if randf() < 0.9:
					_splashes.append([Vector2(d[0], d[3]), SPLASH_LIFE, SPLASH_LIFE, 0.6 + z * 0.7])
				_drops[i] = _new_drop(vs, false)
			elif d[0] < -30.0:
				d[0] += vs.x + 140.0
		# charcos extra al azar, para que el suelo se vea "vivo" aunque no caiga una gota justo ahi
		if randf() < rain * 0.5:
			_splashes.append([Vector2(randf() * vs.x, randf_range(vs.y * 0.08, vs.y)), SPLASH_LIFE, SPLASH_LIFE, randf_range(0.5, 0.9)])
	if _splashes.size() > 220:
		_splashes = _splashes.slice(_splashes.size() - 220)
	for i in range(_splashes.size() - 1, -1, -1):
		_splashes[i][1] -= delta
		if _splashes[i][1] <= 0.0:
			_splashes.remove_at(i)
	for i in _blobs.size():
		var b: Vector3 = _blobs[i]
		b.x += (6.0 + float(i)) * delta
		if b.x > vs.x + b.z:
			b.x = -b.z
		_blobs[i] = b
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	if fog > 0.01:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.42, 0.52, 0.22, fog * 0.22))
		for blob in _blobs:
			var b: Vector3 = blob
			draw_circle(Vector2(b.x, b.y), b.z, Color(0.5, 0.6, 0.3, fog * 0.07))
	if rain > 0.01:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.1, 0.25, 0.1, rain * 0.10))
		var n := int(float(_drops.size()) * rain)
		var wind := _wind()
		for i in n:
			var d: Array = _drops[i]
			var z: float = d[2]
			var p := Vector2(d[0], d[1])
			# estela inclinada segun viento y velocidad, con la cola mas tenue (sin lineas rectas iguales)
			var fall := 300.0 + 340.0 * z
			var dir := Vector2(wind * (0.5 + z) * 0.6, fall).normalized()
			var len := 5.0 + 11.0 * z
			var a := (0.18 + 0.5 * z) * minf(1.0, rain + 0.3)
			var mid := p - dir * (len * 0.5)
			draw_line(p - dir * len, mid, Color(0.55, 0.85, 0.4, a * 0.35), 1.0)
			draw_line(mid, p, Color(0.7, 0.95, 0.5, a), 1.0 if z < 0.7 else 2.0)
		for splash in _splashes:
			var pos: Vector2 = splash[0]
			var k := 1.0 - float(splash[1]) / float(splash[2])  # 0 -> 1 durante la salpicadura
			var sc: float = splash[3]
			var al := (1.0 - k) * rain
			# anillo elipitico que se abre sobre el suelo (vista cenital inclinada)
			var rx := (2.0 + 9.0 * k) * sc
			_ring(pos, rx, rx * 0.45, Color(0.7, 0.95, 0.5, al * 0.55))
			# gotitas que saltan
			for j in 4:
				var ang := float(j) * 1.57 + pos.x * 0.37
				var up := sin(k * PI) * 7.0 * sc
				var q := pos + Vector2(cos(ang) * rx * 0.9, sin(ang) * rx * 0.4 - up)
				draw_rect(Rect2(q.round(), Vector2(1, 1) if sc < 1.0 else Vector2(2, 2)), Color(0.8, 1.0, 0.6, al * 0.9))
			if _splash_texture != null and sc > 1.0 and k < 0.6:
				draw_texture_rect(_splash_texture, Rect2(pos - Vector2(7, 8), Vector2(14, 8)), false, Color(1, 1, 1, al * 0.8))


func _ring(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := float(i) / 16.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, 1.0)
