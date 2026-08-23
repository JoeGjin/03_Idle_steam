extends Node


signal setting_requested
signal collection_requested
signal minimode_requested
signal collected_item_requested


enum RevealState {
	HIDDEN,
	PEEK,
	OPEN,
}


const ZOOMING_INDEX := 2
const COLLECTION_INDEX := 1
const RECENT_MEMORY_BAR_INDEX := 4
const COLLECTED_ITEM_MIN_SCALE_RATIO := 0.6


@export var all_output: Control
@export var setting_button: Button
@export var collection_button: Button
@export var zooming_button: Button
@export var minimode_button: Button
@export var collected_item_button: Button
@export var recent_memory_bar: Panel
@export var recent_memory_texture_1: TextureRect
@export var recent_memory_texture_2: TextureRect
@export var recent_memory_texture_3: TextureRect

@export_group("Reveal State")
## 相对椭圆边缘向外的距离；负值会让按钮收进 WorldOutput 后方。
@export_range(-240.0, 240.0, 1.0, "suffix:px") var hidden_offset := -90.0
@export_range(-240.0, 240.0, 1.0, "suffix:px") var peek_offset := -42.0
@export_range(-240.0, 240.0, 1.0, "suffix:px") var open_offset := 70.0
## RecentMemoryBar 相对世界底部锚点的额外垂直偏移；正值向下，负值向上。
@export_range(-400.0, 400.0, 1.0, "suffix:px") var recent_memory_bar_vertical_offset := 0.0

@export_group("Button Size")
## 统一缩放四角按钮与 CollectedItem，包括文字和样式。
@export_range(0.25, 3.0, 0.05, "or_greater") var button_size_scale := 1.0
@export_range(0.25, 3.0, 0.05, "or_greater") var recent_memory_bar_size_scale := 1.0

@export_group("Animation")
@export var move_duration := 0.22
@export var leave_delay := 0.2

var _corner_buttons: Array[Button] = []
var _floating_controls: Array[Control] = []
var _recent_memory_textures: Array[TextureRect] = []
var _directions: Array[Vector2] = [
	Vector2(-1.0, -1.0).normalized(),
	Vector2(1.0, -1.0).normalized(),
	Vector2(1.0, 1.0).normalized(),
	Vector2(-1.0, 1.0).normalized(),
	Vector2.DOWN,
]
var _anchors: Array[Vector2] = []
var _states: Array[int] = []
var _move_tweens: Array = []
var _outside_time := 0.0
var _ready_for_input := false
var _collection_attention_time := 0.0
var _collected_item_tween: Tween
var _memory_choice_active := false
var _has_recent_memories := false


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
	_floating_controls.append(recent_memory_bar)
	_recent_memory_textures = [
		recent_memory_texture_1,
		recent_memory_texture_2,
		recent_memory_texture_3,
	]

	setting_button.pressed.connect(setting_requested.emit)
	collection_button.pressed.connect(collection_requested.emit)
	minimode_button.pressed.connect(minimode_requested.emit)
	collected_item_button.pressed.connect(collected_item_requested.emit)
	collected_item_button.hide()
	recent_memory_bar.hide()

	while all_output.has_method("is_layout_ready") and not all_output.call("is_layout_ready"):
		await get_tree().process_frame

	_setup_button_layout()
	_ready_for_input = true


func _process(delta: float) -> void:
	if not _ready_for_input:
		return
	if _memory_choice_active:
		return

	if _collection_attention_time > 0.0:
		_collection_attention_time = maxf(_collection_attention_time - delta, 0.0)
		for index in _corner_buttons.size():
			_set_button_state(
				index,
				RevealState.OPEN if index == COLLECTION_INDEX else RevealState.PEEK
			)
		_set_button_state(
			RECENT_MEMORY_BAR_INDEX,
			RevealState.PEEK if _has_recent_memories else RevealState.HIDDEN
		)
		if _collection_attention_time > 0.0:
			return

	# 缩放依赖窗口外的全局鼠标位置。拖拽期间锁住按钮，避免窗口尺寸变化后
	# 本地命中区域离开鼠标，导致 Zooming 收回并中断交互。
	if _is_zooming_dragging():
		_outside_time = 0.0
		for index in _floating_controls.size():
			var target_state := RevealState.OPEN if index == ZOOMING_INDEX else RevealState.PEEK
			if index == RECENT_MEMORY_BAR_INDEX and not _has_recent_memories:
				target_state = RevealState.HIDDEN
			_set_button_state(
				index,
				target_state
			)
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
			if index == RECENT_MEMORY_BAR_INDEX and not _has_recent_memories:
				target_state = RevealState.HIDDEN
			_set_button_state(index, target_state)
		return

	_outside_time += delta
	if _outside_time >= leave_delay:
		_set_all_states(RevealState.HIDDEN)


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


func set_recent_memories(memories: Array[MemoryDef]) -> void:
	_has_recent_memories = false
	for index in _recent_memory_textures.size():
		var memory: MemoryDef
		if index < memories.size():
			memory = memories[index]

		var has_texture := memory != null and memory.texture != null
		var texture_rect := _recent_memory_textures[index]
		texture_rect.texture = memory.texture if has_texture else null
		var memory_panel := texture_rect.get_parent() as CanvasItem
		memory_panel.visible = has_texture
		_has_recent_memories = _has_recent_memories or has_texture

	if _has_recent_memories and not _memory_choice_active:
		recent_memory_bar.show()
	else:
		_set_button_state(RECENT_MEMORY_BAR_INDEX, RevealState.HIDDEN)
		recent_memory_bar.hide()


## 二选一期间隐藏所有浮动控件，并锁住可能重新出现的 CollectedItem。
func set_memory_choice_active(active: bool) -> void:
	if _memory_choice_active == active:
		return

	_memory_choice_active = active
	_collection_attention_time = 0.0
	_outside_time = 0.0
	collected_item_button.disabled = active

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
			(control as BaseButton).disabled = active
		if active:
			control.hide()
		elif index != RECENT_MEMORY_BAR_INDEX or _has_recent_memories:
			control.show()


func _kill_collected_item_tween() -> void:
	if _collected_item_tween != null and _collected_item_tween.is_valid():
		_collected_item_tween.kill()


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

	var recent_memory_nodes := [
		recent_memory_bar,
		recent_memory_texture_1,
		recent_memory_texture_2,
		recent_memory_texture_3,
	]
	for node in recent_memory_nodes:
		if node == null:
			push_error("[FloatButtons] Recent Memory Bar 节点未完整设置")
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
		if index == RECENT_MEMORY_BAR_INDEX:
			anchor.y += recent_memory_bar_vertical_offset
		_anchors.append(anchor)
		_states.append(RevealState.HIDDEN)
		_move_tweens.append(null)

		var control := _floating_controls[index]
		control.pivot_offset = control.size * 0.5
		var control_scale := (
			recent_memory_bar_size_scale
			if index == RECENT_MEMORY_BAR_INDEX
			else button_size_scale
		)
		control.scale = Vector2.ONE * control_scale
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.position = _get_target_position(index, RevealState.HIDDEN)

	collected_item_button.pivot_offset = collected_item_button.size * 0.5
	collected_item_button.scale = Vector2.ONE * button_size_scale
	collected_item_button.position = Vector2(
		center.x - collected_item_button.size.x * 0.5,
		world_rect.position.y - collected_item_button.size.y * 0.01
	)


func _find_hovered_button(mouse_position: Vector2) -> int:
	for index in _floating_controls.size():
		if _states[index] == RevealState.HIDDEN:
			continue
		if index == RECENT_MEMORY_BAR_INDEX and not _has_recent_memories:
			continue

		var control := _floating_controls[index]
		var control_center := control.position + control.pivot_offset
		var scaled_size := control.size * control.scale.abs()
		var visual_rect := Rect2(control_center - scaled_size * 0.5, scaled_size)
		if visual_rect.has_point(mouse_position):
			return index

	return -1


func _set_all_states(state: int) -> void:
	for index in _floating_controls.size():
		var target_state := state
		if index == RECENT_MEMORY_BAR_INDEX and not _has_recent_memories:
			target_state = RevealState.HIDDEN
		_set_button_state(index, target_state)


func _set_button_state(index: int, state: int) -> void:
	if index == ZOOMING_INDEX and _is_zooming_dragging():
		state = RevealState.OPEN

	var control := _floating_controls[index]

	# PEEK 时只由 Manager 检测外露区域，避免按钮在 WorldOutput 内部抢占输入。
	control.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if state == RevealState.OPEN and index != RECENT_MEMORY_BAR_INDEX
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


func _get_all_output_mouse_position() -> Vector2:
	var window_mouse_position := Vector2(
		DisplayServer.mouse_get_position() - get_window().position
	)
	return all_output.get_global_transform_with_canvas().affine_inverse() * window_mouse_position


func _is_zooming_dragging() -> bool:
	return (
		is_instance_valid(zooming_button)
		and zooming_button.has_method("is_dragging")
		and bool(zooming_button.call("is_dragging"))
	)
