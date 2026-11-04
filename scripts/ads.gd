class_name Ads
extends RefCounted
## Anuncios con recompensa (ver 1 anuncio = desbloquear una skin o una mascota).
##
## MODO DEMO: no hay red publicitaria conectada, asi que se muestra un anuncio de PRUEBA
## de 5 segundos (claramente etiquetado) y luego se da la recompensa. Para anuncios reales
## hay que integrar AdMob (plugin de Godot para Android) en `_network_show` y poner DEMO en
## false. Ver docs/MONETIZACION.md.

const DEMO := true
const WATCH_SECS := 5.0

## true mientras se muestra un anuncio (las pantallas ignoran el toque).
static var active := false


static func network_available() -> bool:
	return Engine.has_singleton("AdMob")


## Muestra un anuncio con recompensa; `on_reward` se llama solo si se ve completo.
static func show_rewarded(host: Node, what: String, on_reward: Callable) -> void:
	if active:
		return
	if not DEMO and network_available():
		_network_show(on_reward)
		return
	var ov := Overlay.new()
	ov.what = what
	ov.on_reward = on_reward
	host.get_tree().root.add_child(ov)


## Punto de enganche para AdMob (no incluido: requiere cuenta de AdMob y el plugin).
static func _network_show(_on_reward: Callable) -> void:
	pass


class Overlay extends CanvasLayer:
	var what := ""
	var on_reward: Callable
	var _t := 0.0
	var _ui: Control
	var _claim := Rect2()
	var _cancel := Rect2()
	var _last_ms := 0
	var _done := false

	func _ready() -> void:
		layer = 120
		process_mode = Node.PROCESS_MODE_ALWAYS
		Ads.active = true
		_ui = Control.new()
		_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.draw.connect(_paint)
		add_child(_ui)

	func _process(delta: float) -> void:
		_t += delta
		_ui.queue_redraw()

	func _input(event: InputEvent) -> void:
		var pos := Vector2.ZERO
		if event is InputEventScreenTouch and event.pressed:
			pos = event.position
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pos = event.position
		else:
			if event is InputEventKey or event is InputEventScreenTouch or event is InputEventMouseButton:
				get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		var now := Time.get_ticks_msec()
		if now - _last_ms < 300:
			return
		_last_ms = now
		if _t >= Ads.WATCH_SECS and _claim.has_point(pos):
			_finish(true)
		elif _cancel.has_point(pos):
			_finish(false)

	func _finish(ok: bool) -> void:
		if _done:
			return
		_done = true
		Ads.active = false
		if ok and on_reward.is_valid():
			on_reward.call()
		queue_free()

	func _paint() -> void:
		var vs := _ui.get_viewport_rect().size
		var f := UiFont.get_font()
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.9))
		var card := Rect2(vs.x * 0.5 - 220.0, vs.y * 0.5 - 130.0, 440.0, 230.0)
		_ui.draw_rect(card, Color(0.09, 0.1, 0.13))
		_ui.draw_rect(card, Color(0.55, 0.6, 0.5), false, 1.0)
		# "creatividad" falsa del anuncio de prueba
		var art := Rect2(card.position + Vector2(10, 26), Vector2(card.size.x - 20.0, 120.0))
		for i in 12:
			var k := float(i) / 11.0
			_ui.draw_rect(Rect2(art.position.x, art.position.y + art.size.y * k * 0.92, art.size.x, art.size.y / 11.0 + 1.0), Color(0.12 + 0.5 * k, 0.2 + 0.1 * k, 0.45 - 0.2 * k))
		var bx := art.position.x + fmod(_t * 60.0, art.size.x + 40.0) - 20.0
		_ui.draw_rect(Rect2(bx, art.end.y - 30.0, 16.0, 16.0), Color(1.0, 0.85, 0.3))
		_ui.draw_rect(Rect2(bx + 3.0, art.end.y - 14.0, 4.0, 6.0), Color(1.0, 0.85, 0.3))
		_ui.draw_rect(Rect2(bx + 9.0, art.end.y - 14.0 + (3.0 if int(_t * 8.0) % 2 == 0 else 0.0), 4.0, 6.0), Color(1.0, 0.85, 0.3))
		_ui.draw_string(f, art.position + Vector2(0, 44), "SUPER PIXEL RUN", HORIZONTAL_ALIGNMENT_CENTER, art.size.x, 22, Color(1, 1, 1))
		_ui.draw_string(f, art.position + Vector2(0, 66), "¡Descárgalo gratis!", HORIZONTAL_ALIGNMENT_CENTER, art.size.x, 12, Color(1, 0.95, 0.7))
		_ui.draw_string(f, card.position + Vector2(10, 18), "ANUNCIO DE PRUEBA · " + what, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 20.0, 10, Color(0.8, 0.85, 0.7))
		# barra de progreso
		var k2 := clampf(_t / Ads.WATCH_SECS, 0.0, 1.0)
		var bar := Rect2(card.position.x + 10.0, card.position.y + 156.0, card.size.x - 20.0, 6.0)
		_ui.draw_rect(bar, Color(0.2, 0.22, 0.2))
		_ui.draw_rect(Rect2(bar.position, Vector2(bar.size.x * k2, bar.size.y)), Color(0.5, 0.85, 0.4))
		var ready := _t >= Ads.WATCH_SECS
		var msg := "¡Listo! Reclama tu recompensa" if ready else "Recompensa en %d s…" % int(ceil(Ads.WATCH_SECS - _t))
		_ui.draw_string(f, card.position + Vector2(0, 178), msg, HORIZONTAL_ALIGNMENT_CENTER, card.size.x, 11, Color(0.95, 0.95, 0.85))
		_claim = Rect2(card.position.x + card.size.x - 170.0, card.end.y - 36.0, 160.0, 26.0)
		_cancel = Rect2(card.position.x + 10.0, card.end.y - 36.0, 90.0, 26.0)
		_ui.draw_rect(_claim, Color(0.16, 0.38, 0.14) if ready else Color(0.15, 0.16, 0.15))
		_ui.draw_rect(_claim, Color(0.7, 0.9, 0.6) if ready else Color(0.35, 0.37, 0.35), false, 1.0)
		_ui.draw_string(f, _claim.position + Vector2(0, 18), "RECLAMAR", HORIZONTAL_ALIGNMENT_CENTER, _claim.size.x, 12, Color(1, 1, 1) if ready else Color(0.5, 0.5, 0.5))
		_ui.draw_rect(_cancel, Color(0.22, 0.1, 0.09))
		_ui.draw_rect(_cancel, Color(0.7, 0.55, 0.5), false, 1.0)
		_ui.draw_string(f, _cancel.position + Vector2(0, 18), "CANCELAR", HORIZONTAL_ALIGNMENT_CENTER, _cancel.size.x, 11, Color(0.95, 0.85, 0.8))
		_ui.draw_string(f, Vector2(0, vs.y - 12.0), "Modo demo: aquí iría un anuncio real (AdMob). Sin cobro ni datos.", HORIZONTAL_ALIGNMENT_CENTER, vs.x, 9, Color(0.6, 0.62, 0.58))
