# Main 场景的协调脚本，负责将子节点连接到信号处理函数并分配 target

extends Node

var global_key_hook: Node
var mouse_pass_through_polygon: Node
var drag_controller: Node
var click_scale_animator: Node
var pet: Sprite2D


func _ready():
    # 初始化并绑定子节点引用
    pet = $Pet
    global_key_hook = $GlobalKeyHook

    mouse_pass_through_polygon = $MousePassThroughPolygon
    drag_controller = $DragController
    click_scale_animator = $ClickScaleAnimator

    # 一并将 pet 赋值给各 controller 的 target
    mouse_pass_through_polygon.target = pet
    drag_controller.target = pet
    click_scale_animator.target = pet

    # 连接信号（集中管理）
    _connect_signals()

    # 初始更新鼠标穿透区域
    mouse_pass_through_polygon._update_passthrough()


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
