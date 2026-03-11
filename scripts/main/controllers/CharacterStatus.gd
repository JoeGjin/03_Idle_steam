# 控制角色状态的脚本

extends Node
class_name CharacterStatus

#    sequence_index                      0        1        2         3        4         5         6         7
#CharacterStates enum CharacterState { RESTING, WALKING, RECORDING, PICKING, GAZING, GREETING, CHANGING, TRANSITING }

enum Phase { DURATION, GAP }

# @export var pet: Node2D # 暂时未用，预留
# @export var state_label: Label #调试用
# @export var state_cooldown_label: Label #调试用

@export var state_defs: Array[CharacterStateDef] = []
@export var state: CharacterStates.CharacterState = CharacterStates.CharacterState.WALKING # 当前状态，默认 WALKING, 由状态机内部维护，外部只读
var _sequence_index: int = 0 # 当前状态在 state_defs 中的索引, 由状态机内部维护，外部只关心 state 这个公开属性
var _phase: Phase = Phase.DURATION

var _phase_timer: Timer

signal state_changed(new_state: CharacterStates.CharacterState, duration: float) # 状态改变信号，携带新状态和持续时间（秒）参数




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


func stop_all_timer() -> void:
	_phase_timer.stop()


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
	state_changed.emit(state, def.duration)
	# 进入 duration 阶段
	_phase = Phase.DURATION
	_start_phase(def.duration)


func _start_phase(seconds: float) -> void:
	var s: float = max(0.0, seconds)
	# 用 phase_timer 驱动阶段结束
	_phase_timer.start(s)


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
	match _sequence_index:
		0: return 1
		1: return 0 
		# 2: return 3 
		# 3: return 4 
		# 4: return 5 
		# 5: return 6 
		6: return 7 
		7: return 1 
		_:
			return 1 # 默认回到 1，避免死循环在一个状态



# 通过按键改变状态，按键 0-7 分别对应枚举中的状态，调试用
func _input(event): 
	for i in range(10):
		if event.is_action_pressed("%d" % i):
			start(i)
			break
