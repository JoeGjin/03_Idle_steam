extends Window


# 窗口内的关闭按钮，启动时连接其 pressed 信号。
@onready var close_button: Button = %CloseUI


# 本脚本管理 UI 窗口的打开、隐藏，以及关闭按钮和 ESC 输入。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与初始化：保持窗口隐藏，并连接关闭按钮。
#    入口：_ready
# 2. 窗口开关：居中弹出窗口，或隐藏窗口以便下次重新打开。
#    入口：open_uiwindow / close_uiwindow；Main 通过 open_uiwindow 打开收集窗口。
# 3. 关闭事件：关闭按钮与未处理的 ESC 输入共用关闭回调，ESC 处理后标记输入已消费。
#    入口：_unhandled_input / _on_close_button_pressed


#region 生命周期与初始化

func _ready():
	# 启动时保持隐藏，避免预热原生窗口时闪出空白矩形。
	hide()
	close_button.pressed.connect(_on_close_button_pressed)

#endregion


#region 窗口开关

func open_uiwindow():
	popup_centered()


func close_uiwindow():
	hide()

#endregion


#region 关闭事件

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ESC"):
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()


func _on_close_button_pressed():
	close_uiwindow()

#endregion
