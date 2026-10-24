extends Node2D
## Escena principal del prototipo (Acto I de Mateo): arma el mundo, al jugador,
## los zombis, los objetos, el ciclo dia/noche, el clima, los eventos aleatorios
## y la interfaz.

const DAY_LENGTH := 300.0           # segundos reales por dia completo
const NIGHT_COLOR := Color(0.10, 0.12, 0.22)
const DAY_COLOR := Color(0.88, 0.90, 0.82)
const DUSK_COLOR := Color(0.95, 0.60, 0.45)
const PICKUP_RADIUS := 11.0
const REFUGE_HEAL := 3.0            # vida por segundo dentro del refugio
const TOXIC_TILE_X := 84            # desde aqui empieza el aire toxico (zona industrial)

const NOTES := [
	"Placa en un casco: «M. VARGAS — Bomberos, Turno 14». Todavía huele a humo.",
	"Radio rota: «Horizonte confirma contención total en el sector 4». Mentira: la lluvia ya lo esparcía.",
	"Nota pegada en una puerta: «No beban agua de lluvia. Ceniza viaja en las esporas».",
	"Diario: «Día 212. Los corredores salen de noche. Usen el silencio, no las armas».",
	"Memo interno: «Lote H-7 liberado según cronograma. No informar a Salud Pública».",
	"Mapa tachado a mano: «Laboratorio Horizonte — entrada por el muelle de carga, zona industrial».",
]

var character_id := "mateo"
var world: World
var player: Player
var hud: Hud
var weather: Weather
var canvas_mod: CanvasModulate
var pickup_root: Node2D
var ents: Node2D

var time_of_day := 0.36             # 0 = medianoche, 0.5 = mediodia
var checkpoint := Vector2.ZERO
var refuge_rect := Rect2()
var main_rect := Rect2()

var _pickups: Array = []            # {node, kind, text}
var _icons := {}
var _state := "play"                # play | dead | won
var _end_t := 0.0
var _raining := false
var _rain_t := 40.0
var _event_t := 70.0
var _in_refuge := false
var _warned_toxic := false
var _drop_goal := {}
var _drop_flying := false
var _drop_landed := false
var _drop_crate: Sprite2D


func _ready() -> void:
	InputSetup.register()

	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)

	world = World.new()
	add_child(world)
	world.generate()

	pickup_root = Node2D.new()
	add_child(pickup_root)
	ents = Node2D.new()
	ents.y_sort_enabled = true
	add_child(ents)
	StreetProps.spawn(world, ents)

	_find_rects()
	_spawn_player()
	_spawn_zombies()
	_spawn_pickups()
	_build_ui()
	_update_daylight(0.0)

	hud.toast("Mateo Vargas, ex-bombero. Encuentra el Laboratorio Horizonte.", 6.0)
	hud.toast("Mueve: joystick izquierdo (al borde, corres) · Ataca, esquiva, repara y linterna: botones", 7.0)


# ---------------------------------------------------------------- armado

func _rect_for(pos: Vector2) -> Rect2:
	for b in world.buildings:
		var r: Rect2i = b["rect"]
		var rr := Rect2(Vector2(r.position) * float(World.TS), Vector2(r.size) * float(World.TS))
		if rr.has_point(pos):
			return rr
	return Rect2()


func _find_rects() -> void:
	for g in world.objectives:
		var gp: Vector2 = g["pos"]
		if g["main"]:
			main_rect = _rect_for(gp).grow(-float(World.TS))
		elif g["name"] == "Refugio":
			refuge_rect = _rect_for(gp).grow(-float(World.TS))
	world.safe_rect = refuge_rect


func _spawn_player() -> void:
	player = Player.new()
	player.setup(character_id)
	player.position = world.start_pos
	ents.add_child(player)
	var sz := world.size_px()
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = int(sz.x)
	player.camera.limit_bottom = int(sz.y)
	checkpoint = world.start_pos


func _spawn_zombies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for p in world.zombie_spawns:
		var pos: Vector2 = p
		if refuge_rect.has_point(pos):
			continue
		var kind := "walker"
		var roll := rng.randf()
		if pos.x >= 87.0 * float(World.TS) and roll < 0.12:
			kind = "tank"
		elif roll < 0.30:
			kind = "runner"
		var z := Zombie.new()
		z.configure(kind)
		z.position = pos
		ents.add_child(z)
		z.setup(world, player)


func _icon(kind: String) -> Texture2D:
	if not _icons.has(kind):
		_icons[kind] = PixelArt.make_icon(kind)
	return _icons[kind]


func _add_pickup(pos: Vector2, kind: String, text: String) -> void:
	var s := Sprite2D.new()
	s.texture = _icon(kind)
	s.position = pos
	pickup_root.add_child(s)
	_pickups.append({"node": s, "kind": kind, "text": text})


func _spawn_pickups() -> void:
	for spot in world.loot_spots:
		_add_pickup(spot["pos"], spot["kind"], "")
	# notas de historia repartidas por todo el mapa
	var count := world.buildings.size()
	var step := maxi(1, int(float(count) / float(NOTES.size())))
	for i in NOTES.size():
		var b: Dictionary = world.buildings[mini(i * step, count - 1)]
		var r: Rect2i = b["rect"]
		var t := Vector2i(r.position.x + int(r.size.x / 2.0), r.position.y + int(r.size.y / 2.0))
		_add_pickup(world.tile_center(t), "note", NOTES[i])


func _build_ui() -> void:
	var weather_layer := CanvasLayer.new()
	weather_layer.layer = 5
	add_child(weather_layer)
	weather = Weather.new()
	weather_layer.add_child(weather)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 20
	add_child(ui_layer)
	hud = Hud.new()
	ui_layer.add_child(hud)
	hud.setup(player, world, world.objectives)
	hud.notes_total = NOTES.size()

	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 30
	add_child(touch_layer)
	touch_layer.add_child(TouchControls.new())

	player.toast.connect(func(t: String) -> void: hud.toast(t))
	player.died.connect(_on_player_died)


# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	_update_daylight(delta)
	hud.clock = time_of_day
	hud.raining = weather.rain > 0.3
	if _state == "play":
		_update_weather(delta)
		_check_pickups()
		_check_refuge(delta)
		_check_goal()
		_random_events(delta)
	elif _end_t > 0.0:
		_end_t -= delta


func _input(event: InputEvent) -> void:
	if _state == "play" or _end_t > 0.0:
		return
	var go := false
	if event is InputEventScreenTouch and event.pressed:
		go = true
	elif event is InputEventKey and event.pressed and not event.echo:
		go = true
	if not go:
		return
	if _state == "dead":
		player.revive(checkpoint)
	_state = "play"
	hud.end_kind = ""


func _update_daylight(delta: float) -> void:
	time_of_day = fposmod(time_of_day + delta / DAY_LENGTH, 1.0)
	var sun := sin((time_of_day - 0.25) * TAU)    # 1 = mediodia, -1 = medianoche
	var k := smoothstep(-0.25, 0.35, sun)
	var col := NIGHT_COLOR.lerp(DAY_COLOR, k)
	var dusk := clampf(1.0 - absf(sun) / 0.3, 0.0, 1.0)
	canvas_mod.color = col.lerp(DUSK_COLOR, dusk * 0.33)
	player.light_mult = lerpf(1.0, 0.25, k)
	get_tree().call_group("night_lights", "set_night", 1.0 - k)


func _update_weather(delta: float) -> void:
	_rain_t -= delta
	if _rain_t <= 0.0:
		_raining = not _raining
		_rain_t = randf_range(25.0, 50.0) if _raining else randf_range(45.0, 90.0)
		if _raining:
			hud.toast("Empieza la lluvia ácida: busca techo.", 4.0)
	weather.rain = move_toward(weather.rain, 1.0 if _raining else 0.0, delta * 0.3)

	var tile := world.to_tile(player.global_position)
	var fog_target := 0.15
	if tile.x >= TOXIC_TILE_X - 4:
		fog_target = 0.15 + clampf(float(tile.x - (TOXIC_TILE_X - 4)) / 10.0, 0.0, 1.0) * 0.55
	weather.fog = move_toward(weather.fog, fog_target, delta * 0.2)

	var outdoors := world.in_bounds(tile) and world.tile_id(tile) != PixelArt.T_FLOOR
	var dmg := 0.0
	hud.warning = ""
	if outdoors:
		if weather.rain > 0.5:
			dmg += 0.35
			hud.warning = "LLUVIA ÁCIDA: refúgiate en un edificio"
		if tile.x >= TOXIC_TILE_X:
			dmg += 0.6
			hud.warning = "AIRE TÓXICO: entra a un edificio para respirar"
			if not _warned_toxic:
				_warned_toxic = true
				hud.toast("Zona industrial: el aire quema. Cruza rápido o resguárdate adentro.", 5.0)
	if dmg > 0.0:
		player.environmental_damage(dmg * delta)


func _check_pickups() -> void:
	var pp := player.global_position
	for i in range(_pickups.size() - 1, -1, -1):
		var p: Dictionary = _pickups[i]
		var node: Sprite2D = p["node"]
		if node.position.distance_to(pp) > PICKUP_RADIUS:
			continue
		var kind: String = p["kind"]
		var taken := false
		if kind == "note":
			hud.toast(p["text"], 9.0)
			hud.notes_found += 1
			taken = true
		else:
			taken = player.collect(kind)
		if taken:
			node.queue_free()
			_pickups.remove_at(i)


func _check_refuge(delta: float) -> void:
	var inside := refuge_rect.has_point(player.global_position)
	if inside:
		player.health = minf(player.max_health, player.health + REFUGE_HEAL * delta)
		if not _in_refuge:
			_in_refuge = true
			checkpoint = refuge_rect.get_center()
			hud.toast("Refugio asegurado: progreso guardado y los infectados pierden tu rastro.", 4.5)
	else:
		_in_refuge = false


func _check_goal() -> void:
	if main_rect.has_point(player.global_position):
		_state = "won"
		_end_t = 1.5
		hud.end_kind = "won"
	if not _drop_goal.is_empty() and _drop_landed:
		var gp: Vector2 = _drop_goal["pos"]
		if player.global_position.distance_to(gp) < 24.0:
			world.objectives.erase(_drop_goal)
			_drop_goal = {}
			_drop_landed = false
			if _drop_crate != null and is_instance_valid(_drop_crate):
				_drop_crate.queue_free()
				_drop_crate = null
			hud.toast("Recogiste la caja de suministros.", 3.0)


func _on_player_died() -> void:
	_state = "dead"
	_end_t = 1.5
	hud.end_kind = "dead"


# ------------------------------------------------------- eventos aleatorios

func _random_events(delta: float) -> void:
	_event_t -= delta
	if _event_t > 0.0:
		return
	_event_t = randf_range(80.0, 140.0)
	if randf() < 0.5:
		_event_noise()
	else:
		_event_supply_drop()


func _event_noise() -> void:
	var ang := randf() * TAU
	var point := player.global_position + Vector2.from_angle(ang) * randf_range(150.0, 260.0)
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.global_position.distance_to(point) < 220.0:
			z.investigate(point)
	var dirs := ["este", "sur", "oeste", "norte"]
	var compass: String = dirs[roundi(ang / (PI * 0.5)) % 4]
	hud.toast("Un estruendo suena hacia el %s: los infectados se están moviendo." % compass, 5.0)


func _event_supply_drop() -> void:
	if _drop_flying:
		return
	for attempt in 40:
		var pos := player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(180.0, 320.0)
		var t := world.to_tile(pos)
		if not world.in_bounds(t) or world.is_solid_tile(t):
			continue
		var c := world.tile_center(t)
		if not _drop_goal.is_empty():
			world.objectives.erase(_drop_goal)
			_drop_goal = {}
		if _drop_crate != null and is_instance_valid(_drop_crate):
			_drop_crate.queue_free()
			_drop_crate = null
		_drop_flying = true
		var drop := SupplyDrop.new()
		world.add_child(drop)
		drop.setup(c, ents)
		drop.released.connect(_on_supply_released.bind(c))
		drop.landed.connect(_on_supply_landed.bind(drop, c))
		hud.toast("Se oye un avión de carga sobrevolando la zona...", 4.0)
		return


func _on_supply_released(c: Vector2) -> void:
	_drop_goal = {"name": "Suministros", "pos": c, "main": false}
	world.objectives.append(_drop_goal)
	hud.toast("¡Soltaron una caja con paracaídas! Mírala en el minimapa.", 5.0)


func _on_supply_landed(drop: SupplyDrop, c: Vector2) -> void:
	_drop_flying = false
	_drop_crate = drop.crate
	_add_pickup(c, "bandage", "")
	_add_pickup(c + Vector2(6, 0), "scrap", "")
	_add_pickup(c + Vector2(-6, 0), "water", "")
	_drop_landed = true
