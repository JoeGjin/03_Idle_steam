extends ColorRect

@export var lod: int = 0



func _ready() -> void:
    # 每层保留独立的参数，避免更新共享材质时影响不跟随全局 LOD 的层。
    material = material.duplicate()
    var world_root = %WorldRoot
    world_root.lod_changed.connect(_update_lod)
    _update_lod(world_root.get_effective_lod())


func _update_lod(value: float) -> void:
    if lod == 0:
        material.set_shader_parameter("lod", value)
