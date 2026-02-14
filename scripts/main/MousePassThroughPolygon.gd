# 本脚本用于根据目标 Node2D 的位置和大小，设置鼠标穿透多边形区域

extends Node

@export var target:Node2D # not used currently, reserved for future use
@export var frame:Node2D
var poly :PackedVector2Array

func _update_passthrough() -> void:
	poly = PackedVector2Array()
	_calc_target_rect()
	get_window().set_mouse_passthrough_polygon(poly)


# 计算目标矩形的全局坐标，并更新 poly
func _calc_target_rect():

	# 转换到全局坐标
	for p in frame.polygon: 
		poly.append(frame.to_global(p))
	