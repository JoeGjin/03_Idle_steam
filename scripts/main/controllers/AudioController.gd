extends Node
class_name AudioController


# 环境音淡变的目标音量与静音端点（dB）。
@export var target_volume_db: float = -10.0
@export var silent_volume_db: float = -80.0

# 从世界定义读取环境音，两个环境音播放器交替承担新旧音轨。
@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var ambient_1: AudioStreamPlayer = $Ambient_1
@onready var ambient_2: AudioStreamPlayer = $Ambient_2

# 后台按键触发的独立音效播放器。
@onready var tap: AudioStreamPlayer = $Tap


# 当前环境音播放器与共用的音量 Tween。
var current_ambient_player: AudioStreamPlayer = null
var _tween: Tween = null


# 本脚本响应 Main 的音频调用，播放按键音效并协调世界环境音的淡入淡出。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与初始化
#    将两个环境音播放器设为静音并停止，等待 Main 发起首次环境音请求。
#    入口：_ready
# 2. 按键音效
#    每次播放前随机音高，并从音频的 0.08 秒处开始播放。
#    入口：tap_play
# 3. 世界环境音切换
#    从 TagSceneDef.ambient_audio 读取目标音频；首次只淡入，无音频时只淡出。
#    同一音频正在播放时不重复切换；换曲时用两个播放器交叉淡变。
#    常规切换中旧音轨立即淡出，新音轨延迟过渡时长的 1/3 后淡入，淡变各持续 2/3。
#    首次淡入使用 fade_duration / 3；新请求先终止已有 Tween，避免多个 Tween 争用音量。
#    入口：ambient_transition
# 4. 环境音淡变与播放器辅助
#    淡出并清理当前音轨，执行单播放器音量渐变，选择当前播放器之外的另一个播放器。
#    核心：_fade_out_current / _fade_player / _get_free_ambient_player


#region 生命周期与初始化

func _ready() -> void:
	ambient_1.volume_db = silent_volume_db
	ambient_2.volume_db = silent_volume_db

	ambient_1.stop()
	ambient_2.stop()

#endregion


#region 按键音效

func tap_play() -> void:
	tap.pitch_scale = randf_range(0.8, 1.2) # 每次按键随机音高。
	tap.play(0.08)

#endregion


#region 世界环境音切换

func ambient_transition(new_tag_id: int, transition_duration: float) -> void:
	var new_world_audio: AudioStream = world_assembler.tag_scenes[new_tag_id].ambient_audio
	var fade_duration: float = max(transition_duration * 2.0 / 3.0, 0.01)
	var fade_in_delay: float = max(transition_duration * 1.0 / 3.0, 0.0)

	# 如果之前有残留 Tween，先清掉，避免音量被多个 Tween 同时控制。
	if _tween:
		_tween.kill()
		_tween = null

	# 目标世界没有环境音时，只淡出并清理当前音轨。
	if new_world_audio == null:
		await _fade_out_current(fade_duration)
		return

	# 首次请求没有旧音轨，只需淡入目标环境音。
	if current_ambient_player == null:
		current_ambient_player = ambient_1
		current_ambient_player.stream = new_world_audio
		current_ambient_player.volume_db = silent_volume_db
		current_ambient_player.play()

		await _fade_player(
			current_ambient_player,
			target_volume_db,
			fade_duration/3,
			Tween.EASE_OUT # 进入时先快后慢。
		)
		return

	# 同一环境音正在播放时，不重复切换。
	if current_ambient_player.stream == new_world_audio and current_ambient_player.playing:
		return

	var old_player := current_ambient_player
	var next_player := _get_free_ambient_player()

	next_player.stream = new_world_audio
	next_player.volume_db = silent_volume_db
	next_player.play()

	current_ambient_player = next_player

	_tween = create_tween()

	# 旧音轨立即淡出；整段交叉淡变结束后停止并释放 stream 引用。
	_tween.tween_property(
		old_player,
		"volume_db",
		silent_volume_db,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# 新音轨先以静音启动，延迟后与旧音轨的淡出并行渐入。
	_tween.parallel().tween_property(
		next_player,
		"volume_db",
		target_volume_db,
		fade_duration
	).set_delay(fade_in_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await _tween.finished

	old_player.stop()
	old_player.stream = null
	old_player.volume_db = silent_volume_db

	_tween = null

#endregion


#region 环境音淡变与播放器辅助

func _fade_out_current(duration: float) -> void:
	if current_ambient_player == null:
		return

	var old_player := current_ambient_player

	# 只有正在播放时才需要淡出。
	if old_player.playing:
		await _fade_player(
			old_player,
			silent_volume_db,
			duration,
			Tween.EASE_IN # 退出时先慢后快。
		)

	old_player.stop()
	old_player.stream = null
	old_player.volume_db = silent_volume_db
	current_ambient_player = null


func _fade_player(
	player: AudioStreamPlayer,
	to_volume_db: float,
	duration: float,
	ease_type: Tween.EaseType
) -> void:
	_tween = create_tween()

	_tween.tween_property(
		player,
		"volume_db",
		to_volume_db,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(ease_type)

	await _tween.finished

	_tween = null


func _get_free_ambient_player() -> AudioStreamPlayer:
	# 当前用 ambient_1，就返回 ambient_2；否则返回 ambient_1。
	if current_ambient_player == ambient_1:
		return ambient_2

	return ambient_1

#endregion
