extends Window


@onready var effect_root: Control = %EffectRoot


var _play_generation := 0


func _ready() -> void:
    # 预先创建透明原生窗口，避免第一次播放特效时出现初始化黑帧。
    show()
    hide()


func play_effect(effect: CanvasItem, screen_rect: Rect2i, duration: float) -> void:
    _play_generation += 1
    var generation := _play_generation

    _clear_effect()
    position = screen_rect.position
    size = screen_rect.size
    effect_root.add_child(effect)
    show()

    if duration <= 0.0:
        return

    await get_tree().create_timer(duration).timeout
    if generation == _play_generation:
        stop_effect()


func stop_effect() -> void:
    _play_generation += 1
    hide()
    _clear_effect()


func _clear_effect() -> void:
    for child in effect_root.get_children():
        child.queue_free()
