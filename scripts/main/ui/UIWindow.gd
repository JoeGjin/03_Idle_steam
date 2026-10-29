extends Window


# 窗口内的关闭按钮，启动时连接其 pressed 信号。
@onready var close_button: Button = %CloseUI


# 仅在本窗口收到右键按下后，才允许对应的松开触发关闭。
var _right_click_close_pending := false


# 本脚本管理 UI 窗口的打开、隐藏，以及右键、关闭按钮和 ESC 输入。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与初始化：连接关闭按钮；启动隐藏由 Main._enter_tree 在本窗口入树前完成。
#    入口：_ready
# 2. 窗口开关：居中弹出窗口，或隐藏窗口以便下次重新打开；开关时清理右键关闭记录。
#    入口：open_uiwindow / close_uiwindow；Main 通过 open_uiwindow 打开收集窗口。
# 3. 关闭事件：窗口显示时消费右键按下并记录关闭请求，消费对应松开后再隐藏窗口。
#    关闭按钮与未处理的 ESC 输入共用关闭回调；ESC 处理后标记输入已消费。
#    入口：_input / _unhandled_input / _on_close_button_pressed


#region 生命周期与初始化

func _ready():
	close_button.pressed.connect(_on_close_button_pressed)

#endregion


#region 窗口开关

func open_uiwindow():
	_right_click_close_pending = false
	popup_centered()


func close_uiwindow():
	_right_click_close_pending = false
	hide()

#endregion


#region 关闭事件

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# 保持原生窗口显示到右键松开，避免按下后立刻隐藏，让松开落到后面的程序。
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
	):
		get_viewport().set_input_as_handled()
		if event.pressed:
			_right_click_close_pending = true
		elif _right_click_close_pending:
			close_uiwindow()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ESC"):
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()


func _on_close_button_pressed():
	close_uiwindow()

#endregion
