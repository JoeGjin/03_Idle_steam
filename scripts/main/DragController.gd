# 本脚本用于处理拖拽和点击事件的检测与信号发射

extends Node

enum DragState { IDLE, PENDING, DRAGGING } # 拖拽状态枚举

@export var target: Node2D
const DRAG_THRESHOLD := 6.0

var _state := DragState.IDLE
var _drag_offset := Vector2.ZERO
var _press_pos := Vector2.ZERO

signal drag_started
signal dragged(global_pos: Vector2)
signal drag_ended
signal clicked


func _unhandled_input(event: InputEvent) -> void:
    if target == null:
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            # 仅在点击目标时进入 PENDING 状态
            if _hit_target(event.position):
                _state = DragState.PENDING
                _press_pos = event.position
                _drag_offset = target.global_position - event.position
                get_viewport().set_input_as_handled()
        else:
            match _state:
                DragState.DRAGGING: # 完成拖拽
                    _state = DragState.IDLE
                    drag_ended.emit()
                    get_viewport().set_input_as_handled()
                DragState.PENDING: # 作为点击处理
                    _state = DragState.IDLE
                    clicked.emit()
                    get_viewport().set_input_as_handled()

    elif event is InputEventMouseMotion and _state != DragState.IDLE:
        if _state == DragState.PENDING: # 检测是否超过拖拽阈值
            if event.position.distance_to(_press_pos) >= DRAG_THRESHOLD:
                _state = DragState.DRAGGING
                drag_started.emit()
                get_viewport().set_input_as_handled()
        
        if _state == DragState.DRAGGING: # 继续拖拽
            dragged.emit(event.position + _drag_offset)
            get_viewport().set_input_as_handled()
			

func _hit_target(mouse_pos: Vector2) -> bool:
    var local := target.to_local(mouse_pos)
    if target is Sprite2D:
        if target.texture == null:
            return false
        
        var size: Vector2 = target.texture.get_size() * target.scale
        var rect := Rect2(-size * 0.5, size)  # 默认居中原点
        
        return rect.has_point(local)
    
    else:
        return false
