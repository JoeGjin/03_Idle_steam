extends Node


# 转发按钮请求，由 Main 或其他调用方决定具体流程。
signal setting_requested
signal collection_requested
signal minimode_requested
signal collected_item_requested


# 悬浮组的三个展示状态：收起、部分露出、完全展开。
enum RevealState {
	HIDDEN,
	PEEK,
	OPEN,
}


# 索引对应 _floating_controls：Setting、Collection、Zooming、Minimode。
const ZOOMING_INDEX := 2
const COLLECTION_INDEX := 1
# 待领取按钮在最低收集次数时的缩放比例。
const COLLECTED_ITEM_MIN_SCALE_RATIO := 0.6


# 布局来源、四角按钮与独立的待领取按钮。
@export var all_output: Control
@export var setting_button: Button
@export var collection_button: Button
@export var zooming_button: Button
@export var minimode_button: Button
@export var collected_item_button: Button

@export_group("Reveal State")
## 相对椭圆边缘向外的距离；负值会让按钮收进 WorldOutput 后方。
@export_range(-240.0, 240.0, 1.0, "suffix:px") var hidden_offset := -90.0
@export_range(-240.0, 240.0, 1.0, "suffix:px") var peek_offset := -42.0
@export_range(-240.0, 240.0, 1.0, "suffix:px") var open_offset := 70.0

@export_group("Button Size")
## 统一缩放四角按钮与 CollectedItem，包括文字和样式。
@export_range(0.25, 3.0, 0.05, "or_greater") var button_size_scale := 1.0

@export_group("Memory Popup")
## 二选一弹窗相对游戏显示倍率的额外大小倍率，包含卡片、间距与动画；下次打开时生效。
@export_range(0.25, 3.0, 0.05, "or_greater") var memory_popup_size_scale := 1.0

@export_group("Animation")
@export var move_duration := 0.22
@export var leave_delay := 0.2

# 四角按钮与参与三态显隐的控件组。
var _corner_buttons: Array[Button] = []
var _floating_controls: Array[Control] = []

# 各控件对应的展开方向，与 _floating_controls 保持相同索引。
var _directions: Array[Vector2] = [
	Vector2(-1.0, -1.0).normalized(),
	Vector2(1.0, -1.0).normalized(),
	Vector2(1.0, 1.0).normalized(),
	Vector2(-1.0, 1.0).normalized(),
]

# 设计坐标中的边缘锚点、当前显隐状态和移动 Tween。
var _anchors: Array[Vector2] = []
var _states: Array[int] = []
var _move_tweens: Array = []

# 初始化、离开延迟与收集聚焦的计时状态。
var _outside_time := 0.0
var _ready_for_input := false
var _collection_attention_time := 0.0

# 独立收集按钮动画、二选一与 mini 模式锁定状态。
var _collected_item_tween: Tween
var _memory_choice_active := false
var _mini_mode_active := false


# 本脚本管理世界周围的悬浮控件与待领取按钮，并转发按钮请求。
# AllOutput 提供设计坐标与世界范围；Main 驱动收集反馈和二选一锁定；Zooming 提供拖拽状态。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与按钮布局
#    校验引用、建立控件分组并连接信号，等待 AllOutput 布局完成后初始化锚点、尺寸与位置。
#    四角按钮共用三态布局；CollectedItem 在世界上沿单独定位。
#    核心：_ready / _validate_targets / _setup_button_layout / _get_target_position
# 2. 每帧显隐决策与移动动画
#    二选一或 mini 模式锁定期间跳过更新；优先处理收集聚焦，再处理缩放拖拽，最后处理世界区域与按钮悬停。
#    鼠标离开后按 leave_delay 收起；PEEK 由 Manager 判断命中，展开按钮才接收自身输入。
#    状态变化时替换对应移动 Tween。
#    核心：_process / _set_all_states / _set_button_state
# 3. 待领取按钮显隐与数量反馈
#    按累计次数更新文本和缩放，通过独立 Tween 控制出现、数量变化与隐藏。
#    此按钮不参与悬浮组的三态移动。
#    入口：show_collected_item / hide_collected_item；核心：_kill_collected_item_tween
# 4. 收集聚焦与特效目标查询
#    限时展开 Collection，并提供完全展开位置的屏幕中心，供收集烟花确定收束点。
#    入口：focus_collection / get_collection_open_screen_center
# 5. 二选一大小与模式锁定
#    提供叠加主窗口显示倍率与 memory_popup_size_scale 后的二选一弹窗倍率。
#    二选一期间停止悬浮移动并隐藏悬浮组，禁用按钮；结束后恢复四角按钮。
#    mini 模式冻结当前位置并锁住输入，透明度交给转换动画，待领取数量仍可更新。
#    入口：get_memory_popup_scale / set_memory_choice_active / set_mini_mode_active
# 6. 鼠标坐标、悬停与缩放拖拽检测
#    将全局鼠标转换为 AllOutput 设计坐标，按控件缩放后的矩形检测悬停，并查询 Zooming 状态。
#    核心：_get_all_output_mouse_position / _find_hovered_button / _is_zooming_dragging


#region 生命周期与按钮布局

func _ready() -> void:
	if not _validate_targets():
		set_process(false)
		return

	_corner_buttons = [
		setting_button,
		collection_button,
		zooming_button,
		minimode_button,
	]
	for button: Button in _corner_buttons:
		_floating_controls.append(button)

	setting_button.pressed.connect(setting_requested.emit)
	collection_button.pressed.connect(collection_requested.emit)
	minimode_button.pressed.connect(minimode_requested.emit)
	collected_item_button.pressed.connect(collected_item_requested.emit)
	collected_item_button.hide()

	while all_output.has_method("is_layout_ready") and not all_output.call("is_layout_ready"):
		await get_tree().process_frame

	_setup_button_layout()
	_ready_for_input = true


func _validate_targets() -> bool:
	if all_output == null:
		push_error("[FloatButtons] AllOutput 未设置")
		return false

	var buttons := [
		setting_button,
		collection_button,
		zooming_button,
		minimode_button,
		collected_item_button,
	]
	for button in buttons:
		if button == null:
			push_error("[FloatButtons] 按钮节点未完整设置")
			return false

	return true


func _setup_button_layout() -> void:
	var world_rect: Rect2 = all_output.call("get_world_visual_rect")
	var center := world_rect.get_center()
	var radius := world_rect.size * 0.5

	_anchors.clear()
	_states.clear()
	_move_tweens.clear()

	for index in _floating_controls.size():
		var direction := _directions[index]
		var anchor := center + radius * direction
		_anchors.append(anchor)
		_states.append(RevealState.HIDDEN)
		_move_tweens.append(null)

		var control := _floating_controls[index]
		control.pivot_offset = control.size * 0.5
		control.scale = Vector2.ONE * button_size_scale
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.position = _get_target_position(index, RevealState.HIDDEN)

	collected_item_button.pivot_offset = collected_item_button.size * 0.5
	collected_item_button.scale = Vector2.ONE * button_size_scale
	collected_item_button.position = Vector2(
		center.x - collected_item_button.size.x * 0.5,
		world_rect.position.y - collected_item_button.size.y * 0.01
	)


func _get_target_position(index: int, state: int) -> Vector2:
	var offset := hidden_offset
	match state:
		RevealState.PEEK:
			offset = peek_offset
		RevealState.OPEN:
			offset = open_offset

	var control := _floating_controls[index]
	var center := _anchors[index] + _directions[index] * offset
	return center - control.size * 0.5

#endregion


#region 每帧显隐决策与移动动画

func _process(delta: float) -> void:
	if not _ready_for_input:
		return
	if _memory_choice_active or _mini_mode_active:
		return

	if _collection_attention_time > 0.0:
		_collection_attention_time = maxf(_collection_attention_time - delta, 0.0)
		for index in _corner_buttons.size():
			_set_button_state(
				index,
				RevealState.OPEN if index == COLLECTION_INDEX else RevealState.PEEK
			)
		if _collection_attention_time > 0.0:
			return

	# 缩放依赖窗口外的全局鼠标位置。拖拽期间锁住按钮，避免窗口尺寸变化后
	# 本地命中区域离开鼠标，导致 Zooming 收回并中断交互。
	if _is_zooming_dragging():
		_outside_time = 0.0
		for index in _floating_controls.size():
			var target_state := RevealState.OPEN if index == ZOOMING_INDEX else RevealState.PEEK
			_set_button_state(index, target_state)
		return

	var mouse_position := _get_all_output_mouse_position()
	var mouse_over_world := bool(all_output.call("is_point_in_world", mouse_position))
	var hovered_index := _find_hovered_button(mouse_position)

	if mouse_over_world:
		_outside_time = 0.0
		_set_all_states(RevealState.PEEK)
		return

	if hovered_index >= 0:
		_outside_time = 0.0
		for index in _floating_controls.size():
			var target_state := RevealState.OPEN if index == hovered_index else RevealState.PEEK
			_set_button_state(index, target_state)
		return

	_outside_time += delta
	if _outside_time >= leave_delay:
		_set_all_states(RevealState.HIDDEN)


func _set_all_states(state: int) -> void:
	for index in _floating_controls.size():
		_set_button_state(index, state)


func _set_button_state(index: int, state: int) -> void:
	if index == ZOOMING_INDEX and _is_zooming_dragging():
		state = RevealState.OPEN

	var control := _floating_controls[index]

	# PEEK 时只由 Manager 检测外露区域，避免按钮在 WorldOutput 内部抢占输入。
	control.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if state == RevealState.OPEN
		else Control.MOUSE_FILTER_IGNORE
	)

	if _states[index] == state:
		return

	_states[index] = state
	var old_tween :Tween = _move_tweens[index]
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "position", _get_target_position(index, state), move_duration)
	_move_tweens[index] = tween

#endregion


#region 待领取按钮显隐与数量反馈

func show_collected_item(count: int = 1, max_count: int = 5) -> void:
	if collected_item_button == null:
		return

	var safe_max_count := maxi(max_count, 1)
	var safe_count := clampi(count, 0, safe_max_count)
	if safe_count <= 0:
		hide_collected_item()
		return

	var count_ratio := 1.0
	if safe_max_count > 1:
		count_ratio = float(safe_count - 1) / float(safe_max_count - 1)
	var size_ratio := lerpf(COLLECTED_ITEM_MIN_SCALE_RATIO, 1.0, count_ratio)
	var target_scale := Vector2.ONE * button_size_scale * size_ratio
	var was_visible := collected_item_button.visible

	collected_item_button.text = "Memory" if safe_count <= 1 else "Memory ×%d" % safe_count
	collected_item_button.show()
	_kill_collected_item_tween()

	_collected_item_tween = create_tween().set_parallel(true)
	_collected_item_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not was_visible:
		collected_item_button.modulate.a = 0.0
		collected_item_button.scale = target_scale * 0.75
		_collected_item_tween.tween_property(collected_item_button, "modulate:a", 1.0, 0.25)
	else:
		collected_item_button.modulate.a = 1.0

	_collected_item_tween.tween_property(
		collected_item_button,
		"scale",
		target_scale,
		0.32
	)


func hide_collected_item() -> void:
	if collected_item_button == null or not collected_item_button.visible:
		return

	_kill_collected_item_tween()
	_collected_item_tween = create_tween().set_parallel(true)
	_collected_item_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_collected_item_tween.tween_property(collected_item_button, "modulate:a", 0.0, 0.18)
	_collected_item_tween.tween_property(
		collected_item_button,
		"scale",
		collected_item_button.scale * 0.8,
		0.18
	)
	_collected_item_tween.chain().tween_callback(collected_item_button.hide)


func _kill_collected_item_tween() -> void:
	if _collected_item_tween != null and _collected_item_tween.is_valid():
		_collected_item_tween.kill()

#endregion


#region 收集聚焦与特效目标查询

## 收集特效播放时固定展示 Collection，确保粒子的收束点始终与按钮一致。
func focus_collection(duration: float) -> void:
	if not _ready_for_input:
		return

	_collection_attention_time = maxf(duration, 0.0)
	_set_button_state(COLLECTION_INDEX, RevealState.OPEN)


func get_collection_open_screen_center() -> Vector2:
	var button_parent := collection_button.get_parent() as CanvasItem
	var open_center := (
		_get_target_position(COLLECTION_INDEX, RevealState.OPEN)
		+ collection_button.size * 0.5
	)
	return button_parent.get_screen_transform() * open_center

#endregion


#region 二选一大小与模式锁定

## Main 在打开二选一时查询，保留主窗口缩放并叠加独立的弹窗大小配置。
func get_memory_popup_scale() -> float:
	return all_output.scale.x * maxf(memory_popup_size_scale, 0.01)


## 二选一期间隐藏所有浮动控件，并锁住可能重新出现的 CollectedItem。
func set_memory_choice_active(active: bool) -> void:
	if _memory_choice_active == active:
		return

	_memory_choice_active = active
	_collection_attention_time = 0.0
	_outside_time = 0.0
	collected_item_button.disabled = active or _mini_mode_active

	for index in _floating_controls.size():
		var control := _floating_controls[index]
		var old_tween: Tween = _move_tweens[index]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		_move_tweens[index] = null
		_states[index] = RevealState.HIDDEN
		control.position = _get_target_position(index, RevealState.HIDDEN)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if control is BaseButton:
			(control as BaseButton).disabled = active or _mini_mode_active
		if active:
			control.hide()
		else:
			control.show()


## 冻结按钮位置；父层渐隐期间不再移动或接收输入，数量反馈可以继续更新。
func set_mini_mode_active(active: bool) -> void:
	if _mini_mode_active == active:
		return

	_mini_mode_active = active
	_collection_attention_time = 0.0
	_outside_time = 0.0
	var input_locked := _mini_mode_active or _memory_choice_active
	collected_item_button.disabled = input_locked
	collected_item_button.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if input_locked else Control.MOUSE_FILTER_STOP
	)

	for index in _floating_controls.size():
		var old_tween: Tween = _move_tweens[index]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		_move_tweens[index] = null

		var button := _corner_buttons[index]
		button.disabled = input_locked
		# 入场可能打断移动；解除锁定后重新决策，避免相同状态跳过未完成的移动。
		if not input_locked:
			_states[index] = -1
		button.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if not input_locked and _states[index] == RevealState.OPEN
			else Control.MOUSE_FILTER_IGNORE
		)
		button.release_focus()

#endregion


#region 鼠标坐标、悬停与缩放拖拽检测

func _get_all_output_mouse_position() -> Vector2:
	var window_mouse_position := Vector2(
		DisplayServer.mouse_get_position() - get_window().position
	)
	return all_output.get_global_transform_with_canvas().affine_inverse() * window_mouse_position


func _find_hovered_button(mouse_position: Vector2) -> int:
	for index in _floating_controls.size():
		if _states[index] == RevealState.HIDDEN:
			continue

		var control := _floating_controls[index]
		var control_center := control.position + control.pivot_offset
		var scaled_size := control.size * control.scale.abs()
		var visual_rect := Rect2(control_center - scaled_size * 0.5, scaled_size)
		if visual_rect.has_point(mouse_position):
			return index

	return -1


func _is_zooming_dragging() -> bool:
	return (
		is_instance_valid(zooming_button)
		and zooming_button.has_method("is_dragging")
		and bool(zooming_button.call("is_dragging"))
	)

#endregion
