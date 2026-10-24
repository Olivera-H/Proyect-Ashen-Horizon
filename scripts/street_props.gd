class_name StreetProps
extends RefCounted
## Objetos de calle: semaforos, senales, postes de luz, autos abandonados, conos,
## hidrantes, arboles, arbustos y rocas, mas manchas en el suelo (alcantarillas, sangre vieja).
##
## World.generate() llama a place() (decide donde va cada cosa y reserva los tiles) y
## Main llama a spawn() (crea los nodos, con colision, dentro del nodo ordenado por Y).
## Los sprites estan en assets/world/props/ (los genera tools/gen_props.py); si falta uno,
## ese objeto simplemente no aparece.

const TS := 16
const DIR := "res://assets/world/props/"

# colision de cada objeto: rectangulos relativos al punto de apoyo (centro-abajo del sprite)
const POLE := [Rect2(-2, -3, 4, 4)]
const KINDS := {
	"traffic_light_front": {"hit": [Rect2(-2, -3, 4, 4)], "glow": Vector2(0, -26)},
	"traffic_light_back": {"hit": [Rect2(-2, -3, 4, 4)]},
	"stop_sign": {"hit": [Rect2(-2, -3, 4, 4)]},
	"speed_60": {"hit": [Rect2(-2, -3, 4, 4)]},
	"speed_80": {"hit": [Rect2(-2, -3, 4, 4)]},
	"warning_ped": {"hit": [Rect2(-2, -3, 4, 4)]},
	"guide_horizonte": {"hit": [Rect2(-18, -3, 4, 4), Rect2(14, -3, 4, 4)]},
	"guide_industrial": {"hit": [Rect2(-18, -3, 4, 4), Rect2(14, -3, 4, 4)]},
	"street_lamp": {"hit": [Rect2(-2, -3, 4, 4)], "glow": Vector2(0, -36)},
	"hydrant": {"hit": [Rect2(-3, -4, 6, 5)]},
	"trash_can": {"hit": [Rect2(-4, -5, 8, 6)]},
	"cone": {"hit": []},
	"car_sedan_red": {"hit": [Rect2(-20, -13, 40, 13)]},
	"car_sedan_blue": {"hit": [Rect2(-20, -13, 40, 13)]},
	"car_taxi": {"hit": [Rect2(-20, -13, 40, 13)]},
	"car_van_white": {"hit": [Rect2(-20, -13, 40, 13)]},
	"car_wagon_green": {"hit": [Rect2(-20, -13, 40, 13)]},
	"tree_dead_a": {"hit": [Rect2(-3, -4, 6, 5)]},
	"tree_dead_b": {"hit": [Rect2(-3, -4, 6, 5)]},
	"tree_dying": {"hit": [Rect2(-3, -4, 6, 5)]},
	"bush_green": {"hit": [Rect2(-6, -6, 12, 7)]},
	"bush_dry": {"hit": [Rect2(-6, -6, 12, 7)]},
	"rock_a": {"hit": [Rect2(-4, -5, 8, 6)]},
	"rock_b": {"hit": [Rect2(-5, -6, 10, 7)]},
}
const CARS := ["car_sedan_red", "car_sedan_blue", "car_taxi", "car_van_white", "car_wagon_green"]
const LIGHT_COLORS := {
	"amber": Color(1.0, 0.7, 0.25),
	"red": Color(1.0, 0.22, 0.15),
	"lamp": Color(1.0, 0.86, 0.55),
}

static var _tex_cache := {}
static var _light_tex: Texture2D


# ====================================================================== place

static func _tile_ok(w: World, t: Vector2i, ids: Array) -> bool:
	if not w.in_bounds(t) or w.is_solid_tile(t):
		return false
	if w.prop_block[t.y * World.W + t.x] == 1:
		return false
	return ids.has(w.tile_id(t))


static func _add(w: World, kind: String, pos: Vector2, flip: bool = false, mode: String = "", block: bool = true) -> void:
	w.props.append({"kind": kind, "pos": pos, "flip": flip, "mode": mode})
	if block:
		var t := w.to_tile(pos)
		if w.in_bounds(t):
			w.prop_block[t.y * World.W + t.x] = 1


static func _block_rect(w: World, r: Rect2) -> void:
	var a := w.to_tile(r.position)
	var b := w.to_tile(r.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if w.in_bounds(Vector2i(x, y)):
				w.prop_block[y * World.W + x] = 1


static func place(w: World) -> void:
	w.props.clear()
	w.decals.clear()
	var near := _near_buildings(w)
	_intersections(w)
	_highway_signs(w)
	_lamps(w)
	_wrecks(w)
	_barricade_cones(w)
	_furniture(w)
	_vegetation(w, near)
	_decals(w)


static func _near_buildings(w: World) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(World.W * World.H)
	m.fill(0)
	for b in w.buildings:
		var r: Rect2i = b["rect"]
		for y in range(r.position.y - 2, r.end.y + 2):
			for x in range(r.position.x - 2, r.end.x + 2):
				if w.in_bounds(Vector2i(x, y)):
					m[y * World.W + x] = 1
	return m


static func _intersections(w: World) -> void:
	for vx in World.V_ROADS:
		for hi in World.H_ROADS.size():
			var hr: Array = World.H_ROADS[hi]
			var hy: int = hr[0]
			var hh: int = hr[1]
			# esquinas: NO, NE, SO, SE (tile de acera y desplazamiento hacia el cruce)
			var corners := [
				[Vector2i(vx - 1, hy - 1), Vector2(11, 13), true],
				[Vector2i(vx + World.ROAD_W, hy - 1), Vector2(5, 13), true],
				[Vector2i(vx - 1, hy + hh), Vector2(11, 5), false],
				[Vector2i(vx + World.ROAD_W, hy + hh), Vector2(5, 5), false],
			]
			for i in 4:
				var c: Array = corners[i]
				var t: Vector2i = c[0]
				if not _tile_ok(w, t, [PixelArt.T_SIDEWALK]):
					continue
				var pos := Vector2(t.x * TS, t.y * TS) + (c[1] as Vector2)
				if hi == World.HW:
					if c[2]:
						_add(w, "traffic_light_back", pos)
					else:
						var r := w.rng.randf()
						var mode := ""
						if r < 0.4:
							mode = "amber"
						elif r < 0.65:
							mode = "red"
						_add(w, "traffic_light_front", pos, false, mode)
				elif i == 1 or i == 2:
					_add(w, "stop_sign", pos)


static func _highway_signs(w: World) -> void:
	var hr: Array = World.H_ROADS[World.HW]
	var ny: int = hr[0] - 1
	var sy: int = hr[0] + hr[1]
	var north := [[9, "speed_60"], [45, "speed_80"], [74, "speed_60"], [108, "speed_80"], [39, "guide_horizonte"], [100, "guide_industrial"]]
	for s in north:
		var t := Vector2i(s[0], ny)
		if _tile_ok(w, t, [PixelArt.T_SIDEWALK]) and not w.near_cross_x(t.x):
			_add(w, s[1], Vector2(t.x * TS + 8, t.y * TS + 13))
	for vx in World.V_ROADS:
		for dx in [-5, 7]:
			var t := Vector2i(vx + dx, sy)
			if _tile_ok(w, t, [PixelArt.T_SIDEWALK]):
				_add(w, "warning_ped", Vector2(t.x * TS + 8, t.y * TS + 6))


static func _near_barricade(x: int) -> bool:
	for bx in [30, 62, 96]:
		if x >= bx - 3 and x <= bx + 4:
			return true
	return false


static func _lamp(w: World, pos: Vector2) -> void:
	var mode := "lamp" if w.rng.randf() < 0.28 else ""
	_add(w, "street_lamp", pos, false, mode)


static func _lamps(w: World) -> void:
	var hr: Array = World.H_ROADS[World.HW]
	var ny: int = hr[0] - 1
	var sy: int = hr[0] + hr[1]
	for x in range(6, World.W - 3, 11):
		if not w.near_cross_x(x) and not _near_barricade(x):
			var t := Vector2i(x, ny)
			if _tile_ok(w, t, [PixelArt.T_SIDEWALK]):
				_lamp(w, Vector2(x * TS + 8, t.y * TS + 14))
		var x2 := x + 5
		if not w.near_cross_x(x2) and not _near_barricade(x2):
			var t2 := Vector2i(x2, sy)
			if _tile_ok(w, t2, [PixelArt.T_SIDEWALK]):
				_lamp(w, Vector2(x2 * TS + 8, t2.y * TS + 6))
	for hi in [0, 2]:
		var y: int = World.H_ROADS[hi][0] - 1
		for x in range(11, World.W - 3, 13):
			var t := Vector2i(x, y)
			if not w.near_cross_x(x) and _tile_ok(w, t, [PixelArt.T_SIDEWALK]):
				_lamp(w, Vector2(x * TS + 8, t.y * TS + 14))
	for vx in World.V_ROADS:
		for y in range(8, World.H - 3, 13):
			var t := Vector2i(vx - 1, y)
			if _tile_ok(w, t, [PixelArt.T_SIDEWALK]) and not _near_h_road(y):
				_lamp(w, Vector2(t.x * TS + 5, t.y * TS + 12))


static func _near_h_road(y: int) -> bool:
	for hr in World.H_ROADS:
		if y >= hr[0] - 3 and y <= hr[0] + hr[1] + 2:
			return true
	return false


## Autos abandonados solo en los carriles exteriores: los dos del centro quedan libres.
static func _wrecks(w: World) -> void:
	var hr: Array = World.H_ROADS[World.HW]
	var hy: int = hr[0]
	var gap_lane := {30: 3, 62: 0, 96: 3}
	var placed: Array = []
	var tries := 0
	while placed.size() < 16 and tries < 400:
		tries += 1
		var tx := w.rng.randi_range(4, World.W - 5)
		if w.near_cross_x(tx - 3) or w.near_cross_x(tx + 3) or w.near_cross_x(tx):
			continue
		var lane := 0 if w.rng.randf() < 0.5 else 3
		var skip := false
		for bx in gap_lane:
			if absi(tx - int(bx)) <= 5 and gap_lane[bx] == lane:
				skip = true
		if skip:
			continue
		var cx := float(tx * TS + 8 + w.rng.randi_range(-6, 6))
		var cy := float(hy * TS + 16 + 32 * lane + 11)
		var clash := false
		for p in placed:
			var pp: Vector3 = p
			if int(pp.z) == lane and absf(pp.x - cx) < 72.0:
				clash = true
		if clash:
			continue
		var rubble := false
		for dx in [-24, 0, 24]:
			var t := w.to_tile(Vector2(cx + dx, cy - 8))
			if w.tile_id(t) == PixelArt.T_RUBBLE:
				rubble = true
		if rubble:
			continue
		placed.append(Vector3(cx, cy, lane))
		_add(w, CARS[w.rng.randi() % CARS.size()], Vector2(cx, cy), lane < 2, "", false)
		_block_rect(w, Rect2(cx - 24, cy - 26, 48, 26))


static func _barricade_cones(w: World) -> void:
	var hr: Array = World.H_ROADS[World.HW]
	var hy: int = hr[0]
	var gap_low := true
	for bx in [30, 62, 96]:
		var edge_y := float(hy * TS + (6 if gap_low else 2) * TS)
		for k in 3:
			_add(w, "cone", Vector2(float((bx - 1) * TS + 8 - 20 * k), edge_y + (5.0 if gap_low else -3.0) + 2.0 * k), false, "", false)
			_add(w, "cone", Vector2(float((bx + 2) * TS + 8 + 20 * k), edge_y + (5.0 if gap_low else -3.0) + 2.0 * k), false, "", false)
		gap_low = not gap_low


static func _furniture(w: World) -> void:
	var tries := 0
	var hydrants := 0
	var cans := 0
	while (hydrants < 12 or cans < 16) and tries < 1500:
		tries += 1
		var t := Vector2i(w.rng.randi_range(2, World.W - 3), w.rng.randi_range(2, World.H - 3))
		if not _tile_ok(w, t, [PixelArt.T_SIDEWALK]) or w.crosswalk_tiles.has(t) or w.near_cross_x(t.x):
			continue
		var pos := Vector2(t.x * TS + w.rng.randi_range(4, 12), t.y * TS + w.rng.randi_range(8, 13))
		if hydrants < 12 and w.rng.randf() < 0.5:
			hydrants += 1
			_add(w, "hydrant", pos)
		elif cans < 16:
			cans += 1
			_add(w, "trash_can", pos)


static func _free3(w: World, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := Vector2i(x + dx, y + dy)
			if not w.in_bounds(t) or w.prop_block[t.y * World.W + t.x] == 1:
				return false
	return true


static func _vegetation(w: World, near: PackedByteArray) -> void:
	var start_t := w.to_tile(w.start_pos)
	for y in range(3, World.H - 2):
		for x in range(2, World.W - 2):
			var i := y * World.W + x
			var id := w.tile_id(Vector2i(x, y))
			if id != PixelArt.T_GRASS and id != PixelArt.T_GRASS2:
				continue
			if near[i] == 1 or w.prop_block[i] == 1:
				continue
			if Vector2(Vector2i(x, y) - start_t).length() < 7.0:
				continue
			var n2 := w.noise2.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var dry := w.dryness(x, y)
			var pt := 0.006 + 0.055 * smoothstep(0.5, 0.85, n2)
			var pb := 0.012 + 0.03 * smoothstep(0.4, 0.8, n2)
			var pr := 0.007
			var r := w.rng.randf()
			var pos := Vector2(x * TS + w.rng.randi_range(4, 12), y * TS + w.rng.randi_range(9, 14))
			if r < pt and _free3(w, x, y):
				var kind := "tree_dead_a"
				var k := w.rng.randf()
				if k < (0.55 - dry * 0.5):
					kind = "tree_dying"
				elif k < 0.78:
					kind = "tree_dead_b"
				_add(w, kind, pos, w.rng.randf() < 0.5)
			elif r < pt + pb and _free3(w, x, y):
				_add(w, "bush_dry" if dry > 0.55 else "bush_green", pos, w.rng.randf() < 0.5)
			elif r < pt + pb + pr and _free3(w, x, y):
				_add(w, "rock_a" if w.rng.randf() < 0.6 else "rock_b", pos, w.rng.randf() < 0.5)


static func _decals(w: World) -> void:
	var n := 0
	var tries := 0
	while n < 14 and tries < 600:
		tries += 1
		var t := Vector2i(w.rng.randi_range(2, World.W - 3), w.rng.randi_range(2, World.H - 3))
		var id := w.tile_id(t)
		if (id == PixelArt.T_ASPHALT or id == PixelArt.T_ASPHALT2) and not w.crosswalk_tiles.has(t) and not w.near_cross_x(t.x) and w.prop_block[t.y * World.W + t.x] == 0:
			w.decals.append({"kind": "manhole", "pos": w.tile_center(t), "a": 1.0, "rot": 0.0})
			n += 1
	n = 0
	tries = 0
	while n < 34 and tries < 800:
		tries += 1
		var t := Vector2i(w.rng.randi_range(2, World.W - 3), w.rng.randi_range(2, World.H - 3))
		var id := w.tile_id(t)
		if id == PixelArt.T_ASPHALT or id == PixelArt.T_ASPHALT2 or id == PixelArt.T_SIDEWALK:
			var p := w.tile_center(t) + Vector2(w.rng.randf_range(-5, 5), w.rng.randf_range(-5, 5))
			w.decals.append({"kind": "blood", "pos": p, "a": w.rng.randf_range(0.35, 0.6), "rot": float(w.rng.randi() % 4) * PI * 0.5})
			n += 1


# ====================================================================== spawn

static func _tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var path := DIR + name + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex_cache[name] = t
	return t


static func light_texture() -> Texture2D:
	if _light_tex == null:
		_light_tex = PixelArt.make_radial_light(64)
	return _light_tex


## Crea los nodos. `ents` es el nodo ordenado por Y (donde viven el jugador y los zombis).
static func spawn(w: World, ents: Node2D) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	w.add_child(body)
	# manchas en el suelo (bajo las entidades)
	var ground := Node2D.new()
	w.add_child(ground)
	for d in w.decals:
		var kind: String = d["kind"]
		var s := Sprite2D.new()
		if kind == "blood":
			s.texture = PixelArt.make_blood_splat(int(d["pos"].x * 7.0 + d["pos"].y))
			s.modulate = Color(0.75, 0.5, 0.5, float(d["a"]))
		else:
			s.texture = _tex(kind)
			if s.texture == null:
				continue
		s.position = d["pos"]
		s.rotation = float(d["rot"])
		ground.add_child(s)
	# objetos
	for p in w.props:
		var kind: String = p["kind"]
		var tex := _tex(kind)
		if tex == null:
			continue
		var pos: Vector2 = p["pos"]
		var flip: bool = p["flip"]
		var mode: String = p["mode"]
		var spr: Sprite2D
		var spec: Dictionary = KINDS.get(kind, {})
		if mode != "":
			var suffix := "lit" if mode == "lamp" else mode
			var on := _tex(kind + "_" + suffix)
			var lp := LightProp.new()
			lp.setup(tex, on, mode, spec.get("glow", Vector2(0, -20)))
			spr = lp
		else:
			spr = Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		spr.flip_h = flip
		spr.position = pos
		ents.add_child(spr)
		for h in spec.get("hit", []):
			var r: Rect2 = h
			if flip:
				r = Rect2(-(r.position.x + r.size.x), r.position.y, r.size.x, r.size.y)
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = r.size
			shape.shape = rect
			shape.position = pos + r.position + r.size * 0.5
			body.add_child(shape)


## Semaforo o farola con luz que parpadea. Con la luz del dia casi no se nota.
class LightProp extends Sprite2D:
	var mode := "amber"
	var tex_off: Texture2D
	var tex_on: Texture2D
	var light: PointLight2D
	var night := 1.0
	var _t := 0.0
	var _on := false
	var _dip := false

	func setup(off: Texture2D, on: Texture2D, m: String, glow_pos: Vector2) -> void:
		tex_off = off
		tex_on = on
		mode = m
		_t = randf() * 2.0
		light = PointLight2D.new()
		light.texture = StreetProps.light_texture()
		light.color = StreetProps.LIGHT_COLORS.get(m, Color.WHITE)
		light.texture_scale = 2.6 if m == "lamp" else 0.9
		light.energy = 0.0
		light.position = glow_pos + (Vector2(0, -5) if m == "red" else Vector2.ZERO)
		add_child(light)
		add_to_group("night_lights")

	func set_night(v: float) -> void:
		night = v

	func _process(delta: float) -> void:
		_t -= delta
		match mode:
			"amber":
				if _t <= 0.0:
					_on = not _on
					_t = randf_range(0.45, 0.7)
			"red":
				if _t <= 0.0:
					_on = randf() < 0.55
					_t = randf_range(0.04, 0.9)
			_:
				if _t <= 0.0:
					_dip = randf() < 0.1
					_t = randf_range(0.05, 0.6)
				_on = not _dip
		if tex_on != null:
			texture = tex_on if _on else tex_off
		var base := 0.95 if mode == "lamp" else 0.6
		light.energy = base * (0.15 + 0.85 * night) if _on else 0.0
