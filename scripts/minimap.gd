class_name Minimap
extends Control
## Minimapa circular estilo GTA, con boton para mostrarlo u ocultarlo.
##
## - Mapa base en alta resolucion (4 px por tile): calles con lineas, aceras, pasto,
##   zona industrial, edificios con techo y puertas visibles.
## - Niebla de guerra que se despeja al explorar (con borde suave).
## - Marcadores: tu posicion y direccion, cono de la linterna, rastro de tus pasos,
##   objetivos (con flechas en el borde si estan lejos), zombis dentro del radar
##   (alertas con pulso), anillo de ruido y barrido de radar.
## - Toque en el mapa = cambia el zoom (3 niveles). Boton del mapa (o tecla M) = mostrar/ocultar.
## - Muestra el sector en el que estas.

const D := 100                 # diametro del circulo (px virtuales)
const BTN := 30                # lado del boton
const GAP := 4
const RIM := 6                 # grosor del marco
const S := 4                   # px de la textura base por tile
const F := 2                   # px de la niebla por tile
const PAD := 48                # tiles de relleno alrededor del mapa (para el zoom maximo)
const ZOOMS := [32.0, 64.0, 96.0]
const REVEAL_R := 11.0         # radio de exploracion (tiles)
const RADAR_RANGE := 224.0     # px de mundo en los que se ven zombis
const FOG_ALPHA := 0.95
const TRAIL_MAX := 28

const COL_VOID := Color("0a0c10")
const COL_ASPHALT := Color("3a3e47")
const COL_ASPHALT_SPECK := Color("2e3139")
const COL_LINE := Color("d6ad2c")
const COL_SIDEWALK := Color("7d818c")
const COL_GRASS := Color("2f5a36")
const COL_GRASS_DARK := Color("264b2d")
const COL_GRASS_LIGHT := Color("3b6b3f")
const COL_DIRT := Color("6b5238")
const COL_DIRT_DARK := Color("574330")
const COL_RUBBLE := Color("8a8478")
const COL_WALL := Color("1c1b20")
const COL_ROOF := Color("b3a995")
const COL_ROOF_ALT := Color("a89e8b")

const CLIP_SHADER := """
shader_type canvas_item;
uniform vec2 center = vec2(64.0, 64.0);
uniform float radius = 61.0;
varying vec2 lpos;
void vertex() { lpos = VERTEX; }
void fragment() { if (distance(lpos, center) > radius) { discard; } }
"""

var world: World
var player: Player
var goals: Array = []
var shown := true
var reveal := 1.0              # 0 = oculto, 1 = visible (animado)

var _view: Control
var _icon: Texture2D
var _font: Font
var _base_tex: ImageTexture
var _fog_img: Image
var _fog_tex: ImageTexture
var _last_tile := Vector2i(-9999, -9999)
var _zoom_i := 1
var _view_tiles := 64.0
var _trail: Array = []
var _trail_t := 0.0
var _press := 0.0
var _zoom_flash := 0.0
var _t := 0.0


func setup(w: World, p: Player, g: Array) -> void:
	world = w
	player = p
	goals = g
	_font = UiFont.get_font()
	if ResourceLoader.exists("res://assets/ui/icon_map.png"):
		_icon = load("res://assets/ui/icon_map.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(BTN + GAP + D, D + 18)
	custom_minimum_size = size

	_view = Control.new()
	_view.size = Vector2(D, D)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = CLIP_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("center", Vector2(D, D) * 0.5)
	mat.set_shader_parameter("radius", D * 0.5 - float(RIM))
	_view.material = mat
	_view.draw.connect(_draw_view)
	add_child(_view)

	_base_tex = _render_base()
	var total := Vector2i((World.W + PAD * 2) * F, (World.H + PAD * 2) * F)
	_fog_img = Image.create(total.x, total.y, false, Image.FORMAT_RGBA8)
	_fog_img.fill(Color(0.02, 0.03, 0.05, FOG_ALPHA))
	_fog_tex = ImageTexture.create_from_image(_fog_img)
	_view_tiles = ZOOMS[_zoom_i]


# ------------------------------------------------------------ mapa base

func _paint_tile(img: Image, x: int, y: int) -> void:
	var t: int = world.tiles[y * World.W + x]
	var o := Vector2i((x + PAD) * S, (y + PAD) * S)
	var h := ((x * 73856093) ^ (y * 19349663)) & 255
	var full := Rect2i(o, Vector2i(S, S))
	var sx := o.x + (h & 3)
	var sy := o.y + ((h >> 2) & 3)
	match t:
		PixelArt.T_ASPHALT, PixelArt.T_ASPHALT2:
			img.fill_rect(full, COL_ASPHALT)
			if h < 40:
				img.set_pixel(sx, sy, COL_ASPHALT_SPECK)
		PixelArt.T_ROAD_LINE:
			img.fill_rect(full, COL_ASPHALT)
			img.fill_rect(Rect2i(o.x, o.y + 1, S, 2), COL_LINE)
		PixelArt.T_SIDEWALK:
			img.fill_rect(full, COL_SIDEWALK)
			if h < 50:
				img.set_pixel(sx, sy, COL_SIDEWALK.darkened(0.12))
		PixelArt.T_GRASS, PixelArt.T_GRASS2:
			img.fill_rect(full, COL_GRASS)
			if h < 90:
				img.set_pixel(sx, sy, COL_GRASS_DARK)
			elif h > 215:
				img.set_pixel(sx, sy, COL_GRASS_LIGHT)
		PixelArt.T_DIRT:
			img.fill_rect(full, COL_DIRT)
			if h < 90:
				img.set_pixel(sx, sy, COL_DIRT_DARK)
		PixelArt.T_RUBBLE:
			img.fill_rect(full, COL_RUBBLE)
			img.set_pixel(sx, sy, COL_RUBBLE.darkened(0.35))
		PixelArt.T_WALL:
			img.fill_rect(full, COL_WALL)
		PixelArt.T_FLOOR:
			img.fill_rect(full, COL_ROOF if (h & 1) == 0 else COL_ROOF_ALT)
		_:
			img.fill_rect(full, COL_VOID)


## Lineas amarillas de las calles (las marcas viales se dibujan aparte del mapa de tiles).
func _paint_road_lines(img: Image) -> void:
	var k := float(S) / float(World.TS)
	for i in world.marks_r.size():
		var c: int = world.marks_c[i]
		if c != StreetMarkings.MK_YELLOW and c != StreetMarkings.MK_YELLOW_OLD:
			continue
		var r: Rect2 = world.marks_r[i]
		var x := int(r.position.x * k) + PAD * S
		var y := int(r.position.y * k) + PAD * S
		var rw := maxi(1, int(round(r.size.x * k)))
		var rh := maxi(1, int(round(r.size.y * k)))
		img.fill_rect(Rect2i(x, y, rw, rh), COL_LINE if c == StreetMarkings.MK_YELLOW else COL_LINE.darkened(0.25))


func _render_base() -> ImageTexture:
	var img := Image.create((World.W + PAD * 2) * S, (World.H + PAD * 2) * S, false, Image.FORMAT_RGBA8)
	img.fill(COL_VOID)
	for y in World.H:
		for x in World.W:
			_paint_tile(img, x, y)
	_paint_road_lines(img)
	# borde del mundo
	var edge := Color("4a5060")
	var w := World.W * S
	var h := World.H * S
	var ox := PAD * S
	var oy := PAD * S
	img.fill_rect(Rect2i(ox - 2, oy - 2, w + 4, 2), edge)
	img.fill_rect(Rect2i(ox - 2, oy + h, w + 4, 2), edge)
	img.fill_rect(Rect2i(ox - 2, oy, 2, h), edge)
	img.fill_rect(Rect2i(ox + w, oy, 2, h), edge)
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------- niebla de guerra

func _clear_fog(t: Vector2i) -> void:
	var rpx := int(ceil((REVEAL_R + 1.0) * float(F)))
	var cpx := (t.x + PAD) * F + int(F / 2.0)
	var cpy := (t.y + PAD) * F + int(F / 2.0)
	var cx := float(t.x) + 0.5
	var cy := float(t.y) + 0.5
	for py in range(cpy - rpx, cpy + rpx + 1):
		for px in range(cpx - rpx, cpx + rpx + 1):
			if px < 0 or py < 0 or px >= _fog_img.get_width() or py >= _fog_img.get_height():
				continue
			var tx := (float(px) + 0.5) / float(F) - float(PAD)
			var ty := (float(py) + 0.5) / float(F) - float(PAD)
			var d := Vector2(tx - cx, ty - cy).length()
			if d > REVEAL_R:
				continue
			var a := clampf((d - (REVEAL_R - 3.0)) / 3.0, 0.0, 1.0) * FOG_ALPHA
			if a < _fog_img.get_pixel(px, py).a:
				_fog_img.set_pixel(px, py, Color(0.02, 0.03, 0.05, a))
	_fog_tex.update(_fog_img)


## Fraccion del mapa explorada (0..1).
func explored_fraction() -> float:
	var seen := 0
	for y in World.H:
		for x in World.W:
			if _fog_img.get_pixel((x + PAD) * F + 1, (y + PAD) * F + 1).a < 0.5:
				seen += 1
	return float(seen) / float(World.W * World.H)


# ------------------------------------------------------------- disposicion

func _ease() -> float:
	return reveal * reveal * (3.0 - 2.0 * reveal)


func circle_x() -> float:
	return float(BTN + GAP) + (float(D) + 14.0) * (1.0 - _ease())


func btn_x() -> float:
	return float(D + GAP) * (1.0 - _ease())


## Donde debe empezar la lista de objetivos (y) para no taparse con el mapa.
func list_top() -> float:
	return lerpf(float(BTN) + 22.0, float(D) + 34.0, _ease())


func _toggle() -> void:
	shown = not shown
	_press = 0.18


func _cycle_zoom() -> void:
	_zoom_i = (_zoom_i + 1) % ZOOMS.size()
	_zoom_flash = 1.2


func _sector_name(t: Vector2i) -> String:
	if t.x >= World.ZONE_ZERO_X:
		return "ZONA CERO"
	if t.x >= World.LAB_X:
		return "LABORATORIO"
	if t.x >= 87:
		return "ZONA INDUSTRIAL"
	var hw: Array = World.H_ROADS[1]
	if t.y >= hw[0] - 1 and t.y <= hw[0] + hw[1]:
		return "AUTOPISTA"
	if t.x < World.V_ROADS[0] - 2:
		return "PERIFERIA"
	return "CASCO URBANO"


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position - global_position
	if Rect2(btn_x(), 0.0, float(BTN), float(BTN)).grow(4.0).has_point(p):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if shown and reveal > 0.9:
		var c := Vector2(circle_x() + float(D) * 0.5, float(D) * 0.5)
		if p.distance_to(c) <= float(D) * 0.5:
			_cycle_zoom()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if world == null or player == null:
		return
	_t += delta
	var vs := get_viewport_rect().size
	position = Vector2(vs.x - size.x - 10.0, 10.0)
	reveal = move_toward(reveal, 1.0 if shown else 0.0, delta * 3.5)
	_press = maxf(0.0, _press - delta)
	_zoom_flash = maxf(0.0, _zoom_flash - delta)
	_view.position = Vector2(circle_x(), 0.0)
	_view.visible = reveal > 0.01
	_view_tiles = lerpf(_view_tiles, ZOOMS[_zoom_i], minf(1.0, delta * 8.0))

	if Input.is_action_just_pressed("toggle_map"):
		_toggle()
	if Input.is_action_just_pressed("zoom_map") and shown:
		_cycle_zoom()

	var t := world.to_tile(player.global_position)
	if t != _last_tile:
		_last_tile = t
		_clear_fog(t)

	_trail_t += delta
	if _trail_t >= 0.45:
		_trail_t = 0.0
		_trail.append(player.global_position)
		if _trail.size() > TRAIL_MAX:
			_trail.pop_front()

	queue_redraw()
	_view.queue_redraw()


# ------------------------------------------------------------------ dibujo

func _txt(pos: Vector2, s: String, size_px: int, col: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size_px, 3, Color(0, 0, 0, 0.9))
	draw_string(_font, pos, s, align, width, size_px, col)


func _draw() -> void:
	if world == null or player == null:
		return
	if reveal > 0.01:
		_draw_frame()
	_draw_button()


func _draw_frame() -> void:
	var c := Vector2(circle_x() + float(D) * 0.5, float(D) * 0.5)
	var r := float(D) * 0.5
	draw_arc(c, r - 1.5, 0.0, TAU, 80, Color("08090c"), 3.0)
	draw_arc(c, r - 1.5, PI * 0.95, PI * 1.65, 40, Color("aeb4c2"), 1.0)      # brillo arriba-izquierda
	draw_arc(c, r - 2.5, PI * 0.05, PI * 0.65, 40, Color("3a3f4c"), 1.0)      # sombra abajo-derecha
	draw_arc(c, r - 3.5, 0.0, TAU, 80, Color("14161c"), 1.0)
	# marcas N, E, S, O
	var tick := Color("c9ced9")
	draw_rect(Rect2(c.x - 1.0, 0.0, 2.0, 3.0), tick)
	draw_rect(Rect2(c.x - 1.0, float(D) - 3.0, 2.0, 3.0), tick)
	draw_rect(Rect2(c.x - r, c.y - 1.0, 3.0, 2.0), tick)
	draw_rect(Rect2(c.x + r - 3.0, c.y - 1.0, 3.0, 2.0), tick)
	# placa del norte
	draw_rect(Rect2(c.x - 6.0, -4.0, 12.0, 11.0), Color("0b0c10"))
	draw_rect(Rect2(c.x - 6.0, -4.0, 12.0, 1.0), Color("aeb4c2"))
	_txt(Vector2(c.x - 6.0, 6.0), "N", 10, Color("f0f2f7"), HORIZONTAL_ALIGNMENT_CENTER, 12.0)
	# sector actual y zoom
	var sector := _sector_name(world.to_tile(player.global_position))
	_txt(Vector2(circle_x(), float(D) + 13.0), sector, 10, Color("cfd6e4"), HORIZONTAL_ALIGNMENT_CENTER, float(D))
	if _zoom_flash > 0.0:
		var label := "ZOOM %d/%d" % [_zoom_i + 1, ZOOMS.size()]
		_txt(Vector2(circle_x(), float(D) - 18.0), label, 10, Color(1, 1, 1, clampf(_zoom_flash, 0.0, 1.0)),
			HORIZONTAL_ALIGNMENT_CENTER, float(D))


func _draw_button() -> void:
	var bx := btn_x()
	var by := 1.0 if _press > 0.0 else 0.0
	var b := float(BTN)
	var plate := Color(0.05, 0.06, 0.08, 0.88)
	var rim := Color("8d95a8") if shown else Color("5a6070")
	# placa con esquinas cortadas
	draw_rect(Rect2(bx + 1.0, by, b - 2.0, b), plate)
	draw_rect(Rect2(bx, by + 1.0, b, b - 2.0), plate)
	draw_rect(Rect2(bx + 1.0, by, b - 2.0, 1.0), rim)
	draw_rect(Rect2(bx + 1.0, by + b - 1.0, b - 2.0, 1.0), Color("20232c"))
	draw_rect(Rect2(bx, by + 1.0, 1.0, b - 2.0), rim)
	draw_rect(Rect2(bx + b - 1.0, by + 1.0, 1.0, b - 2.0), Color("20232c"))
	if _icon != null:
		var tint := Color.WHITE if shown else Color(0.5, 0.5, 0.56, 0.9)
		if _press > 0.0:
			tint = Color(1.5, 1.5, 1.5)
		draw_texture_rect(_icon, Rect2(bx + 3.0, by + 3.0, 24.0, 24.0), false, tint)
	if not shown:
		# tachado rojo: el mapa esta oculto
		draw_line(Vector2(bx + 5.0, by + b - 5.0), Vector2(bx + b - 5.0, by + 5.0), Color(0, 0, 0, 0.9), 4.0)
		draw_line(Vector2(bx + 5.0, by + b - 5.0), Vector2(bx + b - 5.0, by + 5.0), Color("e04a3a"), 2.0)
	else:
		var on := int(_t * 2.0) % 2 == 0
		draw_rect(Rect2(bx + b - 6.0, by + 3.0, 3.0, 3.0), Color("7dff8a") if on else Color("3f9a4a"))


func _draw_view() -> void:
	if world == null or player == null or reveal <= 0.01:
		return
	var v := _view
	var dd := float(D)
	var full := Rect2(0.0, 0.0, dd, dd)
	var center := full.get_center()
	var tiles := _view_tiles
	var ts := dd / tiles                                   # px de pantalla por tile
	var pt := player.global_position / float(World.TS)

	var bs := Rect2(floorf((pt.x + float(PAD) - tiles * 0.5) * float(S)), floorf((pt.y + float(PAD) - tiles * 0.5) * float(S)),
		tiles * float(S), tiles * float(S))
	var origin := Vector2(bs.position) / float(S) - Vector2(float(PAD), float(PAD))   # tile de la esquina sup-izq
	var fs := Rect2((origin.x + float(PAD)) * float(F), (origin.y + float(PAD)) * float(F), tiles * float(F), tiles * float(F))

	v.draw_rect(full, COL_VOID)
	v.draw_texture_rect_region(_base_tex, full, bs)
	v.draw_texture_rect_region(_fog_tex, full, fs)

	# barrido de radar (decorativo)
	var sweep := fposmod(_t * 1.5, TAU)
	var rr := dd * 0.5
	for k in 5:
		var a0 := sweep - float(k) * 0.09
		var a1 := sweep - float(k + 1) * 0.09
		var pts := PackedVector2Array([center, center + Vector2.from_angle(a0) * rr, center + Vector2.from_angle(a1) * rr])
		v.draw_colored_polygon(pts, Color(0.45, 1.0, 0.55, 0.075 - float(k) * 0.013))

	# rastro de pasos
	for i in _trail.size():
		var wp: Vector2 = _trail[i]
		var p := _to_mm(wp, origin, ts)
		var a := float(i + 1) / float(_trail.size())
		v.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(0.7, 1.0, 0.75, 0.15 + 0.55 * a))

	var pc := _to_mm(player.global_position, origin, ts)

	# cono de la linterna
	if player.flashlight_on:
		var len_px := 10.0 * ts
		var f := player.facing.angle()
		var cone := PackedVector2Array([pc, pc + Vector2.from_angle(f - 0.5) * len_px, pc + Vector2.from_angle(f + 0.5) * len_px])
		v.draw_colored_polygon(cone, Color(1.0, 0.95, 0.65, 0.14))

	# anillo del radar (rango en que se ven zombis), punteado
	var radar_px := RADAR_RANGE / float(World.TS) * ts
	if radar_px < dd * 0.5 - 4.0:
		for k in 28:
			var a0 := float(k) * TAU / 28.0
			v.draw_arc(pc, radar_px, a0, a0 + TAU / 56.0, 3, Color(1, 1, 1, 0.22), 1.0)

	# anillo de ruido
	var noise := player.noise_radius()
	if noise > 0.0:
		var np := noise / float(World.TS) * ts
		v.draw_arc(pc, np, 0.0, TAU, 48, Color(1.0, 0.9, 0.3, 0.7), 1.0)
		v.draw_arc(pc, np * 0.8, 0.0, TAU, 48, Color(1.0, 0.9, 0.3, 0.25), 1.0)

	# zombis dentro del radar
	var pulse := fposmod(_t * 1.8, 1.0)
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.global_position.distance_to(player.global_position) > RADAR_RANGE:
			continue
		var lvl: float = z.alert_level()
		var kind: String = z.kind
		var zp := _to_mm(z.global_position, origin, ts).round()
		var sz := 5.0 if kind == "tank" else 3.0
		var col := Color(0.72, 0.26, 0.24, 0.6)
		if lvl >= 1.0:
			col = Color("ff3b30") if kind != "runner" else Color("ff4d9a")
		elif lvl > 0.0:
			col = Color("ff9f2e")
		v.draw_rect(Rect2(zp - Vector2(sz * 0.5, sz * 0.5).floor(), Vector2(sz, sz)), Color(0, 0, 0, 0.8))
		v.draw_rect(Rect2(zp - Vector2(sz * 0.5, sz * 0.5).floor() + Vector2(1, 1), Vector2(sz - 2.0, sz - 2.0)), col)
		if lvl > 0.0:
			var ph := fposmod(pulse + float(z.get_instance_id() % 7) * 0.13, 1.0)
			v.draw_arc(zp, 2.0 + ph * 7.0, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.8 * (1.0 - ph)), 1.0)

	# objetivos
	var edge_r := rr - 9.0
	for g in goals:
		if not Hud.goal_visible(g, player):
			continue
		var gp: Vector2 = g["pos"]
		var main_goal: bool = g["main"]
		var gcol := Color("f1c40f") if main_goal else Color("5dd6e8")
		var p := _to_mm(gp, origin, ts)
		var off := p - center
		if off.length() > edge_r:
			var dir := off.normalized()
			var tip := center + dir * (edge_r + 5.0)
			var side := Vector2(-dir.y, dir.x)
			var tri := PackedVector2Array([tip, tip - dir * 7.0 + side * 4.0, tip - dir * 7.0 - side * 4.0])
			v.draw_colored_polygon(tri, gcol)
			v.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0, 0, 0, 0.9), 1.0)
		else:
			var bob := 1.0 if int(_t * 3.0) % 2 == 0 else 0.0
			p = p.round()
			if main_goal:
				var r2 := 5.0
				var diamond := PackedVector2Array([p + Vector2(0, -r2 - bob), p + Vector2(r2, -bob), p + Vector2(0, r2 - bob), p + Vector2(-r2, -bob)])
				v.draw_colored_polygon(diamond, gcol)
				v.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color(0, 0, 0, 0.9), 1.0)
				v.draw_arc(p, 6.0 + fposmod(_t * 2.0, 1.0) * 6.0, 0.0, TAU, 24, Color(gcol.r, gcol.g, gcol.b, 0.6 * (1.0 - fposmod(_t * 2.0, 1.0))), 1.0)
			else:
				v.draw_circle(p, 4.0, Color(0, 0, 0, 0.9))
				v.draw_circle(p, 3.0, gcol)

	# jugador
	var a := player.facing.angle()
	var tri_pts := PackedVector2Array()
	for q in [Vector2(6, 0), Vector2(-4, 4), Vector2(-2, 0), Vector2(-4, -4)]:
		tri_pts.append(pc + (q as Vector2).rotated(a))
	v.draw_colored_polygon(tri_pts, Color("7dff8a"))
	v.draw_polyline(PackedVector2Array([tri_pts[0], tri_pts[1], tri_pts[2], tri_pts[3], tri_pts[0]]), Color(0, 0, 0, 0.95), 1.0)


func _to_mm(world_pos: Vector2, origin: Vector2, ts: float) -> Vector2:
	return (world_pos / float(World.TS) - origin) * ts
