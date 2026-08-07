extends Node
class_name MemoryController



class MemoryList:
    var memories: Array[MemoryDef] = []
class MemoryPools:
    var by_pool: Dictionary[MemoryDef.Pool, MemoryList] = {}
var memories_by_tag: Dictionary[Tags.Tag, MemoryPools] = {} 
# {HOLY:{POI: [memory_1,memory_2],CLOUD: [memory_3,memroy_4]}




func _ready() -> void:
    _build_memories_by_tag()
    if OS.is_debug_build():
        _print_memory_database()


func _build_memories_by_tag() -> void:
    memories_by_tag.clear()
    var memory_paths := _collect_memory_resource_paths(
        "res://scripts/main/controllers/memory/defs"
    )

    for memory_path: String in memory_paths:
        var resource := ResourceLoader.load(memory_path)
        if not (resource is MemoryDef):
            push_warning("跳过非 MemoryDef 资源：%s" % memory_path)
            continue

        var memory := resource as MemoryDef
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


# func tag_calculation(items: Array[String]) -> Dictionary:
#     # var result := {
#     #     "target_world_id": -1, # 目标世界ID，默认为-1表示未指定
#     #     "sub_world_id": -1, # 可选的子世界ID，默认为-1表示未指定
#     #     "sub_world_weight": 0.0 # 可选的子世界权重，范围0.0-1.0，默认为0.0表示未指定
#     # }

#     # 0. 处理标签计算结果，决定发送到哪个世界
#     var tag_calc: Dictionary = {} # 贴图标签计数，格式为 { tag: count, ... }
#     for item in items:
#         # 更新标签计数
#         if item == "":
#             continue # 跳过空字符串，避免处理未选择的 memory slot
#         var item_name_parts: Array = str(item).split("_")
#         var sticker_key: String = "_".join(item_name_parts.slice(0, 3))
#         var tags: Array = sticker_to_tag(sticker_key)
#         for tag in tags:
#             if not tag_calc.has(tag):
#                 tag_calc[tag] = 0
#             tag_calc[tag] += 1

#     # 1. 得到 tag 的总数 tags_total from tag_calc
#     var tags_total: int = 0
#     for tag in tag_calc:
#         tags_total += tag_calc[tag]
#     # 2. 根据 tag_calc 和 tags_total 计算每个 tag 的占比，并乘以对应权重，得到一个 weight
#     var world_scores: Dictionary[int, float] = {} # world_id -> weight
#     for tag in tag_calc:
#         var count: int = tag_calc[tag]
#         world_scores[tag] = float(count) / float(tags_total) # 这里假设 tag 的数值就是对应世界的权重，实际可以根据设计调整
#     # 3. 根据计算得到的 weight 决定 target_world_id（最高weight），sub_world_id（次高weight）和 sub_world_weight（次高weight占比）
   
#     var result := _get_top_two_worlds(world_scores)
#     return result


# func _get_top_two_worlds(world_scores: Dictionary[int, float]) -> Dictionary:
#     var target_world_id_t := -1
#     var target_world_weight := -INF
    
#     var sub_world_id_t := -1
#     var sub_world_weight_t := -INF
    
#     for world_id: int in world_scores:
#         var weight: float = world_scores[world_id]
        
#         if weight > target_world_weight:
#             sub_world_id_t = target_world_id_t
#             sub_world_weight_t = target_world_weight
            
#             target_world_id_t = world_id
#             target_world_weight = weight
        
#         elif weight > sub_world_weight_t:
#             sub_world_id_t = world_id
#             sub_world_weight_t = weight
    
#     return {
#         "target_world_id": target_world_id_t,
#         "sub_world_id": sub_world_id_t,
#         "sub_world_weight": sub_world_weight_t,
#     }




# func sticker_to_tag(sticker_key: String) -> Array:
#     if TAG_BY_STICKER.has(sticker_key):
#         return TAG_BY_STICKER[sticker_key]
#     else:
#         return [] # 返回空数组表示没有标签


# func tag_to_stickers(tag: int) -> Array:
#     if sticker_by_tag.has(tag):
#         return sticker_by_tag[tag]
#     else:
#         return [] # 返回空数组表示没有贴图



