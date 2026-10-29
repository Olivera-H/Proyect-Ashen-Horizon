class_name Hud
extends Control
## HUD: barras de estado, arma y chatarra, reloj, objetivos con distancia,
## avisos temporales y pantallas de muerte / final. El minimapa (con su boton) es hijo de este nodo.

const BAR_W := 64.0
const BAR_H := 6.0

var player: Player
var world: World
var goals: Array = []
var status := ""    # aviso de estado (frio en el refugio)
var hint := ""      # mensaje fijo de objetivo, abajo en pantalla
var minimap: Minimap
var bars: StatBars
var inventory_ui: InventoryUI
var clock := 0.0
var raining := false
var warning := ""         # aviso de peligro ambiental (aire toxico, lluvia acida)
var notes_found := 0
var notes_total := 0
var end_kind := ""        # "" | "dead" | "won"
var end_age := 0.0
var end_ready := false
var end_cause := ""
var end_tip := ""
var end_time := 0.0
var end_checkpoint := Vector2i.ZERO
var _vignette: Texture2D

var _font: Font
var _toasts: Array = []   # [texto, tiempo_restante, duracion]
var _scrap_icon: Texture2D
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(p: Player, w: World, g: Array) -> void:
	player = p
	world = w
	goals = g
	_font = UiFont.get_font()
	_scrap_icon = PixelArt.make_icon("scrap")
	bars = StatBars.new()
	bars.position = Vector2(10, 10)
	add_child(bars)
	bars.setup(p)
	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.setup(p)
	minimap = Minimap.new()
	add_child(minimap)
	minimap.setup(w, p, g)


func toast(text: String, seconds: float = 3.0) -> void:
	_toasts.append([text, seconds, seconds])
	while _toasts.size() > 3:
		_toasts.pop_front()


func _process(delta: float) -> void:
	_t += delta
	end_age = end_age + delta if end_kind != "" else 0.0
	var vs := get_viewport_rect().size
	for i in range(_toasts.size() - 1, -1, -1):
		_toasts[i][1] -= delta
		if _toasts[i][1] <= 0.0:
			_toasts.remove_at(i)
	queue_redraw()


func _txt(pos: Vector2, s: String, size: int, col: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 3, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, s, align, width, size, col)


func _draw() -> void:
	if player == null or _font == null:
		return
	var vs := get_viewport_rect().size
	_draw_gear()
	_draw_clock(vs)
	_draw_goals(vs)
	_draw_toasts(vs)
	_draw_hint(vs)
	_draw_status(vs)
	if end_kind != "":
		_draw_end(vs)


func _draw_gear() -> void:
	var x := 10.0
	var y := 116.0
	var icon := ItemDefs.icon(player.weapon_id)
	if icon != null:
		draw_texture_rect(icon, Rect2(x, y - 4.0, 12, 12), false)
	_txt(Vector2(x + 14.0, y + 7.0), player.weapon_name, 10, Color(0.85, 0.85, 0.9))
	if player.weapon_is_gun:
		var ammo_id: String = ItemDefs.ITEMS[player.weapon_id]["ammo"]
		var n := player.ammo_in_reserve
		var col := Color("f1d262") if n > 0 else Color("d64545")
		var ai := ItemDefs.icon(ammo_id)
		if ai != null:
			draw_texture_rect(ai, Rect2(x, y + 9.0, 10, 10), false)
		_txt(Vector2(x + 12.0, y + 18.0), "x%d" % n, 10, col)
	else:
		var frac := player.weapon_durability / maxf(1.0, player.weapon_max)
		draw_rect(Rect2(x - 1.0, y + 10.0, 102.0, BAR_H - 1.0), Color(0, 0, 0, 0.7))
		var col := Color("b8bcc4") if frac > 0.25 else Color("d64545")
		draw_rect(Rect2(x, y + 11.0, 100.0 * frac, BAR_H - 3.0), col)
	draw_texture(_scrap_icon, Vector2(x, y + 21.0))
	_txt(Vector2(x + 11.0, y + 28.0), "x%d" % player.scrap, 10, Color(0.9, 0.9, 0.9))
	if notes_total > 0:
		_txt(Vector2(x + 54.0, y + 28.0), "Notas %d/%d" % [notes_found, notes_total], 10, Color("e8e2cf"))


func _draw_clock(vs: Vector2) -> void:
	var hour_24 := floori(int(clock * 1440.0) / 60.0) % 24
	var hour_12 := (hour_24 % 12) if (hour_24 % 12) != 0 else 12
	var period := "AM" if hour_24 < 12 else "PM"
	_txt(Vector2(0, 18.0), "%d %s" % [hour_12, period], 14, Color(0.95, 0.95, 0.95), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if warning != "":
		var pulse := 0.65 + 0.35 * sin(_t * 6.0)
		_txt(Vector2(0, 31.0), warning, 11, Color(1.0, 0.45, 0.3, pulse), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	elif raining:
		_txt(Vector2(0, 31.0), "LLUVIA ÁCIDA", 11, Color("9be564"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_goals(vs: Vector2) -> void:
	var right := vs.x - 10.0
	var y := minimap.list_top() if minimap != null else 14.0
	for g in goals:
		if not goal_visible(g, player):
			continue
		var gp: Vector2 = g["pos"]
		var meters := int(player.global_position.distance_to(gp) / 8.0)
		var col := Color("f1c40f") if g["main"] else Color("5dd6e8")
		_txt(Vector2(0, y), "%s  %d m" % [g["name"], meters], 10, col, HORIZONTAL_ALIGNMENT_RIGHT, right)
		y += 11.0


## Que objetivos se muestran (lista y minimapa): el refugio siempre; el laboratorio solo con la
## tarjeta; el hospital nunca; la base militar y demas, solo cuando son el objetivo principal.
static func goal_visible(g: Dictionary, p: Player) -> bool:
	var n: String = g["name"]
	if n == "Refugio":
		return true
	if n == "Hospital":
		return false
	if n == "Laboratorio Horizonte":
		return p != null and p.inventory.owns("tarjeta") and bool(g["main"])
	if n == "Base militar" or n == "Búnker H-7":
		return bool(g["main"])
	return true


func _draw_status(vs: Vector2) -> void:
	if status == "" or end_kind != "":
		return
	var pulse := 0.75 + 0.25 * sin(_t * 3.0)
	var sz := _font.get_string_size(status, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	var y := vs.y - 74.0
	draw_rect(Rect2(vs.x * 0.5 - sz.x * 0.5 - 8.0, y - 11.0, sz.x + 16.0, 16.0), Color(0, 0, 0, 0.6))
	_txt(Vector2(0, y), status, 10, Color(0.55, 0.8, 1.0, pulse), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_hint(vs: Vector2) -> void:
	if hint == "" or end_kind != "":
		return
	var pulse := 0.8 + 0.2 * sin(_t * 3.0)
	var sz := _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	var y := vs.y - 56.0
	draw_rect(Rect2(vs.x * 0.5 - sz.x * 0.5 - 8.0, y - 12.0, sz.x + 16.0, 18.0), Color(0, 0, 0, 0.6))
	_txt(Vector2(0, y), hint, 11, Color(0.96, 0.82, 0.3, pulse), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_toasts(vs: Vector2) -> void:
	var y := vs.y - 82.0
	var width := 300.0
	for i in range(_toasts.size() - 1, -1, -1):
		var t: Array = _toasts[i]
		var text: String = t[0]
		var left: float = t[1]
		var alpha := clampf(left / 0.6, 0.0, 1.0)
		var sz := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, 11)
		y -= sz.y + 8.0
		draw_rect(Rect2(vs.x * 0.5 - sz.x * 0.5 - 6.0, y - 3.0, sz.x + 12.0, sz.y + 6.0), Color(0, 0, 0, 0.62 * alpha))
		draw_multiline_string(_font, Vector2(vs.x * 0.5 - width * 0.5, y + 8.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, width, 11, -1, Color(1, 1, 1, alpha))


func _vignette_tex() -> Texture2D:
	if _vignette == null:
		var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
		for y in 36:
			for x in 64:
				var d := Vector2((x - 31.5) / 32.0, (y - 17.5) / 18.0).length()
				img.set_pixel(x, y, Color(1, 1, 1, clampf((d - 0.35) / 0.9, 0.0, 1.0)))
		_vignette = ImageTexture.create_from_image(img)
	return _vignette


## Texto con sombra dura para que se lea sobre cualquier fondo.
func _txt_sh(pos: Vector2, s: String, size: int, col: Color, w: float) -> void:
	_txt(pos + Vector2(1, 1), s, size, Color(0, 0, 0, col.a * 0.9), HORIZONTAL_ALIGNMENT_CENTER, w)
	_txt(pos, s, size, col, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_end(vs: Vector2) -> void:
	var fade := clampf(end_age / 1.4, 0.0, 1.0)
	if end_kind == "dead":
		_draw_dead(vs, fade)
	else:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.62 * fade))
		var mid := vs.y * 0.42
		_txt_sh(Vector2(0, mid), "SUERO H-7", 22, Color(0.945, 0.769, 0.059, fade), vs.x)
		_txt_sh(Vector2(0, mid + 20.0), "Fin del Acto II · Suero H-7  —  Acto III: «La otra voz»", 13, Color(0.95, 0.95, 0.95, fade), vs.x)
		_txt_sh(Vector2(0, mid + 36.0), "Toca la pantalla para seguir explorando", 12, Color(0.8, 0.8, 0.85, fade), vs.x)


func _draw_dead(vs: Vector2, fade: float) -> void:
	# oscurece y tiñe de rojo, con viñeta que se cierra
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.0, 0.0, 0.72 * fade))
	draw_texture_rect(_vignette_tex(), Rect2(Vector2.ZERO, vs), false, Color(0.55, 0.0, 0.02, 0.85 * fade))
	var cx := vs.x * 0.5
	var top := vs.y * 0.2
	# latido que se apaga: linea de electrocardiograma plana
	var ly := top + 6.0
	var pts := PackedVector2Array()
	var x0 := cx - 70.0
	for i in 141:
		var x := float(i)
		var y := 0.0
		if x < 40.0:
			var m := fmod(x, 20.0)
			y = -9.0 * exp(-pow(m - 10.0, 2.0) / 3.0) if end_age < 1.2 else 0.0
		pts.append(Vector2(x0 + x, ly + y))
	draw_polyline(pts, Color(0.85, 0.15, 0.15, 0.7 * fade), 1.0)
	# titulo que crece, con temblor y goteo de sangre
	var k := clampf((end_age - 0.3) / 0.7, 0.0, 1.0)
	var size := int(round(lerpf(46.0, 34.0, k * k * (3.0 - 2.0 * k))))
	var shake := Vector2(sin(_t * 41.0), cos(_t * 37.0)) * (1.0 - k) * 2.0
	var ty := top + 22.0
	_txt_sh(Vector2(0, ty) + shake, "HAS MUERTO", size, Color(0.84, 0.17, 0.17, k), vs.x)
	var drip := clampf((end_age - 0.9) / 1.6, 0.0, 1.0)
	for i in 11:
		var dx := cx + (float(i) - 5.0) * 17.0 + sin(float(i) * 2.3) * 5.0
		var ln := (10.0 + float((i * 13) % 26)) * drip
		draw_rect(Rect2(dx, ty + float(size) + 2.0, 2.0, ln), Color(0.6, 0.05, 0.05, 0.9 * k))
		draw_circle(Vector2(dx + 1.0, ty + float(size) + 2.0 + ln), 2.0, Color(0.6, 0.05, 0.05, 0.9 * k * drip))
	var a := clampf((end_age - 1.0) / 0.8, 0.0, 1.0)
	_txt_sh(Vector2(0, ty + float(size) + 40.0), end_cause, 12, Color(0.92, 0.82, 0.82, a), vs.x)
	# panel con estadisticas
	var py := ty + float(size) + 62.0
	var pw := 340.0
	var panel := Rect2(cx - pw * 0.5, py, pw, 52.0)
	draw_rect(panel, Color(0, 0, 0, 0.5 * a))
	draw_rect(panel, Color(0.7, 0.15, 0.15, 0.7 * a), false, 1.0)
	var secs := int(end_time)
	var stats := "Sobreviviste %d:%02d   ·   Abatidos: %d   ·   Notas: %d/%d" % [secs / 60, secs % 60, Zombie.kills, notes_found, notes_total]
	_txt_sh(Vector2(0, py + 8.0), stats, 10, Color(0.95, 0.9, 0.9, a), vs.x)
	_txt_sh(Vector2(0, py + 24.0), "Último refugio guardado", 10, Color(0.6, 0.85, 0.65, a), vs.x)
	_txt_sh(Vector2(0, py + 37.0), "Consejo: " + end_tip, 9, Color(0.85, 0.85, 0.7, a * 0.9), vs.x)
	# boton de reaparecer
	if end_ready:
		var pulse := 0.65 + 0.35 * sin(_t * 4.0)
		var bw := 150.0
		var btn := Rect2(cx - bw * 0.5, py + 64.0, bw, 22.0)
		draw_rect(btn, Color(0.5, 0.05, 0.05, 0.85 * pulse))
		draw_rect(btn, Color(1.0, 0.45, 0.4, pulse), false, 1.0)
		_txt_sh(Vector2(0, py + 76.0), "TOCA PARA REAPARECER", 11, Color(1, 0.95, 0.9, pulse), vs.x)
