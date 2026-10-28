extends Node2D
## Pantalla de inicio: logo, lluvia, ruinas al fondo y menu tactil
## (JUGAR / CONTROLES / CREDITOS). Al pulsar JUGAR carga la partida.

const MAIN_SCENE := "res://scenes/main.tscn"

var _font: Font
var _t := 0.0
var _drops: Array = []
var _stars: Array = []
var _panel := ""            # "", "controles", "creditos"
var _buttons: Array = []    # {rect, id, text}
var _go_t := -1.0
var _flash := 0.0
var _skyline: Array = []


func _ready() -> void:
	_font = UiFont.get_font()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 160:
		_drops.append([rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4)])
	for i in 60:
		_stars.append([rng.randf(), rng.randf() * 0.5, rng.randf()])
	var x := 0.0
	while x < 1.1:
		var w := rng.randf_range(0.03, 0.08)
		_skyline.append([x, w, rng.randf_range(0.08, 0.28), rng.randi() % 3])
		x += w * rng.randf_range(0.7, 1.1)
	Sfx.ensure(get_tree())
	_start_audio()
	var m := Music.new()
	m._gap = 1.5
	add_child(m)
	get_viewport().size_changed.connect(queue_redraw)


func _start_audio() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Sfx.loop("rain_loop", true, -12.0)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	if randf() < delta * 0.12:
		_flash = 1.0
	if _go_t >= 0.0:
		_go_t += delta
		if _go_t > 0.7:
			set_process(false)
			Sfx.loop("rain_loop", false)
			get_tree().change_scene_to_file(MAIN_SCENE)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _go_t >= 0.0:
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_press("jugar")
		elif event.keycode == KEY_ESCAPE and _panel != "":
			_press("volver")
		return
	if not pressed:
		return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			_press(b["id"])
			return
	if _panel != "":
		_press("volver")


func _press(id: String) -> void:
	match id:
		"jugar":
			Sfx.play("ui_start")
			_go_t = 0.0
		"controles", "creditos":
			Sfx.play("ui_click")
			_panel = id
		"volver":
			Sfx.play("ui_close", -4.0)
			_panel = ""


func _txt(s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 3, Color(0, 0, 0, 0.9))
	draw_string(_font, pos, s, align, width, size, col)


func _draw() -> void:
	var vs := get_viewport_rect().size
	var cx := vs.x * 0.5
	# cielo
	var steps := 24
	for i in steps:
		var k := float(i) / steps
		var c := Color(0.03, 0.04, 0.06).lerp(Color(0.16, 0.10, 0.09), pow(k, 1.6))
		draw_rect(Rect2(0, vs.y * k, vs.x, vs.y / steps + 1.0), c)
	for s in _stars:
		var a := 0.25 + 0.5 * absf(sin(_t * 0.8 + s[2] * 6.0))
		draw_rect(Rect2(s[0] * vs.x, s[1] * vs.y, 1, 1), Color(0.8, 0.85, 1.0, a * 0.5))
	# luna roja
	draw_circle(Vector2(vs.x * 0.78, vs.y * 0.2), 22.0, Color(0.55, 0.12, 0.10, 0.25))
	draw_circle(Vector2(vs.x * 0.78, vs.y * 0.2), 14.0, Color(0.75, 0.22, 0.16, 0.55))
	# ruinas
	var base := vs.y * 0.80
	for b in _skyline:
		var bx: float = b[0] * vs.x
		var bw: float = b[1] * vs.x
		var bh: float = b[2] * vs.y
		draw_rect(Rect2(bx, base - bh, bw, bh + 40.0), Color(0.04, 0.045, 0.06))
		if b[3] == 1:   # techo roto
			draw_rect(Rect2(bx + bw * 0.4, base - bh - 6.0, bw * 0.3, 6.0), Color(0.04, 0.045, 0.06))
		var wy := base - bh + 6.0
		while wy < base - 6.0:
			var wx := bx + 4.0
			while wx < bx + bw - 5.0:
				var h := int(wx * 13.0 + wy * 7.0) % 11
				if h == 0:
					var fl := 0.7 + 0.3 * sin(_t * 6.0 + wx)
					draw_rect(Rect2(wx, wy, 3, 3), Color(0.9, 0.7, 0.3, 0.7 * fl))
				elif h < 6:
					draw_rect(Rect2(wx, wy, 3, 3), Color(0.08, 0.09, 0.12))
				wx += 8.0
			wy += 9.0
	draw_rect(Rect2(0, base, vs.x, vs.y - base), Color(0.025, 0.028, 0.035))
	# silueta de superviviente con linterna
	var px := vs.x * 0.2
	draw_rect(Rect2(px - 3, base - 14, 6, 14), Color(0.01, 0.01, 0.015))
	draw_rect(Rect2(px - 2, base - 19, 4, 5), Color(0.01, 0.01, 0.015))
	var cone := PackedVector2Array([Vector2(px + 3, base - 12), Vector2(px + 120, base - 30), Vector2(px + 120, base + 6)])
	draw_colored_polygon(cone, Color(1.0, 0.95, 0.7, 0.07 + 0.02 * sin(_t * 9.0)))
	# lluvia
	for d in _drops:
		var y := fposmod(d[1] + _t * 0.9 * d[2], 1.0)
		var x := fposmod(d[0] - y * 0.12 + _t * 0.02, 1.0)
		draw_line(Vector2(x * vs.x, y * vs.y), Vector2(x * vs.x - 2, y * vs.y + 7), Color(0.55, 0.75, 0.6, 0.35))
	# relampago
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.8, 0.9, 1.0, _flash * 0.16))
	# viñeta
	for i in 6:
		var m := float(i) * 10.0
		draw_rect(Rect2(m, m, vs.x - 2.0 * m, vs.y - 2.0 * m), Color(0, 0, 0, 0.07), false, 10.0)

	# logo
	var ly := vs.y * 0.26
	var shake := 0.0 if randf() > 0.02 else 1.0
	_txt("ASHEN", Vector2(shake, ly), 44, Color(0.9, 0.82, 0.7), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_txt("HORIZON", Vector2(0, ly + 40.0), 44, Color(0.78, 0.16, 0.12), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_txt("supervivencia en un mundo de ceniza", Vector2(0, ly + 58.0), 10, Color(0.7, 0.7, 0.72, 0.8), HORIZONTAL_ALIGNMENT_CENTER, vs.x)

	# botones
	_buttons.clear()
	if _panel == "":
		var bw := 150.0
		var bh := 24.0
		var by := vs.y * 0.58
		var items := [["jugar", "JUGAR"], ["controles", "CONTROLES"], ["creditos", "CRÉDITOS"]]
		for i in items.size():
			var r := Rect2(cx - bw * 0.5, by + i * (bh + 8.0), bw, bh)
			_buttons.append({"rect": r, "id": items[i][0]})
			var pulse := 0.5 + 0.5 * sin(_t * 3.0) if i == 0 else 0.0
			var fill := Color(0.10, 0.10, 0.12, 0.85).lerp(Color(0.45, 0.10, 0.08, 0.9), pulse * 0.8)
			draw_rect(r, fill)
			draw_rect(r, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
			_txt(items[i][1], Vector2(r.position.x, r.position.y + 17.0), 14, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, bw)
	else:
		var pr := Rect2(cx - 190, vs.y * 0.45, 380, vs.y * 0.5)
		draw_rect(pr, Color(0.03, 0.03, 0.04, 0.92))
		draw_rect(pr, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
		var lines: Array = []
		if _panel == "controles":
			lines = ["MÓVIL: joystick izquierdo para moverte; botones a la derecha para",
				"atacar/disparar, esquivar, linterna, reparar y abrir la mochila.",
				"Toca las casillas de la barra para usar objetos y armas.",
				"PC: WASD mover · Shift correr · Espacio esquivar · J/Z atacar",
				"F linterna · R reparar · 1-3 barra rápida · B mochila · M mapa",
				"Los ruidos atraen zombis. Busca refugios y la máscara antigás."]
		else:
			lines = ["ASHEN HORIZON", "Diseño, historia y programación: Jose + Claude",
				"Música original: archivos aportados por Jose",
				"Efectos de sonido: sintetizados por código (tools/gen_sfx.py)",
				"Hecho con Godot 4.3"]
		var yy := pr.position.y + 22.0
		for l in lines:
			_txt(l, Vector2(pr.position.x, yy), 10, Color(0.88, 0.86, 0.8), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
			yy += 16.0
		_txt("toca para volver", Vector2(pr.position.x, pr.end.y - 8.0), 9, Color(0.7, 0.7, 0.7, 0.6 + 0.4 * sin(_t * 4.0)), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	_txt("v0.9 · Acto I–II", Vector2(0, vs.y - 6.0), 8, Color(0.6, 0.6, 0.6, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 8.0)

	# fundido al empezar
	if _go_t >= 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, clampf(_go_t / 0.6, 0.0, 1.0)))
