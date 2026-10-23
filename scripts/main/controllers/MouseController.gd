# 统一识别世界与 GUI 转交的鼠标点击、拖拽，将窗口拖动交给系统。

extends Node
class_name MouseController


# 左键按下后进入 PENDING；满足距离和区域条件后进入 DRAGGING，松开后回到 IDLE。
enum DragState { IDLE, PENDING, DRAGGING } # 拖拽状态枚举

# 普通模式的拖动范围与统一拖拽阈值（屏幕像素，不受角色或输出缩放影响）。
@onready var world_output: Control = %WorldOutput
const DRAG_THRESHOLD := 6.0

# 本次左键交互的状态、屏幕按下位置，以及可选的 GUI 来源。
var _state := DragState.IDLE
var _press_screen_pos := Vector2.ZERO
var _gui_source: Control

# Main 订阅这些信号；原生窗口拖动由本脚本直接启动。
signal drag_started
signal drag_ended
signal left_clicked
signal right_clicked


# 目录
# 鼠标输入与拖拽识别
# 1. 普通模式由 _unhandled_input 接收未被 UI 消费的事件。
# 2. GUI 通过 handle_gui_input 转交事件；从控件按下后可拖动，松开仍在控件内才发出单击。
#    MiniModeController 负责转交 WakeButton 输入，Main 根据 left_clicked 协调退出 mini。
# 3. 两种来源共用 _handle_pointer_input：左键区分单击与拖动，右键按下转发信号。
#    普通模式保留移动达到阈值后检查 WorldOutput 矩形的规则，GUI 使用本次按下的来源。
# 4. 拖动由 _start_window_drag 交给系统；_process 在交互期间补查松手与来源失效。
#    丢失松开事件时只清理状态，不补发单击，避免拖动误触唤醒。
#    入口：handle_gui_input / cancel_gui_input；核心：_handle_pointer_input / _finish_pointer_input。


#region 鼠标输入与拖拽识别

func _unhandled_input(event: InputEvent) -> void:
    if _handle_pointer_input(event):
        get_viewport().set_input_as_handled()


## GUI 使用自身局部坐标传入事件；距离和范围由本控制器通过屏幕坐标统一判断。
func handle_gui_input(event: InputEvent, source: Control) -> bool:
    if not is_instance_valid(source) or not source.is_visible_in_tree():
        return false
    return _handle_pointer_input(event, source)


func cancel_gui_input(source: Control) -> void:
    if _gui_source == source:
        _finish_pointer_input()


func _handle_pointer_input(event: InputEvent, source: Control = null) -> bool:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _finish_pointer_input()
            _state = DragState.PENDING
            _press_screen_pos = Vector2(DisplayServer.mouse_get_position())
            _gui_source = source
            set_process(true)
            return true

        if _state == DragState.IDLE:
            return false

        var is_click := _state == DragState.PENDING
        if _gui_source != null:
            is_click = (
                is_click
                and is_instance_valid(_gui_source)
                and _is_point_in_control(_gui_source)
                and Vector2(DisplayServer.mouse_get_position()).distance_to(_press_screen_pos) < DRAG_THRESHOLD
            )
        _finish_pointer_input()
        if is_click:
            left_clicked.emit()
        return true

    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        if event.pressed:
            right_clicked.emit()
            return true

    if event is InputEventMouseMotion and _state != DragState.IDLE:
        if _state == DragState.PENDING:
            var distance := Vector2(DisplayServer.mouse_get_position()).distance_to(_press_screen_pos)
            if distance >= DRAG_THRESHOLD and _can_start_drag():
                _start_window_drag()
        return true

    return false


func _can_start_drag() -> bool:
    if _gui_source != null:
        return is_instance_valid(_gui_source) and _gui_source.is_visible_in_tree()
    return is_instance_valid(world_output) and _is_point_in_control(world_output)


func _is_point_in_control(control: Control) -> bool:
    var mouse_screen := Vector2(DisplayServer.mouse_get_position())
    var local_position := control.get_screen_transform().affine_inverse() * mouse_screen
    return Rect2(Vector2.ZERO, control.size).has_point(local_position)


func _start_window_drag() -> void:
    _state = DragState.DRAGGING
    get_viewport().set_input_as_handled()
    drag_started.emit()
    DisplayServer.window_start_drag(get_window().get_window_id())


func _process(_delta: float) -> void:
    if _state == DragState.IDLE:
        set_process(false)
        return

    # 原生拖窗或离开输入控件后，松开事件可能不再经过原来的事件入口。
    if (
        not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
        or (_gui_source != null and (
            not is_instance_valid(_gui_source) or not _gui_source.is_visible_in_tree()
        ))
    ):
        _finish_pointer_input()


func _finish_pointer_input() -> void:
    var was_dragging := _state == DragState.DRAGGING
    _state = DragState.IDLE
    _gui_source = null
    set_process(false)
    if was_dragging:
        drag_ended.emit()

#endregion
