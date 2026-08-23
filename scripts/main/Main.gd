# Main 场景的协调脚本，负责连接各模块并处理跨模块流程。

extends Node


const DEBUG_DESIGN_BOUNDS_NAME := "DebugDesignBounds"


## 主原生窗口相对 AllOutput.design_size 的初始显示倍率。
## 只改变桌宠窗口及其 UI 的显示大小，不改变 WorldView 的 1920×1080 渲染分辨率。
@export_range(0.1, 3.0, 0.05, "or_greater") var draw_scale: float = 1.0
@export var starting_world_id: int = 0 # 启动时默认组装的世界 ID

@export_group("Debug")
@export var debug_show_design_bounds := false


# Controllers
@onready var global_key_hook: Node = %GlobalKeyHook
@onready var mouse_controller: MouseController = %MouseController
@onready var character_status: CharacterStatus = %CharacterStatus
@onready var character_animator: CharacterAnimator = %CharacterAnimator
@onready var memory_controller: MemoryController = %MemoryController
@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var audio_controller: AudioController = %AudioController

# World
@onready var world_root: Node2D = %WorldRoot
@onready var pet: AnimatedSprite2D = %Pet
@onready var debug_world: Node2D = %DebugWorld

# UI and output
@onready var ui_window: Window = %UIWindow
@onready var ui_root: Control = %UIRoot
@onready var world_output: TextureRect = %WorldOutput
@onready var all_output: Control = $AllOutput
@onready var float_button_manager: Node = %FloatButtonManager
@onready var collection_button: Button = %Collection
@onready var collected_item_button: Button = %CollectedItem
@onready var transient_fx_window: Window = %TransientFxWindow


var memory_slots: Array[String] = ["", "", "", "", "", ""]


#region 生命周期与初始化

func _ready() -> void:
    _setup_debug_design_bounds()
    _scene_into_subviewport()
    _draw_scale_setup()
    _connect_signals()
    _sync_pending_collection_ui()

    world_assembler.assemble_world({1 as Tags.Tag: 1.0})
    character_status.start(1)


func _scene_into_subviewport() -> void:
    var subviewport: SubViewport = %WorldView
    if world_root.get_parent() != subviewport:
        world_root.reparent(subviewport)
    if debug_world.get_parent() != subviewport:
        debug_world.reparent(subviewport)


func _draw_scale_setup() -> void:
    if all_output.has_method("set_initial_window_scale"):
        all_output.call("set_initial_window_scale", draw_scale)


func _connect_signals() -> void:
    global_key_hook.any_key_pressed.connect(_on_global_key_hook_any_key_pressed)
    mouse_controller.drag_started.connect(_on_mouse_controller_drag_started)
    mouse_controller.drag_ended.connect(_on_mouse_controller_drag_ended)
    mouse_controller.left_clicked.connect(_on_mouse_controller_left_clicked)
    mouse_controller.right_clicked.connect(_on_mouse_controller_right_clicked)
    character_status.state_changed.connect(_on_character_status_state_changed)
    pet.mouse_entered_body.connect(_on_pet_mouse_entered_body)
    pet.mouse_exited_body.connect(_on_pet_mouse_exited_body)
    world_assembler.world_changing.connect(_on_world_assembler_world_changing)
    world_assembler.world_changed.connect(_on_world_assembler_world_changed)
    float_button_manager.connect("collection_requested", _on_collection_requested)
    float_button_manager.connect("collected_item_requested", _on_collected_item_requested)
    memory_controller.pending_collection_count_changed.connect(
        _on_memory_controller_pending_collection_count_changed
    )

#endregion


#region Debug 窗口描边

func _setup_debug_design_bounds() -> void:
    if not debug_show_design_bounds:
        return

    var scene_tree := get_tree()
    if not scene_tree.node_added.is_connected(_on_scene_tree_node_added):
        scene_tree.node_added.connect(_on_scene_tree_node_added)

    call_deferred("_add_debug_design_bounds", scene_tree.root)
    for node in scene_tree.root.find_children("*", "Window", true, false):
        call_deferred("_add_debug_design_bounds", node)


func _on_scene_tree_node_added(node: Node) -> void:
    if debug_show_design_bounds and node is Window:
        call_deferred("_add_debug_design_bounds", node)


func _add_debug_design_bounds(window: Window) -> void:
    if not is_instance_valid(window) or window.has_node(DEBUG_DESIGN_BOUNDS_NAME):
        return

    var border := Panel.new()
    border.name = DEBUG_DESIGN_BOUNDS_NAME
    border.mouse_filter = Control.MOUSE_FILTER_IGNORE
    border.z_index = 4096

    var border_style := StyleBoxFlat.new()
    border_style.bg_color = Color.TRANSPARENT
    border_style.border_color = Color(1.0, 0.2, 0.75, 0.95)
    border_style.set_border_width_all(4)
    border.add_theme_stylebox_override("panel", border_style)

    window.add_child(border)
    border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

#endregion


#region UI 与收集反馈

func _on_exit_pressed() -> void:
    get_tree().quit()


func _on_collection_requested() -> void:
    ui_window.call("open_uiwindow")


func _on_collected_item_requested() -> void:
    if memory_controller.pending_collection_count <= 0:
        return

    var origin_screen := _get_control_screen_center(collected_item_button)
    float_button_manager.call("focus_collection", 1.5)
    var target_screen := _get_control_screen_center(collection_button)
    var max_count := memory_controller.get_max_pending_collection_count()
    var collected_count := memory_controller.collect_all_pending_events()

    transient_fx_window.call(
        "play_collection_firework",
        origin_screen,
        target_screen,
        collected_count,
        max_count
    )


func _sync_pending_collection_ui() -> void:
    _on_memory_controller_pending_collection_count_changed(
        memory_controller.pending_collection_count,
        memory_controller.get_max_pending_collection_count()
    )


func _on_memory_controller_pending_collection_count_changed(
    count: int,
    max_count: int
) -> void:
    if count <= 0:
        float_button_manager.call("hide_collected_item")
        return

    float_button_manager.call("show_collected_item", count, max_count)


func _get_control_screen_center(control: Control) -> Vector2:
    return control.get_screen_transform() * (control.size * 0.5)

#endregion


#region 输入回调

func _on_mouse_controller_drag_started() -> void:
    pass


func _on_mouse_controller_drag_ended() -> void:
    pass


func _on_mouse_controller_left_clicked() -> void:
    pass


func _on_mouse_controller_right_clicked() -> void:
    pass


func _on_pet_mouse_entered_body() -> void:
    pass


func _on_pet_mouse_exited_body() -> void:
    pass


func _on_global_key_hook_any_key_pressed() -> void:
    character_animator._play_click_scale_anim()
    audio_controller.tap_play()

#endregion


#region 角色状态与世界切换

func _on_character_status_state_changed(
    new_state: CharacterStates.CharacterState,
    _duration: float
) -> void:
    match new_state:
        CharacterStates.CharacterState.RESTING, \
        CharacterStates.CharacterState.WALKING, \
        CharacterStates.CharacterState.RECORDING, \
        CharacterStates.CharacterState.PICKING, \
        CharacterStates.CharacterState.GAZING, \
        CharacterStates.CharacterState.GREETING, \
        CharacterStates.CharacterState.SENDING:
            pass
        CharacterStates.CharacterState.TRANSITING:
            # TODO: 过渡期间禁用交互，避免重复触发状态切换。
            pass


func _on_world_assembler_world_changing(
    new_tag_id: int,
    transition_duration: float
) -> void:
    var message := (
        "[WORLD ASSEMBLER] World changing to Tag: %s, "
        + "transition duration: %.2f seconds"
    )
    print(message % [Tags.Tag.find_key(new_tag_id), transition_duration])
    if world_assembler.is_transitioning:
        print("[WORLD ASSEMBLER] Already transitioning, ignoring new transition request")
        return

    audio_controller.ambient_transition(new_tag_id, transition_duration)


func _on_world_assembler_world_changed(new_tag_id: int) -> void:
    print(
        "[WORLD ASSEMBLER] World assembled/transitioned to Tag: %s"
        % Tags.Tag.find_key(new_tag_id)
    )
    character_status.get_node("ChangeScene").start()


func _on_change_scene_timeout() -> void:
    print("[MAIN] Change scene timeout reached, switching world")
    var target_tag := ((world_assembler.current_tag_id + 1) % 3) as Tags.Tag
    var target_tags: Dictionary[Tags.Tag, float] = {target_tag: 1.0}
    world_assembler.transition_to_world(target_tags)

#endregion


#region Memory

func _update_memory_slots(chosen: String) -> void:
    memory_slots.append(chosen)
    if memory_slots.size() > 6:
        memory_slots.pop_front()
    print("[MEMORY SLOTS] Updated memory slots: " + str(memory_slots))

#endregion
