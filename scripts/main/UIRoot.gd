extends Control

@onready var _close_button: Button = $CollectionBook/Panel/Buttons/Close
@onready var ui_window: Window = get_parent()



func _ready():
    # 连接关闭按钮的信号
    _close_button.pressed.connect(_on_close_button_pressed)


func _on_close_button_pressed():
    # 关闭窗口
    ui_window.hide()