extends Node
class_name ItemController


@onready var purple_item = preload("res://assets/worldroot/item/2.png")
@onready var green_item = preload("res://assets/worldroot/item/6.png")

@onready var item_slot: TextureRect

func pick_item(color: String) -> void:
    item_slot.texture = null # 先清空当前物品
    match color:
        "purple":
            item_slot.texture = purple_item
        "green":
            item_slot.texture = green_item