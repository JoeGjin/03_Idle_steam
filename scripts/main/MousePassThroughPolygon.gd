# 本脚本用于根据目标 Node2D 的位置和大小，设置鼠标穿透多边形区域

extends Node

@export var target:Node2D
var poly :PackedVector2Array

const CROP_FACTOR := 10

func _update_passthrough() -> void:
	
	poly = PackedVector2Array()

	_calc_target_rect()

	get_window().set_mouse_passthrough_polygon(poly)


func _calc_target_rect():
	if not target or not target is Node2D: # 仅支持 Node2D 目标
		return
	

	# 通过目标的 SpriteFrames 和当前动画帧获取纹理尺寸（目前目标是 AnimatedSprite2D）
	var frames: SpriteFrames = target.sprite_frames
	var anim_name: StringName = target.animation
	var frame_index: int = target.frame
	var texture: Texture2D = frames.get_frame_texture(anim_name, frame_index)

	# 无纹理则不设置穿透区域
	if not texture: 
		return

	# 直接用纹理尺寸和缩放计算四个角
	var size := texture.get_size() * target.scale * CROP_FACTOR
	var half := size * 0.5
	
	# 计算全局坐标的多边形顶点
	var local_pts := PackedVector2Array([
		-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)
	])

	# 转换到全局坐标
	for p in local_pts: 
		poly.append(target.global_transform * p)