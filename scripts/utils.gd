extends Node

var _last_observed_pressed: Dictionary = {}
var _frame_just_pressed_cache: Dictionary = {}
var _last_query_frame: int = -1

func _prepare_frame_cache() -> void:
	var frame := Engine.get_process_frames()
	if frame != _last_query_frame:
		_last_query_frame = frame
		_frame_just_pressed_cache.clear()

func key_pressed(keycode: Key) -> bool:
	return Input.is_physical_key_pressed(keycode)

func key_just_pressed(keycode: Key) -> bool:
	_prepare_frame_cache()
	if _frame_just_pressed_cache.has(keycode):
		return _frame_just_pressed_cache[keycode]

	var current := key_pressed(keycode)
	var just_pressed := false

	if _last_observed_pressed.has(keycode):
		just_pressed = current and not bool(_last_observed_pressed[keycode])

	_last_observed_pressed[keycode] = current
	_frame_just_pressed_cache[keycode] = just_pressed
	return just_pressed

func space_pressed() -> bool:
	return key_just_pressed(KEY_SPACE)
