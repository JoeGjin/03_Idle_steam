extends Node
class_name MemoryController


# 待领取次数实际变化时通知 Main 更新收集 UI。
signal pending_collection_count_changed(count: int, max_count: int)


@export_group("Collection Event")
## 每次增加待领取次数的间隔（秒），可在 Inspector 中调整。
@export_range(1.0, 3600.0, 1.0, "or_greater", "suffix:s") var collection_interval_seconds := 60.0
## 待领取收集事件的累计上限。
@export_range(1, 100, 1, "or_greater") var max_pending_collection_count := 5

@export_group("Debug")
## 启动时提供一次待领取事件，便于检查收集按钮。
@export var debug_show_collected_item := false


# 资源索引容器：Tag → MemoryPools.by_pool → MemoryList.memories。
class MemoryList:
    var memories: Array[MemoryDef] = []


class MemoryPools:
    var by_pool: Dictionary[MemoryDef.Pool, MemoryList] = {}


# 所有 Memory 按各自的全部标签和所属池建立索引，供世界生成查询。
var memories_by_tag: Dictionary[Tags.Tag, MemoryPools] = {}

# 仅包含可收集、有纹理且至少有一个标签的 Memory，供选择流程抽取。
var collectable_memories: Array[MemoryDef] = []

# 待领取次数与定时累计所用的计时器。
var pending_collection_count := 0
var _collection_event_timer: Timer


# 本脚本加载 MemoryDef 资源、维护标签与池索引，并管理待领取事件和收集候选。
# Main 协调领取与二选一流程；WorldAssembler 和 ManualParallax 查询资源索引用于世界生成。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与初始化
#    建立资源索引，在调试构建中打印数据库，然后启动累计计时并按调试开关补一次待领取事件。
#    入口：_ready
# 2. Memory 资源加载与索引
#    递归扫描 memory/defs 下的 .tres，加载 MemoryDef，建立标签与池索引及可收集列表。
#    一个 Memory 可归入多个标签；可收集列表额外要求 is_collectable、纹理及标签有效。
#    核心：_build_memories_by_tag / _collect_memory_resource_paths
# 3. 待领取事件累计与领取
#    计时器不受时间缩放和场景树暂停影响，按间隔增加次数并限制上限。
#    领取时返回当前全部次数并清零；次数实际变化时发出 pending_collection_count_changed。
#    入口：get_max_pending_collection_count / add_pending_collection_event / collect_all_pending_events
# 4. 收集候选抽取
#    首个候选先按可用世界标签权重选标签，再从包含该标签的可收集资源中等概率抽取。
#    后续候选从主标签不同于首个候选的资源中等概率抽取，候选资源互不重复。
#    候选不足时返回已有结果，由 Main 决定是否继续选择流程。
#    入口：get_random_collectable_memories
# 5. Debug 数据库输出
#    按标签、池与资源文件名输出索引内容。
#    入口：_print_memory_database


#region 生命周期与初始化

func _ready() -> void:
    _build_memories_by_tag()
    if OS.is_debug_build():
        _print_memory_database()
    _setup_collection_event_timer()
    if debug_show_collected_item:
        _set_pending_collection_count(1)

#endregion


#region Memory 资源加载与索引

func _build_memories_by_tag() -> void:
    memories_by_tag.clear()
    collectable_memories.clear()
    var memory_paths := _collect_memory_resource_paths(
        "res://scripts/main/controllers/memory/defs"
    )

    for memory_path: String in memory_paths:
        var resource := ResourceLoader.load(memory_path)
        if not (resource is MemoryDef):
            push_warning("跳过非 MemoryDef 资源：%s" % memory_path)
            continue

        var memory := resource as MemoryDef
        if memory.is_collectable and memory.texture != null and not memory.tags.is_empty():
            collectable_memories.append(memory)

        for tag: Tags.Tag in memory.tags:
            if not memories_by_tag.has(tag):
                memories_by_tag[tag] = MemoryPools.new()

            var pools: MemoryPools = memories_by_tag[tag]
            if not pools.by_pool.has(memory.pool):
                pools.by_pool[memory.pool] = MemoryList.new()

            var memory_list: MemoryList = pools.by_pool[memory.pool]
            if not memory_list.memories.has(memory):
                memory_list.memories.append(memory)


func _collect_memory_resource_paths(
    directory_path: String
) -> Array[String]:
    var memory_paths: Array[String] = []
    var directory := DirAccess.open(directory_path)
    if directory == null:
        push_warning("无法读取 MemoryDef 目录：%s" % directory_path)
        return memory_paths

    directory.list_dir_begin()
    var entry_name := directory.get_next()
    while entry_name != "":
        if entry_name != "." and entry_name != "..":
            var entry_path := directory_path.path_join(entry_name)
            if directory.current_is_dir():
                var child_paths := _collect_memory_resource_paths(entry_path)
                memory_paths.append_array(child_paths)
            elif entry_name.get_extension().to_lower() == "tres":
                memory_paths.append(entry_path)
        entry_name = directory.get_next()
    directory.list_dir_end()
    return memory_paths

#endregion


#region 待领取事件累计与领取

func get_max_pending_collection_count() -> int:
    return maxi(max_pending_collection_count, 1)


func add_pending_collection_event(amount: int = 1) -> int:
    if amount <= 0:
        return pending_collection_count

    _set_pending_collection_count(
        mini(
            pending_collection_count + amount,
            get_max_pending_collection_count()
        )
    )
    return pending_collection_count


## 领取当前全部待处理事件，并将累计次数清零。
func collect_all_pending_events() -> int:
    var collected_count := pending_collection_count
    _set_pending_collection_count(0)
    return collected_count


func _setup_collection_event_timer() -> void:
    _collection_event_timer = Timer.new()
    _collection_event_timer.name = "CollectionEventTimer"
    _collection_event_timer.wait_time = maxf(collection_interval_seconds, 1.0)
    _collection_event_timer.one_shot = false
    _collection_event_timer.ignore_time_scale = true
    _collection_event_timer.process_mode = Node.PROCESS_MODE_ALWAYS
    _collection_event_timer.timeout.connect(_on_collection_event_timer_timeout)
    add_child(_collection_event_timer)
    _collection_event_timer.start()


func _on_collection_event_timer_timeout() -> void:
    add_pending_collection_event()


func _set_pending_collection_count(value: int) -> void:
    var next_count := clampi(value, 0, get_max_pending_collection_count())
    if next_count == pending_collection_count:
        return

    pending_collection_count = next_count
    pending_collection_count_changed.emit(
        pending_collection_count,
        get_max_pending_collection_count()
    )

#endregion


#region 收集候选抽取

## 第一个候选按当前世界标签权重抽取；后续候选从全部可收集记忆中等概率抽取。
## 后续候选的主标签必须与第一个候选不同，候选资源互不重复。
## 没有纹理或主标签的资源无法完成当前选择流程，因此不会进入候选。
func get_random_collectable_memories(
    weighted_tags: Dictionary[Tags.Tag, float],
    count: int = 2
) -> Array[MemoryDef]:
    var result: Array[MemoryDef] = []
    if count <= 0 or collectable_memories.is_empty() or weighted_tags.is_empty():
        return result

    var available_tags: Array[Tags.Tag] = []
    for tag: Tags.Tag in weighted_tags:
        if weighted_tags[tag] > 0.0 and not _get_collectable_memories_for_tag(tag).is_empty():
            available_tags.append(tag)

    if available_tags.is_empty():
        return result

    var selected_tag := _pick_weighted_tag(available_tags, weighted_tags)
    var tag_candidates := _get_collectable_memories_for_tag(selected_tag)
    var first_memory: MemoryDef = tag_candidates.pick_random()
    result.append(first_memory)
    if count == 1:
        return result

    var remaining_candidates: Array[MemoryDef] = []
    for memory in collectable_memories:
        if memory.tags[0] != first_memory.tags[0]:
            remaining_candidates.append(memory)

    for _index in range(1, count):
        if remaining_candidates.is_empty():
            break
        var chosen_memory: MemoryDef = remaining_candidates.pick_random()
        result.append(chosen_memory)
        remaining_candidates.erase(chosen_memory)

    return result


func _get_collectable_memories_for_tag(tag: Tags.Tag) -> Array[MemoryDef]:
    var result: Array[MemoryDef] = []
    for memory in collectable_memories:
        if tag in memory.tags:
            result.append(memory)
    return result


func _pick_weighted_tag(
    available_tags: Array[Tags.Tag],
    weighted_tags: Dictionary[Tags.Tag, float]
) -> Tags.Tag:
    var total_weight := 0.0
    for tag in available_tags:
        total_weight += maxf(weighted_tags[tag], 0.0)

    var random_weight := randf() * total_weight
    for tag in available_tags:
        random_weight -= maxf(weighted_tags[tag], 0.0)
        if random_weight <= 0.0:
            return tag

    return available_tags[-1]

#endregion


#region Debug 数据库输出

func _print_memory_database() -> void:
    print("========== Memory Database ==========")

    for tag: Tags.Tag in memories_by_tag:
        var tag_name := String(Tags.Tag.keys()[tag])
        print(tag_name)

        var pools: MemoryPools = memories_by_tag[tag]
        for pool: MemoryDef.Pool in pools.by_pool:
            var pool_name := String(MemoryDef.Pool.keys()[pool])
            var memory_list: MemoryList = pools.by_pool[pool]
            print("  └─ %s (%d)" % [pool_name, memory_list.memories.size()])

            for memory: MemoryDef in memory_list.memories:
                print("      └─ %s" % memory.resource_path.get_file())

#endregion
