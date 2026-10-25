class_name PixelArt
extends RefCounted
## Generador de pixel art placeholder: tiles, personajes, iconos y luces.
## Todo se dibuja por codigo para que el prototipo no dependa de archivos de arte.
## Cuando tengas arte real, reemplaza estas funciones por texturas importadas.

const TILE := 16

const T_ASPHALT := 0
const T_ASPHALT2 := 1
const T_ROAD_LINE := 2
const T_GRASS := 3
const T_GRASS2 := 4
const T_DIRT := 5
const T_FLOOR := 6
const T_WALL := 7
const T_RUBBLE := 8
const T_SIDEWALK := 9
const T_COUNT := 10


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, c)


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- tiles

static func _trect(img: Image, idx: int, x: int, y: int, w: int, h: int, c: Color) -> void:
	_rect(img, idx * TILE + x, y, w, h, c)


static func _tile_noise(img: Image, idx: int, base: Color, specks: Array, count: int, rng: RandomNumberGenerator) -> void:
	_trect(img, idx, 0, 0, TILE, TILE, base)
	for i in count:
		var c: Color = specks[rng.randi() % specks.size()]
		_trect(img, idx, rng.randi() % TILE, rng.randi() % TILE, 1, 1, c)


static func make_tile_atlas() -> ImageTexture:
	var img := Image.create(TILE * T_COUNT, TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	var asphalt_specks := [Color("26282d"), Color("383b42"), Color("2a2c31")]
	_tile_noise(img, T_ASPHALT, Color("2e3036"), asphalt_specks, 14, rng)

	_tile_noise(img, T_ASPHALT2, Color("2e3036"), asphalt_specks, 10, rng)
	for p in [Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 5), Vector2i(6, 6), Vector2i(7, 6), Vector2i(8, 7), Vector2i(9, 9)]:
		_trect(img, T_ASPHALT2, p.x, p.y, 1, 1, Color("1d1e22"))

	_tile_noise(img, T_ROAD_LINE, Color("2e3036"), asphalt_specks, 10, rng)
	_trect(img, T_ROAD_LINE, 2, 7, 12, 2, Color("c9a227"))

	var grass_specks := [Color("4a7a3a"), Color("2b4522"), Color("35602a")]
	_tile_noise(img, T_GRASS, Color("3d5a2e"), grass_specks, 18, rng)

	_tile_noise(img, T_GRASS2, Color("3d5a2e"), grass_specks, 12, rng)
	for p in [Vector2i(4, 5), Vector2i(4, 4), Vector2i(5, 4), Vector2i(11, 10), Vector2i(11, 9), Vector2i(10, 9)]:
		_trect(img, T_GRASS2, p.x, p.y, 1, 1, Color("6aa04c"))

	_tile_noise(img, T_DIRT, Color("6b5238"), [Color("5a4430"), Color("7c6244"), Color("4f3b28")], 18, rng)

	_tile_noise(img, T_FLOOR, Color("5a5750"), [Color("4f4c46"), Color("66635b")], 10, rng)
	_trect(img, T_FLOOR, 0, 0, TILE, 1, Color("45423d"))
	_trect(img, T_FLOOR, 0, 0, 1, TILE, Color("45423d"))

	_trect(img, T_WALL, 0, 0, TILE, TILE, Color("4d3b37"))
	for y in [3, 7, 11, 15]:
		_trect(img, T_WALL, 0, y, TILE, 1, Color("2a2220"))
	for x in [7]:
		_trect(img, T_WALL, x, 0, 1, 3, Color("2a2220"))
		_trect(img, T_WALL, x, 8, 1, 3, Color("2a2220"))
	for x in [3, 11]:
		_trect(img, T_WALL, x, 4, 1, 3, Color("2a2220"))
		_trect(img, T_WALL, x, 12, 1, 3, Color("2a2220"))
	_trect(img, T_WALL, 0, 0, TILE, 1, Color("6b544e"))

	_tile_noise(img, T_RUBBLE, Color("2e3036"), asphalt_specks, 8, rng)
	_trect(img, T_RUBBLE, 3, 4, 5, 4, Color("55575c"))
	_trect(img, T_RUBBLE, 3, 4, 5, 1, Color("73767c"))
	_trect(img, T_RUBBLE, 9, 8, 4, 4, Color("4a4c51"))
	_trect(img, T_RUBBLE, 9, 8, 4, 1, Color("686b71"))
	_trect(img, T_RUBBLE, 6, 11, 3, 2, Color("5f6166"))

	_tile_noise(img, T_SIDEWALK, Color("6c6c68"), [Color("62625e"), Color("76766f")], 10, rng)
	_trect(img, T_SIDEWALK, 0, 0, TILE, 1, Color("565652"))
	_trect(img, T_SIDEWALK, 0, 0, 1, TILE, Color("565652"))

	return _tex(img)


# ---------------------------------------------------------- personajes

static func zombie_palette() -> Dictionary:
	return {
		"skin": Color("7f9f6a"),
		"hair": Color("3a3326"),
		"hair_dark": Color("24201a"),
		"shirt": Color("5a4d45"),
		"shirt_light": Color("6b1f1f"),
		"pants": Color("3a3a32"),
		"shoes": Color("1b1b18"),
	}


static func make_humanoid_frames(pal: Dictionary, zombie: bool = false) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for facing in ["down", "up", "side"]:
		var idle_name: String = "idle_" + facing
		var walk_name: String = "walk_" + facing
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 2.0)
		frames.set_animation_loop(idle_name, true)
		frames.add_frame(idle_name, _tex(_humanoid(facing, 0, pal, zombie)))
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, 8.0)
		frames.set_animation_loop(walk_name, true)
		for step in [1, 0, 2, 0]:
			frames.add_frame(walk_name, _tex(_humanoid(facing, step, pal, zombie)))
	return frames


static func _humanoid(facing: String, step: int, pal: Dictionary, zombie: bool) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	_rect(img, 4, 14, 8, 2, Color(0, 0, 0, 0.28))
	var swing := 0
	if step == 1:
		swing = 1
	elif step == 2:
		swing = -1
	if facing == "side":
		_hum_side(img, swing, pal, zombie)
	else:
		_hum_front_back(img, facing == "up", swing, pal, zombie)
	return img


static func _hum_front_back(img: Image, back: bool, swing: int, pal: Dictionary, zombie: bool) -> void:
	var skin: Color = pal["skin"]
	var hair: Color = pal["hair"]
	var hair_dark: Color = pal["hair_dark"]
	var shirt: Color = pal["shirt"]
	var stripe: Color = pal["shirt_light"]
	var pants: Color = pal["pants"]
	var shoes: Color = pal["shoes"]

	# piernas
	var l_len := 3 - swing
	var r_len := 3 + swing
	_rect(img, 5, 11, 3, l_len, pants)
	_rect(img, 8, 11, 3, r_len, pants)
	_rect(img, 5, 11 + l_len - 1, 3, 1, shoes)
	_rect(img, 8, 11 + r_len - 1, 3, 1, shoes)

	# torso
	_rect(img, 4, 6, 8, 6, shirt)
	_rect(img, 4, 9, 8, 1, stripe)

	# brazos
	if zombie:
		_rect(img, 3, 7, 1, 5, shirt)
		_rect(img, 12, 7, 1, 5, shirt)
		_rect(img, 3, 12, 1, 1, skin)
		_rect(img, 12, 12, 1, 1, skin)
	else:
		var al := 7 + swing
		var ar := 7 - swing
		_rect(img, 3, al, 1, 3, shirt)
		_rect(img, 3, al + 3, 1, 1, skin)
		_rect(img, 12, ar, 1, 3, shirt)
		_rect(img, 12, ar + 3, 1, 1, skin)

	# cabeza
	if back:
		_rect(img, 5, 1, 6, 5, hair)
		_rect(img, 5, 1, 6, 1, hair_dark)
		_rect(img, 4, 2, 1, 2, hair)
		_rect(img, 11, 2, 1, 2, hair)
	else:
		_rect(img, 5, 1, 6, 5, skin)
		_rect(img, 5, 1, 6, 2, hair)
		_rect(img, 5, 1, 6, 1, hair_dark)
		_rect(img, 4, 2, 1, 2, hair)
		_rect(img, 11, 2, 1, 2, hair)
		var eye := Color("e8d44d") if zombie else Color("151515")
		_rect(img, 6, 4, 1, 1, eye)
		_rect(img, 9, 4, 1, 1, eye)
		if zombie:
			_rect(img, 7, 5, 2, 1, Color("4a1010"))


static func _hum_side(img: Image, swing: int, pal: Dictionary, zombie: bool) -> void:
	var skin: Color = pal["skin"]
	var hair: Color = pal["hair"]
	var hair_dark: Color = pal["hair_dark"]
	var shirt: Color = pal["shirt"]
	var stripe: Color = pal["shirt_light"]
	var pants: Color = pal["pants"]
	var shoes: Color = pal["shoes"]

	# piernas (la trasera mas oscura)
	var back_x := 6 - swing * 2
	var front_x := 6 + swing * 2
	_rect(img, back_x, 11, 3, 4, pants.darkened(0.25))
	_rect(img, back_x, 14, 3, 1, shoes.darkened(0.2))
	_rect(img, front_x, 11, 3, 4, pants)
	_rect(img, front_x, 14, 3, 1, shoes)

	# torso
	_rect(img, 5, 6, 6, 6, shirt)
	_rect(img, 5, 9, 6, 1, stripe)

	# brazo
	if zombie:
		_rect(img, 8, 7, 5, 2, shirt)
		_rect(img, 13, 7, 1, 2, skin)
	else:
		var arm_x := 7 + swing
		_rect(img, arm_x, 7, 2, 3, shirt.lightened(0.1))
		_rect(img, arm_x, 10, 2, 1, skin)

	# cabeza (mirando a la derecha)
	_rect(img, 5, 1, 5, 5, skin)
	_rect(img, 4, 1, 6, 2, hair)
	_rect(img, 4, 1, 6, 1, hair_dark)
	_rect(img, 4, 3, 2, 3, hair)
	var eye := Color("e8d44d") if zombie else Color("151515")
	_rect(img, 8, 4, 1, 1, eye)


# --------------------------------------------------------------- sangre

## Charco de sangre pixel art (el zombi lo deja al morir).
static func make_blood_splat(seed_value: int) -> ImageTexture:
	var img := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base := Color("6e1414")
	var wet := Color("a32420")
	var blobs := []
	for i in 5:
		blobs.append([rng.randi_range(6, 17), rng.randi_range(5, 10), rng.randi_range(2, 5)])
	for b in blobs:
		for y in range(b[1] - b[2], b[1] + b[2] + 1):
			for x in range(b[0] - b[2], b[0] + b[2] + 1):
				var d := Vector2(x - b[0], (y - b[1]) * 1.25).length()
				if d <= b[2] and x >= 0 and y >= 0 and x < 24 and y < 16:
					img.set_pixel(x, y, base)
	for b in blobs:
		var cx: int = b[0] - 1
		var cy: int = b[1] - 1
		if cx >= 0 and cy >= 0 and img.get_pixel(cx, cy).a > 0.0 and b[2] >= 3:
			img.set_pixel(cx, cy, wet)
			if cx + 1 < 24:
				img.set_pixel(cx + 1, cy, wet)
	for i in 7:   # gotas sueltas
		var x := rng.randi_range(1, 22)
		var y := rng.randi_range(1, 14)
		if img.get_pixel(x, y).a == 0.0:
			img.set_pixel(x, y, base)
	return _tex(img)


# -------------------------------------------------------------- iconos

static func make_icon(kind: String) -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	match kind:
		"scrap":
			_rect(img, 1, 3, 6, 3, Color("8a8d93"))
			_rect(img, 2, 2, 2, 1, Color("b4b7bd"))
			_rect(img, 4, 5, 3, 1, Color("55585e"))
			_rect(img, 2, 4, 1, 1, Color("3a3c41"))
		"food":
			_rect(img, 2, 2, 4, 5, Color("d9822b"))
			_rect(img, 2, 2, 4, 1, Color("c8ccd2"))
			_rect(img, 2, 6, 4, 1, Color("c8ccd2"))
			_rect(img, 3, 3, 2, 2, Color("f4d35e"))
		"water":
			_rect(img, 3, 0, 2, 1, Color("9aa0a8"))
			_rect(img, 2, 1, 4, 7, Color("4aa3df"))
			_rect(img, 3, 2, 1, 5, Color("a8e0ff"))
		"bandage":
			_rect(img, 1, 1, 6, 6, Color("ecebe6"))
			_rect(img, 3, 2, 2, 4, Color("c0392b"))
			_rect(img, 2, 3, 4, 2, Color("c0392b"))
		"manual":
			_rect(img, 1, 1, 6, 6, Color("3d6b4a"))
			_rect(img, 1, 1, 1, 6, Color("2a4a33"))
			_rect(img, 3, 2, 3, 1, Color("e0b030"))
			_rect(img, 3, 4, 2, 1, Color("e8e2cf"))
		"note":
			_rect(img, 1, 0, 6, 8, Color("e8e2cf"))
			_rect(img, 2, 2, 4, 1, Color("6b6456"))
			_rect(img, 2, 4, 4, 1, Color("6b6456"))
			_rect(img, 2, 6, 3, 1, Color("6b6456"))
		_:
			_rect(img, 1, 1, 6, 6, Color("ff00ff"))
	return _tex(img)


# --------------------------------------------------------------- luces

## Cono de linterna apuntando a +X (hacia la derecha). Origen en el centro.
static func make_cone_light(size: int = 256) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c)
			var r := d.length() / c
			var v := 0.0
			if r <= 1.0:
				var ang := absf(d.angle())
				var edge := clampf(1.0 - (ang - 0.25) / 0.3, 0.0, 1.0)
				v = edge * pow(1.0 - r, 1.1)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return _tex(img)


## Halo circular suave (luz ambiental alrededor del jugador).
static func make_radial_light(size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var r := Vector2(x - c, y - c).length() / c
			var v := pow(clampf(1.0 - r, 0.0, 1.0), 1.5)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return _tex(img)
