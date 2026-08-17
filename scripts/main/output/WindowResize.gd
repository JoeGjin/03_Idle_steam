extends Button

@export var all_output: Control

@export var min_scale := 0.2
@export var max_scale := 1.5
@export var resize_speed := 1.0

var _dragging := false

var _base_window_size: Vector2i
var _start_mouse_screen: Vector2i
var _start_scale := 1.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

    if all_output == null:
        push_error("AllOutput node is not assigned in WindowResize.gd")
        return

    await get_tree().process_frame

    get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

    # AllOutput 会在完整场景 ready 后裁剪原生窗口；缩放基准必须等待裁剪完成。
    while all_output.has_method("is_window_fit_ready") and not all_output.call("is_window_fit_ready"):
        await get_tree().process_frame

    _base_window_size = get_window().size

    # 兼容未启用窗口裁剪的其他场景。
    if not all_output.has_method("apply_window_scale"):
        all_output.scale = Vector2.ONE
        all_output.position = Vector2.ZERO
        all_output.size = Vector2(_base_window_size)


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _dragging = true
            _start_mouse_screen = DisplayServer.mouse_get_position()
            _start_scale = float(get_window().size.x) / float(_base_window_size.x)
            accept_event()
        else:
            _dragging = false
            accept_event()

    elif event is InputEventMouseMotion and _dragging:
        var mouse_screen := DisplayServer.mouse_get_position()
        var delta := mouse_screen - _start_mouse_screen

        var delta_scale_x : float = float(delta.x) / float(_base_window_size.x)
        var delta_scale_y : float = float(delta.y) / float(_base_window_size.y)

        var delta_scale : float = max(delta_scale_x, delta_scale_y) * resize_speed
        var new_scale : float = clampf(_start_scale + delta_scale, min_scale, max_scale)

        _apply_window_scale(new_scale)

        accept_event()


func _apply_window_scale(scale_value: float) -> void:
    if all_output.has_method("apply_window_scale"):
        all_output.call("apply_window_scale", scale_value)
        return

    var window := get_window()

    var new_window_size := Vector2i(
        roundi(_base_window_size.x * scale_value),
        roundi(_base_window_size.y * scale_value)
    )

    window.size = new_window_size

    # 关键：AllOutput 不 scale，只同步到窗口大小
    all_output.scale = Vector2.ONE
    all_output.position = Vector2.ZERO
    all_output.size = Vector2(new_window_size)
