class_name ItemDefs
extends RefCounted
## Catalogo de objetos y habilidades del inventario.
## Los iconos estan en assets/ui/inv/ (tools/gen_inventory_ui.py): item_<id>.png / skill_<id>.png.

const ITEMS := {
	"bandage": {"name": "Vendaje", "desc": "+25 de vida y -20 de infección.", "max": 5, "use": true},
	"food": {"name": "Comida", "desc": "Sacia 35 de hambre.", "max": 5, "use": true},
	"water": {"name": "Agua", "desc": "Sacia 40 de sed.", "max": 5, "use": true},
	"scrap": {"name": "Chatarra", "desc": "Gasta 2 para reparar el arma.", "max": 8, "use": true},
	"tubo": {"name": "Tubo de hierro", "desc": "Cuerpo a cuerpo. Se desgasta; repáralo con chatarra.", "max": 1, "weapon": "melee", "dmg": 18.0, "cd": 0.45, "range": 42.0, "dur": 40.0, "noise": 90.0},
	"machete": {"name": "Machete", "desc": "Cuerpo a cuerpo rápido y afilado. Se desgasta.", "max": 1, "weapon": "melee", "dmg": 22.0, "cd": 0.36, "range": 40.0, "dur": 35.0, "noise": 80.0},
	"hacha": {"name": "Hacha de bombero", "desc": "Cuerpo a cuerpo lento pero devastador. Se desgasta.", "max": 1, "weapon": "melee", "dmg": 34.0, "cd": 0.7, "range": 46.0, "dur": 32.0, "noise": 100.0},
	"pistola": {"name": "Pistola", "desc": "Dispara balas. Precisa, pero el disparo se oye lejos.", "max": 1, "weapon": "gun", "ammo": "balas", "dmg": 34.0, "cd": 0.34, "range": 230.0, "pellets": 1, "spread": 0.04, "noise": 280.0},
	"escopeta": {"name": "Escopeta", "desc": "Dispara cartuchos. Devasta de cerca; muy ruidosa.", "max": 1, "weapon": "gun", "ammo": "cartuchos", "dmg": 17.0, "cd": 0.95, "range": 120.0, "pellets": 5, "spread": 0.26, "noise": 340.0},
	"fusil": {"name": "Fusil de asalto", "desc": "Dispara balas muy rápido. Arma militar; hace muchísimo ruido.", "max": 1, "weapon": "gun", "ammo": "balas", "dmg": 26.0, "cd": 0.13, "range": 260.0, "pellets": 1, "spread": 0.07, "noise": 380.0},
	"mascara": {"name": "Máscara antigás", "desc": "Mientras la lleves en la mochila te protege de la lluvia ácida y del aire tóxico.", "max": 1, "key": true},
	"llave": {"name": "Llave del búnker H-7", "desc": "Llave de acceso del coronel Reyes. Abre el búnker de la Zona Cero.", "max": 1, "key": true},
	"suero": {"name": "Suero H-7", "desc": "La muestra madre. Llévala al refugio.", "max": 1, "key": true},
	"semillas": {"name": "Semillas", "desc": "Plántalas en las parcelas del huerto del refugio y cosecha comida.", "max": 10},
	"balas": {"name": "Balas", "desc": "Munición de la pistola.", "max": 18},
	"cartuchos": {"name": "Cartuchos", "desc": "Munición de la escopeta.", "max": 8},
	"tarjeta": {"name": "Tarjeta Horizonte", "desc": "Acceso de nivel 3. Abre la puerta del laboratorio.", "max": 1, "key": true},
	"golpe": {"name": "Golpe fuerte", "desc": "Habilidad: +25% de daño cuerpo a cuerpo.", "skill": true},
	"resistencia": {"name": "Resistencia", "desc": "Habilidad: la estamina se recupera 40% más rápido.", "skill": true},
	"pies": {"name": "Pies ligeros", "desc": "Habilidad: caminas y corres 8% más rápido.", "skill": true},
	"manos": {"name": "Manos hábiles", "desc": "Habilidad: reparas 50% más con la misma chatarra.", "skill": true},
	"estomago": {"name": "Estómago fuerte", "desc": "Habilidad: el hambre y la sed bajan 40% más lento.", "skill": true},
	"sigilo": {"name": "Sigilo", "desc": "Habilidad: haces 35% menos ruido.", "skill": true},
}
const SKILLS := ["golpe", "resistencia", "pies", "manos", "estomago", "sigilo"]

static var _tex := {}


## Cuanto da cada recogida de municion o arma.
const PICKUP_AMOUNT := {"balas": 6, "cartuchos": 3, "semillas": 3}


static func is_weapon(id: String) -> bool:
	return ITEMS.get(id, {}).has("weapon")


static func is_gun(id: String) -> bool:
	return ITEMS.get(id, {}).get("weapon", "") == "gun"


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
