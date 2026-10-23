class_name SpriteSheets
extends RefCounted
## Carga las hojas de sprites de assets/sprites/ y arma los SpriteFrames.
## Las hojas las genera tools/gen_sprites.py (o puedes pintarlas a mano):
## 12 filas (animaciones) x 4 columnas (cuadros). Ver ANIMS.
## 'side' mira a la derecha; el nodo AnimatedSprite2D lo voltea con flip_h.

const ANIMS := [
	["idle_down", 2], ["idle_up", 2], ["idle_side", 2],
	["walk_down", 4], ["walk_up", 4], ["walk_side", 4],
	["run_down", 4], ["run_up", 4], ["run_side", 4],
	["attack_down", 3], ["attack_up", 3], ["attack_side", 3],
]
const SPEEDS := {"idle": 2.5, "walk": 8.0, "run": 11.0, "attack": 16.0}

# Tamano de cuadro y posicion del sprite respecto al origen del cuerpo (los pies).
const HUMAN := Vector2i(24, 32)
const HUMAN_POS := Vector2(0, -7)
const TANK := Vector2i(40, 44)
const TANK_POS := Vector2(0, -15)

static var _cache := {}


## Devuelve null si la hoja no existe (el llamador usa el arte de respaldo).
static func frames(sheet: String, size: Vector2i) -> SpriteFrames:
	var key := "%s_%d_%d" % [sheet, size.x, size.y]
	if _cache.has(key):
		return _cache[key]
	var path := "res://assets/sprites/%s.png" % sheet
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	if tex == null:
		return null
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for row in ANIMS.size():
		var anim_name: String = ANIMS[row][0]
		var count: int = ANIMS[row][1]
		var kind: String = anim_name.split("_")[0]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, SPEEDS[kind])
		sf.set_animation_loop(anim_name, kind != "attack")
		for col in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(col * size.x, row * size.y, size.x, size.y)
			sf.add_frame(anim_name, at)
	_cache[key] = sf
	return sf


## Elige la animacion si existe; si no (arte de respaldo), cae a una equivalente.
static func pick(sf: SpriteFrames, prefix: String, facing_name: String) -> String:
	var wanted := prefix + facing_name
	if sf.has_animation(wanted):
		return wanted
	var alt := ("walk_" if prefix != "idle_" else "idle_") + facing_name
	return alt if sf.has_animation(alt) else "idle_down"
