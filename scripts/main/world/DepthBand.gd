extends Node


## 按原绘制顺序中连续的一段分组，保留 CanvasLayer 与内容节点的父子关系。
@export var source_layers: Array[CanvasLayer] = []
@export var enabled := true:
    set(value):
        enabled = value
        if _initialized:
            _apply_enabled()
## 各组独立的基础 LOD；0 表示保留本组原图。
@export_range(0.0, 5.0, 0.1) var blur_lod: float = 1.5:
    set(value):
        blur_lod = clampf(value, 0.0, 5.0)
        if _initialized:
            _update_blur()
## 合成层级应位于本组占用的原始绘制区间内，避免改变跨组遮挡关系。
@export var composite_layer: int = 1:
    set(value):
        composite_layer = value
        if _initialized:
            _composite_layer.layer = composite_layer
## POI 动画只提供清晰化倍率，各组保留独立的基础强度。
@export var follow_poi_blur_weight := true:
    set(value):
        follow_poi_blur_weight = value
        if _initialized:
            _update_blur()


@onready var _view: SubViewport = $View
@onready var _post_process_layer: CanvasLayer = $View/PostProcess
@onready var _blur: ColorRect = $View/PostProcess/Blur
@onready var _composite_layer: CanvasLayer = $Composite
@onready var _output: TextureRect = $Composite/Output


var _world_view: SubViewport
var _blur_material: ShaderMaterial
var _poi_blur_weight := 1.0
var _initialized := false


# Main 在 WorldRoot 进入 WorldView 后调用，避免 reparent 改变视口归属。
func initialize(world_view: SubViewport, world_root: Node) -> void:
    if _initialized:
        return
    if source_layers.is_empty():
        push_error("[DepthBand] %s 未配置 source_layers" % name)
        return
    for layer: CanvasLayer in source_layers:
        if layer == null:
            push_error("[DepthBand] %s 的 source_layers 包含失效节点" % name)
            return

    _world_view = world_view
    # 隔离默认 2D 画布；只有显式指定 custom_viewport 的源图层进入此视口。
    _view.world_2d = World2D.new()
    _view.use_hdr_2d = _world_view.use_hdr_2d
    var last_source_layer := source_layers[0].layer
    for layer: CanvasLayer in source_layers:
        last_source_layer = maxi(last_source_layer, layer.layer)
    _post_process_layer.layer = last_source_layer + 1
    _composite_layer.custom_viewport = _world_view
    _composite_layer.layer = composite_layer
    _output.texture = _view.get_texture()
    _blur_material = _blur.material.duplicate() as ShaderMaterial
    _blur.material = _blur_material

    _world_view.size_changed.connect(_sync_size)
    _poi_blur_weight = clampf(float(world_root.get("poi_blur_weight")), 0.0, 1.0)
    world_root.connect("blur_weight_changed", _on_blur_weight_changed)
    _initialized = true
    _sync_size()
    _update_blur()
    _apply_enabled()


func _sync_size() -> void:
    # 始终使用 WorldView 的设计像素，窗口缩放由现有 AllOutput 统一处理。
    _view.size = _world_view.size
    var source_size := Vector2(_world_view.size)
    _blur.position = Vector2.ZERO
    _blur.size = source_size
    _output.position = Vector2.ZERO
    _output.size = source_size


func _apply_enabled() -> void:
    for layer: CanvasLayer in source_layers:
        layer.custom_viewport = _view if enabled else _world_view

    # 合成层保持固定变换：各源图层已经执行了自己的 POI 镜头变换。
    _composite_layer.visible = enabled
    _view.render_target_update_mode = (
        SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
    )


func _on_blur_weight_changed(weight: float) -> void:
    _poi_blur_weight = clampf(weight, 0.0, 1.0)
    _update_blur()


func _update_blur() -> void:
    var poi_weight := 1.0
    if follow_poi_blur_weight:
        poi_weight = _poi_blur_weight
    var effective_lod := blur_lod * poi_weight
    _blur_material.set_shader_parameter("lod", effective_lod)
    # LOD 为 0 时直接输出本组原图，也省去屏幕拷贝和 mipmap 生成。
    _post_process_layer.visible = effective_lod > 0.0
