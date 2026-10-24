class_name SupplyDrop
extends Node2D
## Entrega aerea: un avion cruza el cielo, suelta una caja con paracaidas y esta aterriza
## en `ground_pos`. Emite `released` cuando se suelta y `landed` cuando toca el suelo.

signal released
signal landed

const PLANE_SPEED := 300.0
const ALTITUDE := 190.0        # altura (en pixeles) desde la que se suelta la caja
const FALL_TIME := 5.0
const PLANE_TEX := "res://assets/supply/plane.png"
const CRATE_TEX := "res://assets/supply/crate.png"
const CHUTE_TEX := "res://assets/supply/parachute.png"

var ground_pos := Vector2.ZERO
var crate: Sprite2D              # la caja que queda en el suelo (hija de `ground_parent`)
var ground_parent: Node2D

var _plane: Sprite2D
var _plane_shadow: Sprite2D
var _chute: Sprite2D
var _falling_crate: Sprite2D
var _dir := Vector2.RIGHT
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _release_pos := Vector2.ZERO
var _t := 0.0
var _released := false
var _landed := false
var _land_t := 0.0
var _phase := 0.0


static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func setup(target: Vector2, ents: Node2D) -> void:
	ground_pos = target
	ground_parent = ents
	z_index = 60
	_release_pos = target + Vector2(0, -ALTITUDE)
	var sgn := 1.0 if randf() < 0.5 else -1.0
	_dir = Vector2(sgn, randf_range(-0.18, 0.18)).normalized()
	_start = _release_pos - _dir * 520.0
	_end = _release_pos + _dir * 520.0
	_phase = randf() * TAU

	_plane_shadow = Sprite2D.new()
	_plane_shadow.texture = _tex(PLANE_TEX)
	_plane_shadow.modulate = Color(0, 0, 0, 0.28)
	_plane_shadow.scale = Vector2(0.8, 0.8)
	_plane_shadow.z_index = -10
	add_child(_plane_shadow)

	_plane = Sprite2D.new()
	_plane.texture = _tex(PLANE_TEX)
	add_child(_plane)
	_plane.rotation = _dir.angle() + PI * 0.5   # el dibujo mira hacia arriba
	_plane_shadow.rotation = _plane.rotation
	_plane.global_position = _start
	_plane_shadow.global_position = _start + Vector2(30, ALTITUDE * 0.9)


func _process(delta: float) -> void:
	_t += delta
	var travel := _t * PLANE_SPEED
	var total := _start.distance_to(_end)
	if _plane != null:
		var p := _start + _dir * travel
		_plane.global_position = p
		_plane_shadow.global_position = p + Vector2(34, ALTITUDE * 0.9)
		if travel >= total:
			_plane.queue_free()
			_plane_shadow.queue_free()
			_plane = null
	if not _released and travel >= _start.distance_to(_release_pos):
		_release()
	if _released and not _landed:
		_update_fall(delta)
	elif _landed:
		_update_landing(delta)


func _release() -> void:
	_released = true
	_falling_crate = Sprite2D.new()
	_falling_crate.texture = _tex(CRATE_TEX)
	add_child(_falling_crate)
	_chute = Sprite2D.new()
	_chute.texture = _tex(CHUTE_TEX)
	_chute.scale = Vector2(0.4, 0.4)   # empieza cerrado y se abre
	add_child(_chute)
	_fall_t = 0.0
	released.emit()


var _fall_t := 0.0


func _update_fall(delta: float) -> void:
	_fall_t += delta
	var k := clampf(_fall_t / FALL_TIME, 0.0, 1.0)
	var ease_k := 1.0 - pow(1.0 - k, 2.0)               # cae rapido y frena con el paracaidas
	var alt := ALTITUDE * (1.0 - ease_k)
	var sway := sin(_fall_t * 2.2 + _phase) * 7.0 * (1.0 - k)
	var base := ground_pos + Vector2(sway, -alt)
	_falling_crate.global_position = base
	var open := clampf(_fall_t / 0.8, 0.0, 1.0)
	_chute.scale = Vector2.ONE * lerpf(0.4, 1.0, open)
	_chute.global_position = base + Vector2(0, -22.0 * open)
	_chute.rotation = sin(_fall_t * 2.2 + _phase) * 0.12 * (1.0 - k)
	# sombra de la caja sobre el suelo, mas grande al acercarse
	queue_redraw()
	if k >= 1.0:
		_land()


func _draw() -> void:
	if _released and not _landed:
		var k := clampf(_fall_t / FALL_TIME, 0.0, 1.0)
		var r := lerpf(5.0, 15.0, k)
		draw_set_transform(ground_pos + Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, r, Color(0, 0, 0, lerpf(0.12, 0.35, k)))


func _land() -> void:
	_landed = true
	_land_t = 0.0
	_falling_crate.queue_free()
	_falling_crate = null
	crate = Sprite2D.new()
	crate.texture = _tex(CRATE_TEX)
	crate.centered = false
	var sz := crate.texture.get_size() if crate.texture != null else Vector2(36, 20)
	crate.offset = Vector2(-sz.x * 0.5, -sz.y + 3.0)
	crate.global_position = ground_pos
	ground_parent.add_child(crate)
	queue_redraw()
	landed.emit()


func _update_landing(delta: float) -> void:
	_land_t += delta
	# el paracaidas se desinfla sobre la caja y se desvanece
	var k := clampf(_land_t / 2.5, 0.0, 1.0)
	_chute.scale = Vector2(lerpf(1.0, 1.25, k), lerpf(1.0, 0.25, k))
	_chute.global_position = ground_pos + Vector2(0, lerpf(-22.0, -4.0, k))
	_chute.modulate.a = 1.0 - maxf(0.0, (k - 0.6) / 0.4)
	if _land_t >= 2.5:
		queue_free()
