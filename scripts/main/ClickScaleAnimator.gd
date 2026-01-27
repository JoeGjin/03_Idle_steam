extends Node

@export var target:Node2D
var _click_tween: Tween

func _play_click_scale_anim():
	if _click_tween and _click_tween.is_running():
		_click_tween.kill()

	_click_tween = create_tween()
	_click_tween.set_trans(Tween.TRANS_BACK)
	_click_tween.set_ease(Tween.EASE_OUT)

	# 先快速缩小
	_click_tween.tween_property(
		target,
		"scale",
		Vector2.ONE * 0.75,
		0.06
	)

	# 再弹回原大小
	_click_tween.tween_property(
		target,
		"scale",
		Vector2.ONE,
		0.1
	)
