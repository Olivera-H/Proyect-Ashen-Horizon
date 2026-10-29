class_name Refuge
extends Node2D
## Mejoras del refugio, en el patio cercado junto a la casa:
## - Mesa de trabajo: fabrica vendajes, municion, combustible y semillas con chatarra.
## - Botiquin ampliable: guarda vendajes como cargas (3/6/10) que curan mas que un vendaje suelto.
## - Cofre: guarda recursos (hasta CHEST_CAP unidades) para no cargarlos en la mochila.
## - Generador: gasta combustible; encendido da calor de noche, cura mas rapido y enciende las luces.
##   De noche, sin generador, el refugio esta frio: no cura casi y el hambre y la sed bajan mas rapido.
## La interfaz (panel) esta en station_menu.gd; aqui viven el estado, el dibujo y las reglas.

const FUEL_MAX := 100.0
const FUEL_CAN := 30.0         # lo que aporta un bidon
const BURN := 0.3              # combustible por segundo con el generador encendido
const NEAR_R := 30.0
const MED_CAP := [3, 6, 10]
const MED_HEAL := [40.0, 50.0, 60.0]
const MED_COST := [0, 6, 10]   # chatarra para llegar a cada nivel
const CHEST_CAP := 60
const CHEST_ITEMS := ["bandage", "food", "water", "scrap", "semillas", "combustible", "balas", "cartuchos"]
## Lamparas del interior (tiles desde la esquina de la casa); coinciden con "lamps" de tools/gen_buildings.py.
const LAMPS := [Vector2(3.6, 5.4), Vector2(9.6, 5.4), Vector2(6.6, 8.7)]
const LAMP_ON := 18.0          # hora a la que se encienden las luces
const LAMP_OFF := 6.0
const RECIPES := [
	{"id": "bandage", "name": "Vendaje", "n": 1, "cost": 3},
	{"id": "balas", "name": "Balas x6", "give": "balas", "n": 6, "cost": 5},
	{"id": "cartuchos", "name": "Cartuchos x3", "give": "cartuchos", "n": 3, "cost": 6},
	{"id": "combustible", "name": "Combustible", "n": 1, "cost": 6},
	{"id": "semillas", "name": "Semillas x3", "n": 3, "cost": 2},
]

var world: World
var player: Player
var stations := {}             # nombre -> {c: Vector2 centro, rect: Rect2}
var gen_on := false
var fuel := 0.0
var med_level := 0
var med_charges := 2
var chest := {}                # id -> unidades guardadas
var hour := 12.0               # hora del dia (0-24), la fija main
var near := ""
var _low_warned := false
var _gen_light: PointLight2D
var _door_light: PointLight2D
var _lamp_lights: Array = []
var _lamp_k := 0.0
var _night := 1.0
var _loop_on := false
var _t := 0.0


func setup(w: World, ents: Node2D) -> void:
	world = w
	if w.refuge_b.is_empty() or w.fence.is_empty():
		return
	var house: Rect2i = w.refuge_b["rect"]
	var ring: Rect2i = w.fence["ring"]
	var door: Vector2i = w.refuge_b["door"]
	var ts := float(World.TS)
	var o := Vector2(house.position) * ts
	# dentro de la casa (ver "reserve" en tools/gen_buildings.py): cofre, botiquin y mesa de trabajo
	_add("chest", Rect2(o + Vector2(5.0, 3.55) * ts, Vector2(2, 1) * ts), ents)
	_add("medkit", Rect2(o + Vector2(7.7, 3.2) * ts, Vector2(1, 1) * ts), ents)
	_add("bench", Rect2(o + Vector2(9.0, 3.55) * ts, Vector2(2, 1) * ts), ents)
	# el generador queda fuera, en el patio delantero, junto al caminito
	_add("generator", Rect2(Vector2(door.x + 4, house.end.y) * ts, Vector2(2, 2) * ts), ents)
	for lp in LAMPS:
		_lamp_lights.append(_make_light(o + lp * ts, 2.0, Color("ffd9a0")))
	var g: Rect2 = stations["generator"]["rect"]
	_gen_light = _make_light(g.get_center() + Vector2(0, -6), 1.6, Color("ffd890"))
	_door_light = _make_light(Vector2((door.x + 1) * ts, (house.end.y - 1.5) * ts), 2.6, Color("ffcf80"))
	# colision de los tres puestos
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for k in stations:
		var r: Rect2 = stations[k]["rect"]
		var box := Rect2(r.position + Vector2(1, r.size.y * 0.45), Vector2(r.size.x - 2, r.size.y * 0.55 - 1))
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = box.size
		cs.shape = rs
		cs.position = box.position + box.size * 0.5
		body.add_child(cs)


func _make_light(pos: Vector2, scale_: float, col: Color) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = PixelArt.make_radial_light(128)
	l.texture_scale = scale_
	l.color = col
	l.energy = 0.0
	l.position = pos
	add_child(l)
	return l


func _add(name_: String, rect: Rect2, ents: Node2D) -> void:
	stations[name_] = {"c": rect.get_center(), "rect": rect}
	var p := Prop.new()
	p.kind = name_
	p.refuge = self
	p.size = rect.size
	p.position = Vector2(rect.get_center().x, rect.end.y)
	ents.add_child(p)


## 1 = pleno dia, 0 = noche cerrada (lo fija main cada fotograma).
func set_daylight(k: float) -> void:
	_night = 1.0 - k


func _process(delta: float) -> void:
	_t += delta
	if stations.is_empty():
		return
	if gen_on:
		fuel = maxf(0.0, fuel - BURN * delta)
		if fuel <= FUEL_MAX * 0.2 and not _low_warned:
			_low_warned = true
			_say("El generador tiene poco combustible.")
		if fuel <= 0.0:
			gen_on = false
			Sfx.play("gen_stop", -4.0)
			_say("El generador se quedó sin combustible.")
	if fuel > FUEL_MAX * 0.2:
		_low_warned = false
	var e := (0.35 + 0.65 * _night) if gen_on else 0.0
	e *= 0.94 + 0.06 * sin(_t * 23.0)
	_gen_light.energy = e * 0.9
	# luces de la casa: encienden a las 18:00 y se apagan a las 6:00; con el generador brillan mas
	var want_k := 1.0 if (hour >= LAMP_ON or hour < LAMP_OFF) else 0.0
	_lamp_k = move_toward(_lamp_k, want_k, delta * 0.8)
	var lamp_e := _lamp_k * (0.95 if gen_on else 0.6) * (0.97 + 0.03 * sin(_t * 9.0))
	for l in _lamp_lights:
		(l as PointLight2D).energy = lamp_e * (1.0 if gen_on else 0.9)
		(l as PointLight2D).color = Color("ffe2b0") if gen_on else Color("ffc88a")
	_door_light.energy = lamp_e * 0.8
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	near = ""
	if player != null and not player.dead:
		var pp := to_local(player.global_position)
		var best := NEAR_R
		for k in stations:
			var d := pp.distance_to(stations[k]["c"])
			if d < best:
				best = d
				near = k
		var want := gen_on and pp.distance_to(stations["generator"]["c"]) < 220.0
		if want != _loop_on:
			_loop_on = want
			Sfx.loop("gen_loop", want, -14.0)


func _say(t: String) -> void:
	if player != null:
		player.toast.emit(t)


func station_title(k: String) -> String:
	match k:
		"bench":
			return "MESA DE TRABAJO"
		"medkit":
			return "BOTIQUÍN DEL REFUGIO"
		"chest":
			return "COFRE DEL REFUGIO"
	return "GENERADOR"


# ------------------------------------------------------------- reglas

func scrap() -> int:
	return player.inventory.count("scrap")


func craft(i: int) -> void:
	var r: Dictionary = RECIPES[i]
	if scrap() < int(r["cost"]):
		_say("Te falta chatarra (%d)." % int(r["cost"]))
		return
	var give: String = r.get("give", r["id"])
	var n: int = int(r["n"])
	var left := player.inventory.add(give, n)
	if left > 0:
		player.inventory.remove(give, n - left)
		_say("Mochila llena: libera espacio.")
		return
	player.inventory.remove("scrap", int(r["cost"]))
	Sfx.play("craft", -2.0)
	_say("Fabricaste: %s." % String(r["name"]).to_lower())


func med_cap() -> int:
	return MED_CAP[med_level]


func med_use() -> void:
	if med_charges <= 0:
		_say("El botiquín no tiene cargas: guarda vendajes.")
		return
	if player.health >= player.max_health and player.infection <= 0.0:
		_say("No necesitas curarte ahora.")
		return
	med_charges -= 1
	player.health = minf(player.max_health, player.health + MED_HEAL[med_level])
	player.infection = maxf(0.0, player.infection - 30.0)
	Sfx.play("heal", -3.0)
	_say("Botiquín: te curaste.")


func med_store() -> void:
	if med_charges >= med_cap():
		_say("El botiquín está lleno.")
		return
	if not player.inventory.remove("bandage", 1):
		_say("No tienes vendajes.")
		return
	med_charges += 1
	Sfx.play("equip", -4.0)
	_say("Guardaste un vendaje en el botiquín.")


func med_upgrade() -> void:
	if med_level >= MED_CAP.size() - 1:
		return
	var cost: int = MED_COST[med_level + 1]
	if scrap() < cost:
		_say("Ampliar cuesta %d de chatarra." % cost)
		return
	player.inventory.remove("scrap", cost)
	med_level += 1
	Sfx.play("repair", -2.0)
	_say("Botiquín ampliado: nivel %d (%d cargas, cura %d)." % [med_level + 1, med_cap(), int(MED_HEAL[med_level])])


func chest_total() -> int:
	var n := 0
	for k in chest:
		n += int(chest[k])
	return n


## Guarda unidades de la mochila en el cofre (n = 0 -> todas las que quepan).
func chest_put(id: String, n: int) -> void:
	var have: int = player.inventory.count(id)
	var amount := mini(have if n <= 0 else n, CHEST_CAP - chest_total())
	if have <= 0:
		return
	if amount <= 0:
		_say("El cofre está lleno.")
		return
	player.inventory.remove(id, amount)
	chest[id] = int(chest.get(id, 0)) + amount
	Sfx.play("equip", -4.0)


## Saca unidades del cofre a la mochila (n = 0 -> todas las que quepan).
func chest_take(id: String, n: int) -> void:
	var have: int = int(chest.get(id, 0))
	if have <= 0:
		return
	var want := have if n <= 0 else mini(n, have)
	var left: int = player.inventory.add(id, want)
	var got := want - left
	if got <= 0:
		_say("Mochila llena: libera espacio.")
		return
	chest[id] = have - got
	if int(chest[id]) <= 0:
		chest.erase(id)
	Sfx.play("pickup", -4.0)


func gen_toggle() -> void:
	if gen_on:
		gen_on = false
		Sfx.play("gen_stop", -4.0)
		return
	if fuel <= 0.0:
		_say("Sin combustible: añade un bidón.")
		return
	gen_on = true
	Sfx.play("gen_start", -3.0)


func gen_refuel() -> void:
	if fuel > FUEL_MAX - FUEL_CAN * 0.5:
		_say("El depósito está lleno.")
		return
	if not player.inventory.remove("combustible", 1):
		_say("No tienes combustible (fabrícalo en la mesa o búscalo en talleres).")
		return
	fuel = minf(FUEL_MAX, fuel + FUEL_CAN)
	Sfx.play("pickup", -4.0)
	_say("Añadiste combustible al generador.")


# ------------------------------------------------------------- dibujo de los puestos

class Prop extends Node2D:
	var kind := ""
	var refuge: Refuge
	var size := Vector2(16, 16)
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		match kind:
			"bench":
				_bench()
			"medkit":
				_medkit()
			"chest":
				_chest()
			_:
				_generator()

	func _chest() -> void:
		var w := size.x
		var full: float = clampf(float(refuge.chest_total()) / float(Refuge.CHEST_CAP), 0.0, 1.0)
		draw_rect(Rect2(-w * 0.5 + 1, -3, 3, 3), Color("2a1f14"))
		draw_rect(Rect2(w * 0.5 - 4, -3, 3, 3), Color("2a1f14"))
		draw_rect(Rect2(-w * 0.5, -13, w, 11), Color("7a5430"))
		draw_rect(Rect2(-w * 0.5, -17, w, 5), Color("96693a"))                       # tapa
		draw_rect(Rect2(-w * 0.5, -17, w, 1), Color("c2935a"))
		for i in 4:                                                                  # tablas
			draw_rect(Rect2(-w * 0.5 + 7 + i * 7, -12, 1, 9), Color("5e4024"))
		draw_rect(Rect2(-w * 0.5 + 2, -17, 3, 15), Color("4a4e56"))                  # herrajes
		draw_rect(Rect2(w * 0.5 - 5, -17, 3, 15), Color("4a4e56"))
		draw_rect(Rect2(-2, -13, 4, 5), Color("d8b040"))                             # cerradura
		draw_rect(Rect2(-1, -11, 2, 2), Color("3a2a10"))
		draw_rect(Rect2(-w * 0.5, -17, w, 15), Color("2a1f14"), false, 1.0)
		draw_rect(Rect2(-w * 0.5 + 8, -2, (w - 16) * full, 1), Color("7dff8a") if full < 0.9 else Color("e8a030"))   # nivel de llenado

	func _bench() -> void:
		var w := size.x
		draw_rect(Rect2(-w * 0.5 + 2, -4, 3, 4), Color("4a3420"))
		draw_rect(Rect2(w * 0.5 - 5, -4, 3, 4), Color("4a3420"))
		draw_rect(Rect2(-w * 0.5, -11, w, 7), Color("8a6a3e"))
		draw_rect(Rect2(-w * 0.5, -11, w, 2), Color("b58d52"))
		draw_rect(Rect2(-w * 0.5, -5, w, 1), Color("5a4020"))
		draw_rect(Rect2(-w * 0.5 + 3, -16, 6, 5), Color("7a7e86"))      # tornillo de banco
		draw_rect(Rect2(-w * 0.5 + 3, -16, 6, 1), Color("b4b8c0"))
		draw_rect(Rect2(2, -13, 2, 3), Color("5a4020"))                 # martillo
		draw_rect(Rect2(0, -14, 6, 2), Color("8a8d93"))
		draw_rect(Rect2(w * 0.5 - 9, -13, 5, 2), Color("8a8d93"))       # chatarra
		draw_rect(Rect2(w * 0.5 - 8, -14, 2, 1), Color("b4b7bd"))

	func _medkit() -> void:
		draw_rect(Rect2(-1, -4, 2, 4), Color("4a3420"))                 # poste
		draw_rect(Rect2(-7, -20, 14, 16), Color("e8e6df"))
		draw_rect(Rect2(-7, -20, 14, 2), Color("ffffff"))
		draw_rect(Rect2(-7, -6, 14, 2), Color("a8a69c"))
		draw_rect(Rect2(-7, -20, 14, 16), Color("5a5a60"), false, 1.0)
		draw_rect(Rect2(-1, -16, 2, 8), Color("c0392b"))
		draw_rect(Rect2(-4, -13, 8, 2), Color("c0392b"))
		for i in 3:   # niveles de ampliacion
			var on: bool = i <= refuge.med_level
			draw_rect(Rect2(-5 + i * 4, -3, 2, 1), Color("7dff8a") if on else Color("3a3d44"))
		if refuge.med_charges > 0:
			draw_rect(Rect2(4, -21, 3, 3), Color("7dff8a"))

	func _generator() -> void:
		var w := size.x
		var on: bool = refuge.gen_on
		var j := Vector2(sin(_t * 60.0) * 0.4, 0.0) if on else Vector2.ZERO
		draw_rect(Rect2(-w * 0.5 + 1, -3, 4, 3) , Color("2a2c30"))
		draw_rect(Rect2(w * 0.5 - 5, -3, 4, 3), Color("2a2c30"))
		draw_rect(Rect2(Vector2(-w * 0.5 + 1, -20) + j, Vector2(w - 2, 17)), Color("6b7a3e"))
		draw_rect(Rect2(Vector2(-w * 0.5 + 1, -20) + j, Vector2(w - 2, 3)), Color("8a9a52"))
		draw_rect(Rect2(Vector2(-w * 0.5 + 1, -6) + j, Vector2(w - 2, 3)), Color("4a5628"))
		draw_rect(Rect2(Vector2(-w * 0.5 + 1, -20) + j, Vector2(w - 2, 17)), Color("2e3318"), false, 1.0)
		draw_rect(Rect2(Vector2(-w * 0.5 + 4, -15) + j, Vector2(8, 6)), Color("1c1e14"))   # rejilla
		for i in 3:
			draw_rect(Rect2(Vector2(-w * 0.5 + 5, -14 + i * 2) + j, Vector2(6, 1)), Color("4a4e3a"))
		draw_rect(Rect2(Vector2(w * 0.5 - 11, -14) + j, Vector2(7, 5)), Color("d8d4c4"))    # medidor
		var f: float = clampf(refuge.fuel / Refuge.FUEL_MAX, 0.0, 1.0)
		draw_rect(Rect2(Vector2(w * 0.5 - 10, -13) + j, Vector2(5.0 * f, 3)), Color("e8a030") if f > 0.2 else Color("d64545"))
		draw_rect(Rect2(Vector2(w * 0.5 - 7, -19) + j, Vector2(2, 2)), Color("7dff8a") if on else Color("8a2a2a"))   # piloto
		draw_rect(Rect2(Vector2(w * 0.5 - 4, -26) + j, Vector2(3, 7)), Color("3a3c41"))    # escape
		if on:
			for i in 3:
				var k := fposmod(_t * 0.9 + i * 0.33, 1.0)
				draw_circle(Vector2(w * 0.5 - 2.5 + sin(_t * 3.0 + i) * 1.5, -28.0 - k * 12.0), 1.0 + k * 2.0, Color(0.7, 0.7, 0.72, 0.4 * (1.0 - k)))
