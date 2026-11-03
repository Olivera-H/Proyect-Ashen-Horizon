class_name Premium
extends RefCounted
## Capa de acceso a contenido de pago (mascotas). Guarda los derechos en user://premium.cfg.
##
## MODO DEMO: mientras no haya una tienda real conectada, "comprar" desbloquea al instante y
## el panel lo avisa con la etiqueta DEMO (nadie paga nada). Para cobrar de verdad hay que
## conectar Google Play Billing en `_store_purchase` y validar el recibo en un servidor
## (lo guardado en el telefono se puede editar). Ver docs/MONETIZACION.md.

const PATH := "user://premium.cfg"
## true = desbloqueo gratis de prueba. Poner en false al publicar con tienda real.
const DEMO := true

static var _owned: Dictionary = {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in cfg.get_section_keys("owned"):
		_owned[k] = bool(cfg.get_value("owned", k, false))


static func owns(id: String) -> bool:
	_ensure()
	return bool(_owned.get(id, false))


static func is_demo() -> bool:
	return DEMO


## True si la tienda real esta disponible en este dispositivo (plugin de Play Billing).
static func store_available() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling")


## Intenta comprar la mascota. Devuelve true si queda desbloqueada.
static func purchase(id: String) -> bool:
	_ensure()
	if owns(id):
		return true
	var ok := false
	if DEMO:
		ok = true
	else:
		ok = _store_purchase(Pets.get_def(id).get("sku", ""))
	if ok:
		_grant(id)
	return ok


## Punto de enganche para Google Play Billing (no incluido: requiere cuenta de Play Console).
static func _store_purchase(_sku: String) -> bool:
	return false


static func _grant(id: String) -> void:
	_owned[id] = true
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("owned", id, true)
	cfg.save(PATH)
