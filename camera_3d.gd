# camera_controller.gd
extends Camera3D

@export var move_speed: float = 5.0
@export var boost_multiplier: float = 2.5 # Hold Shift to move faster
@export var mouse_sensitivity: float = 0.002 # Radians per pixel

var _velocity: Vector3 = Vector3.ZERO
var _mouse_delta: Vector2 = Vector2.ZERO

var _total_pitch: float = 0.0
const MAX_PITCH_UP: float = deg_to_rad(89.0)
const MAX_PITCH_DOWN: float = deg_to_rad(-89.0)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion:
		_mouse_delta = event.relative
	
	if event.is_action_pressed("ui_cancel"): # Pressing Esc
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and _mouse_delta.length_squared() > 0:
		rotate_y(-_mouse_delta.x * mouse_sensitivity)
		
		var pitch_change = -_mouse_delta.y * mouse_sensitivity
		var new_pitch = _total_pitch + pitch_change
		
		new_pitch = clamp(new_pitch, MAX_PITCH_DOWN, MAX_PITCH_UP)
		pitch_change = new_pitch - _total_pitch
		
		rotate_object_local(Vector3.RIGHT, pitch_change)
		_total_pitch = new_pitch
		
		_mouse_delta = Vector2.ZERO

	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_up"):
		input_dir.y += 1
	if Input.is_action_pressed("move_down"):
		input_dir.y -= 1

	input_dir = input_dir.normalized()

	var current_speed = move_speed
	if Input.is_action_pressed("move_boost"):
		current_speed *= boost_multiplier
		
	_velocity = basis * input_dir * current_speed

	global_translate(_velocity * delta)

func _create_key_event(key_code: Key) -> InputEventKey:
	var event = InputEventKey.new()
	event.keycode = key_code
	return event

func _enter_tree():
	if not InputMap.has_action("move_forward"):
		InputMap.add_action("move_forward")
		InputMap.action_add_event("move_forward", _create_key_event(KEY_W))
	if not InputMap.has_action("move_backward"):
		InputMap.add_action("move_backward")
		InputMap.action_add_event("move_backward", _create_key_event(KEY_S))
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
		InputMap.action_add_event("move_left", _create_key_event(KEY_A))
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
		InputMap.action_add_event("move_right", _create_key_event(KEY_D))
	if not InputMap.has_action("move_up"):
		InputMap.add_action("move_up")
		InputMap.action_add_event("move_up", _create_key_event(KEY_SPACE))
	if not InputMap.has_action("move_down"): # Corrected from line 94
		InputMap.add_action("move_down")
		InputMap.action_add_event("move_down", _create_key_event(KEY_CTRL))
	if not InputMap.has_action("move_boost"): # Corrected from line 97
		InputMap.add_action("move_boost")
		InputMap.action_add_event("move_boost", _create_key_event(KEY_SHIFT))
