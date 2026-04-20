extends ColorRect





func _ready():
# func _process(_delta: float) -> void:
    material.set_shader_parameter("lod", %WorldRoot.lod)