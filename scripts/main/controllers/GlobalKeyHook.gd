# 本脚本用于全局键盘钩子功能的初始化与信号转发

extends Node

var _hook: GlobalKeyHook

@export var hook_switch : bool = false
signal any_key_pressed


func _ready() -> void:
	
	if hook_switch:

		_hook = GlobalKeyHook.new()
		add_child(_hook)
	
		_hook.any_key_pressed.connect(_on_any_key_pressed)

		# print("GlobalKeyHook ready.")
	else :
		print("GlobalKeyHook is disabled by hook_switch.")


func _on_any_key_pressed() -> void:
	any_key_pressed.emit()


func _notification(what: int) -> void:
	# 处理应用程序焦点变化通知
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			print("[FOCUS] IN (game window active)")
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			print("[FOCUS] OUT (game window inactive)")
