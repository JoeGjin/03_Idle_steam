extends Button

@export var min_scale := 0.5
@export var max_scale := 2.0

@export var _target: Control
var _dragging := false

var _start_mouse: Vector2
var _start_scale: Vector2
var _pivot_global: Vector2


func _ready() -> void:
	# _target = %CollectionBook
	
	# 不要覆盖 Editor 里设置的 pivot_offset
	# _target.pivot_offset = Vector2.ZERO
	
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_start_mouse = get_global_mouse_position()
			_start_scale = _target.scale

			# 使用 Editor 里设置好的 pivot_offset
			_pivot_global = _target.global_position + _target.pivot_offset * _target.scale

			print(_pivot_global)

			accept_event()
		else:
			_dragging = false
			accept_event()

	elif event is InputEventMouseMotion and _dragging:
		var mouse_pos := get_global_mouse_position()

		var start_vec := _start_mouse - _pivot_global
		var current_vec := mouse_pos - _pivot_global

		var start_len : float= max(start_vec.length(), 1.0)
		var current_len : float= current_vec.length()

		var ratio : float= current_len / start_len
		var new_scale_value : float= clamp(_start_scale.x * ratio, min_scale, max_scale)

		_target.scale = Vector2.ONE * new_scale_value

		accept_event()
