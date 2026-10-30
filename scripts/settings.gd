class_name Settings
extends RefCounted
## Ajustes de la partida guardados en el dispositivo (user://game_settings.cfg):
## skin elegida del protagonista y "no mostrar mensajes".

const PATH := "user://game_settings.cfg"
## id de la hoja de sprites (assets/sprites/<id>.png), nombre y oficio.
const SKINS := [
	{"id": "mateo", "name": "MATEO VARGAS", "job": "BOMBERO"},
	{"id": "lena", "name": "LENA ORTIZ", "job": "INVESTIGADORA"},
	{"id": "soldado", "name": "CABO RAMOS", "job": "SOLDADO"},
	{"id": "medica", "name": "DRA. SALAS", "job": "MÉDICA"},
	{"id": "mecanico", "name": "TOMÁS PARDO", "job": "MECÁNICO"},
	{"id": "motero", "name": "DANTE RIVAS", "job": "MOTERO"},
	{"id": "granjero", "name": "ABEL CRUZ", "job": "GRANJERO"},
]

static var skin := "mateo"
static var hide_messages := false
static var _loaded := false


static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	skin = str(cfg.get_value("game", "skin", "mateo"))
	hide_messages = bool(cfg.get_value("game", "hide_messages", false))
	if skin_index() < 0:
		skin = "mateo"


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "skin", skin)
	cfg.set_value("game", "hide_messages", hide_messages)
	cfg.save(PATH)


static func skin_index() -> int:
	for i in SKINS.size():
		if SKINS[i]["id"] == skin:
			return i
	return -1


static func cycle_skin(step: int) -> void:
	ensure()
	var i := maxi(0, skin_index())
	skin = SKINS[posmod(i + step, SKINS.size())]["id"]
	save()
