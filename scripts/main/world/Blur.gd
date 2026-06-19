extends ColorRect

@export var lod: int = 0



func _ready():
    if lod == 0:
        material.set_shader_parameter("lod", %WorldRoot.lod)