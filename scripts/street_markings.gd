class_name StreetMarkings
extends Node2D
## Marcas viales y bordillos, dibujados con rectangulos a coordenadas enteras para que
## queden nitidos. World guarda los datos (marks_r / marks_c) y este nodo solo los pinta.
##
## - Bordillos con labio claro y cara oscura (sin bordillo junto a las cebras: rampa).
## - Autopista de 4 carriles: doble linea amarilla, lineas blancas discontinuas, bordes.
## - Calles menores: linea amarilla discontinua.
## - Cebras en los 4 lados de cada interseccion, lineas de pare y flechas de carril.
## - La pintura esta desgastada: tonos mas apagados y huecos al azar.

const TS := 16

const MK_WHITE := 0
const MK_WHITE_OLD := 1
const MK_YELLOW := 2
const MK_YELLOW_OLD := 3
const MK_CURB := 4
const MK_CURB_FACE := 5
const MK_SHADOW := 6

const COLORS := [
	Color("d6d3c2"),   # blanco
	Color("a6a496"),   # blanco desgastado
	Color("d0a424"),   # amarillo
	Color("9a8030"),   # amarillo desgastado
	Color("9b9b94"),   # bordillo (labio)
	Color("5e5e59"),   # bordillo (cara)
	Color(0.0, 0.0, 0.0, 0.28),   # sombra del bordillo
]

var world: World


func setup(w: World) -> void:
	world = w
	# Optimizacion: las marcas (decenas de miles de rectangulos) se reparten en trozos de 256 px,
	# asi el motor solo dibuja los que estan en pantalla en vez de todo el mapa en cada fotograma.
	var groups := {}
	for i in world.marks_r.size():
		var r: Rect2 = world.marks_r[i]
		var key := Vector2i(floori(r.get_center().x / CHUNK), floori(r.get_center().y / CHUNK))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(i)
	for key in groups:
		var ch := Chunk.new()
		ch.rects = []
		ch.cols = []
		for i in groups[key]:
			ch.rects.append(world.marks_r[i])
			ch.cols.append(COLORS[world.marks_c[i]])
		add_child(ch)


const CHUNK := 256.0


class Chunk extends Node2D:
	var rects: Array = []
	var cols: Array = []

	func _draw() -> void:
		for i in rects.size():
			draw_rect(rects[i], cols[i])


# ------------------------------------------------------------ construccion

static func build(w: World) -> void:
	w.marks_r.clear()
	w.marks_c.clear()
	w.crosswalk_tiles.clear()
	_crosswalk_tiles(w)
	_curbs(w)
	_road_lines(w)
	_intersections(w)


static func _push(w: World, r: Rect2, c: int) -> void:
	w.marks_r.append(r)
	w.marks_c.append(c)


static func _is_road(w: World, t: Vector2i) -> bool:
	if not w.in_bounds(t):
		return false
	var id := w.tile_id(t)
	return id == PixelArt.T_ASPHALT or id == PixelArt.T_ASPHALT2 or id == PixelArt.T_RUBBLE


## Pintura con desgaste. Se recorta por tile para no pintar sobre escombros.
static func _paint(w: World, x: float, y: float, wd: float, h: float, c: int) -> void:
	var tx0 := int(floorf(x / TS))
	var tx1 := int(floorf((x + wd - 0.01) / TS))
	var ty0 := int(floorf(y / TS))
	var ty1 := int(floorf((y + h - 0.01) / TS))
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			var t := Vector2i(tx, ty)
			if not w.in_bounds(t) or w.is_solid_tile(t) or w.tile_id(t) == PixelArt.T_RUBBLE:
				continue
			var r := Rect2(x, y, wd, h).intersection(Rect2(tx * TS, ty * TS, TS, TS))
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				continue
			var col := c
			if (c == MK_WHITE or c == MK_YELLOW) and w.rng.randf() < 0.3:
				col = c + 1
			if w.rng.randf() < 0.1 and maxf(r.size.x, r.size.y) >= 8.0:
				if r.size.x >= r.size.y:
					var gx := w.rng.randi_range(2, int(r.size.x) - 4)
					var gw := w.rng.randi_range(2, 3)
					_push(w, Rect2(r.position.x, r.position.y, gx, r.size.y), col)
					_push(w, Rect2(r.position.x + gx + gw, r.position.y, r.size.x - gx - gw, r.size.y), col)
				else:
					var gy := w.rng.randi_range(2, int(r.size.y) - 4)
					var gh := w.rng.randi_range(2, 3)
					_push(w, Rect2(r.position.x, r.position.y, r.size.x, gy), col)
					_push(w, Rect2(r.position.x, r.position.y + gy + gh, r.size.x, r.size.y - gy - gh), col)
				continue
			_push(w, r, col)


static func _crosswalk_tiles(w: World) -> void:
	for vx in World.V_ROADS:
		for hr in World.H_ROADS:
			var hy: int = hr[0]
			var hh: int = hr[1]
			for y in range(hy, hy + hh):
				w.crosswalk_tiles[Vector2i(vx - 1, y)] = true
				w.crosswalk_tiles[Vector2i(vx + World.ROAD_W, y)] = true
			for x in range(vx, vx + World.ROAD_W):
				w.crosswalk_tiles[Vector2i(x, hy - 1)] = true
				w.crosswalk_tiles[Vector2i(x, hy + hh)] = true


static func _curbs(w: World) -> void:
	for y in World.H:
		for x in World.W:
			var t := Vector2i(x, y)
			if w.tile_id(t) != PixelArt.T_SIDEWALK:
				continue
			var px := float(x * TS)
			var py := float(y * TS)
			var s := Vector2i(x, y + 1)
			var n := Vector2i(x, y - 1)
			var e := Vector2i(x + 1, y)
			var o := Vector2i(x - 1, y)
			if _is_road(w, s) and not w.crosswalk_tiles.has(s):
				_push(w, Rect2(px, py + 12, TS, 1), MK_CURB)
				_push(w, Rect2(px, py + 13, TS, 3), MK_CURB_FACE)
				_push(w, Rect2(px, py + TS, TS, 2), MK_SHADOW)
			if _is_road(w, n) and not w.crosswalk_tiles.has(n):
				_push(w, Rect2(px, py, TS, 2), MK_CURB)
			if _is_road(w, e) and not w.crosswalk_tiles.has(e):
				_push(w, Rect2(px + 14, py, 2, TS), MK_CURB)
				_push(w, Rect2(px + TS, py, 1, TS), MK_SHADOW)
			if _is_road(w, o) and not w.crosswalk_tiles.has(o):
				_push(w, Rect2(px, py, 2, TS), MK_CURB)


# ----------------------------------------------------------------- lineas

## Parte [a, b) en tramos quitando las zonas prohibidas.
static func _cut(a: float, b: float, zones: Array) -> Array:
	var segs: Array = [Vector2(a, b)]
	for z in zones:
		var next: Array = []
		for sg in segs:
			var s: Vector2 = sg
			if s.y <= z.x or s.x >= z.y:
				next.append(s)
				continue
			if s.x < z.x:
				next.append(Vector2(s.x, z.x))
			if s.y > z.y:
				next.append(Vector2(z.y, s.y))
		segs = next
	return segs


static func _x_zones() -> Array:
	var z: Array = []
	for vx in World.V_ROADS:
		z.append(Vector2((vx - 2) * TS, (vx + World.ROAD_W + 2) * TS))
	return z


static func _y_zones() -> Array:
	var z: Array = []
	for hr in World.H_ROADS:
		z.append(Vector2((hr[0] - 2) * TS, (hr[0] + hr[1] + 2) * TS))
	return z


## Linea horizontal (dash = gap = 0: continua).
static func _hline(w: World, y: float, th: float, x0: float, x1: float, dash: float, gap: float, c: int, zones: Array) -> void:
	var step := dash + gap
	var x := x0
	while x < x1:
		var e := x1 if dash <= 0.0 else minf(x + dash, x1)
		for sg in _cut(x, e, zones):
			var s: Vector2 = sg
			if s.y - s.x >= 2.0:
				_paint(w, s.x, y, s.y - s.x, th, c)
		if step <= 0.0:
			break
		x += step


static func _vline(w: World, x: float, th: float, y0: float, y1: float, dash: float, gap: float, c: int, zones: Array) -> void:
	var step := dash + gap
	var y := y0
	while y < y1:
		var e := y1 if dash <= 0.0 else minf(y + dash, y1)
		for sg in _cut(y, e, zones):
			var s: Vector2 = sg
			if s.y - s.x >= 2.0:
				_paint(w, x, s.x, th, s.y - s.x, c)
		if step <= 0.0:
			break
		y += step


static func _road_lines(w: World) -> void:
	var xz := _x_zones()
	var yz := _y_zones()
	var ww := float(World.W * TS)
	var hh_px := float(World.H * TS)
	for hi in World.H_ROADS.size():
		var hr: Array = World.H_ROADS[hi]
		var y0 := float(hr[0] * TS)
		if hi == World.HW:
			var h := float(hr[1] * TS)
			_hline(w, y0 + 2, 2, 0, ww, 0, 0, MK_WHITE, xz)                  # borde norte
			_hline(w, y0 + h - 4, 2, 0, ww, 0, 0, MK_WHITE, xz)              # borde sur
			_hline(w, y0 + 2 * TS - 1, 2, 0, ww, 14, 18, MK_WHITE, xz)       # carril discontinuo norte
			_hline(w, y0 + 6 * TS - 1, 2, 0, ww, 14, 18, MK_WHITE, xz)       # carril discontinuo sur
			_hline(w, y0 + 4 * TS - 3, 2, 0, ww, 0, 0, MK_YELLOW, xz)        # doble amarilla
			_hline(w, y0 + 4 * TS + 1, 2, 0, ww, 0, 0, MK_YELLOW, xz)
		else:
			_hline(w, y0 + 23, 2, 0, ww, 12, 12, MK_YELLOW, xz)
	for vx in World.V_ROADS:
		_vline(w, float(vx * TS + 23), 2, 0, hh_px, 12, 12, MK_YELLOW, yz)


# ----------------------------------------------------------- intersecciones

static func _arrow(w: World, cx: float, cy: float, dir: int) -> void:
	# flecha recta de 22 px (cuerpo + cabeza), apuntando a la derecha (dir = 1) o a la izquierda (-1)
	var x0 := cx - 11.0
	if dir > 0:
		_paint(w, x0, cy - 1, 14, 3, MK_WHITE)
	else:
		_paint(w, x0 + 8, cy - 1, 14, 3, MK_WHITE)
	for i in 8:
		var half := 4 - i / 2
		var px := x0 + 14.0 + float(i) if dir > 0 else x0 + 7.0 - float(i)
		_paint(w, px, cy - float(half), 1, float(half * 2 + 1), MK_WHITE)


static func _intersections(w: World) -> void:
	for vx in World.V_ROADS:
		for hi in World.H_ROADS.size():
			var hr: Array = World.H_ROADS[hi]
			var hy: int = hr[0]
			var hh: int = hr[1]
			var x_w := float((vx - 1) * TS)                      # cebra oeste (cruza la calle horizontal)
			var x_e := float((vx + World.ROAD_W) * TS)           # cebra este
			var y_n := float((hy - 1) * TS)                      # cebra norte (cruza la calle vertical)
			var y_s := float((hy + hh) * TS)                     # cebra sur
			var road_top := float(hy * TS)
			var road_h := float(hh * TS)
			var road_left := float(vx * TS)
			var road_w := float(World.ROAD_W * TS)
			# cebras: barras de 4 px separadas 4 px
			for k in hh * 2:
				var by := road_top + 2.0 + 8.0 * float(k)
				_paint(w, x_w + 1, by, 14, 4, MK_WHITE)
				_paint(w, x_e + 1, by, 14, 4, MK_WHITE)
			for k in World.ROAD_W * 2:
				var bx := road_left + 2.0 + 8.0 * float(k)
				_paint(w, bx, y_n + 1, 4, 14, MK_WHITE)
				_paint(w, bx, y_s + 1, 4, 14, MK_WHITE)
			# lineas de pare (trafico por la derecha): solo en los carriles que se acercan
			var cy := road_top + road_h * 0.5
			var cx := road_left + road_w * 0.5
			_paint(w, float((vx - 2) * TS) + 9, cy + 2, 3, road_top + road_h - 1 - (cy + 2), MK_WHITE)    # oeste: hacia el este = mitad sur
			_paint(w, float((vx + World.ROAD_W + 1) * TS) + 4, road_top + 1, 3, cy - 2 - (road_top + 1), MK_WHITE)   # este: hacia el oeste = mitad norte
			_paint(w, road_left + 1, float((hy - 2) * TS) + 9, cx - 2 - (road_left + 1), 3, MK_WHITE)     # norte: hacia el sur = mitad oeste
			_paint(w, cx + 2, float((hy + hh + 1) * TS) + 4, road_left + road_w - 1 - (cx + 2), 3, MK_WHITE)   # sur: hacia el norte = mitad este
			# flechas de carril en la autopista
			if hi == World.HW:
				for lane in 4:
					var lcy := road_top + 16.0 + 32.0 * float(lane)
					if lane >= 2:
						_arrow(w, float((vx - 2) * TS) - 36.0, lcy, 1)
					else:
						_arrow(w, float((vx + World.ROAD_W + 2) * TS) + 36.0, lcy, -1)
