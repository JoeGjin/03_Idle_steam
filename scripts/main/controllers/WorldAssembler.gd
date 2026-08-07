# 世界组装器，负责将世界环境定义资源转换为实际的场景节点
# 直接控制图像资源切换，音频资源通过signal通知main，main再调用AudioController进行切换

extends Node
class_name WorldAssembler



@export var tag_scenes: Dictionary[Tags.Tag, TagSceneDef] = {}

@export var transition_duration: float = 30.0 # 世界切换的过渡动画时长（秒）

@onready var world_root: Node2D = %WorldRoot
@onready var memory_controller: MemoryController = %MemoryController

# var current_world_id: int = 0 # 当前世界ID，初始为-1表示未设置
var is_transitioning: bool = false # 是否正在进行世界切换过渡

var unhandled_letter_tags: Array = [] # 存储未处理的标签，供发送时使用

var banned_texture: String = "" # 单个槽位，记录最近一次未选择的texture名称



@onready var _sky: Parallax2D = %Sky
@onready var _poi: ManualParallax = %POI
@onready var _ground: Parallax2D = %Ground

@onready var _cloud_1: ManualParallax = %Cloud_1
@onready var _landform_1: ManualParallax = %Landform_1
@onready var _component_1: ManualParallax = %Component_1

@onready var _cloud_2: ManualParallax = %Cloud_2
@onready var _landform_2: ManualParallax = %Landform_2
@onready var _component_2: ManualParallax = %Component_2

@onready var _cloud_3: ManualParallax = %Cloud_3
@onready var _landform_3: ManualParallax = %Landform_3
@onready var _component_3: ManualParallax = %Component_3

# @onready var _pet: Node2D = %Pet

@onready var _cloud_4: ManualParallax = %Cloud_4
@onready var _landform_4: ManualParallax = %Landform_4
@onready var _component_4: ManualParallax = %Component_4

@onready var _cloud_5: ManualParallax = %Cloud_5
@onready var _landform_5: ManualParallax = %Landform_5
@onready var _component_5: ManualParallax = %Component_5


var _clouds: Array[ManualParallax] = []
var _landforms: Array[ManualParallax] = []
var _components: Array[ManualParallax] = []
# @onready var _world_player: AnimationPlayer = %WorldPlayer



# signal world_changing(new_world_id: int, transition_duration: float) # 定义世界切换信号，参数为新的世界ID和过渡时长
# signal world_changed(new_world_id: int)





func _ready() -> void:
    _build_tag_scenes() # 构建tag_scenes字典

func _build_tag_scenes() -> void:
    const TAG_SCENE_DEFS_PATH := "res://scripts/main/controllers/tagscene/defs"

    tag_scenes.clear()

    var directory := DirAccess.open(TAG_SCENE_DEFS_PATH)
    if directory == null:
        push_warning("[WORLD ASSEMBLER] 无法打开 TagSceneDef 目录：%s" % TAG_SCENE_DEFS_PATH)
        return

    directory.list_dir_begin()
    var file_name := directory.get_next()
    while not file_name.is_empty():
        if not directory.current_is_dir() and file_name.get_extension() == "tres":
            var resource_path := TAG_SCENE_DEFS_PATH.path_join(file_name)
            var tag_scene_def := load(resource_path) as TagSceneDef
            if tag_scene_def == null:
                push_warning("[WORLD ASSEMBLER] 无法加载 TagSceneDef 资源：%s" % resource_path)
            else:
                tag_scenes[tag_scene_def.tag_name] = tag_scene_def

        file_name = directory.get_next()
    directory.list_dir_end()



func _initialize_manual_parallax_layers() -> void:
    # 初始化所有手动滚动的Parallax层
    _poi.pool = MemoryDef.Pool.POI

    _cloud_1.pool = MemoryDef.Pool.CLOUD
    _clouds.append(_cloud_1)

    _landform_1.pool = MemoryDef.Pool.LANDFORM_FAR
    _landforms.append(_landform_1)

    _component_1.pool = MemoryDef.Pool.COMPONENT_FAR
    _components.append(_component_1)

    _cloud_2.pool = MemoryDef.Pool.CLOUD
    _clouds.append(_cloud_2)

    _landform_2.pool = MemoryDef.Pool.LANDFORM_MID
    _landforms.append(_landform_2)

    _component_2.pool = MemoryDef.Pool.COMPONENT_MID
    _components.append(_component_2)

    _cloud_3.pool = MemoryDef.Pool.CLOUD
    _clouds.append(_cloud_3)

    _landform_3.pool = MemoryDef.Pool.LANDFORM_MID
    _landforms.append(_landform_3)

    _component_3.pool = MemoryDef.Pool.COMPONENT_MID
    _components.append(_component_3)

    _cloud_4.pool = MemoryDef.Pool.CLOUD
    _clouds.append(_cloud_4)

    _landform_4.pool = MemoryDef.Pool.LANDFORM_FRONT
    _landforms.append(_landform_4)

    _component_4.pool = MemoryDef.Pool.COMPONENT_FRONT
    _components.append(_component_4)

    _cloud_5.pool = MemoryDef.Pool.CLOUD
    _clouds.append(_cloud_5)

    _landform_5.pool = MemoryDef.Pool.LANDFORM_FRONT
    _landforms.append(_landform_5)

    _component_5.pool = MemoryDef.Pool.COMPONENT_FRONT
    _components.append(_component_5)



func _update_def_to_scene(weighted_tags: Dictionary[Tags.Tag, float]) -> void: 
    # weighted_tags: {MYSTERIOUS: 0.5, HOLY: 0.3, BARREN: 0.2}
    # mode: 0直接切换(或初始化场景)，1渐变切换
    var main_tag: Tags.Tag = weighted_tags.keys()[0] # 获取权重最高的标签作为主标签
    var main_tag_scene := tag_scenes[main_tag]
    
    
    _sky.sky_main_color = main_tag_scene.sky_main_color
    _sky.sky_star_texture = main_tag_scene.sky_star_texture
    _sky.sky_star_color = main_tag_scene.sky_star_color
    _sky.sky_effect_texture = main_tag_scene.sky_effect_texture
    _sky.sky_effect_color = main_tag_scene.sky_effect_color


    _poi.color = main_tag_scene.poi_color
    _poi.scroll_speed = main_tag_scene.poi_scroll_speed


    _ground.ground_main_color = main_tag_scene.ground_main_color
    _ground.ground_effect_texture = main_tag_scene.ground_effect_texture
    _ground.ground_effect_color = main_tag_scene.ground_effect_color

    var clouds_count = _clouds.size()
    for i in clouds_count:
        var cloud = _clouds[i]
        cloud.color = main_tag_scene.cloud_color
        var t = float(i) / (clouds_count - 1)
        var speed_ratio = lerp(1.0, main_tag_scene.landform_speed_ratio, t) # 根据云层索引调整速度比率
        cloud.scroll_speed = main_tag_scene.cloud_scroll_speed * speed_ratio

    var landforms_count = _landforms.size()
    for i in landforms_count:
        var landform = _landforms[i]
        landform.color = main_tag_scene.landform_light_color.lerp(
            main_tag_scene.landform_dark_color,
            i / 4.0
            )
        var t = float(i) / (landforms_count - 1)
        var speed_ratio = lerp(1.0, main_tag_scene.landform_speed_ratio, t) # 根据地形层索引调整速度比率
        landform.scroll_speed = main_tag_scene.landform_scroll_speed * speed_ratio
    
    var components_count = _components.size()
    for i in components_count:
        var component = _components[i]
        component.color = main_tag_scene.component_color
        var t = float(i) / (components_count - 1)
        var speed_ratio = lerp(1.0, main_tag_scene.component_speed_ratio, t) # 根据组件层索引调整速度比率
        component.scroll_speed = main_tag_scene.component_scroll_speed * speed_ratio








# func _defs_to_scene(current_world: WorldDef, mode: int = 0, sub_world: WorldDef = null, sub_world_weight: float = 0.0) -> void: # mode: 0直接切换，1渐变切换
# 	if mode == 0:
# 		_sky.repeat_size = current_world.sky_repeat_size
# 		_sky.autoscroll = current_world.sky_scroll_speed
# 		_sky.get_child(0).texture = current_world.sky_main_texture
# 		_sky.get_child(0).modulate = current_world.sky_main_color
# 		_sky.get_child(1).modulate = current_world.sky_effect_color
# 	_sky.get_child(1).texture = current_world.sky_effect_texture
	
# 	if mode == 0:
# 		_moon.repeat_size = current_world.moon_repeat_size
# 		_moon.autoscroll = current_world.moon_scroll_speed
# 		_moon.get_child(0).modulate = current_world.moon_main_color
# 		_moon.get_child(1).modulate = current_world.moon_effect_color
# 	_moon.get_child(0).texture = current_world.moon_main_texture
# 	_moon.get_child(1).texture = current_world.moon_effect_texture
	

# 	_far_1.scroll_speed = current_world.far_1_scroll_speed
# 	_far_1.spawn_scale = current_world.far_1_spawn_scale
# 	_far_1.spawn_position = current_world.far_1_spawn_position
# 	_far_1.spawn_cooldown = current_world.far_1_spawn_cooldown
# 	_far_1.spawn_randomness = current_world.far_1_spawn_randomness
# 	_far_1.textures_0 = current_world.far_0_textures
# 	_far_1.color_0 = current_world.far_0_color
# 	_far_1.textures = current_world.far_1_textures
# 	_far_1.color = current_world.far_1_color
# 	_far_1.spawn_scale_0 = current_world.far_0_spawn_scale
# 	_far_1.spawn_position_0 = current_world.far_0_spawn_position
# 	# _far_1.spawn_cooldown_0 = current_world.far_0_spawn_cooldown
# 	_far_1.spawn_randomness_0 = current_world.far_0_spawn_randomness
# 	if sub_world != null:
# 		_far_1.texture_0_sub = sub_world.far_0_textures
# 		_far_1.spawn_position_0_sub = sub_world.far_0_spawn_position
# 		_far_1.spawn_scale_0_sub = sub_world.far_0_spawn_scale
# 		_far_1.texture_sub = sub_world.far_1_textures
# 		_far_1.spawn_position_sub = sub_world.far_1_spawn_position
# 		_far_1.spawn_scale_sub = sub_world.far_1_spawn_scale
# 		_far_1.weight_sub = sub_world_weight

# 	_far_2.scroll_speed = current_world.far_2_scroll_speed
# 	_far_2.spawn_scale = current_world.far_2_spawn_scale
# 	_far_2.spawn_position = current_world.far_2_spawn_position
# 	_far_2.spawn_cooldown = current_world.far_2_spawn_cooldown
# 	_far_2.spawn_randomness = current_world.far_2_spawn_randomness
# 	_far_2.textures_0 = current_world.far_0_textures
# 	_far_2.color_0 = current_world.far_0_color
# 	_far_2.textures = current_world.far_2_textures
# 	_far_2.color = current_world.far_2_color
# 	_far_2.spawn_scale_0 = current_world.far_0_spawn_scale
# 	_far_2.spawn_position_0 = current_world.far_0_spawn_position
# 	# _far_2.spawn_cooldown_0 = current_world.far_0_spawn_cooldown
# 	_far_2.spawn_randomness_0 = current_world.far_0_spawn_randomness
# 	if sub_world != null:
# 		_far_2.texture_0_sub = sub_world.far_0_textures
# 		_far_2.spawn_position_0_sub = sub_world.far_0_spawn_position
# 		_far_2.spawn_scale_0_sub = sub_world.far_0_spawn_scale
# 		_far_2.texture_sub = sub_world.far_2_textures
# 		_far_2.spawn_position_sub = sub_world.far_2_spawn_position
# 		_far_2.spawn_scale_sub = sub_world.far_2_spawn_scale
# 		_far_2.weight_sub = sub_world_weight

# 	if mode == 0:
# 		_land.repeat_size = current_world.land_repeat_size
# 		_land.autoscroll = current_world.land_scroll_speed
# 		_land.get_child(0).texture = current_world.land_main_texture
# 		_land.get_child(0).modulate = current_world.land_main_color
# 		_land.get_child(1).modulate = current_world.land_effect_color
# 	_land.get_child(1).texture = current_world.land_effect_texture
	
# 	if mode == 0:
# 		_sea.repeat_size = current_world.sea_repeat_size
# 		_sea.autoscroll = current_world.sea_scroll_speed
# 		_sea.get_child(0).texture = current_world.sea_main_texture
# 		_sea.get_child(0).modulate = current_world.sea_main_color
# 		_sea.get_child(1).modulate = current_world.sea_effect_color
# 	_sea.get_child(1).texture = current_world.sea_effect_texture
	
# 	_mid_1.scroll_speed = current_world.mid_1_scroll_speed
# 	_mid_1.spawn_scale = current_world.mid_1_spawn_scale
# 	_mid_1.spawn_position = current_world.mid_1_spawn_position
# 	_mid_1.spawn_cooldown = current_world.mid_1_spawn_cooldown
# 	_mid_1.spawn_randomness = current_world.mid_1_spawn_randomness
# 	_mid_1.textures_0 = current_world.mid_0_textures
# 	_mid_1.color_0 = current_world.mid_0_color
# 	_mid_1.textures = current_world.mid_1_textures
# 	_mid_1.color = current_world.mid_1_color
# 	_mid_1.spawn_scale_0 = current_world.mid_0_spawn_scale
# 	_mid_1.spawn_position_0 = current_world.mid_0_spawn_position
# 	# _mid_1.spawn_cooldown_0 = current_world.mid_0_spawn_cooldown
# 	_mid_1.spawn_randomness_0 = current_world.mid_0_spawn_randomness
# 	if sub_world != null:
# 		_mid_1.texture_0_sub = sub_world.mid_0_textures
# 		_mid_1.spawn_position_0_sub = sub_world.mid_0_spawn_position
# 		_mid_1.spawn_scale_0_sub = sub_world.mid_0_spawn_scale
# 		_mid_1.texture_sub = sub_world.mid_1_textures
# 		_mid_1.spawn_position_sub = sub_world.mid_1_spawn_position
# 		_mid_1.spawn_scale_sub = sub_world.mid_1_spawn_scale
# 		_mid_1.weight_sub = sub_world_weight

# 	_mid_2.scroll_speed = current_world.mid_2_scroll_speed
# 	_mid_2.spawn_scale = current_world.mid_2_spawn_scale
# 	_mid_2.spawn_position = current_world.mid_2_spawn_position
# 	_mid_2.spawn_cooldown = current_world.mid_2_spawn_cooldown
# 	_mid_2.spawn_randomness = current_world.mid_2_spawn_randomness
# 	_mid_2.textures_0 = current_world.mid_0_textures
# 	_mid_2.color_0 = current_world.mid_0_color
# 	_mid_2.textures = current_world.mid_2_textures
# 	_mid_2.color = current_world.mid_2_color
# 	_mid_2.spawn_scale_0 = current_world.mid_0_spawn_scale
# 	_mid_2.spawn_position_0 = current_world.mid_0_spawn_position
# 	# _mid_2.spawn_cooldown_0 = current_world.mid_0_spawn_cooldown
# 	_mid_2.spawn_randomness_0 = current_world.mid_0_spawn_randomness
# 	if sub_world != null:
# 		_mid_2.texture_0_sub = sub_world.mid_0_textures
# 		_mid_2.spawn_position_0_sub = sub_world.mid_0_spawn_position
# 		_mid_2.spawn_scale_0_sub = sub_world.mid_0_spawn_scale
# 		_mid_2.texture_sub = sub_world.mid_2_textures
# 		_mid_2.spawn_position_sub = sub_world.mid_2_spawn_position
# 		_mid_2.spawn_scale_sub = sub_world.mid_2_spawn_scale
# 		_mid_2.weight_sub = sub_world_weight

# 	_front_1.scroll_speed = current_world.front_1_scroll_speed
# 	_front_1.spawn_scale = current_world.front_1_spawn_scale
# 	_front_1.spawn_position = current_world.front_1_spawn_position
# 	_front_1.spawn_cooldown = current_world.front_1_spawn_cooldown
# 	_front_1.spawn_randomness = current_world.front_1_spawn_randomness
# 	_front_1.textures_0 = current_world.front_0_textures
# 	_front_1.color_0 = current_world.front_0_color
# 	_front_1.textures = current_world.front_1_textures
# 	_front_1.color = current_world.front_1_color
# 	_front_1.spawn_scale_0 = current_world.front_0_spawn_scale
# 	_front_1.spawn_position_0 = current_world.front_0_spawn_position
# 	# _front_1.spawn_cooldown_0 = current_world.front_0_spawn_cooldown
# 	_front_1.spawn_randomness_0 = current_world.front_0_spawn_randomness
# 	if sub_world != null:
# 		_front_1.texture_0_sub = sub_world.front_0_textures
# 		_front_1.spawn_position_0_sub = sub_world.front_0_spawn_position
# 		_front_1.spawn_scale_0_sub = sub_world.front_0_spawn_scale
# 		_front_1.texture_sub = sub_world.front_1_textures
# 		_front_1.spawn_position_sub = sub_world.front_1_spawn_position
# 		_front_1.spawn_scale_sub = sub_world.front_1_spawn_scale
# 		_front_1.weight_sub = sub_world_weight

# 	_front_2.scroll_speed = current_world.front_2_scroll_speed
# 	_front_2.spawn_scale = current_world.front_2_spawn_scale
# 	_front_2.spawn_position = current_world.front_2_spawn_position
# 	_front_2.spawn_cooldown = current_world.front_2_spawn_cooldown
# 	_front_2.spawn_randomness = current_world.front_2_spawn_randomness
# 	_front_2.textures_0 = current_world.front_0_textures
# 	_front_2.color_0 = current_world.front_0_color
# 	_front_2.textures = current_world.front_2_textures
# 	_front_2.color = current_world.front_2_color
# 	_front_2.spawn_scale_0 = current_world.front_0_spawn_scale
# 	_front_2.spawn_position_0 = current_world.front_0_spawn_position
# 	# _front_2.spawn_cooldown_0 = current_world.front_0_spawn_cooldown
# 	_front_2.spawn_randomness_0 = current_world.front_0_spawn_randomness
# 	if sub_world != null:
# 		_front_2.texture_0_sub = sub_world.front_0_textures
# 		_front_2.spawn_position_0_sub = sub_world.front_0_spawn_position
# 		_front_2.spawn_scale_0_sub = sub_world.front_0_spawn_scale
# 		_front_2.texture_sub = sub_world.front_2_textures
# 		_front_2.spawn_position_sub = sub_world.front_2_spawn_position
# 		_front_2.spawn_scale_sub = sub_world.front_2_spawn_scale
# 		_front_2.weight_sub = sub_world_weight

# 	_light.repeat_size = current_world.light_repeat_size
# 	_light.autoscroll = current_world.light_scroll_speed
# 	_light.get_child(0).texture = current_world.light_main_texture
# 	_light.get_child(0).modulate = current_world.light_main_color
# 	_light.get_child(1).texture = current_world.light_effect_texture
# 	_light.get_child(1).modulate = current_world.light_effect_color

# 	#print("[WORLD ASSEMBLER] World assembled with ID: %d" % current_world_id)






# func assemble_world(world_id: int) -> void:

# 	if world_id < 0 or world_id >= world_defs.size():
# 		print("[WORLD ASSEMBLER] Invalid world_id: %d" % world_id)
# 		return
	
# 	world_changing.emit(world_id, transition_duration) # 发出世界切换信号
# 	is_transitioning = true

# 	var target_world: WorldDef = null

# 	target_world = world_defs[world_id]
# 	_defs_to_scene(target_world) # 将world def的参数应用到场景节点上
# 	_start_manual_scroll() # 启动手动滚动的层
# 	current_world_id = world_id

# 	world_changed.emit(current_world_id) # 发出世界切换信号，供其他系统（如角色状态机）响应
# 	is_transitioning = false



# func transition_to_world(target_world_id: int,
# 	sub_world_id: int = -1, # 可选的子世界ID，默认为-1表示未指定
# 	sub_world_weight: float = 0.0 # 可选的子世界权重，范围0.0-1.0，默认为0.0表示未指定
# 	) -> void:
	
# 	if is_transitioning:
# 		print("[WORLD ASSEMBLER] Already transitioning, ignoring new transition request")
# 		return
	
# 	if target_world_id < 0 or target_world_id >= world_defs.size():
# 		print("[WORLD ASSEMBLER] Invalid world_id: %d" % target_world_id)
# 		return

	
# 	var target_world: WorldDef = world_defs[target_world_id]
# 	var sub_world: WorldDef = world_defs[sub_world_id]


	
# 	if target_world_id != current_world_id: # 只有在切换到不同世界时才执行过渡动画
		
# 		world_changing.emit(target_world_id, transition_duration) # 发出世界切换信号
# 		is_transitioning = true


# 		# Parallex2D节点透明度开始渐变
# 		var tween := create_tween()
# 		tween.tween_property(_sky.get_child(1), "modulate:a", 0.0, transition_duration/2)
# 		tween.parallel().tween_property(_moon.get_child(1), "modulate:a", 0.0, transition_duration/2)
# 		tween.parallel().tween_property(_land.get_child(1), "modulate:a", 0.0, transition_duration/2)
# 		tween.parallel().tween_property(_sea.get_child(1), "modulate:a", 0.0, transition_duration/2)

# 		# 同时moon开始移出场景，新的moon移入场景
# 		var moon_main = _moon.get_child(0)
# 		var center: Vector2 = _moon.scroll_offset # 公转中心（Moon 本地）
# 		var r: Vector2 = moon_main.position - center # 半径向量（Moon 本地）
# 		var start_angle := r.angle()
# 		var end_angle := start_angle - PI
# 		var return_angle := start_angle
# 		tween.parallel().tween_method(
# 			func(a: float) -> void:
# 				# 保持半径长度不变，绕 center 旋转
# 				moon_main.position = center + Vector2(cos(a), sin(a)) * r.length(),
# 			start_angle,
# 			end_angle,
# 			transition_duration/2
# 		).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
		
# 		# moon移出的同时，effect也刚好透明度变为0，moon和effect的texture切换 _defs_to_scene(target_world, 1)
# 		tween.tween_callback(func() -> void: 
# 			_defs_to_scene(target_world, 1, sub_world, sub_world_weight) # 切换到新世界的参数（渐变切换）
# 			_start_manual_scroll(1)
# 			)
		
# 		# moon转回来，texture的颜色变化，effect透明度逐渐变为1
# 		tween.tween_property(_sky.get_child(0), "modulate", target_world.sky_main_color, transition_duration/2)
# 		tween.parallel().tween_property(_moon.get_child(0), "modulate", target_world.moon_main_color, transition_duration/2)
# 		tween.parallel().tween_property(_land.get_child(0), "modulate", target_world.land_main_color, transition_duration/2)
# 		tween.parallel().tween_property(_sea.get_child(0), "modulate", target_world.sea_main_color, transition_duration/2)
# 		tween.parallel().tween_property(_sky.get_child(1), "modulate:a", 1.0, transition_duration/2)
# 		tween.parallel().tween_property(_moon.get_child(1), "modulate:a", 1.0, transition_duration/2)
# 		tween.parallel().tween_property(_land.get_child(1), "modulate:a", 1.0, transition_duration/2)
# 		tween.parallel().tween_property(_sea.get_child(1), "modulate:a", 1.0, transition_duration/2)
# 		tween.parallel().tween_method(
# 			func(a: float) -> void:
# 				# 保持半径长度不变，绕 center 旋转
# 				moon_main.position = center + Vector2(cos(a), sin(a)) * r.length(),
# 			end_angle,
# 			return_angle,
# 			transition_duration/2
# 		).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
# 		# 同时非Parallex2D节点开始改变（新进素材，间隔，位置）
# 		# tween.tween_callback(func() -> void:_start_manual_scroll(1)) # 渐变切换
		
# 		current_world_id = target_world_id

# 		tween.tween_callback(func() -> void: 
# 			world_changed.emit(current_world_id) # 发出世界切换信号，供其他系统（如角色状态机）响应
# 			is_transitioning = false
# 			)
	
# 	else: # 切换到同一世界但不同子世界，直接切换参数，不需要过渡动画
# 		world_changing.emit(target_world_id, 0) # 发出世界切换信号
# 		is_transitioning = true
# 		_defs_to_scene(target_world, 1, sub_world, sub_world_weight) # 切换到新世界的参数（渐变切换）
# 		# _start_manual_scroll(1)
# 		world_changed.emit(current_world_id)
# 		is_transitioning = false



# func immediate_spawn(texture_name: String) -> void: # string格式为 0_frontxxx_2_1xx
# 	# 通过name来确定在哪个层生成素材
# 	var target_layer_name = texture_name.split("_")[1] # 例如 "0_front_2" -> "front"
# 	var target_sublayer_name = texture_name.split("_")[2] # 例如 "0_front_2" -> "2"
# 	# get对应的层
# 	var target_layer: ManualParallax
# 	match target_layer_name:
# 		"far":
# 			match target_sublayer_name:
# 				"1":
# 					target_layer = _far_1
# 				"2":
# 					target_layer = _far_2
# 				"0": # 如果是0层，随机选择一个层生成
# 					if randi() % 2 == 0:
# 						target_layer = _far_1
# 					else:
# 						target_layer = _far_2
# 		"mid":
# 			match target_sublayer_name:
# 				"1":
# 					target_layer = _mid_1
# 				"2":
# 					target_layer = _mid_2
# 				"0": # 如果是0层，随机选择一个层生成
# 					if randi() % 2 == 0:
# 						target_layer = _mid_1
# 					else:
# 						target_layer = _mid_2
# 		"front":
# 			match target_sublayer_name:
# 				"1":
# 					target_layer = _front_1
# 				"2":
# 					target_layer = _front_2
# 				"0": # 如果是0层，随机选择一个层生成
# 					if randi() % 2 == 0:
# 						target_layer = _front_1
# 					else:
# 						target_layer = _front_2
# 	# 从assembler层级手动生成一个新的sprite并加入场景, 需要调用对应的世界def中的参数
# 	var sprite = Sprite2D.new()
# 	sprite.texture = memory_controller.get_popup_texture_by_name(texture_name) # 通过贴图名称获取Texture2D资源
# 	var target_world_id: int = texture_name.split("_")[0].to_int() # 例如 "0_front_2" -> 0
# 	var target_world_def = world_defs[target_world_id] 
	
# 	var color_property_name: String = "%s_%s_color" % [target_layer_name, target_sublayer_name]
# 	sprite.modulate = target_world_def.get(color_property_name)
# 	var scale_property_name: String = "%s_%s_spawn_scale" % [target_layer_name, target_sublayer_name]
# 	sprite.scale = target_world_def.get(scale_property_name)
# 	var position_property_name: String = "%s_%s_spawn_position" % [target_layer_name, target_sublayer_name]
# 	sprite.position = Vector2(0, target_world_def.get(position_property_name).y)
	
# 	match target_sublayer_name:
# 		"1", "2":
# 			target_layer._objects.append(sprite)
# 		"0":
# 			target_layer._objects_0.append(sprite)
	
# 	target_layer.add_child(sprite)
# 	target_layer.animation_popup(sprite)
	
	


# func texture_banned(texture_name: String) -> bool:
# 	# 检查给定的贴图名称是否在当前世界的禁止列表中
# 	# print("[WORLD ASSEMBLER] Checking if texture '%s' is banned (banned_texture: '%s')" % [texture_name, banned_texture])
# 	return texture_name == banned_texture











# func _start_manual_scroll(mode: int = 0) -> void: # mode: 0直接切换，1渐变切换
# 	_far_1.start_manual_scroll(mode)
# 	_far_2.start_manual_scroll(mode)
# 	_mid_1.start_manual_scroll(mode)
# 	_mid_2.start_manual_scroll(mode)
# 	_front_1.start_manual_scroll(mode)
# 	_front_2.start_manual_scroll(mode)



# # 小键盘控制世界切换
# func _input(event): 
# 	for i in range(10):
# 		if event.is_action_pressed("%d" % i):
# 			# assemble_world(i)
# 			transition_to_world(i)
# 			break
