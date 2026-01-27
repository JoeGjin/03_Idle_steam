# 本脚本用于处理点击的所有动画效果

extends Node

@export var target: Node2D
@export var shrink_scale := 0.75
@export var shrink_duration := 0.06
@export var expand_duration := 0.10

var _click_tween: Tween

func _play_click_scale_anim() -> void:
    if _click_tween:
        _click_tween.kill()

    _click_tween = create_tween()
    _click_tween.set_trans(Tween.TRANS_BACK)
    _click_tween.set_ease(Tween.EASE_OUT)
    
    _click_tween.tween_property(target, "scale", Vector2.ONE * shrink_scale, shrink_duration)
    _click_tween.tween_property(target, "scale", Vector2.ONE, expand_duration)
