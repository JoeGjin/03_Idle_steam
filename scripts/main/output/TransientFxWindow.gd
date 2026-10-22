extends Window
class_name TransientFxWindow


# 收集烟花的绘制脚本，以及按收集强度插值的窗口留白范围（屏幕像素）。
const CollectionFireworkFx = preload("res://scripts/main/output/CollectionFireworkFx.gd")
const MIN_EFFECT_PADDING := 280.0
const MAX_EFFECT_PADDING := 380.0


# 当前特效节点的挂载容器。
@onready var effect_root: Control = %EffectRoot


# 播放代次：新播放或停止时递增，使旧计时器无法关闭后续特效。
var _play_generation := 0

# 跟随主窗口所需的引用与播放开始时的屏幕位置基准。
var _follow_window: Window
var _follow_window_start_position := Vector2i.ZERO
var _effect_window_start_position := Vector2i.ZERO


# 本脚本用透明原生窗口承载临时特效，负责窗口范围、主窗口跟随和播放生命周期。
# Main 发起收集反馈；CollectionFireworkFx 负责烟花自身的粒子绘制与动画时长。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与主窗口跟随
#    启动时先显示再隐藏以预热原生窗口；播放期间按主窗口的屏幕位移同步特效窗口位置。
#    入口：_ready / _process
# 2. 收集烟花入口
#    根据收集次数计算窗口留白，将屏幕起终点转换为特效窗口局部坐标，再创建并播放烟花。
#    入口：play_collection_firework
# 3. 通用特效播放与清理
#    按屏幕矩形设置窗口，挂载新特效并跟随主窗口；Control 特效铺满容器。
#    正时长到期后仅关闭同一播放代次；duration <= 0 时立即返回，特效持续到停止或被替换。
#    停止时关闭跟随、隐藏窗口并释放内容，新播放也会清理旧内容。
#    入口：play_effect / stop_effect；核心：_clear_effect
# 4. 特效窗口范围计算
#    取屏幕起终点的外接矩形并向四周扩展留白，将位置与尺寸转换为整数窗口坐标。
#    核心：_make_effect_rect


#region 生命周期与主窗口跟随

func _ready() -> void:
    # 预先创建透明原生窗口，避免第一次播放特效时出现初始化黑帧。
    show()
    hide()
    set_process(false)


func _process(_delta: float) -> void:
    if not visible or not is_instance_valid(_follow_window):
        return

    var window_offset := _follow_window.position - _follow_window_start_position
    var target_position := _effect_window_start_position + window_offset
    if position != target_position:
        position = target_position

#endregion


#region 收集烟花入口

func play_collection_firework(
    origin_screen: Vector2,
    target_screen: Vector2,
    collection_count: int = 3,
    max_collection_count: int = 5
) -> void:
    var safe_max_count : int = maxi(max_collection_count, 1)
    var safe_count : int = clampi(collection_count, 1, safe_max_count)
    var intensity : float = 1.0
    if safe_max_count > 1:
        intensity = float(safe_count - 1) / float(safe_max_count - 1)

    var effect_padding := lerpf(MIN_EFFECT_PADDING, MAX_EFFECT_PADDING, intensity)
    var effect_rect := _make_effect_rect(
        origin_screen,
        target_screen,
        effect_padding
    )
    # 绘制节点使用窗口局部坐标，窗口本身按屏幕坐标放置。
    var effect := CollectionFireworkFx.new()
    effect.configure(
        origin_screen - Vector2(effect_rect.position),
        target_screen - Vector2(effect_rect.position),
        collection_count,
        max_collection_count
    )
    await play_effect(effect, effect_rect, effect.get_duration())

#endregion


#region 通用特效播放与清理

func play_effect(effect: CanvasItem, screen_rect: Rect2i, duration: float) -> void:
    _play_generation += 1
    var generation := _play_generation

    _clear_effect()
    position = screen_rect.position
    size = screen_rect.size
    _follow_window = get_tree().root
    _follow_window_start_position = _follow_window.position
    _effect_window_start_position = position
    effect_root.add_child(effect)
    if effect is Control:
        effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    show()
    set_process(true)

    # 非正时长保留特效，等待后续 stop_effect 或新播放替换。
    if duration <= 0.0:
        return

    await get_tree().create_timer(duration).timeout
    # 等待期间若已开始新播放或停止，旧计时器不再处理当前窗口。
    if generation == _play_generation:
        stop_effect()


func stop_effect() -> void:
    _play_generation += 1
    set_process(false)
    _follow_window = null
    hide()
    _clear_effect()


func _clear_effect() -> void:
    for child in effect_root.get_children():
        child.queue_free()

#endregion


#region 特效窗口范围计算

func _make_effect_rect(
    origin_screen: Vector2,
    target_screen: Vector2,
    effect_padding: float
) -> Rect2i:
    var minimum := Vector2(
        minf(origin_screen.x, target_screen.x),
        minf(origin_screen.y, target_screen.y)
    ) - Vector2.ONE * effect_padding
    var maximum := Vector2(
        maxf(origin_screen.x, target_screen.x),
        maxf(origin_screen.y, target_screen.y)
    ) + Vector2.ONE * effect_padding

    return Rect2i(
        Vector2i(floori(minimum.x), floori(minimum.y)),
        Vector2i(ceili(maximum.x - minimum.x), ceili(maximum.y - minimum.y))
    )

#endregion
