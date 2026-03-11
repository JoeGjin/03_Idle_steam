# 本脚本用于处理拖拽和点击事件的检测与信号发射

extends Node
class_name MouseController

enum DragState { IDLE, PENDING, DRAGGING } # 拖拽状态枚举

@export var pet: Node2D
const DRAG_THRESHOLD := 6.0

var _state := DragState.IDLE
var _press_pos := Vector2.ZERO

signal drag_started
signal drag_ended
signal left_clicked
signal right_clicked


# 处理原生窗口的输入事件，检测拖拽和点击，并发出相应的信号给main.gd中的处理函数
func _unhandled_input(event: InputEvent) -> void:
    if pet == null:
        return

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _state = DragState.PENDING
            _press_pos = event.position
            get_viewport().set_input_as_handled()
        else:
            match _state:
                DragState.DRAGGING: # 完成拖拽
                    _state = DragState.IDLE
                    drag_ended.emit()
                    get_viewport().set_input_as_handled()
                DragState.PENDING: # 作为点击处理
                    _state = DragState.IDLE
                    left_clicked.emit()
                    get_viewport().set_input_as_handled()

    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        if event.pressed:
            right_clicked.emit()
            get_viewport().set_input_as_handled()

    elif event is InputEventMouseMotion and _state != DragState.IDLE:
        if _state == DragState.PENDING: 
            # 检测是否超过拖拽阈值
            if event.position.distance_to(_press_pos) >= DRAG_THRESHOLD:
                _state = DragState.DRAGGING
                drag_started.emit()
                DisplayServer.window_start_drag() # 交给系统原生拖窗
                get_viewport().set_input_as_handled()
        
        if _state == DragState.DRAGGING: # 原生拖窗进行中，这里不用做任何事
            get_viewport().set_input_as_handled()
