class_name Weather
extends Control
## Efectos climaticos en pantalla: lluvia acida y niebla toxica.
## Main controla `rain` y `fog` (0..1); este nodo solo dibuja.

var rain := 0.0
var fog := 0.15

var _drops: Array = []
var _blobs: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
				d = Vector2(randf() * vs.x * 1.2, -8.0)
			if d.x < -10.0:
				d.x += vs.x * 1.2
			_drops[i] = d
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
			draw_line(d, d + Vector2(-2.5, 7.0), Color(0.6, 0.9, 0.45, 0.55), 1.0)
