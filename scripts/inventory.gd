class_name Inventory
extends RefCounted
## Modelo del inventario: 3 casillas rapidas (barra inferior), una mochila de 15 y
## 3 casillas de habilidades equipadas. Cada casilla es null o {id, n}.

signal changed

const HOTBAR := 3
const BAG_BASE := 15            # mochila normal
const BAG := 18                 # tamaño maximo (con mascota equipada: Pets.BAG_BONUS)
const SKILL_SLOTS := 3
const TOTAL := HOTBAR + BAG + SKILL_SLOTS
const BAG_START := HOTBAR
const SKILL_START := HOTBAR + BAG

## Casillas de mochila usables ahora (15, o 18 con mascota equipada).
var bag_size := BAG_BASE

var slots: Array = []


func _init() -> void:
	slots.resize(TOTAL)
	slots.fill(null)


## true si la casilla existe y se puede usar (las 3 ultimas de la mochila exigen mascota).
func usable(i: int) -> bool:
	if i >= BAG_START and i < SKILL_START:
		return i < BAG_START + bag_size
	return true


## Cambia el tamaño de mochila. Al quitar la mascota, lo que haya en las casillas extra
## se recoloca en huecos libres; si no cabe, se queda en la casilla (no se pierde) pero
## bloqueada hasta volver a equipar.
func set_bag_size(n: int) -> void:
	if n == bag_size:
		return
	bag_size = n
	if n < BAG:
		for i in range(BAG_START + n, SKILL_START):
			var s = slots[i]
			if s == null:
				continue
			for j in range(0, BAG_START + n):
				if slots[j] == null and accepts(j, s["id"]):
					slots[j] = s
					slots[i] = null
					break
	changed.emit()


static func kind_of(i: int) -> String:
	if i < BAG_START:
		return "hotbar"
	if i < SKILL_START:
		return "bag"
	return "skill"


func accepts(i: int, id: String) -> bool:
	var skill := ItemDefs.is_skill(id)
	match kind_of(i):
		"skill":
			return skill
		"hotbar":
			return not skill
	return true


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["id"] == id:
			n += int(s["n"])
	return n


func has_equipped(id: String) -> bool:
	for i in range(SKILL_START, TOTAL):
		if slots[i] != null and slots[i]["id"] == id:
			return true
	return false


func owns(id: String) -> bool:
	return count(id) > 0


## Mete n unidades: primero completa montones, luego usa casillas libres (barra rapida y luego mochila).
## Devuelve las unidades que no cupieron.
func add(id: String, n: int = 1, durability: float = -1.0) -> int:
	var maxn := ItemDefs.max_stack(id)
	var order: Array = []
	if ItemDefs.is_skill(id):
		order = range(BAG_START, BAG_START + bag_size)
	else:
		order = range(0, BAG_START + bag_size)
	for i in order:
		if n <= 0:
			break
		var s = slots[i]
		if s != null and s["id"] == id and int(s["n"]) < maxn:
			var put := mini(n, maxn - int(s["n"]))
			s["n"] = int(s["n"]) + put
			n -= put
	for i in order:
		if n <= 0:
			break
		if slots[i] == null:
			var put := mini(n, maxn)
			slots[i] = {"id": id, "n": put}
			if ItemDefs.is_weapon(id) and not ItemDefs.is_gun(id):
				slots[i]["d"] = durability if durability >= 0.0 else float(ItemDefs.ITEMS[id]["dur"])
			n -= put
	changed.emit()
	return n


func remove(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	# primero de la mochila, luego de la barra rapida
	var order: Array = range(BAG_START, SKILL_START) + range(0, BAG_START)
	for i in order:
		if n <= 0:
			break
		var s = slots[i]
		if s != null and s["id"] == id:
			var take := mini(n, int(s["n"]))
			s["n"] = int(s["n"]) - take
			n -= take
			if int(s["n"]) <= 0:
				slots[i] = null
	changed.emit()
	return true


func take_one(i: int) -> void:
	var s = slots[i]
	if s == null:
		return
	s["n"] = int(s["n"]) - 1
	if int(s["n"]) <= 0:
		slots[i] = null
	changed.emit()


func discard(i: int) -> void:
	slots[i] = null
	changed.emit()


## Mueve o intercambia dos casillas respetando que las de habilidad solo aceptan habilidades.
## Si son del mismo objeto, junta los montones. Devuelve true si algo cambio.
func move(a: int, b: int) -> bool:
	if a == b or slots[a] == null:
		return false
	var sa = slots[a]
	var sb = slots[b]
	if not usable(b) or not accepts(b, sa["id"]):
		return false
	if sb != null and not accepts(a, sb["id"]):
		return false
	if sb != null and sb["id"] == sa["id"] and not ItemDefs.is_skill(sa["id"]):
		var maxn := ItemDefs.max_stack(sa["id"])
		var put := mini(int(sa["n"]), maxn - int(sb["n"]))
		if put > 0:
			sb["n"] = int(sb["n"]) + put
			sa["n"] = int(sa["n"]) - put
			if int(sa["n"]) <= 0:
				slots[a] = null
			changed.emit()
			return true
	slots[a] = sb
	slots[b] = sa
	changed.emit()
	return true
