class_name Zombie
extends CharacterBody2D
## Zombi caminante: vaga, oye el ruido del jugador, lo ve con la linterna
## o de cerca, lo persigue y lo ataca cuerpo a cuerpo.

enum State { WANDER, INVESTIGATE, CHASE }

const HEARING_BASE := 14.0       # oye siempre a esta distancia (pasos muy cerca)
const SIGHT_RANGE := 90.0
const SIGHT_RANGE_LIGHT := 130.0  # si el jugador tiene la linterna encendida
const SIGHT_DOT := 0.2            # cono de vision frontal
const LOSE_RANGE := 170.0
const ATTACK_RANGE := 11.0

@export var max_health := 80.0
@export var wander_speed := 14.0
@export var chase_speed := 36.0
@export var damage := 12.0

var health := 80.0
var state := State.WANDER
var player: Player = null
var world: World = null
var sprite: AnimatedSprite2D
var variant := 0              # que aspecto de la hoja de sprites usa
var _atk_t := 0.0
var facing := Vector2.DOWN

var _target := Vector2.ZERO
var _wander_t := 0.0
var _stun := 0.0
var _attack_cd := 0.0
var _knock := Vector2.ZERO
var _flash_t := 0.0
var _alert_t := 0.0


var kind := "walker"          # walker | runner | tank
var tint := Color.WHITE
var knock_resist := 1.0
var body_scale := 1.0
var sight_mult := 1.0


## Ajusta las estadisticas segun el tipo. Llamar ANTES de setup().
func configure(k: String) -> void:
	kind = k
	variant = randi() % 4
	match k:
		"runner":  # agil: ve mas lejos y corre casi al ritmo del jugador
			max_health = 48.0
			wander_speed = 22.0
			chase_speed = 70.0
			damage = 9.0
			sight_mult = 1.35
		"tank":    # colosal: aguanta mucho, golpea fuerte, casi no retrocede
			max_health = 440.0
			wander_speed = 10.0
			chase_speed = 30.0
			damage = 30.0
			knock_resist = 0.15
			body_scale = 1.6   # solo el cuerpo fisico; el sprite del tanque ya es grande


## Un ruido lejano (evento del mapa) los hace ir a investigar.
func investigate(pos: Vector2) -> void:
	if state == State.CHASE:
		return
	state = State.INVESTIGATE
	_target = pos
	_alert_t = 6.0


func setup(w: World, p: Player) -> void:
	world = w
	player = p
	health = max_health
	collision_layer = 4
	collision_mask = 1 | 4
	add_to_group("zombies")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.5 * body_scale
	shape.shape = circle
	add_child(shape)

	sprite = AnimatedSprite2D.new()
	var sheet: SpriteFrames = null
	match kind:
		"tank":
			sheet = SpriteSheets.frames("tank", SpriteSheets.TANK)
			sprite.position = SpriteSheets.TANK_POS
		"runner":
			sheet = SpriteSheets.frames("runner_%d" % (variant % 2), SpriteSheets.HUMAN)
			sprite.position = SpriteSheets.HUMAN_POS
		_:
			sheet = SpriteSheets.frames("walker_%d" % (variant % 4), SpriteSheets.HUMAN)
			sprite.position = SpriteSheets.HUMAN_POS
	if sheet != null:
		sprite.sprite_frames = sheet
	else:  # arte de respaldo si falta la hoja de sprites
		sprite.sprite_frames = PixelArt.make_humanoid_frames(PixelArt.zombie_palette(), true)
		sprite.position = Vector2(0, -4.0 * body_scale)
		sprite.scale = Vector2.ONE * body_scale
	sprite.play("idle_down")
	add_child(sprite)

	_wander_t = randf_range(0.5, 3.0)
	facing = Vector2.from_angle(randf() * TAU)


## Nivel de alerta 0..1 para el minimapa.
func alert_level() -> float:
	match state:
		State.CHASE:
			return 1.0
		State.INVESTIGATE:
			return 0.6
	return 0.0


func take_damage(amount: float, knockback: Vector2, stun_time: float) -> void:
	health -= amount
	_knock = knockback * knock_resist
	_stun = maxf(_stun, stun_time * maxf(knock_resist, 0.3))
	_flash_t = 0.15
	if player != null and not player.dead:
		state = State.CHASE
		_target = player.global_position
	_spawn_blood(6 if health > 0.0 else 14, knockback.normalized() if knockback.length() > 1.0 else Vector2.DOWN)
	if health <= 0.0:
		_leave_corpse()
		queue_free()


func _physics_process(delta: float) -> void:
	if player == null or world == null:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_flash_t = maxf(0.0, _flash_t - delta)
	_atk_t = maxf(0.0, _atk_t - delta)
	_alert_t = maxf(0.0, _alert_t - delta)

	if _stun > 0.0:
		_stun -= delta
		_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
		velocity = _knock
		move_and_slide()
		_update_visuals()
		return

	_knock = Vector2.ZERO
	var player_safe := world.safe_rect.has_point(player.global_position)
	if player_safe and state != State.WANDER:
		state = State.WANDER
		_dir = Vector2.ZERO
	if not player.dead and not player_safe:
		_perceive()
	var speed := 0.0
	match state:
		State.WANDER:
			speed = _do_wander(delta)
		State.INVESTIGATE:
			speed = _do_investigate()
		State.CHASE:
			speed = _do_chase()
	velocity = velocity.move_toward(_desired_velocity(speed), 400.0 * delta)
	move_and_slide()
	_update_visuals()


var _dir := Vector2.ZERO

func _desired_velocity(speed: float) -> Vector2:
	return _dir * speed


func _perceive() -> void:
	var to_p := player.global_position - global_position
	var dist := to_p.length()

	# vista: cono frontal, con mas alcance si el jugador lleva la linterna
	var sight := (SIGHT_RANGE_LIGHT if player.flashlight_on else SIGHT_RANGE) * sight_mult
	if dist < sight and (to_p.normalized().dot(facing) > SIGHT_DOT or dist < 24.0) and _has_line_of_sight():
		state = State.CHASE
		_target = player.global_position
		return

	# oido: el ruido del jugador (correr, atacar, disparar) los atrae
	var hear := HEARING_BASE + player.noise_radius()
	if dist < hear:
		if state == State.WANDER:
			state = State.INVESTIGATE
		_target = player.global_position
		_alert_t = 1.5
		if player.noise_radius() > 80.0 and dist < hear * 0.7:
			state = State.CHASE


func _has_line_of_sight() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	return space.intersect_ray(q).is_empty()


func _do_wander(delta: float) -> float:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 4.5)
		if randf() < 0.35:
			_dir = Vector2.ZERO
		else:
			_dir = Vector2.from_angle(randf() * TAU)
	if _dir.length() > 0.1:
		facing = _dir
	return wander_speed


func _do_investigate() -> float:
	var to_t := _target - global_position
	if to_t.length() < 8.0 or _alert_t <= 0.0:
		state = State.WANDER
		_wander_t = 1.0
		_dir = Vector2.ZERO
		return 0.0
	_dir = to_t.normalized()
	facing = _dir
	return chase_speed * 0.7


func _do_chase() -> float:
	var to_p := player.global_position - global_position
	if player.dead or to_p.length() > LOSE_RANGE:
		state = State.INVESTIGATE
		_alert_t = 2.0
		return 0.0
	_target = player.global_position
	_dir = to_p.normalized()
	facing = _dir
	if to_p.length() < ATTACK_RANGE * body_scale and _attack_cd <= 0.0:
		_attack_cd = 1.0
		_atk_t = 0.4
		player.take_damage(damage, global_position)
	return chase_speed


func _update_visuals() -> void:
	var speed := velocity.length()
	var moving := speed > 3.0
	var anim_name := "down"
	if absf(facing.x) > absf(facing.y):
		anim_name = "side"
		sprite.flip_h = facing.x < 0.0
	elif facing.y < 0.0:
		anim_name = "up"
	var prefix := "idle_"
	var anim_speed := 1.0
	if _atk_t > 0.0:
		prefix = "attack_"
		anim_speed = 0.5                      # el zarpazo dura ~0.4 s
	elif moving:
		if kind == "runner" and speed > 40.0:
			prefix = "run_"                   # el corredor se lanza a todo correr
			anim_speed = clampf(speed / 70.0, 0.7, 1.4)
		else:
			prefix = "walk_"
			var ref := 36.0 if kind == "tank" else (28.0 if kind == "walker" else 30.0)
			anim_speed = clampf(speed / ref, 0.5, 1.6)
	var wanted := SpriteSheets.pick(sprite.sprite_frames, prefix, anim_name)
	if sprite.animation != wanted:
		sprite.play(wanted)
	sprite.speed_scale = anim_speed
	sprite.modulate = Color(2.2, 2.2, 2.2) if _flash_t > 0.0 else tint


## Salpicadura de sangre al recibir un golpe (mas grande al morir).
func _spawn_blood(amount: int, dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.4
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.gravity = Vector2.ZERO
	p.damping_min = 110.0
	p.damping_max = 160.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	p.color = Color("8e1b1b")
	p.z_index = 4
	parent.add_child(p)
	p.global_position = global_position + Vector2(0, -8.0 if kind != "tank" else -14.0)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


## Charco de sangre en el suelo que se desvanece solo.
func _leave_corpse() -> void:
	if world == null:
		return
	var d := Sprite2D.new()
	d.texture = PixelArt.make_blood_splat(randi())
	d.position = world.to_local(global_position)
	d.rotation_degrees = 90.0 * float(randi() % 4)
	if kind == "tank":
		d.scale = Vector2(2.0, 2.0)
	d.modulate = Color(1, 1, 1, 0.92)
	world.add_child(d)
	var tw := d.create_tween()
	tw.tween_interval(14.0)
	tw.tween_property(d, "modulate:a", 0.0, 8.0)
	tw.tween_callback(d.queue_free)
