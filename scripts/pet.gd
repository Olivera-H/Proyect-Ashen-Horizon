class_name Pet
extends Node2D
## Mascota que sigue al jugador en tiempo real. Es solo decoracion + buffs (no recibe dano ni
## estorba): se mueve con un resorte suave detras del jugador, esquiva muros por ejes,
## y si se queda muy atras se teletransporta junto a el.

const FOLLOW_DIST := 20.0
const STOP_DIST := 12.0
const SPEED_MAX := 128.0
const WARP_DIST := 170.0

var player: Node2D
var world: Node
var def: Dictionary
var sprite: AnimatedSprite2D
var _facing := "down"
var _flip := false
var _hover_t := 0.0
var _flies := false
var _bark_t := 0.0


static var _frames_cache := {}


static func frames_for(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var path := "res://assets/sprites/pet_%s.png" % id
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var names := ["idle_down", "idle_up", "idle_side", "walk_down", "walk_up", "walk_side"]
	for row in names.size():
		var n: String = names[row]
		sf.add_animation(n)
		sf.set_animation_speed(n, 4.0 if n.begins_with("idle") else 9.0)
		sf.set_animation_loop(n, true)
		for col in 4:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(col * Pets.FRAME.x, row * Pets.FRAME.y, Pets.FRAME.x, Pets.FRAME.y)
			sf.add_frame(n, at)
	_frames_cache[id] = sf
	return sf


func setup(p: Node2D, w: Node) -> void:
	player = p
	world = w
	def = Pets.current()
	_flies = bool(def.get("flies", false))
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames_for(def["id"])
	sprite.offset = Vector2(0, -10)
	sprite.play("idle_down")
	add_child(sprite)
	if def.has("glow"):
		var l := PointLight2D.new()
		l.texture = PixelArt.make_radial_light(96)
		l.texture_scale = 1.1
		l.energy = 0.55 * float(def["glow"])
		l.color = def.get("glow_color", Color("cfe6ff"))
		l.position = Vector2(0, -8)
		add_child(l)
	position = p.position + Vector2(-FOLLOW_DIST, 6.0)
	add_to_group("pets")


func _solid(pos: Vector2) -> bool:
	if _flies or world == null:
		return false
	return world.is_solid_tile(Vector2i(int(floor(pos.x / World.TS)), int(floor(pos.y / World.TS))))


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var to_p := player.position - position
	var d := to_p.length()
	if d > WARP_DIST:
		position = player.position + Vector2(-FOLLOW_DIST, 4.0)
		return
	var vel := Vector2.ZERO
	if d > FOLLOW_DIST:
		var sp := clampf((d - STOP_DIST) * 5.0, 20.0, SPEED_MAX)
		vel = to_p / d * sp
	if vel != Vector2.ZERO:
		# eje por eje para deslizar contra paredes
		var nx := position + Vector2(vel.x * delta, 0)
		if not _solid(nx):
			position = nx
		var ny := position + Vector2(0, vel.y * delta)
		if not _solid(ny):
			position = ny
		if absf(vel.x) > absf(vel.y):
			_facing = "side"
			_flip = vel.x < 0.0
		else:
			_facing = "down" if vel.y > 0.0 else "up"
	var moving := vel.length() > 8.0
	var anim := ("walk_" if moving else "idle_") + _facing
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.flip_h = _flip and _facing == "side"
	if _flies:
		_hover_t += delta * 3.0
		sprite.offset.y = -14.0 + sin(_hover_t) * 2.0
