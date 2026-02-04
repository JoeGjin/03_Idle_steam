# Main 场景的协调脚本，负责将子节点连接到信号处理函数并分配 target

extends Node

@onready var global_key_hook: Node = $Controllers/GlobalKeyHook
@onready var mouse_pass_through_polygon: Node = $Controllers/MousePassThroughPolygon
@onready var drag_controller: Node = $Controllers/DragController
@onready var click_scale_animator: Node = $Controllers/ClickScaleAnimator
@onready var pet: AnimatedSprite2D = %Pet
@onready var world_root: Node2D = $WorldRoot

func _ready():
	
	# 初始将 pet 放在视口中心
	world_root.global_position = get_viewport().get_visible_rect().size * 0.5

	# 一并将 pet 赋值给各 controller 的 target
	mouse_pass_through_polygon.target = pet
	drag_controller.target = pet
	click_scale_animator.target = pet

	# 设置pet base scale
	click_scale_animator.base_scale = pet.scale

	# 连接信号（集中管理）
	_connect_signals()

	# 初始更新鼠标穿透区域
	mouse_pass_through_polygon._update_passthrough()
	
	# 调试信息
	print("[SCENE] Pet position: ", pet.global_position)
	print("[SCENE] Viewport size: ", get_viewport().get_visible_rect().size)


func _connect_signals() -> void:
	# 使用普通的函数引用连接到本节点的处理函数（保留 _on_* 命名风格）
	global_key_hook.any_key_pressed.connect(_on_global_key_hook_any_key_pressed)
	drag_controller.drag_started.connect(_on_drag_controller_drag_started)
	drag_controller.dragged.connect(_on_drag_controller_dragged)
	drag_controller.drag_ended.connect(_on_drag_controller_drag_ended)
	drag_controller.clicked.connect(_on_drag_controller_clicked)


func _on_drag_controller_drag_started():
	print("[MOUSE] Drag started")


func _on_drag_controller_dragged(global_pos):
	world_root.global_position = global_pos
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
