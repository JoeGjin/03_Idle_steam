extends Node2D

@onready var _exit_button: Button = $Exit

@export_range(0.0, 10.0, 0.1) var lod: float = 0.5 # 模糊程度


func _ready():

    # 初始将 pet 放在视口中心
    global_position = get_viewport().get_visible_rect().size * 0.5

    # 连接退出按钮的信号
    _exit_button.pressed.connect(_on_exit_button_pressed)

    show()


func _on_exit_button_pressed():
    get_tree().quit()