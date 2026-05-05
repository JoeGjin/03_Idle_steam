extends Node2D

@export_range(0.0, 10.0, 0.1) var lod: float = 0.5 # 模糊程度


func _ready():

	# 初始将 pet 放在视口中心
	global_position = get_viewport().get_visible_rect().size * 0.5


	show()
