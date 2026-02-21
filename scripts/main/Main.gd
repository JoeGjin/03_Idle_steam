# Main 场景的协调脚本，负责将子节点连接到信号处理函数并分配 target

extends Node

@onready var global_key_hook: Node = %GlobalKeyHook
@onready var mouse_pass_through_polygon: MousePassThroughPolygon = %MousePassThroughPolygon
@onready var mouse_controller: MouseController = %MouseController
@onready var character_status: CharacterStatus = %CharacterStatus
@onready var character_animator: CharacterAnimator = %CharacterAnimator
@onready var scene_animator: SceneAnimator = %SceneAnimator

@onready var world_root: Node2D = %WorldRoot
@onready var pet: AnimatedSprite2D = %Pet
@onready var frame: Node2D = %WorldRoot/Frame

@onready var ui_window: Window = %UIWindow
@onready var ui_root: Control = %UIRoot

@export var debug_mode: bool = false


const DRAW_SCALE: Vector2 = Vector2(0.5, 0.5) # 预设的窗口缩放级别，供调试使用

func _ready():
	
	# 初始设置缩放
	_draw_scale_setup()

	# 交叉分配目标
	_cross_assign_targets()

	# 初始化场景动画器的初始速度（以便后续暂停/继续）
	scene_animator.setup_initial_speed()

	# 连接信号（集中管理）
	_connect_signals()

	# 初始更新鼠标穿透区域
	mouse_pass_through_polygon._update_passthrough()

	_setup_debug()

	# 启动角色状态机，从 WALKING 状态开始
	character_status.start(1) 
	

func _cross_assign_targets():
	# 将 pet 赋值给各 controller 的 target
	mouse_pass_through_polygon.target = pet
	mouse_controller.target = pet
	character_status.target = pet
	character_animator.target = pet

	# 将 frame 赋值给 mouse_pass_through_polygon 的 frame 属性
	mouse_pass_through_polygon.frame = frame

	# 设置pet base scale
	character_animator.base_scale = pet.scale

	# 将场景中的三个 Parallax2D 赋值给 scene_animator 的对应属性
	scene_animator.background = %Background
	scene_animator.midground = %Midground
	scene_animator.foreground = %Foreground

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
	character_status.state_changed.connect(_on_character_status_state_changed)


func _setup_debug():
	# 将 debug_mode 传递给 character_status
	character_status.debug_mode = debug_mode
	if debug_mode:
		print("[DEBUG] Debug mode is ON")
		var state_label = pet.get_child(0)
		var state_cooldown_label = pet.get_child(1)
		state_label.show()
		state_cooldown_label.show()
		character_status.state_label = state_label
		character_status.state_cooldown_label = state_cooldown_label
	else:
		print("[DEBUG] Debug mode is OFF")

func _on_mouse_controller_drag_started():
	print("[MOUSE] Drag started")


func _on_mouse_controller_dragged(global_pos: Vector2):
	world_root.global_position = global_pos
	mouse_pass_through_polygon._update_passthrough()


func _on_mouse_controller_drag_ended():
	print("[MOUSE] Drag ended")
	mouse_pass_through_polygon._update_passthrough()


func _on_mouse_controller_left_clicked():
	print("[MOUSE] Left clicked")
	character_animator._play_click_scale_anim()


func _on_mouse_controller_right_clicked():
	print("[MOUSE] Right clicked")
	ui_window.show()


func _on_global_key_hook_any_key_pressed() -> void:
	print("[KEY] Outside window pressed any key")
	character_animator._play_click_scale_anim()

func _on_character_status_state_changed(new_state: CharacterStates.CharacterState) -> void:
	print("[STATE] Changed to %s" % CharacterStates.CharacterState.find_key(new_state))
	match new_state:
		CharacterStates.CharacterState.RESTING:
			scene_animator.stop_para_animation()
		CharacterStates.CharacterState.WALKING:
			scene_animator.continue_para_animation()
		CharacterStates.CharacterState.RECORDING:
			pass
		CharacterStates.CharacterState.PICKING:
			pass
		CharacterStates.CharacterState.GAZING:
			pass
		CharacterStates.CharacterState.GREETING:
			pass
		CharacterStates.CharacterState.CHANGING:
			pass
		CharacterStates.CharacterState.TRANSITING:
			pass
