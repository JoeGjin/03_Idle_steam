# 控制角色状态的脚本

extends Node
class_name CharacterStatus

#                                        0        1        2         3        4         5         6         7
#CharacterStates enum CharacterState { RESTING, WALKING, RECORDING, PICKING, GAZING, GREETING, CHANGING, TRANSITING }

@export var target: Node2D
@export var debug_mode: bool = false
@export var state_label: Label #调试用
@export var state_cooldown_label: Label #调试用
@export var state: CharacterStates.CharacterState = CharacterStates.CharacterState.WALKING

@export var state_defs: Array[CharacterStateDef] = []

signal state_changed(new_state: CharacterStates.CharacterState)

enum Phase { DURATION, GAP }

var _sequence_index: int = 0
var _phase: Phase = Phase.DURATION

var _phase_timer: Timer
var _debug_timer: Timer

var _phase_end_ms: int = 0 # 仅用于显示剩余时间（调试）


func _ready() -> void:
	_setup_state_defs()
	_setup_timers()


func _setup_state_defs():
	if state_defs.is_empty():
		push_warning("[STATUS] state_defs is empty")
		return


func _setup_timers():
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	add_child(_phase_timer)
	_phase_timer.timeout.connect(_on_phase_timeout)

	_debug_timer = Timer.new()
	_debug_timer.one_shot = false
	_debug_timer.wait_time = 0.1
	add_child(_debug_timer)
	_debug_timer.timeout.connect(_update_debug_countdown)


func stop_all_timer() -> void:
	_phase_timer.stop()
	if debug_mode:
		_debug_timer.stop()
		state_cooldown_label.text = ""


# 第一次将从 main 的 _ready() 方法，通过 start() 方法启动状态机，默认从第一个状态开始
func start(from_index: int = 0) -> void:
	stop_all_timer()
	if state_defs.is_empty():
		return
	_sequence_index = from_index
	if _sequence_index >= state_defs.size():
		return
	_enter_state_at(_sequence_index)


func _enter_state_at(i: int) -> void:
	var def := state_defs[i]
	# 更新公开 state（对外）
	state = def.state
	state_changed.emit(state)
	# 更新调试标签
	if debug_mode:
		state_label.text = CharacterStates.CharacterState.find_key(state)
	# 进入 duration 阶段
	_phase = Phase.DURATION
	_start_phase(def.duration)


func _start_phase(seconds: float) -> void:
	var s: float = max(0.0, seconds)
	_phase_end_ms = Time.get_ticks_msec() + int(s * 1000.0)
	# 用 phase_timer 驱动阶段结束
	_phase_timer.start(s)
	# 开启/关闭调试倒计时刷新（只在你拖了 label 的情况下）
	if debug_mode:
		_debug_timer.start()
		# 立刻刷新一次（避免等 0.1s 才更新）
		_update_debug_countdown()


func _on_phase_timeout() -> void:
	var def := state_defs[_sequence_index]
	if _phase == Phase.DURATION:
		# duration 结束 -> 进入 gap
		_phase = Phase.GAP
		_start_phase(def.gap)
	else:
		# gap 结束 -> 切换到下一个状态 
		_sequence_index = _choose_next_state_index()
		_enter_state_at(_sequence_index)


func _choose_next_state_index() -> int:
	# （循环 for now）
	return (_sequence_index + 1) % state_defs.size()


func _update_debug_countdown() -> void: # 仅在 debug 模式下被 _debug_timer 驱动，用于更新状态剩余时间的显示
	var now := Time.get_ticks_msec()
	var remaining: float = max(0.0, float(_phase_end_ms - now) / 1000.0)
	var phase_name := "DUR" if _phase == Phase.DURATION else "GAP"
	state_cooldown_label.text = "%s: %.2fs" % [phase_name, remaining]
	# 如果已经到 0 了，就没必要继续刷（等下一次 _start_phase 再开）
	if remaining <= 0.0:
		_debug_timer.stop()


# 通过按键改变状态，按键 0-7 分别对应枚举中的状态，调试用
func _input(event): 
	for i in range(10):
		if event.is_action_pressed("%d" % i):
			start(i)
			break
