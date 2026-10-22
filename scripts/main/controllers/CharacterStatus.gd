# 按状态定义与阶段计时推进角色状态，并通过 state_changed 通知 Main。

extends Node
class_name CharacterStatus


# 每个状态先经历持续期，再经历间隔期；间隔期间保留当前公开状态。
enum Phase { DURATION, GAP }

# 预留角色引用，暂不启用。
# @export var pet: Node2D # 暂时未用，预留

# 状态配置与公开状态：state_defs 的数组索引不等同于状态枚举值。
@export var state_defs: Array[CharacterStateDef] = []
@export var state: CharacterStates.CharacterState = CharacterStates.CharacterState.WALKING # 当前状态，默认 WALKING, 由状态机内部维护，外部只读

# 当前数组索引、阶段与共用的单次计时器。
var _sequence_index: int = 0 # 当前状态在 state_defs 中的索引, 由状态机内部维护，外部只关心 state 这个公开属性
var _phase: Phase = Phase.DURATION
var _phase_timer: Timer

signal state_changed(new_state: CharacterStates.CharacterState, duration: float) # 状态改变信号，携带新状态和持续时间（秒）参数


# 目录（与下方代码分区顺序一致）
# 1. 生命周期与初始化
#    检查 state_defs 是否为空，创建供持续期与间隔期共用的单次计时器。
#    _ready 只做准备，不自动启动状态循环。
# 2. 启动与停止
#    start 按 state_defs 数组索引启动；默认索引为 0，Main 当前传入 1。
#    stop_all_timer 只停止阶段计时器，不重置当前状态、索引或阶段。
# 3. 状态进入与阶段推进
#    进入状态时更新 state 并发出 state_changed，再启动 DURATION 计时。
#    持续期结束后进入 GAP；间隔期结束后选择并进入下一状态。
#    核心：_enter_state_at / _start_phase / _on_phase_timeout
# 4. 下一状态选择
#    当前按数组索引执行 0 与 1 循环、6 → 7 → 1，其余索引回到 1。
#    入口：_choose_next_state_index；此处尚未使用资源中的优先级或中断配置。


#region 生命周期与初始化

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

#endregion


#region 启动与停止

func start(from_index: int = 0) -> void:
	stop_all_timer()
	if state_defs.is_empty():
		return
	_sequence_index = from_index
	if _sequence_index >= state_defs.size():
		return
	_enter_state_at(_sequence_index)


func stop_all_timer() -> void:
	_phase_timer.stop()

#endregion


#region 状态进入与阶段推进

func _enter_state_at(i: int) -> void:
	var def := state_defs[i]
	state = def.state
	state_changed.emit(state, def.duration)
	_phase = Phase.DURATION
	_start_phase(def.duration)


func _start_phase(seconds: float) -> void:
	var s: float = max(0.0, seconds)
	_phase_timer.start(s)


func _on_phase_timeout() -> void:
	var def := state_defs[_sequence_index]
	if _phase == Phase.DURATION:
		# 间隔期间不再次发出 state_changed，继续保留当前 state。
		_phase = Phase.GAP
		_start_phase(def.gap)
	else:
		_sequence_index = _choose_next_state_index()
		_enter_state_at(_sequence_index)

#endregion


#region 下一状态选择

func _choose_next_state_index() -> int:
	# 当前临时跳转规则，以 state_defs 的数组顺序为准。
	match _sequence_index:
		0: return 1
		1: return 0
		6: return 7
		7: return 1
		_:
			return 1 # 默认回到 1，避免死循环在一个状态

#endregion
