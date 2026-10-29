class_name StationMenu
extends Control
## Boton "USAR" cuando estas junto a un puesto del refugio (mesa, botiquin, generador)
## y el panel de cada uno. Pausa el juego mientras esta abierto.

var refuge: Refuge
var main: Node
var open := false
var station := ""
var _font: Font
var _t := 0.0
var _buttons: Array = []     # {rect, id}
var _last_press_ms := -1000
var _last_press_pos := Vector2(-100, -100)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = UiFont.get_font()
	get_viewport().size_changed.connect(queue_redraw)


func _can_show() -> bool:
	return main != null and main.get("_state") == "play" and refuge != null and not refuge.stations.is_empty()


func _use_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x * 0.5 - 80.0, 44.0, 160.0, 22.0)


func _panel_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x * 0.5 - 180.0, vs.y * 0.5 - 135.0, 360.0, 270.0)


func set_open(v: bool, st := "") -> void:
	if v == open:
		return
	open = v
	station = st
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
	if event is InputEventKey and event.pressed and not event.echo:
		if open and event.keycode == KEY_ESCAPE:
			set_open(false)
			get_viewport().set_input_as_handled()
		elif not open and _can_show() and refuge.near != "" and event.keycode == KEY_E:
			set_open(true, refuge.near)
			get_viewport().set_input_as_handled()
		return
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
	else:
		return
	var now := Time.get_ticks_msec()   # un toque llega como tactil y raton: atender solo el primero
	if now - _last_press_ms < 300 and pos.distance_to(_last_press_pos) < 16.0:
		if open or (_can_show() and refuge.near != "" and _use_rect().grow(6.0).has_point(pos)):
			get_viewport().set_input_as_handled()
		return
	if not open:
		if _can_show() and refuge.near != "" and _use_rect().grow(6.0).has_point(pos):
			_last_press_ms = now
			_last_press_pos = pos
			set_open(true, refuge.near)
			get_viewport().set_input_as_handled()
		return
	_last_press_ms = now
	_last_press_pos = pos
	get_viewport().set_input_as_handled()
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			_press(b["id"])
			return
	if not _panel_rect().has_point(pos):
		set_open(false)


func _press(id: String) -> void:
	if id == "cerrar":
		set_open(false)
		return
	if id.begins_with("craft"):
		refuge.craft(int(id.substr(5)))
		return
	match id:
		"med_use":
			refuge.med_use()
		"med_store":
			refuge.med_store()
		"med_up":
			refuge.med_upgrade()
		"gen_toggle":
			refuge.gen_toggle()
		"gen_fuel":
			refuge.gen_refuel()


func _txt(s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 3, Color(0, 0, 0, 0.9))
	draw_string(_font, pos, s, align, width, size, col)


func _draw() -> void:
	_buttons.clear()
	if _font == null or not _can_show():
		return
	var vs := get_viewport_rect().size
	if not open:
		if refuge.near != "":
			var r := _use_rect()
			var a := 0.8 + 0.2 * sin(_t * 4.0)
			draw_rect(r, Color(0.05, 0.08, 0.05, 0.85))
			draw_rect(r, Color(0.58, 0.78, 0.37, a), false, 1.0)
			_txt("USAR · " + refuge.station_title(refuge.near).substr(0, 24), Vector2(r.position.x, r.position.y + 15.0), 10, Color(0.92, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.008, 0.012, 0.016, 0.7))
	var pr := _panel_rect()
	draw_rect(pr, Color(0.035, 0.047, 0.053, 0.98))
	draw_rect(pr, Color(0.47, 0.63, 0.48, 0.9), false, 1.0)
	draw_rect(Rect2(pr.position, Vector2(pr.size.x, 4.0)), Color(0.56, 0.74, 0.43))
	_txt(refuge.station_title(station), Vector2(pr.position.x, pr.position.y + 26.0), 16, Color(0.95, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	draw_rect(Rect2(pr.position.x + 16.0, pr.position.y + 36.0, pr.size.x - 32.0, 1.0), Color(0.35, 0.43, 0.37))
	var rows: Array = []   # [id, texto, activo]
	var info: Array = []
	var inv := refuge.player.inventory
	match station:
		"bench":
			info = ["Chatarra: %d" % refuge.scrap(), "Fabrica con la chatarra que encuentres."]
			for i in Refuge.RECIPES.size():
				var rc: Dictionary = Refuge.RECIPES[i]
				rows.append(["craft%d" % i, "%s  ·  %d chatarra" % [rc["name"], rc["cost"]], refuge.scrap() >= int(rc["cost"])])
		"medkit":
			var lv := refuge.med_level
			info = ["Nivel %d/3  ·  Cargas %d/%d  ·  Cura %d" % [lv + 1, refuge.med_charges, refuge.med_cap(), int(Refuge.MED_HEAL[lv])],
				"Vendajes en la mochila: %d  ·  Chatarra: %d" % [inv.count("bandage"), refuge.scrap()]]
			rows.append(["med_use", "CURARME  (usa 1 carga)", refuge.med_charges > 0])
			rows.append(["med_store", "GUARDAR UN VENDAJE  (+1 carga)", inv.owns("bandage") and refuge.med_charges < refuge.med_cap()])
			if lv < Refuge.MED_CAP.size() - 1:
				var cost: int = Refuge.MED_COST[lv + 1]
				rows.append(["med_up", "AMPLIAR a nivel %d  ·  %d chatarra" % [lv + 2, cost], refuge.scrap() >= cost])
			else:
				rows.append(["", "NIVEL MÁXIMO", false])
		_:
			info = ["Combustible: %d%%   ·   Bidones: %d" % [int(round(refuge.fuel)), inv.count("combustible")],
				"Encendido: calor de noche, cura más rápido y luces."]
			rows.append(["gen_toggle", "APAGAR GENERADOR" if refuge.gen_on else "ENCENDER GENERADOR", refuge.gen_on or refuge.fuel > 0.0])
			rows.append(["gen_fuel", "AÑADIR COMBUSTIBLE  (1 bidón)", inv.owns("combustible")])
	var y := pr.position.y + 54.0
	for l in info:
		_txt(l, Vector2(pr.position.x, y), 10, Color(0.85, 0.88, 0.78), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
		y += 15.0
	if station == "generator":   # barra de combustible
		var bar := Rect2(pr.position.x + 40.0, y + 2.0, pr.size.x - 80.0, 10.0)
		draw_rect(bar, Color(0.13, 0.13, 0.16))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * refuge.fuel / Refuge.FUEL_MAX, bar.size.y)), Color(0.9, 0.63, 0.19) if refuge.fuel > 20.0 else Color(0.84, 0.27, 0.27))
		draw_rect(bar, Color(0.8, 0.8, 0.7), false, 1.0)
		y += 22.0
	y += 6.0
	for rw in rows:
		var rect := Rect2(pr.position.x + 30.0, y, pr.size.x - 60.0, 24.0)
		var on: bool = rw[2]
		if rw[0] != "":
			_buttons.append({"rect": rect, "id": rw[0]})
		draw_rect(rect, Color(0.12, 0.22, 0.1, 0.95) if on else Color(0.09, 0.09, 0.1, 0.95))
		draw_rect(rect, Color(0.75, 0.7, 0.62, 0.85 if on else 0.35), false, 1.0)
		_txt(rw[1], Vector2(rect.position.x, rect.position.y + 16.0), 10, Color(0.95, 0.92, 0.85) if on else Color(0.5, 0.5, 0.5), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		y += 28.0
	var cr := Rect2(pr.position.x + 30.0, pr.end.y - 32.0, pr.size.x - 60.0, 22.0)
	_buttons.append({"rect": cr, "id": "cerrar"})
	draw_rect(cr, Color(0.25, 0.07, 0.06, 0.95))
	draw_rect(cr, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
	_txt("CERRAR", Vector2(cr.position.x, cr.position.y + 15.0), 11, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)
