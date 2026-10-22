class_name StatBars
extends Control
## Barras de estado en pixel art con icono: vida, estamina, hambre, sed e infeccion.
## Todo se dibuja con rectangulos a coordenadas enteras para que se vea nitido.
##
## Animaciones:
## - La barra se desliza hacia el valor nuevo y deja una estela clara (dano o ganancia).
## - Destello blanco al mejorar, rojo al empeorar; el icono tiembla con los golpes.
## - Brillo que recorre la barra y marcas en segmentos.
## - Corazon que late (mas rapido con poca vida), iconos que rebotan con valores bajos.
## - Infeccion: rayas que avanzan y calavera que tiembla cuando es grave.

const ROW_H := 20
const PLATE := 18
const BAR_X := 22
const BAR_W := 88
const BAR_H := 9
const SEG := 6
const CHANGE_MIN := 0.015   # cambio por fotograma que cuenta como "evento" (golpe, curacion)

const DEFS := [
	{"key": "health", "col": Color("c0392b"), "hi": Color("f0705f"), "lo": Color("6e1a16"), "shake_on_bad": true},
	{"key": "stamina", "col": Color("d4a017"), "hi": Color("f7d84a"), "lo": Color("7a5a0a"), "shake_on_bad": false},
	{"key": "hunger", "col": Color("d9822b"), "hi": Color("f2ab62"), "lo": Color("85470f"), "shake_on_bad": true},
	{"key": "thirst", "col": Color("3d9be0"), "hi": Color("86d3ff"), "lo": Color("1d5a96"), "shake_on_bad": true},
	{"key": "infection", "col": Color("6fb83a"), "hi": Color("a8e467"), "lo": Color("386a1a"), "shake_on_bad": true, "inverse": true},
]

var player: Player

var _icons := {}
var _st := {}
var _t := 0.0


func setup(p: Player) -> void:
	player = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(BAR_X + BAR_W + 4, ROW_H * DEFS.size())
	for d in DEFS:
		var key: String = d["key"]
		var path := "res://assets/ui/icon_%s.png" % key
		if ResourceLoader.exists(path):
			_icons[key] = load(path)
		var f := _frac(key)
		_st[key] = {"prev": f, "shown": f, "trail": f, "wait": 0.0,
			"flash": 0.0, "flash_bad": false, "shake": 0.0}


func _frac(key: String) -> float:
	match key:
		"health":
			return clampf(player.health / player.max_health, 0.0, 1.0)
		"stamina":
			return clampf(player.stamina / player.max_stamina, 0.0, 1.0)
		"hunger":
			return clampf(player.hunger / 100.0, 0.0, 1.0)
		"thirst":
			return clampf(player.thirst / 100.0, 0.0, 1.0)
		"infection":
			return clampf(player.infection / 100.0, 0.0, 1.0)
	return 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	_t += delta
	for d in DEFS:
		var key: String = d["key"]
		var s: Dictionary = _st[key]
		var f := _frac(key)
		var diff := f - float(s["prev"])
		if absf(diff) >= CHANGE_MIN:
			var inverse: bool = d.get("inverse", false)
			var bad := (diff > 0.0) if inverse else (diff < 0.0)
			s["flash"] = 0.4
			s["flash_bad"] = bad
			if bad and d["shake_on_bad"]:
				s["shake"] = 0.4
			if diff < 0.0:
				s["wait"] = 0.5
		s["prev"] = f
		s["shown"] = lerpf(float(s["shown"]), f, minf(1.0, delta * 12.0))
		if f >= float(s["trail"]):
			s["trail"] = f
		else:
			s["wait"] = float(s["wait"]) - delta
			if float(s["wait"]) <= 0.0:
				s["trail"] = move_toward(float(s["trail"]), f, delta * 0.6)
		s["flash"] = maxf(0.0, float(s["flash"]) - delta)
		s["shake"] = maxf(0.0, float(s["shake"]) - delta)
	queue_redraw()


func _draw() -> void:
	if player == null:
		return
	for i in DEFS.size():
		_draw_row(i, DEFS[i])


func _draw_row(i: int, d: Dictionary) -> void:
	var key: String = d["key"]
	var s: Dictionary = _st[key]
	var col: Color = d["col"]
	var hi: Color = d["hi"]
	var lo: Color = d["lo"]
	var inverse: bool = d.get("inverse", false)
	var y := i * ROW_H
	var f := _frac(key)
	var low := f < 0.25 and not inverse
	var critical := f > 0.7 and inverse
	var blink := int(_t * 5.0) % 2 == 0

	# --- icono con placa ---
	var shake_x := 0
	if float(s["shake"]) > 0.0 or f <= 0.001 and not inverse or critical:
		shake_x = int(round(sin(_t * 70.0) * 1.3))
	var bounce := 0
	if (low or (inverse and f > 0.3)) and blink:
		bounce = -1
	var plate_col := Color(0.04, 0.04, 0.06, 0.8)
	draw_rect(Rect2(0, y + 1, PLATE, PLATE - 2), plate_col)
	draw_rect(Rect2(1, y, PLATE - 2, PLATE), plate_col)
	var rim := lo.darkened(0.2)
	if low and blink:
		rim = Color("e04a3a")
	draw_rect(Rect2(1, y, PLATE - 2, 1), rim)
	draw_rect(Rect2(1, y + PLATE - 1, PLATE - 2, 1), rim)
	draw_rect(Rect2(0, y + 1, 1, PLATE - 2), rim)
	draw_rect(Rect2(PLATE - 1, y + 1, 1, PLATE - 2), rim)

	var tint := Color.WHITE
	if float(s["flash"]) > 0.0:
		tint = Color(1.0, 0.45, 0.45) if s["flash_bad"] else Color(1.6, 1.6, 1.6)
	if inverse and f <= 0.001:
		tint = Color(1, 1, 1, 0.45)   # sin infeccion: calavera apagada
	var tex: Texture2D = _icons.get(key)
	if tex != null:
		var ip := Vector2(1 + shake_x, y + 1 + bounce)
		var isz := Vector2(16, 16)
		if key == "health":
			var period := lerpf(0.45, 1.3, f)
			var phase := fposmod(_t, period) / period
			if phase < 0.14:   # latido
				ip += Vector2(-1, -1)
				isz = Vector2(18, 18)
		draw_texture_rect(tex, Rect2(ip, isz), false, tint)

	# --- barra ---
	var bx := BAR_X
	var by := y + int((PLATE - BAR_H) / 2.0)
	var outline := Color(0.02, 0.02, 0.03)
	if low and blink:
		outline = Color("e04a3a")
	elif critical and blink:
		outline = Color("b8ff6a")
	draw_rect(Rect2(bx + 1, by, BAR_W - 2, 1), outline)
	draw_rect(Rect2(bx + 1, by + BAR_H - 1, BAR_W - 2, 1), outline)
	draw_rect(Rect2(bx, by + 1, 1, BAR_H - 2), outline)
	draw_rect(Rect2(bx + BAR_W - 1, by + 1, 1, BAR_H - 2), outline)

	var ix := bx + 1
	var iy := by + 1
	var iw := BAR_W - 2
	var ih := BAR_H - 2
	draw_rect(Rect2(ix, iy, iw, ih), Color(0.09, 0.09, 0.12))
	draw_rect(Rect2(ix, iy + ih - 1, iw, 1), Color(0.05, 0.05, 0.07))

	# estela (dano o ganancia)
	var tw := int(floor(float(iw) * float(s["trail"])))
	if tw > 0:
		draw_rect(Rect2(ix, iy, tw, ih), hi.lerp(Color.WHITE, 0.55))

	# relleno
	var fw := int(floor(float(iw) * float(s["shown"])))
	var fill := col
	var fill_hi := hi
	var fill_lo := lo
	if key == "stamina" and player.exhausted:
		fill = col.darkened(0.45)
		fill_hi = hi.darkened(0.45)
		fill_lo = lo.darkened(0.45)
		if blink:
			fill = fill.lerp(Color("c0392b"), 0.5)
	if fw > 0:
		draw_rect(Rect2(ix, iy, fw, ih), fill)
		draw_rect(Rect2(ix, iy, fw, 1), fill_hi)
		draw_rect(Rect2(ix, iy + ih - 1, fw, 1), fill_lo)
		if inverse:   # rayas que avanzan: la infeccion "se arrastra"
			var off := int(_t * 14.0) % 8
			var k := -8
			while k < fw:
				var x0 := maxi(ix + k + off, ix)
				var x1 := mini(ix + k + off + 2, ix + fw)
				if x1 > x0:
					draw_rect(Rect2(x0, iy + 1, x1 - x0, ih - 2), Color(0, 0, 0, 0.28))
				k += 8
		# brillo que recorre la barra
		var sx := int(fposmod(_t * 45.0 + float(i) * 23.0, float(iw + 40))) - 20
		var gx0 := maxi(ix + sx, ix)
		var gx1 := mini(ix + sx + 5, ix + fw)
		if gx1 > gx0:
			draw_rect(Rect2(gx0, iy + 1, gx1 - gx0, 2), Color(1, 1, 1, 0.3))
		# destello al cambiar
		var fl := float(s["flash"])
		if fl > 0.0:
			var fc := Color(1.0, 0.25, 0.2, fl * 1.2) if s["flash_bad"] else Color(1, 1, 1, fl * 1.5)
			draw_rect(Rect2(ix, iy, fw, ih), fc)

	# marcas de segmento
	var k2 := SEG
	while k2 < iw:
		draw_rect(Rect2(ix + k2, iy, 1, ih), Color(0, 0, 0, 0.3))
		k2 += SEG
	# esquinas de brillo del marco
	draw_rect(Rect2(ix, iy, 1, 1), Color(1, 1, 1, 0.25))
