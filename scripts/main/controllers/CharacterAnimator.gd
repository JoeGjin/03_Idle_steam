# 响应 Main 的按键反馈调用，为 Pet 播放先收缩再恢复的缩放动画。

extends Node
class_name CharacterAnimator


# 执行缩放反馈的角色节点。
@onready var pet: Node2D = %Pet

# 相对基准缩放的收缩倍率，以及收缩、恢复阶段的时长（秒）。
@export var shrink_scale := 0.75
@export var shrink_duration := 0.08
@export var expand_duration := 0.10
# 启动时由 Pet 的实际缩放覆盖，后续动画始终恢复到该基准。
@export var base_scale: Vector2 = Vector2.ONE

# 当前缩放 Tween，连续触发时先终止旧动画，避免同时写入 Pet.scale。
var _click_tween: Tween


# 目录（与下方代码分区顺序一致）
# 1. 生命周期与基准记录：_ready 读取 Pet 的初始缩放作为恢复目标。
# 2. 按键缩放反馈：_play_click_scale_anim 替换旧 Tween，依次执行收缩与恢复。
#    Main 在全局按键回调中调用此入口；曲线使用 TRANS_BACK 和 EASE_OUT。


#region 生命周期与基准记录

func _ready() -> void:
    base_scale = pet.scale

#endregion


#region 按键缩放反馈

func _play_click_scale_anim() -> void:
    if _click_tween:
        _click_tween.kill()

    _click_tween = create_tween()
    _click_tween.set_trans(Tween.TRANS_BACK)
    _click_tween.set_ease(Tween.EASE_OUT)

    _click_tween.tween_property(pet, "scale", base_scale * shrink_scale, shrink_duration)
    _click_tween.tween_property(pet, "scale", base_scale, expand_duration)

#endregion
