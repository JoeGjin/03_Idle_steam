extends Node2D


@export var start_pos: Vector2 = Vector2(0, -5000.0)
@export var end_pos: Vector2 = Vector2(0, 0)

@export var fall_time := 5.0
@export var spin_turns := 2.0          # 旋转几圈（1=360°）
@export var shrink_time := 0.5        # “迅速缩小”时长


func _ready() -> void:
	hide()

func drop_letter() -> void:
	# 初始化到起点
	position = start_pos
	scale = Vector2.ONE
	rotation = 0.0
	modulate = Color(1, 1, 1, 1) # 确保不透明
	show()

	# 串联 Tween：先6秒旋转+降落 -> 再快速缩小消失
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)

	# 6s：降落
	t.tween_property(self, "position", end_pos, fall_time)

	# 6s：同时慢慢旋转（并行）
	t.parallel().tween_property(self, "rotation", TAU * spin_turns, fall_time)

	# 到达后：快速缩小（也可以同时淡出）
	t.tween_property(self, "scale", Vector2.ZERO, shrink_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	# 可选：如果是 CanvasItem（Sprite2D/Polygon2D 这类），可以再淡出更自然
	t.parallel().tween_property(self, "modulate:a", 0.0, shrink_time)

	# 最后隐藏/删除
	t.tween_callback(func():
		hide()
	)
