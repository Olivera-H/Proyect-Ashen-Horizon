class_name Pets
extends RefCounted
## Catalogo de mascotas premium. Cada una da un buff propio y, al equiparla,
## la mochila pasa de 15 a 18 casillas (BAG_BONUS).

const BAG_BONUS := 3
const FRAME := Vector2i(24, 24)

## buff: clave que consulta el juego con Pets.buff("clave"); valor = multiplicador o radio.
const LIST := [
	{"id": "ceniza", "name": "CENIZA", "kind": "PERRO LOBO", "sku": "pet_ceniza", "price": "$1.99",
		"buffs": ["Olfato: recoges objetos desde +60% más lejos", "Colmillo: tus golpes +10% de daño"],
		"pickup": 1.6, "melee": 1.10, "color": Color("c8412f")},
	{"id": "sombra", "name": "SOMBRA", "kind": "GATO NEGRO", "sku": "pet_sombra", "price": "$1.99",
		"buffs": ["Sigilo felino: haces 25% menos ruido", "Ojos de noche: luz tenue a tu alrededor"],
		"noise": 0.75, "glow": 0.5, "color": Color("4fd6e6")},
	{"id": "presagio", "name": "PRESAGIO", "kind": "CUERVO", "sku": "pet_presagio", "price": "$2.99",
		"buffs": ["Vigía: la estamina regenera +30%", "Presagio: hambre y sed bajan 15% más lento"],
		"stamina": 1.3, "drain": 0.85, "flies": true, "color": Color("b78cff")},
	{"id": "ambar", "name": "ÁMBAR", "kind": "ZORRO", "sku": "pet_ambar", "price": "$2.99",
		"buffs": ["Instinto: +10% de velocidad al moverte", "Brasa: lleva una luz cálida que alumbra de noche"],
		"speed": 1.10, "glow": 1.0, "glow_color": Color("ffb45a"), "color": Color("62d26f")},
]


static func get_def(id: String) -> Dictionary:
	for p in LIST:
		if p["id"] == id:
			return p
	return {}


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return -1


## Mascota equipada (vacia si no hay o si no esta desbloqueada).
static func current() -> Dictionary:
	Settings.ensure()
	if Settings.pet == "" or not Premium.owns(Settings.pet):
		return {}
	return get_def(Settings.pet)


static func equipped() -> bool:
	return not current().is_empty()


## Valor de un buff de la mascota equipada, o `fallback` si no tiene.
static func buff(key: String, fallback: float = 1.0) -> float:
	var d := current()
	return float(d[key]) if d.has(key) else fallback


static func bag_size() -> int:
	return Inventory.BAG_BASE + (BAG_BONUS if equipped() else 0)
