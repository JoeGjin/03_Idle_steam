extends Control


# 根据收集强度插值的粒子数量范围。
const MIN_PARTICLE_COUNT := 18
const MAX_PARTICLE_COUNT := 54

# 动画阶段的时间边界（秒）：扩散结束、汇聚结束、整体结束。
const GATHER_START := 0.62
const GATHER_END := 1.16
const TOTAL_DURATION := 1.34

# 扩散阶段的重力，以及按粒子索引循环使用的色板。
const GRAVITY := Vector2(0.0, 115.0)
const COLORS := [
	Color("fff3a6"),
	Color("ff9e7a"),
	Color("ff70a6"),
	Color("70d6ff"),
	Color("8cff98"),
	Color("c9a7ff"),
]


# 起终点均由 TransientFxWindow 转换为特效窗口局部坐标后传入。
var _origin := Vector2.ZERO
var _target := Vector2.ZERO

# 本次播放的累计时间，以及创建时生成的粒子参数与随机数发生器。
var _elapsed := 0.0
var _particles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

# 由收集次数计算的效果强度和实际粒子数量。
var _intensity := 0.5
var _particle_count := 36


# 本脚本绘制收集烟花：起点爆发、粒子扩散并汇聚到目标、终点闪光。
# TransientFxWindow 创建实例、传入局部坐标，并按 get_duration 的时长负责窗口关闭与节点清理。
#
# 目录（与下方代码分区顺序一致）
# 1. 配置入口与播放时长
#    根据收集次数计算强度和粒子数量，初始化随机参数；节点不接收鼠标输入。
#    入口：configure / get_duration
# 2. 生命周期与重绘调度
#    入树后开始累计时间并请求重绘；到达 TOTAL_DURATION 时停止逐帧更新。
#    _draw 按阶段组合起点闪光、粒子和终点闪光，节点释放由窗口负责。
#    入口：_ready / _process / _draw
# 3. 粒子生成、运动与绘制
#    创建时按环形分布生成带随机扰动的速度、半径和曲线偏移，颜色按色板循环。
#    GATHER_START 前按抛体运动扩散，之后沿二次贝塞尔曲线平滑汇聚至目标。
#    每帧按时间求当前位置及拖尾位置，绘制拖尾、粒子主体与亮芯；汇聚时同步缩小和变淡。
#    核心：_build_particles / _particle_position / _draw_particle
# 4. 起终点闪光
#    起点在前 0.28 秒绘制扩张圆环与亮芯；GATHER_END 后在目标位置绘制收集闪光。
#    核心：_draw_origin_flash / _draw_target_flash


#region 配置入口与播放时长

func configure(
	origin: Vector2,
	target: Vector2,
	collection_count: int = 3,
	max_collection_count: int = 5
) -> void:
	_origin = origin
	_target = target
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var safe_max_count := maxi(max_collection_count, 1)
	var safe_count := clampi(collection_count, 1, safe_max_count)
	_intensity = 1.0
	if safe_max_count > 1:
		_intensity = float(safe_count - 1) / float(safe_max_count - 1)
	_particle_count = roundi(lerpf(MIN_PARTICLE_COUNT, MAX_PARTICLE_COUNT, _intensity))

	_rng.randomize()
	_build_particles()


func get_duration() -> float:
	return TOTAL_DURATION

#endregion


#region 生命周期与重绘调度

func _ready() -> void:
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, TOTAL_DURATION)
	queue_redraw()
	if _elapsed >= TOTAL_DURATION:
		set_process(false)


func _draw() -> void:
	_draw_origin_flash()

	if _elapsed <= GATHER_END:
		for particle in _particles:
			_draw_particle(particle)

	_draw_target_flash()

#endregion


#region 粒子生成、运动与绘制

func _build_particles() -> void:
	# 随机参数只在创建时确定，逐帧绘制按同一组参数和时间求值。
	_particles.clear()
	var burst_scale := lerpf(0.8, 1.2, _intensity)
	var particle_size_scale := lerpf(0.85, 1.15, _intensity)
	for index in _particle_count:
		var angle := TAU * float(index) / float(_particle_count)
		angle += _rng.randf_range(-0.09, 0.09)
		var direction := Vector2.from_angle(angle)
		var speed := _rng.randf_range(220.0, 390.0) * burst_scale
		var curve_side := -1.0 if index % 2 == 0 else 1.0

		_particles.append({
			"velocity": direction * speed,
			"color": COLORS[index % COLORS.size()],
			"radius": _rng.randf_range(2.8, 5.2) * particle_size_scale,
			"curve": curve_side * _rng.randf_range(35.0, 95.0),
		})


func _particle_position(particle: Dictionary, time: float) -> Vector2:
	var velocity: Vector2 = particle["velocity"]
	# 汇聚段始终从扩散结束位置出发，避免控制点继续随时间漂移。
	var ballistic_time := minf(time, GATHER_START)
	var ballistic_position := (
		_origin
		+ velocity * ballistic_time
		+ GRAVITY * ballistic_time * ballistic_time * 0.5
	)

	if time <= GATHER_START:
		return ballistic_position

	var progress := clampf(
		(time - GATHER_START) / (GATHER_END - GATHER_START),
		0.0,
		1.0
	)
	# smoothstep 让粒子平滑离开爆炸末端，并同步落入收藏按钮。
	progress = progress * progress * (3.0 - 2.0 * progress)

	var to_target := _target - ballistic_position
	var perpendicular := Vector2(-to_target.y, to_target.x).normalized()
	var curve_amount: float = particle["curve"]
	var control := ballistic_position.lerp(_target, 0.5) + perpendicular * curve_amount
	var inverse := 1.0 - progress
	return (
		inverse * inverse * ballistic_position
		+ 2.0 * inverse * progress * control
		+ progress * progress * _target
	)


func _draw_particle(particle: Dictionary) -> void:
	var position_now := _particle_position(particle, _elapsed)
	var previous_time := maxf(_elapsed - 0.045, 0.0)
	var position_before := _particle_position(particle, previous_time)
	var color: Color = particle["color"]
	var radius: float = particle["radius"]
	var alpha := 1.0
	var size_scale := 1.0

	if _elapsed >= GATHER_START:
		var gather_progress := clampf(
			(_elapsed - GATHER_START) / (GATHER_END - GATHER_START),
			0.0,
			1.0
		)
		size_scale = lerpf(1.0, 0.38, gather_progress)
		alpha = lerpf(1.0, 0.72, gather_progress)

	var trail_color := color
	trail_color.a = alpha * 0.38
	draw_line(position_before, position_now, trail_color, maxf(1.0, radius * size_scale * 0.75), true)

	color.a = alpha
	draw_circle(position_now, radius * size_scale, color)
	var core_color := Color.WHITE
	core_color.a = alpha * 0.8
	draw_circle(position_now, radius * size_scale * 0.36, core_color)

#endregion


#region 起终点闪光

func _draw_origin_flash() -> void:
	if _elapsed > 0.28:
		return

	var progress := _elapsed / 0.28
	var flash_scale := lerpf(0.8, 1.2, _intensity)
	var ring_color := Color("fff4c2")
	ring_color.a = (1.0 - progress) * 0.7
	draw_arc(
		_origin,
		lerpf(8.0, 54.0, progress) * flash_scale,
		0.0,
		TAU,
		48,
		ring_color,
		3.0,
		true
	)

	var core_color := Color.WHITE
	core_color.a = (1.0 - progress) * 0.9
	draw_circle(_origin, lerpf(13.0, 2.0, progress) * flash_scale, core_color)


func _draw_target_flash() -> void:
	if _elapsed < GATHER_END:
		return

	var progress := clampf(
		(_elapsed - GATHER_END) / (TOTAL_DURATION - GATHER_END),
		0.0,
		1.0
	)
	var flash_scale := lerpf(0.75, 1.35, _intensity)
	var flash_color := Color("fff7c7")
	flash_color.a = (1.0 - progress) * 0.95
	draw_circle(_target, lerpf(12.0, 3.0, progress) * flash_scale, flash_color)

	var ring_color := Color("ffffff")
	ring_color.a = (1.0 - progress) * 0.8
	draw_arc(
		_target,
		lerpf(6.0, 42.0, progress) * flash_scale,
		0.0,
		TAU,
		48,
		ring_color,
		3.0,
		true
	)

#endregion
