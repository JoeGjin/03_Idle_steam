extends Sprite2D
class_name Mpara_Object


@export var memory_def: MemoryDef




func initialize(incoming_memory_def: MemoryDef) -> void:
    self.memory_def = incoming_memory_def
    texture = memory_def.texture


func _ready() -> void:
    centered = false
    global_position = Vector2.ZERO


