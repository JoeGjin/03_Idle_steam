extends Control

@onready var content_grid: GridContainer = %Content/ScrollContainer/GridContainer
@onready var collected_items_scene: PackedScene = preload("res://scenes/CollectedItem.tscn")



func _ready() -> void:
	visible = Debug.enabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_add_random_item_pressed() -> void:
	pass