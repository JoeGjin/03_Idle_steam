extends Node

@export var target:Node2D

var _dragging := false
var _drag_offset := Vector2.ZERO # 鼠标按下点相对 Sprite 的偏移（全局坐标）
var _pending_click := false
var _press_pos := Vector2.ZERO
const DRAG_THRESHOLD := 6.0

signal drag_started
signal dragged(global_pos: Vector2)
signal drag_ended
signal clicked


func _unhandled_input(event: InputEvent) -> void:
	if target == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# 只在点到目标上才开始“候选”
			if _hit_target(event.position):
				_pending_click = true
				_dragging = false
				_press_pos = event.position
				_drag_offset = target.global_position - event.position
				get_viewport().set_input_as_handled()

		else:
			# 松开：根据是否真正拖拽来决定发什么
			if _dragging:
				# 拖拽停止
				_dragging = false
				drag_ended.emit()
				get_viewport().set_input_as_handled()

			elif _pending_click:
				# 点击事件
				_pending_click = false
				clicked.emit()
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _pending_click and not _dragging:
			# 移动超过阈值才算拖拽
			if event.position.distance_to(_press_pos) >= DRAG_THRESHOLD:
				_dragging = true
				_pending_click = false
				drag_started.emit()
				get_viewport().set_input_as_handled()

		if _dragging:
			# 拖拽中，传给main更新位置
			dragged.emit(event.position + _drag_offset)
			get_viewport().set_input_as_handled()

func _hit_target(mouse_pos: Vector2) -> bool:
	var local := target.to_local(mouse_pos)
	if target is Sprite2D:
		if target.texture == null:
			return false

		var size :Vector2 = target.texture.get_size() * target.scale
		var rect := Rect2(-size * 0.5, size)  # 默认居中原点
		return rect.has_point(local)

	else:
		return false
