class_name Weather
extends Control
## Efectos climaticos en pantalla: lluvia acida y niebla toxica.
## Main controla `rain` y `fog` (0..1); este nodo solo dibuja.

var rain := 0.0
var fog := 0.15

var _drops: Array = []
var _blobs: Array = []
var _splashes: Array = []
var _drop_texture: Texture2D
var _splash_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_drop_texture = load("res://assets/weather/gota.png") if ResourceLoader.exists("res://assets/weather/gota.png") else null
	_splash_texture = load("res://assets/weather/got_salpicadura.png") if ResourceLoader.exists("res://assets/weather/got_salpicadura.png") else null
	var vs := get_viewport_rect().size
	for i in 170:
		_drops.append(Vector2(randf() * vs.x * 1.2, randf() * vs.y))
	for i in 7:
		_blobs.append(Vector3(randf() * vs.x, randf() * vs.y, randf_range(70.0, 130.0)))


func _process(delta: float) -> void:
	var vs := get_viewport_rect().size
	if rain > 0.01:
		for i in _drops.size():
			var d: Vector2 = _drops[i]
			d += Vector2(-60.0, 380.0) * delta
			if d.y > vs.y:
				if randf() < 0.32:
					_splashes.append([Vector2(d.x, vs.y - randf_range(12.0, 48.0)), 0.22])
				d = Vector2(randf() * vs.x * 1.2, -8.0)
			if d.x < -10.0:
				d.x += vs.x * 1.2
			_drops[i] = d
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
		for i in n:
			var d: Vector2 = _drops[i]
			if _drop_texture != null:
				draw_texture_rect(_drop_texture, Rect2(d, Vector2(5, 7)), false, Color(1, 1, 1, 0.65))
			else:
				draw_line(d, d + Vector2(-2.5, 7.0), Color(0.6, 0.9, 0.45, 0.55), 1.0)
		for splash in _splashes:
			if _splash_texture != null:
				var alpha := clampf(splash[1] / 0.22, 0.0, 1.0)
				draw_texture_rect(_splash_texture, Rect2(splash[0], Vector2(12, 9)), false, Color(1, 1, 1, alpha * rain))
