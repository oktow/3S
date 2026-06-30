extends Node


func _ready() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("reload", KEY_R)
	_add_key_action("sprint", KEY_SHIFT)
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)


func _add_key_action(action_name: String, key: Key) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	InputMap.action_add_event(action_name, event)


func _add_mouse_action(action_name: String, button: MouseButton) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)
