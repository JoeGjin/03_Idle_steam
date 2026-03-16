extends Control




func free_all_children():
    for child in get_children():
        child.queue_free()