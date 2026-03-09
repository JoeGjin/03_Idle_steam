# 世界组装器，负责将世界环境定义资源转换为实际的场景节点

extends Node
class_name WorldAssembler


@export var world_root: Node2D
@export var world_defs: Array[WorldDef] = []
@export var current_world_id: int = 0

var _sky: Parallax2D
var _sky_sprite: Sprite2D
var _cloud: Parallax2D
var _cloud_sprite: Sprite2D
var _background: Parallax2D
var _background_sprite: Sprite2D
var _midground: Parallax2D
var _midground_sprite: Sprite2D
var _foreground: Parallax2D
var _foreground_sprite: Sprite2D
var _world_player: AnimationPlayer

signal world_changed(new_world_id: int)

func initiate_assembler() -> void:
	# print("[WorldAssembler] Initializing assembler...")
	# print(world_defs)
	
	# 这里可以放一些初始化逻辑，比如预加载资源等
	_sky = world_root.get_node("%Sky")
	_sky_sprite = _sky.get_child(0)
	_cloud = world_root.get_node("%Cloud")
	_cloud_sprite = _cloud.get_child(0)
	_background = world_root.get_node("%Background")
	_background_sprite = _background.get_child(0)
	_midground = world_root.get_node("%Midground")
	_midground_sprite = _midground.get_child(0)
	_foreground = world_root.get_node("%Foreground")
	_foreground_sprite = _foreground.get_child(0)
	_world_player = world_root.get_node("%WorldPlayer")

	_assemble_world(0) # 默认组装第一个世界，后续可以根据需要切换



func _assemble_world(world_id: int) -> void:
		
	_world_player.stop() # 切换世界时先停止动画
	
	var target_world = world_defs[world_id]
	
	_sky_sprite.texture = target_world.sky_texture
	_sky.repeat_size = target_world.sky_repeat_size
	_sky.autoscroll = target_world.sky_scroll_speed

	_cloud_sprite.texture = target_world.cloud_texture
	_cloud.repeat_size = target_world.cloud_repeat_size
	_cloud.autoscroll = target_world.cloud_scroll_speed

	_background_sprite.texture = target_world.background_texture
	_background.repeat_size = target_world.background_repeat_size
	_background.autoscroll = target_world.background_scroll_speed

	_midground_sprite.texture = target_world.midground_texture
	_midground.repeat_size = target_world.midground_repeat_size
	_midground.autoscroll = target_world.midground_scroll_speed

	_foreground_sprite.texture = target_world.foreground_texture
	_foreground.repeat_size = target_world.foreground_repeat_size
	_foreground.autoscroll = target_world.foreground_scroll_speed
	
	match world_id:
		0:
			_world_player.play("World_0")

	current_world_id = world_id
	world_changed.emit(current_world_id)
