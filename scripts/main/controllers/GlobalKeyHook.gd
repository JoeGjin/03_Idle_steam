# 全局键盘钩子的 GDScript 包装层，负责初始化扩展实例并向 Main 转发按键事件。

extends Node


# GDExtension 提供的原生钩子实例，由本节点持有。
var _hook: GlobalKeyHook

# 仅在 _ready 中读取，决定启动时是否创建钩子实例。
@export var hook_switch : bool = false
signal any_key_pressed


# 目录（与下方代码分区顺序一致）
# 1. 钩子初始化：_ready 按 hook_switch 创建原生实例，并连接按键信号。
# 2. 按键信号转发：_on_any_key_pressed 向外发出 any_key_pressed，由 Main 响应。
# 3. 焦点调试：_notification 记录应用获得或失去焦点，不改变钩子状态。


#region 钩子初始化

func _ready() -> void:
	if hook_switch:
		_hook = GlobalKeyHook.new()
		add_child(_hook)
		_hook.any_key_pressed.connect(_on_any_key_pressed)
	else :
		print("GlobalKeyHook is disabled by hook_switch.")

#endregion


#region 按键信号转发

func _on_any_key_pressed() -> void:
	any_key_pressed.emit()

#endregion


#region 焦点调试

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			print("[FOCUS] IN (game window active)")
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			print("[FOCUS] OUT (game window inactive)")

#endregion
