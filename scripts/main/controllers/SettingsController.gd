extends Node


const SETTINGS_PATH := "user://settings.cfg"
const AUDIO_BUSES: Array[StringName] = [&"Master", &"Ambient", &"SFX"]
const LANGUAGE_CODES: Array[String] = ["en", "zh_CN"]

## 连续调整音量时合并写入；退出前会立即保存。
@export_range(0.1, 2.0, 0.1, "suffix:s") var save_delay := 0.4

@onready var all_output: Control = $"../../AllOutput"
@onready var layer_setting: Control = $"../../UIWindow/UIRoot/HandBook/LayerSetting"
@onready var mouse_controller: MouseController = %MouseController
@onready var zooming: Button = %Zooming

var language := "en"
var _config := ConfigFile.new()
var _save_timer: Timer
var _window_ready := false
var _quitting := false


# 本脚本负责设置读写、启动恢复和退出前保存；语言只记忆选择，不调用翻译切换。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与恢复：入树时读取并恢复音量，布局就绪后恢复语言选项、缩放和位置。
# 2. 保存与退出：合并设置调整、拖动和缩放结束的保存请求，主窗口关闭时立即保存并打印结果再退出。
# 3. 配置读取与校验：启动时打印读取结果，读取失败使用默认值，校验语言、音量、倍率和屏幕位置。


#region 生命周期与恢复

func _enter_tree() -> void:
    # Controllers 位于设置页之前，先恢复总线，让设置页的 _ready 直接读取正确音量。
    _load_settings()
    _restore_audio()


func _ready() -> void:
    _save_timer = Timer.new()
    _save_timer.one_shot = true
    _save_timer.ignore_time_scale = true
    _save_timer.timeout.connect(save_settings)
    add_child(_save_timer)

    layer_setting.connect("settings_changed", queue_save)
    layer_setting.connect("language_selected", _on_language_selected)
    layer_setting.connect("quit_requested", request_quit)
    mouse_controller.drag_ended.connect(queue_save)
    zooming.connect("resize_ended", queue_save)

    get_tree().auto_accept_quit = false
    get_window().close_requested.connect(request_quit)

    # AllOutput 的首次布局会重设窗口尺寸与位置，必须等它完成后再恢复。
    if not all_output.call("is_layout_ready"):
        await Signal(all_output, "layout_ready")
    layer_setting.call("set_language_selection", language)
    _restore_window()
    _window_ready = true


func _restore_audio() -> void:
    for bus_name in AUDIO_BUSES:
        var bus_index := AudioServer.get_bus_index(bus_name)
        if bus_index < 0:
            continue
        var default_volume := _get_bus_volume(bus_index)
        var volume := clampf(_read_number("audio", String(bus_name), default_volume), 0.0, 1.0)
        AudioServer.set_bus_mute(bus_index, is_zero_approx(volume))
        if volume > 0.0:
            AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume))


func _restore_window() -> void:
    var zoom_scale := clampf(
        _read_number("window", "zoom_scale", 1.0),
        float(zooming.get("min_scale")),
        float(zooming.get("max_scale"))
    )
    # 保存的是相对 draw_scale 的用户倍率，避免每次启动都把已保存倍率乘入基础尺寸。
    all_output.call("apply_window_scale", zoom_scale, Vector2.ZERO)

    var saved_position: Variant = _config.get_value("window", "position", get_window().position)
    if not saved_position is Vector2i:
        saved_position = get_window().position
    get_window().position = _get_visible_window_position(saved_position)

#endregion


#region 保存与退出

func queue_save() -> void:
    if not _quitting:
        _save_timer.start(save_delay)


func save_settings() -> void:
    _config.set_value("general", "language", language)
    for bus_name in AUDIO_BUSES:
        var bus_index := AudioServer.get_bus_index(bus_name)
        if bus_index >= 0:
            _config.set_value("audio", String(bus_name), _get_bus_volume(bus_index))

    # 启动尚未完成时退出，保留原有窗口记录，避免用首次布局前的临时状态覆盖。
    if _window_ready:
        _config.set_value("window", "zoom_scale", all_output.call("get_window_zoom_scale"))
        _config.set_value("window", "position", all_output.call("get_normal_window_position"))

    var error := _config.save(SETTINGS_PATH)
    if error != OK:
        var message := "[SettingsController] 保存设置失败，错误码：%s" % error
        if _quitting:
            print(message)
        push_warning(message)
    elif _quitting:
        print("[SettingsController] 退出前设置保存完成：%s" % SETTINGS_PATH)


func request_quit() -> void:
    if _quitting:
        return
    _quitting = true
    _save_timer.stop()
    save_settings()
    get_tree().quit()


func _on_language_selected(locale: String) -> void:
    if locale not in LANGUAGE_CODES:
        return
    language = locale
    queue_save()

#endregion


#region 配置读取与校验

func _load_settings() -> void:
    var error := _config.load(SETTINGS_PATH)
    if error != OK:
        _config.clear()
        if error == ERR_FILE_NOT_FOUND:
            print("[SettingsController] 未找到设置文件，使用默认设置：%s" % SETTINGS_PATH)
        else:
            var message := "[SettingsController] 读取设置失败，使用默认值，错误码：%s" % error
            print(message)
            push_warning(message)
    else:
        print("[SettingsController] 设置读取完成：%s" % SETTINGS_PATH)

    var saved_language: Variant = _config.get_value("general", "language", "en")
    if saved_language is String and saved_language in LANGUAGE_CODES:
        language = saved_language


func _read_number(section: String, key: String, fallback: float) -> float:
    var value: Variant = _config.get_value(section, key, fallback)
    if (value is float or value is int) and is_finite(float(value)):
        return float(value)
    return fallback


func _get_bus_volume(bus_index: int) -> float:
    if AudioServer.is_bus_mute(bus_index):
        return 0.0
    return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)), 0.0, 1.0)


func _get_visible_window_position(saved_position: Vector2i) -> Vector2i:
    # 透明窗口边缘不一定能拖动，检查世界中央区域，保留至少一块可操作区域。
    var visible_rect: Rect2 = all_output.call("get_world_visual_rect")
    visible_rect.position = (visible_rect.position + visible_rect.size * 0.25) * all_output.scale
    visible_rect.size *= all_output.scale * 0.5
    var screen_rect := Rect2(Vector2(saved_position) + visible_rect.position, visible_rect.size)
    var required_size := Vector2(minf(64.0, visible_rect.size.x), minf(64.0, visible_rect.size.y))

    for screen_index in DisplayServer.get_screen_count():
        var usable_rect := Rect2(DisplayServer.screen_get_usable_rect(screen_index))
        var overlap := screen_rect.intersection(usable_rect)
        if overlap.size.x >= required_size.x and overlap.size.y >= required_size.y:
            return saved_position

    # 原显示器已断开或位置失效时，让世界主体回到主屏中央；正常的负坐标不视为错误。
    var primary_rect := DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen())
    if primary_rect.size.x <= 0 or primary_rect.size.y <= 0:
        return saved_position
    return Vector2i(Vector2(primary_rect.get_center()) - visible_rect.get_center())

#endregion
