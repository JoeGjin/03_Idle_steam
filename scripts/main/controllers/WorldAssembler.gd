extends Node
class_name WorldAssembler


const INITIAL_POI_SPAWN_DELAY := 60.0


# 外部依赖
@onready var world_root: Node2D = %WorldRoot
@onready var memory_controller: MemoryController = %MemoryController

# 世界定义与过渡配置
@export var tag_scenes: Dictionary[Tags.Tag, TagSceneDef] = {}
@export var transition_duration: float = 30.0 # 世界切换的过渡动画时长（秒）

# 高度对齐与生成缩放配置
@export_range(0.0, 500.0, 1.0, "suffix:px") var component_ground_sink: float = 0.0
## Pet 胶囊碰撞体最低点相对 Landform_4 地表的下沉距离。
@export_range(0.0, 500.0, 1.0, "suffix:px") var pet_ground_sink: float = 0.0
## 同组的 Cloud、Component 共用倍率，组号从后往前排列；Landform 保持原始尺寸。
@export_range(0.01, 2.0, 0.01, "or_greater") var group_1_scale_factor: float = 0.4
@export_range(0.01, 2.0, 0.01, "or_greater") var group_2_scale_factor: float = 0.5
@export_range(0.01, 2.0, 0.01, "or_greater") var group_3_scale_factor: float = 0.6
@export_range(0.01, 2.0, 0.01, "or_greater") var group_4_scale_factor: float = 0.7
@export_range(0.01, 2.0, 0.01, "or_greater") var group_5_scale_factor: float = 0.8
@export_range(0.01, 2.0, 0.01, "or_greater") var poi_scale_factor: float = 0.5
## 除 Landform 外手动视差素材的随机缩放幅度；0.1 表示基础倍率上下浮动 10%，0 表示关闭。
@export_range(0.0, 1.0, 0.01) var spawn_scale_randomness: float = 0.1

## 全局滚动速度倍率，同时作用于 Parallax2D 和手动视差层。
@export_range(0.0, 4.0, 0.05, "or_greater") var global_scroll_speed: float = 1.0:
    set(value):
        global_scroll_speed = maxf(value, 0.0)
        if is_node_ready():
            _apply_global_scroll_speed()

# 当前世界状态
@export var current_tag_id: Tags.Tag = Tags.Tag.MYSTERIOUS # 当前世界的主标签
@export var is_transitioning: bool = false # 是否正在进行世界切换过渡

var current_weighted_tags: Dictionary[Tags.Tag, float] = {}


# 世界表现节点：视差组按从后往前的顺序排列
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


@onready var _cloud_4: ManualParallax = %Cloud_4
@onready var _landform_4: ManualParallax = %Landform_4
@onready var _component_4: ManualParallax = %Component_4

@onready var _cloud_5: ManualParallax = %Cloud_5
@onready var _landform_5: ManualParallax = %Landform_5
@onready var _component_5: ManualParallax = %Component_5


var banned_texture: String = "" # 单个槽位，记录最近一次未选择的texture名称

# 手动视差层分组：相同索引对应同组的云、地形与组件
var _clouds: Array[ManualParallax] = []
var _landforms: Array[ManualParallax] = []
var _components: Array[ManualParallax] = []

# 未乘全局倍率的基础速度
var _sky_base_autoscroll: Vector2
var _ground_base_autoscroll: Vector2
var _manual_base_scroll_speeds: Dictionary = {}

# Memory 生成记录与最近选择
var _last_memory_by_layer: Dictionary = {}
var _spawned_objects_by_memory: Dictionary = {}
var _recently_chosen_memories: Array[MemoryDef] = []


# 世界切换通知：由 Main 协调音频与其他系统
signal world_changing(new_tag_id: int, transition_duration: float) # 定义世界切换信号，参数为新的世界ID和过渡时长
signal world_changed(new_tag_id: int)


# 本脚本将 TagSceneDef 配置应用到世界节点，并协调各手动视差层的生成。
# ManualParallax 负责层内对象与计时；本脚本负责世界过渡、Memory 选用及跨层占用。
#
# 目录（与下方代码分区顺序一致）
# 1. 初始化与资源加载
#    加载 TagSceneDef，建立视差层的池、初始位置、分组与生成倍率，记录基础速度。
#    入口：_ready
# 2. 世界组装与过渡
#    首次直接构建世界；同主标签只更新配置，跨主标签执行过渡并保留首次 POI 等待。
#    入口：assemble_world / transition_to_world / get_current_weighted_tags
#    通过 world_changing / world_changed 通知 Main 协调其他系统。
# 3. 世界参数与滚动速度
#    将主标签的颜色、纹理、速度和加权标签应用到各层；统一应用全局速度倍率。
#    核心：_update_def_to_scene / _apply_global_scroll_speed
# 4. 手动视差层启动与布局
#    统一设置右侧生成线；首次按地形、云、组件顺序预填充，POI 单独延迟。
#    世界切换时按指定模式重新启动非 POI 层。
#    入口：set_manual_spawn_x
#    核心：_start_initial_manual_scroll / _start_non_poi_manual_scroll
# 5. Memory 选用与跨层占用
#    最近选择优先，排除本层上次素材，并按世界坐标检查同一 Memory 的跨层间距。
#    仅登记成功生成的实例，通过弱引用清理失效占用；候选不足时跳过本次生成。
#    入口：set_recently_chosen_memories / get_manual_parallax_memory
#          can_spawn_manual_parallax_memory / register_manual_parallax_spawn
# 6. 地表与云高度查询
#    按组查找对应地形，为组件查询地表，为云查询地形层原点。
#    入口：get_component_ground_y / get_cloud_layer_origin_y
# 7. 调试输入
#    将数字输入动作转换为单标签的世界切换请求。
#    入口：_input


#region 1. 初始化与资源加载

func _ready() -> void:
    _build_tag_scenes()
    _initialize_manual_parallax_layers()
    _sky_base_autoscroll = _sky.autoscroll
    _ground_base_autoscroll = _ground.autoscroll
    _apply_global_scroll_speed()


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


# 初始化手动视差层的池、位置和生成倍率，并建立对应分组。
func _initialize_manual_parallax_layers() -> void:
    var viewport_bottom_y := get_viewport().get_visible_rect().size.y
    var initial_height: float = -150.00
    var height_increment: float = initial_height / 5.0 # 将高度均分为5个层级
    var height_levels: Array[float] = [
        0,
        initial_height - 0.75 * height_increment,
        initial_height - 1.5 * height_increment,
        initial_height - 2 * height_increment,
        initial_height - 2.75 * height_increment,
        initial_height - 4.5 * height_increment
    ]

    _poi.pool = MemoryDef.Pool.POI
    _poi.position = Vector2(0, viewport_bottom_y + height_levels[0])
    _poi.spawn_scale_factor = poi_scale_factor

    _cloud_1.pool = MemoryDef.Pool.CLOUD
    _cloud_1.position = Vector2(0, viewport_bottom_y + height_levels[1])
    _clouds.append(_cloud_1)

    _landform_1.pool = MemoryDef.Pool.LANDFORM_FAR
    _landform_1.position = Vector2(0, viewport_bottom_y + height_levels[1])
    _landforms.append(_landform_1)

    _component_1.pool = MemoryDef.Pool.COMPONENT_FAR
    _component_1.position = Vector2(0, viewport_bottom_y + height_levels[1])
    _components.append(_component_1)

    _cloud_2.pool = MemoryDef.Pool.CLOUD
    _cloud_2.position = Vector2(0, viewport_bottom_y + height_levels[2])
    _clouds.append(_cloud_2)

    _landform_2.pool = MemoryDef.Pool.LANDFORM_MID
    _landform_2.position = Vector2(0, viewport_bottom_y + height_levels[2])
    _landforms.append(_landform_2)

    _component_2.pool = MemoryDef.Pool.COMPONENT_MID
    _component_2.position = Vector2(0, viewport_bottom_y + height_levels[2])
    _components.append(_component_2)

    _cloud_3.pool = MemoryDef.Pool.CLOUD
    _cloud_3.position = Vector2(0, viewport_bottom_y + height_levels[3])
    _clouds.append(_cloud_3)

    _landform_3.pool = MemoryDef.Pool.LANDFORM_MID
    _landform_3.position = Vector2(0, viewport_bottom_y + height_levels[3])
    _landforms.append(_landform_3)

    _component_3.pool = MemoryDef.Pool.COMPONENT_MID
    _component_3.position = Vector2(0, viewport_bottom_y + height_levels[3])
    _components.append(_component_3)

    _cloud_4.pool = MemoryDef.Pool.CLOUD
    _cloud_4.position = Vector2(0, viewport_bottom_y + height_levels[4])
    _clouds.append(_cloud_4)

    _landform_4.pool = MemoryDef.Pool.LANDFORM_FRONT
    _landform_4.position = Vector2(0, viewport_bottom_y + height_levels[4])
    _landforms.append(_landform_4)

    _component_4.pool = MemoryDef.Pool.COMPONENT_FRONT
    _component_4.position = Vector2(0, viewport_bottom_y + height_levels[4])
    _components.append(_component_4)

    _cloud_5.pool = MemoryDef.Pool.CLOUD
    _cloud_5.position = Vector2(0, viewport_bottom_y + height_levels[5])
    _clouds.append(_cloud_5)

    _landform_5.pool = MemoryDef.Pool.LANDFORM_FRONT
    _landform_5.position = Vector2(0, viewport_bottom_y + height_levels[5])
    _landforms.append(_landform_5)

    _component_5.pool = MemoryDef.Pool.COMPONENT_FRONT
    _component_5.position = Vector2(0, viewport_bottom_y + height_levels[5])
    _components.append(_component_5)

    var group_scale_factors: Array[float] = [
        group_1_scale_factor,
        group_2_scale_factor,
        group_3_scale_factor,
        group_4_scale_factor,
        group_5_scale_factor,
    ]
    for i in group_scale_factors.size():
        _clouds[i].spawn_scale_factor = group_scale_factors[i]
        _components[i].spawn_scale_factor = group_scale_factors[i]

#endregion


#region 2. 世界组装与过渡

# 用于第一次建立场景，直接应用参数，不需要过渡动画
func assemble_world(
    weighted_tags: Dictionary[Tags.Tag, float],
    world_visible_rect: Rect2
) -> void:
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
    _start_initial_manual_scroll(world_visible_rect)

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
        world_changed.emit(main_tag) # 发出世界切换信号，供其他系统（如角色状态机）响应
        is_transitioning = false

    else:
        var duration := maxf(transition_duration, 0.0)
        var keep_initial_poi_delay := _poi.is_waiting_for_initial_spawn()
        world_changing.emit(main_tag, duration) # 发出世界切换信号
        is_transitioning = true

        current_tag_id = main_tag # 更新当前世界ID
        _update_def_to_scene(weighted_tags)

        # 首次 POI 等待沿用启动时的计时器，切换世界只更新它的目标配置。
        _sky.transition_to_target(duration)
        _ground.transition_to_target(duration)
        if not keep_initial_poi_delay:
            _poi.fade_out_children(duration)
        _start_non_poi_manual_scroll(1, false)

        if not is_zero_approx(duration):
            await get_tree().create_timer(duration).timeout

        # 强制落到目标值，避免 Tween 与计时器同帧结束时留下微小误差。
        _sky.apply_immediate()
        _ground.apply_immediate()
        # 等待期间生成的首个 POI 也保留，避免过渡结束后清掉或重新延迟。
        if not keep_initial_poi_delay:
            _poi.start_manual_scroll(0, false)

        world_changed.emit(main_tag)
        is_transitioning = false


func get_current_weighted_tags() -> Dictionary[Tags.Tag, float]:
    var result: Dictionary[Tags.Tag, float] = {}
    for tag: Tags.Tag in current_weighted_tags:
        result[tag] = current_weighted_tags[tag]
    return result

#endregion


#region 3. 世界参数与滚动速度

# 更新各层的目标配置；立即应用或渐变由世界组装与过渡流程决定。
func _update_def_to_scene(weighted_tags: Dictionary[Tags.Tag, float]) -> void:
    # weighted_tags: {MYSTERIOUS: 0.5, PEACEFUL: 0.3, BARREN: 0.2}
    var main_tag: Tags.Tag = weighted_tags.keys()[0] # 获取权重最高的标签作为主标签
    var main_tag_scene := tag_scenes[main_tag]

    current_weighted_tags.clear()
    for tag: Tags.Tag in weighted_tags:
        current_weighted_tags[tag] = weighted_tags[tag]

    _sky.main_color = main_tag_scene.sky_main_color
    _sky.invert_amount = main_tag_scene.sky_invert_amount
    _sky.star_texture = main_tag_scene.sky_star_texture
    _sky.star_color = main_tag_scene.sky_star_color
    _sky.effect_texture = main_tag_scene.sky_effect_texture
    _sky.effect_color = main_tag_scene.sky_effect_color

    _poi.color = main_tag_scene.poi_color
    _set_manual_base_scroll_speed(_poi, main_tag_scene.poi_scroll_speed)
    _poi.weighted_tags = weighted_tags

    _ground.main_color = main_tag_scene.ground_main_color
    _ground.effect_texture = main_tag_scene.ground_effect_texture
    _ground.effect_color = main_tag_scene.ground_effect_color

    var clouds_count = _clouds.size()
    for i in clouds_count:
        var cloud = _clouds[i]
        cloud.color = main_tag_scene.cloud_color
        var t = float(i) / (clouds_count - 1)
        var speed_ratio = lerp(1.0, main_tag_scene.cloud_speed_ratio, t) # 根据云层索引调整速度比率
        _set_manual_base_scroll_speed(
            cloud,
            main_tag_scene.cloud_scroll_speed * speed_ratio
        )
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
        _set_manual_base_scroll_speed(
            landform,
            main_tag_scene.landform_scroll_speed * speed_ratio
        )
        landform.weighted_tags = weighted_tags

    var components_count = _components.size()
    for i in components_count:
        var component = _components[i]
        component.color = main_tag_scene.component_color
        var t = float(i) / (components_count - 1)
        var speed_ratio = lerp(1.0, main_tag_scene.component_speed_ratio, t) # 根据组件层索引调整速度比率
        _set_manual_base_scroll_speed(
            component,
            main_tag_scene.component_scroll_speed * speed_ratio
        )
        component.weighted_tags = weighted_tags


func _set_manual_base_scroll_speed(layer: ManualParallax, speed: Vector2) -> void:
    _manual_base_scroll_speeds[layer] = speed
    layer.scroll_speed = speed * global_scroll_speed


func _apply_global_scroll_speed() -> void:
    _sky.autoscroll = _sky_base_autoscroll * global_scroll_speed
    _ground.autoscroll = _ground_base_autoscroll * global_scroll_speed
    for layer: ManualParallax in _manual_base_scroll_speeds:
        if is_instance_valid(layer):
            layer.scroll_speed = _manual_base_scroll_speeds[layer] * global_scroll_speed

#endregion


#region 4. 手动视差层启动与布局

func set_manual_spawn_x(spawn_x: float) -> void:
    # 各手动视差层的横向原点相同，统一让纹理左边缘从窗口右侧生成。
    _poi.spawn_position.x = spawn_x
    for layer: ManualParallax in _clouds + _landforms + _components:
        layer.spawn_position.x = spawn_x


# 首次构建先准备所有层，再依次填充地形、云和组件，最后启动滚动与 POI 延迟。
func _start_initial_manual_scroll(world_visible_rect: Rect2) -> void:
    var layers: Array[ManualParallax] = []
    layers.append_array(_clouds)
    layers.append_array(_landforms)
    layers.append_array(_components)
    # 清理场景内的示例 POI，但不参与可见区域预填充。
    _poi.prepare_initial_scroll()
    for layer: ManualParallax in layers:
        layer.prepare_initial_scroll()
    _last_memory_by_layer.clear()
    _spawned_objects_by_memory.clear()

    for landform: ManualParallax in _landforms:
        landform.prefill_visible_range(world_visible_rect)
    for cloud: ManualParallax in _clouds:
        cloud.prefill_visible_range(world_visible_rect)
    for component: ManualParallax in _components:
        component.prefill_visible_range(world_visible_rect)

    for layer: ManualParallax in layers:
        layer.start_prefilled_scroll()
    _poi.start_initial_spawn_delay(INITIAL_POI_SPAWN_DELAY)


func _start_non_poi_manual_scroll(mode: int = 0, spawn_immediately: bool = true) -> void:
    for cloud in _clouds:
        cloud.start_manual_scroll(mode, spawn_immediately)
    for landform in _landforms:
        landform.start_manual_scroll(mode, spawn_immediately)
    for component in _components:
        component.start_manual_scroll(mode, spawn_immediately)

#endregion


#region 5. Memory 选用与跨层占用

func set_recently_chosen_memories(memories: Array[MemoryDef]) -> void:
    _recently_chosen_memories.clear()
    for memory: MemoryDef in memories:
        if memory == null or _recently_chosen_memories.has(memory):
            continue
        _recently_chosen_memories.append(memory)
        if _recently_chosen_memories.size() >= 3:
            break


# 每层按自己的 Timer 独立请求；先到的请求先占用实际空间，不再依赖逻辑轮次对齐。
func get_manual_parallax_memory(layer: ManualParallax, spawn_x: float = NAN) -> MemoryDef:
    var layer_id := layer.get_instance_id()
    var excluded_memories: Array[MemoryDef] = []
    if _last_memory_by_layer.has(layer_id):
        var previous_memory := _last_memory_by_layer[layer_id] as MemoryDef
        if previous_memory != null:
            excluded_memories.append(previous_memory)

    var recent_candidates := layer.get_recent_memory_candidates(
        _recently_chosen_memories,
        excluded_memories
    )
    for memory: MemoryDef in recent_candidates:
        if can_spawn_manual_parallax_memory(layer, memory, spawn_x):
            return memory

    for memory: MemoryDef in layer.get_memory_candidates(excluded_memories):
        if can_spawn_manual_parallax_memory(layer, memory, spawn_x):
            return memory

    var suppress_warning := layer.pool in [
        MemoryDef.Pool.CLOUD,
        MemoryDef.Pool.LANDFORM_FAR,
        MemoryDef.Pool.LANDFORM_MID,
        MemoryDef.Pool.LANDFORM_FRONT,
    ]
    if not suppress_warning:
        var pool_name := String(MemoryDef.Pool.keys()[layer.pool])
        print(
            "[MANUAL PARALLAX] 候选不足，已严格跳过本次生成：layer=%s, pool=%s"
            % [layer.name, pool_name]
        )
    return null


func can_spawn_manual_parallax_memory(
    layer: ManualParallax,
    memory: MemoryDef,
    spawn_x: float = NAN
) -> bool:
    if layer == null or memory == null or memory.texture == null or memory.pool != layer.pool:
        return false
    return not _is_memory_blocked_by_other_layer(memory, layer, spawn_x)


# 只有实例化成功后才登记，确保层内“上一次”与跨层空间占用都对应实际生成结果。
func register_manual_parallax_spawn(
    layer: ManualParallax,
    memory: MemoryDef,
    object: MparaObject
) -> void:
    if layer == null or memory == null or object == null or not is_instance_valid(object):
        return

    _last_memory_by_layer[layer.get_instance_id()] = memory
    var object_refs: Array = _spawned_objects_by_memory.get(memory, [])
    object_refs.append(weakref(object))
    _spawned_objects_by_memory[memory] = object_refs


func _is_memory_blocked_by_other_layer(
    memory: MemoryDef,
    requesting_layer: ManualParallax,
    spawn_x: float = NAN
) -> bool:
    if memory == null or memory.texture == null:
        return false
    if not _spawned_objects_by_memory.has(memory):
        return false

    var distance_ratio := maxf(memory.spawn_distance_ratio, 0.0)
    if distance_ratio <= 0.0:
        return false

    var requesting_width := (
        memory.texture.get_width()
        * requesting_layer.spawn_scale_factor
        * absf(requesting_layer.global_scale.x)
    )
    # 首次填充也按本次放置位置检查，普通生成仍默认使用右侧生成线。
    var local_spawn := requesting_layer.spawn_position
    if not is_nan(spawn_x):
        local_spawn.x = spawn_x
    var requesting_spawn_x := requesting_layer.to_global(local_spawn).x
    var object_refs: Array = _spawned_objects_by_memory[memory]
    var is_blocked := false
    for index: int in range(object_refs.size() - 1, -1, -1):
        var object_ref := object_refs[index] as WeakRef
        var object: MparaObject
        if object_ref != null:
            object = object_ref.get_ref() as MparaObject

        if object == null or not is_instance_valid(object) or object.is_queued_for_deletion():
            object_refs.remove_at(index)
            continue

        var source_layer := object.get_parent() as ManualParallax
        if source_layer == null or source_layer == requesting_layer:
            continue

        # 跨层使用世界坐标宽度，并以较大的实例为准，兼容不同组的缩放。
        var object_width := memory.texture.get_width() * absf(object.global_scale.x)
        var safe_distance := distance_ratio * maxf(requesting_width, object_width)
        if absf(requesting_spawn_x - object.global_position.x) < safe_distance:
            is_blocked = true

    if object_refs.is_empty():
        _spawned_objects_by_memory.erase(memory)
    else:
        _spawned_objects_by_memory[memory] = object_refs
    return is_blocked

#endregion


#region 6. 地表与云高度查询

func get_component_ground_y(component_layer: ManualParallax, world_x: float) -> Variant:
    var layer_index := _components.find(component_layer)
    if layer_index < 0 or layer_index >= _landforms.size():
        return null
    return _landforms[layer_index].get_ground_y(world_x)


func get_cloud_layer_origin_y(cloud_layer: ManualParallax) -> Variant:
    # Cloud 与 Landform 按相同顺序初始化，云只对齐对应层的原点。
    var layer_index := _clouds.find(cloud_layer)
    if layer_index < 0 or layer_index >= _landforms.size():
        return null
    return _landforms[layer_index].to_global(Vector2.ZERO).y

#endregion


#region 7. 调试输入

# 通过数字输入动作调试世界切换。
func _input(event):
    for i in range(Tags.Tag.size()):
        if event.is_action_pressed("%d" % i):
            # 创建一个权重为1.0的字典，表示选择的标签
            var target_tag: Dictionary[Tags.Tag, float] = {i as Tags.Tag: 1.0}
            transition_to_world(target_tag)
            break

#endregion
