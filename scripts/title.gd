extends Node2D
## Pantalla de inicio: logo, lluvia, ruinas al fondo y menu tactil
## (JUGAR / CONTROLES / CREDITOS). Al pulsar JUGAR carga la partida.

const MAIN_SCENE := "res://scenes/main.tscn"
const AUDIO_CONFIG := "user://audio_settings.cfg"
const MASTER_BUS := 0

var _font: Font
var _t := 0.0
var _drops: Array = []
var _stars: Array = []
var _panel := ""            # "", "controles", "creditos"
var _buttons: Array = []    # {rect, id, text}
var _go_t := -1.0
var _flash := 0.0
var _last_press_ms := -1000
var _last_press_pos := Vector2(-100, -100)
var _ash: Array = []
var _zombies: Array = []
const TIPS := ["Los ruidos atraen a los infectados: corre solo si es necesario.", "La lluvia ácida quema. Busca techo o una máscara antigás.", "Los refugios curan y guardan tu progreso.", "Revisa las casas: el botín brilla dentro.", "Una linterna encendida te delata de lejos."]
var _skyline: Array = []
var _master_volume := 0.8
var _music_volume := 1.0
var _sfx_volume := 1.0
var _skin_preview: AnimatedSprite2D
var _skin_mode := "idle_down"
var _skin_timer := 0.0


func _ready() -> void:
	_font = UiFont.get_font()
	Sfx.setup_audio()
	_load_volume()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 160:
		_drops.append([rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4)])
	for i in 60:
		_stars.append([rng.randf(), rng.randf() * 0.5, rng.randf()])
	var x := 0.0
	while x < 1.1:
		var w := rng.randf_range(0.03, 0.08)
		_skyline.append([x, w, rng.randf_range(0.08, 0.28), rng.randi() % 3])
		x += w * rng.randf_range(0.7, 1.1)
	_create_skin_preview()
	for i in 55:
		_ash.append([rng.randf(), rng.randf(), rng.randf_range(0.01, 0.035), rng.randf_range(0.6, 1.6), rng.randf()])
	for i in 4:
		_zombies.append([rng.randf(), rng.randf_range(0.012, 0.03), rng.randf_range(0.9, 1.25), rng.randf() * 6.0])
	Sfx.ensure(get_tree())
	_start_audio()
	var m := Music.new()
	m._gap = 1.5
	add_child(m)
	get_viewport().size_changed.connect(queue_redraw)


func _load_volume() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(AUDIO_CONFIG) == OK:
		_master_volume = clampf(float(cfg.get_value("audio", "master", 0.8)), 0.0, 1.0)
	_music_volume = clampf(float(cfg.get_value("audio", "music", 1.0)), 0.0, 1.0)
	_sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	_apply_volume()


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(maxf(_master_volume, 0.0001)))
	AudioServer.set_bus_mute(MASTER_BUS, _master_volume <= 0.001)
	Sfx.set_bus_level("Music", _music_volume)
	Sfx.set_bus_level("SFX", _sfx_volume)


func _set_volume(kind: String, value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	match kind:
		"master":
			_master_volume = v
		"music":
			_music_volume = v
		"sfx":
			_sfx_volume = v
	_apply_volume()
	var cfg := ConfigFile.new()
	cfg.load(AUDIO_CONFIG)
	cfg.set_value("audio", kind, v)
	cfg.save(AUDIO_CONFIG)
	queue_redraw()


func _volume_rect(vs: Vector2, index: int) -> Rect2:
	return Rect2(vs.x * 0.5 - 112.0, vs.y * 0.51 + index * 44.0, 224.0, 14.0)


func _adjust_volume(pos: Vector2) -> bool:
	if _panel != "configuracion":
		return false
	var keys := ["master", "music", "sfx"]
	for i in 3:
		var bar := _volume_rect(get_viewport_rect().size, i)
		if bar.grow(12.0).has_point(pos):
			_set_volume(keys[i], (pos.x - bar.position.x) / bar.size.x)
			return true
	return false


func _skin_panel(vs: Vector2) -> Rect2:
	return Rect2(vs.x - 204.0, vs.y * 0.46, 184.0, 164.0)


func _create_skin_preview() -> void:
	Settings.ensure()
	_skin_preview = AnimatedSprite2D.new()
	_apply_skin_frames()
	_skin_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_skin_preview.scale = Vector2(2.6, 2.6)
	_skin_preview.play("idle_down")
	add_child(_skin_preview)
	_position_skin_preview()
	get_viewport().size_changed.connect(_position_skin_preview)


func _apply_skin_frames() -> void:
	var frames := SpriteSheets.frames(Settings.skin, SpriteSheets.HUMAN)
	if frames == null:
		frames = PixelArt.make_humanoid_frames(Characters.get_data("mateo")["palette"])
	_skin_preview.sprite_frames = frames
	_skin_preview.play("idle_down")
	_skin_mode = "idle_down"
	_skin_timer = 0.0


func _change_skin(step: int) -> void:
	Settings.cycle_skin(step)
	_apply_skin_frames()
	Sfx.play("ui_click", -4.0)


func _position_skin_preview() -> void:
	if _skin_preview == null:
		return
	var p := _skin_panel(get_viewport_rect().size)
	_skin_preview.position = p.position + Vector2(p.size.x * 0.5, 90.0)


func _start_audio() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	Sfx.loop("rain_loop", true, -12.0)


func _process(delta: float) -> void:
	_t += delta
	_skin_timer += delta
	if _skin_preview != null:
		_skin_preview.visible = _panel == ""
		if _skin_timer > 3.2:
			_skin_timer = 0.0
			_skin_mode = "walk_down" if _skin_mode == "idle_down" else "idle_down"
			_skin_preview.play(SpriteSheets.pick(_skin_preview.sprite_frames, _skin_mode.split("_")[0] + "_", "down"))
	_flash = maxf(0.0, _flash - delta * 2.0)
	if randf() < delta * 0.12:
		_flash = 1.0
	if _go_t >= 0.0:
		_go_t += delta
		if _go_t > 0.7:
			set_process(false)
			Sfx.loop("rain_loop", false)
			get_tree().change_scene_to_file(MAIN_SCENE)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _go_t >= 0.0:
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventScreenDrag:
		_adjust_volume(event.position)
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pos = event.position
		pressed = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_adjust_volume(event.position)
		return
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_press("jugar")
		elif event.keycode == KEY_ESCAPE and _panel != "":
			_press("volver")
		return
	if not pressed:
		return
	var now := Time.get_ticks_msec()   # un toque llega como tactil Y raton: atender solo el primero
	if now - _last_press_ms < 300 and pos.distance_to(_last_press_pos) < 16.0:
		return
	_last_press_ms = now
	_last_press_pos = pos
	if _adjust_volume(pos):
		return
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			_press(b["id"])
			return
	if _panel != "":
		_press("volver")


func _press(id: String) -> void:
	match id:
		"jugar":
			Sfx.play("ui_start")
			_go_t = 0.0
		"controles", "creditos", "configuracion":
			Sfx.play("ui_click")
			_panel = id
		"skin_prev":
			_change_skin(-1)
		"skin_next":
			_change_skin(1)
		"mensajes":
			Settings.hide_messages = not Settings.hide_messages
			Settings.save()
			Sfx.play("ui_click")
		"volver":
			Sfx.play("ui_close", -4.0)
			_panel = ""


## Rectangulo con las esquinas cortadas (estilo consola militar).
func _chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut),
		Vector2(r.end.x, r.end.y - cut), Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x + cut, r.end.y),
		Vector2(r.position.x, r.end.y - cut), Vector2(r.position.x, r.position.y + cut)])


func _brackets(r: Rect2, ln: float, col: Color) -> void:
	for sx in [0, 1]:
		for sy in [0, 1]:
			var c := Vector2(r.position.x if sx == 0 else r.end.x, r.position.y if sy == 0 else r.end.y)
			var dx := ln if sx == 0 else -ln
			var dy := ln if sy == 0 else -ln
			draw_line(c, c + Vector2(dx, 0), col, 2.0)
			draw_line(c, c + Vector2(0, dy), col, 2.0)


func _txt(s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 3, Color(0, 0, 0, 0.9))
	draw_string(_font, pos, s, align, width, size, col)


func _draw() -> void:
	var vs := get_viewport_rect().size
	var cx := vs.x * 0.5
	# cielo
	var steps := 24
	for i in steps:
		var k := float(i) / steps
		var c := Color(0.03, 0.04, 0.06).lerp(Color(0.16, 0.10, 0.09), pow(k, 1.6))
		draw_rect(Rect2(0, vs.y * k, vs.x, vs.y / steps + 1.0), c)
	for s in _stars:
		var a := 0.25 + 0.5 * absf(sin(_t * 0.8 + s[2] * 6.0))
		draw_rect(Rect2(s[0] * vs.x, s[1] * vs.y, 1, 1), Color(0.8, 0.85, 1.0, a * 0.5))
	# luna roja
	draw_circle(Vector2(vs.x * 0.78, vs.y * 0.2), 22.0, Color(0.55, 0.12, 0.10, 0.25))
	draw_circle(Vector2(vs.x * 0.78, vs.y * 0.2), 14.0, Color(0.75, 0.22, 0.16, 0.55))
	# ruinas
	var base := vs.y * 0.80
	# sol de ceniza en el horizonte: disco rojo con franjas (estilo retro) y halo
	var sun_c := Vector2(vs.x * 0.52, base - 6.0)
	for gi in 6:
		draw_circle(sun_c, 120.0 - gi * 14.0, Color(0.6, 0.1, 0.06, 0.02 + 0.005 * gi))
	draw_circle(sun_c, 62.0, Color(0.62, 0.13, 0.07, 0.42))
	draw_circle(sun_c, 52.0, Color(0.78, 0.2, 0.1, 0.30))
	for i in 9:   # franjas oscuras que se hacen mas gruesas hacia abajo
		var sy := sun_c.y - 56.0 + i * 8.0 + 4.0
		draw_rect(Rect2(sun_c.x - 64.0, sy, 128.0, 1.0 + i * 0.55), Color(0.1, 0.07, 0.075, 0.95))
	# segunda capa de edificios, lejana y mas clara
	for b in _skyline:
		var fx: float = fposmod(b[0] * vs.x * 1.25 + 60.0 + _t * 1.2, vs.x * 1.3) - 40.0
		var fw: float = b[1] * vs.x * 0.9
		var fh: float = b[2] * vs.y * 0.62 + 10.0
		draw_rect(Rect2(fx, base - fh - 4.0, fw, fh + 8.0), Color(0.075, 0.07, 0.095, 0.9))
	# reflector que barre el cielo desde una torre
	var tw_x := vs.x * 0.9
	var ang := -1.9 + 0.55 * sin(_t * 0.35)
	var beam := PackedVector2Array([Vector2(tw_x, base - 30.0), Vector2(tw_x, base - 30.0) + Vector2.from_angle(ang - 0.05) * 420.0, Vector2(tw_x, base - 30.0) + Vector2.from_angle(ang + 0.05) * 420.0])
	draw_colored_polygon(beam, Color(0.85, 0.9, 1.0, 0.035))
	draw_rect(Rect2(tw_x - 2.0, base - 30.0, 4.0, 30.0), Color(0.03, 0.03, 0.04))
	for b in _skyline:
		var bx: float = b[0] * vs.x
		var bw: float = b[1] * vs.x
		var bh: float = b[2] * vs.y
		draw_rect(Rect2(bx, base - bh, bw, bh + 40.0), Color(0.04, 0.045, 0.06))
		if b[3] == 1:   # techo roto
			draw_rect(Rect2(bx + bw * 0.4, base - bh - 6.0, bw * 0.3, 6.0), Color(0.04, 0.045, 0.06))
		var wy := base - bh + 6.0
		while wy < base - 6.0:
			var wx := bx + 4.0
			while wx < bx + bw - 5.0:
				var h := int(wx * 13.0 + wy * 7.0) % 11
				if h == 0:
					var fl := 0.7 + 0.3 * sin(_t * 6.0 + wx)
					draw_rect(Rect2(wx, wy, 3, 3), Color(0.9, 0.7, 0.3, 0.7 * fl))
				elif h < 6:
					draw_rect(Rect2(wx, wy, 3, 3), Color(0.08, 0.09, 0.12))
				wx += 8.0
			wy += 9.0
	draw_rect(Rect2(0, base, vs.x, vs.y - base), Color(0.025, 0.028, 0.035))
	# resplandor del horizonte y zombis que deambulan
	for i in 10:
		var k2 := float(i) / 10.0
		draw_rect(Rect2(0, base - 46.0 + i * 5.0, vs.x, 6.0), Color(0.55, 0.12, 0.08, 0.035 * (1.0 - k2) + 0.01))
	for z in _zombies:
		var zx := fposmod(z[0] * vs.x + _t * z[1] * vs.x, vs.x + 60.0) - 30.0
		var sc: float = z[2]
		var sw := sin(_t * 2.2 + z[3])
		var zy := base + 10.0 * (sc - 1.0) + 6.0
		var zc := Color(0.012, 0.014, 0.02)
		draw_rect(Rect2(zx - 3.0 * sc + sw * 0.5, zy - 13.0 * sc, 6.0 * sc, 9.0 * sc), zc)
		draw_rect(Rect2(zx - 2.0 * sc + sw, zy - 18.0 * sc, 4.0 * sc, 5.0 * sc), zc)
		draw_rect(Rect2(zx + 2.0 * sc, zy - 12.0 * sc + sw, 7.0 * sc, 2.0 * sc), zc)
		draw_rect(Rect2(zx - 3.0 * sc, zy - 4.0 * sc, 2.5 * sc, 4.0 * sc + sw), zc)
		draw_rect(Rect2(zx + 0.5 * sc, zy - 4.0 * sc, 2.5 * sc, 4.0 * sc - sw), zc)
		draw_rect(Rect2(zx + 1.0 * sc, zy - 16.5 * sc, 1.2, 1.2), Color(0.9, 0.15, 0.1, 0.8))
	# silueta de superviviente con linterna
	var px := vs.x * 0.2
	draw_rect(Rect2(px - 3, base - 14, 6, 14), Color(0.01, 0.01, 0.015))
	draw_rect(Rect2(px - 2, base - 19, 4, 5), Color(0.01, 0.01, 0.015))
	var cone := PackedVector2Array([Vector2(px + 3, base - 12), Vector2(px + 120, base - 30), Vector2(px + 120, base + 6)])
	draw_colored_polygon(cone, Color(1.0, 0.95, 0.7, 0.07 + 0.02 * sin(_t * 9.0)))
	# lluvia
	for d in _drops:
		var y := fposmod(d[1] + _t * 0.9 * d[2], 1.0)
		var x := fposmod(d[0] - y * 0.12 + _t * 0.02, 1.0)
		draw_line(Vector2(x * vs.x, y * vs.y), Vector2(x * vs.x - 2, y * vs.y + 7), Color(0.55, 0.75, 0.6, 0.35))
	# ceniza que sube y bruma a ras de suelo
	for a in _ash:
		var ay := fposmod(a[1] - _t * a[2], 1.0)
		var ax := fposmod(a[0] + sin(_t * a[3] + a[4] * 6.0) * 0.012, 1.0)
		draw_rect(Rect2(ax * vs.x, ay * vs.y, 1.5, 1.5), Color(0.85, 0.5, 0.3, 0.25 + 0.35 * a[4]))
	for i in 3:
		var fx := fposmod(_t * (6.0 + i * 4.0) + i * 200.0, vs.x + 400.0) - 400.0
		draw_rect(Rect2(fx, base - 8.0 + i * 7.0, 400.0, 14.0), Color(0.5, 0.55, 0.6, 0.035))
	# relampago
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.8, 0.9, 1.0, _flash * 0.16))
	# viñeta
	for i in 6:
		var m := float(i) * 10.0
		draw_rect(Rect2(m, m, vs.x - 2.0 * m, vs.y - 2.0 * m), Color(0, 0, 0, 0.07), false, 10.0)

	# logo
	var col_x := maxf(24.0, cx - 230.0)
	var col_w := 200.0
	var ly := vs.y * 0.2
	var shake := 0.0 if randf() > 0.02 else 1.0
	var neon := 1.0 if fmod(_t, 7.0) > 0.35 or fmod(_t * 23.0, 1.0) > 0.5 else 0.45   # parpadeo ocasional
	for gi in 5:
		draw_circle(Vector2(col_x + col_w * 0.5, ly + 20.0), 150.0 - gi * 28.0, Color(0.5, 0.08, 0.05, 0.018 * neon))
	# emblema: sol naciente sobre una linea de horizonte
	var ex := col_x + col_w * 0.5
	var ey := ly - 40.0
	draw_arc(Vector2(ex, ey + 10.0), 11.0, PI, TAU, 18, Color(0.9, 0.3, 0.18, 0.95), 2.0)
	for k in 5:
		var a2 := PI + (float(k) + 0.5) * PI / 5.0
		draw_line(Vector2(ex, ey + 10.0) + Vector2.from_angle(a2) * 14.0, Vector2(ex, ey + 10.0) + Vector2.from_angle(a2) * 19.0, Color(0.9, 0.55, 0.3, 0.8), 1.0)
	draw_rect(Rect2(ex - 26.0, ey + 10.0, 52.0, 2.0), Color(0.85, 0.8, 0.7, 0.9))
	draw_rect(Rect2(ex - 16.0, ey + 14.0, 32.0, 1.0), Color(0.85, 0.8, 0.7, 0.45))
	_txt("ASHEN", Vector2(col_x - 20.0 + shake + 2.0, ly + 2.0), 44, Color(0.25, 0.05, 0.03, 0.9), HORIZONTAL_ALIGNMENT_CENTER, col_w + 40.0)   # sombra
	_txt("ASHEN", Vector2(col_x - 20.0 + shake, ly), 44, Color(0.93, 0.85, 0.72), HORIZONTAL_ALIGNMENT_CENTER, col_w + 40.0)
	_txt("HORIZON", Vector2(col_x - 20.0 + 2.0, ly + 42.0), 44, Color(0.18, 0.02, 0.02, 0.9), HORIZONTAL_ALIGNMENT_CENTER, col_w + 40.0)
	_txt("HORIZON", Vector2(col_x - 20.0, ly + 40.0), 44, Color(0.9 * neon, 0.17 * neon, 0.12 * neon), HORIZONTAL_ALIGNMENT_CENTER, col_w + 40.0)
	draw_rect(Rect2(col_x, ly + 49.0, col_w * 0.5 - 8.0, 1.0), Color(0.75, 0.7, 0.62, 0.5))
	draw_rect(Rect2(col_x + col_w * 0.5 + 8.0, ly + 49.0, col_w * 0.5 - 8.0, 1.0), Color(0.75, 0.7, 0.62, 0.5))
	draw_colored_polygon(PackedVector2Array([Vector2(ex - 4.0, ly + 49.5), Vector2(ex, ly + 45.5), Vector2(ex + 4.0, ly + 49.5), Vector2(ex, ly + 53.5)]), Color(0.85, 0.2, 0.14))
	_txt("supervivencia en un mundo de ceniza", Vector2(col_x - 20.0, ly + 64.0), 9, Color(0.7, 0.7, 0.72, 0.85), HORIZONTAL_ALIGNMENT_CENTER, col_w + 40.0)

	# botones
	_buttons.clear()
	if _panel == "":
		var skin_box := _skin_panel(vs)
		draw_colored_polygon(_chamfer(skin_box, 8.0), Color(0.045, 0.055, 0.065, 0.9))
		draw_rect(Rect2(skin_box.position.x + 8.0, skin_box.position.y, skin_box.size.x - 16.0, 3.0), Color(0.6, 0.76, 0.46))
		_brackets(skin_box.grow(2.0), 12.0, Color(0.62, 0.78, 0.48, 0.9))
		# foco y sombra bajo el personaje
		var spot := skin_box.position + Vector2(skin_box.size.x * 0.5, 112.0)
		draw_colored_polygon(PackedVector2Array([spot + Vector2(-8.0, -70.0), spot + Vector2(8.0, -70.0), spot + Vector2(38.0, 4.0), spot + Vector2(-38.0, 4.0)]), Color(0.9, 0.95, 0.75, 0.06))
		for ei in 4:
			draw_rect(Rect2(spot.x - 26.0 + ei * 3.0, spot.y - 2.0 + ei * 1.5, 52.0 - ei * 6.0, 2.0), Color(0, 0, 0, 0.28))
		_txt("SUPERVIVIENTE", skin_box.position + Vector2(0, 19), 12, Color(0.87, 0.91, 0.75), HORIZONTAL_ALIGNMENT_CENTER, skin_box.size.x)
		var si := maxi(0, Settings.skin_index())
		var sk: Dictionary = Settings.SKINS[si]
		_txt(String(sk["name"]), skin_box.position + Vector2(0, 133), 12, Color(0.94, 0.87, 0.73), HORIZONTAL_ALIGNMENT_CENTER, skin_box.size.x)
		_txt("%s  ·  SKIN %02d / %02d" % [sk["job"], si + 1, Settings.SKINS.size()], skin_box.position + Vector2(0, 149), 9, Color(0.58, 0.79, 0.55), HORIZONTAL_ALIGNMENT_CENTER, skin_box.size.x)
		for di in Settings.SKINS.size():   # indicador de pagina
			var dx := skin_box.position.x + skin_box.size.x * 0.5 + (float(di) - (Settings.SKINS.size() - 1) * 0.5) * 9.0
			draw_circle(Vector2(dx, skin_box.end.y - 8.0), 2.2 if di == si else 1.4, Color(0.62, 0.8, 0.48) if di == si else Color(0.4, 0.45, 0.4, 0.8))
		for side in 2:   # flechas para cambiar de skin
			var ar := Rect2(skin_box.position.x + (6.0 if side == 0 else skin_box.size.x - 36.0), skin_box.position.y + 56.0, 30.0, 56.0)
			_buttons.append({"rect": ar, "id": "skin_prev" if side == 0 else "skin_next"})
			draw_rect(ar, Color(0.1, 0.12, 0.13, 0.7))
			draw_rect(ar, Color(0.54, 0.68, 0.46, 0.7), false, 1.0)
			var c := ar.get_center()
			var d := -1.0 if side == 0 else 1.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(5.0 * d, 0), c + Vector2(-4.0 * d, -9), c + Vector2(-4.0 * d, 9)]), Color(0.9, 0.88, 0.7))
		var bw := col_w
		var bh := 24.0
		var by := vs.y * 0.52
		var items := [["jugar", "JUGAR"], ["controles", "CONTROLES"], ["configuracion", "CONFIGURACIÓN"], ["creditos", "CRÉDITOS"]]
		for i in items.size():
			var r := Rect2(col_x, by + i * (bh + 8.0), bw, bh)
			_buttons.append({"rect": r, "id": items[i][0]})
			var pulse := 0.5 + 0.5 * sin(_t * 3.0) if i == 0 else 0.0
			var fill := Color(0.09, 0.095, 0.115, 0.88).lerp(Color(0.5, 0.1, 0.07, 0.94), pulse * 0.85 if i == 0 else 0.0)
			draw_colored_polygon(_chamfer(r, 6.0), fill)
			draw_rect(Rect2(r.position.x + 6.0, r.position.y, r.size.x - 12.0, 1.0), Color(1, 1, 1, 0.12))   # brillo superior
			draw_polyline(PackedVector2Array(_chamfer(r, 6.0) + PackedVector2Array([_chamfer(r, 6.0)[0]])), Color(0.8, 0.74, 0.64, 0.85) if i == 0 else Color(0.62, 0.62, 0.58, 0.7), 1.0)
			draw_rect(Rect2(r.position.x + 2.0, r.position.y + 5.0, 3.0, bh - 10.0), Color(0.9, 0.22, 0.15) if i == 0 else Color(0.5, 0.58, 0.45))
			# icono a la izquierda
			var ic := Vector2(r.position.x + 20.0, r.position.y + bh * 0.5)
			var icol := Color(0.95, 0.88, 0.75, 0.95)
			match int(i):
				0:   # jugar: triangulo animado
					var sh := 1.5 * sin(_t * 5.0)
					draw_colored_polygon(PackedVector2Array([ic + Vector2(-4.0 + sh, -6.0), ic + Vector2(6.0 + sh, 0.0), ic + Vector2(-4.0 + sh, 6.0)]), Color(1.0, 0.5, 0.35))
				1:   # controles: cruceta
					draw_rect(Rect2(ic.x - 1.5, ic.y - 6.0, 3.0, 12.0), icol)
					draw_rect(Rect2(ic.x - 6.0, ic.y - 1.5, 12.0, 3.0), icol)
				2:   # configuracion: sliders
					for k in 3:
						draw_rect(Rect2(ic.x - 6.0, ic.y - 5.0 + k * 5.0, 12.0, 1.5), icol)
						draw_rect(Rect2(ic.x - 4.0 + k * 3.5, ic.y - 6.5 + k * 5.0, 2.5, 4.5), Color(0.62, 0.8, 0.48))
				_:   # creditos: estrella
					draw_colored_polygon(PackedVector2Array([ic + Vector2(0, -6), ic + Vector2(2, -1.5), ic + Vector2(6, -1), ic + Vector2(3, 2), ic + Vector2(4, 6), ic + Vector2(0, 3.5), ic + Vector2(-4, 6), ic + Vector2(-3, 2), ic + Vector2(-6, -1), ic + Vector2(-2, -1.5)]), icol)
			if i == 0 and fmod(_t, 1.0) < 0.6:
				_txt(">", Vector2(r.end.x - 20.0, r.position.y + 17.0), 14, Color(0.95, 0.4, 0.3))
			_txt(items[i][1], Vector2(r.position.x + 12.0, r.position.y + 17.0), 14, Color(0.97, 0.94, 0.87), HORIZONTAL_ALIGNMENT_CENTER, bw - 12.0)
	else:
		var pr := Rect2(cx - 190, vs.y * 0.36, 380, vs.y * 0.58)
		draw_rect(pr, Color(0.03, 0.03, 0.04, 0.92))
		draw_rect(pr, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
		var lines: Array = []
		if _panel == "configuracion":
			lines = ["CONFIGURACIÓN DE AUDIO", "Ajusta música y efectos por separado."]
		elif _panel == "controles":
			lines = ["MÓVIL: joystick izquierdo para moverte; botones a la derecha para",
				"atacar/disparar, esquivar, linterna, reparar y abrir la mochila.",
				"Toca las casillas de la barra para usar objetos y armas.",
				"PC: WASD mover · Shift correr · Espacio esquivar · J/Z atacar",
				"F linterna · R reparar · 1-3 barra rápida · B mochila · M mapa",
				"Los ruidos atraen zombis. Busca refugios y la máscara antigás."]
		else:
			lines = ["ASHEN HORIZON", "Diseño, historia y programación: Jose + Claude",
				"Música original: archivos aportados por Jose",
				"Efectos de sonido: sintetizados por código (tools/gen_sfx.py)",
				"Hecho con Godot 4.3"]
		var yy := pr.position.y + 22.0
		for l in lines:
			_txt(l, Vector2(pr.position.x, yy), 10, Color(0.88, 0.86, 0.8), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
			yy += 16.0
		if _panel == "configuracion":
			var names := ["GENERAL", "MÚSICA", "EFECTOS"]
			var values := [_master_volume, _music_volume, _sfx_volume]
			for i in 3:
				var bar := _volume_rect(vs, i)
				var value: float = values[i]
				_txt("%s: %d%%" % [names[i], int(round(value * 100.0))], Vector2(pr.position.x, bar.position.y - 7.0), 10, Color(0.9, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
				draw_rect(bar, Color(0.13, 0.13, 0.16))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x * value, bar.size.y)), Color(0.58, 0.78, 0.37))
				draw_rect(bar, Color(0.8, 0.8, 0.7), false, 1.0)
				draw_rect(Rect2(bar.position.x + bar.size.x * value - 3.0, bar.position.y - 3.0, 6.0, bar.size.y + 6.0), Color(0.95, 0.9, 0.72))
		if _panel == "configuracion":
			var tr := Rect2(pr.position.x + 70.0, pr.end.y - 38.0, pr.size.x - 140.0, 22.0)
			_buttons.append({"rect": tr, "id": "mensajes"})
			draw_rect(tr, Color(0.1, 0.1, 0.13, 0.95))
			draw_rect(tr, Color(0.75, 0.7, 0.62, 0.8), false, 1.0)
			var box := Rect2(tr.position.x + 6.0, tr.position.y + 5.0, 12.0, 12.0)
			draw_rect(box, Color(0.05, 0.05, 0.07))
			draw_rect(box, Color(0.85, 0.85, 0.75), false, 1.0)
			if Settings.hide_messages:
				draw_rect(box.grow(-3.0), Color(0.58, 0.78, 0.37))
			_txt("NO MOSTRAR MENSAJES", Vector2(tr.position.x + 22.0, tr.position.y + 15.0), 10, Color(0.95, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x - 22.0)
		_txt("toca para volver", Vector2(pr.position.x, pr.end.y - 8.0), 9, Color(0.7, 0.7, 0.7, 0.6 + 0.4 * sin(_t * 4.0)), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	if _panel == "":
		var tip: String = TIPS[int(_t / 6.0) % TIPS.size()]
		var ta := clampf(minf(fmod(_t, 6.0), 6.0 - fmod(_t, 6.0)), 0.0, 1.0)
		_txt(tip, Vector2(0, vs.y - 22.0), 10, Color(0.85, 0.82, 0.7, ta * 0.9), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_txt("v1.0 · Acto I–III", Vector2(0, vs.y - 6.0), 8, Color(0.6, 0.6, 0.6, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 8.0)

	# fundido al empezar
	if _go_t >= 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, clampf(_go_t / 0.6, 0.0, 1.0)))
