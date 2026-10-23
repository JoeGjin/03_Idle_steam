# Main 场景的协调脚本，负责连接各模块并处理跨模块流程。

extends Node


const DEBUG_DESIGN_BOUNDS_NAME := "DebugDesignBounds"


# 启动与显示配置
## 主原生窗口相对 AllOutput.design_size 的初始显示倍率。
## 只改变桌宠窗口及其 UI 的显示大小，不改变 WorldView 的 1920×1080 渲染分辨率。
@export_range(0.1, 3.0, 0.05, "or_greater") var draw_scale: float = 1.0
@export var starting_world_id: int = 0 # 启动时默认组装的世界 ID

@export_group("Debug")
@export var debug_show_design_bounds := false


# 控制器与自动世界切换计时器
@onready var global_key_hook: Node = %GlobalKeyHook
@onready var mouse_controller: MouseController = %MouseController
@onready var character_status: CharacterStatus = %CharacterStatus
@onready var character_animator: CharacterAnimator = %CharacterAnimator
@onready var memory_controller: MemoryController = %MemoryController
@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var audio_controller: AudioController = %AudioController
@onready var change_scene_timer: Timer = $Controllers/CharacterStatus/ChangeScene

# 世界表现与深度渲染
@onready var world_root: Node2D = %WorldRoot
@onready var pet: AnimatedSprite2D = %Pet
@onready var depth_rendering: Node = %DepthRendering

# UI、窗口输出与收集反馈
@onready var ui_window: Window = %UIWindow
@onready var ui_root: Control = %UIRoot
@onready var world_output: TextureRect = %WorldOutput
@onready var all_output: Control = $AllOutput
@onready var float_button_manager: Node = %FloatButtonManager
@onready var mini_mode_controller: Node = %MiniModeController
@onready var collection_button: Button = %Collection
@onready var collected_item_button: Button = %CollectedItem
@onready var transient_fx_window: TransientFxWindow = %TransientFxWindow
@onready var memory_choice_window: MemoryChoiceWindow = %MemoryChoiceWindow


# Memory 记录：槽位按从新到旧排列，最多保留 9 个标签与 3 个最近选择
var memory_slots: Array[Tags.Tag] = []
var recent_chosen_memories: Array[MemoryDef] = []

# 收集与二选一流程的重入保护
var _collection_flow_active := false


# 本脚本协调初始化、收集选择、Memory 槽位和世界变化，具体处理交给各模块。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与初始化
#    将世界放入 WorldView，初始化深度渲染、窗口倍率、信号连接和收集 UI。
#    等待输出布局完成后设置生成线、初始化 POI 强调，再组装世界并启动角色状态。
#    入口：_ready
# 2. UI 与收集反馈
#    打开收集窗口、同步待收集数量，协调烟花反馈与逐轮 Memory 二选一。
#    二选一窗口通过 FloatButtonManager 获取叠加弹窗大小参数后的显示倍率。
#    接入 mini 模式请求与按钮锁定，避免模式转换和收集流程同时进行。
#    进入 mini 时暂停全局键盘监听，退出动画完成后按原有总开关恢复。
#    选择期间暂停自动世界切换计时，整批完成后统一更新 Memory 槽位。
#    入口：_on_collection_requested / _on_collected_item_requested
#          _on_memory_controller_pending_collection_count_changed / _on_minimode_requested
#          _on_mini_mode_interaction_lock_changed
# 3. Memory 槽位与世界权重
#    更新最近标签与 Memory，通知世界生成和悬浮按钮，并按槽位占比计算标签权重。
#    权重相同时优先最近出现的标签；重启自动切换计时并请求 WorldAssembler 更新世界。
#    核心：_update_memory_slots / _calculate_memory_slot_weights
# 4. 输入回调
#    后台按键触发角色点击缩放动画与敲击音效；单击请求退出 mini，控制器仅在 MINI 状态接受。
#    拖动与宠物悬停回调当前为预留入口。
#    入口：_on_global_key_hook_any_key_pressed / _on_mouse_controller_left_clicked
# 5. 角色状态与世界切换
#    接收角色状态变化（当前为预留逻辑），协调世界切换期间的 POI 强调和环境音。
#    世界切换完成后重启计时器；计时到期时按标签顺序请求下一个世界。
#    入口：_on_character_status_state_changed / _on_world_assembler_world_changing
#          _on_world_assembler_world_changed / _on_change_scene_timeout
# 6. Debug 窗口描边
#    按开关为主窗口、已有子窗口及后续新增窗口添加不拦截鼠标的调试边框。
#    入口：_setup_debug_design_bounds


#region 生命周期与初始化

func _ready() -> void:
    _setup_debug_design_bounds()
    _scene_into_subviewport()
    _draw_scale_setup()
    _connect_signals()
    _sync_pending_collection_ui()

    # 输出布局确定后再设置公共生成线，避免首次生成使用尚未应用的横向偏移。
    if not all_output.call("is_layout_ready"):
        await Signal(all_output, "layout_ready")
    world_assembler.set_manual_spawn_x(float(all_output.call("get_world_spawn_x")))
    var world_visible_rect: Rect2 = all_output.call("get_world_visual_rect")
    world_visible_rect.position -= world_output.position
    world_root.call("initialize_poi_emphasis", world_visible_rect)
    world_assembler.assemble_world({starting_world_id as Tags.Tag: 1.0}, world_visible_rect)
    character_status.start(1)


func _scene_into_subviewport() -> void:
    var subviewport: SubViewport = %WorldView
    if world_root.get_parent() != subviewport:
        world_root.reparent(subviewport)
    for band in depth_rendering.get_children():
        band.call("initialize", subviewport, world_root)


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
    float_button_manager.connect("minimode_requested", _on_minimode_requested)
    mini_mode_controller.connect("interaction_lock_changed", _on_mini_mode_interaction_lock_changed)
    memory_controller.pending_collection_count_changed.connect(
        _on_memory_controller_pending_collection_count_changed
    )

#endregion


#region UI 与收集反馈

func _on_exit_pressed() -> void:
    get_tree().quit()


func _on_collection_requested() -> void:
    if not mini_mode_controller.call("is_normal_mode"):
        return
    ui_window.call("open_uiwindow")


func _on_minimode_requested() -> void:
    if _collection_flow_active or ui_window.visible:
        return
    mini_mode_controller.call("enter_mini_mode")


func _on_mini_mode_interaction_lock_changed(locked: bool) -> void:
    global_key_hook.call("set_suspended", locked)
    float_button_manager.call("set_mini_mode_active", locked)


func _on_collected_item_requested() -> void:
    if (
        _collection_flow_active
        or not mini_mode_controller.call("is_normal_mode")
        or memory_controller.pending_collection_count <= 0
    ):
        return

    _collection_flow_active = true
    var origin_screen := _get_control_screen_center(collected_item_button)
    float_button_manager.call("focus_collection", 1.5)
    var target_screen: Vector2 = float_button_manager.call(
        "get_collection_open_screen_center"
    )
    var max_count : int = memory_controller.get_max_pending_collection_count()
    var collected_count : int = memory_controller.collect_all_pending_events()

    await transient_fx_window.play_collection_firework(
        origin_screen,
        target_screen,
        collected_count,
        max_count
    )

    change_scene_timer.stop()
    float_button_manager.call("set_memory_choice_active", true)
    var popup_scale: float = float_button_manager.call("get_memory_popup_scale")
    memory_choice_window.begin_choices(get_tree().root, popup_scale)
    var choice_weighted_tags := world_assembler.get_current_weighted_tags()
    var chosen_tags: Array[Tags.Tag] = []
    var chosen_memories: Array[MemoryDef] = []
    for _round_index in collected_count:
        var choices := memory_controller.get_random_collectable_memories(
            choice_weighted_tags,
            2
        )
        if choices.size() < 2:
            push_warning(
                "[MEMORY CHOICE] 当前 weighted_tags 无法提供两个可收集 MemoryDef，选择流程提前结束"
            )
            break

        var chosen_memory := await memory_choice_window.play_choice(
            choices[0],
            choices[1],
            _get_pet_screen_position()
        )
        chosen_tags.append(chosen_memory.tags[0])
        chosen_memories.append(chosen_memory)

    _update_memory_slots(chosen_tags, chosen_memories)
    memory_choice_window.finish_choices()
    float_button_manager.call("set_memory_choice_active", false)
    _collection_flow_active = false


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


func _get_pet_screen_position() -> Vector2:
    return world_output.get_screen_transform() * pet.get_global_transform_with_canvas().origin

#endregion


#region Memory 槽位与世界权重

func _update_memory_slots(
    chosen_tags: Array[Tags.Tag],
    chosen_memories: Array[MemoryDef]
) -> void:
    # 一整批选择完成后统一更新槽位、最近 Memory 与世界权重，再请求 WorldAssembler 切换世界。
    for chosen_tag in chosen_tags:
        memory_slots.push_front(chosen_tag)
    while memory_slots.size() > 9:
        memory_slots.pop_back()

    for chosen_memory: MemoryDef in chosen_memories:
        recent_chosen_memories.push_front(chosen_memory)
    while recent_chosen_memories.size() > 3:
        recent_chosen_memories.pop_back()
    world_assembler.set_recently_chosen_memories(recent_chosen_memories)

    if not chosen_memories.is_empty():
        var recent_memory_names: Array[String] = []
        for memory: MemoryDef in recent_chosen_memories:
            var memory_name := memory.resource_name
            if memory_name.is_empty() and not memory.resource_path.is_empty():
                memory_name = memory.resource_path.get_file().get_basename()
            recent_memory_names.append(memory_name)
        print("[RECENT MEMORIES] Updated recent memories: %s" % [recent_memory_names])

    var slot_names: Array[String] = []
    for tag in memory_slots:
        slot_names.append(String(Tags.Tag.find_key(tag)))

    var weighted_tags := _calculate_memory_slot_weights()
    var weighted_tag_names: Dictionary[String, float] = {}
    for tag: Tags.Tag in weighted_tags:
        weighted_tag_names[String(Tags.Tag.find_key(tag))] = weighted_tags[tag]

    print(
        "[MEMORY SLOTS] Updated memory slots: %s, weighted tags: %s"
        % [slot_names, weighted_tag_names]
    )

    # 二选一批次完成并准备触发世界过渡时，从头计算下次自动切换时间。
    change_scene_timer.start()
    if not weighted_tags.is_empty():
        world_assembler.transition_to_world(weighted_tags)


func _calculate_memory_slot_weights() -> Dictionary[Tags.Tag, float]:
    var tag_counts: Dictionary[Tags.Tag, int] = {}
    var first_slot_indices: Dictionary[Tags.Tag, int] = {}
    var sorted_tags: Array[Tags.Tag] = []

    # memory_slots 从新到旧排列；相同权重时，最近出现的 Tag 排在前面。
    for slot_index: int in range(memory_slots.size()):
        var tag := memory_slots[slot_index]
        if not tag_counts.has(tag):
            tag_counts[tag] = 0
            first_slot_indices[tag] = slot_index
            sorted_tags.append(tag)
        tag_counts[tag] += 1

    for index: int in range(sorted_tags.size()):
        var best_index := index
        for candidate_index: int in range(index + 1, sorted_tags.size()):
            var candidate_tag := sorted_tags[candidate_index]
            var best_tag := sorted_tags[best_index]
            var candidate_is_higher := tag_counts[candidate_tag] > tag_counts[best_tag]
            var candidate_is_more_recent := (
                tag_counts[candidate_tag] == tag_counts[best_tag]
                and first_slot_indices[candidate_tag] < first_slot_indices[best_tag]
            )
            if candidate_is_higher or candidate_is_more_recent:
                best_index = candidate_index

        if best_index != index:
            var current_tag := sorted_tags[index]
            sorted_tags[index] = sorted_tags[best_index]
            sorted_tags[best_index] = current_tag

    var weighted_tags: Dictionary[Tags.Tag, float] = {}
    var slot_count := memory_slots.size()
    if slot_count <= 0:
        return weighted_tags

    for tag: Tags.Tag in sorted_tags:
        weighted_tags[tag] = float(tag_counts[tag]) / float(slot_count)

    return weighted_tags

#endregion


#region 输入回调

func _on_mouse_controller_drag_started() -> void:
    pass


func _on_mouse_controller_drag_ended() -> void:
    pass


func _on_mouse_controller_left_clicked() -> void:
    mini_mode_controller.call("exit_mini_mode")


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
    world_root.call("set_poi_emphasis_transitioning", true)
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
    world_root.call("set_poi_emphasis_transitioning", false)
    print(
        "[WORLD ASSEMBLER] World assembled/transitioned to Tag: %s"
        % Tags.Tag.find_key(new_tag_id)
    )
    change_scene_timer.start()


func _on_change_scene_timeout() -> void:
    print("[MAIN] Change scene timeout reached, switching world")
    var target_tag := ((world_assembler.current_tag_id + 1) % Tags.Tag.size()) as Tags.Tag
    var target_tags: Dictionary[Tags.Tag, float] = {target_tag: 1.0}
    world_assembler.transition_to_world(target_tags)

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
