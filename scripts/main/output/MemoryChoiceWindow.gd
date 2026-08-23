extends Window
class_name MemoryChoiceWindow


signal choice_pressed(index: int)


@export_group("Layout")
@export var choice_size := Vector2(240.0, 240.0)
@export_range(0.0, 400.0, 1.0, "suffix:px") var choice_gap := 96.0
@export_range(0.0, 600.0, 1.0, "suffix:px") var choice_area_height := 280.0
@export_range(0.0, 300.0, 1.0, "suffix:px") var scene_gap := 28.0
## 二选一原生窗口的额外初始垂直偏移；正值向下，负值向上。
@export_range(-600.0, 600.0, 1.0, "suffix:px") var initial_vertical_offset := 0.0
@export_range(0.0, 100.0, 1.0, "suffix:px") var input_region_padding := 20.0

@export_group("Animation")
@export_range(0.0, 2.0, 0.01, "suffix:s") var fade_in_duration := 0.32
@export_range(0.0, 2.0, 0.01, "suffix:s") var selected_grow_duration := 0.55
@export_range(0.0, 2.0, 0.01, "suffix:s") var selected_hold_duration := 0.35
@export_range(0.0, 2.0, 0.01, "suffix:s") var fly_duration := 0.72
@export_range(0.0, 2.0, 0.01, "suffix:s") var rejected_fade_duration := 0.25


@onready var choice_left: TextureButton = %ChoiceLeft
@onready var choice_right: TextureButton = %ChoiceRight


var _follow_window: Window
var _follow_window_start_position := Vector2i.ZERO
var _choice_window_start_position := Vector2i.ZERO
var _awaiting_choice := false
var _selected_index := -1
var _flight_button: TextureButton
var _flight_start := Vector2.ZERO
var _flight_control := Vector2.ZERO
var _flight_end := Vector2.ZERO


func _ready() -> void:
    choice_left.pressed.connect(_on_choice_pressed.bind(0))
    choice_right.pressed.connect(_on_choice_pressed.bind(1))
    show()
    hide()
    set_process(false)


func _process(_delta: float) -> void:
    if not visible or not is_instance_valid(_follow_window):
        return

    var window_offset := _follow_window.position - _follow_window_start_position
    var target_position := _choice_window_start_position + window_offset
    if position != target_position:
        position = target_position


func begin_choices(follow_window: Window) -> void:
    _follow_window = follow_window
    var top_extension := roundi(choice_area_height + scene_gap)
    position = (
        follow_window.position
        - Vector2i(0, top_extension)
        + Vector2i(0, roundi(initial_vertical_offset))
    )
    size = Vector2i(
        follow_window.size.x,
        follow_window.size.y + top_extension
    )
    _follow_window_start_position = follow_window.position
    _choice_window_start_position = position
    _reset_button(choice_left)
    _reset_button(choice_right)
    set_process(true)


func play_choice(
    left_memory: MemoryDef,
    right_memory: MemoryDef,
    pet_screen_position: Vector2
) -> MemoryDef:
    # 使用相对主窗口的坐标，用户在选择期间拖动窗口也不会改变飞行终点。
    var pet_window_position := pet_screen_position - Vector2(position)
    _prepare_button(choice_left, left_memory.texture)
    _prepare_button(choice_right, right_memory.texture)
    _layout_buttons()
    _set_input_region_for_buttons([choice_left, choice_right], 1.2)
    if not visible:
        show()

    var fade_in := create_tween().set_parallel(true)
    fade_in.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    for button in [choice_left, choice_right]:
        fade_in.tween_property(button, "modulate:a", 1.0, fade_in_duration)
        fade_in.tween_property(button, "scale", Vector2.ONE, fade_in_duration)
    await fade_in.finished

    _selected_index = -1
    _awaiting_choice = true
    await choice_pressed
    _awaiting_choice = false
    var selected_index := _selected_index
    choice_left.disabled = true
    choice_right.disabled = true

    var selected := choice_left if selected_index == 0 else choice_right
    var rejected := choice_right if selected_index == 0 else choice_left
    await _play_selection_animation(selected, rejected, pet_window_position)

    return left_memory if selected_index == 0 else right_memory


func finish_choices() -> void:
    _awaiting_choice = false
    set_process(false)
    _follow_window = null
    _reset_button(choice_left)
    _reset_button(choice_right)
    mouse_passthrough_polygon = PackedVector2Array()
    hide()


func _prepare_button(button: TextureButton, texture: Texture2D) -> void:
    button.texture_normal = texture
    button.size = choice_size
    button.pivot_offset = choice_size * 0.5
    button.scale = Vector2.ONE * 0.78
    button.modulate.a = 0.0
    button.disabled = false
    button.show()


func _layout_buttons() -> void:
    var content_size := Vector2(size)
    var pair_width := choice_size.x * 2.0 + choice_gap
    var pair_left := (content_size.x - pair_width) * 0.5
    var top := maxf(0.0, (choice_area_height - choice_size.y) * 0.5)
    choice_left.position = Vector2(pair_left, top)
    choice_right.position = Vector2(pair_left + choice_size.x + choice_gap, top)


func _play_selection_animation(
    selected: TextureButton,
    rejected: TextureButton,
    pet_window_position: Vector2
) -> void:
    var emphasis := create_tween().set_parallel(true)
    emphasis.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    emphasis.tween_property(
        selected,
        "scale",
        Vector2.ONE * 1.14,
        selected_grow_duration
    )
    emphasis.tween_property(
        rejected,
        "scale",
        Vector2.ONE * 0.2,
        rejected_fade_duration
    )
    emphasis.tween_property(
        rejected,
        "modulate:a",
        0.0,
        rejected_fade_duration
    )
    await emphasis.finished

    rejected.hide()
    _set_input_region_for_buttons([selected], 1.14)

    if selected_hold_duration > 0.0:
        await get_tree().create_timer(selected_hold_duration).timeout

    _flight_button = selected
    _flight_start = selected.position
    _flight_end = pet_window_position - selected.size * 0.5
    var flight_midpoint := _flight_start.lerp(_flight_end, 0.5)
    var arc_height := maxf(120.0, absf(_flight_end.x - _flight_start.x) * 0.28)
    _flight_control = flight_midpoint + Vector2(0.0, -arc_height)

    var flight := create_tween().set_parallel(true)
    flight.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    flight.tween_method(_set_flight_progress, 0.0, 1.0, fly_duration)
    flight.tween_property(selected, "scale", Vector2.ONE * 0.18, fly_duration)
    flight.tween_property(selected, "modulate:a", 0.0, fly_duration)
    await flight.finished

    selected.hide()


func _set_flight_progress(progress: float) -> void:
    if not is_instance_valid(_flight_button):
        return

    var inverse := 1.0 - progress
    _flight_button.position = (
        inverse * inverse * _flight_start
        + 2.0 * inverse * progress * _flight_control
        + progress * progress * _flight_end
    )
    _set_input_region_for_buttons([_flight_button])


func _set_input_region_for_buttons(
    buttons: Array,
    scale_override: float = -1.0
) -> void:
    var region := Rect2()
    var has_region := false
    for button: TextureButton in buttons:
        if not is_instance_valid(button) or not button.visible:
            continue

        var visual_scale := button.scale.abs()
        if scale_override >= 0.0:
            visual_scale = Vector2.ONE * scale_override
        var visual_size := button.size * visual_scale
        var center := button.position + button.pivot_offset
        var button_rect := Rect2(center - visual_size * 0.5, visual_size)
        button_rect = button_rect.grow(input_region_padding)
        region = region.merge(button_rect) if has_region else button_rect
        has_region = true

    if not has_region:
        mouse_passthrough_polygon = PackedVector2Array()
        return

    mouse_passthrough_polygon = PackedVector2Array([
        region.position,
        Vector2(region.end.x, region.position.y),
        region.end,
        Vector2(region.position.x, region.end.y),
    ])


func _reset_button(button: TextureButton) -> void:
    button.disabled = true
    button.modulate = Color.WHITE
    button.scale = Vector2.ONE
    button.texture_normal = null
    button.hide()


func _on_choice_pressed(index: int) -> void:
    if not _awaiting_choice:
        return

    _awaiting_choice = false
    _selected_index = index
    choice_pressed.emit(index)
