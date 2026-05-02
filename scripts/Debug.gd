extends Node


# enum Mode {
# 	PET
# }

var enabled: bool = true


func _ready():
	if enabled:
		print("[DEBUG] Debug mode is ON")
	else:
		print("[DEBUG] Debug mode is OFF")
