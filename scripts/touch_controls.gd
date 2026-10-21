class_name TouchControls
extends Control
## Controles tactiles para movil en horizontal.
## - Mitad izquierda: joystick flotante (aparece donde pones el dedo; al llevarlo
##   al borde del circulo el personaje corre).
## - Derecha: botones de ataque, esquiva, reparar y linterna.
## Todo se traduce a acciones de Input, asi el jugador no sabe de donde vienen.
## Con emulate_touch_from_mouse tambien se puede probar con el mouse en PC.

const STICK_R := 34.0
const DEAD_ZONE := 0.18
const RUN_THRESHOLD := 0.92

var buttons: Array = []
var _stick_id := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _touch_btn := {}   # indice de toque -> accion
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vs := get_viewport_rect().size
	buttons = [
		{"action": "attack", "c": Vector2(vs.x - 50.0, vs.y - 60.0), "r": 28.0, "label": "ATACAR"},
		{"action": "dodge", "c": Vector2(vs.x - 116.0, vs.y - 34.0), "r": 19.0, "label": "ESQUIVA"},
		{"action": "repair", "c": Vector2(vs.x - 40.0, vs.y - 124.0), "r": 15.0, "label": "REPARAR"},
		{"action": "flashlight", "c": Vector2(vs.x - 100.0, vs.y - 100.0), "r": 15.0, "label": "LUZ"},
	]
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			_knob = (event.position - _origin).limit_length(STICK_R)
			_apply()
			queue_redraw()


func _press(index: int, pos: Vector2) -> void:
	for b in buttons:
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		if pos.distance_to(c) <= r * 1.3:
			var action: String = b["action"]
			_touch_btn[index] = action
			Input.action_press(action)
			queue_redraw()
			return
	var vs := get_viewport_rect().size
	if _stick_id == -1 and pos.x < vs.x * 0.55:
		_stick_id = index
		_origin = pos
		_knob = Vector2.ZERO
		queue_redraw()


func _release(index: int) -> void:
	if index == _stick_id:
		_stick_id = -1
		_knob = Vector2.ZERO
		_apply()
	elif _touch_btn.has(index):
		Input.action_release(_touch_btn[index])
		_touch_btn.erase(index)
	queue_redraw()


func _apply() -> void:
	var v := _knob / STICK_R
	var mag := v.length()
	if mag < DEAD_ZONE:
		v = Vector2.ZERO
	_axis("move_right", v.x)
	_axis("move_left", -v.x)
	_axis("move_down", v.y)
	_axis("move_up", -v.y)
	if mag > RUN_THRESHOLD:
		Input.action_press("run")
	else:
		Input.action_release("run")


func _axis(action: String, value: float) -> void:
	if value > 0.01:
		Input.action_press(action, value)
	else:
		Input.action_release(action)


func _draw() -> void:
	var vs := get_viewport_rect().size
	if _stick_id != -1:
		draw_circle(_origin, STICK_R, Color(1, 1, 1, 0.08))
		draw_arc(_origin, STICK_R, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 1.5)
		draw_circle(_origin + _knob, 13.0, Color(1, 1, 1, 0.35))
	else:
		var hint := Vector2(72.0, vs.y - 72.0)
		draw_arc(hint, STICK_R, 0.0, TAU, 40, Color(1, 1, 1, 0.16), 1.5)
		draw_circle(hint, 11.0, Color(1, 1, 1, 0.12))

	var held := _touch_btn.values()
	for b in buttons:
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var down := held.has(b["action"])
		draw_circle(c, r, Color(1, 1, 1, 0.34 if down else 0.12))
		draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 1.5)
		if _font != null:
			var label: String = b["label"]
			draw_string(_font, c + Vector2(-r, 3.0), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 7, Color(1, 1, 1, 0.8))
