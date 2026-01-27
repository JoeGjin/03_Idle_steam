# 本脚本用于根据目标 Sprite2D 的位置和大小，设置鼠标穿透多边形区域

extends Node

@export var target:Node2D

func _update_passthrough() -> void:
	if not target or not target is Sprite2D: # 仅支持 Sprite2D 目标
		get_window().set_mouse_passthrough_polygon(PackedVector2Array())
		return

	var tex: CompressedTexture2D = target.texture
	if not tex: # 无纹理则不设置穿透区域
		get_window().set_mouse_passthrough_polygon(PackedVector2Array())
		return

	# 直接用纹理尺寸和缩放计算四个角
	var size := tex.get_size() * target.scale
	var half := size * 0.5

	# 计算全局坐标的多边形顶点
	var local_pts := PackedVector2Array([
		-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)
	])

	var poly := PackedVector2Array()
	for p in local_pts: # 转换到全局坐标
		poly.append(target.global_transform * p)
	get_window().set_mouse_passthrough_polygon(poly)
