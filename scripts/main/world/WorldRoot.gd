extends Node2D

## 向 Blur 层同步经过 POI 动画倍率计算的实际 LOD。
signal lod_changed(value: float)

const POI_EMPHASIS_ANIMATION := &"PoiEmphasis"

@export_range(0.0, 10.0, 0.1) var lod: float = 0.5: # 基础模糊程度
	set(value):
		if lod == value:
			return
		lod = value
		lod_changed.emit(get_effective_lod())

@export_group("POI 镜头控制")
@export var poi_emphasis_enabled := true:
	set(value):
		poi_emphasis_enabled = value
		if _poi_emphasis_ready and not value:
			_reset_poi_emphasis()
## 使用未缩放的设计像素；窗口缩放不会改变保持区间。
@export_range(0.0, 900.0, 10.0, "suffix:px") var poi_hold_half_width := 400.0
## 越大越快跟随目标强度；用于消除 POI 更替和世界切换时的突变。
@export_range(0.1, 20.0, 0.1) var poi_emphasis_response := 5.0
## 相对可见范围的缩放锚点，允许超出 0～1；支持在 Remote Inspector 中实时调整。
@export var poi_zoom_anchor_ratio := Vector2(0.5, 0.925):
	set(value):
		poi_zoom_anchor_ratio = value
		_refresh_poi_zoom_anchor()
## 0 为普通镜头，1 为 dramatic 预设，2 继续加强缩放和位移；支持实时调整。
@export_range(0.0, 2.0, 0.01) var poi_dramatic_amount := 0.5:
	set(value):
		poi_dramatic_amount = value
		_refresh_poi_emphasis_configuration()
## -1 远景缩得多，0 各层缩放一致，1 近景缩得多；支持实时调整。
@export_range(-1.0, 1.0, 0.01) var poi_zoom_depth_bias := 1.0:
	set(value):
		poi_zoom_depth_bias = value
		_refresh_poi_emphasis_configuration()
## 额外位移的整体倍率；0 无额外位移，1 原效果，2 加倍。
@export_range(0.0, 2.0, 0.01) var poi_offset_strength := 1.0:
	set(value):
		poi_offset_strength = value
		_refresh_poi_emphasis_configuration()
## -1 反转各层 offset 差异，0 各层 offset 一致，1 保留原分布；支持实时调整。
@export_range(-1.0, 1.0, 0.01) var poi_offset_depth_bias := 1.0:
	set(value):
		poi_offset_depth_bias = value
		_refresh_poi_emphasis_configuration()
## 运行主场景后，在 Remote Inspector 中打开，可不等待 POI 测试镜头。
@export var poi_emphasis_preview := false
@export_range(0.0, 1.0, 0.01) var poi_preview_strength := 1.0

# WorldPlayer 的动画轨道驱动这些属性，不在 Inspector 中暴露。
var poi_lod_weight := 1.0:
	set(value):
		if poi_lod_weight == value:
			return
		poi_lod_weight = value
		lod_changed.emit(get_effective_lod())
var poi_camera_scale := 1.0
var poi_camera_offset := Vector2.ZERO
var poi_group_1_scale := 1.0
var poi_group_1_offset := Vector2.ZERO
var poi_group_2_scale := 1.0
var poi_group_2_offset := Vector2.ZERO
var poi_group_3_scale := 1.0
var poi_group_3_offset := Vector2.ZERO
var poi_group_4_scale := 1.0
var poi_group_4_offset := Vector2.ZERO
var poi_group_5_scale := 1.0
var poi_group_5_offset := Vector2.ZERO

@onready var _world_player: AnimationPlayer = $WorldPlayer
@onready var _poi: ManualParallax = %POI
@onready var _landform_4: ManualParallax = %Landform_4
@onready var _pet: AnimatedSprite2D = %Pet
@onready var _pet_layer: CanvasLayer = $"15_Pet"

var _poi_emphasis_ready := false
var _world_transitioning := false
var _poi_strength := 0.0
var _world_visible_rect := Rect2()
var _poi_zoom_anchor := Vector2.ZERO
# 原始动画只读，调参始终从它计算；WorldPlayer 只使用初始化时创建的副本。
var _poi_base_animation: Animation
var _poi_animation: Animation
var _camera_layers: Array[CanvasLayer] = []
var _layer_groups: Dictionary[CanvasLayer, int] = {}
var _layer_contents: Dictionary[CanvasLayer, ManualParallax] = {}
var _layer_base_transforms: Dictionary[CanvasLayer, Transform2D] = {}
var _layer_base_spawn_x: Dictionary[CanvasLayer, float] = {}
var _blur_base_positions: Dictionary[Control, Vector2] = {}
var _blur_base_scales: Dictionary[Control, Vector2] = {}
var _pet_base_transform := Transform2D.IDENTITY


func _ready() -> void:
	global_position = get_viewport().get_visible_rect().size * 0.5
	# 在 POI 移动和 Pet 贴地完成后更新显示变换。
	process_priority = maxi(_poi.process_priority, _pet.process_priority) + 1
	show()


func get_effective_lod() -> float:
	return lod * clampf(poi_lod_weight, 0.0, 1.0)


func initialize_poi_emphasis(visible_rect: Rect2) -> void:
	if not _world_player.has_animation(POI_EMPHASIS_ANIMATION):
		push_warning("[WorldRoot] WorldPlayer 缺少 PoiEmphasis 动画")
		return
	if not visible_rect.has_area():
		push_warning("[WorldRoot] POI 镜头需要有效的世界可见范围")
		return

	_world_visible_rect = visible_rect
	_refresh_poi_zoom_anchor()
	if not _initialize_poi_animation():
		return
	if not _configure_poi_emphasis_animation():
		return
	_capture_camera_layer(_poi, 0)
	for group_index: int in range(1, 6):
		for prefix: String in ["Cloud", "Landform", "Component"]:
			var content := get_node(NodePath("%%%s_%d" % [prefix, group_index])) as ManualParallax
			_capture_camera_layer(content, group_index)
	_pet_base_transform = _pet_layer.transform

	# 时间轴作为镜头强度使用，由位置采样；禁止它自行按时间播放。
	_world_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_poi_emphasis_ready = true
	_reset_poi_emphasis()


func _refresh_poi_emphasis_configuration() -> void:
	# 场景加载时 setter 也可能被调用，等可见范围和图层基准完成初始化后再刷新。
	if not _poi_emphasis_ready:
		return
	if not _configure_poi_emphasis_animation():
		return
	if not poi_emphasis_enabled:
		_reset_poi_emphasis()
		return
	# 重新生成关键帧后沿用当前强调进度，避免调参时镜头从头进入。
	_world_player.play(POI_EMPHASIS_ANIMATION)
	_sample_poi_emphasis(_poi_strength)
	_apply_poi_camera()


func _refresh_poi_zoom_anchor() -> void:
	if not _world_visible_rect.has_area():
		return
	_poi_zoom_anchor = _world_visible_rect.position + _world_visible_rect.size * poi_zoom_anchor_ratio
	if _poi_emphasis_ready and poi_emphasis_enabled:
		_apply_poi_camera()


func _initialize_poi_animation() -> bool:
	if _poi_animation != null:
		return true
	_poi_base_animation = _world_player.get_animation(POI_EMPHASIS_ANIMATION)
	var properties: Array[String] = ["poi_lod_weight"]
	for group_index: int in range(6):
		var prefix := "poi_camera" if group_index == 0 else "poi_group_%d" % group_index
		properties.append(prefix + "_scale")
		properties.append(prefix + "_offset")
	for property: String in properties:
		var track := _find_poi_camera_track(_poi_base_animation, property)
		if track < 0:
			return false
		var target_value: Variant = _poi_base_animation.track_get_key_value(track, 1)
		var valid_type := target_value is Vector2 if property.ends_with("_offset") else (
			target_value is float or target_value is int
		)
		if not valid_type:
			push_warning("[WorldRoot] PoiEmphasis 的 %s 轨道终点类型不正确" % property)
			return false

	# 动画库只复制一次；保留场景中的原始关键帧、轨道曲线和 RESET。
	var library := _world_player.get_animation_library(&"").duplicate() as AnimationLibrary
	_poi_animation = _poi_base_animation.duplicate(true) as Animation
	library.remove_animation(POI_EMPHASIS_ANIMATION)
	library.add_animation(POI_EMPHASIS_ANIMATION, _poi_animation)
	_world_player.remove_animation_library(&"")
	_world_player.add_animation_library(&"", library)
	return true


func _get_poi_base_value(property: String) -> Variant:
	var track := _poi_base_animation.find_track(NodePath(".:" + property), Animation.TYPE_VALUE)
	return _poi_base_animation.track_get_key_value(track, 1)


func _configure_poi_emphasis_animation() -> bool:
	var amount := clampf(poi_dramatic_amount, 0.0, 2.0)
	var depth_bias := clampf(poi_zoom_depth_bias, -1.0, 1.0)
	var offset_strength := clampf(poi_offset_strength, 0.0, 2.0)
	var offset_depth_bias := clampf(poi_offset_depth_bias, -1.0, 1.0)
	# 以最远和最近 group 的缩放中点为共同值，反转层次时保持相同的缩放范围。
	var uniform_scale := (
		float(_get_poi_base_value("poi_group_1_scale"))
		+ float(_get_poi_base_value("poi_group_5_scale"))
	) * 0.5
	# 对额外位移调节层次，保证 bias 为 0 时各层额外位移一致。
	var uniform_offset: Vector2 = (
		_get_poi_base_value("poi_group_1_offset") + _get_poi_base_value("poi_group_5_offset")
	) * 0.5
	for group_index: int in range(6):
		var property_prefix := "poi_camera" if group_index == 0 else "poi_group_%d" % group_index
		var base_scale: float = _get_poi_base_value(property_prefix + "_scale")
		var base_offset: Vector2 = _get_poi_base_value(property_prefix + "_offset")
		var depth_scale := uniform_scale + (base_scale - uniform_scale) * depth_bias
		# 超过 1 时继续外推，最低缩放与显示变换一致，避免归零或翻转。
		var camera_scale := maxf(lerpf(1.0, depth_scale, amount), 0.05)
		var camera_offset := (
			uniform_offset + (base_offset - uniform_offset) * offset_depth_bias
		) * amount * offset_strength
		if not _set_poi_camera_keys(_poi_animation, property_prefix + "_scale", 1.0, camera_scale):
			return false
		if not _set_poi_camera_keys(_poi_animation, property_prefix + "_offset", Vector2.ZERO, camera_offset):
			return false

	# 倍率随同一镜头进度从 1 降到 0，离开保持区间时反向采样恢复基础 LOD。
	if not _set_poi_camera_keys(_poi_animation, "poi_lod_weight", 1.0, 0.0):
		return false
	return true


func _set_poi_camera_keys(
	animation: Animation, property: String, normal_value: Variant, target_value: Variant
) -> bool:
	var track := _find_poi_camera_track(animation, property)
	if track < 0:
		return false
	animation.track_set_key_value(track, 0, normal_value)
	animation.track_set_key_value(track, 1, target_value)
	return true


func _find_poi_camera_track(animation: Animation, property: String) -> int:
	var track := animation.find_track(NodePath(".:" + property), Animation.TYPE_VALUE)
	if track < 0 or animation.track_get_key_count(track) != 2:
		push_warning("[WorldRoot] PoiEmphasis 的 %s 轨道需要起点和终点两个关键帧" % property)
		return -1
	return track


func set_poi_emphasis_transitioning(active: bool) -> void:
	_world_transitioning = active


func _process(delta: float) -> void:
	if not _poi_emphasis_ready or not poi_emphasis_enabled:
		return

	var target_strength := 0.0
	if not _world_transitioning:
		if poi_emphasis_preview:
			target_strength = clampf(poi_preview_strength, 0.0, 1.0)
		else:
			target_strength = _get_poi_target_strength()

	var response_weight := 1.0 - exp(-maxf(poi_emphasis_response, 0.1) * delta)
	_poi_strength = lerpf(_poi_strength, target_strength, response_weight)
	if absf(_poi_strength - target_strength) < 0.0001:
		_poi_strength = target_strength
	_sample_poi_emphasis(_poi_strength)
	_apply_poi_camera()


func _capture_camera_layer(content: ManualParallax, group_index: int) -> void:
	var layer := content.get_parent() as CanvasLayer
	_camera_layers.append(layer)
	_layer_groups[layer] = group_index
	_layer_contents[layer] = content
	_layer_base_transforms[layer] = layer.transform
	_layer_base_spawn_x[layer] = content.spawn_position.x
	var blur := layer.get_node_or_null("Blur") as Control
	if blur != null:
		_blur_base_positions[blur] = blur.position
		_blur_base_scales[blur] = blur.scale


func _get_poi_target_strength() -> float:
	var target_strength := 0.0
	var center_x := _world_visible_rect.get_center().x
	# 为窄画面保留过渡区间，避免保持范围占满整个窗口。
	var half_hold := clampf(poi_hold_half_width, 0.0, _world_visible_rect.size.x * 0.45)
	for child in _poi.get_children():
		var object := child as MparaObject
		if (
			object == null
			or object.is_queued_for_deletion()
			or object.memory_def == null
			or object.texture == null
			or object.modulate.a <= 0.001
		):
			continue

		# global_transform 不含 CanvasLayer 镜头变换，判断不会受拉远反向影响。
		var object_rect := Rect2(
			object.global_position,
			Vector2(object.texture.get_size()) * object.global_scale.abs()
		)
		if not object_rect.intersects(_world_visible_rect):
			continue
		var object_center := object_rect.get_center().x
		var half_width := object_rect.size.x * 0.5
		var strength := 1.0
		if object_center > center_x + half_hold:
			var enter_center := _world_visible_rect.end.x + half_width
			var enter_span := maxf(enter_center - center_x - half_hold, 1.0)
			strength = (enter_center - object_center) / enter_span
		elif object_center < center_x - half_hold:
			var exit_center := _world_visible_rect.position.x - half_width
			var exit_span := maxf(center_x - half_hold - exit_center, 1.0)
			strength = (object_center - exit_center) / exit_span
		# 重叠 POI 共用最强的镜头需求，不让多个对象分别覆盖时间轴。
		target_strength = maxf(target_strength, clampf(strength, 0.0, 1.0))
	return target_strength


func _sample_poi_emphasis(strength: float) -> void:
	if _world_player.assigned_animation != POI_EMPHASIS_ANIMATION:
		_world_player.play(POI_EMPHASIS_ANIMATION)
	_world_player.seek(clampf(strength, 0.0, 1.0) * _poi_animation.length, true, true)


func _apply_poi_camera() -> void:
	var scales: Array[float] = [
		poi_camera_scale, poi_group_1_scale, poi_group_2_scale,
		poi_group_3_scale, poi_group_4_scale, poi_group_5_scale,
	]
	var offsets: Array[Vector2] = [
		poi_camera_offset, poi_group_1_offset, poi_group_2_offset,
		poi_group_3_offset, poi_group_4_offset, poi_group_5_offset,
	]
	for layer: CanvasLayer in _camera_layers:
		var group_index: int = _layer_groups[layer]
		var camera_scale := maxf(scales[group_index], 0.05)
		var camera_transform := Transform2D.IDENTITY.scaled(Vector2.ONE * camera_scale)
		camera_transform.origin = _poi_zoom_anchor * (1.0 - camera_scale) + offsets[group_index]
		layer.transform = camera_transform * _layer_base_transforms[layer]

		# 拉远后可见范围变大，生成线也要留在原来的窗口外，避免素材突然冒出。
		var content: ManualParallax = _layer_contents[layer]
		var original_spawn := content.to_global(Vector2(
			_layer_base_spawn_x[layer], content.spawn_position.y
		))
		var spawn_in_canvas := layer.transform.affine_inverse() * (
			_layer_base_transforms[layer] * original_spawn
		)
		content.spawn_position.x = maxf(
			_layer_base_spawn_x[layer], content.to_local(spawn_in_canvas).x
		)

		# Blur 是全屏后处理，逆向补偿镜头，保持它原来的屏幕覆盖范围。
		var blur := layer.get_node_or_null("Blur") as Control
		if blur != null:
			var original_origin: Vector2 = _layer_base_transforms[layer] * _blur_base_positions[blur]
			blur.position = layer.transform.affine_inverse() * original_origin
			blur.scale = _blur_base_scales[blur] / camera_scale
	# Pet 与 group 4 共用镜头变换，贴地仍由 Pet.gd 在原始世界坐标中处理。
	var group_4_layer := _landform_4.get_parent() as CanvasLayer
	var group_4_base: Transform2D = _layer_base_transforms[group_4_layer]
	_pet_layer.transform = group_4_layer.transform * group_4_base.affine_inverse() * _pet_base_transform


func _reset_poi_emphasis() -> void:
	_poi_strength = 0.0
	_world_player.play(&"RESET")
	_world_player.seek(0.0, true, true)
	_world_player.pause()
	for layer: CanvasLayer in _camera_layers:
		layer.transform = _layer_base_transforms[layer]
		_layer_contents[layer].spawn_position.x = _layer_base_spawn_x[layer]
		var blur := layer.get_node_or_null("Blur") as Control
		if blur != null:
			blur.position = _blur_base_positions[blur]
			blur.scale = _blur_base_scales[blur]
	_pet_layer.transform = _pet_base_transform
