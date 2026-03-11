extends Control



func _ready():
    if Debug.enabled:
        show()
    else:
        hide()