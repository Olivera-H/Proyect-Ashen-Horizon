class_name World
extends Node2D
## Mundo procedural de prueba: calles, aceras, edificios con puertas, barricadas
## en la autopista y una zona industrial al este. Genera el TileMap, las
## colisiones, los objetivos, los puntos de botin y los puntos de aparicion.

const W := 128
const H := 96
const TS := PixelArt.TILE
const ZOMBIE_COUNT := 100

const V_ROADS := [20, 52, 84]                 # x inicial de cada calle vertical
const H_ROADS := [[18, 3], [46, 8], [74, 3]]  # [y inicial, ancho]; la de 8 es la autopista (4 carriles)
const HW := 1                                 # indice de la autopista en H_ROADS (la calle del medio)
const ROAD_W := 3
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


func _place_buildings() -> void:
	for block in _block_ranges():
		var industrial: bool = block.position.x >= INDUSTRIAL_X
		var attempts := 9 if not industrial else 5
		for i in attempts:
			var w := rng.randi_range(10, 18) if industrial else rng.randi_range(6, 11)
			var h := rng.randi_range(8, 14) if industrial else rng.randi_range(5, 9)
			if w + 2 >= block.size.x or h + 2 >= block.size.y:
				continue
			var x := rng.randi_range(block.position.x + 1, block.position.x + block.size.x - w - 1)
			var y := rng.randi_range(block.position.y + 1, block.position.y + block.size.y - h - 1)
			var r := Rect2i(x, y, w, h)
			var ok := true
			for b in buildings:
				if r.grow(1).intersects(b["rect"]):
					ok = false
					break
			if ok:
				_build_house(r)


func _build_house(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var edge := x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			if edge:
				_put(x, y, PixelArt.T_WALL)
				_put_solid(x, y, 1)
			else:
				_put(x, y, PixelArt.T_FLOOR)
	# puerta de 2 tiles en un lado al azar
	var side := rng.randi() % 4
	var door := Vector2i.ZERO
	match side:
		0:  # arriba
			door = Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 3), r.position.y)
			for dx in 2:
				_open_door(door.x + dx, door.y)
		1:  # abajo
			door = Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 3), r.end.y - 1)
			for dx in 2:
				_open_door(door.x + dx, door.y)
		2:  # izquierda
			door = Vector2i(r.position.x, rng.randi_range(r.position.y + 1, r.end.y - 3))
			for dy in 2:
				_open_door(door.x, door.y + dy)
		_:  # derecha
			door = Vector2i(r.end.x - 1, rng.randi_range(r.position.y + 1, r.end.y - 3))
			for dy in 2:
				_open_door(door.x, door.y + dy)
	buildings.append({"rect": r, "door": door})


func _open_door(x: int, y: int) -> void:
	_put(x, y, PixelArt.T_FLOOR)
	_put_solid(x, y, 0)


func _scatter_details() -> void:
	for i in 140:
		var x := rng.randi() % W
		var y := rng.randi() % H
		var t: int = tiles[y * W + x]
		if solid[y * W + x] == 0 and (t == PixelArt.T_ASPHALT or t == PixelArt.T_ASPHALT2):
			_put_v(x, y, PixelArt.T_RUBBLE, rng.randi_range(8, 15))


func _center_px(r: Rect2i) -> Vector2:
	return (Vector2(r.position) + Vector2(r.size) * 0.5) * TS


func _pick_start_and_objectives() -> void:
	start_pos = tile_center(Vector2i(21, 19))
	if buildings.is_empty():
		return
	var lab: Dictionary = buildings[0]
	for b in buildings:
		var r: Rect2i = b["rect"]
		if r.position.x > lab["rect"].position.x or (r.position.x == lab["rect"].position.x and r.size.x * r.size.y > lab["rect"].size.x * lab["rect"].size.y):
			lab = b
	objectives.append({"name": "Laboratorio Horizonte", "pos": _center_px(lab["rect"]), "main": true})

	var refuge: Dictionary = buildings[0]
	var hospital: Dictionary = buildings[0]
	var best_refuge := INF
	var best_hosp := INF
	for b in buildings:
		var c := _center_px(b["rect"])
		var d1 := c.distance_to(Vector2(30, 30) * TS)
		var d2 := c.distance_to(Vector2(68, 62) * TS)
		if d1 < best_refuge:
			best_refuge = d1
			refuge = b
		if d2 < best_hosp:
			best_hosp = d2
			hospital = b
	objectives.append({"name": "Refugio", "pos": _center_px(refuge["rect"]), "main": false})
	if hospital != refuge:
		objectives.append({"name": "Hospital", "pos": _center_px(hospital["rect"]), "main": false})


func _random_kind() -> String:
	var r := rng.randf()
	if r < 0.4:
		return "scrap"
	if r < 0.6:
		return "food"
	if r < 0.8:
		return "water"
	return "bandage"


func _pick_loot_and_spawns() -> void:
	for b in buildings:
		var inner: Rect2i = b["rect"].grow(-1)
		if inner.size.x <= 0 or inner.size.y <= 0:
			continue
		for i in rng.randi_range(1, 3):
			var t := Vector2i(rng.randi_range(inner.position.x, inner.end.x - 1), rng.randi_range(inner.position.y, inner.end.y - 1))
			loot_spots.append({"pos": tile_center(t), "kind": _random_kind()})
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
		if Vector2(t - start_t).length() < 22.0:
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
	# limites del mundo
	var s := size_px()
	_add_box(Vector2(-64, -64), Vector2(s.x + 128, 64))
	_add_box(Vector2(-64, s.y), Vector2(s.x + 128, 64))
	_add_box(Vector2(-64, 0), Vector2(64, s.y))
	_add_box(Vector2(s.x, 0), Vector2(64, s.y))


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
