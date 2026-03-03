extends AnimatedSprite2D


@onready var mood: Control = $mood
@onready var mood_stay_timer: Timer = $mood/stay

@export var mouse_in_body: bool = false


signal mouse_entered_body
signal mouse_exited_body


func _ready():
	mood.hide()
	mood_stay_timer.one_shot = true
	mood_stay_timer.wait_time = 0.2
	mood_stay_timer.timeout.connect(_on_stay_timeout)


# 外部调用，显示或隐藏心情图标
func mood_show(on: bool) -> void:
	if on:
		if not mood.is_visible():
			mood.show()
	else:
		mood_stay_timer.start()

func _on_body_mouse_exited() -> void:
	mouse_in_body = false
	mouse_exited_body.emit()

func _on_body_mouse_entered() -> void:
	mouse_in_body = true
	mouse_entered_body.emit()


func _on_stay_timeout() -> void:
	if not mouse_in_body:
		mood.hide()
