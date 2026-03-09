

extends Node
class_name ColorPickController

@export var pet: AnimatedSprite2D
@export var color_picker: Control
@export var color_picker_stay_timer: Timer

signal color_chosen(color_name: String)


func initialize():
	color_picker.hide()
	color_picker_stay_timer.one_shot = true
	color_picker_stay_timer.wait_time = 0.2
	color_picker_stay_timer.timeout.connect(_on_stay_timeout)
	_color_pool_setup()



# 外部调用，显示或隐藏心情图标
func color_picker_show(on: bool) -> void:
	if on:
		if not color_picker.is_visible():
			color_picker.show()
	else:
		color_picker_stay_timer.start()


func _on_stay_timeout() -> void:
	if not pet.mouse_in_body:
		color_picker.hide()


func _color_pool_setup():
	#_color_pool = []
	for child in color_picker.get_node("hbox").get_children():
		child.pressed.connect(_on_color_button_pressed.bind(child))


func _on_color_button_pressed(button: Button) -> void:
	var color_name = button.name
	color_chosen.emit(color_name)
	color_picker.hide()
