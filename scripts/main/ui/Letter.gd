extends Control




@export var dash_length := 10.0
@export var gap_length := 5.0
@export var line_width := 4.0
@export var line_color := Color.TAN

@onready var work_board: Control = %WorkBoard
@onready var crop_and_send_button: Button = %CropAndSend
@onready var sticker_controller: StickerController = %StickerController
@onready var world_assembler: WorldAssembler = %WorldAssembler




var _to_move: Array[Control] = [] # 临时变量，存储需要移动的物品，避免在遍历时修改子节点列表导致问题



signal sent(target_world_id: int, sub_world_id: int, sub_world_weight: float) # 发送完成信号，参数可选，表示发送到哪个世界（-1表示未指定）




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
    
    # 0. 处理标签计算结果，决定发送到哪个世界
    var tag_calculation: Dictionary = {} # 贴图标签计数，格式为 { tag: count, ... }
    for item in _to_move:
        # 更新标签计数
        var item_name_parts: Array = str(item.name).split("_")
        var sticker_key: String = "_".join(item_name_parts.slice(0, 3))
        var tags: Array = sticker_controller.sticker_to_tag(sticker_key)
        for tag in tags:
            if not tag_calculation.has(tag):
                tag_calculation[tag] = 0
            tag_calculation[tag] += 1
    
    var target_world_id: int = -1 # 目标世界ID，默认为-1表示未指定
    var sub_world_id: int = -1 # 可选的子世界ID，默认为-1表示未指定
    var sub_world_weight: float = 0.0 # 可选的子世界权重，范围0.0-1.0，默认为0.0表示未指定

    # 1. 得到 tag 的总数 tags_total from tag_calculation
    var tags_total: int = 0
    for tag in tag_calculation:
        tags_total += tag_calculation[tag]
    # 2. 根据 tag_calculation 和 tags_total 计算每个 tag 的占比，并乘以对应权重，得到一个 weight
    var world_scores: Dictionary[int, float] = {} # world_id -> weight
    for tag in tag_calculation:
        var count: int = tag_calculation[tag]
        world_scores[tag] = float(count) / float(tags_total) # 这里假设 tag 的数值就是对应世界的权重，实际可以根据设计调整
    # 3. 根据计算得到的 weight 决定 target_world_id（最高weight），sub_world_id（次高weight）和 sub_world_weight（次高weight占比）
    var result := _get_top_two_worlds(world_scores)
    target_world_id = result["target_world_id"]
    sub_world_id = result["sub_world_id"]
    sub_world_weight = result["sub_world_weight"]

    # 发出信号，通知 Main 世界切换
    sent.emit(target_world_id, sub_world_id, sub_world_weight) 
    
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
        

func _get_top_two_worlds(world_scores: Dictionary[int, float]) -> Dictionary:
    var target_world_id_t := -1
    var target_world_weight := -INF
    
    var sub_world_id_t := -1
    var sub_world_weight_t := -INF
    
    for world_id: int in world_scores:
        var weight: float = world_scores[world_id]
        
        if weight > target_world_weight:
            sub_world_id_t = target_world_id_t
            sub_world_weight_t = target_world_weight
            
            target_world_id_t = world_id
            target_world_weight = weight
        
        elif weight > sub_world_weight_t:
            sub_world_id_t = world_id
            sub_world_weight_t = weight
    
    return {
        "target_world_id": target_world_id_t,
        "sub_world_id": sub_world_id_t,
        "sub_world_weight": sub_world_weight_t,
    }




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
