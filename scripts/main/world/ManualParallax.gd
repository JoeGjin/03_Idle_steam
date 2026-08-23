extends Node2D

class_name ManualParallax


const MPARA_OBJECT_SCENE: PackedScene = preload("res://scenes/MparaObject.tscn")
const SPAWN_DISTANCE_EPSILON := 1.0
const SPAWN_RECHECK_INTERVAL := 0.25


@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var memory_controller : MemoryController = %MemoryController

@export var spawn_position: Vector2 = Vector2(1920 + 300,0) # 生成位置，默认在屏幕右侧400像素


var pool: MemoryDef.Pool 
var scroll_speed: Vector2 = Vector2.ZERO
var color: Color = Color(1, 1, 1, 1)

var weighted_tags: Dictionary[Tags.Tag, float]


var _objects: Array[Sprite2D] = []
var _is_scrolling: bool = true
var _spawn_timer: Timer
var _spawn_cooldown: float = 999.0
var _fade_tween: Tween


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
    if _fade_tween != null and _fade_tween.is_valid():
        _fade_tween.kill()
    _fade_tween = null

    # 先读取旧对象位置，再按过渡模式清理，避免清理右侧对象后丢失原有间距基准。
    var transition_wait_time := 0.0
    if not spawn_immediately:
        transition_wait_time = _calculate_transition_spawn_wait_time()
    
    _free_all_timer() # 先停止计时器
    
    match mode:
        0:
            _free_all_children()
        1:
            _free_distant_children(0.85)

    _initialize_timer()

    if spawn_immediately:
        var next_memory := _request_next_memory()
        _spawn_object(next_memory)
        _update_spawn_timer(next_memory)
    else:
        _spawn_timer.wait_time = maxf(transition_wait_time, 0.001)
    
    _spawn_timer.start()
    _is_scrolling = true



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
    _spawn_timer.one_shot = false
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
    object.modulate = color
    add_child(object)
    object.position = spawn_position
    _objects.append(object)
    world_assembler.register_manual_parallax_spawn(self, memory, object)



func _calculate_transition_spawn_wait_time() -> float:
    var horizontal_speed := absf(scroll_speed.x)
    if is_zero_approx(horizontal_speed):
        push_warning("[MANUAL PARALLAX] 水平滚动速度为 0，无法计算过渡后的首次生成间隔：%s" % name)
        return maxf(_spawn_cooldown, 0.001)

    var rightmost_object := _get_rightmost_object()
    if rightmost_object != null and rightmost_object.memory_def != null:
        var target_distance := _get_spawn_distance(rightmost_object.memory_def)
        if target_distance > 0.0:
            var movement_direction := signf(scroll_speed.x)
            var traveled_distance := maxf(
                (rightmost_object.position.x - spawn_position.x) * movement_direction,
                0.0
            )
            var remaining_distance := maxf(target_distance - traveled_distance, 0.0)
            return maxf(remaining_distance / horizontal_speed, 0.001)

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
        if mpara_object == null or not is_instance_valid(mpara_object):
            continue
        if rightmost_object == null or mpara_object.position.x > rightmost_object.position.x:
            rightmost_object = mpara_object
    return rightmost_object



func _get_spawn_distance(memory: MemoryDef) -> float:
    if memory == null or memory.texture == null:
        return 0.0
    return maxf(memory.spawn_distance_ratio, 0.0) * memory.texture.get_width()



func _update_spawn_timer(memory: MemoryDef = null) -> void:
    # 根据 memory 的 spawn_distance_ratio * texture宽度算出距离下个object的距离
    # 然后根据该ManualParallax的 scroll speed，算出下一个object spawn的 cooldown
    if memory == null or memory.texture == null:
        return

    var horizontal_speed := absf(scroll_speed.x)
    if is_zero_approx(horizontal_speed):
        push_warning("[MANUAL PARALLAX] 水平滚动速度为 0，无法计算生成间隔：%s" % name)
        return

    var spawn_distance := _get_spawn_distance(memory)
    _spawn_cooldown = maxf(spawn_distance / horizontal_speed, 0.001)
    if is_instance_valid(_spawn_timer):
        _spawn_timer.wait_time = _spawn_cooldown




func _calculate_remaining_spawn_wait_time() -> float:
    var rightmost_object := _get_rightmost_object()
    if rightmost_object == null or rightmost_object.memory_def == null:
        return 0.0

    var target_distance := _get_spawn_distance(rightmost_object.memory_def)
    if target_distance <= 0.0:
        return 0.0

    var horizontal_speed := absf(scroll_speed.x)
    if is_zero_approx(horizontal_speed):
        # 滚动暂停时短间隔复查，避免在原生成点继续叠加对象。
        return SPAWN_RECHECK_INTERVAL

    var movement_direction := signf(scroll_speed.x)
    var traveled_distance := maxf(
        (rightmost_object.position.x - spawn_position.x) * movement_direction,
        0.0
    )
    var remaining_distance := target_distance - traveled_distance
    if remaining_distance <= SPAWN_DISTANCE_EPSILON:
        return 0.0
    return remaining_distance / horizontal_speed




func _on_spawn_timer_timeout() -> void:
    # Timer 只负责唤醒；生成前以对象真实位置复核，避免速度变化或计时偏差导致同层重叠。
    var remaining_wait_time := _calculate_remaining_spawn_wait_time()
    if remaining_wait_time > 0.0:
        _spawn_timer.wait_time = maxf(remaining_wait_time, 0.001)
        return

    var next_memory := _request_next_memory()
    _spawn_object(next_memory)
    _update_spawn_timer(next_memory)



func _request_next_memory() -> MemoryDef:
    return world_assembler.get_manual_parallax_memory(self)




#region old_code


#endregion
