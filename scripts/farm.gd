class_name Farm
extends Node2D
## Huerto del refugio: parcelas de 2x2 tiles en el patio cercado, junto a la casa.
## - Camina sobre una parcela vacia con semillas en la mochila para plantar (1 semilla).
## - Brota, crece y madura sola (aprox. 90 s). Camina sobre una parcela madura para cosechar
##   (2 de comida y, a veces, una semilla de vuelta).
## Se dibuja con rectangulos (pixel art por codigo), sin texturas.

const PLOT_TILES := 2
const COLS := 2
const ROWS := 4
const GAP_TILES := 1
const T_SPROUT := 35.0       # semilla -> brote (s)
const T_GROW := 55.0         # brote -> maduro (s)
const REACH := 11.0          # distancia al centro de la parcela para plantar/cosechar

var world: World
var player: Player
var plots: Array = []        # {pos: Vector2 (esquina), c: Vector2 (centro), stage: 0..3, t: float, seed: int}
var _tip_seeds := false
var _tip_plant := false
var _t := 0.0
var _area := Rect2()
var _lamp: PointLight2D
var _lamp_pos := Vector2.ZERO
var _night := 0.0
var _flick := 0.0            # >0 mientras la luz parpadea
var _next_flick := 6.0


func setup(w: World) -> void:
	world = w
	if w.refuge_b.is_empty() or w.fence.is_empty():
		return
	var house: Rect2i = w.refuge_b["rect"]
	var ring: Rect2i = w.fence["ring"]
	var x0 := house.end.x + 2
	var y0 := house.position.y
	var ts := float(World.TS)
	var step := PLOT_TILES + GAP_TILES
	for cx in COLS:
		for cy in ROWS:
			var tx := x0 + cx * step
			var ty := y0 + cy * step
			if tx + PLOT_TILES > ring.end.x - 2 or ty + PLOT_TILES > ring.end.y - 2:
				continue
			var pos := Vector2(tx, ty) * ts
			plots.append({"pos": pos, "c": pos + Vector2(PLOT_TILES, PLOT_TILES) * ts * 0.5, "stage": 0, "t": 0.0, "seed": plots.size() * 7919 + 13})
	if plots.is_empty():
		return
	var first: Vector2 = plots[0]["pos"]
	var last: Vector2 = plots[plots.size() - 1]["pos"]
	_area = Rect2(first - Vector2(6, 6), (last + Vector2(PLOT_TILES, PLOT_TILES) * ts) - first + Vector2(12, 12))
	# farol del huerto: poste en la esquina superior izquierda, luz sobre las parcelas
	_lamp_pos = _area.position + Vector2(-4.0, 4.0)
	_lamp = PointLight2D.new()
	_lamp.texture = PixelArt.make_radial_light(128)
	_lamp.texture_scale = 2.4
	_lamp.color = Color("ffe0a0")
	_lamp.energy = 0.0
	_lamp.position = _area.get_center() + Vector2(0, -8)
	add_child(_lamp)


func set_daylight(k: float) -> void:
	_night = 1.0 - k


func _process(delta: float) -> void:
	_t += delta
	if plots.is_empty():
		return
	# parpadeo: cada cierto tiempo la luz titila unos instantes
	_next_flick -= delta
	if _next_flick <= 0.0:
		_flick = 1.2
		_next_flick = randf_range(7.0, 14.0)
	var e := 1.0
	if _flick > 0.0:
		_flick -= delta
		e = 0.15 + 0.85 * float(sin(_t * 38.0) > 0.0) * (0.4 + 0.6 * randf())
	_lamp.energy = _night * e * 0.95
	queue_redraw()
	for p in plots:
		if int(p["stage"]) in [1, 2]:
			p["t"] += delta
			if int(p["stage"]) == 1 and p["t"] >= T_SPROUT:
				p["stage"] = 2
				p["t"] = 0.0
			elif int(p["stage"]) == 2 and p["t"] >= T_GROW:
				p["stage"] = 3
				p["t"] = 0.0
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	if player.dead:
		return
	var pp: Vector2 = to_local(player.global_position)
	for p in plots:
		var d := pp.distance_to(p["c"])
		if d > REACH:
			p["lock"] = false
			continue
		if int(p["stage"]) == 3:
			_harvest(p)
		elif int(p["stage"]) == 0 and not p.get("lock", false):
			_plant(p)
	queue_redraw()


func _plant(p: Dictionary) -> void:
	if not player.inventory.owns("semillas"):
		if not _tip_seeds:
			_tip_seeds = true
			player.toast.emit("Parcela de cultivo vacía: necesitas semillas (búscalas en tiendas, supermercados y casas).")
		return
	player.inventory.remove("semillas", 1)
	p["stage"] = 1
	p["t"] = 0.0
	Sfx.play("plant", -3.0)
	player.toast.emit("Plantaste semillas. Madurarán en un minuto y medio.")


func _harvest(p: Dictionary) -> void:
	var left := player.inventory.add("food", 2)
	if left >= 2:
		if not _tip_plant:
			_tip_plant = true
			player.toast.emit("Mochila llena: libera espacio para cosechar.")
		return
	p["stage"] = 0
	p["t"] = 0.0
	p["lock"] = true   # hay que salir de la parcela antes de volver a plantar
	Sfx.play("harvest", -2.0)
	var got := 2 - left
	var extra := ""
	if randf() < 0.45 and player.inventory.add("semillas", 1) == 0:
		extra = " y una semilla"
	player.toast.emit("Cosecha: +%d comida%s." % [got, extra])


func _draw() -> void:
	if plots.is_empty():
		return
	var ts := float(World.TS)
	# tierra labrada comun y borde de madera
	draw_rect(_area, Color("3b2a1a"))
	draw_rect(_area, Color("6b4a2a"), false, 2.0)
	# poste del farol
	draw_rect(Rect2(_lamp_pos + Vector2(-1, -2), Vector2(2, 14)), Color("2a2118"))
	var glow := 0.35 + 0.65 * (_lamp.energy / 0.95 if _lamp != null else 0.0)
	draw_rect(Rect2(_lamp_pos + Vector2(-3, -6), Vector2(6, 5)), Color(1.0, 0.85, 0.45, glow))
	draw_rect(Rect2(_lamp_pos + Vector2(-3, -6), Vector2(6, 5)), Color("4a3a28"), false, 1.0)
	for p in plots:
		_draw_plot(p, ts)
	# cartel
	var sx := _area.position.x + _area.size.x * 0.5
	var sy := _area.position.y - 2.0
	draw_rect(Rect2(sx - 1.0, sy - 9.0, 2.0, 9.0), Color("5a4020"))
	draw_rect(Rect2(sx - 12.0, sy - 17.0, 24.0, 9.0), Color("a47b45"))
	draw_rect(Rect2(sx - 12.0, sy - 17.0, 24.0, 9.0), Color("5a4020"), false, 1.0)
	for i in 4:
		draw_rect(Rect2(sx - 8.0 + i * 5.0, sy - 14.0, 3.0, 3.0), Color("c0392b") if i % 2 == 0 else Color("4f9a3a"))


func _draw_plot(p: Dictionary, ts: float) -> void:
	var o: Vector2 = p["pos"]
	var sz := Vector2(PLOT_TILES, PLOT_TILES) * ts
	draw_rect(Rect2(o + Vector2(1, 1), sz - Vector2(2, 2)), Color("4d3520"))
	for i in 4:   # surcos
		draw_rect(Rect2(o + Vector2(3, 4 + i * 7), Vector2(sz.x - 6, 2)), Color("3a2916"))
	draw_rect(Rect2(o + Vector2(1, 1), Vector2(sz.x - 2, 1)), Color("6d4e30"))
	var stage: int = p["stage"]
	if stage == 0:
		return
	var sway := sin(_t * 1.6 + float(p["seed"]))
	var prog: float = float(p["t"]) / (T_SPROUT if stage == 1 else T_GROW)
	for row in 2:
		for col in 3:
			var base := o + Vector2(7.0 + col * 9.0, 10.0 + row * 14.0)
			match stage:
				1:   # semilla recien puesta y brote diminuto
					draw_rect(Rect2(base + Vector2(0, 0), Vector2(2, 1)), Color("c9b57a"))
					if prog > 0.5:
						draw_rect(Rect2(base + Vector2(0, -2), Vector2(1, 2)), Color("6bbd4c"))
				2:   # planta joven que crece
					var h := 3.0 + 4.0 * prog
					draw_rect(Rect2(base + Vector2(0, -h), Vector2(1, h)), Color("3f8a34"))
					draw_rect(Rect2(base + Vector2(-2 + sway * 0.4, -h), Vector2(2, 1)), Color("6bbd4c"))
					draw_rect(Rect2(base + Vector2(1 + sway * 0.4, -h + 1), Vector2(2, 1)), Color("6bbd4c"))
				3:   # planta madura con frutos
					draw_rect(Rect2(base + Vector2(0, -8), Vector2(1, 8)), Color("3f8a34"))
					draw_rect(Rect2(base + Vector2(-3 + sway * 0.5, -8), Vector2(3, 2)), Color("5aad45"))
					draw_rect(Rect2(base + Vector2(1 + sway * 0.5, -6), Vector2(3, 2)), Color("5aad45"))
					draw_rect(Rect2(base + Vector2(-2, -4), Vector2(2, 2)), Color("d9402b"))
					draw_rect(Rect2(base + Vector2(1, -3), Vector2(2, 2)), Color("e9552f"))
					draw_rect(Rect2(base + Vector2(0, -9), Vector2(1, 1)), Color("f3d36a"))
	if stage == 3:
		var a := 0.25 + 0.2 * sin(_t * 4.0 + float(p["seed"]))
		draw_arc(o + sz * 0.5, 15.0, 0.0, TAU, 20, Color(1.0, 0.9, 0.4, a), 1.0)
