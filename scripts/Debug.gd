extends Node


# enum Mode {
# 	PET
# }

var enabled: bool = false


func _ready():
	if enabled:
		print("[DEBUG] Debug mode is ON")
	else:
		print("[DEBUG] Debug mode is OFF")
