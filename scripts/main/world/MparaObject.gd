extends Sprite2D
class_name MparaObject


# 当前实例对应的 Memory 定义，供生成登记、间距和地表查询使用。
@export var memory_def: MemoryDef


# 本脚本承载单个手动视差对象的 Memory 定义与纹理。
#
# 目录（与下方代码分区顺序一致）
# 1. Memory 数据初始化：initialize 接收 MemoryDef，并将其纹理赋给精灵。
#    ManualParallax 在 add_child 前调用，缩放、颜色和最终位置由 ManualParallax 设置。
# 2. 入树设置：_ready 使用左上角原点，并先将全局位置归零。
#    ManualParallax 在入树完成后再设置最终生成位置，保持已有初始化顺序。


#region Memory 数据初始化

func initialize(incoming_memory_def: MemoryDef) -> void:
    self.memory_def = incoming_memory_def
    texture = memory_def.texture

#endregion


#region 入树设置

func _ready() -> void:
    centered = false
    global_position = Vector2.ZERO

#endregion
