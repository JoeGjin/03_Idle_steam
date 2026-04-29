extends Node2D




func _ready() -> void:
    visible = Debug.enabled
    get_child(0).visible = Debug.enabled