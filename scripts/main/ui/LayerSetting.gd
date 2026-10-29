extends Control


signal settings_changed
signal language_selected(locale: String)
signal quit_requested

const LANGUAGE_CODES: Array[String] = ["en", "zh_CN"]

@onready var language_select: OptionButton = $SettingsOptions/LanguageRow/LanguageSelect
@onready var master_row: HBoxContainer = $SettingsOptions/MasterRow
@onready var ambient_row: HBoxContainer = $SettingsOptions/AmbientIndent/AmbientRow
@onready var sfx_row: HBoxContainer = $SettingsOptions/SfxIndent/SfxRow
@onready var quit_button: Button = $SettingsOptions/QuitMargin/QuitButton


func _ready() -> void:
	language_select.item_selected.connect(_on_language_selected)
	_setup_volume_row(master_row, &"Master")
	_setup_volume_row(ambient_row, &"Ambient")
	_setup_volume_row(sfx_row, &"SFX")
	quit_button.pressed.connect(_on_quit_pressed)


func set_language_selection(locale: String) -> void:
	var index := LANGUAGE_CODES.find(locale)
	language_select.select(index if index >= 0 else 0)


func _on_language_selected(index: int) -> void:
	# 当前仅记忆选项；实际界面翻译后续接入。
	if index >= 0 and index < LANGUAGE_CODES.size():
		language_selected.emit(LANGUAGE_CODES[index])


func _setup_volume_row(row: HBoxContainer, bus_name: StringName) -> void:
	var slider: HSlider = row.get_node("Slider")
	var value_label: Label = row.get_node("Value")
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		slider.editable = false
		value_label.text = "—"
		push_warning("设置页找不到音频总线：%s" % bus_name)
		return

	var volume := db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0
	if AudioServer.is_bus_mute(bus_index):
		volume = 0.0
	slider.set_value_no_signal(clampf(volume, slider.min_value, slider.max_value))
	value_label.text = "%d%%" % roundi(slider.value)
	slider.value_changed.connect(_on_volume_changed.bind(bus_name, value_label))


func _on_volume_changed(value: float, bus_name: StringName, value_label: Label) -> void:
	value_label.text = "%d%%" % roundi(value)
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	# 在总线上调节，保留播放器原有的环境音交叉淡变；零值使用静音避免 log(0)。
	AudioServer.set_bus_mute(bus_index, is_zero_approx(value))
	if value > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value / 100.0))
	settings_changed.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
