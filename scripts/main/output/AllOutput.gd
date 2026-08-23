extends Control


signal layout_ready(world_visual_rect: Rect2)


@export_group("Design Layout")
@export var design_size := Vector2(1600.0, 1200.0)
## WorldOutput 的 Shader 可见范围相对 design_size 垂直居中位置的偏移。
## 负值向上，正值向下；依附于椭圆范围的浮动按钮会一起移动。
@export_range(-600.0, 600.0, 1.0, "suffix:px") var world_vertical_offset := 0.0

@onready var world_output: TextureRect = %WorldOutput


var _initial_content_scale := 1.0
var _base_window_size := Vector2i.ZERO
var _world_visual_rect := Rect2()
var _layout_ready := false


func _ready() -> void:
    visible = true

    # 等待 Main._ready() 应用调试缩放，并让所有子节点完成初始化。
    await get_tree().process_frame
    _setup_fixed_layout()


func is_layout_ready() -> bool:
    return _layout_ready


func set_initial_window_scale(scale_value: float) -> void:
    _initial_content_scale = maxf(scale_value, 0.01)


func get_base_window_size() -> Vector2i:
    return _base_window_size


func get_world_visual_rect() -> Rect2:
    return _world_visual_rect


func is_point_in_world(point: Vector2) -> bool:
    if not _layout_ready:
        return false

    var shader_material := world_output.material as ShaderMaterial
    if shader_material == null:
        return _world_visual_rect.has_point(point)

    var output_rect := Rect2(world_output.position, world_output.size)
    var center := output_rect.position + Vector2(
        float(shader_material.get_shader_parameter("center_u")),
        float(shader_material.get_shader_parameter("center_v"))
    ) * output_rect.size
    var radius := Vector2(
        maxf(float(shader_material.get_shader_parameter("radius_u")), 0.0001),
        maxf(float(shader_material.get_shader_parameter("radius_v")), 0.0001)
    ) * output_rect.size

    var normalized := (point - center) / radius
    return normalized.length_squared() <= 1.0


func apply_window_scale(scale_value: float, _window_center: Vector2) -> void:
    if not _layout_ready:
        return

    var safe_scale := maxf(scale_value, 0.01)
    var physical_scale := _initial_content_scale * safe_scale
    var window := get_window()
    var new_window_size := Vector2i(
        maxi(1, roundi(design_size.x * physical_scale)),
        maxi(1, roundi(design_size.y * physical_scale))
    )
    if window.size != new_window_size:
        window.size = new_window_size
    scale = Vector2.ONE * physical_scale
    position = Vector2.ZERO


func _setup_fixed_layout() -> void:
    var window := get_window()
    var source_size := _get_world_source_size()

    var previous_center := Vector2(window.position) + Vector2(window.size) * 0.5

    set_anchors_preset(Control.PRESET_TOP_LEFT, true)
    size = design_size
    scale = Vector2.ONE * _initial_content_scale
    position = Vector2.ZERO

    world_output.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
    world_output.position = Vector2.ZERO
    world_output.size = source_size

    var source_fit_rect := _calculate_world_output_fit_rect()
    if source_fit_rect.size.x <= 0.0 or source_fit_rect.size.y <= 0.0:
        push_warning("[AllOutput] 无法计算 WorldOutput 可见范围，使用完整输出范围")
        source_fit_rect = Rect2(Vector2.ZERO, source_size)

    var world_offset := (
        design_size * 0.5
        - source_fit_rect.get_center()
        + Vector2(0.0, world_vertical_offset)
    )
    world_output.position = world_offset
    _world_visual_rect = Rect2(source_fit_rect.position + world_offset, source_fit_rect.size)

    _base_window_size = Vector2i(
        maxi(1, roundi(design_size.x * _initial_content_scale)),
        maxi(1, roundi(design_size.y * _initial_content_scale))
    )
    window.size = _base_window_size
    window.position = Vector2i(previous_center - Vector2(_base_window_size) * 0.5)

    _layout_ready = true
    layout_ready.emit(_world_visual_rect)


func _get_world_source_size() -> Vector2:
    if world_output.texture != null:
        var texture_size := Vector2(world_output.texture.get_size())
        if texture_size.x > 0.0 and texture_size.y > 0.0:
            return texture_size

    return Vector2(1920.0, 1080.0)


func _calculate_world_output_fit_rect() -> Rect2:
    var shader_material := world_output.material as ShaderMaterial
    if shader_material == null:
        return Rect2()

    var output_rect := Rect2(Vector2.ZERO, world_output.size)
    var center_uv := Vector2(
        float(shader_material.get_shader_parameter("center_u")),
        float(shader_material.get_shader_parameter("center_v"))
    )
    var radius_uv := Vector2(
        maxf(float(shader_material.get_shader_parameter("radius_u")), 0.0),
        maxf(float(shader_material.get_shader_parameter("radius_v")), 0.0)
    )

    var texture_size := _get_world_source_size()
    var px_to_uv := maxf(1.0 / texture_size.x, 1.0 / texture_size.y)
    var feather_px := maxf(float(shader_material.get_shader_parameter("feather_px")), 0.0)
    var smoke_enable := clampf(float(shader_material.get_shader_parameter("smoke_enable")), 0.0, 1.0)
    var smoke_amp_px := maxf(float(shader_material.get_shader_parameter("smoke_amp_px")), 0.0)
    var outer_distance := 1.0 + (feather_px + smoke_amp_px * smoke_enable) * px_to_uv

    var center := center_uv * output_rect.size
    var radius := radius_uv * output_rect.size * outer_distance
    var ellipse_rect := Rect2(center - radius, radius * 2.0)
    return ellipse_rect.intersection(output_rect)
