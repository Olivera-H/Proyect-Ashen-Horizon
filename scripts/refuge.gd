class_name Refuge
extends Node2D
## Mejoras del refugio, en el patio cercado junto a la casa:
## - Mesa de trabajo: fabrica vendajes, municion, combustible y semillas con chatarra.
## - Botiquin ampliable: guarda vendajes como cargas (3/6/10) que curan mas que un vendaje suelto.
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
var near := ""
var _low_warned := false
var _gen_light: PointLight2D
var _door_light: PointLight2D
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
	var y := mini(house.end.y + 2, ring.end.y - 4)
	var ts := float(World.TS)
	_add("bench", Rect2(Vector2(door.x - 6, y) * ts, Vector2(2, 1) * ts), ents)
	_add("medkit", Rect2(Vector2(door.x + 3, y) * ts, Vector2(1, 1) * ts), ents)
	_add("generator", Rect2(Vector2(door.x + 6, y) * ts, Vector2(2, 2) * ts), ents)
	var g: Rect2 = stations["generator"]["rect"]
	_gen_light = _make_light(g.get_center() + Vector2(0, -6), 1.6, Color("ffd890"))
	_door_light = _make_light(Vector2((door.x + 1) * ts, (house.end.y + 1) * ts), 2.6, Color("ffcf80"))
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
	_door_light.energy = e * 0.7
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
			_:
				_generator()

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
