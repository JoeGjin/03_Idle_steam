# 从WorldAssembler 得到各 vars的值，apply到子节点上


extends Parallax2D
class_name WorldSky


@onready var main: Sprite2D = $Main
@onready var star: Sprite2D = $Star
@onready var effect: Sprite2D = $Effect

var main_color: Color
var invert_amount: float = 0.0
var star_texture: Texture2D
var star_color: Color
var effect_texture: Texture2D
var effect_color: Color

var _main_material: ShaderMaterial
var _transition_tweens: Array[Tween] = []



func _ready() -> void:
    var source_material := main.material as ShaderMaterial
    if source_material == null:
        push_warning("[SKY] Main requires a ShaderMaterial for invert_amount")
        return

    # 只复制材质参数，保留 Shader 引用，避免影响共用材质的其他实例。
    _main_material = source_material.duplicate() as ShaderMaterial
    main.material = _main_material



func apply_immediate() -> void:
    _kill_transition_tweens()

    main.modulate = main_color
    _set_invert_amount(invert_amount)
    star.texture = star_texture
    star.modulate = star_color
    effect.texture = effect_texture
    effect.modulate = effect_color



func transition_to_target(duration: float) -> void:
    _kill_transition_tweens()

    var safe_duration := maxf(duration, 0.0)
    if is_zero_approx(safe_duration):
        apply_immediate()
        return

    _transition_color(main, main_color, safe_duration)
    _transition_invert_amount(safe_duration)
    _transition_texture(star, star_texture, star_color, safe_duration)
    _transition_texture(effect, effect_texture, effect_color, safe_duration)



func _set_invert_amount(value: float) -> void:
    if _main_material != null:
        _main_material.set_shader_parameter(&"invert_amount", clampf(value, 0.0, 1.0))



func _transition_invert_amount(duration: float) -> void:
    if _main_material == null:
        return

    var current_amount := float(_main_material.get_shader_parameter(&"invert_amount"))
    var target_amount := clampf(invert_amount, 0.0, 1.0)
    if is_equal_approx(current_amount, target_amount):
        return

    # 从材质当前值开始，过渡被停止后也能继续衔接当前画面。
    var tween := create_tween()
    tween.tween_method(_set_invert_amount, current_amount, target_amount, duration)
    _transition_tweens.append(tween)



func _transition_color(target: CanvasItem, target_color: Color, duration: float) -> void:
    if target.modulate.is_equal_approx(target_color):
        return

    var tween := create_tween()
    tween.tween_property(target, "modulate", target_color, duration)
    _transition_tweens.append(tween)



func _transition_texture(
    target: Sprite2D,
    target_texture: Texture2D,
    target_color: Color,
    duration: float
) -> void:
    if target.texture == target_texture:
        _transition_color(target, target_color, duration)
        return

    # RGB 在整个过渡期内变化；Alpha 分两段淡出、换图、淡入，避免纹理瞬切。
    var color_tween := create_tween().set_parallel(true)
    color_tween.tween_property(target, "modulate:r", target_color.r, duration)
    color_tween.tween_property(target, "modulate:g", target_color.g, duration)
    color_tween.tween_property(target, "modulate:b", target_color.b, duration)
    _transition_tweens.append(color_tween)

    var half_duration := duration * 0.5
    var texture_tween := create_tween()
    texture_tween.tween_property(target, "modulate:a", 0.0, half_duration)
    texture_tween.tween_callback(
        func() -> void:
            target.texture = target_texture
    )
    texture_tween.tween_property(target, "modulate:a", target_color.a, half_duration)
    _transition_tweens.append(texture_tween)



func _kill_transition_tweens() -> void:
    for tween in _transition_tweens:
        if tween != null and tween.is_valid():
            tween.kill()
    _transition_tweens.clear()
