extends Node


# enum Mode {
# 	PET
# }

var enabled: bool = false
var engine_time_scale: float = 5.0


func _ready():
	if enabled:
		print("[DEBUG] Debug mode is ON")
		Engine.time_scale = engine_time_scale
	else:
		print("[DEBUG] Debug mode is OFF")
		Engine.time_scale = 1.0
