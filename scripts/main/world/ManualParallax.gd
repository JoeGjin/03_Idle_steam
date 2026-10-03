extends Node2D

class_name ManualParallax


const MPARA_OBJECT_SCENE: PackedScene = preload("res://scenes/MparaObject.tscn")
const SPAWN_DISTANCE_EPSILON := 1.0
const SPAWN_RECHECK_INTERVAL := 0.25
const SURFACE_ALPHA_THRESHOLD := 0.1


@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var memory_controller : MemoryController = %MemoryController

@export var spawn_position: Vector2 = Vector2(1920 + 300,0) # 生成位置，默认在屏幕右侧400像素


var pool: MemoryDef.Pool 
var spawn_scale_factor: float = 1.0:
    set(value):
        spawn_scale_factor = maxf(value, 0.01)
var scroll_speed: Vector2 = Vector2.ZERO
var color: Color = Color(1, 1, 1, 1)

var weighted_tags: Dictionary[Tags.Tag, float]:
    set(value):
        weighted_tags = value
        _pending_memory = null


var _objects: Array[Sprite2D] = []
var _is_scrolling: bool = true
var _spawn_timer: Timer
var _spawn_cooldown: float = 999.0
var _pending_memory: MemoryDef
var _fade_tween: Tween
var _surface_height_maps: Dictionary = {}


#非Parallex2D 手动滚动program开始运行（生成随机texture，移动，到尽头自动释放，间隔时长后重复）
# 目录
# 1.外部调用func
#  1.1 开始滚动
#  1.2 停止滚动
#  1.3 继续滚动
# 2.内部调用func
#  2.0 queue_free所有子节点
#  2.1 初始化计时器
#  2.2 生成随机object并spawn在场景右侧
#  2.3 移动
#  2.4 到尽头自动释放
#  2.5 间隔时长后重复




func start_manual_scroll(mode: int = 0, spawn_immediately: bool = true) -> void:
    _pending_memory = null
    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()
    _fade_tween = null

    # 先读取旧对象位置，再按过渡模式清理，避免清理右侧对象后丢失原有间距基准。
    var transition_wait_time := 0.0
    if not spawn_immediately:
        if is_component_layer():
            _pending_memory = _request_next_memory()
        transition_wait_time = _calculate_transition_spawn_wait_time()
    
    _free_all_timer() # 先停止计时器
    
    match mode:
        0:
            _free_all_children()
        1:
            _free_distant_children(0.85)

    _initialize_timer()

    _is_scrolling = true
    if spawn_immediately and is_component_layer():
        _on_component_spawn_timer_timeout()
        return

    if spawn_immediately:
        var next_memory := _request_next_memory()
        _spawn_object(next_memory)
        _update_spawn_timer(next_memory)
    else:
        _spawn_timer.wait_time = maxf(transition_wait_time, 0.001)
    
    _spawn_timer.start()



func fade_out_children(duration: float) -> void:
    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()
    _fade_tween = null

    # POI 退场期间不再生成新对象，但已有对象继续向前滚动。
    _free_all_timer()

    var children_to_fade: Array[MparaObject] = []
    for child in get_children():
        if child is MparaObject:
            children_to_fade.append(child)

    if children_to_fade.is_empty():
        return

    var safe_duration := maxf(duration, 0.0)
    if is_zero_approx(safe_duration):
        for child in children_to_fade:
            child.modulate.a = 0.0
        return

    _fade_tween = create_tween().set_parallel(true)
    for child in children_to_fade:
        _fade_tween.tween_property(child, "modulate:a", 0.0, safe_duration)



func stop_manual_scroll() -> void:
    _is_scrolling = false
    _spawn_timer.stop()



func resume_manual_scroll() -> void:
    if not _is_scrolling:
        _spawn_timer.start()
        _is_scrolling = true



func _process(delta: float) -> void:
    # 移动所有子节点
    _move_textures(delta)



func _move_textures(delta: float) -> void:
    # 移动所有子节点
    if _is_scrolling:
        for object in _objects:
            _move_and_release(object, delta, _objects)



func _move_and_release(object: Sprite2D, delta: float, object_list: Array[Sprite2D]) -> void:
    object.position += scroll_speed * delta
    # 如果从场景左侧出去，自动释放
    if object.position.x < -6000:
        object_list.erase(object)
        object.queue_free()



func _initialize_timer() -> void:
    # 初始化计时器
    _spawn_timer = Timer.new()
    _spawn_timer.wait_time = _spawn_cooldown
    _spawn_timer.one_shot = is_component_layer()
    _spawn_timer.autostart = false
    add_child(_spawn_timer)
    _spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))



func _free_all_children() -> void:
    for child in get_children():
        if child is MparaObject:
            child.queue_free()
    _objects.clear()
    # _objects_0.clear()



func _free_all_timer() -> void:
    for timer in get_children():
        if timer is Timer:
            timer.stop()
            timer.queue_free()



func _free_distant_children(distance_modulus: float) -> void:
    for child in get_children():
        if child is MparaObject:
            if child in _objects:
                if child.position.x > distance_modulus * spawn_position.x:
                    _objects.erase(child)
                    child.queue_free()



func get_memory_candidates(excluded_memories: Array[MemoryDef] = []) -> Array[MemoryDef]:
    if weighted_tags.is_empty():
        return []

    var main_tag: Tags.Tag = weighted_tags.keys()[0]
    if _uses_main_tag_only():
        return _get_main_tag_candidates(main_tag, excluded_memories)

    # 标签按权重随机排序；协调器优先使用靠前候选，并可在冲突时继续尝试后续标签。
    var available_tags: Array[Tags.Tag] = []
    for tag: Tags.Tag in weighted_tags:
        var weight: float = maxf(weighted_tags[tag], 0.0)
        if is_zero_approx(weight) or not memory_controller.memories_by_tag.has(tag):
            continue

        var memory_pools: MemoryController.MemoryPools = memory_controller.memories_by_tag[tag]
        if memory_pools.by_pool.has(pool):
            available_tags.append(tag)

    if available_tags.is_empty():
        return []

    var candidates: Array[MemoryDef] = []
    for tag: Tags.Tag in _get_weighted_tag_order(available_tags):
        var tag_candidates := _get_tag_candidates(tag, main_tag, excluded_memories)
        tag_candidates.shuffle()
        for memory: MemoryDef in tag_candidates:
            if not candidates.has(memory):
                candidates.append(memory)

    return candidates



func get_recent_memory_candidates(
    recent_memories: Array[MemoryDef],
    excluded_memories: Array[MemoryDef] = []
) -> Array[MemoryDef]:
    if weighted_tags.is_empty() or recent_memories.is_empty():
        return []

    # 保留最近优先顺序，同时按 MemoryDef 身份去重。
    var eligible_memories: Array[MemoryDef] = []
    for memory: MemoryDef in recent_memories:
        if (
            memory == null
            or memory.pool != pool
            or excluded_memories.has(memory)
            or eligible_memories.has(memory)
        ):
            continue
        eligible_memories.append(memory)

    var available_tags: Array[Tags.Tag] = []
    for tag: Tags.Tag in weighted_tags:
        var weight: float = maxf(weighted_tags[tag], 0.0)
        if is_zero_approx(weight):
            continue
        for memory: MemoryDef in eligible_memories:
            if tag in memory.tags:
                available_tags.append(tag)
                break

    if available_tags.is_empty():
        return []

    var main_tag: Tags.Tag = weighted_tags.keys()[0]
    var candidates: Array[MemoryDef] = []
    for tag: Tags.Tag in _get_weighted_tag_order(available_tags):
        var tag_candidates := _get_tag_candidates_from_memories(
            tag,
            main_tag,
            eligible_memories,
            excluded_memories
        )
        for memory: MemoryDef in tag_candidates:
            if not candidates.has(memory):
                candidates.append(memory)

    return candidates



func _uses_main_tag_only() -> bool:
    return pool in [
        MemoryDef.Pool.CLOUD,
        MemoryDef.Pool.LANDFORM_FAR,
        MemoryDef.Pool.LANDFORM_MID,
        MemoryDef.Pool.LANDFORM_FRONT,
    ]



func _get_main_tag_candidates(
    main_tag: Tags.Tag,
    excluded_memories: Array[MemoryDef]
) -> Array[MemoryDef]:
    var candidates: Array[MemoryDef] = []
    if not memory_controller.memories_by_tag.has(main_tag):
        return candidates

    var memory_pools: MemoryController.MemoryPools = memory_controller.memories_by_tag[main_tag]
    if not memory_pools.by_pool.has(pool):
        return candidates

    var memory_list: MemoryController.MemoryList = memory_pools.by_pool[pool]
    for memory: MemoryDef in memory_list.memories:
        if (
            main_tag in memory.tags
            and not excluded_memories.has(memory)
        ):
            candidates.append(memory)

    candidates.shuffle()
    return candidates



func _get_weighted_tag_order(available_tags: Array[Tags.Tag]) -> Array[Tags.Tag]:
    var remaining_tags := available_tags.duplicate()
    var ordered_tags: Array[Tags.Tag] = []

    while not remaining_tags.is_empty():
        var total_weight := 0.0
        for tag: Tags.Tag in remaining_tags:
            total_weight += maxf(weighted_tags[tag], 0.0)

        var selected_index := remaining_tags.size() - 1
        var random_weight := randf() * total_weight
        for index: int in range(remaining_tags.size()):
            random_weight -= maxf(weighted_tags[remaining_tags[index]], 0.0)
            if random_weight <= 0.0:
                selected_index = index
                break

        ordered_tags.append(remaining_tags[selected_index])
        remaining_tags.remove_at(selected_index)

    return ordered_tags



func _get_tag_candidates(
    selected_tag: Tags.Tag,
    main_tag: Tags.Tag,
    excluded_memories: Array[MemoryDef]
) -> Array[MemoryDef]:
    var selected_pools: MemoryController.MemoryPools = memory_controller.memories_by_tag[selected_tag]
    var selected_list: MemoryController.MemoryList = selected_pools.by_pool[pool]
    return _get_tag_candidates_from_memories(
        selected_tag,
        main_tag,
        selected_list.memories,
        excluded_memories
    )



func _get_tag_candidates_from_memories(
    selected_tag: Tags.Tag,
    main_tag: Tags.Tag,
    source_memories: Array[MemoryDef],
    excluded_memories: Array[MemoryDef]
) -> Array[MemoryDef]:
    var candidates: Array[MemoryDef] = []
    var max_tag_count := 0
    for memory: MemoryDef in source_memories:
        max_tag_count = maxi(max_tag_count, memory.tags.size())

    if selected_tag == main_tag:
        # 主标签优先使用标签顺位更靠前的 Memory。
        for tag_index: int in range(max_tag_count):
            candidates.clear()
            for memory: MemoryDef in source_memories:
                if (
                    tag_index < memory.tags.size()
                    and memory.tags[tag_index] == selected_tag
                    and not excluded_memories.has(memory)
                ):
                    candidates.append(memory)
            if not candidates.is_empty():
                return candidates
        return candidates

    # 副标签优先匹配 [副标签, 主标签]。
    for memory: MemoryDef in source_memories:
        if (
            memory.tags.size() >= 2
            and memory.tags[0] == selected_tag
            and memory.tags[1] == main_tag
            and not excluded_memories.has(memory)
        ):
            candidates.append(memory)
    if not candidates.is_empty():
        return candidates

    # 其次接受第一顺位为副标签的任意 Memory。
    for memory: MemoryDef in source_memories:
        if (
            not memory.tags.is_empty()
            and memory.tags[0] == selected_tag
            and not excluded_memories.has(memory)
        ):
            candidates.append(memory)
    if not candidates.is_empty():
        return candidates

    # 最后从第二顺位开始寻找副标签，越靠前优先级越高。
    for tag_index: int in range(1, max_tag_count):
        candidates.clear()
        for memory: MemoryDef in source_memories:
            if (
                tag_index < memory.tags.size()
                and memory.tags[tag_index] == selected_tag
                and not excluded_memories.has(memory)
            ):
                candidates.append(memory)
        if not candidates.is_empty():
            return candidates

    return candidates



func _spawn_object(memory: MemoryDef = null) -> void:
    if memory == null:
        return
    # 根据 MemoryDef 生成 MparaObject，调用 initialize(memory) 初始化
    # spawn在 spawn_position 位置
    var object := MPARA_OBJECT_SCENE.instantiate() as MparaObject
    if object == null:
        push_error("[MANUAL PARALLAX] 无法实例化 MparaObject 场景")
        return

    object.initialize(memory)
    var is_landform := pool in [
        MemoryDef.Pool.LANDFORM_FAR,
        MemoryDef.Pool.LANDFORM_MID,
        MemoryDef.Pool.LANDFORM_FRONT,
    ]
    if is_landform:
        object.scale = Vector2.ONE
    else:
        var scale_randomness := clampf(world_assembler.spawn_scale_randomness, 0.0, 1.0)
        var random_scale_factor := randf_range(1.0 - scale_randomness, 1.0 + scale_randomness)
        object.scale = Vector2.ONE * maxf(spawn_scale_factor * random_scale_factor, 0.01)
    object.modulate = color
    add_child(object)
    # Sprite2D 使用左上角原点，因此上移纹理高度，让左下角对齐层的生成高度。
    var object_height := memory.texture.get_height() * absf(object.scale.y)
    var is_component := is_component_layer()
    var is_cloud := pool == MemoryDef.Pool.CLOUD
    var is_poi := pool == MemoryDef.Pool.POI
    var component_half_width := memory.texture.get_width() * absf(object.scale.x) * 0.5
    var horizontal_anchor_offset := component_half_width if is_component else 0.0
    object.position = spawn_position - Vector2(horizontal_anchor_offset, object_height)

    if is_landform:
        _get_surface_height_map(memory.texture)

    if is_component or is_cloud or is_poi:
        if memory.spawn_alignment == MemoryDef.SpawnAlignment.SPAWN_HEIGHT:
            object.position.y -= memory.spawn_height
        elif is_component:
            var component_world_x := to_global(spawn_position).x
            var ground_y: Variant = world_assembler.get_component_ground_y(self, component_world_x)
            if ground_y != null:
                object.global_position.y = ground_y - object_height + world_assembler.component_ground_sink
        elif is_cloud:
            var layer_origin_y: Variant = world_assembler.get_cloud_layer_origin_y(self)
            if layer_origin_y != null:
                object.global_position.y = layer_origin_y - object_height
        else:
            object.position.y = -object_height

    _objects.append(object)
    world_assembler.register_manual_parallax_spawn(self, memory, object)



func get_ground_y(world_x: float) -> Variant:
    if pool not in [
        MemoryDef.Pool.LANDFORM_FAR,
        MemoryDef.Pool.LANDFORM_MID,
        MemoryDef.Pool.LANDFORM_FRONT,
    ]:
        return null

    # 从最新生成的地形开始查找，与当前可见地形的覆盖顺序一致。
    for index: int in range(_objects.size() - 1, -1, -1):
        var landform := _objects[index] as MparaObject
        if landform == null or not is_instance_valid(landform) or landform.texture == null:
            continue

        var height_map: PackedInt32Array = _get_surface_height_map(landform.texture)
        if height_map.is_empty():
            continue

        # 精灵左上角是原点；to_local 同时处理节点位置与缩放，flip_h 再映射回图像列。
        var local_point := landform.to_local(Vector2(world_x, landform.global_position.y))
        var pixel_x := floori(local_point.x)
        if landform.flip_h:
            pixel_x = landform.texture.get_width() - 1 - pixel_x
        if pixel_x < 0 or pixel_x >= height_map.size():
            continue

        var surface_y := height_map[pixel_x]
        if surface_y < 0:
            continue
        if landform.flip_v:
            surface_y = landform.texture.get_height() - 1 - surface_y
        return landform.to_global(Vector2(
            local_point.x,
            float(surface_y)
        )).y

    return null



func _get_surface_height_map(texture: Texture2D) -> PackedInt32Array:
    var texture_id := texture.get_instance_id()
    if _surface_height_maps.has(texture_id):
        return _surface_height_maps[texture_id]

    var image := texture.get_image()
    if image == null or image.is_empty():
        _surface_height_maps[texture_id] = PackedInt32Array()
        return _surface_height_maps[texture_id]

    var height_map := PackedInt32Array()
    height_map.resize(image.get_width())
    for x: int in range(image.get_width()):
        height_map[x] = -1
        for y: int in range(image.get_height()):
            if image.get_pixel(x, y).a > SURFACE_ALPHA_THRESHOLD:
                height_map[x] = y
                break

    _surface_height_maps[texture_id] = height_map
    return height_map



func _calculate_transition_spawn_wait_time() -> float:
    if is_component_layer() and _pending_memory == null:
        return SPAWN_RECHECK_INTERVAL

    var horizontal_speed := absf(scroll_speed.x)
    if is_zero_approx(horizontal_speed):
        if is_component_layer():
            return SPAWN_RECHECK_INTERVAL
        push_warning("[MANUAL PARALLAX] 水平滚动速度为 0，无法计算过渡后的首次生成间隔：%s" % name)
        return maxf(_spawn_cooldown, 0.001)

    var rightmost_object := _get_rightmost_object()
    if rightmost_object != null and rightmost_object.memory_def != null:
        var target_distance := _get_spawn_distance(
            rightmost_object.memory_def, rightmost_object, _pending_memory
        )
        if target_distance > 0.0:
            var movement_direction := signf(scroll_speed.x)
            var traveled_distance := maxf(
                (get_object_spawn_anchor_x(rightmost_object) - spawn_position.x) * movement_direction,
                0.0
            )
            var remaining_distance := maxf(target_distance - traveled_distance, 0.0)
            return maxf(remaining_distance / horizontal_speed, 0.001)

    # 没有旧组件时，按选定候选与同宽组件之间的正常间距安排首次等待。
    if is_component_layer():
        return maxf(
            _get_spawn_distance(_pending_memory, null, _pending_memory) / horizontal_speed,
            0.001
        )

    # 当前层没有旧对象时，用新世界候选的正常间距作为首次等待时间。
    var candidates := get_memory_candidates()
    if not candidates.is_empty():
        var fallback_distance := _get_spawn_distance(candidates.front())
        if fallback_distance > 0.0:
            return maxf(fallback_distance / horizontal_speed, 0.001)

    return maxf(_spawn_cooldown, 0.001)



func _get_rightmost_object() -> MparaObject:
    var rightmost_object: MparaObject = null
    for object: Sprite2D in _objects:
        var mpara_object := object as MparaObject
        if (
            mpara_object == null
            or not is_instance_valid(mpara_object)
            or mpara_object.is_queued_for_deletion()
        ):
            continue
        if (
            rightmost_object == null
            or get_object_spawn_anchor_x(mpara_object) > get_object_spawn_anchor_x(rightmost_object)
        ):
            rightmost_object = mpara_object
    return rightmost_object



func is_component_layer() -> bool:
    return pool in [
        MemoryDef.Pool.COMPONENT_FAR,
        MemoryDef.Pool.COMPONENT_MID,
        MemoryDef.Pool.COMPONENT_FRONT,
    ]



func get_object_spawn_anchor_x(object: MparaObject) -> float:
    # 组件以中心生成；其他层沿用左边缘，避免改变地形的拼接间距。
    if is_component_layer() and object.texture != null:
        return object.position.x + object.texture.get_width() * absf(object.scale.x) * 0.5
    return object.position.x



func _get_spawn_distance(
    memory: MemoryDef,
    object: MparaObject = null,
    next_memory: MemoryDef = null
) -> float:
    if memory == null or memory.texture == null:
        return 0.0
    # 已生成对象使用自身实际倍率，候选对象使用本层的生成倍率。
    var scale_factor := absf(object.scale.x) if object != null else spawn_scale_factor
    var previous_width := memory.texture.get_width() * scale_factor
    if not is_component_layer():
        return maxf(memory.spawn_distance_ratio, 0.0) * previous_width

    # 同宽且倍率 >= 1 时保持原有间距；倍率 <= 1 时组件只相接，不再重叠。
    var empty_gap := maxf(memory.spawn_distance_ratio - 1.0, 0.0) * previous_width
    var next_width := 0.0
    if next_memory != null and next_memory.texture != null:
        next_width = next_memory.texture.get_width() * spawn_scale_factor
    # 尚未选择候选时只计算等待下限，选定后再补上候选半宽并复核。
    return (previous_width + next_width) * 0.5 + empty_gap



func _update_spawn_timer(memory: MemoryDef = null) -> void:
    # 组件先按等待下限唤醒，再结合候选宽度复核；其他层沿用原有间距。
    if memory == null or memory.texture == null:
        return

    var horizontal_speed := absf(scroll_speed.x)
    if is_zero_approx(horizontal_speed):
        if is_component_layer():
            _spawn_cooldown = SPAWN_RECHECK_INTERVAL
            if is_instance_valid(_spawn_timer):
                _spawn_timer.wait_time = _spawn_cooldown
            return
        push_warning("[MANUAL PARALLAX] 水平滚动速度为 0，无法计算生成间隔：%s" % name)
        return

    var spawn_distance := _get_spawn_distance(memory)
    _spawn_cooldown = maxf(spawn_distance / horizontal_speed, 0.001)
    if is_instance_valid(_spawn_timer):
        _spawn_timer.wait_time = _spawn_cooldown




func _calculate_remaining_spawn_wait_time(next_memory: MemoryDef = null) -> float:
    var rightmost_object := _get_rightmost_object()
    if rightmost_object == null or rightmost_object.memory_def == null:
        return 0.0

    var target_distance := _get_spawn_distance(
        rightmost_object.memory_def, rightmost_object, next_memory
    )
    if target_distance <= 0.0:
        return 0.0

    var horizontal_speed := absf(scroll_speed.x)
    if is_zero_approx(horizontal_speed):
        # 滚动暂停时短间隔复查，避免在原生成点继续叠加对象。
        return SPAWN_RECHECK_INTERVAL

    var movement_direction := signf(scroll_speed.x)
    var traveled_distance := maxf(
        (get_object_spawn_anchor_x(rightmost_object) - spawn_position.x) * movement_direction,
        0.0
    )
    var remaining_distance := target_distance - traveled_distance
    var distance_epsilon := 0.0 if is_component_layer() else SPAWN_DISTANCE_EPSILON
    if remaining_distance <= distance_epsilon:
        return 0.0
    return remaining_distance / horizontal_speed




func _on_spawn_timer_timeout() -> void:
    if is_component_layer():
        _on_component_spawn_timer_timeout()
        return

    # Timer 只负责唤醒；生成前以对象真实位置复核，避免速度变化或计时偏差导致同层重叠。
    var remaining_wait_time := _calculate_remaining_spawn_wait_time()
    if remaining_wait_time > 0.0:
        _spawn_timer.wait_time = maxf(remaining_wait_time, 0.001)
        return

    var next_memory := _request_next_memory()
    _spawn_object(next_memory)
    _update_spawn_timer(next_memory)



func _on_component_spawn_timer_timeout() -> void:
    # 等待期间保留候选；真正生成前重查跨层占用，防止其他层抢先使用同一 Memory。
    if (
        _pending_memory != null
        and not world_assembler.can_spawn_manual_parallax_memory(self, _pending_memory)
    ):
        _pending_memory = null
    if _pending_memory == null:
        _pending_memory = _request_next_memory()
    if _pending_memory == null:
        # 候选不足时沿用正常周期，避免每次短复查都重新抽取并输出警告。
        _spawn_timer.start(maxf(_spawn_cooldown, SPAWN_RECHECK_INTERVAL))
        return

    var remaining_wait_time := _calculate_remaining_spawn_wait_time(_pending_memory)
    if remaining_wait_time > 0.0:
        _spawn_timer.start(maxf(remaining_wait_time, 0.001))
        return

    var next_memory := _pending_memory
    _spawn_object(next_memory)
    _pending_memory = null
    _update_spawn_timer(next_memory)
    _spawn_timer.start()



func _request_next_memory() -> MemoryDef:
    return world_assembler.get_manual_parallax_memory(self)




#region old_code


#endregion
