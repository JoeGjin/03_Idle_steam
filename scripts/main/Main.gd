# Main 场景的协调脚本，负责将子节点连接到信号处理函数并分配 target

extends Node

@onready var global_key_hook: Node = %GlobalKeyHook
# @onready var window_controller: WindowController = %WindowController
@onready var mouse_controller: MouseController = %MouseController
@onready var character_status: CharacterStatus = %CharacterStatus
@onready var character_animator: CharacterAnimator = %CharacterAnimator
@onready var item_controller: ItemController = %ItemController
@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var audio_controller: AudioController = %AudioController

@onready var world_root: Node2D = %WorldRoot
@onready var pet: AnimatedSprite2D = %Pet
# @onready var frame: Node2D = %Frame

@onready var ui_window: Window = %UIWindow
@onready var ui_root: Control = %UIRoot
@onready var letter: Control = %Letter

@onready var debug_world: Node2D = %DebugWorld

@onready var world_output: TextureRect = %WorldOutput


@export var draw_scale: float = 1.0 # 预设的窗口缩放级别，供调试使用
@export var starting_world_id: int = 0 # 启动时默认组装的世界ID


func _ready():

    # 将场景放入子视口以便后续处理
    _scene_into_subviewport()
    
    # 初始设置缩放
    _draw_scale_setup()

    # 交叉分配目标
    _cross_assign_targets()

    # 连接信号（集中管理）
    _connect_signals()

    # 初始更新window裁剪区域
    # window_controller.update_crop_to_frame()

    # 初始化世界组装器
    world_assembler.initiate()
    world_assembler.assemble_world(starting_world_id) # 默认组装指定世界，后续可以根据需要切换

    # 启动角色状态机，从 WALKING 状态开始
    character_status.start(1) 


    


func _scene_into_subviewport():
    var subviewport = %WorldView
    if world_root.get_parent() != subviewport:
        world_root.reparent(subviewport)
    if debug_world.get_parent() != subviewport:
        debug_world.reparent(subviewport)



func _cross_assign_targets():
    # 将 pet 赋值给各 controller 的 target
    # window_controller.pet = pet
    mouse_controller.pet = pet
    # character_status.pet = pet
    character_animator.pet = pet

    # 将 frame 和 world_root 赋值给 window_controller
    # window_controller.world_root = world_root
    # window_controller.frame = frame

    # 设置pet base scale
    character_animator.base_scale = pet.scale

    # 将 world_root 赋值给 world_assembler 和 scene_animator
    world_assembler.world_root = world_root



func _draw_scale_setup():
    # 可选：根据需要调整 world_root 的缩放级别
    # world_root.scale = DRAW_SCALE
    # debug_world.scale = DRAW_SCALE
    # world_output.scale = draw_scale
    get_window().size *= draw_scale


func _connect_signals() -> void:
    # 使用普通的函数引用连接到本节点的处理函数（保留 _on_* 命名风格）
    global_key_hook.any_key_pressed.connect(_on_global_key_hook_any_key_pressed)
    mouse_controller.drag_started.connect(_on_mouse_controller_drag_started)
    mouse_controller.drag_ended.connect(_on_mouse_controller_drag_ended)
    mouse_controller.left_clicked.connect(_on_mouse_controller_left_clicked)
    mouse_controller.right_clicked.connect(_on_mouse_controller_right_clicked)
    character_status.state_changed.connect(_on_character_status_state_changed)
    pet.mouse_entered_body.connect(_on_pet_mouse_entered_body)
    pet.mouse_exited_body.connect(_on_pet_mouse_exited_body)
    
    # 连接世界组装器的世界切换信号到处理函数
    world_assembler.world_changing.connect(_on_world_assembler_world_changing)
    world_assembler.world_changed.connect(_on_world_assembler_world_changed)
    

    # 连接 letter 的 sent 信号到处理函数
    letter.sent.connect(_on_letter_sent)


func _on_mouse_controller_drag_started():
    # print("[MOUSE] Drag started")
    pass


func _on_mouse_controller_drag_ended():
    # print("[MOUSE] Drag ended")
    pass


func _on_mouse_controller_left_clicked():
    #print("[MOUSE] Left clicked")
    character_animator._play_click_scale_anim()


func _on_mouse_controller_right_clicked():
    # print("[MOUSE] Right clicked")
    # character_animator._play_click_scale_anim()
    ui_window.open_uiwindow()
    if pet.get_node("letter").visible:
        ui_root.play_receive_postcard()
        pet.get_node("letter").hide()


func _on_pet_mouse_entered_body():
    # print("[PET] Mouse entered body")
    pass


func _on_pet_mouse_exited_body():
    # print("[PET] Mouse exited body")
    pass


func _on_global_key_hook_any_key_pressed() -> void:
    # print("[KEY] Outside window pressed any key")
    character_animator._play_click_scale_anim()
    audio_controller.tap_play() # 播放 tap 音效


func _on_character_status_state_changed(new_state: CharacterStates.CharacterState, _duration: float) -> void:
    # print("[STATE] Changed to %s" % CharacterStates.CharacterState.find_key(new_state))
    match new_state:
        CharacterStates.CharacterState.RESTING:
            pass
            # scene_animator.stop_para_animation()
        CharacterStates.CharacterState.WALKING:
            pass
            # scene_animator.continue_para_animation()
        CharacterStates.CharacterState.RECORDING:
            pass
            # scene_animator.stop_para_animation()
        CharacterStates.CharacterState.PICKING:
            pass
            # scene_animator.stop_para_animation()
        CharacterStates.CharacterState.GAZING:
            pass
            # scene_animator.stop_para_animation()
        CharacterStates.CharacterState.GREETING:
            pass
            # scene_animator.stop_para_animation()
        CharacterStates.CharacterState.SENDING:
            pass
            # scene_animator.continue_para_animation()
        CharacterStates.CharacterState.TRANSITING:
            pass
            ## 已知问题，目前在播放动画后没有禁用交互，可能会导致在过渡动画播放过程中触发其他状态改变，进而重复调用过渡动画
            # scene_animator.stop_para_animation()
            # scene_animator.play_world_transition()
            # await get_tree().create_timer(duration).timeout
            # world_assembler._assemble_world((world_assembler.current_world_id+1)%2) # 切换世界


func _on_world_assembler_world_changing(new_world_id: int, transition_duration: float) -> void:
    print("[WORLD ASSEMBLER] World changing to ID: %d, transition duration: %.2f seconds" % [new_world_id, transition_duration])
    if world_assembler.is_transitioning:
        print("[WORLD ASSEMBLER] Already transitioning, ignoring new transition request")
        return
    else:
        audio_controller.ambient_transition(new_world_id, transition_duration)
    # scene_animator.play_world_transition(transition_duration)
    

func _on_world_assembler_world_changed(new_world_id: int) -> void:
    print("[WORLD ASSEMBLER] World assembled/transitioned to ID: %d" % new_world_id)
    # scene_animator.setup_initial_speed()



func _on_letter_sent(target_world_id: int) -> void: # 临时动画
    print("[LETTER] SENT")
    character_status.start(CharacterStates.CharacterState.GAZING)
     # 临时动画 演示：钻石从天而降，心形出现
    pet.get_node("diamond").drop_letter()
    await get_tree().create_timer(5.0).timeout
    pet.get_node("heart").show()
    await get_tree().create_timer(2.0).timeout
    pet.get_node("heart").hide()
    if world_assembler.is_transitioning:
        print("[LETTER] World is currently transitioning, skipping world switch")
        return
    else :
        print("[LETTER] Initiating world switch to ID: %d" % target_world_id)
        world_assembler.transition_to_world(target_world_id)


func _on_send_postcard_timeout() -> void:
    print("[POSTCARD] SENT")
    character_status.start(CharacterStates.CharacterState.SENDING)
    pet.get_node("letter").show()



func _on_exit_pressed() -> void:
    get_tree().quit()



