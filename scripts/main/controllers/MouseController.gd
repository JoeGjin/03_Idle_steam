# 检测未被 UI 消费的鼠标点击与拖拽，转发交互信号，并将窗口拖动交给系统。

extends Node
class_name MouseController


# 左键按下后进入 PENDING；满足距离和区域条件后进入 DRAGGING，松开后回到 IDLE。
enum DragState { IDLE, PENDING, DRAGGING } # 拖拽状态枚举

# 外部依赖与拖拽阈值（输入事件坐标中的距离）。
@onready var pet: Node2D = %Pet
const DRAG_THRESHOLD := 6.0

# 本次左键交互的状态与按下位置。
var _state := DragState.IDLE
var _press_pos := Vector2.ZERO

# Main 订阅这些信号；原生窗口拖动由本脚本直接启动。
signal drag_started
signal drag_ended
signal left_clicked
signal right_clicked


# 目录
# 鼠标输入与拖拽识别：统一由 _unhandled_input 处理，pet 为空时跳过。
# 1. 左键：按下记录位置；松开时按状态发出 left_clicked 或 drag_ended。
# 2. 右键：按下时发出 right_clicked。
# 3. 移动：达到 DRAG_THRESHOLD 且鼠标当前位于 WorldOutput 矩形内时，
#    发出 drag_started 并启动系统原生拖窗；拖拽期间只标记输入已处理。


#region 鼠标输入与拖拽识别

func _unhandled_input(event: InputEvent) -> void:
    if pet == null:
        return

    # 左键负责区分点击与拖拽，松开时结束本次交互。
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

    # 右键在按下时立即通知监听者。
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        if event.pressed:
            right_clicked.emit()
            get_viewport().set_input_as_handled()

    elif event is InputEventMouseMotion and _state != DragState.IDLE:
        if _state == DragState.PENDING:
            if event.position.distance_to(_press_pos) >= DRAG_THRESHOLD:
                # 达到阈值时检查当前鼠标位置；这里不判断最初的按下位置。
                if %WorldOutput.get_global_rect().has_point(%WorldOutput.get_global_mouse_position()):
                    _state = DragState.DRAGGING
                    drag_started.emit()
                    DisplayServer.window_start_drag() # 交给系统原生拖窗
                    get_viewport().set_input_as_handled()

        if _state == DragState.DRAGGING: # 原生拖窗进行中，这里不用做任何事
            get_viewport().set_input_as_handled()

#endregion
