extends Control


@export var work_board: Control
@export var texture_rect: TextureRect
# @export var letter: Control

var drag_target: Control = null # 可能是 self，也可能是 copy
var dragging := false 
var drag_offset := Vector2.ZERO # 鼠标位置与拖动目标位置的偏移（统一用 work_board 坐标系）

var texture_name: String = "" # 记录当前贴图的名字（不带路径和扩展名），方便后续复制时命名使用
var vibe_tag: Tags.Tag


func randomize_texture() -> void: # to be deleted
	$TextureRect.texture = load("res://assets/uiroot/stickers/%d.png" % randi_range(1, 5))


func update_actual_size() -> void:
	custom_minimum_size = texture_rect.size
	size = texture_rect.size



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP




func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_begin_drag()
			accept_event()


func _input(event: InputEvent) -> void:
	if not dragging:
		return

	if event is InputEventMouseMotion:
		_update_drag_target()
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_drag()
			work_board.update_resize_button()
			get_viewport().set_input_as_handled()




func _begin_drag() -> void:
	if dragging:
		return
	dragging = true

	# 1) 决定拖动目标
	if get_parent() == work_board:
		drag_target = self
		# 已经在 work_board 上了，直接拖动自己，并把自己移到最上层
		work_board.move_child(self, work_board.get_child_count() - 1)

	else:
		var drag_copy := duplicate() as Control
		drag_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		work_board.add_child(drag_copy)

		# 先把 copy 放到“跟原物体看起来一样”的世界位置
		drag_copy.global_position = self.global_position

		# 更新 copy 的尺寸（如果原物体有缩放的话，copy 也要保持一样的实际尺寸）
		drag_copy.update_actual_size()

		# 更新 copy 的名字和标签（如果有的话）
		_update_name_and_tag(drag_copy)

		drag_target = drag_copy

	# 2) 计算 offset（统一用 work_board 坐标系）
	var mouse_in_board := _to_local_of(work_board, get_global_mouse_position())
	var target_in_board := _to_local_of(work_board, drag_target.global_position)

	drag_offset = mouse_in_board - target_in_board
	drag_target.position = mouse_in_board - drag_offset


func _update_drag_target() -> void:
	if drag_target == null:
		return
	var mouse_in_board := _to_local_of(work_board, get_global_mouse_position())
	drag_target.position = mouse_in_board - drag_offset


func _finish_drag() -> void:
	if drag_target != null:
		_update_drag_target()
	dragging = false
	drag_target = null


func _to_local_of(target: CanvasItem, global_point: Vector2) -> Vector2:
	# 将 global_point 转换到 target 的局部坐标系
	return target.get_global_transform_with_canvas().affine_inverse() * global_point


func _update_name_and_tag(target_node: Control) -> void:
	# update name
	texture_name = texture_rect.texture.resource_path.get_file().get_basename()
	target_node.name = texture_name + "_c1"
	# update tag
