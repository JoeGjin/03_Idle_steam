extends Node

@export var target:Node2D

func _update_passthrough() -> void:
	var tex :CompressedTexture2D = target.texture
	if tex == null:
		return

	# Sprite2D 默认以中心为原点（offset=0时），这里用贴图尺寸算四个角
	var size: Vector2 = tex.get_size()
	var half := size * 0.5

	# Sprite 的四个角（Sprite 本地坐标）
	var local_pts := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2( half.x, -half.y),
		Vector2( half.x,  half.y),
		Vector2(-half.x,  half.y),
	])

	# 转到“窗口坐标”（也就是全局画面坐标）
	var poly := PackedVector2Array()
	for p in local_pts:
		poly.append(target.global_transform * p)

	# 设置：poly 内能接收鼠标，poly 外全部穿透到系统/别的程序
	get_window().set_mouse_passthrough_polygon(poly)
