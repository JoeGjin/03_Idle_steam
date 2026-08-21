# Main 场景的协调脚本，负责将子节点连接到信号处理函数并分配 target

extends Node

@onready var global_key_hook: Node = %GlobalKeyHook
# @onready var window_controller: WindowController = %WindowController
@onready var mouse_controller: MouseController = %MouseController
@onready var character_status: CharacterStatus = %CharacterStatus
@onready var character_animator: CharacterAnimator = %CharacterAnimator
@onready var memory_controller: MemoryController = %MemoryController
@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var audio_controller: AudioController = %AudioController

@onready var world_root: Node2D = %WorldRoot
@onready var pet: AnimatedSprite2D = %Pet
# @onready var frame: Node2D = %Frame

@onready var ui_window: Window = %UIWindow
@onready var ui_root: Control = %UIRoot

@onready var debug_world: Node2D = %DebugWorld

@onready var world_output: TextureRect = %WorldOutput
@onready var all_output: Control = $AllOutput


## 主原生窗口相对 AllOutput.design_size 的初始显示倍率。
## 只改变桌宠窗口及其 UI 的显示大小，不改变 WorldView 的 1920×1080 渲染分辨率。
@export_range(0.1, 3.0, 0.05, "or_greater") var draw_scale: float = 1.0
@export var starting_world_id: int = 0 # 启动时默认组装的世界ID


var memory_slots: Array[String] = ["", "", "", "", "", ""]




func _on_exit_pressed() -> void:
	get_tree().quit()

func _ready():

	# 将场景放入子视口以便后续处理
	_scene_into_subviewport()
	
	# 初始设置缩放
	_draw_scale_setup()


	# 连接信号（集中管理）
	_connect_signals()


	# 初始化世界组装器
	world_assembler.assemble_world({1 as Tags.Tag: 1.0}) 

	# 启动角色状态机，从 WALKING 状态开始
	character_status.start(1) 


	


func _scene_into_subviewport():
	var subviewport = %WorldView
	if world_root.get_parent() != subviewport:
		world_root.reparent(subviewport)
	if debug_world.get_parent() != subviewport:
		debug_world.reparent(subviewport)






func _draw_scale_setup():
	if all_output.has_method("set_initial_window_scale"):
		all_output.call("set_initial_window_scale", draw_scale)


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
	


func _on_mouse_controller_drag_started():
	# print("[MOUSE] Drag started")
	pass


func _on_mouse_controller_drag_ended():
	# print("[MOUSE] Drag ended")
	pass


func _on_mouse_controller_left_clicked():
	#print("[MOUSE] Left clicked")

	pass

func _on_mouse_controller_right_clicked():
	# print("[MOUSE] Right clicked")
	ui_window.open_uiwindow()


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


func _on_world_assembler_world_changing(new_tag_id: int, transition_duration: float) -> void:
	print("[WORLD ASSEMBLER] World changing to Tag: %s, transition duration: %.2f seconds" % [Tags.Tag.find_key(new_tag_id), transition_duration])
	if world_assembler.is_transitioning:
		print("[WORLD ASSEMBLER] Already transitioning, ignoring new transition request")
		return
	else:
		audio_controller.ambient_transition(new_tag_id, transition_duration)

	

func _on_world_assembler_world_changed(new_tag_id: int) -> void:
	print("[WORLD ASSEMBLER] World assembled/transitioned to Tag: %s" % Tags.Tag.find_key(new_tag_id))
	character_status.get_node("ChangeScene").start()




# func _on_popups_memory_chose(chosen: String, unchosen: String) -> void: # string格式为 0_frontxxx_2_1xx
	
# 	print("[MEMORY] Memory chosen: %s, unchosen: %s" % [chosen, unchosen])
# 	_update_memory_slots(chosen)
# 	world_assembler.banned_texture = unchosen
	
# 	pet.get_node("heart").show()
# 	await get_tree().create_timer(2.0).timeout
# 	pet.get_node("heart").hide()

# 	world_assembler.immediate_spawn(chosen)
		
# 	if world_assembler.is_transitioning:
# 		print("[MEMORY] World is currently transitioning, skipping world switch")
# 		return
# 	else :
# 		var tag_calc_result := memory_controller.tag_calculation(memory_slots)
# 		var target_world_id = tag_calc_result["target_world_id"]
# 		var sub_world_id = tag_calc_result["sub_world_id"]
# 		var sub_world_weight = tag_calc_result["sub_world_weight"]
# 		print("[MEMORY] Initiating world switch to ID: %d" % target_world_id, " with sub-world ID: %d and weight: %.2f" % [sub_world_id, sub_world_weight])
# 		world_assembler.transition_to_world(target_world_id, sub_world_id, sub_world_weight) # 切换世界
		


func _update_memory_slots(chosen: String) -> void:
	# 更新 memory_slots 数组，保持最新的6条记录
	memory_slots.append(chosen)
	if memory_slots.size() > 6:
		memory_slots.pop_front()
	print("[MEMORY SLOTS] Updated memory slots: " + str(memory_slots))


func _on_change_scene_timeout() -> void:
	print("[MAIN] Change scene timeout reached, switching world")
	var target_tag := ((world_assembler.current_tag_id + 1) % 3) as Tags.Tag
	var target_tags: Dictionary[Tags.Tag, float] = {target_tag: 1.0}
	world_assembler.transition_to_world(target_tags) # 切换世界
