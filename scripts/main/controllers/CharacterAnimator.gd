# 本脚本用于处理点击的所有动画效果

extends Node
class_name CharacterAnimator

@export var pet: Node2D
@export var shrink_scale := 0.75
@export var shrink_duration := 0.08
@export var expand_duration := 0.10
@export var base_scale: Vector2 = Vector2.ONE

var _click_tween: Tween

func _play_click_scale_anim() -> void:
    if _click_tween:
        _click_tween.kill()

    _click_tween = create_tween()
    _click_tween.set_trans(Tween.TRANS_BACK)
    _click_tween.set_ease(Tween.EASE_OUT)
    

    _click_tween.tween_property(pet, "scale", base_scale * shrink_scale, shrink_duration)
    _click_tween.tween_property(pet, "scale", base_scale, expand_duration)
