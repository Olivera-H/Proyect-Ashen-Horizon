class_name InputSetup
extends RefCounted
## Registra las acciones de entrada por codigo (teclado para probar en PC).
## En el movil las acciones las dispara TouchControls con Input.action_press().


static func register() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("run", [KEY_SHIFT])
	_bind("dodge", [KEY_SPACE])
	_bind("attack", [KEY_J, KEY_Z])
	_bind("repair", [KEY_R])
	_bind("flashlight", [KEY_F])
	_bind("toggle_map", [KEY_M])
	_bind("zoom_map", [KEY_N])


static func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(action, ev)
