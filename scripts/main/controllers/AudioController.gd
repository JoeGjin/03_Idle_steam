extends Node
class_name AudioController


@export var target_volume_db: float = -10.0
@export var silent_volume_db: float = -80.0

@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var ambient_1: AudioStreamPlayer = $Ambient_1
@onready var ambient_2: AudioStreamPlayer = $Ambient_2
@onready var tap: AudioStreamPlayer = $Tap


var current_ambient_player: AudioStreamPlayer = null
var _tween: Tween = null


func _ready() -> void:
	ambient_1.volume_db = silent_volume_db
	ambient_2.volume_db = silent_volume_db

	ambient_1.stop()
	ambient_2.stop()


func tap_play() -> void:
	tap.pitch_scale = randf_range(0.8, 1.2) # 你想要的范围
	tap.play(0.08)



func ambient_transition(new_world_id: int, transition_duration: float) -> void:
	var new_world_audio: AudioStream = world_assembler.world_defs[new_world_id].ambient_audio
	var fade_duration: float = max(transition_duration * 2.0 / 3.0, 0.01)
	var fade_in_delay: float = max(transition_duration * 1.0 / 3.0, 0.0)

	# Note: 如果之前有残留 Tween，先清掉，避免音量被多个 Tween 同时控制。
	if _tween:
		_tween.kill()
		_tween = null

	# Note: 如果新世界没有 ambient audio，只淡出当前 ambient。
	if new_world_audio == null:
		await _fade_out_current(fade_duration)
		return

	# Note: 第一次初始化，没有旧 ambient，直接淡入新 ambient。
	if current_ambient_player == null:
		current_ambient_player = ambient_1
		current_ambient_player.stream = new_world_audio
		current_ambient_player.volume_db = silent_volume_db
		current_ambient_player.play()

		await _fade_player(
			current_ambient_player,
			target_volume_db,
			fade_duration/3,
			Tween.EASE_OUT # Note: 进入时先快后慢。
		)
		return

	# Note: 如果当前已经在播放同一个 ambient，不重复切换。
	if current_ambient_player.stream == new_world_audio and current_ambient_player.playing:
		return

	var old_player := current_ambient_player
	var next_player := _get_free_ambient_player()

	next_player.stream = new_world_audio
	next_player.volume_db = silent_volume_db
	next_player.play()

	current_ambient_player = next_player

	_tween = create_tween()

	# Note: transition 一开始，旧 ambient 立刻淡出，持续 transition_duration * 2/3。
	_tween.tween_property(
		old_player,
		"volume_db",
		silent_volume_db,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Note: 新 ambient 延迟 transition_duration * 1/3 后淡入，持续 transition_duration * 2/3。
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


func _fade_out_current(duration: float) -> void:
	# Note: 没有当前 ambient 时，什么都不用淡出。
	if current_ambient_player == null:
		return

	var old_player := current_ambient_player

	# Note: 只有正在播放时才需要淡出。
	if old_player.playing:
		await _fade_player(
			old_player,
			silent_volume_db,
			duration,
			Tween.EASE_IN # Note: 退出时先慢后快。
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
	# Note: 当前用 ambient_1，就返回 ambient_2；否则返回 ambient_1。
	if current_ambient_player == ambient_1:
		return ambient_2

	return ambient_1
