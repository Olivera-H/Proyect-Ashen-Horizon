class_name Minimap
extends Control
## Minimapa estilo GTA: ventana centrada en el jugador, marcadores de objetivos
## (los fuera de rango se pegan al borde), alertas de zombis cercanos, anillo de
## ruido y niebla de guerra que se despeja al explorar.

const SIZE_PX := 112.0
const VIEW_TILES := 48.0     # tiles visibles en la ventana
const PAD := 28              # relleno alrededor del mapa para no salirse de la textura
const REVEAL_R := 11.0       # radio de exploracion en tiles
const NEAR_RADIUS := 150.0   # px de mundo: zombis que se muestran como alerta
const FOG_ALPHA := 0.94

var world: World
var player: Player
var goals: Array = []

var _base_tex: ImageTexture
var _fog_img: Image
var _fog_tex: ImageTexture
var _last_tile := Vector2i(-9999, -9999)
var _font: Font


func setup(w: World, p: Player, g: Array) -> void:
	world = w
	player = p
	goals = g
	_font = ThemeDB.fallback_font
	size = Vector2(SIZE_PX, SIZE_PX)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	var total := Vector2i(World.W + PAD * 2, World.H + PAD * 2)
	var base := Image.create(total.x, total.y, false, Image.FORMAT_RGBA8)
	base.fill(Color("0b0c10"))
	base.blit_rect(w.make_minimap_image(), Rect2i(0, 0, World.W, World.H), Vector2i(PAD, PAD))
	_base_tex = ImageTexture.create_from_image(base)

	_fog_img = Image.create(total.x, total.y, false, Image.FORMAT_RGBA8)
	_fog_img.fill(Color(0.0, 0.0, 0.0, FOG_ALPHA))
	_fog_tex = ImageTexture.create_from_image(_fog_img)


## Fraccion del mapa explorada (0..1), util para estadisticas o logros.
func explored_fraction() -> float:
	var seen := 0
	for y in range(PAD, PAD + World.H):
		for x in range(PAD, PAD + World.W):
			if _fog_img.get_pixel(x, y).a < 0.5:
				seen += 1
	return float(seen) / float(World.W * World.H)


func _reveal(t: Vector2i) -> void:
	var r := int(REVEAL_R)
	for dy in range(-r - 1, r + 2):
		for dx in range(-r - 1, r + 2):
			var d := Vector2(dx, dy).length()
			if d > REVEAL_R + 1.0:
				continue
			var px := t.x + dx + PAD
			var py := t.y + dy + PAD
			if px < 0 or py < 0 or px >= _fog_img.get_width() or py >= _fog_img.get_height():
				continue
			var a := clampf((d - (REVEAL_R - 3.0)) / 3.0, 0.0, 1.0) * FOG_ALPHA
			if a < _fog_img.get_pixel(px, py).a:
				_fog_img.set_pixel(px, py, Color(0.0, 0.0, 0.0, a))
	_fog_tex.update(_fog_img)


func _process(_delta: float) -> void:
	if world == null or player == null:
		return
	var t := world.to_tile(player.global_position)
	if t != _last_tile:
		_last_tile = t
		_reveal(t)
	queue_redraw()


func _to_mm(world_pos: Vector2) -> Vector2:
	var s := SIZE_PX / VIEW_TILES
	var rel := (world_pos - player.global_position) / float(World.TS)
	return Vector2(SIZE_PX, SIZE_PX) * 0.5 + rel * s


func _draw() -> void:
	if world == null or player == null:
		return
	var full := Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX))
	var pt := player.global_position / float(World.TS)
	var src := Rect2(
		pt.x + PAD - VIEW_TILES * 0.5, pt.y + PAD - VIEW_TILES * 0.5, VIEW_TILES, VIEW_TILES
	)
	draw_rect(full, Color(0.02, 0.02, 0.03, 0.92))
	draw_texture_rect_region(_base_tex, full, src)
	draw_texture_rect_region(_fog_tex, full, src)

	var center := full.get_center()
	var s := SIZE_PX / VIEW_TILES
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)

	# anillo de ruido del jugador
	var noise := player.noise_radius()
	if noise > 0.0:
		draw_arc(center, noise / float(World.TS) * s, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.55), 1.0)

	# zombis cercanos: tenues si solo estan cerca, brillantes si te detectaron
	for z in get_tree().get_nodes_in_group("zombies"):
		var dist: float = z.global_position.distance_to(player.global_position)
		if dist > NEAR_RADIUS:
			continue
		var lvl: float = z.alert_level()
		var big: bool = z.kind == "tank"
		var p := _to_mm(z.global_position)
		if lvl > 0.0:
			var rad := (2.6 if big else 1.8) + pulse * 0.8 * lvl
			draw_circle(p, rad, Color(1.0, 0.15, 0.1, 0.95))
		elif dist < NEAR_RADIUS * 0.55:
			draw_circle(p, 1.4, Color(0.75, 0.25, 0.2, 0.55))

	# objetivos (los que quedan fuera de la ventana se pegan al borde)
	for g in goals:
		var gp: Vector2 = g["pos"]
		var main_goal: bool = g["main"]
		var col := Color("f1c40f") if main_goal else Color("5dd6e8")
		var p := _to_mm(gp)
		var inside := full.grow(-6.0).has_point(p)
		var q := Vector2(clampf(p.x, 6.0, SIZE_PX - 6.0), clampf(p.y, 6.0, SIZE_PX - 6.0))
		var r := 4.0 if inside else 3.0
		if main_goal:
			var pts := PackedVector2Array([q + Vector2(0, -r), q + Vector2(r, 0), q + Vector2(0, r), q + Vector2(-r, 0)])
			draw_colored_polygon(pts, col)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.8), 1.0)
		else:
			draw_circle(q, r - 0.5, col)
			draw_arc(q, r, 0.0, TAU, 16, Color(0, 0, 0, 0.8), 1.0)

	# jugador (triangulo orientado hacia donde mira)
	var a := player.facing.angle()
	var tri := PackedVector2Array()
	for v in [Vector2(5, 0), Vector2(-3.5, 3.2), Vector2(-2, 0), Vector2(-3.5, -3.2)]:
		tri.append(center + (v as Vector2).rotated(a))
	draw_colored_polygon(tri, Color("7dff8a"))

	# marco y norte
	draw_rect(full, Color(0.82, 0.84, 0.9, 0.95), false, 1.5)
	if _font != null:
		draw_string(_font, Vector2(SIZE_PX * 0.5 - 3.0, 9.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.85))
