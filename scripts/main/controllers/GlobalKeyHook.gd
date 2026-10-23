# 全局键盘钩子的 GDScript 包装层，负责启停扩展实例并向 Main 转发按键事件。

extends Node


# GDExtension 提供的原生钩子实例，由本节点持有。
var _hook: GlobalKeyHook

# mini 模式的临时暂停状态，不覆盖 Inspector 中的总开关。
var _suspended := false
# 原生扩展的待处理按键标记是静态变量，重建后先让原生实例处理一帧，丢弃旧标记。
var _ignore_input_until_frame := 0

# 启动及恢复时读取，决定是否创建钩子实例。
@export var hook_switch : bool = false
signal any_key_pressed


# 目录（与下方代码分区顺序一致）
# 1. 钩子初始化与启停：_ready / set_suspended 通过 _sync_hook 按总开关与暂停状态创建或释放原生实例。
#    暂停时立即释放实例以解除 Windows 键盘钩子，恢复时重建并连接按键信号。
# 2. 按键信号转发：_on_any_key_pressed 在暂停和重建缓冲期间丢弃事件，其余转发给 Main。
# 3. 焦点调试：_notification 记录应用获得或失去焦点，不改变钩子状态。


#region 钩子初始化与启停

func _ready() -> void:
	_sync_hook()
	if not hook_switch:
		print("GlobalKeyHook is disabled by hook_switch.")


func set_suspended(suspended: bool) -> void:
	if _suspended == suspended:
		return
	_suspended = suspended
	_sync_hook()


func _sync_hook() -> void:
	if not hook_switch or _suspended:
		if _hook != null:
			_hook.free()
			_hook = null
		return
	if _hook != null:
		return

	_ignore_input_until_frame = Engine.get_process_frames() + 1
	_hook = GlobalKeyHook.new()
	add_child(_hook)
	_hook.any_key_pressed.connect(_on_any_key_pressed)

#endregion


#region 按键信号转发

func _on_any_key_pressed() -> void:
	if _suspended or Engine.get_process_frames() <= _ignore_input_until_frame:
		return
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
