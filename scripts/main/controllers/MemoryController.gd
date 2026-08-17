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


