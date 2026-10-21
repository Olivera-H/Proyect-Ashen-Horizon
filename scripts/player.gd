class_name Player
extends CharacterBody2D
## Protagonista jugable. Movimiento, estamina, esquiva, combate cuerpo a cuerpo
## con desgaste del arma, ruido, linterna y estados de supervivencia.

signal died
signal toast(text: String)

const DODGE_SPEED := 190.0
const DODGE_TIME := 0.22
const ATTACK_RANGE := 28.0
const ATTACK_DAMAGE := 18.0
const WEAPON_MAX := 40.0
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
var scrap := 0
var weapon_durability := WEAPON_MAX
var weapon_name := "Tubo de hierro"

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
var camera: Camera2D
var flash: PointLight2D
var halo: PointLight2D
var fx: Node2D


func setup(id: String) -> void:
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
	sprite.sprite_frames = PixelArt.make_humanoid_frames(data["palette"])
	sprite.position = Vector2(0, -4)
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
	return base


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
	if Input.is_action_just_pressed("flashlight"):
		flashlight_on = not flashlight_on

	move_and_slide()
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	_dodge_t = maxf(0.0, _dodge_t - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	_attack_t = maxf(0.0, _attack_t - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_spike_t = maxf(0.0, _spike_t - delta)


func _update_stats(delta: float) -> void:
	# estamina
	if not running and _dodge_t <= 0.0:
		var regen: float = data["stamina_regen"]
		if hunger < 20.0 or thirst < 20.0:
			regen *= 0.5
		stamina = minf(max_stamina, stamina + regen * delta)
		if exhausted and stamina >= max_stamina * 0.25:
			exhausted = false
	# hambre y sed
	hunger = maxf(0.0, hunger - 0.12 * delta)
	thirst = maxf(0.0, thirst - 0.18 * delta)
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


func _try_attack() -> void:
	if _attack_cd > 0.0 or _dodge_t > 0.0 or stamina < 8.0:
		return
	_attack_cd = 0.45
	_attack_t = 0.18
	_swing_dir = facing
	stamina -= 8.0
	make_noise(90.0, 0.35)
	var armed := weapon_durability > 0.0
	var dmg: float = (ATTACK_DAMAGE if armed else 6.0) * float(data["melee_damage"])
	var hit_any := false
	for z in get_tree().get_nodes_in_group("zombies"):
		var to_z: Vector2 = z.global_position - global_position
		if to_z.length() <= ATTACK_RANGE and to_z.normalized().dot(facing) > 0.3:
			z.take_damage(dmg, facing * 140.0, 0.35 if armed else 0.15)
			hit_any = true
	if hit_any and armed:
		weapon_durability = maxf(0.0, weapon_durability - 1.5)
		if weapon_durability <= 0.0:
			toast.emit("Tu %s se rompió. Repárala con chatarra." % weapon_name.to_lower())


func _try_repair() -> void:
	if scrap < 2:
		toast.emit("Necesitas 2 de chatarra para reparar.")
		return
	if weapon_durability >= WEAPON_MAX:
		toast.emit("El arma ya está en buen estado.")
		return
	scrap -= 2
	var gain := 20.0 * float(data["craft_bonus"])
	weapon_durability = minf(WEAPON_MAX, weapon_durability + gain)
	toast.emit("Arma reparada.")


## Devuelve true si el objeto fue recogido/consumido.
func collect(kind: String) -> bool:
	match kind:
		"scrap":
			if scrap >= INVENTORY_LIMIT:
				toast.emit("Inventario lleno.")
				return false
			scrap += 1
			toast.emit("+1 chatarra")
		"food":
			hunger = minf(100.0, hunger + 35.0)
			toast.emit("Comida: hambre saciada")
		"water":
			thirst = minf(100.0, thirst + 40.0)
			toast.emit("Agua: sed saciada")
		"bandage":
			health = minf(max_health, health + 25.0)
			infection = maxf(0.0, infection - 20.0)
			toast.emit("Vendaje: salud recuperada")
		_:
			return false
	return true


func take_damage(amount: float, from_pos: Vector2) -> void:
	if dead or _invuln > 0.0:
		return
	health -= amount
	_invuln = 0.55
	velocity += (global_position - from_pos).normalized() * 120.0
	if randf() < 0.25:
		infection = minf(100.0, infection + 12.0)
		toast.emit("Te mordieron: infección en aumento")
	if health <= 0.0:
		_die()


## Dano continuo del ambiente (lluvia acida, aire toxico).
func environmental_damage(amount: float) -> void:
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
	died.emit()


func _update_visuals(delta: float) -> void:
	var moving := velocity.length() > 5.0
	var anim_name := "down"
	if absf(facing.x) > absf(facing.y):
		anim_name = "side"
		sprite.flip_h = facing.x < 0.0
	elif facing.y < 0.0:
		anim_name = "up"
	var wanted := ("walk_" if moving else "idle_") + anim_name
	if sprite.animation != wanted:
		sprite.play(wanted)
	sprite.speed_scale = 1.4 if running else 1.0

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
	if _attack_t > 0.0:
		fx.queue_redraw()
	elif fx.has_meta("drawn"):
		fx.remove_meta("drawn")
		fx.queue_redraw()


func _draw_fx() -> void:
	if _attack_t <= 0.0:
		return
	fx.set_meta("drawn", true)
	var progress := 1.0 - _attack_t / 0.18
	var base := _swing_dir.angle()
	var a0 := base - 1.0
	var a1 := base + 1.0
	var a := lerpf(a0, a1, progress)
	var origin := Vector2(0, -3)
	var tip := origin + Vector2.from_angle(a) * 20.0
	fx.draw_line(origin + Vector2.from_angle(a) * 6.0, tip, Color("b8bcc4"), 2.0)
	fx.draw_arc(origin, 17.0, a0, a, 10, Color(1, 1, 1, 0.35), 2.0)
