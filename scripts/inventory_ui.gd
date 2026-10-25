class_name InventoryUI
extends Control
## Barra inferior con 3 casillas rapidas y el boton de la mochila. La mochila abre un panel
## con 15 casillas y 3 casillas de habilidades equipadas.
## - Barra cerrada: tocar una casilla usa el objeto (teclas 1, 2, 3 en PC).
## - Mochila abierta: tocar un objeto lo selecciona; tocar otra casilla lo mueve o intercambia.
##   Debajo aparecen los botones Usar / Equipar / Quitar / Tirar. Boton de mochila o tecla B abre y cierra.

const SLOT := 24.0
const GAP := 3.0
const PAD := 8.0
const GRID_COLS := 5
const FONT_S := 9

var player: Player
var inv: Inventory
var open := false
var selected := -1

var _font: Font
var _tex_slot: Texture2D
var _tex_sel: Texture2D
var _tex_skill: Texture2D
var _tex_bag: Texture2D
var _flash := {}          # casilla -> tiempo restante del destello al usar
var _bag_pop := 0.0       # rebote del icono de la mochila al recoger algo
var _last_total := 0
var _buttons: Array = []  # [{rect, label, action}]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("ui_block")
	_font = UiFont.get_font()
	_tex_slot = load("res://assets/ui/inv/slot.png")
	_tex_sel = load("res://assets/ui/inv/slot_sel.png")
	_tex_skill = load("res://assets/ui/inv/slot_skill.png")
	_tex_bag = load("res://assets/ui/inv/bag.png")


func setup(p: Player) -> void:
	player = p
	inv = p.inventory
	_last_total = _total_items()


func _total_items() -> int:
	var n := 0
	for s in inv.slots:
		if s != null:
			n += int(s["n"])
	return n


# ------------------------------------------------------------ geometria

func _hotbar_origin() -> Vector2:
	var vs := get_viewport_rect().size
	var w := Inventory.HOTBAR * SLOT + (Inventory.HOTBAR - 1) * GAP + 8.0 + SLOT
	return Vector2(vs.x * 0.5 - w * 0.5, vs.y - SLOT - 8.0)


func _bag_button_rect() -> Rect2:
	var o := _hotbar_origin()
	return Rect2(o.x + Inventory.HOTBAR * (SLOT + GAP) + 5.0, o.y, SLOT, SLOT)


func _panel_rect() -> Rect2:
	var w := PAD * 2.0 + GRID_COLS * SLOT + (GRID_COLS - 1) * 2.0 + 10.0 + SLOT
	var h := 160.0
	var hb := _hotbar_origin()
	var br := _bag_button_rect()
	return Rect2(br.end.x - w, hb.y - h - 6.0, w, h)


func _slot_rect(i: int) -> Rect2:
	var k := Inventory.kind_of(i)
	if k == "hotbar":
		var o := _hotbar_origin()
		return Rect2(o.x + i * (SLOT + GAP), o.y, SLOT, SLOT)
	var pr := _panel_rect()
	if k == "bag":
		var j := i - Inventory.BAG_START
		return Rect2(pr.position.x + PAD + (j % GRID_COLS) * (SLOT + 2.0), pr.position.y + 18.0 + (j / GRID_COLS) * (SLOT + 2.0), SLOT, SLOT)
	var j2 := i - Inventory.SKILL_START
	var x := pr.position.x + PAD + GRID_COLS * (SLOT + 2.0) + 8.0
	return Rect2(x, pr.position.y + 18.0 + j2 * (SLOT + 2.0), SLOT, SLOT)


func _slot_at(pos: Vector2) -> int:
	var last := Inventory.TOTAL if open else Inventory.HOTBAR
	for i in last:
		if _slot_rect(i).has_point(pos):
			return i
	return -1


## TouchControls pregunta esto para no iniciar el joystick al tocar el inventario.
func blocks(pos: Vector2) -> bool:
	if _bag_button_rect().grow(4.0).has_point(pos):
		return true
	var ho := _hotbar_origin()
	if Rect2(ho.x - 3.0, ho.y - 3.0, Inventory.HOTBAR * (SLOT + GAP) + 3.0, SLOT + 6.0).has_point(pos):
		return true
	return open and _panel_rect().grow(2.0).has_point(pos)


# ------------------------------------------------------------ entrada

func _input(event: InputEvent) -> void:
	if player == null:
		return
	if event is InputEventScreenTouch and event.pressed:
		if _tap(event.position):
			get_viewport().set_input_as_handled()


func _tap(pos: Vector2) -> bool:
	if _bag_button_rect().grow(3.0).has_point(pos):
		set_open(not open)
		return true
	if open:
		for b in _buttons:
			if (b["rect"] as Rect2).has_point(pos):
				_press_button(b["action"])
				return true
	var i := _slot_at(pos)
	if i >= 0:
		_tap_slot(i)
		return true
	return open and _panel_rect().has_point(pos)


func set_open(v: bool) -> void:
	open = v
	selected = -1
	queue_redraw()


func _tap_slot(i: int) -> void:
	if not open:
		_use(i)
		return
	if selected == -1:
		if inv.slots[i] != null:
			selected = i
		return
	if selected == i:
		selected = -1
		return
	if inv.move(selected, i):
		selected = -1
	elif inv.slots[i] != null:
		player.toast.emit("Ahí no se puede guardar eso.")
		selected = i
	else:
		player.toast.emit("Las casillas de habilidad solo aceptan habilidades.")


func _use(i: int) -> void:
	if inv.slots[i] == null:
		return
	if player.use_slot(i):
		_flash[i] = 0.25


func _press_button(action: String) -> void:
	if selected < 0 or inv.slots[selected] == null:
		return
	match action:
		"use":
			_use(selected)
			if inv.slots[selected] == null:
				selected = -1
		"equip":
			var target := -1
			for k in range(Inventory.SKILL_START, Inventory.TOTAL):
				if inv.slots[k] == null:
					target = k
					break
			if target == -1:
				target = Inventory.SKILL_START   # intercambia con la primera
			inv.move(selected, target)
			selected = -1
		"unequip":
			for k in range(Inventory.BAG_START, Inventory.SKILL_START):
				if inv.slots[k] == null:
					inv.move(selected, k)
					selected = -1
					return
			player.toast.emit("La mochila está llena.")
		"drop":
			inv.discard(selected)
			selected = -1


# ------------------------------------------------------------ dibujo

func _process(delta: float) -> void:
	if player == null:
		return
	if Input.is_action_just_pressed("toggle_bag"):
		set_open(not open)
	for k in _flash.keys():
		_flash[k] -= delta
		if _flash[k] <= 0.0:
			_flash.erase(k)
	var total := _total_items()
	if total > _last_total:
		_bag_pop = 0.35
	_last_total = total
	_bag_pop = maxf(0.0, _bag_pop - delta)
	if selected >= 0 and inv.slots[selected] == null:
		selected = -1
	queue_redraw()


func _txt(pos: Vector2, s: String, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string_outline(_font, pos, s, align, width, size, 3, Color(0, 0, 0, 0.9))
	draw_string(_font, pos, s, align, width, size, col)


func _draw_slot(i: int) -> void:
	var r := _slot_rect(i)
	var kind := Inventory.kind_of(i)
	var tex := _tex_skill if kind == "skill" else _tex_slot
	var pulse := 1.0
	if _flash.has(i):
		pulse = 1.0 + 0.25 * sin(float(_flash[i]) / 0.25 * PI)
	draw_texture(tex, r.position)
	var s = inv.slots[i]
	if s != null:
		var icon := ItemDefs.icon(s["id"])
		if icon != null:
			var sz := Vector2(16, 16) * pulse
			draw_texture_rect(icon, Rect2(r.position + Vector2(SLOT, SLOT) * 0.5 - sz * 0.5, sz), false)
		if int(s["n"]) > 1:
			_txt(r.position + Vector2(0, SLOT - 2.0), str(int(s["n"])), 8, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 2.0)
	if i == selected:
		draw_texture(_tex_sel, r.position)
	if kind == "hotbar":
		_txt(r.position + Vector2(3.0, 9.0), str(i + 1), 8, Color(1, 1, 1, 0.55))


func _draw() -> void:
	if player == null or _font == null:
		return
	# barra rapida
	var ho := _hotbar_origin()
	draw_rect(Rect2(ho.x - 3.0, ho.y - 3.0, Inventory.HOTBAR * (SLOT + GAP) + 3.0, SLOT + 6.0), Color(0, 0, 0, 0.35))
	for i in Inventory.HOTBAR:
		_draw_slot(i)
	# boton de la mochila
	var br := _bag_button_rect()
	var pop := sin(_bag_pop / 0.35 * PI) * 3.0 if _bag_pop > 0.0 else 0.0
	if open:
		draw_rect(br.grow(2.0), Color(0.95, 0.77, 0.06, 0.35))
	draw_texture(_tex_bag, br.position + Vector2(0, -pop))
	_buttons.clear()
	if not open:
		return
	_draw_panel()


func _draw_panel() -> void:
	var pr := _panel_rect()
	draw_rect(pr, Color(0.06, 0.07, 0.11, 0.93))
	draw_rect(pr, Color("4a5068"), false, 1.0)
	_txt(pr.position + Vector2(PAD, 12.0), "MOCHILA", 10, Color("e8e2cf"))
	var sx := pr.position.x + PAD + GRID_COLS * (SLOT + 2.0) + 8.0
	_txt(Vector2(sx - 2.0, pr.position.y + 12.0), "HABIL.", 8, Color("e0b030"))
	for i in range(Inventory.BAG_START, Inventory.TOTAL):
		_draw_slot(i)
	# informacion del objeto seleccionado
	var info_y := pr.position.y + 18.0 + 3.0 * (SLOT + 2.0) + 4.0
	if selected >= 0 and inv.slots[selected] != null:
		var id: String = inv.slots[selected]["id"]
		_txt(Vector2(pr.position.x + PAD, info_y + 8.0), ItemDefs.item_name(id), 10, Color("f1c40f"))
		var desc: String = ItemDefs.ITEMS[id].get("desc", "")
		draw_multiline_string(_font, Vector2(pr.position.x + PAD, info_y + 19.0), desc,
			HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - PAD * 2.0, 8, 2, Color(0.82, 0.84, 0.9))
		var labels: Array = []
		var kind := Inventory.kind_of(selected)
		if ItemDefs.is_skill(id):
			labels.append(["QUITAR", "unequip"] if kind == "skill" else ["EQUIPAR", "equip"])
		else:
			labels.append(["USAR", "use"])
		labels.append(["TIRAR", "drop"])
		var bx := pr.position.x + PAD
		var by := pr.end.y - 20.0
		for l in labels:
			var rr := Rect2(bx, by, 52.0, 15.0)
			draw_rect(rr, Color(0.16, 0.18, 0.27))
			draw_rect(rr, Color("a8842a") if l[1] != "drop" else Color("8a3a3a"), false, 1.0)
			_txt(Vector2(rr.position.x, rr.position.y + 11.0), l[0], 9, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
			_buttons.append({"rect": rr, "label": l[0], "action": l[1]})
			bx += 58.0
	else:
		draw_multiline_string(_font, Vector2(pr.position.x + PAD, info_y + 10.0),
			"Toca un objeto y luego otra casilla para moverlo.", HORIZONTAL_ALIGNMENT_LEFT, pr.size.x - PAD * 2.0, 8, 3, Color(0.6, 0.63, 0.72))
