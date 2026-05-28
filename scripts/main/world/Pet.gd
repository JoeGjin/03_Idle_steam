extends AnimatedSprite2D


@export var mouse_in_body: bool = false


signal mouse_entered_body
signal mouse_exited_body



func _on_body_mouse_exited() -> void:
	mouse_in_body = false
	mouse_exited_body.emit()


func _on_body_mouse_entered() -> void:
	mouse_in_body = true
	mouse_entered_body.emit()


