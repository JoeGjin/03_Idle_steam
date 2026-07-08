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

# @export var fit_layers: Array[String] = [] # "Cloud_1", "Landform_1", "Component_1", match with world layers