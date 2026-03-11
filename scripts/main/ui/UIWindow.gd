extends Window


@onready var _close_button: Button = %CollectionBook/Panel/Buttons/Close



func _ready():
    
    #开关来取消初始化黑屏
    show()
    hide()
    
    # 连接关闭按钮的信号
    _close_button.pressed.connect(_on_close_button_pressed)


func _on_close_button_pressed(): 
    # 关闭窗口
    self.hide()

