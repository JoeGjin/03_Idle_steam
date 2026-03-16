extends Control

@onready var content_grid: GridContainer = %Content/ScrollContainer/GridContainer
@onready var work_board: Control = %WorkBoard
@onready var letter: Control = %Letter

@onready var collected_items_scene: PackedScene = preload("res://scenes/CollectedItem.tscn")



func _ready() -> void:
	visible = Debug.enabled
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_add_random_item_pressed() -> void:
	var new_item = collected_items_scene.instantiate()
	new_item.work_board = work_board
	# new_item.letter = letter
	new_item.randomize_texture()
	content_grid.add_child(new_item)
