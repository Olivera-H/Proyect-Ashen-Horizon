class_name PauseMenu
extends Control
## Boton de configuracion (engranaje) y menu de pausa dentro de la partida:
## continuar, volumenes, controles, "estoy atascado" y salir a la pantalla de inicio.

const TITLE_SCENE := "res://scenes/title.tscn"
const KINDS := ["master", "music", "sfx"]
const NAMES := ["GENERAL", "MÚSICA", "EFECTOS"]

var main: Node
var open := false
var _font: Font
var _t := 0.0
var _view := ""             # "", "controles"
var _confirm := ""          # "", "salir", "atascado"
var _last_press_ms := -1000
var _last_press_pos := Vector2(-100, -100)
var _buttons: Array = []    # {rect, id}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = UiFont.get_font()
	get_viewport().size_changed.connect(queue_redraw)


func _gear_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x - 10.0 - 134.0 - 26.0, 10.0, 22.0, 22.0)


func _can_show() -> bool:
	return main != null and main.get("_state") == "play"


func _panel_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x * 0.5 - 194.0, vs.y * 0.5 - 153.0, 388.0, 306.0)


func _bar_rect(i: int) -> Rect2:
	var pr := _panel_rect()
	var bw := 264.0
	return Rect2(pr.position.x + (pr.size.x - bw) * 0.5, pr.position.y + 79.0 + i * 36.0, bw, 12.0)


func set_open(v: bool) -> void:
	if v == open:
		return
	open = v
	_view = ""
	_confirm = ""
	get_tree().paused = v
	if v:
		for a in ["move_left", "move_right", "move_up", "move_down", "run", "attack", "dodge"]:
			Input.action_release(a)
	Sfx.play("ui_open" if v else "ui_close", -4.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if open and not _can_show():
		set_open(false)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _can_show() or open:
			set_open(not open)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and open:
		_drag(event.position)
		get_viewport().set_input_as_handled()
		return
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and open:
		_drag(event.position)
		get_viewport().set_input_as_handled()
		return
	else:
		return
	# un mismo toque llega como evento tactil Y de raton (emulacion): atender solo el primero.
	# IMPORTANTE: fuera del menu solo se consumen los toques sobre el engranaje; el resto
	# (joystick, botones, mochila, mapa) debe llegar intacto a sus nodos.
	var now := Time.get_ticks_msec()
	var dup := now - _last_press_ms < 300 and pos.distance_to(_last_press_pos) < 16.0
	if not open:
		if _can_show() and not get_tree().paused and _gear_rect().grow(6.0).has_point(pos):
			get_viewport().set_input_as_handled()
			if not dup:
				_last_press_ms = now
				_last_press_pos = pos
				set_open(true)
		return
	if dup:
		get_viewport().set_input_as_handled()
		return
	_last_press_ms = now
	_last_press_pos = pos
	get_viewport().set_input_as_handled()
	if _drag(pos):
		return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			_press(b["id"])
			return
	if _view != "" and _panel_rect().has_point(pos):
		_view = ""
		queue_redraw()
	elif not _panel_rect().has_point(pos):
		set_open(false)


func _drag(pos: Vector2) -> bool:
	if _view != "":
		return false
	for i in 3:
		var bar := _bar_rect(i)
		if bar.grow(10.0).has_point(pos):
			Sfx.set_volume(KINDS[i], (pos.x - bar.position.x) / bar.size.x)
			return true
	return false


func _press(id: String) -> void:
	match id:
		"continuar":
			set_open(false)
		"controles":
			Sfx.play("ui_click")
			_view = "controles"
		"atascado":
			if _confirm != "atascado":
				_confirm = "atascado"
				Sfx.play("ui_blip")
			else:
				var p = main.get("player")
				p.global_position = main.get("checkpoint")
				set_open(false)
				main.get("hud").toast("Te llevamos al último refugio guardado.", 3.0)
		"salir":
			if _confirm != "salir":
				_confirm = "salir"
				Sfx.play("ui_blip")
			else:
				get_tree().paused = false
				Sfx.loop("rain_loop", false)
				for a in ["move_left", "move_right", "move_up", "move_down", "run", "attack", "dodge", "flashlight", "repair"]:
					Input.action_release(a)
				get_tree().change_scene_to_file(TITLE_SCENE)


func _txt(s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 3, Color(0, 0, 0, 0.9))
	draw_string(_font, pos, s, align, width, size, col)


func _draw() -> void:
	_buttons.clear()
	if _font == null:
		return
	if not open:
		if _can_show() and not get_tree().paused:
			var g := _gear_rect()
			draw_rect(g, Color(0.05, 0.05, 0.07, 0.65))
			draw_rect(g, Color(0.8, 0.78, 0.7, 0.7), false, 1.0)
			var c := g.get_center()
			draw_circle(c, 6.0, Color(0.85, 0.83, 0.75, 0.9))
			for i in 8:
				var a := TAU * float(i) / 8.0
				draw_rect(Rect2(c + Vector2.from_angle(a) * 7.0 - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.85, 0.83, 0.75, 0.9))
			draw_circle(c, 2.5, Color(0.05, 0.05, 0.07))
		return
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.008, 0.012, 0.016, 0.78))
	var pr := _panel_rect()
	draw_rect(pr, Color(0.035, 0.047, 0.053, 0.98))
	draw_rect(pr, Color(0.47, 0.63, 0.48, 0.9), false, 1.0)
	draw_rect(Rect2(pr.position, Vector2(pr.size.x, 4.0)), Color(0.56, 0.74, 0.43))
	draw_rect(Rect2(pr.position.x + 18.0, pr.position.y + 48.0, pr.size.x - 36.0, 1.0), Color(0.35, 0.43, 0.37))
	_txt("ASHEN HORIZON  /  PAUSA", Vector2(pr.position.x, pr.position.y + 28.0), 18, Color(0.95, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	_txt("AJUSTES DE AUDIO Y PARTIDA", Vector2(pr.position.x, pr.position.y + 43.0), 9, Color(0.58, 0.74, 0.59), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	if _view == "controles":
		var lines := ["MÓVIL: joystick izquierdo para moverte (al borde, corres).",
			"Botones derechos: atacar/disparar, esquivar, linterna, reparar.",
			"Casillas inferiores: usar objetos; botón de mochila: inventario.",
			"Botón del mapa (arriba a la derecha): minimapa y zoom.",
			"PC: WASD · Shift correr · Espacio esquivar · J/Z atacar",
			"F linterna · R reparar · 1-3 barra · B mochila · M mapa · Esc pausa",
			"Los ruidos atraen zombis. Los refugios curan y guardan progreso.",
			"La lluvia ácida y la Zona Cero queman: necesitas la máscara."]
		var yy := pr.position.y + 65.0
		for l in lines:
			_txt(l, Vector2(pr.position.x, yy), 9, Color(0.88, 0.86, 0.8), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
			yy += 23.0
		_txt("toca para volver", Vector2(pr.position.x, pr.end.y - 10.0), 9, Color(0.7, 0.7, 0.7, 0.6 + 0.4 * sin(_t * 4.0)), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		return
	for i in 3:
		var bar := _bar_rect(i)
		var v: float = Sfx.get_volume(KINDS[i])
		_txt("%s: %d%%" % [NAMES[i], int(round(v * 100.0))], Vector2(pr.position.x, bar.position.y - 5.0), 9, Color(0.9, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		draw_rect(bar, Color(0.13, 0.13, 0.16))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * v, bar.size.y)), Color(0.54, 0.75, 0.43))
		draw_rect(bar, Color(0.8, 0.8, 0.7), false, 1.0)
		var kx := clampf(bar.position.x + bar.size.x * v - 3.0, bar.position.x, bar.end.x - 6.0)   # la perilla no se sale de la barra
		draw_rect(Rect2(kx, bar.position.y - 3.0, 6.0, bar.size.y + 6.0), Color(0.95, 0.9, 0.72))
	var items := [
		["continuar", "CONTINUAR", Color(0.12, 0.25, 0.1, 0.95)],
		["controles", "CONTROLES", Color(0.1, 0.1, 0.13, 0.95)],
		["atascado", "¿ATASCADO? IR AL REFUGIO" if _confirm != "atascado" else "TOCA DE NUEVO PARA CONFIRMAR", Color(0.1, 0.1, 0.13, 0.95) if _confirm != "atascado" else Color(0.35, 0.25, 0.05, 0.95)],
		["salir", "SALIR AL INICIO" if _confirm != "salir" else "TOCA DE NUEVO PARA SALIR", Color(0.25, 0.07, 0.06, 0.95)],
	]
	var by := pr.position.y + 196.0
	for i in items.size():
		var r := Rect2(pr.position.x + 40.0, by + i * 26.0, pr.size.x - 80.0, 22.0)
		_buttons.append({"rect": r, "id": items[i][0]})
		draw_rect(r, items[i][2])
		draw_rect(r, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
		_txt(items[i][1], Vector2(r.position.x, r.position.y + 16.0), 11, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
