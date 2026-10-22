class_name Hud
extends Control
## HUD: barras de estado, arma y chatarra, reloj, objetivos con distancia,
## avisos temporales y pantallas de muerte / final. El minimapa (con su boton) es hijo de este nodo.

const BAR_W := 64.0
const BAR_H := 6.0

var player: Player
var world: World
var goals: Array = []
var minimap: Minimap
var bars: StatBars
var clock := 0.0
var raining := false
var warning := ""         # aviso de peligro ambiental (aire toxico, lluvia acida)
var notes_found := 0
var notes_total := 0
var end_kind := ""        # "" | "dead" | "won"

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
	minimap = Minimap.new()
	add_child(minimap)
	minimap.setup(w, p, g)


func toast(text: String, seconds: float = 3.0) -> void:
	_toasts.append([text, seconds, seconds])
	while _toasts.size() > 3:
		_toasts.pop_front()


func _process(delta: float) -> void:
	_t += delta
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
	if end_kind != "":
		_draw_end(vs)


func _draw_gear() -> void:
	var x := 10.0
	var y := 116.0
	_txt(Vector2(x, y + 7.0), player.weapon_name, 10, Color(0.85, 0.85, 0.9))
	var frac := player.weapon_durability / Player.WEAPON_MAX
	draw_rect(Rect2(x - 1.0, y + 10.0, 102.0, BAR_H - 1.0), Color(0, 0, 0, 0.7))
	var col := Color("b8bcc4") if frac > 0.25 else Color("d64545")
	draw_rect(Rect2(x, y + 11.0, 100.0 * frac, BAR_H - 3.0), col)
	draw_texture(_scrap_icon, Vector2(x, y + 19.0))
	_txt(Vector2(x + 11.0, y + 26.0), "%d/%d" % [player.scrap, Player.INVENTORY_LIMIT], 10, Color(0.9, 0.9, 0.9))
	if notes_total > 0:
		_txt(Vector2(x + 54.0, y + 26.0), "Notas %d/%d" % [notes_found, notes_total], 10, Color("e8e2cf"))


func _draw_clock(vs: Vector2) -> void:
	var total := int(clock * 1440.0)
	var hh := floori(total / 60.0)
	var mm := total % 60
	_txt(Vector2(0, 18.0), "%02d:%02d" % [hh, mm], 14, Color(0.95, 0.95, 0.95), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if warning != "":
		var pulse := 0.65 + 0.35 * sin(_t * 6.0)
		_txt(Vector2(0, 31.0), warning, 11, Color(1.0, 0.45, 0.3, pulse), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	elif raining:
		_txt(Vector2(0, 31.0), "LLUVIA ÁCIDA", 11, Color("9be564"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_goals(vs: Vector2) -> void:
	var right := vs.x - 10.0
	var y := minimap.list_top() if minimap != null else 14.0
	for g in goals:
		var gp: Vector2 = g["pos"]
		var meters := int(player.global_position.distance_to(gp) / 8.0)
		var col := Color("f1c40f") if g["main"] else Color("5dd6e8")
		_txt(Vector2(0, y), "%s  %d m" % [g["name"], meters], 10, col, HORIZONTAL_ALIGNMENT_RIGHT, right)
		y += 11.0


func _draw_toasts(vs: Vector2) -> void:
	var y := vs.y - 70.0
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


func _draw_end(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.62))
	var mid := vs.y * 0.42
	if end_kind == "dead":
		_txt(Vector2(0, mid), "HAS MUERTO", 28, Color("d64545"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_txt(Vector2(0, mid + 22.0), "Toca la pantalla para reaparecer en el último refugio",
			12, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	else:
		_txt(Vector2(0, mid), "LABORATORIO HORIZONTE", 22, Color("f1c40f"), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_txt(Vector2(0, mid + 20.0), "Fin del prototipo · Acto I de Mateo",
			13, Color(0.95, 0.95, 0.95), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
		_txt(Vector2(0, mid + 36.0), "Toca la pantalla para seguir explorando",
			12, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
