class_name Player
extends CharacterBody2D
## Protagonista jugable. Movimiento, estamina, esquiva, combate cuerpo a cuerpo
## con desgaste del arma, ruido, linterna y estados de supervivencia.

signal died
signal toast(text: String)

const DODGE_SPEED := 190.0
const DODGE_TIME := 0.22
const ATTACK_RANGE := 42.0
const ATTACK_DAMAGE := 18.0
const INVENTORY_LIMIT := 8

var char_id := "mateo"
var data: Dictionary = {}

var max_health := 100.0
var health := 100.0
var max_stamina := 100.0
var stamina := 100.0
var hunger := 100.0     # 100 = lleno
var thirst := 100.0     # 100 = hidratado
var infection := 0.0    # 0 = sano, 100 = muerte
var inventory := Inventory.new()
var last_env_hit_ms := -100000
var scrap: int:
	get:
		return inventory.count("scrap")
var weapon_id := "tubo"
var weapon_durability := 40.0
var weapon_name: String:
	get:
		return ItemDefs.item_name(weapon_id)
var weapon_max: float:
	get:
		return float(ItemDefs.ITEMS[weapon_id].get("dur", 1.0))
var weapon_is_gun: bool:
	get:
		return ItemDefs.is_gun(weapon_id)
var ammo_in_reserve: int:
	get:
		return inventory.count(ItemDefs.ITEMS[weapon_id].get("ammo", "")) if weapon_is_gun else 0
var _muzzle_t := 0.0

var facing := Vector2.DOWN
var running := false
var exhausted := false
var dead := false
var flashlight_on := true
var light_mult := 1.0   # Main lo baja de dia para que las luces no quemen la imagen

var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector2.DOWN
var _attack_t := 0.0
var _attack_cd := 0.0
var _invuln := 0.0
var _spike_radius := 0.0
var _spike_t := 0.0
var _swing_dir := Vector2.DOWN

var sprite: AnimatedSprite2D
var _sprite_base := Vector2.ZERO
var camera: Camera2D
var flash: PointLight2D
var halo: PointLight2D
var fx: Node2D


func has_skill(id: String) -> bool:
	return inventory.has_equipped(id)


func _give_starting_items() -> void:
	inventory.add("bandage", 1)
	inventory.add("water", 1)
	inventory.add("golpe", 1)
	inventory.add("resistencia", 1)
	inventory.move(Inventory.BAG_START, Inventory.SKILL_START)   # "Golpe fuerte" ya viene equipada


func setup(id: String) -> void:
	_give_starting_items()
	char_id = id
	data = Characters.get_data(id)
	max_health = data["max_health"]
	health = max_health
	max_stamina = data["max_stamina"]
	stamina = max_stamina

	collision_layer = 2
	collision_mask = 1
	add_to_group("player")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)

	sprite = AnimatedSprite2D.new()
	Settings.ensure()
	var sheet := SpriteSheets.frames(Settings.skin, SpriteSheets.HUMAN)   # la skin elegida solo cambia el aspecto
	if sheet == null:
		sheet = SpriteSheets.frames(char_id, SpriteSheets.HUMAN)
	if sheet != null:
		sprite.sprite_frames = sheet
		sprite.position = SpriteSheets.HUMAN_POS
	else:  # arte de respaldo si falta la hoja de sprites
		sprite.sprite_frames = PixelArt.make_humanoid_frames(data["palette"])
		sprite.position = Vector2(0, -4)
	_sprite_base = sprite.position
	sprite.play("idle_down")
	add_child(sprite)

	halo = PointLight2D.new()
	halo.texture = PixelArt.make_radial_light(128)
	halo.texture_scale = 1.5
	halo.energy = 0.55
	halo.color = Color("ffe9b8")
	add_child(halo)

	flash = PointLight2D.new()
	flash.texture = PixelArt.make_cone_light(256)
	flash.texture_scale = 1.25
	flash.energy = 1.15
	flash.color = Color("fff2cc")
	add_child(flash)

	fx = Node2D.new()
	fx.z_index = 5
	fx.draw.connect(_draw_fx)
	add_child(fx)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)


func noise_radius() -> float:
	var base := 0.0
	if velocity.length() > 5.0:
		base = 110.0 if running else 38.0
	if _spike_t > 0.0:
		base = maxf(base, _spike_radius)
	return base * (0.65 if has_skill("sigilo") else 1.0)


func make_noise(radius: float, duration: float) -> void:
	_spike_radius = maxf(_spike_radius if _spike_t > 0.0 else 0.0, radius)
	_spike_t = maxf(_spike_t, duration)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_tick_timers(delta)
	_update_stats(delta)

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.2:
		facing = dir.normalized()

	if _dodge_t > 0.0:
		velocity = _dodge_dir * DODGE_SPEED
	else:
		var wants_run := Input.is_action_pressed("run") and dir.length() > 0.3
		running = wants_run and not exhausted and stamina > 0.0
		var speed: float = data["run_speed"] if running else data["walk_speed"]
		if has_skill("pies"):
			speed *= 1.08
		if _attack_t > 0.0:
			speed *= 0.5
		velocity = dir * speed
		if running:
			stamina = maxf(0.0, stamina - 22.0 * delta)
			if stamina <= 0.0:
				exhausted = true

	if Input.is_action_just_pressed("dodge"):
		_try_dodge(dir)
	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if Input.is_action_just_pressed("repair"):
		_try_repair()
	for k in Inventory.HOTBAR:
		if Input.is_action_just_pressed("slot%d" % (k + 1)):
			use_slot(k)
	if Input.is_action_just_pressed("flashlight"):
		flashlight_on = not flashlight_on
		Sfx.play("flashlight", -6.0)

	move_and_slide()
	_footsteps(delta)
	_update_visuals(delta)


var drain_mult := 1.0   # el frio del refugio sin generador acelera hambre y sed
var _step_t := 0.0


func _footsteps(delta: float) -> void:
	if velocity.length() < 12.0 or _dodge_t > 0.0:
		_step_t = 0.12
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.26 if running else 0.4
		Sfx.pick("step", 4, -11.0 if running else -17.0)


func _tick_timers(delta: float) -> void:
	_dodge_t = maxf(0.0, _dodge_t - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_attack_t = maxf(0.0, _attack_t - delta)
	_muzzle_t = maxf(0.0, _muzzle_t - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_spike_t = maxf(0.0, _spike_t - delta)


func _update_stats(delta: float) -> void:
	# estamina
	if not running and _dodge_t <= 0.0:
		var regen: float = data["stamina_regen"]
		if has_skill("resistencia"):
			regen *= 1.4
		if hunger < 20.0 or thirst < 20.0:
			regen *= 0.5
		stamina = minf(max_stamina, stamina + regen * delta)
		if exhausted and stamina >= max_stamina * 0.25:
			exhausted = false
	# hambre y sed
	var drain := (0.6 if has_skill("estomago") else 1.0) * drain_mult
	hunger = maxf(0.0, hunger - 0.12 * delta * drain)
	thirst = maxf(0.0, thirst - 0.18 * delta * drain)
	if hunger <= 0.0 or thirst <= 0.0:
		_hurt_over_time(1.5 * delta)
	# infeccion
	if infection > 0.0:
		infection = minf(100.0, infection + 0.1 * delta)
		if infection >= 70.0:
			_hurt_over_time(1.0 * delta)
		if infection >= 100.0:
			_die()


func _hurt_over_time(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		_die()


func _try_dodge(dir: Vector2) -> void:
	if _dodge_cd > 0.0 or stamina < 20.0 or _dodge_t > 0.0:
		return
	_dodge_dir = dir.normalized() if dir.length() > 0.2 else facing
	_dodge_t = DODGE_TIME
	_dodge_cd = 0.7
	_invuln = maxf(_invuln, 0.3)
	stamina -= 20.0
	make_noise(60.0, 0.3)
	Sfx.play("dodge", -4.0)


func _try_attack() -> void:
	var def: Dictionary = ItemDefs.ITEMS[weapon_id]
	if _attack_cd > 0.0 or _dodge_t > 0.0 or stamina < 8.0:
		return
	if weapon_is_gun:
		_try_shoot(def)
		return
	_attack_cd = float(def["cd"])
	_attack_t = 0.18
	_swing_dir = facing
	stamina -= 8.0
	make_noise(float(def["noise"]), 0.35)
	Sfx.play("swing", -3.0, 0.12)
	var armed := weapon_durability > 0.0
	var dmg: float = (float(def["dmg"]) if armed else 6.0) * float(data["melee_damage"])
	if has_skill("golpe"):
		dmg *= 1.25
	var reach: float = float(def["range"])
	var hit_any := false
	for z in get_tree().get_nodes_in_group("zombies"):
		var to_z: Vector2 = z.global_position - global_position
		if to_z.length() <= reach and to_z.normalized().dot(facing) > 0.3:
			z.take_damage(dmg, facing * 140.0, 0.35 if armed else 0.15)
			hit_any = true
	if not hit_any:   # sin zombis a tiro, el golpe desmonta una cerca o barricada cercana
		for st in get_tree().get_nodes_in_group("structures"):
			var sn := st as Structure
			if sn.near_player(global_position + facing * reach * 0.5, 6.0):
				sn.dismantle_swing(self)
				break
	if hit_any:
		Sfx.play("hit_metal" if weapon_id == "machete" or weapon_id == "hacha" else "hit", -2.0)
	if hit_any and armed:
		weapon_durability = maxf(0.0, weapon_durability - 1.5)
		if weapon_durability <= 0.0:
			toast.emit("Tu %s se rompió. Repárala con chatarra." % weapon_name.to_lower())


func _try_shoot(def: Dictionary) -> void:
	var ammo_id: String = def["ammo"]
	if inventory.count(ammo_id) <= 0:
		_attack_cd = 0.3
		Sfx.play("click_empty", -2.0)
		toast.emit("Sin munición: busca %s." % ItemDefs.item_name(ammo_id).to_lower())
		return
	inventory.remove(ammo_id, 1)
	_attack_cd = float(def["cd"])
	_muzzle_t = 0.08
	_swing_dir = facing
	stamina -= 3.0
	make_noise(float(def["noise"]), 0.6)
	Sfx.play("shot_" + weapon_id, -2.0, 0.04)
	if weapon_id == "escopeta":
		get_tree().create_timer(0.45).timeout.connect(func(): Sfx.play("pump", -6.0))
	var dmg: float = float(def["dmg"])
	var world_node := get_tree().get_first_node_in_group("world")
	# punteria: Mateo apunta peor (aim_spread alto) y Lena mejor
	var spread: float = float(def["spread"]) * float(data["aim_spread"])
	for i in int(def["pellets"]):
		var b := Projectile.new()
		b.world = world_node
		b.dir = facing.rotated(randf_range(-spread, spread))
		b.damage = dmg
		b.max_dist = float(def["range"])
		get_parent().add_child(b)
		b.global_position = global_position + facing * 10.0 + Vector2(0, -5)
	if inventory.count(ammo_id) == 0:
		toast.emit("Última bala usada.")


## Equipa el arma que esta en la casilla i; el arma actual vuelve a esa casilla.
func equip_from_slot(i: int) -> void:
	var s = inventory.slots[i]
	if s == null or not ItemDefs.is_weapon(s["id"]):
		return
	var new_id: String = s["id"]
	var new_d: float = float(s.get("d", ItemDefs.ITEMS[new_id].get("dur", 1.0)))
	var old_id := weapon_id
	var old_d := weapon_durability
	inventory.slots[i] = null
	weapon_id = new_id
	weapon_durability = new_d
	var back: Dictionary = {"id": old_id, "n": 1}
	if not ItemDefs.is_gun(old_id):
		back["d"] = old_d
	inventory.slots[i] = back
	inventory.changed.emit()
	Sfx.play("equip", -4.0)
	toast.emit("Equipaste: %s" % weapon_name)


func _try_repair() -> void:
	if scrap < 2:
		toast.emit("Necesitas 2 de chatarra para reparar.")
		return
	if weapon_is_gun:
		toast.emit("Las armas de fuego no se reparan con chatarra.")
		return
	if weapon_durability >= weapon_max:
		toast.emit("El arma ya está en buen estado.")
		return
	inventory.remove("scrap", 2)
	Sfx.play("repair", -3.0)
	var gain := 20.0 * float(data["craft_bonus"]) * (1.5 if has_skill("manos") else 1.0)
	weapon_durability = minf(weapon_max, weapon_durability + gain)
	toast.emit("Arma reparada.")


## Devuelve true si el objeto fue recogido. Los consumibles van al inventario (barra rapida y luego mochila).
func collect(kind: String) -> bool:
	if kind == "manual":
		return _learn_skill()
	if not ItemDefs.ITEMS.has(kind):
		return false
	var amount: int = ItemDefs.PICKUP_AMOUNT.get(kind, 1)
	var left := inventory.add(kind, amount)
	if left >= amount:
		toast.emit("Inventario lleno.")
		return false
	var got := amount - left
	if kind in ["tarjeta", "llave", "suero"]:
		Sfx.play("pickup_key", -2.0)
	elif kind == "mascara":
		Sfx.play("mask_on", -2.0)
	else:
		Sfx.play("pickup", -4.0)
	toast.emit("+%d %s" % [got, ItemDefs.item_name(kind).to_lower()])
	return left == 0


func _learn_skill() -> bool:
	var unknown: Array = []
	for sk in ItemDefs.SKILLS:
		if not inventory.owns(sk):
			unknown.append(sk)
	if unknown.is_empty():
		toast.emit("Manual de supervivencia: ya conoces todo lo que enseña.")
		return true
	var pick: String = unknown[randi() % unknown.size()]
	if inventory.add(pick, 1) > 0:
		toast.emit("Manual de supervivencia: libera espacio en la mochila para aprender.")
		return false
	toast.emit("Aprendiste «%s». Equípala en la mochila." % ItemDefs.item_name(pick))
	return true


## Usa el objeto de la casilla i (vendaje, comida, agua, chatarra). Devuelve true si se consumio.
func use_slot(i: int) -> bool:
	var s = inventory.slots[i]
	if s == null or ItemDefs.is_skill(s["id"]) or dead:
		return false
	if ItemDefs.is_weapon(s["id"]):
		equip_from_slot(i)
		return false
	match s["id"]:
		"bandage":
			if health >= max_health and infection <= 0.0:
				toast.emit("No necesitas un vendaje ahora.")
				return false
			health = minf(max_health, health + 25.0)
			infection = maxf(0.0, infection - 20.0)
			Sfx.play("heal", -3.0)
			toast.emit("Vendaje: salud recuperada")
		"food":
			if hunger >= 99.0:
				toast.emit("No tienes hambre.")
				return false
			hunger = minf(100.0, hunger + 35.0)
			Sfx.play("eat", -3.0)
			toast.emit("Comida: hambre saciada")
		"water":
			if thirst >= 99.0:
				toast.emit("No tienes sed.")
				return false
			thirst = minf(100.0, thirst + 40.0)
			Sfx.play("drink", -3.0)
			toast.emit("Agua: sed saciada")
		"cerca", "barricada":
			if not Structure.try_place(self, s["id"]):
				return false
		"madera":
			toast.emit("La madera se usa en la mesa de trabajo del refugio: cercas y barricadas.")
			return false
		"scrap":
			if scrap < 2 or weapon_is_gun or weapon_durability >= weapon_max:
				_try_repair()
				return false
			_try_repair()
			return true
		_:
			return false
	inventory.take_one(i)
	return true


func take_damage(amount: float, from_pos: Vector2) -> void:
	if dead or _invuln > 0.0:
		return
	health -= amount
	_invuln = 0.55
	Sfx.play("hurt", -2.0)
	velocity += (global_position - from_pos).normalized() * 120.0
	if randf() < 0.25:
		infection = minf(100.0, infection + 12.0)
		toast.emit("Te mordieron: infección en aumento")
	if health <= 0.0:
		_die()


## Dano continuo del ambiente (lluvia acida, aire toxico).
func environmental_damage(amount: float) -> void:
	last_env_hit_ms = Time.get_ticks_msec()
	_hurt_over_time(amount)


## Reaparece en un refugio tras morir.
func revive(at: Vector2) -> void:
	dead = false
	global_position = at
	velocity = Vector2.ZERO
	health = max_health * 0.6
	stamina = max_stamina
	hunger = maxf(hunger, 50.0)
	thirst = maxf(thirst, 50.0)
	infection = 0.0
	exhausted = false
	_invuln = 2.0
	sprite.modulate = Color.WHITE
	sprite.play("idle_down")


func _die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	sprite.stop()
	sprite.modulate = Color(0.5, 0.2, 0.2)
	flash.enabled = false
	Sfx.play("death", 0.0, 0.0)
	died.emit()


func _update_visuals(delta: float) -> void:
	var moving := velocity.length() > 5.0
	var anim_name := "down"
	if absf(facing.x) > absf(facing.y):
		anim_name = "side"
		sprite.flip_h = facing.x < 0.0
	elif facing.y < 0.0:
		anim_name = "up"
	var prefix := "idle_"
	if _attack_t > 0.0:
		prefix = "attack_"
	elif _dodge_t > 0.0:
		prefix = "run_"
	elif moving:
		prefix = "run_" if running else "walk_"
	var wanted := SpriteSheets.pick(sprite.sprite_frames, prefix, anim_name)
	if sprite.animation != wanted:
		sprite.play(wanted)
	sprite.speed_scale = 1.0
	# la esquiva se ve como un impulso: cuerpo agachado y estirado
	if _dodge_t > 0.0:
		sprite.scale = Vector2(1.12, 0.84)
		sprite.position = _sprite_base + Vector2(0, 2.5)
	else:
		sprite.scale = Vector2.ONE
		sprite.position = _sprite_base

	# parpadeo al recibir dano / esquivar
	if _invuln > 0.0:
		sprite.modulate = Color(1.0, 0.55, 0.55, 0.6 if _dodge_t > 0.0 else 1.0)
	else:
		sprite.modulate = Color.WHITE

	flash.enabled = flashlight_on
	flash.energy = 1.15 * light_mult
	halo.energy = 0.55 * light_mult
	var target := facing.angle()
	flash.rotation = lerp_angle(flash.rotation, target, clampf(12.0 * delta, 0.0, 1.0))
	if _attack_t > 0.0 or weapon_is_gun:
		fx.queue_redraw()
	elif fx.has_meta("drawn"):
		fx.remove_meta("drawn")
		fx.queue_redraw()


func _draw_fx() -> void:
	if weapon_is_gun:
		_draw_gun()
		return
	if _attack_t <= 0.0:
		return
	fx.set_meta("drawn", true)
	var progress := 1.0 - _attack_t / 0.18
	var base := _swing_dir.angle()
	var a0 := base - 1.0
	var a1 := base + 1.0
	var a := lerpf(a0, a1, progress)
	var origin := Vector2(0, -6)
	# el tubo ya esta dibujado en el sprite: aqui solo la estela del golpe
	fx.draw_arc(origin, 25.0, a0, a, 10, Color(1, 1, 1, 0.45), 2.0)
	fx.draw_arc(origin, 22.0, a0 + 0.2, a - 0.1, 8, Color(1, 1, 1, 0.2), 1.0)


## Arma de fuego en la mano: se apoya en el costado hacia donde mira, con destello al disparar.
func _draw_gun() -> void:
	fx.set_meta("drawn", true)
	var dirv := facing
	var base := Vector2(0, -5) + dirv * 6.0
	var long := weapon_id == "escopeta" or weapon_id == "fusil"
	var n := 11.0 if long else 7.0
	var tip := base + dirv * n
	var side := Vector2(-dirv.y, dirv.x)
	fx.draw_line(base - dirv * 2.0, tip, Color("22171e"), 4.0 if long else 3.0)
	fx.draw_line(base - dirv * 2.0, tip, Color("5a5e68"), 2.0)
	fx.draw_line(base - dirv * 2.0 + side * 1.0, base + side * 1.0 + dirv * 2.0, Color("8a5a2b"), 2.0)
	if _muzzle_t > 0.0:
		var k := _muzzle_t / 0.08
		fx.draw_circle(tip + dirv * 3.0, 4.0 * k + 1.0, Color(1.0, 0.85, 0.4, 0.9))
		fx.draw_circle(tip + dirv * 3.0, 2.0 * k + 0.5, Color(1.0, 1.0, 0.9, 1.0))
