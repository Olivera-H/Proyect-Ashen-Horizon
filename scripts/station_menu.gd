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
var _was_near := false
var _bulk := false           # cofre: mover 1 unidad o todas
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
	var h := 340.0 if station == "chest" else (330.0 if station == "bench" else 270.0)
	return Rect2(vs.x * 0.5 - 180.0, vs.y * 0.5 - h * 0.5, 360.0, h)


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
	var near_now: bool = _can_show() and refuge.near != ""
	if open or near_now or _was_near:    # sin puesto cerca no hay nada que dibujar
		queue_redraw()
	_was_near = near_now


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
	if id.begins_with("cput:"):
		refuge.chest_put(id.substr(5), 0 if _bulk else 1)
		return
	if id.begins_with("ctake:"):
		refuge.chest_take(id.substr(6), 0 if _bulk else 1)
		return
	match id:
		"cbulk":
			_bulk = not _bulk
			Sfx.play("ui_click")
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
		"chest":
			_draw_chest(pr)
			return
		"bench":
			info = ["Chatarra: %d   ·   Madera: %d" % [refuge.scrap(), refuge.wood()], "Cercas y barricadas se colocan con USAR en la mochila."]
			for i in Refuge.RECIPES.size():
				var rc: Dictionary = Refuge.RECIPES[i]
				rows.append(["craft%d" % i, "%s  ·  %s" % [rc["name"], Refuge.cost_text(rc)], refuge.can_craft(rc)])
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
		var rect := Rect2(pr.position.x + 30.0, y, pr.size.x - 60.0, 22.0 if station == "bench" else 24.0)
		var on: bool = rw[2]
		if rw[0] != "":
			_buttons.append({"rect": rect, "id": rw[0]})
		draw_rect(rect, Color(0.12, 0.22, 0.1, 0.95) if on else Color(0.09, 0.09, 0.1, 0.95))
		draw_rect(rect, Color(0.75, 0.7, 0.62, 0.85 if on else 0.35), false, 1.0)
		_txt(rw[1], Vector2(rect.position.x, rect.position.y + 16.0), 10, Color(0.95, 0.92, 0.85) if on else Color(0.5, 0.5, 0.5), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)
		y += 26.0 if station == "bench" else 28.0
	var cr := Rect2(pr.position.x + 30.0, pr.end.y - 32.0, pr.size.x - 60.0, 22.0)
	_buttons.append({"rect": cr, "id": "cerrar"})
	draw_rect(cr, Color(0.25, 0.07, 0.06, 0.95))
	draw_rect(cr, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
	_txt("CERRAR", Vector2(cr.position.x, cr.position.y + 15.0), 11, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)


## Panel del cofre: dos columnas (mochila / cofre); tocar una fila mueve 1 unidad (o todas).
func _draw_chest(pr: Rect2) -> void:
	var inv := refuge.player.inventory
	var total := refuge.chest_total()
	_txt("Cofre: %d / %d   ·   toca un objeto para moverlo" % [total, Refuge.CHEST_CAP], Vector2(pr.position.x, pr.position.y + 54.0), 9, Color(0.85, 0.88, 0.78), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	var colw := (pr.size.x - 48.0) * 0.5
	var lx := pr.position.x + 16.0
	var rx := lx + colw + 16.0
	_txt("MOCHILA  →", Vector2(lx, pr.position.y + 76.0), 10, Color(0.6, 0.8, 0.55), HORIZONTAL_ALIGNMENT_CENTER, colw)
	_txt("←  COFRE", Vector2(rx, pr.position.y + 76.0), 10, Color(0.9, 0.75, 0.45), HORIZONTAL_ALIGNMENT_CENTER, colw)
	var y := pr.position.y + 84.0
	for id in Refuge.CHEST_ITEMS:
		var nm: String = ItemDefs.item_name(id)
		var nb: int = inv.count(id)
		var nc: int = int(refuge.chest.get(id, 0))
		for side in 2:
			var r := Rect2(lx if side == 0 else rx, y, colw, 18.0)
			var n: int = nb if side == 0 else nc
			var on := n > 0 and (side == 1 or total < Refuge.CHEST_CAP)
			_buttons.append({"rect": r, "id": ("cput:" if side == 0 else "ctake:") + id})
			draw_rect(r, Color(0.12, 0.22, 0.1, 0.95) if on else Color(0.09, 0.09, 0.1, 0.95))
			draw_rect(r, Color(0.75, 0.7, 0.62, 0.85 if on else 0.3), false, 1.0)
			var col := Color(0.95, 0.92, 0.85) if on else Color(0.5, 0.5, 0.5)
			_txt(nm, Vector2(r.position.x + 5.0, r.position.y + 13.0), 9, col)
			_txt("x%d" % n, Vector2(r.position.x, r.position.y + 13.0), 9, col, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 5.0)
		y += 20.0
	var br := Rect2(pr.position.x + 30.0, y + 4.0, pr.size.x - 60.0, 20.0)
	_buttons.append({"rect": br, "id": "cbulk"})
	draw_rect(br, Color(0.1, 0.1, 0.13, 0.95))
	draw_rect(br, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
	_txt("MOVER: " + ("TODO EL MONTÓN" if _bulk else "DE A 1 UNIDAD"), Vector2(br.position.x, br.position.y + 14.0), 10, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, br.size.x)
	var cr := Rect2(pr.position.x + 30.0, pr.end.y - 32.0, pr.size.x - 60.0, 22.0)
	_buttons.append({"rect": cr, "id": "cerrar"})
	draw_rect(cr, Color(0.25, 0.07, 0.06, 0.95))
	draw_rect(cr, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
	_txt("CERRAR", Vector2(cr.position.x, cr.position.y + 15.0), 11, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, cr.size.x)
