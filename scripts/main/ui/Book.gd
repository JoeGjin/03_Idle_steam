# 监测Book本身的GUI事件，负责拖动整个collection book

extends Control


@onready var collection_book: Control = %CollectionBook

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = get_global_mouse_position() - collection_book.global_position
			accept_event()
		else:
			_dragging = false
			accept_event()

	elif event is InputEventMouseMotion and _dragging:
		collection_book.global_position = get_global_mouse_position() - _drag_offset
		accept_event()