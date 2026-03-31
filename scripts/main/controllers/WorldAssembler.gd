# 世界组装器，负责将世界环境定义资源转换为实际的场景节点

extends Node

class_name WorldAssembler


@export var world_root: Node2D
@export var world_defs: Array[WorldDef] = []
@export var current_world_id: int = 0

var _sky: Parallax2D
var _moon: Parallax2D
var _far_1: Node2D
var _far_2: Node2D
var _land: Parallax2D
var _sea: Parallax2D
var _mid_1: Node2D
var _mid_2: Node2D
var _front_1: Node2D
var _front_2: Node2D
var _light: Parallax2D

var _world_player: AnimationPlayer


signal world_changed(new_world_id: int)




func initiate() -> void:
	return
	_sky = world_root.get_node("%Sky")
	_moon = world_root.get_node("%Moon")
	_far_1 = world_root.get_node("%Far_1")
	_far_2 = world_root.get_node("%Far_2")
	_sea = world_root.get_node("%Sea")
	_mid_1 = world_root.get_node("%Mid_1")
	_mid_2 = world_root.get_node("%Mid_2")
	_land = world_root.get_node("%Land")
	_front_1 = world_root.get_node("%Front_1")
	_front_2 = world_root.get_node("%Front_2")
	_light = world_root.get_node("%Light")
	_world_player = world_root.get_node("%WorldPlayer")

	_assemble_world(0) # 默认组装第一个世界，后续可以根据需要切换



func _assemble_world(world_id: int) -> void:
	return
		
	# _world_player.stop() # 切换世界时先停止动画
	
	# var target_world = world_defs[world_id]
	
	# _sky_sprite.texture = target_world.sky_texture
	# _sky.repeat_size = target_world.sky_repeat_size
	# _sky.autoscroll = target_world.sky_scroll_speed

	# _cloud_sprite.texture = target_world.cloud_texture
	# _cloud.repeat_size = target_world.cloud_repeat_size
	# _cloud.autoscroll = target_world.cloud_scroll_speed

	# _background_sprite.texture = target_world.background_texture
	# _background.repeat_size = target_world.background_repeat_size
	# _background.autoscroll = target_world.background_scroll_speed

	# _midground_sprite.texture = target_world.midground_texture
	# _midground.repeat_size = target_world.midground_repeat_size
	# _midground.autoscroll = target_world.midground_scroll_speed

	# _foreground_sprite.texture = target_world.foreground_texture
	# _foreground.repeat_size = target_world.foreground_repeat_size
	# _foreground.autoscroll = target_world.foreground_scroll_speed
	
	# match world_id:
	# 	0:
	# 		_world_player.play("World_0")

	# current_world_id = world_id
	# world_changed.emit(current_world_id)
