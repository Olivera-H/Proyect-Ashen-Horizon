class_name World
extends Node2D
## Mundo procedural de prueba: calles, aceras, edificios con puertas, barricadas
## en la autopista y una zona industrial al este. Genera el TileMap, las
## colisiones, los objetivos, los puntos de botin y los puntos de aparicion.

const W := 128
const H := 96
const TS := PixelArt.TILE
const ZOMBIE_COUNT := 200

const V_ROADS := [20, 52, 84]                 # x inicial de cada calle vertical
const H_ROADS := [[18, 3], [46, 5], [74, 3]]  # [y inicial, ancho]; la de 5 es la autopista
const ROAD_W := 3

var tiles := PackedByteArray()
var solid := PackedByteArray()
var buildings: Array = []      # {rect: Rect2i, door: Vector2i}
var objectives: Array = []     # {name, pos, main}
var loot_spots: Array = []     # {pos, kind}
var zombie_spawns: Array = []  # Vector2
var start_pos := Vector2.ZERO
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
	_fill_terrain()
	_lay_roads()
	_place_buildings()
	_scatter_details()
	_pick_start_and_objectives()
	_pick_loot_and_spawns()
	_build_tilemap()
	_build_colliders()


# ------------------------------------------------------------ generacion

func _fill_terrain() -> void:
	for y in H:
		for x in W:
			var t := PixelArt.T_GRASS
			if x >= 87:
				t = PixelArt.T_DIRT  # zona industrial
			elif rng.randf() < 0.06:
				t = PixelArt.T_GRASS2
			_put(x, y, t)


func _asphalt() -> int:
	return PixelArt.T_ASPHALT2 if rng.randf() < 0.08 else PixelArt.T_ASPHALT


func _lay_roads() -> void:
	# aceras
	for vx in V_ROADS:
		for y in H:
			for x in range(vx - 1, vx + ROAD_W + 1):
				_put(x, y, PixelArt.T_SIDEWALK)
	for hr in H_ROADS:
		for y in range(hr[0] - 1, hr[0] + hr[1] + 1):
			for x in W:
				_put(x, y, PixelArt.T_SIDEWALK)
	# asfalto
	for vx in V_ROADS:
		for y in H:
			for x in range(vx, vx + ROAD_W):
				_put(x, y, _asphalt())
	for hr in H_ROADS:
		var mid: int = hr[0] + int(hr[1] / 2.0)
		for y in range(hr[0], hr[0] + hr[1]):
			for x in W:
				var t := _asphalt()
				var on_vroad := false
				for vx in V_ROADS:
					if x >= vx and x < vx + ROAD_W:
						on_vroad = true
				if y == mid and not on_vroad and x % 4 < 3:
					t = PixelArt.T_ROAD_LINE
				_put(x, y, t)
	# barricadas en la autopista: dejan un solo carril libre
	var hw: Array = H_ROADS[1]
	var gap_low := true
	for bx in [30, 62, 96]:
		for y in range(hw[0], hw[0] + hw[1]):
			var is_gap: bool = (y == hw[0] + hw[1] - 1) if gap_low else (y == hw[0])
			if is_gap:
				continue
			for x in range(bx, bx + 2):
				_put(x, y, PixelArt.T_RUBBLE)
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
		var industrial: bool = block.position.x >= 87
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
			_put(x, y, PixelArt.T_RUBBLE)


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
		if not is_solid_tile(t) and tile_id(t) != PixelArt.T_FLOOR:
			loot_spots.append({"pos": tile_center(t), "kind": _random_kind()})
			street += 1
	var count := 0
	guard = 0
	var start_t := to_tile(start_pos)
	while count < ZOMBIE_COUNT and guard < 2000:
		guard += 1
		var t := Vector2i(rng.randi() % W, rng.randi() % H)
		if is_solid_tile(t):
			continue
		if Vector2(t - start_t).length() < 22.0:
			continue
		zombie_spawns.append(tile_center(t))
		count += 1


# ----------------------------------------------------------- construccion

func _build_tilemap() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TS, TS)
	var src := TileSetAtlasSource.new()
	src.texture = PixelArt.make_tile_atlas()
	src.texture_region_size = Vector2i(TS, TS)
	for i in PixelArt.T_COUNT:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	_layer = TileMapLayer.new()
	_layer.tile_set = ts
	for y in H:
		for x in W:
			_layer.set_cell(Vector2i(x, y), 0, Vector2i(tiles[y * W + x], 0))
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
