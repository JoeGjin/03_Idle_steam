extends Control


@export var resize_button: Button 


func free_all_children():
	reset_resize_button()
	for child in get_children():
		child.queue_free()


func reset_resize_button():
	if resize_button.get_parent() != null:
		resize_button.get_parent().remove_child(resize_button)


func update_resize_button():
	var item_on_top = get_child(get_child_count() - 1)
	if item_on_top != null:
		if resize_button.get_parent() != null:
			resize_button.reparent(item_on_top)
		else:
			item_on_top.add_child(resize_button)
		resize_button.target = item_on_top
		resize_button.global_position = item_on_top.global_position + item_on_top.size * item_on_top.scale
		resize_button.show()
