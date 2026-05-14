extends Control



@export var postcards: Array[Texture2D] = []

signal postcard_showed

const MIN_SIZE := Vector2(800, 600)
const MAX_SIZE := Vector2(2048, 2048) # 2k 上限（按需求可改成 Vector2(2048, 1080) 等）


func show_postcard():
    var postcard_to_show := TextureRect.new()
    postcard_to_show.name = "postcard_to_show"
    add_child(postcard_to_show)

    if postcards.is_empty():
        push_warning("postcards array is empty; nothing to show.")
        postcard_to_show.queue_free()
        emit_signal("postcard_showed")
        return

    var tex: Texture2D = postcards[randi() % postcards.size()]
    postcard_to_show.texture = tex

    # 保持等比并居中显示
    postcard_to_show.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    postcard_to_show.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

    # 居中锚点：出现在屏幕中心
    postcard_to_show.set_anchors_preset(Control.PRESET_CENTER)
    postcard_to_show.position = Vector2.ZERO

    # 计算目标尺寸
    var tex_size : Vector2 = tex.get_size()
    var target_size : Vector2 = _fit_size_in_range(tex_size, MIN_SIZE, MAX_SIZE)

    postcard_to_show.size = target_size
    postcard_to_show.custom_minimum_size = target_size

    # ✅ 强制：锚点锁到中心点
    postcard_to_show.anchor_left = 0.5
    postcard_to_show.anchor_top = 0.5
    postcard_to_show.anchor_right = 0.5
    postcard_to_show.anchor_bottom = 0.5

    # ✅ 强制：offset 设为 ±size/2（真正居中）
    postcard_to_show.offset_left = -target_size.x * 0.5
    postcard_to_show.offset_top = -target_size.y * 0.5
    postcard_to_show.offset_right = target_size.x * 0.5
    postcard_to_show.offset_bottom = target_size.y * 0.5

    # 缩放围绕中心
    postcard_to_show.pivot_offset = target_size * 0.5

    # tween：从小到大（快到慢）
    var original_scale := Vector2.ONE
    postcard_to_show.scale = original_scale * 0.1

    var tween := create_tween()
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)

    tween.tween_property(postcard_to_show, "scale", original_scale, 0.45)
    tween.tween_interval(2.0)
    
    # 渐隐：2s 后淡出
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(postcard_to_show, "modulate:a", 0.0, 1.0)

    tween.tween_callback(func():
        if is_instance_valid(postcard_to_show):
            postcard_to_show.queue_free()
    )
    tween.tween_callback(func():
        emit_signal("postcard_showed")
    )

func _fit_size_in_range(src: Vector2, min_s: Vector2, max_s: Vector2) -> Vector2:
    # 目标：等比缩放 src，使其至少不小于 min_s，且不大于 max_s（任一维都不超过）
    var scale_up : float = max(min_s.x / src.x, min_s.y / src.y)
    var scale_down : float = min(max_s.x / src.x, max_s.y / src.y)

    # 如果原图太小 -> 放大到满足最小；如果原图太大 -> 缩小到不超过最大；否则保持原尺寸
    var s : float = 1.0
    if scale_up > 1.0:
        s = scale_up
    elif scale_down < 1.0:
        s = scale_down

    var out : Vector2 = src * s
    out.x = clamp(out.x, min_s.x, max_s.x)
    out.y = clamp(out.y, min_s.y, max_s.y)
    return out