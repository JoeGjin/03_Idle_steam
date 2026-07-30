extends Window


@onready var close_button: Button = %CloseUI





func open_uiwindow():
	popup_centered()


func close_uiwindow():
	hide() 



func _ready():
	
	#开关来取消初始化黑屏
	show()
	hide()
	

	# 连接关闭按钮的信号
	close_button.pressed.connect(_on_close_button_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ESC"):
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()


func _on_close_button_pressed(): 
	close_uiwindow()


