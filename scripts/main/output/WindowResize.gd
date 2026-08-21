extends Button


signal resize_started
signal resize_ended


@export var all_output: Control
@export var min_scale := 0.2
@export var max_scale := 1.5
@export var resize_speed := 1.0
## 越高越紧跟鼠标，越低越平滑。用于吸收快速拖动时原生窗口的大跨度跳变。
@export_range(1.0, 60.0, 1.0, "or_greater") var resize_smoothing := 16.0


var _dragging := false
var _base_window_size := Vector2i.ZERO
var _start_mouse_screen := Vector2i.ZERO
var _last_mouse_screen := Vector2i.ZERO
var _window_center_screen := Vector2.ZERO
var _start_scale := 1.0
var _target_scale := 1.0
var _display_scale := 1.0


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

    var smooth_weight := 1.0 - exp(-resize_smoothing * minf(delta, 1.0 / 30.0))
    var next_scale := lerpf(_display_scale, _target_scale, smooth_weight)
    if absf(next_scale - _target_scale) < 0.0001:
        next_scale = _target_scale
    if is_equal_approx(next_scale, _display_scale):
        return

    _display_scale = next_scale
    all_output.call("apply_window_scale", _display_scale, _window_center_screen)


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


func _calculate_target_scale(mouse_screen: Vector2i) -> float:
    if _base_window_size.x <= 0 or _base_window_size.y <= 0:
        return _start_scale

    var delta := Vector2(mouse_screen - _start_mouse_screen)
    var resize_axis := Vector2(_base_window_size) * 0.5
    var delta_scale := delta.dot(resize_axis) / resize_axis.length_squared() * resize_speed
    return clampf(_start_scale + delta_scale, min_scale, max_scale)
