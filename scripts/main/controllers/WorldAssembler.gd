# 世界组装器，负责将世界环境定义资源转换为实际的场景节点

extends Node

class_name WorldAssembler


@export var world_root: Node2D
@export var world_defs: Array[WorldDef] = []
@export var current_world_id: int = 0

var _sky: Parallax2D
var _moon: Parallax2D
var _far_1: ManualParallax
var _far_2: ManualParallax
var _land: Parallax2D
var _sea: Parallax2D
var _mid_1: ManualParallax
var _mid_2: ManualParallax
var _front_1: ManualParallax
var _front_2: ManualParallax
var _light: Parallax2D

var _world_player: AnimationPlayer


signal world_changed(new_world_id: int)




func initiate() -> void:
	_sky = world_root.get_node("%Sky")
	_moon = world_root.get_node("%Moon")
	_far_1 = world_root.get_node("%Far_1")
	_far_2 = world_root.get_node("%Far_2")
	_land = world_root.get_node("%Land")
	_sea = world_root.get_node("%Sea")
	_mid_1 = world_root.get_node("%Mid_1")
	_mid_2 = world_root.get_node("%Mid_2")
	_front_1 = world_root.get_node("%Front_1")
	_front_2 = world_root.get_node("%Front_2")
	_light = world_root.get_node("%Light")
	_world_player = world_root.get_node("%WorldPlayer")



func assemble_world(world_id: int) -> void:
	# _world_player.stop() # 切换世界时先停止动画
	
	var target_world = world_defs[world_id]
	_defs_to_scene(target_world) # 将world def的参数应用到场景节点上

	_start_manual_scroll() # 启动手动滚动的层

	
	# 3. 播放world player动画（如果有的话）
	#   3.1 func play_world_animation (world player根据world def切换

	world_changed.emit(world_id) # 发出世界切换信号，供其他系统（如角色状态机）响应


# func _transition_to_world(new_world_id: int) -> void:
	# 1. target_world = world_defs[new_world_id]
	# 2. 非Parallex2D节点texture开始渐变
	# 3. Parallex2D节点颜色开始渐变
	# 4. moon开始移出场景，新的moon移入（moon完成及transition完成）


func _defs_to_scene(current_world: WorldDef) -> void:
	_sky.repeat_size = current_world.sky_repeat_size
	_sky.autoscroll = current_world.sky_scroll_speed
	_sky.get_child(0).texture = current_world.sky_main_texture
	_sky.get_child(0).modulate = current_world.sky_main_color
	_sky.get_child(1).texture = current_world.sky_effect_texture
	_sky.get_child(1).modulate = current_world.sky_effect_color

	_moon.repeat_size = current_world.moon_repeat_size
	_moon.autoscroll = current_world.moon_scroll_speed
	_moon.get_child(0).texture = current_world.moon_main_texture
	_moon.get_child(0).modulate = current_world.moon_main_color
	_moon.get_child(1).texture = current_world.moon_effect_texture
	_moon.get_child(1).modulate = current_world.moon_effect_color

	_far_1.scroll_speed = current_world.far_1_scroll_speed
	_far_1.spawn_scale = current_world.far_1_spwan_scale
	_far_1.spawn_position = current_world.far_1_spawn_position
	_far_1.spawn_cooldown = current_world.far_1_spwan_cooldown
	_far_1.spawn_randomness = current_world.far_1_spwan_randomness
	_far_1._textures_0 = current_world.far_0_textures
	_far_1._color_0 = current_world.far_0_color
	_far_1._textures = current_world.far_1_textures
	_far_1._color = current_world.far_1_colors

	_far_2.scroll_speed = current_world.far_2_scroll_speed
	_far_2.spawn_scale = current_world.far_2_spwan_scale
	_far_2.spawn_position = current_world.far_2_spawn_position
	_far_2.spawn_cooldown = current_world.far_2_spwan_cooldown
	_far_2.spawn_randomness = current_world.far_2_spwan_randomness
	_far_2._textures_0 = current_world.far_0_textures
	_far_2._color_0 = current_world.far_0_color
	_far_2._textures = current_world.far_2_textures
	_far_2._color = current_world.far_2_colors

	_land.repeat_size = current_world.land_repeat_size
	_land.autoscroll = current_world.land_scroll_speed
	_land.get_child(0).texture = current_world.land_main_texture
	_land.get_child(0).modulate = current_world.land_main_color
	_land.get_child(1).texture = current_world.land_effect_texture
	_land.get_child(1).modulate = current_world.land_effect_color

	_sea.repeat_size = current_world.sea_repeat_size
	_sea.autoscroll = current_world.sea_scroll_speed
	_sea.get_child(0).texture = current_world.sea_main_texture
	_sea.get_child(0).modulate = current_world.sea_main_color
	_sea.get_child(1).texture = current_world.sea_effect_texture
	_sea.get_child(1).modulate = current_world.sea_effect_color

	_mid_1.scroll_speed = current_world.mid_1_scroll_speed
	_mid_1.spawn_scale = current_world.mid_1_spwan_scale
	_mid_1.spawn_position = current_world.mid_1_spawn_position
	_mid_1.spawn_cooldown = current_world.mid_1_spwan_cooldown
	_mid_1.spawn_randomness = current_world.mid_1_spwan_randomness
	_mid_1._textures_0 = current_world.mid_0_textures
	_mid_1._color_0 = current_world.mid_0_color
	_mid_1._textures = current_world.mid_1_textures
	_mid_1._color = current_world.mid_1_colors

	_mid_2.scroll_speed = current_world.mid_2_scroll_speed
	_mid_2.spawn_scale = current_world.mid_2_spwan_scale
	_mid_2.spawn_position = current_world.mid_2_spawn_position
	_mid_2.spawn_cooldown = current_world.mid_2_spwan_cooldown
	_mid_2.spawn_randomness = current_world.mid_2_spwan_randomness
	_mid_2._textures_0 = current_world.mid_0_textures
	_mid_2._color_0 = current_world.mid_0_color
	_mid_2._textures = current_world.mid_2_textures
	_mid_2._color = current_world.mid_2_colors

	_front_1.scroll_speed = current_world.front_1_scroll_speed
	_front_1.spawn_scale = current_world.front_1_spwan_scale
	_front_1.spawn_position = current_world.front_1_spawn_position
	_front_1.spawn_cooldown = current_world.front_1_spwan_cooldown
	_front_1.spawn_randomness = current_world.front_1_spwan_randomness
	_front_1._textures_0 = current_world.front_0_textures
	_front_1._color_0 = current_world.front_0_color
	_front_1._textures = current_world.front_1_textures
	_front_1._color = current_world.front_1_colors

	_front_2.scroll_speed = current_world.front_2_scroll_speed
	_front_2.spawn_scale = current_world.front_2_spwan_scale
	_front_2.spawn_position = current_world.front_2_spawn_position
	_front_2.spawn_cooldown = current_world.front_2_spwan_cooldown
	_front_2.spawn_randomness = current_world.front_2_spwan_randomness
	_front_2._textures_0 = current_world.front_0_textures
	_front_2._color_0 = current_world.front_0_color
	_front_2._textures = current_world.front_2_textures
	_front_2._color = current_world.front_2_colors
	
	_light.repeat_size = current_world.light_repeat_size
	_light.autoscroll = current_world.light_scroll_speed
	_light.get_child(0).texture = current_world.light_main_texture
	_light.get_child(0).modulate = current_world.light_main_color
	_light.get_child(1).texture = current_world.light_effect_texture
	_light.get_child(1).modulate = current_world.light_effect_color

	#print("[WORLD ASSEMBLER] World assembled with ID: %d" % current_world_id)


func _start_manual_scroll() -> void:
	_far_1.start_manual_scroll()
	_far_2.start_manual_scroll()
	_mid_1.start_manual_scroll()
	_mid_2.start_manual_scroll()
	_front_1.start_manual_scroll()
	_front_2.start_manual_scroll()
