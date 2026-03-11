extends Node2D


@export var debug_mode: bool = false

@onready var debug_status: Label = $DebugStatus
@onready var debug_cooldown: Label = $DebugCooldown


func _ready() -> void:
	set_process(debug_mode)
	visible = debug_mode


func _process(_delta: float) -> void:
	var status: String = CharacterStates.CharacterState.find_key(%CharacterStatus.state)
	debug_status.text = "Status: " + status
	var phase: String = CharacterStatus.Phase.find_key(%CharacterStatus._phase)
	var timer: Timer = %CharacterStatus._phase_timer
	var cooldown: String = "%.2f" % timer.time_left
	debug_cooldown.text = phase + ": " + cooldown
