# 世界组装器，负责将世界环境定义资源转换为实际的场景节点
# 直接控制图像资源切换，音频资源通过signal通知main，main再调用AudioController进行切换

extends Node

class_name WorldAssembler



@export var world_defs: Array[WorldDef] = []
@export var transition_duration: float = 30.0 # 世界切换的过渡动画时长（秒）

@onready var world_root: Node2D = %WorldRoot

var current_world_id: int = 0 # 当前世界ID，初始为-1表示未设置
var is_transitioning: bool = false # 是否正在进行世界切换过渡

var unhandled_letter_tags: Array = [] # 存储未处理的标签，供发送时使用

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


signal world_changing(new_world_id: int, transition_duration: float) # 定义世界切换信号，参数为新的世界ID和过渡时长
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



# 小键盘控制世界切换
func _input(event): 
	for i in range(10):
		if event.is_action_pressed("%d" % i):
			# assemble_world(i)
			transition_to_world(i)
			break



func assemble_world(world_id: int) -> void:

	if world_id < 0 or world_id >= world_defs.size():
		print("[WORLD ASSEMBLER] Invalid world_id: %d" % world_id)
		return
	
	world_changing.emit(world_id, transition_duration) # 发出世界切换信号
	is_transitioning = true

	var target_world: WorldDef = null

	target_world = world_defs[world_id]
	_defs_to_scene(target_world) # 将world def的参数应用到场景节点上
	_start_manual_scroll() # 启动手动滚动的层
	current_world_id = world_id

	world_changed.emit(current_world_id) # 发出世界切换信号，供其他系统（如角色状态机）响应
	is_transitioning = false



func transition_to_world(target_world_id: int,
	sub_world_id: int = -1, # 可选的子世界ID，默认为-1表示未指定
	sub_world_weight: float = 0.0 # 可选的子世界权重，范围0.0-1.0，默认为0.0表示未指定
	) -> void:
	
	if is_transitioning:
		print("[WORLD ASSEMBLER] Already transitioning, ignoring new transition request")
		return
	
	if target_world_id < 0 or target_world_id >= world_defs.size():
		print("[WORLD ASSEMBLER] Invalid world_id: %d" % target_world_id)
		return

	
	world_changing.emit(target_world_id, transition_duration) # 发出世界切换信号
	is_transitioning = true

	var target_world: WorldDef = world_defs[target_world_id]
	var sub_world: WorldDef = world_defs[sub_world_id]


		
	if target_world_id != current_world_id:

		# Parallex2D节点透明度开始渐变
		var tween := create_tween()
		tween.tween_property(_sky.get_child(1), "modulate:a", 0.0, transition_duration/2)
		tween.parallel().tween_property(_moon.get_child(1), "modulate:a", 0.0, transition_duration/2)
		tween.parallel().tween_property(_land.get_child(1), "modulate:a", 0.0, transition_duration/2)
		tween.parallel().tween_property(_sea.get_child(1), "modulate:a", 0.0, transition_duration/2)

		# 同时moon开始移出场景，新的moon移入场景
		var moon_main = _moon.get_child(0)
		var center: Vector2 = _moon.scroll_offset # 公转中心（Moon 本地）
		var r: Vector2 = moon_main.position - center # 半径向量（Moon 本地）
		var start_angle := r.angle()
		var end_angle := start_angle - PI
		var return_angle := start_angle
		tween.parallel().tween_method(
			func(a: float) -> void:
				# 保持半径长度不变，绕 center 旋转
				moon_main.position = center + Vector2(cos(a), sin(a)) * r.length(),
			start_angle,
			end_angle,
			transition_duration/2
		).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		
		# moon移出的同时，effect也刚好透明度变为0，moon和effect的texture切换 _defs_to_scene(target_world, 1)
		tween.tween_callback(func() -> void: 
			_defs_to_scene(target_world, 1, sub_world, sub_world_weight) # 切换到新世界的参数（渐变切换）
			_start_manual_scroll(1)
			)
		
		# moon转回来，texture的颜色变化，effect透明度逐渐变为1
		tween.tween_property(_sky.get_child(0), "modulate", target_world.sky_main_color, transition_duration/2)
		tween.parallel().tween_property(_moon.get_child(0), "modulate", target_world.moon_main_color, transition_duration/2)
		tween.parallel().tween_property(_land.get_child(0), "modulate", target_world.land_main_color, transition_duration/2)
		tween.parallel().tween_property(_sea.get_child(0), "modulate", target_world.sea_main_color, transition_duration/2)
		tween.parallel().tween_property(_sky.get_child(1), "modulate:a", 1.0, transition_duration/2)
		tween.parallel().tween_property(_moon.get_child(1), "modulate:a", 1.0, transition_duration/2)
		tween.parallel().tween_property(_land.get_child(1), "modulate:a", 1.0, transition_duration/2)
		tween.parallel().tween_property(_sea.get_child(1), "modulate:a", 1.0, transition_duration/2)
		tween.parallel().tween_method(
			func(a: float) -> void:
				# 保持半径长度不变，绕 center 旋转
				moon_main.position = center + Vector2(cos(a), sin(a)) * r.length(),
			end_angle,
			return_angle,
			transition_duration/2
		).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		# 同时非Parallex2D节点开始改变（新进素材，间隔，位置）
		# tween.tween_callback(func() -> void:_start_manual_scroll(1)) # 渐变切换
		
		current_world_id = target_world_id

		tween.tween_callback(func() -> void: 
			world_changed.emit(current_world_id) # 发出世界切换信号，供其他系统（如角色状态机）响应
			is_transitioning = false
			)
	
	else:
		_defs_to_scene(target_world, 1, sub_world, sub_world_weight) # 切换到新世界的参数（渐变切换）
		_start_manual_scroll(1)
		world_changed.emit(current_world_id)
		is_transitioning = false

	



func _defs_to_scene(current_world: WorldDef, mode: int = 0, sub_world: WorldDef = null, sub_world_weight: float = 0.0) -> void: # mode: 0直接切换，1渐变切换
	if mode == 0:
		_sky.repeat_size = current_world.sky_repeat_size
		_sky.autoscroll = current_world.sky_scroll_speed
		_sky.get_child(0).texture = current_world.sky_main_texture
		_sky.get_child(0).modulate = current_world.sky_main_color
		_sky.get_child(1).modulate = current_world.sky_effect_color
	_sky.get_child(1).texture = current_world.sky_effect_texture
	
	if mode == 0:
		_moon.repeat_size = current_world.moon_repeat_size
		_moon.autoscroll = current_world.moon_scroll_speed
		_moon.get_child(0).modulate = current_world.moon_main_color
		_moon.get_child(1).modulate = current_world.moon_effect_color
	_moon.get_child(0).texture = current_world.moon_main_texture
	_moon.get_child(1).texture = current_world.moon_effect_texture
	

	_far_1.scroll_speed = current_world.far_1_scroll_speed
	_far_1.spawn_scale = current_world.far_1_spwan_scale
	_far_1.spawn_position = current_world.far_1_spawn_position
	_far_1.spawn_cooldown = current_world.far_1_spwan_cooldown
	_far_1.spawn_randomness = current_world.far_1_spwan_randomness
	_far_1.textures_0 = current_world.far_0_textures
	_far_1.color_0 = current_world.far_0_color
	_far_1.textures = current_world.far_1_textures
	_far_1.color = current_world.far_1_colors
	_far_1.spawn_scale_0 = current_world.far_0_spwan_scale
	_far_1.spawn_position_0 = current_world.far_0_spawn_position
	# _far_1.spawn_cooldown_0 = current_world.far_0_spwan_cooldown
	_far_1.spawn_randomness_0 = current_world.far_0_spwan_randomness
	if sub_world != null:
		_far_1.texture_0_sub = sub_world.far_0_textures
		_far_1.spawn_position_0_sub = sub_world.far_0_spawn_position
		_far_1.spawn_scale_0_sub = sub_world.far_0_spwan_scale
		_far_1.texture_sub = sub_world.far_1_textures
		_far_1.spawn_position_sub = sub_world.far_1_spawn_position
		_far_1.spawn_scale_sub = sub_world.far_1_spwan_scale
		_far_1.weight_sub = sub_world_weight

	_far_2.scroll_speed = current_world.far_2_scroll_speed
	_far_2.spawn_scale = current_world.far_2_spwan_scale
	_far_2.spawn_position = current_world.far_2_spawn_position
	_far_2.spawn_cooldown = current_world.far_2_spwan_cooldown
	_far_2.spawn_randomness = current_world.far_2_spwan_randomness
	_far_2.textures_0 = current_world.far_0_textures
	_far_2.color_0 = current_world.far_0_color
	_far_2.textures = current_world.far_2_textures
	_far_2.color = current_world.far_2_colors
	_far_2.spawn_scale_0 = current_world.far_0_spwan_scale
	_far_2.spawn_position_0 = current_world.far_0_spawn_position
	# _far_2.spawn_cooldown_0 = current_world.far_0_spwan_cooldown
	_far_2.spawn_randomness_0 = current_world.far_0_spwan_randomness
	if sub_world != null:
		_far_2.texture_0_sub = sub_world.far_0_textures
		_far_2.spawn_position_0_sub = sub_world.far_0_spawn_position
		_far_2.spawn_scale_0_sub = sub_world.far_0_spwan_scale
		_far_2.texture_sub = sub_world.far_2_textures
		_far_2.spawn_position_sub = sub_world.far_2_spawn_position
		_far_2.spawn_scale_sub = sub_world.far_2_spwan_scale
		_far_2.weight_sub = sub_world_weight

	if mode == 0:
		_land.repeat_size = current_world.land_repeat_size
		_land.autoscroll = current_world.land_scroll_speed
		_land.get_child(0).texture = current_world.land_main_texture
		_land.get_child(0).modulate = current_world.land_main_color
		_land.get_child(1).modulate = current_world.land_effect_color
	_land.get_child(1).texture = current_world.land_effect_texture
	
	if mode == 0:
		_sea.repeat_size = current_world.sea_repeat_size
		_sea.autoscroll = current_world.sea_scroll_speed
		_sea.get_child(0).texture = current_world.sea_main_texture
		_sea.get_child(0).modulate = current_world.sea_main_color
		_sea.get_child(1).modulate = current_world.sea_effect_color
	_sea.get_child(1).texture = current_world.sea_effect_texture
	
	_mid_1.scroll_speed = current_world.mid_1_scroll_speed
	_mid_1.spawn_scale = current_world.mid_1_spwan_scale
	_mid_1.spawn_position = current_world.mid_1_spawn_position
	_mid_1.spawn_cooldown = current_world.mid_1_spwan_cooldown
	_mid_1.spawn_randomness = current_world.mid_1_spwan_randomness
	_mid_1.textures_0 = current_world.mid_0_textures
	_mid_1.color_0 = current_world.mid_0_color
	_mid_1.textures = current_world.mid_1_textures
	_mid_1.color = current_world.mid_1_colors
	_mid_1.spawn_scale_0 = current_world.mid_0_spwan_scale
	_mid_1.spawn_position_0 = current_world.mid_0_spawn_position
	# _mid_1.spawn_cooldown_0 = current_world.mid_0_spwan_cooldown
	_mid_1.spawn_randomness_0 = current_world.mid_0_spwan_randomness
	if sub_world != null:
		_mid_1.texture_0_sub = sub_world.mid_0_textures
		_mid_1.spawn_position_0_sub = sub_world.mid_0_spawn_position
		_mid_1.spawn_scale_0_sub = sub_world.mid_0_spwan_scale
		_mid_1.texture_sub = sub_world.mid_1_textures
		_mid_1.spawn_position_sub = sub_world.mid_1_spawn_position
		_mid_1.spawn_scale_sub = sub_world.mid_1_spwan_scale
		_mid_1.weight_sub = sub_world_weight

	_mid_2.scroll_speed = current_world.mid_2_scroll_speed
	_mid_2.spawn_scale = current_world.mid_2_spwan_scale
	_mid_2.spawn_position = current_world.mid_2_spawn_position
	_mid_2.spawn_cooldown = current_world.mid_2_spwan_cooldown
	_mid_2.spawn_randomness = current_world.mid_2_spwan_randomness
	_mid_2.textures_0 = current_world.mid_0_textures
	_mid_2.color_0 = current_world.mid_0_color
	_mid_2.textures = current_world.mid_2_textures
	_mid_2.color = current_world.mid_2_colors
	_mid_2.spawn_scale_0 = current_world.mid_0_spwan_scale
	_mid_2.spawn_position_0 = current_world.mid_0_spawn_position
	# _mid_2.spawn_cooldown_0 = current_world.mid_0_spwan_cooldown
	_mid_2.spawn_randomness_0 = current_world.mid_0_spwan_randomness
	if sub_world != null:
		_mid_2.texture_0_sub = sub_world.mid_0_textures
		_mid_2.spawn_position_0_sub = sub_world.mid_0_spawn_position
		_mid_2.spawn_scale_0_sub = sub_world.mid_0_spwan_scale
		_mid_2.texture_sub = sub_world.mid_2_textures
		_mid_2.spawn_position_sub = sub_world.mid_2_spawn_position
		_mid_2.spawn_scale_sub = sub_world.mid_2_spwan_scale
		_mid_2.weight_sub = sub_world_weight

	_front_1.scroll_speed = current_world.front_1_scroll_speed
	_front_1.spawn_scale = current_world.front_1_spwan_scale
	_front_1.spawn_position = current_world.front_1_spawn_position
	_front_1.spawn_cooldown = current_world.front_1_spwan_cooldown
	_front_1.spawn_randomness = current_world.front_1_spwan_randomness
	_front_1.textures_0 = current_world.front_0_textures
	_front_1.color_0 = current_world.front_0_color
	_front_1.textures = current_world.front_1_textures
	_front_1.color = current_world.front_1_colors
	_front_1.spawn_scale_0 = current_world.front_0_spwan_scale
	_front_1.spawn_position_0 = current_world.front_0_spawn_position
	# _front_1.spawn_cooldown_0 = current_world.front_0_spwan_cooldown
	_front_1.spawn_randomness_0 = current_world.front_0_spwan_randomness
	if sub_world != null:
		_front_1.texture_0_sub = sub_world.front_0_textures
		_front_1.spawn_position_0_sub = sub_world.front_0_spawn_position
		_front_1.spawn_scale_0_sub = sub_world.front_0_spwan_scale
		_front_1.texture_sub = sub_world.front_1_textures
		_front_1.spawn_position_sub = sub_world.front_1_spawn_position
		_front_1.spawn_scale_sub = sub_world.front_1_spwan_scale
		_front_1.weight_sub = sub_world_weight

	_front_2.scroll_speed = current_world.front_2_scroll_speed
	_front_2.spawn_scale = current_world.front_2_spwan_scale
	_front_2.spawn_position = current_world.front_2_spawn_position
	_front_2.spawn_cooldown = current_world.front_2_spwan_cooldown
	_front_2.spawn_randomness = current_world.front_2_spwan_randomness
	_front_2.textures_0 = current_world.front_0_textures
	_front_2.color_0 = current_world.front_0_color
	_front_2.textures = current_world.front_2_textures
	_front_2.color = current_world.front_2_colors
	_front_2.spawn_scale_0 = current_world.front_0_spwan_scale
	_front_2.spawn_position_0 = current_world.front_0_spawn_position
	# _front_2.spawn_cooldown_0 = current_world.front_0_spwan_cooldown
	_front_2.spawn_randomness_0 = current_world.front_0_spwan_randomness
	if sub_world != null:
		_front_2.texture_0_sub = sub_world.front_0_textures
		_front_2.spawn_position_0_sub = sub_world.front_0_spawn_position
		_front_2.spawn_scale_0_sub = sub_world.front_0_spwan_scale
		_front_2.texture_sub = sub_world.front_2_textures
		_front_2.spawn_position_sub = sub_world.front_2_spawn_position
		_front_2.spawn_scale_sub = sub_world.front_2_spwan_scale
		_front_2.weight_sub = sub_world_weight

	_light.repeat_size = current_world.light_repeat_size
	_light.autoscroll = current_world.light_scroll_speed
	_light.get_child(0).texture = current_world.light_main_texture
	_light.get_child(0).modulate = current_world.light_main_color
	_light.get_child(1).texture = current_world.light_effect_texture
	_light.get_child(1).modulate = current_world.light_effect_color

	#print("[WORLD ASSEMBLER] World assembled with ID: %d" % current_world_id)


func _start_manual_scroll(mode: int = 0) -> void: # mode: 0直接切换，1渐变切换
	_far_1.start_manual_scroll(mode)
	_far_2.start_manual_scroll(mode)
	_mid_1.start_manual_scroll(mode)
	_mid_2.start_manual_scroll(mode)
	_front_1.start_manual_scroll(mode)
	_front_2.start_manual_scroll(mode)
