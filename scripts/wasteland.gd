class_name Wasteland
extends RefCounted
## Bordes oeste, norte y sur del mapa: una cerca recorre la columna 0 y las filas 0 y H-1 y, al
## otro lado, se ve un campo desolado con zombis muertos (assets/world/wasteland*.png, ver
## tools/gen_wasteland.py). El campo es solo decorado: la cerca es solida y no se puede cruzar.

const TEX := "res://assets/world/wasteland.png"
const WIDTH_PX := 384           # ancho visible del campo (24 tiles)
const POST_EVERY := 5


## Marca la columna 0 como cerca solida (antes de colocar props y colisiones).
static func reserve(w: World) -> void:
	for y in World.H:
		w._put_solid(0, y, 1)
		w.prop_block[y * World.W] = 1
		w.prop_block[y * World.W + 1] = 1
	for x in World.W:
		for y in [0, World.H - 1]:
			w._put_solid(x, y, 1)
		for y in [0, 1, World.H - 2, World.H - 1]:
			w.prop_block[y * World.W + x] = 1


## Suelo del campo (bajo las entidades): franja oeste y franjas norte/sur (incluyen las esquinas).
static func build_ground(parent: Node2D) -> void:
	var d := float(WIDTH_PX)
	var h := float(World.H * World.TS)
	for part in [["wasteland.png", Vector2(-d, 0.0)], ["wasteland_n.png", Vector2(-d, -d)], ["wasteland_s.png", Vector2(-d, h)]]:
		var path := "res://assets/world/" + String(part[0])
		if not ResourceLoader.exists(path):
			continue
		var s := Sprite2D.new()
		s.texture = load(path)
		s.centered = false
		s.position = part[1]
		parent.add_child(s)


## Cerca (se ordena en y con el resto de entidades).
static func build_fence(ents: Node2D) -> void:
	var seg: Texture2D = load("res://assets/world/props/fence_v.png")
	var post: Texture2D = load("res://assets/world/props/fence_post.png")
	if seg == null:
		return
	var ts := float(World.TS)
	for y in World.H:
		var base := Vector2(ts * 0.5, (y + 1.0) * ts)
		var s := Sprite2D.new()
		s.texture = seg
		s.centered = false
		s.offset = Vector2(-seg.get_width() * 0.5, -seg.get_height() + 3.0)
		s.position = base
		ents.add_child(s)
		if post != null and (y % POST_EVERY == 0 or y == World.H - 1):
			_post(ents, post, base)
	# norte y sur: tramos horizontales (misma variedad que las cercas de las casas)
	var hs: Array[Texture2D] = [load("res://assets/world/props/fence_h_a.png"), load("res://assets/world/props/fence_h_b.png"), load("res://assets/world/props/fence_h_c.png")]
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 777
	for row in [0, World.H - 1]:
		for x in World.W:
			var base2 := Vector2((x + 0.5) * ts, (row + 1.0) * ts)
			if x == 0 or x == World.W - 1 or x % POST_EVERY == 0:
				if post != null:
					_post(ents, post, base2)
				if x == 0:
					continue
			var v := rnd.randi() % 7
			var t: Texture2D = hs[1] if v == 0 else (hs[2] if v == 1 else hs[0])
			var sp := Sprite2D.new()
			sp.texture = t
			sp.centered = false
			sp.offset = Vector2(-t.get_width() * 0.5, -t.get_height() + 3.0)
			sp.position = base2
			ents.add_child(sp)


static func _post(ents: Node2D, post: Texture2D, base: Vector2) -> void:
	var p := Sprite2D.new()
	p.texture = post
	p.centered = false
	p.offset = Vector2(-post.get_width() * 0.5, -post.get_height() + 3.0)
	p.position = base
	ents.add_child(p)
