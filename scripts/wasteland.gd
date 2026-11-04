class_name Wasteland
extends RefCounted
## Borde oeste del mapa: una cerca recorre toda la columna 0 y, al otro lado, se ve un campo
## desolado con zombis muertos (assets/world/wasteland.png, ver tools/gen_wasteland.py).
## El campo es solo decorado: la cerca es solida y el jugador no puede cruzar.

const TEX := "res://assets/world/wasteland.png"
const WIDTH_PX := 384           # ancho visible del campo (24 tiles)
const POST_EVERY := 5


## Marca la columna 0 como cerca solida (antes de colocar props y colisiones).
static func reserve(w: World) -> void:
	for y in World.H:
		w._put_solid(0, y, 1)
		w.prop_block[y * World.W] = 1
		w.prop_block[y * World.W + 1] = 1


## Suelo del campo (bajo las entidades).
static func build_ground(parent: Node2D) -> void:
	if not ResourceLoader.exists(TEX):
		return
	var s := Sprite2D.new()
	s.texture = load(TEX)
	s.centered = false
	s.position = Vector2(-WIDTH_PX, 0)
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
		if post != null and y % POST_EVERY == 0:
			var p := Sprite2D.new()
			p.texture = post
			p.centered = false
			p.offset = Vector2(-post.get_width() * 0.5, -post.get_height() + 3.0)
			p.position = base
			ents.add_child(p)
