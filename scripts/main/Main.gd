# Main 场景的协调脚本，负责将子节点连接到信号处理函数并分配 target

extends Node

@onready var global_key_hook: Node = $Controllers/GlobalKeyHook
@onready var mouse_pass_through_polygon: Node = $Controllers/MousePassThroughPolygon
@onready var mouse_controller: Node = $Controllers/MouseController
@onready var click_scale_animator: Node = $Controllers/ClickScaleAnimator

@onready var world_root: Node2D = %WorldRoot
@onready var pet: AnimatedSprite2D = %Pet
@onready var frame: Node2D = %WorldRoot/Frame

@onready var ui_window: Window = $UIWindow
@onready var ui_root: Control = %UIRoot


const DRAW_SCALE: Vector2 = Vector2(0.5, 0.5) # 预设的窗口缩放级别，供调试使用

func _ready():
	
	# 初始设置缩放
	_draw_scale_setup()

	# 交叉分配目标
	_cross_assign_targets()

	# 连接信号（集中管理）
	_connect_signals()

	# 初始更新鼠标穿透区域
	mouse_pass_through_polygon._update_passthrough()
	

func _cross_assign_targets():
	# 将 pet 赋值给各 controller 的 target
	mouse_pass_through_polygon.target = pet
	mouse_controller.target = pet
	click_scale_animator.target = pet

	# 将 frame 赋值给 mouse_pass_through_polygon 的 frame 属性
	mouse_pass_through_polygon.frame = frame

	# 设置pet base scale
	click_scale_animator.base_scale = pet.scale


func _draw_scale_setup():
	# 可选：根据需要调整 world_root 的缩放级别
	world_root.scale = DRAW_SCALE


func _connect_signals() -> void:
	# 使用普通的函数引用连接到本节点的处理函数（保留 _on_* 命名风格）
	global_key_hook.any_key_pressed.connect(_on_global_key_hook_any_key_pressed)
	mouse_controller.drag_started.connect(_on_mouse_controller_drag_started)
	mouse_controller.dragged.connect(_on_mouse_controller_dragged)
	mouse_controller.drag_ended.connect(_on_mouse_controller_drag_ended)
	mouse_controller.left_clicked.connect(_on_mouse_controller_left_clicked)
	mouse_controller.right_clicked.connect(_on_mouse_controller_right_clicked)


func _on_mouse_controller_drag_started():
	print("[MOUSE] Drag started")


func _on_mouse_controller_dragged(global_pos):
	world_root.global_position = global_pos
	mouse_pass_through_polygon._update_passthrough()


func _on_mouse_controller_drag_ended():
	print("[MOUSE] Drag ended")
	mouse_pass_through_polygon._update_passthrough()


func _on_mouse_controller_left_clicked():
	print("[MOUSE] Left clicked")
	click_scale_animator._play_click_scale_anim()


func _on_mouse_controller_right_clicked():
	print("[MOUSE] Right clicked")
	ui_window.show()


func _on_global_key_hook_any_key_pressed() -> void:
	print("[KEY] Outside window pressed any key")
	click_scale_animator._play_click_scale_anim()
