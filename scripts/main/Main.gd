extends Node

var global_key_hook: Node
var mouse_pass_through_polygon: Node
var drag_controller: Node
var click_scale_animator: Node
var pet: Sprite2D


func _ready():
	pet = $Pet

	global_key_hook = $GlobalKeyHook
	global_key_hook.any_key_pressed.connect(_on_global_key_hook_any_key_pressed)

	mouse_pass_through_polygon = $MousePassThroughPolygon
	mouse_pass_through_polygon.target = pet

	drag_controller = $DragController
	drag_controller.target = pet
	drag_controller.drag_started.connect(_on_drag_controller_drag_started)
	drag_controller.dragged.connect(_on_drag_controller_dragged)
	drag_controller.drag_ended.connect(_on_drag_controller_drag_ended)
	drag_controller.clicked.connect(_on_drag_controller_clicked)

	click_scale_animator = $ClickScaleAnimator
	click_scale_animator.target = pet

	mouse_pass_through_polygon._update_passthrough()

func _on_drag_controller_drag_started():
	print("[MOUSE] Drag started")

func _on_drag_controller_dragged(global_pos):
	pet.global_position = global_pos
	mouse_pass_through_polygon._update_passthrough()

func _on_drag_controller_drag_ended():
	print("[MOUSE] Drag ended")
	mouse_pass_through_polygon._update_passthrough()

func _on_drag_controller_clicked():
	print("[MOUSE] Clicked")
	click_scale_animator._play_click_scale_anim()

func _on_global_key_hook_any_key_pressed() -> void:
	print("[KEY] Pressed")
	click_scale_animator._play_click_scale_anim()
