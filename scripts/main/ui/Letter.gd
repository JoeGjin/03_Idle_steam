extends Control




@export var dash_length := 10.0
@export var gap_length := 5.0
@export var line_width := 4.0
@export var line_color := Color.TAN

@onready var work_board: Control = %WorkBoard
@onready var crop_and_send_button: Button = %CropAndSend

var target_world_id: int

var _to_move: Array[Control] = [] # 临时变量，存储需要移动的物品，避免在遍历时修改子节点列表导致问题

signal sent(target_world_id: int) # 发送完成信号，参数可选，表示发送到哪个世界（-1表示未指定）




func free_all_children():
    for child in _to_move:
        child.queue_free()


func _draw():
    _draw_dashed_line(Vector2(0,0), Vector2(size.x,0))
    _draw_dashed_line(Vector2(size.x,0), Vector2(size.x,size.y))
    _draw_dashed_line(Vector2(size.x,size.y), Vector2(0,size.y))
    _draw_dashed_line(Vector2(0,size.y), Vector2(0,0))


func _draw_dashed_line(from:Vector2, to:Vector2):
    var dir = (to - from).normalized()
    var length = from.distance_to(to)

    var current = 0.0
    while current < length:
        var start = from + dir * current
        var end = from + dir * min(current + dash_length, length)

        draw_line(start, end, line_color, line_width)

        current += dash_length + gap_length




func _on_crop_and_send_pressed() -> void:
    crop_and_send_button.disabled = true # 防止重复点击
    work_board.reset_resize_button() 
    _move_overlapped_items_into_letter(true)
    work_board.free_all_children() # 清空工作区，留下被裁剪的物品
    _play_send_animation()


func _on_letter_animation_finished() -> void:
    free_all_children()
    crop_and_send_button.disabled = false
    sent.emit(target_world_id) # 发出信号，通知 Main 世界切换
    %UIWindow.close_uiwindow()


func _move_overlapped_items_into_letter(include_borders: bool = true) -> void:
   
    var letter_rect: Rect2 = get_global_rect()
    # 先收集，避免遍历时 reparent 改变 child 列表
    _to_move = []

    for child in work_board.get_children():
        
        var item := child as Control
        var item_rect: Rect2 = item.get_global_rect()

        if letter_rect.intersects(item_rect, include_borders):
            _to_move.append(item)

    for item in _to_move:
        # 保持视觉位置不变
        var old_global_pos := item.global_position
        # Godot 4.x：reparent 会自动从原父节点移除再加入新父节点
        item.reparent(self)
        item.global_position = old_global_pos
        item.mouse_filter = Control.MOUSE_FILTER_IGNORE # 进入 letter 后不再响应鼠标事件


func _play_send_animation(duration: float = 1.5) -> void:
    
    # 记录初始状态（用于重置）
    var start_scale: Vector2 = scale
    var start_modulate: Color = modulate
    var start_visible: bool = visible

    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

    # 放大并停留一会儿
    tween.tween_property(self, "scale", start_scale * 1.1, duration)
    tween.tween_interval(1.0) # 放大后停留的时间

    # 同时缩小 + 淡出
    tween.tween_property(self, "scale", start_scale * 0.1, duration)
    tween.parallel().tween_property(self, "modulate:a", 0.0, duration)

    # 动画完成后：重置状态
    tween.tween_callback(func ():
        scale = start_scale
        modulate = start_modulate
        visible = start_visible
        _on_letter_animation_finished()
    )
