class_name Characters
extends RefCounted
## Datos de los protagonistas. Mateo es el jugable en este prototipo;
## Lena queda definida para cuando se agregue la seleccion de personaje.

const DATA := {
	"mateo": {
		"name": "Mateo Vargas",
		"max_health": 120.0,
		"max_stamina": 130.0,
		"stamina_regen": 26.0,
		"walk_speed": 68.0,
		"run_speed": 112.0,
		"melee_damage": 1.25,   # multiplicador de dano cuerpo a cuerpo
		"aim_spread": 1.6,      # mayor = peor punteria (para armas de fuego futuras)
		"craft_bonus": 1.0,
		"palette": {
			"skin": Color("d9a066"),
			"hair": Color("c0392b"),       # casco rojo de bombero
			"hair_dark": Color("8e2a20"),
			"shirt": Color("2c3e50"),
			"shirt_light": Color("f1c40f"), # franja reflectante
			"pants": Color("3b3b4f"),
			"shoes": Color("1b1b24"),
		},
	},
	"lena": {
		"name": "Lena Ortiz",
		"max_health": 90.0,
		"max_stamina": 100.0,
		"stamina_regen": 22.0,
		"walk_speed": 70.0,
		"run_speed": 108.0,
		"melee_damage": 0.9,
		"aim_spread": 0.6,
		"craft_bonus": 1.35,
		"palette": {
			"skin": Color("e0b088"),
			"hair": Color("3a2418"),
			"hair_dark": Color("22150e"),
			"shirt": Color("e8e8e8"),
			"shirt_light": Color("2e86c1"),
			"pants": Color("34495e"),
			"shoes": Color("1b1b24"),
		},
	},
}

static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["mateo"])
