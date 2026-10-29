class_name Houses
extends Node2D
## Dibuja las casas del vecindario: el interior (siempre) y el techo, que se vuelve
## transparente cuando el jugador entra. Tambien coloca el cercado del refugio.
## El arte sale de assets/houses (ver tools/gen_houses.py); los muros y pisos de cada
## casa estan en house_data.gd.

const FADE_SPEED := 5.0
const FENCE_DIR := "res://assets/world/props/"

var world: World
var player: Node2D
var _roofs: Array = []     # {sprite: Sprite2D, b: Dictionary}
var _tex_cache := {}


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


## floor_parent: nodo que se dibuja debajo de las entidades (interior).  ents: entidades (cercado).
func setup(w: World, floor_parent: Node2D, ents: Node2D) -> void:
	world = w
	z_index = 30
	for b in w.buildings:
		var r: Rect2i = b["rect"]
		var origin := Vector2(r.position) * float(World.TS)
		var shadow_tex := _tex("res://assets/houses/%s_shadow.png" % b["kind"])
		if shadow_tex != null:
			var sh := Sprite2D.new()
			sh.texture = shadow_tex
			sh.centered = false
			sh.scale = Vector2(0.5, 0.5)
			sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sh.position = origin - Vector2(12, 12)
			floor_parent.add_child(sh)
		var inner := Sprite2D.new()
		inner.texture = _tex("res://assets/houses/%s_interior.png" % b["kind"])
		inner.centered = false
		inner.scale = Vector2(0.5, 0.5)    # el arte esta al doble de resolucion
		inner.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		inner.position = origin
		floor_parent.add_child(inner)
		var roof := Sprite2D.new()
		roof.texture = _tex("res://assets/houses/%s_roof.png" % b["kind"])
		roof.centered = false
		roof.scale = Vector2(0.5, 0.5)
		roof.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		roof.position = origin
		if b == w.refuge_b:
			roof.light_mask = 2     # el techo no se ilumina con las luces interiores del refugio
		add_child(roof)
		_roofs.append({"sprite": roof, "b": b})
	_build_fence(ents)
	_make_doors()


func _process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var pt := world.to_tile(player.global_position)
	for e in _roofs:
		var b: Dictionary = e["b"]
		var s: Sprite2D = e["sprite"]
		var target := 1.0
		if _inside(b, pt):
			target = 0.0
		s.modulate.a = move_toward(s.modulate.a, target, FADE_SPEED * delta)
		s.visible = s.modulate.a > 0.01


## true si el tile esta en el piso interior o en el camino de la puerta de la casa b.
func _inside(b: Dictionary, t: Vector2i) -> bool:
	var r: Rect2i = b["rect"]
	if not r.has_point(t):
		return false
	var d: Dictionary = HouseData.TYPES[b["kind"]]
	var row: String = d["rows"][t.y - r.position.y]
	var c := row[t.x - r.position.x]
	return c == "f" or c == "p" or c == "o"


# ------------------------------------------------------------ cercado

func _sprite(ents: Node2D, tex_name: String, bottom_center: Vector2) -> Sprite2D:
	var t := _tex(FENCE_DIR + tex_name + ".png")
	if t == null:
		return null
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.offset = Vector2(-t.get_width() * 0.5, -t.get_height() + 3.0)
	s.position = bottom_center
	ents.add_child(s)
	return s


func _build_fence(ents: Node2D) -> void:
	for f in world.fences:
		_build_one_fence(ents, f)


func _build_one_fence(ents: Node2D, f: Dictionary) -> void:
	var ring: Rect2i = f["ring"]
	var ts := float(World.TS)
	var x0 := ring.position.x
	var x1 := ring.end.x - 1
	var y0 := ring.position.y
	var y1 := ring.end.y - 1
	var gate: Array = f["gate"]
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 4242 + x0
	for c in f["cells"]:
		var cell: Vector2i = c
		var base := Vector2((cell.x + 0.5) * ts, (cell.y + 1.0) * ts)
		var corner := (cell.x == x0 or cell.x == x1) and (cell.y == y0 or cell.y == y1)
		if corner:
			_sprite(ents, "fence_post", base)
		elif cell.y == y0 or cell.y == y1:
			var v := rnd.randi() % 7
			_sprite(ents, "fence_h_b" if v == 0 else ("fence_h_c" if v == 1 else "fence_h_a"), base)
		else:
			_sprite(ents, "fence_v", base)
	# porton abierto: dos postes altos y el cartel
	var gy := (y1 + 1.0) * ts
	var left := _sprite(ents, "gate_post", Vector2(gate[0] * ts + 3.0, gy))
	_sprite(ents, "gate_post", Vector2((gate[1] + 1) * ts - 3.0, gy))
	if left != null:
		var sign_s := _sprite(ents, f.get("sign", "refuge_sign"), Vector2(gate[0] * ts + 3.0 + 18.0, gy - 12.0))
		if sign_s != null:
			sign_s.z_index = 1


# ------------------------------------------------------------ puertas cerradas (laboratorio, bunker)

var _door_sprites := {}     # nombre -> Sprite2D (puerta abierta, oculta hasta abrir)
var _opened := {}


func _make_doors() -> void:
	_make_door("lab", world.lab_b, Vector2(17.0 - 0.5, 14.0 + 0.2))
	_make_door("bunker", world.bunker_b, Vector2(8.0 - 0.5, 9.0 + 0.2))


func _make_door(id: String, b: Dictionary, local: Vector2) -> void:
	if b.is_empty():
		return
	var spr := Sprite2D.new()
	spr.texture = _tex("res://assets/houses/lab_door_open.png")
	spr.centered = false
	spr.scale = Vector2(0.5, 0.5)
	var r: Rect2i = b["rect"]
	spr.position = (Vector2(r.position) + local) * float(World.TS)
	spr.z_index = 2
	spr.visible = false
	add_child(spr)
	_door_sprites[id] = spr


func open_door(id: String) -> void:
	if _opened.has(id):
		return
	_opened[id] = true
	if id == "lab" and world.lab_door_body != null:
		world.lab_door_body.queue_free()
		world.lab_door_body = null
	elif id == "bunker" and world.bunker_door_body != null:
		world.bunker_door_body.queue_free()
		world.bunker_door_body = null
	if _door_sprites.has(id):
		(_door_sprites[id] as Sprite2D).visible = true


func open_lab_door() -> void:
	open_door("lab")
