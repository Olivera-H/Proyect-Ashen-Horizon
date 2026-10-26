class_name Projectile
extends Node2D
## Bala: avanza en linea recta, se detiene en muros y golpea al primer zombi que toca.

const SPEED := 460.0

var world: World
var dir := Vector2.RIGHT
var damage := 30.0
var max_dist := 200.0
var _travelled := 0.0
var _dead := false
var _fade := 0.0


func _process(delta: float) -> void:
	if _dead:
		_fade -= delta
		queue_redraw()
		if _fade <= 0.0:
			queue_free()
		return
	var step := SPEED * delta
	var n := maxi(1, int(ceil(step / 4.0)))
	for i in n:
		global_position += dir * (step / float(n))
		_travelled += step / float(n)
		if world != null and world.is_solid_tile(world.to_tile(global_position)):
			_end()
			return
		for z in get_tree().get_nodes_in_group("zombies"):
			if z.global_position.distance_to(global_position + Vector2(0, 4)) < 9.0:
				z.take_damage(damage, dir * 90.0, 0.3)
				_end()
				return
		if _travelled >= max_dist:
			_end()
			return
	queue_redraw()


func _end() -> void:
	_dead = true
	_fade = 0.12


func _draw() -> void:
	if _dead:
		var a := clampf(_fade / 0.12, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.9, 0.5, a * 0.8))
		return
	draw_line(-dir * 9.0, Vector2.ZERO, Color(1.0, 0.85, 0.4, 0.55), 2.0)
	draw_line(-dir * 4.0, Vector2.ZERO, Color(1.0, 1.0, 0.85, 1.0), 2.0)
