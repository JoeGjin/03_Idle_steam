# 记忆定义资源，包含id，texture，tags，fit layers, pool等属性

extends Resource
class_name MemoryDef

@export var is_collectable: bool = false # 是否可被玩家收集，默认为 false
# @export var id: String = "XX000" # xx (CL,LF,CP,PI) + xxx (num)
@export var texture: Texture2D

## 第一个tag是最贴切的标签，主标签。后续副标签表示该记忆也可以在其他氛围中出现。
@export var tags: Array[Tags.Tag] = [] 

enum Pool { POI, CLOUD, LANDFORM_FAR, LANDFORM_MID, LANDFORM_FRONT, COMPONENT_FAR, COMPONENT_MID, COMPONENT_FRONT }
@export var pool: Pool = Pool.POI 

## 生成距离比率；根据ratio * 自身宽度，对应层的scroll speed，前一个texture的宽度，算出层的updated timer cooldown
@export var spawn_distance_ratio: float = 5.0 
