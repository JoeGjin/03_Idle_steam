extends Control

@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var grid_container : GridContainer = $ScrollContainer/GridContainer
@onready var collected_items_scene: PackedScene = preload("res://scenes/CollectedItem.tscn")




#region old_code
# var _world_items: Dictionary[int, Array] = {} # world_id -> Control
# var _texture_cache: Array[Texture2D] = [] # 预加载的世界贴图缓存

# func _ready() -> void:
# 	_load_world_background_and_items(0)



# func _load_world_background_and_items(world_id: int) -> void:
# 	# 先不上背景颜色
# 	# _update_letter_background(world_id)
# 	_add_world_item(world_id)



# func _add_world_item(world_id: int) -> void:

# 	if not _world_items.has(world_id):
# 		_texture_cache = _load_world_textures(world_id) # 预加载世界资源，确保随机贴图时有资源可用
# 		_world_items[world_id] = []
# 		for texture in _texture_cache:
# 			var new_item = collected_items_scene.instantiate()
# 			# new_item.work_board = work_board
# 			new_item.get_node("TextureRect").texture = texture
# 			_world_items[world_id].append(new_item)
# 		_texture_cache.clear() # 资源已实例化，清空缓存
	
# 	for child in grid_container.get_children():
# 		grid_container.remove_child(child) # 清空当前显示的物品
	
# 	# 已经存在该世界的物品，直接添加到界面
# 	for item in _world_items[world_id]:
# 		grid_container.add_child(item)



# func _load_world_textures(world_id: int) -> Array[Texture2D]:
# 	var textures: Array[Texture2D] = []
# 	var path := "res://assets/worldroot/world/%d" % world_id
# 	var dir := DirAccess.open(path)
# 	if dir == null:
# 		push_error("无法打开世界资源目录: %s" % path)
# 		return textures
# 	dir.list_dir_begin()
# 	while true:
# 		var file_name := dir.get_next()
# 		if file_name == "":
# 			break

# 		if dir.current_is_dir():
# 			continue

# 		if file_name.get_extension().to_lower() != "png":
# 			continue

# 		var file_path := path.path_join(file_name)
# 		var texture := load(file_path)
		
# 		if texture != null:
# 			textures.append(texture)
# 		else:
# 			push_warning("Failed to load texture: " + file_path)
# 	dir.list_dir_end()
# 	return textures

#endregion