extends Control

@export var wait_before_fade := 1.0
@export var fade_duration := 0.5

var _fade_tween: Tween


func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

    modulate.a = 1.0
    visible = true


func _on_mouse_entered() -> void:
    # print("[FloatButtons] Mouse entered")
    _kill_fade_tween()

    visible = true
    modulate.a = 1.0


func _on_mouse_exited() -> void:
    # print("[FloatButtons] Mouse exited")
    _kill_fade_tween()

    _fade_tween = create_tween()
    _fade_tween.tween_interval(wait_before_fade)
    _fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration)


func _kill_fade_tween() -> void:
    if _fade_tween and _fade_tween.is_valid():
        _fade_tween.kill()