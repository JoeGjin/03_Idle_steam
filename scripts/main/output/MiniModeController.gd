extends Node


signal interaction_lock_changed(locked: bool)


enum ModeState { NORMAL, ENTERING, MINI, EXITING }


## 睡觉角色相对世界椭圆中心的偏移，使用 AllOutput 设计坐标。
@export var mini_pet_offset := Vector2.ZERO
## 素材画布较大，通过父节点确定正常尺寸；MiniPet 自身只负责 0 到 1 的转换。
@export_range(0.05, 1.0, 0.01, "or_greater") var mini_pet_size_scale := 0.25

## 转换动画使用归一化开合值，避免把正常 radius_v 写死在关键帧里。
@export_range(0.0, 1.0, 0.001) var world_open_ratio := 1.0:
	set(value):
		world_open_ratio = clampf(value, 0.0, 1.0)
		if _world_material != null:
			_world_material.set_shader_parameter("radius_v", _normal_radius_v * world_open_ratio)
			# Shader 内部保留极小半径，完全闭合时隐藏输出，避免留下细线。
			world_output.visible = world_open_ratio > 0.0


@onready var all_output: Control = get_parent()
@onready var mouse_controller: MouseController = %MouseController
@onready var world_output: TextureRect = %WorldOutput
# MiniModeLayer 保持零偏移和单位缩放，与 AllOutput 共用设计坐标原点。
@onready var mini_pet_root: Node2D = $"../MiniModeLayer/MiniPetRoot"
@onready var mini_pet: AnimatedSprite2D = $"../MiniModeLayer/MiniPetRoot/MiniPet"
@onready var wake_button: Button = $"../MiniModeLayer/MiniPetRoot/MiniPet/WakeButton"
@onready var input_blocker: Control = $"../MiniModeLayer/ModeInputBlocker"
@onready var transition_player: AnimationPlayer = $TransitionPlayer


var _state := ModeState.NORMAL
var _initialized := false
var _world_material: ShaderMaterial
var _normal_radius_v := 0.0


# 模式转换只影响最终输出，世界、Memory 和计时继续运行。
# Main 接入进入请求和交互锁定；TransitionPlayer 正反播放同一条 to_mini 动画。
# 入口：enter_mini_mode / exit_mini_mode / is_normal_mode。
# WakeButton 的 GUI 事件交给 MouseController 区分点击与拖动，Main 将单击转为退出请求。
# 进入时先闭合世界，角色隐藏期间由 AllOutput 贴合窗口，绘制空帧后再放大角色。
# 退出先缩小角色，绘制空帧后再恢复窗口并展开世界。
# _get_mini_pet_hidden_time 从缩放轨道读取正反播放的分段位置，沿用编辑器中的动画节奏。
# 表现参数：mini_pet_offset / mini_pet_size_scale，以及 TransitionPlayer 的关键帧。


func _ready() -> void:
	mini_pet_root.hide()
	mini_pet.scale = Vector2.ZERO
	_set_wake_enabled(false)
	input_blocker.hide()
	wake_button.gui_input.connect(_on_wake_button_gui_input)

	if not all_output.call("is_layout_ready"):
		await Signal(all_output, "layout_ready")

	var source_material := world_output.material as ShaderMaterial
	if source_material == null:
		push_error("[MiniMode] WorldOutput 缺少 ShaderMaterial，无法转换模式")
		return

	_world_material = source_material.duplicate() as ShaderMaterial
	world_output.material = _world_material
	_normal_radius_v = float(_world_material.get_shader_parameter("radius_v"))
	world_open_ratio = 1.0
	_update_mini_pet_layout()
	_initialized = true


func is_normal_mode() -> bool:
	return _initialized and _state == ModeState.NORMAL


func enter_mini_mode() -> void:
	if not is_normal_mode():
		return

	_state = ModeState.ENTERING
	_update_mini_pet_layout()
	_set_wake_enabled(false)
	input_blocker.show()
	mini_pet_root.show()
	mini_pet.play(&"sleep")
	interaction_lock_changed.emit(true)
	var hidden_time := _get_mini_pet_hidden_time()
	if hidden_time > 0.0:
		transition_player.play_section(&"to_mini", 0.0, hidden_time)
		transition_player.advance(0.0)
		await transition_player.animation_finished

	# 先提交世界闭合、角色隐藏的画面，避免缩小原生窗口时裁到旧帧。
	mini_pet_root.hide()
	await RenderingServer.frame_post_draw
	# MiniPet 的缩放轨道约定为 0 到 1，临时使用最终尺寸测量 WakeButton，再恢复零缩放。
	mini_pet.scale = Vector2.ONE
	all_output.call("fit_window_to_control", wake_button)
	mini_pet.scale = Vector2.ZERO
	await RenderingServer.frame_post_draw

	mini_pet_root.show()
	transition_player.play_section(&"to_mini", hidden_time)
	transition_player.advance(0.0)
	await transition_player.animation_finished
	_state = ModeState.MINI
	_set_wake_enabled(true)


func exit_mini_mode() -> void:
	if _state != ModeState.MINI:
		return

	_state = ModeState.EXITING
	_set_wake_enabled(false)
	var hidden_time := _get_mini_pet_hidden_time()
	transition_player.play_section_backwards(&"to_mini", hidden_time)
	await transition_player.animation_finished

	# 保持小窗口直到角色缩小结束，再提交不含角色的画面，避免原生窗口恢复时重用旧帧。
	mini_pet_root.hide()
	await RenderingServer.frame_post_draw
	all_output.call("restore_window_from_fit")
	if hidden_time > 0.0:
		transition_player.play_section_backwards(&"to_mini", 0.0, hidden_time)
		await transition_player.animation_finished

	_state = ModeState.NORMAL
	mini_pet.stop()
	input_blocker.hide()
	interaction_lock_changed.emit(false)


func _on_wake_button_gui_input(event: InputEvent) -> void:
	if _state == ModeState.MINI and mouse_controller.handle_gui_input(event, wake_button):
		wake_button.accept_event()


func _get_mini_pet_hidden_time() -> float:
	var animation := transition_player.get_animation(&"to_mini")
	var scale_path := NodePath("%s:scale" % all_output.get_path_to(mini_pet))
	var scale_track := animation.find_track(scale_path, Animation.TYPE_VALUE)
	if scale_track < 0:
		return 0.0

	for key_index in range(animation.track_get_key_count(scale_track) - 1, -1, -1):
		var key_scale: Vector2 = animation.track_get_key_value(scale_track, key_index)
		var key_time := animation.track_get_key_time(scale_track, key_index)
		if key_scale.is_zero_approx() and key_time < animation.length:
			return key_time
	return 0.0


func _set_wake_enabled(enabled: bool) -> void:
	if not enabled:
		mouse_controller.cancel_gui_input(wake_button)
	wake_button.disabled = not enabled
	wake_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	)


func _update_mini_pet_layout() -> void:
	var center_uv := Vector2(
		float(_world_material.get_shader_parameter("center_u")),
		float(_world_material.get_shader_parameter("center_v"))
	)
	mini_pet_root.position = world_output.position + world_output.size * center_uv + mini_pet_offset
	mini_pet_root.scale = Vector2.ONE * mini_pet_size_scale
