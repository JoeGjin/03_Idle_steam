extends Button


# 拖拽开始与结束通知，保留供外部监听。
signal resize_started
signal resize_ended


# 缩放执行节点，以及相对基础窗口尺寸的倍率范围、拖拽灵敏度和平滑速度。
@export var all_output: Control
@export var min_scale := 0.2
@export var max_scale := 1.5
@export var resize_speed := 1.0
## 越高越紧跟鼠标，越低越平滑。用于吸收快速拖动时原生窗口的大跨度跳变。
@export_range(1.0, 60.0, 1.0, "or_greater") var resize_smoothing := 16.0


# 当前拖拽状态与 AllOutput 初始化后提供的基础窗口尺寸。
var _dragging := false
var _base_window_size := Vector2i.ZERO

# 鼠标屏幕坐标，以及拖拽开始时记录并传给 AllOutput 的窗口中心。
var _start_mouse_screen := Vector2i.ZERO
var _last_mouse_screen := Vector2i.ZERO
var _window_center_screen := Vector2.ZERO

# 本轮起始倍率、鼠标对应的目标倍率和平滑后的显示倍率。
var _start_scale := 1.0
var _target_scale := 1.0
var _display_scale := 1.0


# 本脚本响应缩放按钮拖拽，按全局鼠标位移计算倍率，再请求 AllOutput 应用窗口缩放。
# FloatButtonManager 通过 is_dragging 锁定按钮展开状态，避免缩放时按钮收回中断交互。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与缩放准备
#    初始关闭逐帧更新并忽略按钮输入，等待 AllOutput 布局完成后记录基础窗口尺寸。
#    禁用原生窗口的内容自动缩放，实际窗口尺寸与内容倍率交给 AllOutput 协调。
#    入口：_ready
# 2. 拖拽输入与状态切换
#    左键按下时记录屏幕位置与起始倍率并开启逐帧处理，松开时停止并发出对应通知。
#    按钮的输入接收由 FloatButtonManager 随展开状态控制。
#    入口：_gui_input / is_dragging；核心：_begin_resize / _finish_resize
# 3. 目标倍率计算与逐帧平滑
#    拖拽期间直接读取全局鼠标位置和左键状态，光标离开窗口后也能检测移动与松开。
#    将屏幕位移投影到基础窗口的半对角线，按灵敏度计算倍率增量并限制范围。
#    显示倍率平滑跟随目标后调用 AllOutput；接近目标时吸附，相同倍率时跳过更新。
#    核心：_process / _calculate_target_scale


#region 生命周期与缩放准备

func _ready() -> void:
    set_process(false)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    if all_output == null:
        push_error("[WindowResize] AllOutput 未设置")
        return

    while all_output.has_method("is_layout_ready") and not all_output.call("is_layout_ready"):
        await get_tree().process_frame

    get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    _base_window_size = all_output.call("get_base_window_size")

#endregion


#region 拖拽输入与状态切换

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _begin_resize()
        else:
            _finish_resize()
        accept_event()


func is_dragging() -> bool:
    return _dragging


func _begin_resize() -> void:
    if _dragging:
        return

    _dragging = true
    _start_mouse_screen = DisplayServer.mouse_get_position()
    _last_mouse_screen = _start_mouse_screen
    _window_center_screen = Vector2(get_window().position) + Vector2(get_window().size) * 0.5
    _start_scale = float(get_window().size.x) / float(_base_window_size.x)
    _target_scale = _start_scale
    _display_scale = _start_scale
    set_process(true)
    resize_started.emit()


func _finish_resize() -> void:
    if not _dragging:
        return

    _dragging = false
    set_process(false)
    resize_ended.emit()

#endregion


#region 目标倍率计算与逐帧平滑

func _process(delta: float) -> void:
    if not _dragging:
        return

    # GUI 事件可能在光标离开窗口后停止派发，因此拖拽期间直接读取全局鼠标。
    if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _finish_resize()
        return

    var mouse_screen := DisplayServer.mouse_get_position()
    if mouse_screen != _last_mouse_screen:
        _last_mouse_screen = mouse_screen
        _target_scale = _calculate_target_scale(mouse_screen)

    # 限制参与平滑的帧时长，减少长帧导致的倍率跳变。
    var smooth_weight := 1.0 - exp(-resize_smoothing * minf(delta, 1.0 / 30.0))
    var next_scale := lerpf(_display_scale, _target_scale, smooth_weight)
    if absf(next_scale - _target_scale) < 0.0001:
        next_scale = _target_scale
    if is_equal_approx(next_scale, _display_scale):
        return

    _display_scale = next_scale
    all_output.call("apply_window_scale", _display_scale, _window_center_screen)


func _calculate_target_scale(mouse_screen: Vector2i) -> float:
    if _base_window_size.x <= 0 or _base_window_size.y <= 0:
        return _start_scale

    var delta := Vector2(mouse_screen - _start_mouse_screen)
    var resize_axis := Vector2(_base_window_size) * 0.5
    var delta_scale := delta.dot(resize_axis) / resize_axis.length_squared() * resize_speed
    return clampf(_start_scale + delta_scale, min_scale, max_scale)

#endregion
