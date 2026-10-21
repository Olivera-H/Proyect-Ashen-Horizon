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

@export var max_health := 40.0
@export var wander_speed := 14.0
@export var chase_speed := 36.0
@export var damage := 12.0

var health := 40.0
var state := State.WANDER
var player: Player = null
var world: World = null
var sprite: AnimatedSprite2D
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
	match k:
		"runner":  # agil: ve mas lejos y corre casi al ritmo del jugador
			max_health = 24.0
			wander_speed = 22.0
			chase_speed = 70.0
			damage = 9.0
			sight_mult = 1.35
			tint = Color(1.0, 0.85, 0.8)
		"tank":    # colosal: aguanta mucho, golpea fuerte, casi no retrocede
			max_health = 220.0
			wander_speed = 10.0
			chase_speed = 30.0
			damage = 30.0
			knock_resist = 0.15
			body_scale = 1.6
			tint = Color(0.75, 0.85, 0.65)


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
	if health <= 0.0:
		queue_free()


func _physics_process(delta: float) -> void:
	if player == null or world == null:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_flash_t = maxf(0.0, _flash_t - delta)
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
		player.take_damage(damage, global_position)
	return chase_speed


func _update_visuals() -> void:
	var moving := velocity.length() > 3.0
	var anim_name := "down"
	if absf(facing.x) > absf(facing.y):
		anim_name = "side"
		sprite.flip_h = facing.x < 0.0
	elif facing.y < 0.0:
		anim_name = "up"
	var wanted := ("walk_" if moving else "idle_") + anim_name
	if sprite.animation != wanted:
		sprite.play(wanted)
	sprite.modulate = Color(2.2, 2.2, 2.2) if _flash_t > 0.0 else tint
