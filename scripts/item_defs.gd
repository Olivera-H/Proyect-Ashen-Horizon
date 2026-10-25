class_name ItemDefs
extends RefCounted
## Catalogo de objetos y habilidades del inventario.
## Los iconos estan en assets/ui/inv/ (tools/gen_inventory_ui.py): item_<id>.png / skill_<id>.png.

const ITEMS := {
	"bandage": {"name": "Vendaje", "desc": "+25 de vida y -20 de infección.", "max": 5, "use": true},
	"food": {"name": "Comida", "desc": "Sacia 35 de hambre.", "max": 5, "use": true},
	"water": {"name": "Agua", "desc": "Sacia 40 de sed.", "max": 5, "use": true},
	"scrap": {"name": "Chatarra", "desc": "Gasta 2 para reparar el arma.", "max": 8, "use": true},
	"golpe": {"name": "Golpe fuerte", "desc": "Habilidad: +25% de daño cuerpo a cuerpo.", "skill": true},
	"resistencia": {"name": "Resistencia", "desc": "Habilidad: la estamina se recupera 40% más rápido.", "skill": true},
	"pies": {"name": "Pies ligeros", "desc": "Habilidad: caminas y corres 8% más rápido.", "skill": true},
	"manos": {"name": "Manos hábiles", "desc": "Habilidad: reparas 50% más con la misma chatarra.", "skill": true},
	"estomago": {"name": "Estómago fuerte", "desc": "Habilidad: el hambre y la sed bajan 40% más lento.", "skill": true},
	"sigilo": {"name": "Sigilo", "desc": "Habilidad: haces 35% menos ruido.", "skill": true},
}
const SKILLS := ["golpe", "resistencia", "pies", "manos", "estomago", "sigilo"]

static var _tex := {}


static func is_skill(id: String) -> bool:
	return ITEMS.get(id, {}).get("skill", false)


static func max_stack(id: String) -> int:
	return ITEMS.get(id, {}).get("max", 1)


static func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


static func icon(id: String) -> Texture2D:
	if not _tex.has(id):
		var prefix := "skill_" if is_skill(id) else "item_"
		var path := "res://assets/ui/inv/%s%s.png" % [prefix, id]
		_tex[id] = load(path) if ResourceLoader.exists(path) else null
	return _tex[id]
