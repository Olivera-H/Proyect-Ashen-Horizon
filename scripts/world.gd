class_name World
extends Node2D
## Mundo procedural de prueba: calles, aceras, edificios con puertas, barricadas
## en la autopista y una zona industrial al este. Genera el TileMap, las
## colisiones, los objetivos, los puntos de botin y los puntos de aparicion.

const W := 224
const H := 120
const TS := PixelArt.TILE
const ZOMBIE_COUNT := 140

const V_ROADS := [20, 52, 84, 116, 176]                 # x inicial de cada calle vertical
const H_ROADS := [[18, 3], [46, 8], [74, 3], [98, 3]]  # [y inicial, ancho]; la de 8 es la autopista (4 carriles)
const HW := 1                                 # indice de la autopista en H_ROADS (la calle del medio)
const ROAD_W := 3
const LAB_X := 120                            # desde aqui empieza el complejo del laboratorio
const ZONE_ZERO_X := 180                      # zona contaminada del extremo este
const INDUSTRIAL_X := 87                      # desde aqui empieza la zona industrial
const TERRAIN_PATH := "res://assets/world/terrain.png"
const ATLAS_COLS := 16
const ATLAS_ROWS := 6

var tiles := PackedByteArray()
var solid := PackedByteArray()
var buildings: Array = []      # {rect: Rect2i, door: Vector2i}
var objectives: Array = []     # {name, pos, main}
var loot_spots: Array = []     # {pos, kind}
var zombie_spawns: Array = []  # Vector2
var start_pos := Vector2.ZERO
var vari := PackedByteArray()          # variante visual de cada tile (columna/fila en terrain.png)
var prop_block := PackedByteArray()    # 1 = hay un objeto (arbol, poste...) en este tile
var marks_r: Array = []                # marcas viales y bordillos: rectangulos en px de mundo
var marks_c := PackedByteArray()       # color de cada marca (ver StreetMarkings)
var crosswalk_tiles := {}              # tiles con cebra (sin bordillo al lado)
var props: Array = []                  # objetos de calle: {kind, pos, flip, mode}
var decals: Array = []                 # manchas en el suelo: {kind, pos, a, rot}
var markings: StreetMarkings
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var fence := {}   # cercado del refugio (el ultimo de `fences` creado para el)                        # cercado del refugio: {ring: Rect2i, gate: [x0, x1]}
var house_boxes: Array = []           # cajas de colision de muebles y tabiques (px de mundo)
var refuge_zone := Rect2i()           # refugio + patio cercado: aqui no nacen zombis
var lab_b := {}
var bunker_b := {}
var bunker_door_body: StaticBody2D
var bunker_door_rect := Rect2()
var bunker_terminal := Vector2.ZERO
var base_b := {}
var base_ring := Rect2i()
var lab_door_body: StaticBody2D
var lab_door_rect := Rect2()
var lab_terminal := Vector2.ZERO
var fences: Array = []              # cercados: refugio y laboratorio
var refuge_b := {}
var hospital_b := {}
var safe_rect := Rect2()       # refugio asegurado: los zombis pierden el rastro adentro

var rng := RandomNumberGenerator.new()
var _layer: TileMapLayer
var _body: StaticBody2D


func size_px() -> Vector2:
	return Vector2(W * TS, H * TS)


func to_tile(p: Vector2) -> Vector2i:
	return Vector2i(int(floorf(p.x / TS)), int(floorf(p.y / TS)))


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * TS + TS * 0.5, t.y * TS + TS * 0.5)


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H


func is_solid_tile(t: Vector2i) -> bool:
	return not in_bounds(t) or solid[t.y * W + t.x] == 1


func tile_id(t: Vector2i) -> int:
	return tiles[t.y * W + t.x]


func _put(x: int, y: int, t: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		tiles[y * W + x] = t


func _put_v(x: int, y: int, t: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		tiles[y * W + x] = t
		vari[y * W + x] = v


func _put_solid(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		solid[y * W + x] = v


func _is_road(x: int, y: int) -> bool:
	for vx in V_ROADS:
		if x >= vx and x < vx + ROAD_W:
			return true
	for hr in H_ROADS:
		if y >= hr[0] and y < hr[0] + hr[1]:
			return true
	return false


func generate(seed_value: int = 20261021) -> void:
	add_to_group("world")
	rng.seed = seed_value
	tiles.resize(W * H)
	solid.resize(W * H)
	solid.fill(0)
	vari.resize(W * H)
	vari.fill(0)
	prop_block.resize(W * H)
	prop_block.fill(0)
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	noise2.seed = seed_value + 99
	noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise2.frequency = 0.07
	noise2.fractal_octaves = 2
	_fill_terrain()
	_lay_roads()
	_place_buildings()
	_scatter_details()
	_pick_start_and_objectives()
	StreetMarkings.build(self)
	StreetProps.place(self)
	_pick_loot_and_spawns()
	_build_tilemap()
	_build_colliders()
	markings = StreetMarkings.new()
	markings.setup(self)
	add_child(markings)


# ------------------------------------------------------------ generacion

func _fill_terrain() -> void:
	for y in H:
		for x in W:
			# transicion irregular entre el cesped y la tierra industrial
			var dirt := x >= INDUSTRIAL_X
			if not dirt and x >= INDUSTRIAL_X - 5:
				dirt = rng.randf() < smoothstep(float(INDUSTRIAL_X - 5), float(INDUSTRIAL_X + 1), float(x) + rng.randf() * 3.0) * 0.8
			if dirt:
				_put_v(x, y, PixelArt.T_DIRT, _dirt_variant())
			else:
				_put_v(x, y, PixelArt.T_GRASS, _grass_variant(x, y))


## Nivel de sequedad del cesped (0 exuberante .. 1 ceniza): ruido + mas seco hacia el este.
func dryness(x: int, y: int) -> float:
	var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
	return clampf(n * 0.75 + float(x) / float(W) * 0.45 - 0.05, 0.0, 0.999)


func _grass_variant(x: int, y: int) -> int:
	# el ruido de sequedad lleva un temblor por casilla: los bordes entre zonas salen irregulares
	var tier := int(clampf(dryness(x, y) + (rng.randf() - 0.5) * 0.16, 0.0, 0.999) * 5.0)
	var r := rng.randf()
	if r < 0.04 and tier <= 1:
		return 16 + rng.randi_range(0, 3)                       # flores
	if r < 0.095 and tier <= 3:
		return 16 + (rng.randi_range(4, 6) if tier <= 1 else rng.randi_range(7, 9))   # hierba alta
	if r < 0.115:
		return 16 + 10 + rng.randi_range(0, 1)                  # tierra pisada
	if r < 0.123 and tier >= 2:
		return 16 + 12                                          # piedras
	if r < 0.14 and tier >= 3:
		return 16 + 13                                          # hojarasca
	if r < 0.15 and tier <= 1:
		return 16 + 14                                          # trebol
	if r < 0.155:
		return 16 + 15                                          # charco
	return tier * 3 + rng.randi_range(0, 2)


func _dirt_variant() -> int:
	var r := rng.randf()
	if r < 0.06:
		return 4 + rng.randi_range(0, 1)
	if r < 0.09:
		return 6 + rng.randi_range(0, 1)
	if r < 0.12:
		return 8 + rng.randi_range(0, 1)
	if r < 0.125:
		return 10
	if r < 0.17:
		return 11 + rng.randi_range(0, 1)
	if r < 0.19:
		return 13
	if r < 0.205:
		return 14
	if r < 0.24:
		return 15
	return rng.randi_range(0, 3)


func _asphalt_var(tracks: bool) -> int:
	var r := rng.randf()
	if tracks and r < 0.3:
		return 13 + rng.randi_range(0, 1)                       # huella de neumaticos
	r = rng.randf()
	if r < 0.03:
		return 6
	if r < 0.045:
		return 7
	if r < 0.075:
		return 8 + rng.randi_range(0, 1)
	if r < 0.12:
		return 4 + rng.randi_range(0, 1)
	if r < 0.135:
		return 15
	if r < 0.185:
		return 10 + rng.randi_range(0, 1)
	if r < 0.2:
		return 12
	return rng.randi_range(0, 3)


func _sidewalk_var() -> int:
	var r := rng.randf()
	if r < 0.05:
		return 4 + rng.randi_range(0, 1)
	if r < 0.065:
		return 6
	if r < 0.085:
		return 7
	if r < 0.105:
		return 8
	if r < 0.12:
		return 9
	if r < 0.14:
		return 10
	if r < 0.16:
		return 11
	if r < 0.18:
		return 12
	if r < 0.22:
		return 13
	return rng.randi_range(0, 3)


func _put_side(x: int, y: int) -> void:
	_put_v(x, y, PixelArt.T_SIDEWALK, _sidewalk_var())


func _put_road(x: int, y: int, tracks: bool) -> void:
	var v := _asphalt_var(tracks)
	var t := PixelArt.T_ASPHALT
	if v in [4, 5, 6, 7, 15]:
		t = PixelArt.T_ASPHALT2
	_put_v(x, y, t, v)


## true si x (en tiles) cae en la zona de una interseccion (cruces, lineas de pare).
func near_cross_x(x: int) -> bool:
	for vx in V_ROADS:
		if x >= vx - 2 and x <= vx + 4:
			return true
	return false


func _lay_roads() -> void:
	# aceras
	for vx in V_ROADS:
		for y in H:
			for x in range(vx - 1, vx + ROAD_W + 1):
				_put_side(x, y)
	for hr in H_ROADS:
		for y in range(hr[0] - 1, hr[0] + hr[1] + 1):
			for x in W:
				_put_side(x, y)
	# asfalto (las lineas, cebras y bordillos los pinta StreetMarkings)
	for vx in V_ROADS:
		for y in H:
			for x in range(vx, vx + ROAD_W):
				_put_road(x, y, false)
	for hi in H_ROADS.size():
		var hr: Array = H_ROADS[hi]
		for y in range(hr[0], hr[0] + hr[1]):
			for x in W:
				_put_road(x, y, hi == HW and not near_cross_x(x))
	# barricadas en la autopista: dejan un solo carril libre (2 tiles)
	var hw: Array = H_ROADS[HW]
	var gap_low := true
	for bx in [30, 62, 96]:
		for y in range(hw[0], hw[0] + hw[1]):
			var is_gap: bool = (y >= hw[0] + hw[1] - 2) if gap_low else (y < hw[0] + 2)
			if is_gap:
				continue
			for x in range(bx, bx + 2):
				_put_v(x, y, PixelArt.T_RUBBLE, rng.randi_range(0, 7))
				_put_solid(x, y, 1)
		gap_low = not gap_low


func _block_ranges() -> Array:
	var xs: Array = [[0, V_ROADS[0] - 2]]
	for i in V_ROADS.size():
		var x0: int = V_ROADS[i] + ROAD_W + 1
		var x1: int = (V_ROADS[i + 1] - 2) if i + 1 < V_ROADS.size() else W - 1
		xs.append([x0, x1])
	var ys: Array = [[0, H_ROADS[0][0] - 2]]
	for i in H_ROADS.size():
		var y0: int = H_ROADS[i][0] + H_ROADS[i][1] + 1
		var y1: int = (H_ROADS[i + 1][0] - 2) if i + 1 < H_ROADS.size() else H - 1
		ys.append([y0, y1])
	var blocks: Array = []
	for xr in xs:
		for yr in ys:
			blocks.append(Rect2i(xr[0], yr[0], xr[1] - xr[0] + 1, yr[1] - yr[0] + 1))
	return blocks


## Vecindarios: en cada manzana, una fila de casas con la fachada hacia la calle del sur,
## separadas por patios, con un caminito de la puerta hasta la acera.
func _place_buildings() -> void:
	var residential := ["cabana", "casa", "chalet", "casita"]
	for block in _block_ranges():
		if block.position.x == 120 and block.position.y == 22:
			_build_house(Vector2i(130, 23), "laboratorio", block)
			lab_b = buildings[buildings.size() - 1]
			_build_fence_ring(lab_b, Rect2i(126, 22, 44, 23), "horizonte_sign")
			continue
		if block.position.x == 120 and block.position.y == 55:
			_build_base(block)
			continue
		if block.position.x == 24 and block.position.y == 22:
			# bloque reservado al refugio: casa con un gran patio cercado (futuro huerto)
			_build_house(Vector2i(28, 27), "chalet", block)
			refuge_b = buildings[buildings.size() - 1]
			_build_fence_ring(refuge_b, Rect2i(25, 23, 25, 21), "refuge_sign")
			fence = fences[fences.size() - 1]
			continue
		if block.position.x == 180 and block.position.y == 22:
			_build_house(Vector2i(189, 26), "bunker", block)
			bunker_b = buildings[buildings.size() - 1]
			_build_fence_ring(bunker_b, Rect2i(185, 25, 26, 17), "zero_sign")
			continue
		var industrial: bool = block.position.x >= INDUSTRIAL_X
		var downtown: bool = block.position.x >= 56 and not industrial
		var kinds: Array = ["taller"] if industrial else residential.duplicate()
		var forced: Array = []
		var civic := {Vector2i(56, 22): "iglesia", Vector2i(56, 55): "supermercado", Vector2i(56, 78): "hospital",
			Vector2i(56, 102): "comisaria", Vector2i(24, 102): "supermercado", Vector2i(88, 102): "cancha"}
		var key := Vector2i(block.position.x, block.position.y)
		if downtown:
			kinds = ["tienda", "casita", "apartamentos", "casa"]
			forced = [civic[key]] if civic.has(key) else ["tienda", "casita"]
		elif not industrial and block.position.x >= 24:
			kinds.append("apartamentos")
			if civic.has(key):
				forced = [civic[key]]
		elif industrial and civic.has(key):
			forced = [civic[key]]
		var x: int = block.position.x + rng.randi_range(1, 2)
		var count := 0
		for fk in forced:
			var fd: Dictionary = HouseData.TYPES[fk]
			if x + fd["w"] <= block.end.x and fd["h"] + 4 <= block.size.y:
				_place_in_row(Vector2i(x, 0), fk, block)
				count += 1
				x += fd["w"] + rng.randi_range(3, 5)
		var guard := 0
		while guard < 8:
			guard += 1
			var options: Array = []
			for k in kinds:
				var d: Dictionary = HouseData.TYPES[k]
				if x + d["w"] <= block.end.x and d["h"] + 4 <= block.size.y:
					options.append(k)
			if options.is_empty():
				break
			if count > 0 and rng.randf() < 0.18:
				x += rng.randi_range(4, 7)   # un lote vacio
				continue
			var kind: String = options[rng.randi() % options.size()]
			var d2: Dictionary = HouseData.TYPES[kind]
			_place_in_row(Vector2i(x, 0), kind, block)
			count += 1
			x += d2["w"] + rng.randi_range(3, 5)


func _place_in_row(at: Vector2i, kind: String, block: Rect2i) -> void:
	var d: Dictionary = HouseData.TYPES[kind]
	var bottom: int = block.end.y - rng.randi_range(3, 4)      # patio delantero
	var y: int = bottom - d["h"] + 1
	if y < block.position.y:
		y = block.position.y
	_build_house(Vector2i(at.x, y), kind, block)


## Base militar: patio de concreto cercado con un cuartel; muchos infectados y armas serias.
func _build_base(block: Rect2i) -> void:
	var ring := Rect2i(131, 55, 36, 18)
	base_ring = ring
	for yy in range(ring.position.y + 1, ring.end.y - 1):
		for xx in range(ring.position.x + 1, ring.end.x - 1):
			_put_side(xx, yy)
	_build_house(Vector2i(138, 57), "cuartel", block)
	base_b = buildings[buildings.size() - 1]
	_build_fence_ring(base_b, ring, "base_sign")


func _build_house(pos: Vector2i, kind: String, block: Rect2i) -> void:
	var d: Dictionary = HouseData.TYPES[kind]
	var w: int = d["w"]
	var h: int = d["h"]
	var rows: Array = d["rows"]
	var floors: Array = []
	for ly in h:
		var row: String = rows[ly]
		for lx in w:
			var x := pos.x + lx
			var y := pos.y + ly
			match row[lx]:
				"#":
					_put(x, y, PixelArt.T_WALL)
					_put_solid(x, y, 1)
				"f":
					_put(x, y, PixelArt.T_FLOOR)
					_put_solid(x, y, 0)
					floors.append(Vector2i(x, y))
				"o", "p":
					_put(x, y, PixelArt.T_FLOOR)
					_put_solid(x, y, 0)
				_:
					pass
	for bx in d["boxes"]:
		var bb: Rect2 = bx
		house_boxes.append(Rect2((Vector2(pos) + bb.position) * float(TS), bb.size * float(TS)))
	if d.has("terminal"):
		var tp: Vector2 = d["terminal"]
		var db: Rect2 = d["door_block"]
		var term_px := (Vector2(pos) + tp) * float(TS)
		var door_px := Rect2((Vector2(pos) + db.position) * float(TS), db.size * float(TS))
		if kind == "bunker":
			bunker_terminal = term_px
			bunker_door_rect = door_px
		else:
			lab_terminal = term_px
			lab_door_rect = door_px
	var door := Vector2i(pos.x + int(d["door_x"]), pos.y + h - 1)
	# caminito desde la escalera del porche hasta la acera
	var py := pos.y + h
	while py <= block.end.y + 1 and py < H:
		var tid: int = tiles[py * W + door.x]
		if tid == PixelArt.T_SIDEWALK or tid == PixelArt.T_ASPHALT or tid == PixelArt.T_ASPHALT2:
			break
		_put_side(door.x, py)
		_put_side(door.x + 1, py)
		for dx in range(-1, 3):   # el caminito y sus lados quedan libres de postes, hidrantes, etc.
			if door.x + dx >= 0 and door.x + dx < W:
				prop_block[py * W + door.x + dx] = 1
		py += 1
	# caja de los pisos caminables y su centro
	var fmin := Vector2i(W, H)
	var fmax := Vector2i(-1, -1)
	var mean := Vector2.ZERO
	for t in floors:
		fmin = Vector2i(mini(fmin.x, t.x), mini(fmin.y, t.y))
		fmax = Vector2i(maxi(fmax.x, t.x), maxi(fmax.y, t.y))
		mean += Vector2(t)
	mean /= float(maxi(1, floors.size()))
	var center_t: Vector2i = floors[0]
	var best := INF
	for t in floors:
		var dd := Vector2(t).distance_to(mean)
		if dd < best:
			best = dd
			center_t = t
	var inner := Rect2(Vector2(fmin) * float(TS), Vector2(fmax - fmin + Vector2i.ONE) * float(TS))
	buildings.append({
		"rect": Rect2i(pos, Vector2i(w, h)), "door": door, "kind": kind, "floors": floors,
		"center": tile_center(center_t), "inner": inner, "block": block,
	})


func _scatter_details() -> void:
	for i in 140:
		var x := rng.randi() % W
		var y := rng.randi() % H
		var t: int = tiles[y * W + x]
		if solid[y * W + x] == 0 and (t == PixelArt.T_ASPHALT or t == PixelArt.T_ASPHALT2):
			_put_v(x, y, PixelArt.T_RUBBLE, rng.randi_range(8, 15))


func _pick_start_and_objectives() -> void:
	start_pos = tile_center(Vector2i(21, 19))
	if buildings.is_empty():
		return
	var lab: Dictionary = lab_b if not lab_b.is_empty() else buildings[0]
	objectives.append({"name": "Laboratorio Horizonte", "pos": lab["center"], "main": true})

	var refuge: Dictionary = buildings[0]
	var hospital: Dictionary = buildings[0]
	var best_refuge := INF
	var best_hosp := INF
	for b in buildings:
		if not (b["kind"] in ["cabana", "casa", "chalet", "casita", "hospital"]):
			continue
		var c: Vector2 = b["center"]
		var d1 := c.distance_to(Vector2(30, 30) * TS)
		var d2 := c.distance_to(Vector2(68, 62) * TS)
		if d1 < best_refuge and b["kind"] != "hospital" and _ring_clear(b):
			best_refuge = d1
			refuge = b
		if b["kind"] == "hospital":
			d2 = -1.0
		if d2 < best_hosp:
			best_hosp = d2
			hospital = b
	if not refuge_b.is_empty():
		refuge = refuge_b
	objectives.append({"name": "Refugio", "pos": refuge["center"], "main": false})
	if refuge_b.is_empty():
		_build_fence(refuge)
	refuge_zone = fence["ring"] if not fence.is_empty() else (refuge["rect"] as Rect2i).grow(3)
	start_pos = _free_spot_in(refuge)   # el jugador nace dentro del refugio, en suelo libre
	if hospital == refuge:
		hospital = buildings[(buildings.find(refuge) + 1) % buildings.size()]
	hospital_b = hospital
	refuge_b = refuge
	objectives.append({"name": "Hospital", "pos": hospital["center"], "main": false})
	if not base_b.is_empty():
		objectives.append({"name": "Base militar", "pos": base_b["center"], "main": false})


## Anillo del cercado: margen de m tiles alrededor de la casa (3 minimo; el refugio usa hasta 8).
func _fence_ring(b: Dictionary, m := 3) -> Rect2i:
	var r: Rect2i = b["rect"]
	return Rect2i(r.position.x - m, r.position.y - m, r.size.x + 2 * m, r.size.y + 2 * m)


func _ring_clear(b: Dictionary, m := 3) -> bool:
	var ring := _fence_ring(b, m)
	var blk: Rect2i = b["block"]
	if not blk.encloses(ring):
		return false
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			if _is_road(x, y) or (solid[y * W + x] == 1 and not b["rect"].has_point(Vector2i(x, y))):
				return false
	for o in buildings:
		if o != b and ring.intersects(o["rect"]):
			return false
	return true


func _free_spot_in(b: Dictionary) -> Vector2:
	# BFS de baldosas desde la puerta: suelo libre de muebles y conectado con la entrada
	var d: Dictionary = HouseData.TYPES[b["kind"]]
	var rows: Array = d["rows"]
	var r: Rect2i = b["rect"]
	var walk: Dictionary = {}
	for ly in int(d["h"]):
		for lx in int(d["w"]):
			if not (rows[ly][lx] in ["f", "o", "p"]):
				continue
			var t := Vector2i(r.position.x + lx, r.position.y + ly)
			var c := tile_center(t)
			var clear := true
			for hb in house_boxes:
				if (hb as Rect2).grow(9.0).has_point(c):
					clear = false
					break
			if clear:
				walk[t] = true
	var q: Array = []
	var seen: Dictionary = {}
	var door := Vector2i(r.position.x + int(d["door_x"]), r.end.y - 1)
	for dx in [0, 1]:
		var t := door + Vector2i(dx, 0)
		if walk.has(t):
			seen[t] = true
			q.append(t)
	var i := 0
	while i < q.size():
		var cur: Vector2i = q[i]
		i += 1
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + dv
			if walk.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	var best: Vector2 = b["center"]
	var best_d := INF
	for t in q:
		var c := tile_center(t)
		var dd := c.distance_to(b["center"])
		if dd < best_d:
			best_d = dd
			best = c
	return best


func _build_fence(b: Dictionary) -> void:
	if not _ring_clear(b):
		return
	var m := 3
	for cand in [8, 7, 6, 5, 4]:   # cercado lo mas amplio posible (huerto futuro)
		if _ring_clear(b, cand):
			m = cand
			break
	_build_fence_ring(b, _fence_ring(b, m), "refuge_sign")
	fence = fences[fences.size() - 1]


## Cercado rectangular con un portón de 4 tiles frente a la puerta de la casa b.
func _build_fence_ring(b: Dictionary, ring: Rect2i, sign_name: String) -> void:
	var door: Vector2i = b["door"]
	var gx0 := door.x - 1
	var gx1 := door.x + 2
	var cells: Array = []
	for x in range(ring.position.x, ring.end.x):
		for y in [ring.position.y, ring.end.y - 1]:
			if y == ring.end.y - 1 and x >= gx0 and x <= gx1:
				continue
			cells.append(Vector2i(x, y))
	for y in range(ring.position.y + 1, ring.end.y - 1):
		for x in [ring.position.x, ring.end.x - 1]:
			cells.append(Vector2i(x, y))
	for c in cells:
		_put_solid(c.x, c.y, 1)
		prop_block[c.y * W + c.x] = 1
	fences.append({"ring": ring, "gate": [gx0, gx1], "cells": cells, "sign": sign_name})


func _random_kind() -> String:
	var r := rng.randf()
	if r < 0.30:
		return "scrap"
	if r < 0.46:
		return "food"
	if r < 0.62:
		return "water"
	if r < 0.76:
		return "bandage"
	if r < 0.88:
		return "balas"
	if r < 0.93:
		return "cartuchos"
	if r < 0.96:
		return "machete"
	if r < 0.985:
		return "semillas"
	return "scrap"


## Botin de historia: armas escondidas en casas concretas (cerca del refugio, hospital, zona industrial).
func _place_special_loot(refuge: Dictionary, hospital: Dictionary) -> void:
	var near: Array = buildings.duplicate()
	near.erase(refuge)
	near.sort_custom(func(a, b): return (a["center"] as Vector2).distance_to(refuge["center"]) < (b["center"] as Vector2).distance_to(refuge["center"]))
	var kinds_near := ["machete", "hacha"]
	for i in mini(kinds_near.size(), near.size()):
		_loot_in(near[i], kinds_near[i])
		_loot_in(near[i], "balas" if i == 1 else "bandage")
	_loot_in(refuge, "semillas")   # el refugio trae un par de paquetes para empezar el huerto
	_loot_in(refuge, "semillas")
	_loot_in(hospital, "pistola")
	# la tarjeta Horizonte siempre aparece en una de las casas cercanas al refugio
	var card_pool: Array = []
	for nb in near:
		if card_pool.size() >= 5:
			break
		if nb["kind"] in ["cabana", "casa", "chalet", "casita", "apartamentos", "tienda"]:
			card_pool.append(nb)
	if card_pool.is_empty():
		card_pool = near.slice(0, 4)
	_loot_in(card_pool[rng.randi() % card_pool.size()], "tarjeta")
	_loot_in(hospital, "balas")
	_loot_in(hospital, "balas")
	_loot_in(hospital, "bandage")
	for b in buildings:
		if b["kind"] == "taller" and (b["rect"] as Rect2i).position.x < LAB_X:
			_loot_in(b, "escopeta")
			_loot_in(b, "cartuchos")
			_loot_in(b, "cartuchos")
			break


func _place_civic_loot() -> void:
	var table := {
		"supermercado": ["food", "food", "food", "water", "water", "scrap", "bandage", "semillas"],
		"comisaria": ["pistola", "balas", "balas", "balas", "bandage", "bandage"],
		"iglesia": ["bandage", "bandage", "water"],
		"tienda": ["food", "water", "scrap", "semillas"],
		"hospital": ["bandage", "bandage", "bandage", "water"],
		"apartamentos": ["food", "scrap", "bandage", "balas"],
	}
	for b in buildings:
		var k: String = b["kind"]
		if table.has(k):
			for it in table[k]:
				_loot_in(b, it)
	if not base_b.is_empty():
		_loot_in(base_b, "mascara")
		_loot_in(base_b, "llave")   # unico lugar donde aparece la mascara antigas
		for it in ["fusil", "balas", "balas", "balas", "balas", "cartuchos", "cartuchos", "bandage", "bandage", "food", "water"]:
			_loot_in(base_b, it)
		for it in ["balas", "cartuchos", "bandage", "scrap"]:
			loot_spots.append({"pos": _yard_spot(), "kind": it})
		var fl: Array = base_b["floors"]
		var i := 5
		while i < fl.size():
			zombie_spawns.append(tile_center(fl[i]))
			i += 9
		for _n in 12:
			zombie_spawns.append(_yard_spot())


func _place_bunker_loot() -> void:
	if bunker_b.is_empty():
		return
	for it in ["bandage", "bandage", "balas", "balas", "cartuchos", "water"]:
		_loot_in(bunker_b, it)
	var fl: Array = bunker_b["floors"]
	var i := 4
	while i < fl.size():
		zombie_spawns.append(tile_center(fl[i]))
		i += 10


func _yard_spot() -> Vector2:
	var r := base_ring
	for _t in 40:
		var t := Vector2i(rng.randi_range(r.position.x + 2, r.end.x - 3), rng.randi_range(r.position.y + 2, r.end.y - 3))
		var c := tile_center(t)
		if solid[t.y * W + t.x] == 0 and not (base_b["rect"] as Rect2i).grow(1).has_point(t):
			return c
	return tile_center(r.get_center())


func _place_lab_loot() -> void:
	if lab_b.is_empty():
		return
	for k in ["bandage", "bandage", "balas", "balas", "cartuchos", "food", "water"]:
		_loot_in(lab_b, k)
	# infectados dentro del laboratorio: uno cada pocos tiles de piso
	var fl: Array = lab_b["floors"]
	var i := 3
	while i < fl.size():
		zombie_spawns.append(tile_center(fl[i]))
		i += 11


func _loot_in(b: Dictionary, kind: String) -> void:
	var fl: Array = b["floors"]
	if fl.is_empty():
		return
	loot_spots.append({"pos": tile_center(fl[rng.randi() % fl.size()]), "kind": kind})


func _pick_loot_and_spawns() -> void:
	for b in buildings:
		var fl: Array = b["floors"]
		if fl.is_empty():
			continue
		for i in rng.randi_range(2, 4):
			var t: Vector2i = fl[rng.randi() % fl.size()]
			loot_spots.append({"pos": tile_center(t), "kind": _random_kind()})
	_place_special_loot(refuge_b, hospital_b)
	_place_lab_loot()
	_place_civic_loot()
	_place_bunker_loot()
	# manuales de supervivencia (ensenan una habilidad): uno en cada una de 5 casas al azar
	var pool: Array = buildings.duplicate()
	for i in mini(5, pool.size()):
		var bi := rng.randi() % pool.size()
		var fl: Array = pool[bi]["floors"]
		pool.remove_at(bi)
		if not fl.is_empty():
			loot_spots.append({"pos": tile_center(fl[rng.randi() % fl.size()]), "kind": "manual"})
	var street := 0
	var guard := 0
	while street < 25 and guard < 600:
		guard += 1
		var t := Vector2i(rng.randi() % W, rng.randi() % H)
		if not is_solid_tile(t) and tile_id(t) != PixelArt.T_FLOOR and prop_block[t.y * W + t.x] == 0:
			loot_spots.append({"pos": tile_center(t), "kind": _random_kind()})
			street += 1
	var count := 0
	guard = 0
	var start_t := to_tile(start_pos)
	while count < ZOMBIE_COUNT and guard < 2000:
		guard += 1
		var t := Vector2i(rng.randi() % W, rng.randi() % H)
		if is_solid_tile(t) or prop_block[t.y * W + t.x] == 1:
			continue
		if refuge_zone.grow(2).has_point(t) or Vector2(t - start_t).length() < 14.0:
			continue
		zombie_spawns.append(tile_center(t))
		count += 1


# ----------------------------------------------------------- construccion

## Celda del atlas nuevo (terrain.png) para un tile logico; (-1, -1) si usa el atlas basico.
func _terrain_cell(t: int, v: int) -> Vector2i:
	var row := -1
	match t:
		PixelArt.T_ASPHALT, PixelArt.T_ASPHALT2:
			row = 0
		PixelArt.T_SIDEWALK:
			row = 1
		PixelArt.T_GRASS, PixelArt.T_GRASS2:
			row = 2
		PixelArt.T_DIRT:
			row = 4
		PixelArt.T_RUBBLE:
			row = 5
	if row < 0:
		return Vector2i(-1, -1)
	return Vector2i(v & 15, row + (v >> 4))


func _build_tilemap() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TS, TS)
	var src := TileSetAtlasSource.new()
	src.texture = PixelArt.make_tile_atlas()
	src.texture_region_size = Vector2i(TS, TS)
	for i in PixelArt.T_COUNT:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	# atlas de terreno (asfalto, aceras, cesped, tierra); si falta se usa el basico
	var terrain: Texture2D = null
	if ResourceLoader.exists(TERRAIN_PATH):
		terrain = load(TERRAIN_PATH)
	if terrain != null:
		var src2 := TileSetAtlasSource.new()
		src2.texture = terrain
		src2.texture_region_size = Vector2i(TS, TS)
		for ry in ATLAS_ROWS:
			for rx in ATLAS_COLS:
				src2.create_tile(Vector2i(rx, ry))
		ts.add_source(src2, 1)
	_layer = TileMapLayer.new()
	_layer.tile_set = ts
	for y in H:
		for x in W:
			var i := y * W + x
			var cell := Vector2i(-1, -1)
			if terrain != null:
				cell = _terrain_cell(tiles[i], vari[i])
			if cell.x >= 0:
				_layer.set_cell(Vector2i(x, y), 1, cell)
			else:
				_layer.set_cell(Vector2i(x, y), 0, Vector2i(tiles[i], 0))
	add_child(_layer)


func _build_colliders() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	for y in H:
		var x := 0
		while x < W:
			if solid[y * W + x] == 1:
				var x0 := x
				while x < W and solid[y * W + x] == 1:
					x += 1
				_add_box(Vector2(x0 * TS, y * TS), Vector2((x - x0) * TS, TS))
			else:
				x += 1
	for hb in house_boxes:
		var r: Rect2 = hb
		_add_box(r.position, r.size)
	if lab_door_rect.size.x > 0.0:
		lab_door_body = _make_door_body(lab_door_rect)
	if bunker_door_rect.size.x > 0.0:
		bunker_door_body = _make_door_body(bunker_door_rect)
	# limites del mundo
	var s := size_px()
	_add_box(Vector2(-64, -64), Vector2(s.x + 128, 64))
	_add_box(Vector2(-64, s.y), Vector2(s.x + 128, 64))
	_add_box(Vector2(-64, 0), Vector2(64, s.y))
	_add_box(Vector2(s.x, 0), Vector2(64, s.y))


func _make_door_body(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var sh := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	sh.shape = rs
	sh.position = r.position + r.size * 0.5
	body.add_child(sh)
	add_child(body)
	return body


func _add_box(pos: Vector2, size: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos + size * 0.5
	_body.add_child(shape)


# --------------------------------------------------------------- minimapa

func minimap_color(t: int, is_wall: bool) -> Color:
	if is_wall:
		return Color("d0c8c0")
	match t:
		PixelArt.T_ASPHALT, PixelArt.T_ASPHALT2, PixelArt.T_ROAD_LINE:
			return Color("8a8f9c")
		PixelArt.T_RUBBLE:
			return Color("6a6e78")
		PixelArt.T_SIDEWALK:
			return Color("5a5e68")
		PixelArt.T_GRASS, PixelArt.T_GRASS2:
			return Color("2f5233")
		PixelArt.T_DIRT:
			return Color("5d4a35")
		PixelArt.T_FLOOR:
			return Color("7d746d")
	return Color("222222")


func make_minimap_image() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			img.set_pixel(x, y, minimap_color(tiles[y * W + x], solid[y * W + x] == 1 and tiles[y * W + x] == PixelArt.T_WALL))
	return img
