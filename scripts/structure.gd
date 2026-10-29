class_name Structure
extends StaticBody2D
## Cercas y barricadas de madera que el jugador coloca delante de si.
## - Cerca: 1 tile, barata, aguanta poco.
## - Barricada: 2 tiles de largo, aguanta mucho (ideal para tapar una puerta).
## Los zombis que se topan con una la golpean hasta romperla. Con el arma de mano (sin zombis a tiro)
## puedes desmontarla de 3 golpes y recuperas la pieza.

const TS := 16
const DEFS := {
	"cerca": {"len": 1, "hp": 40.0, "thick": 8.0, "name": "Cerca"},
	"barricada": {"len": 2, "hp": 150.0, "thick": 12.0, "name": "Barricada"},
}

var kind := "cerca"
var horizontal := true        # corre a lo ancho (true) o a lo alto (false)
var tiles: Array = []         # Vector2i que ocupa
var max_hp := 40.0
var hp := 40.0
var _flash := 0.0
var _hit_cd := 0.0
var _dismantle := 0
var _w := 16.0                # tamano de la huella en px
var _h := 16.0


## Intenta colocar la pieza delante del jugador. Devuelve true si se coloco.
static func try_place(player: Player, k: String) -> bool:
	var world := player.get_tree().get_first_node_in_group("world") as World
	if world == null or not DEFS.has(k):
		return false
	var d: Dictionary = DEFS[k]
	var n: int = d["len"]
	var target := player.global_position + player.facing * 20.0
	var horiz := absf(player.facing.y) >= absf(player.facing.x)
	var tl: Array = []
	for i in n:
		if horiz:
			tl.append(Vector2i(roundi(target.x / float(TS) - float(n) * 0.5) + i, floori(target.y / float(TS))))
		else:
			tl.append(Vector2i(floori(target.x / float(TS)), roundi(target.y / float(TS) - float(n) * 0.5) + i))
	var taken := {}
	for s in player.get_tree().get_nodes_in_group("structures"):
		for t in (s as Structure).tiles:
			taken[t] = true
	for t in tl:
		if world.is_solid_tile(t) or taken.has(t):
			player.toast.emit("No cabe ahí.")
			return false
	var area := Rect2(Vector2(tl[0]) * float(TS), Vector2(float(TS) * (n if horiz else 1), float(TS) * (1 if horiz else n))).grow(5.0)
	if area.has_point(player.global_position):
		player.toast.emit("Hay algo en medio: da un paso atrás.")
		return false
	for z in player.get_tree().get_nodes_in_group("zombies"):
		if area.has_point((z as Node2D).global_position):
			player.toast.emit("Hay un zombi en medio.")
			return false
	var st := Structure.new()
	st.kind = k
	st.horizontal = horiz
	st.tiles = tl
	player.get_parent().add_child(st)
	st.setup(world)
	Sfx.play("craft", -3.0)
	return true


func setup(_world: World) -> void:
	var d: Dictionary = DEFS[kind]
	max_hp = d["hp"]
	hp = max_hp
	var n: int = d["len"]
	_w = float(TS) * (n if horizontal else 1)
	_h = float(TS) * (1 if horizontal else n)
	var first: Vector2i = tiles[0]
	position = Vector2(first) * float(TS) + Vector2(_w * 0.5, _h)    # abajo al centro (orden por y)
	collision_layer = 1
	collision_mask = 0
	add_to_group("structures")
	var th: float = d["thick"]
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(_w, th) if horizontal else Vector2(th, _h)
	cs.shape = rs
	cs.position = Vector2(0.0, -th * 0.5 - 1.0) if horizontal else Vector2(0.0, -_h * 0.5)
	add_child(cs)
	queue_redraw()


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if _flash > 0.0:
		queue_redraw()


## Dano (de un zombi, por segundo * delta).
func hit(amount: float) -> void:
	hp -= amount
	_flash = 0.12
	if _hit_cd <= 0.0:
		_hit_cd = 0.45
		Sfx.play_at("hit", global_position, -6.0)
	queue_redraw()
	if hp <= 0.0:
		Sfx.play_at("hit_metal", global_position, -2.0)
		queue_free()


## El jugador la golpea con su arma de mano: a los 3 golpes la recoge.
func dismantle_swing(player: Player) -> void:
	_dismantle += 1
	_flash = 0.12
	Sfx.play("repair", -6.0)
	if _dismantle >= 3:
		if player.inventory.add(kind, 1) > 0:
			_dismantle = 2
			player.toast.emit("Mochila llena: no puedes recogerla.")
			return
		player.toast.emit("Recogiste: %s." % String(DEFS[kind]["name"]).to_lower())
		queue_free()


func near_player(p: Vector2, reach: float) -> bool:
	var r := Rect2(position - Vector2(_w * 0.5, _h), Vector2(_w, _h)).grow(reach)
	return r.has_point(p)


func _draw() -> void:
	var dmg := 1.0 - hp / max_hp
	var wood := Color("8a6a3e")
	var light := Color("b58d52")
	var dark := Color("4a3420")
	if _flash > 0.0:
		wood = wood.lightened(0.35)
		light = light.lightened(0.35)
	if kind == "cerca":
		if horizontal:
			var l := -_w * 0.5
			draw_rect(Rect2(l, -9, _w, 2), wood)                  # travesanos
			draw_rect(Rect2(l, -5, _w, 2), wood)
			draw_rect(Rect2(l, -9, _w, 1), light)
			for px in [l + 1.0, -1.5, -l - 4.0]:
				draw_rect(Rect2(px, -13, 3, 13), dark)
				draw_rect(Rect2(px, -13, 3, 2), wood)
		else:
			var tp := -_h
			draw_rect(Rect2(-2, tp + 1, 4, _h - 1), wood)          # travesano visto desde arriba
			draw_rect(Rect2(-2, tp + 1, 1, _h - 1), light)
			for k in range(0, int(_h), 8):
				draw_rect(Rect2(-3, tp + 1 + k, 6, 7 if k + 7 <= _h else 4), dark)
				draw_rect(Rect2(-3, tp + 1 + k, 6, 2), wood)
	else:
		if horizontal:
			var l := -_w * 0.5
			for i in 3:
				draw_rect(Rect2(l, -14 + i * 4, _w, 3), wood if i % 2 == 0 else wood.darkened(0.12))
				draw_rect(Rect2(l, -14 + i * 4, _w, 1), light)
			draw_line(Vector2(l + 2, -2), Vector2(-l - 2, -13), dark, 2.0)       # tirantes
			draw_line(Vector2(l + 2, -13), Vector2(-l - 2, -2), dark, 2.0)
			for sx in range(int(l) + 4, int(-l) - 2, 8):                          # puas
				draw_rect(Rect2(sx, -17, 1, 3), Color("9aa0a8"))
			draw_rect(Rect2(l, -2, _w, 2), dark)
		else:
			var tp := -_h
			for i in 3:
				draw_rect(Rect2(-6 + i * 4, tp, 3, _h), wood if i % 2 == 0 else wood.darkened(0.12))
				draw_rect(Rect2(-6 + i * 4, tp, 1, _h), light)
			draw_line(Vector2(-6, tp + 2), Vector2(6, -2), dark, 2.0)
			draw_line(Vector2(6, tp + 2), Vector2(-6, -2), dark, 2.0)
	if dmg > 0.25:   # grietas
		var cr := Color(0.05, 0.03, 0.02, 0.8)
		var cx := 0.0
		var top := -12.0 if horizontal else -_h * 0.8
		draw_line(Vector2(cx - 4, top), Vector2(cx, top + 5), cr, 1.0)
		draw_line(Vector2(cx, top + 5), Vector2(cx - 2, top + 9), cr, 1.0)
		if dmg > 0.6:
			draw_line(Vector2(cx + 6, top + 1), Vector2(cx + 3, top + 7), cr, 1.0)
	if _dismantle > 0:
		draw_rect(Rect2(-_w * 0.5, 1, _w * float(_dismantle) / 3.0, 2), Color("e8a030"))
