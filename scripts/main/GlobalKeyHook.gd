extends Node

var _hook: GlobalKeyHook

signal any_key_pressed

func _ready() -> void:
	_hook = GlobalKeyHook.new()
	add_child(_hook)

	_hook.any_key_pressed.connect(_on_any_key_pressed)

	print("GlobalKeyHook ready.")
	print("Tip: switch to another window and press any key to test background input.")

func _on_any_key_pressed() -> void:
	any_key_pressed.emit()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			print("[FOCUS] IN (game window active)")
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			print("[FOCUS] OUT (game window inactive)")
