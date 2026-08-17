extends Control


signal window_fit_completed


@onready var world_output: TextureRect = %WorldOutput
@onready var float_buttons: Control = get_node_or_null("FloatButtons") as Control


var _base_content_size := Vector2.ZERO
var _base_fit_rect := Rect2()
var _window_fit_ready := false




func _ready() -> void:
    visible = true

    # 子节点和 Main._ready() 完成后再读取最终布局与 shader 参数。
    await get_tree().process_frame
    _fit_native_window_to_world_output()


func is_window_fit_ready() -> bool:
    return _window_fit_ready


func apply_window_scale(scale_value: float) -> void:
    if not _window_fit_ready:
        return

    var safe_scale := maxf(scale_value, 0.01)
    var window := get_window()

    window.size = Vector2i(
        maxi(1, roundi(_base_fit_rect.size.x * safe_scale)),
        maxi(1, roundi(_base_fit_rect.size.y * safe_scale))
    )

    # 内容保留初始化时的坐标系，只缩放并偏移到椭圆裁剪框内。
    scale = Vector2.ONE * safe_scale
    position = -_base_fit_rect.position * safe_scale


func _fit_native_window_to_world_output() -> void:
    _base_content_size = size

    # 解除对根 Viewport 的全窗口锚定，避免原生窗口缩小时内容也被压缩。
    set_anchors_preset(Control.PRESET_TOP_LEFT, true)
    size = _base_content_size
    scale = Vector2.ONE

    var fit_rect := _calculate_world_output_fit_rect()
    if fit_rect.size.x <= 0.0 or fit_rect.size.y <= 0.0:
        push_warning("[AllOutput] WorldOutput 椭圆范围无效，保留当前窗口大小")
        _base_fit_rect = Rect2(Vector2.ZERO, _base_content_size)
        _finish_window_fit()
        return

    var fit_start := Vector2(floorf(fit_rect.position.x), floorf(fit_rect.position.y))
    var fit_end := Vector2(ceilf(fit_rect.end.x), ceilf(fit_rect.end.y))
    _base_fit_rect = Rect2(fit_start, fit_end - fit_start)

    var window := get_window()
    var fit_offset := Vector2i(roundi(fit_start.x), roundi(fit_start.y))

    # 同步移动窗口与内部内容，保证裁剪前后的椭圆保持在桌面同一位置。
    window.position += fit_offset
    window.size = Vector2i(
        maxi(1, roundi(_base_fit_rect.size.x)),
        maxi(1, roundi(_base_fit_rect.size.y))
    )
    position = -fit_start
    _fit_float_buttons_to_window()

    _finish_window_fit()


func _calculate_world_output_fit_rect() -> Rect2:
    var shader_material := world_output.material as ShaderMaterial
    if shader_material == null:
        push_warning("[AllOutput] WorldOutput 没有 ShaderMaterial，无法计算椭圆范围")
        return Rect2()

    var output_rect := Rect2(world_output.position, world_output.size)
    if output_rect.size.x <= 0.0 or output_rect.size.y <= 0.0:
        return Rect2()

    var center_uv := Vector2(
        float(shader_material.get_shader_parameter("center_u")),
        float(shader_material.get_shader_parameter("center_v"))
    )
    var radius_uv := Vector2(
        maxf(float(shader_material.get_shader_parameter("radius_u")), 0.0),
        maxf(float(shader_material.get_shader_parameter("radius_v")), 0.0)
    )

    var texture_size := output_rect.size
    if world_output.texture != null:
        var source_size := Vector2(world_output.texture.get_size())
        if source_size.x > 0.0 and source_size.y > 0.0:
            texture_size = source_size

    # 与 MaskGroup.gdshader 的像素转 UV 方式保持一致，并保守包含羽化和烟雾外扩。
    var px_to_uv := maxf(1.0 / texture_size.x, 1.0 / texture_size.y)
    var feather_px := maxf(float(shader_material.get_shader_parameter("feather_px")), 0.0)
    var smoke_enable := clampf(float(shader_material.get_shader_parameter("smoke_enable")), 0.0, 1.0)
    var smoke_amp_px := maxf(float(shader_material.get_shader_parameter("smoke_amp_px")), 0.0)
    var outer_distance := 1.0 + (feather_px + smoke_amp_px * smoke_enable) * px_to_uv

    var center := output_rect.position + center_uv * output_rect.size
    var radius := radius_uv * output_rect.size * outer_distance
    var ellipse_rect := Rect2(center - radius, radius * 2.0)

    # Shader 只能在 WorldOutput 自身范围内绘制，窗口无需保留其外部区域。
    return ellipse_rect.intersection(output_rect)


func _fit_float_buttons_to_window() -> void:
    if float_buttons == null:
        return

    # WorldOutput 保留原始坐标系；按钮容器单独对齐裁剪框，确保角落按钮仍可见。
    float_buttons.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
    float_buttons.position = _base_fit_rect.position
    float_buttons.size = _base_fit_rect.size


func _finish_window_fit() -> void:
    _window_fit_ready = true
    window_fit_completed.emit()
