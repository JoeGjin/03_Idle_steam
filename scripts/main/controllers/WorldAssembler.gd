# 世界组装器，负责将世界环境定义资源转换为实际的场景节点
# 直接控制图像资源切换，音频资源通过signal通知main，main再调用AudioController进行切换

extends Node
class_name WorldAssembler


@onready var world_root: Node2D = %WorldRoot
@onready var memory_controller: MemoryController = %MemoryController

@export var tag_scenes: Dictionary[Tags.Tag, TagSceneDef] = {}
@export var transition_duration: float = 30.0 # 世界切换的过渡动画时长（秒）

@export var current_tag_id: int = -1 # 当前世界ID，初始为-1表示未设置
@export var is_transitioning: bool = false # 是否正在进行世界切换过渡




@onready var _sky: WorldSky = %Sky
@onready var _poi: ManualParallax = %POI
@onready var _ground: WorldGround = %Ground

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

# @onready var _world_player: AnimationPlayer = %WorldPlayer

# var unhandled_letter_tags: Array = [] # 存储未处理的标签，供发送时使用
var banned_texture: String = "" # 单个槽位，记录最近一次未选择的texture名称

var _clouds: Array[ManualParallax] = []
var _landforms: Array[ManualParallax] = []
var _components: Array[ManualParallax] = []



signal world_changing(new_tag_id: int, transition_duration: float) # 定义世界切换信号，参数为新的世界ID和过渡时长
signal world_changed(new_tag_id: int)




# 用于第一次建立场景，直接应用参数，不需要过渡动画
func assemble_world(weighted_tags: Dictionary[Tags.Tag, float]) -> void:
    if weighted_tags.is_empty():
        push_warning("[WORLD ASSEMBLER] Cannot assemble a world without weighted tags")
        return
    
    var main_tag: Tags.Tag = weighted_tags.keys()[0] # 获取权重最高的标签作为主标签

    if main_tag not in tag_scenes:
        print("[WORLD ASSEMBLER] Invalid tag: %s" % main_tag)
        return

    world_changing.emit(main_tag, transition_duration) # 发出世界切换信号
    is_transitioning = true

    current_tag_id = main_tag # 更新当前世界ID
    _update_def_to_scene(weighted_tags)
    _sky.apply_immediate()
    _ground.apply_immediate()
    _start_manual_scroll(0) # 启动手动滚动的层

    world_changed.emit(main_tag) # 发出世界切换信号，供其他系统（如角色状态机）响应
    is_transitioning = false



func transition_to_world(weighted_tags: Dictionary[Tags.Tag, float]) -> void:
    if is_transitioning:
        print("[WORLD ASSEMBLER] Already transitioning, ignoring new transition request")
        return

    if weighted_tags.is_empty():
        push_warning("[WORLD ASSEMBLER] Cannot transition without weighted tags")
        return

    var main_tag: Tags.Tag = weighted_tags.keys()[0]

    if main_tag not in tag_scenes:
        print("[WORLD ASSEMBLER] Invalid tag: %s" % main_tag)
        return
    
    if main_tag == current_tag_id:
        print("[WORLD ASSEMBLER] Already in the target world: %s" % main_tag)
        world_changing.emit(main_tag, transition_duration) # 发出世界切换信号
        is_transitioning = true

        _update_def_to_scene(weighted_tags) # 切换到新世界的参数（仅参数）
        _start_manual_scroll(1)

        world_changed.emit(main_tag) # 发出世界切换信号，供其他系统（如角色状态机）响应
        is_transitioning = false
    
    else:
        var duration := maxf(transition_duration, 0.0)
        world_changing.emit(main_tag, duration) # 发出世界切换信号
        is_transitioning = true

        current_tag_id = main_tag # 更新当前世界ID
        _update_def_to_scene(weighted_tags)

        # 静态层、POI 和其余手动视差层同时开始过渡。
        _sky.transition_to_target(duration)
        _ground.transition_to_target(duration)
        _poi.fade_out_children(duration)
        _start_non_poi_manual_scroll(1)

        if not is_zero_approx(duration):
            await get_tree().create_timer(duration).timeout

        # 强制落到目标值，避免 Tween 与计时器同帧结束时留下微小误差。
        _sky.apply_immediate()
        _ground.apply_immediate()
        _poi.start_manual_scroll(0)

        world_changed.emit(main_tag)
        is_transitioning = false



func _ready() -> void:
    _build_tag_scenes() 
    _initialize_manual_parallax_layers()



# 小键盘控制世界切换
func _input(event): 
    for i in range(10):
        if event.is_action_pressed("%d" % i):
            # 创建一个权重为1.0的字典，表示选择的标签
            var target_tag: Dictionary[Tags.Tag, float] = {i as Tags.Tag: 1.0} 
            transition_to_world(target_tag)
            break


# 从 scripts/main/controllers/tagscene/defs 读取所有 TagSceneDef 资源，并将它们存储在 tag_scenes 字典中
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



# 初始化手动滚动的Parallax层的pool，并加入到对应的数组中
func _initialize_manual_parallax_layers() -> void:
    # 初始化所有手动滚动的Parallax层
    var initial_height: float = -150.00
    var height_increment: float = initial_height / 5.0 # 将高度均分为5个层级
    var height_levels: Array[float] = [
        0,
        initial_height - height_increment,
        initial_height - 2 * height_increment,
        initial_height - 3 * height_increment,
        initial_height - 4 * height_increment,
        initial_height - 5 * height_increment
    ]

    _poi.pool = MemoryDef.Pool.POI
    _poi.position = Vector2(0, height_levels[0])

    _cloud_1.pool = MemoryDef.Pool.CLOUD
    _cloud_1.position = Vector2(0, height_levels[1])
    _clouds.append(_cloud_1)

    _landform_1.pool = MemoryDef.Pool.LANDFORM_FAR
    _landform_1.position = Vector2(0, height_levels[1])
    _landforms.append(_landform_1)

    _component_1.pool = MemoryDef.Pool.COMPONENT_FAR
    _component_1.position = Vector2(0, height_levels[1])
    _components.append(_component_1)

    _cloud_2.pool = MemoryDef.Pool.CLOUD
    _cloud_2.position = Vector2(0, height_levels[2])
    _clouds.append(_cloud_2)

    _landform_2.pool = MemoryDef.Pool.LANDFORM_MID
    _landform_2.position = Vector2(0, height_levels[2])
    _landforms.append(_landform_2)

    _component_2.pool = MemoryDef.Pool.COMPONENT_MID
    _component_2.position = Vector2(0, height_levels[2])
    _components.append(_component_2)

    _cloud_3.pool = MemoryDef.Pool.CLOUD
    _cloud_3.position = Vector2(0, height_levels[3])
    _clouds.append(_cloud_3)

    _landform_3.pool = MemoryDef.Pool.LANDFORM_MID
    _landform_3.position = Vector2(0, height_levels[3])
    _landforms.append(_landform_3)

    _component_3.pool = MemoryDef.Pool.COMPONENT_MID
    _component_3.position = Vector2(0, height_levels[3])
    _components.append(_component_3)

    _cloud_4.pool = MemoryDef.Pool.CLOUD
    _cloud_4.position = Vector2(0, height_levels[4])
    _clouds.append(_cloud_4)

    _landform_4.pool = MemoryDef.Pool.LANDFORM_FRONT
    _landform_4.position = Vector2(0, height_levels[4])
    _landforms.append(_landform_4)

    _component_4.pool = MemoryDef.Pool.COMPONENT_FRONT
    _component_4.position = Vector2(0, height_levels[4])
    _components.append(_component_4)

    _cloud_5.pool = MemoryDef.Pool.CLOUD
    _cloud_5.position = Vector2(0, height_levels[5])
    _clouds.append(_cloud_5)

    _landform_5.pool = MemoryDef.Pool.LANDFORM_FRONT
    _landform_5.position = Vector2(0, height_levels[5])
    _landforms.append(_landform_5)

    _component_5.pool = MemoryDef.Pool.COMPONENT_FRONT
    _component_5.position = Vector2(0, height_levels[5])
    _components.append(_component_5)


# 将tag_scene的参数应用到场景节点上
func _update_def_to_scene(weighted_tags: Dictionary[Tags.Tag, float]) -> void: 
    # weighted_tags: {MYSTERIOUS: 0.5, HOLY: 0.3, BARREN: 0.2}
    # mode: 0直接切换(或初始化场景)，1渐变切换
    var main_tag: Tags.Tag = weighted_tags.keys()[0] # 获取权重最高的标签作为主标签
    var main_tag_scene := tag_scenes[main_tag]
    
    
    _sky.main_color = main_tag_scene.sky_main_color
    _sky.star_texture = main_tag_scene.sky_star_texture
    _sky.star_color = main_tag_scene.sky_star_color
    _sky.effect_texture = main_tag_scene.sky_effect_texture
    _sky.effect_color = main_tag_scene.sky_effect_color


    _poi.color = main_tag_scene.poi_color
    _poi.scroll_speed = main_tag_scene.poi_scroll_speed
    _poi.weighted_tags = weighted_tags


    _ground.main_color = main_tag_scene.ground_main_color
    _ground.effect_texture = main_tag_scene.ground_effect_texture
    _ground.effect_color = main_tag_scene.ground_effect_color


    var clouds_count = _clouds.size()
    for i in clouds_count:
        var cloud = _clouds[i]
        cloud.color = main_tag_scene.cloud_color
        var t = float(i) / (clouds_count - 1)
        var speed_ratio = lerp(1.0, main_tag_scene.landform_speed_ratio, t) # 根据云层索引调整速度比率
        cloud.scroll_speed = main_tag_scene.cloud_scroll_speed * speed_ratio
        cloud.weighted_tags = weighted_tags


    var active_landforms: Array[ManualParallax] = []
    var main_tag_pools: MemoryController.MemoryPools
    if memory_controller.memories_by_tag.has(main_tag):
        main_tag_pools = memory_controller.memories_by_tag[main_tag]
    else:
        push_warning("[WORLD ASSEMBLER] 当前主标签没有可用的 MemoryDef：%s" % main_tag)

    # 只让主标签拥有素材的地形池参与颜色梯度。
    for landform in _landforms:
        if main_tag_pools != null and main_tag_pools.by_pool.has(landform.pool):
            active_landforms.append(landform)

    var active_landforms_count := active_landforms.size()
    for i in active_landforms_count:
        var landform := active_landforms[i]
        var t := 0.0 if active_landforms_count == 1 else float(i) / (active_landforms_count - 1)
        landform.color = main_tag_scene.landform_light_color.lerp(
            main_tag_scene.landform_dark_color,
            t
            )

    var landforms_count := _landforms.size()
    for i in landforms_count:
        var landform := _landforms[i]
        var t := float(i) / (landforms_count - 1)
        var speed_ratio = lerp(1.0, main_tag_scene.landform_speed_ratio, t) # 根据地形层索引调整速度比率
        landform.scroll_speed = main_tag_scene.landform_scroll_speed * speed_ratio
        landform.weighted_tags = weighted_tags
    

    var components_count = _components.size()
    for i in components_count:
        var component = _components[i]
        component.color = main_tag_scene.component_color
        var t = float(i) / (components_count - 1)
        var speed_ratio = lerp(1.0, main_tag_scene.component_speed_ratio, t) # 根据组件层索引调整速度比率
        component.scroll_speed = main_tag_scene.component_scroll_speed * speed_ratio
        component.weighted_tags = weighted_tags



# 开始手动滚动的Parallax层
func _start_manual_scroll(mode: int = 0) -> void: # mode: 0直接切换，1渐变切换
    _poi.start_manual_scroll(mode)
    _start_non_poi_manual_scroll(mode)



func _start_non_poi_manual_scroll(mode: int = 0) -> void:
    for cloud in _clouds:
        cloud.start_manual_scroll(mode)
    for landform in _landforms:
        landform.start_manual_scroll(mode)
    for component in _components:
        component.start_manual_scroll(mode)



#region old_code







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



#endregion
