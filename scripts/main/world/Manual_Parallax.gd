extends Node2D

class_name ManualParallax


const MPARA_OBJECT_SCENE: PackedScene = preload("res://scenes/MparaObject.tscn")


@onready var world_assembler: WorldAssembler = %WorldAssembler
@onready var memory_controller : MemoryController = %MemoryController

@export var spawn_position: Vector2 = Vector2(1920 + 400,0) # 生成位置，默认在屏幕右侧400像素


var pool: MemoryDef.Pool 
var scroll_speed: Vector2 = Vector2.ZERO
var color: Color = Color(1, 1, 1, 1)

var weighted_tags: Dictionary[Tags.Tag, float]

# @export var spawn_cooldown_0: float = 1.0
# @export var spawn_position_0: Vector2 = Vector2.ZERO
# @export var spawn_scale_0: Vector2 = Vector2.ONE
# @export var textures_0: Array[Texture2D] = []
# @export var color_0: Color = Color(1, 1, 1, 1)
# @export_range(0.0, 1.0, 0.01) var spawn_randomness_0: float = 0.1



# @export var spawn_cooldown: float = 1.0
# @export var spawn_position: Vector2 = Vector2.ZERO
# @export var spawn_scale: Vector2 = Vector2.ONE
# @export var textures: Array[Texture2D] = []
# @export var color: Color = Color(1, 1, 1, 1)
# @export_range(0.0, 1.0, 0.01) var spawn_randomness: float = 0.1

# @export var texture_0_sub: Array[Texture2D] = []
# @export var spawn_position_0_sub: Vector2 = Vector2.ZERO
# @export var spawn_scale_0_sub: Vector2 = Vector2.ONE
# @export var texture_sub: Array[Texture2D] = []
# @export var spawn_position_sub: Vector2 = Vector2.ZERO
# @export var spawn_scale_sub: Vector2 = Vector2.ONE
# @export var weight_sub: float = 0.0 # 0-1之间，表示子贴图在随机选择时的权重，0表示不使用子贴图，1表示只使用子贴图


# var _objects_0: Array[Sprite2D] = []

var _objects: Array[Sprite2D] = []
var _is_scrolling: bool = true
var _spawn_timer: Timer
var _spawn_cooldown: float = 999.0


#非Parallex2D 手动滚动program开始运行（生成随机texture，移动，到尽头自动释放，间隔时长后重复）
# 目录
# 1.外部调用func
#  1.1 开始滚动
#  1.2 停止滚动
#  1.3 继续滚动
# 2.内部调用func
#  2.0 queue_free所有子节点
#  2.1 初始化计时器
#  2.2 生成随机object并spawn在场景右侧
#  2.3 移动
#  2.4 到尽头自动释放
#  2.5 间隔时长后重复




func start_manual_scroll(mode: int = 0) -> void: # mode: 0直接切换，1渐变切换
	if mode == 0:
		_free_all_children()
	elif mode == 1:
		_free_all_timer() # 先停止计时器，等现有的texture都移出场景后再释放
		_free_distant_children(0.85)

	_initialize_timer()

	var next_memory = _choose_memory()
	_spawn_object(next_memory)
	_update_spawn_timer(next_memory)
	
	_spawn_timer.start()
	_is_scrolling = true



func stop_manual_scroll() -> void:
	_is_scrolling = false
	_spawn_timer.stop()



func resume_manual_scroll() -> void:
	if not _is_scrolling:
		_spawn_timer.start()
		_is_scrolling = true



func _process(delta: float) -> void:
	# 移动所有子节点
	_move_textures(delta)



func _move_textures(delta: float) -> void:
	# 移动所有子节点
	if _is_scrolling:
		for object in _objects:
			_move_and_release(object, delta, _objects)



func _move_and_release(object: Sprite2D, delta: float, object_list: Array[Sprite2D]) -> void:
	object.position += scroll_speed * delta
	# 如果从场景左侧出去，自动释放
	if object.position.x < -4000:
		object_list.erase(object)
		object.queue_free()



func _initialize_timer() -> void:
	# 初始化计时器
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = _spawn_cooldown
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = false
	add_child(_spawn_timer)
	_spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))



func _free_all_children() -> void:
	for child in get_children():
		if child is Mpara_Object:
			child.queue_free()
	_objects.clear()
	# _objects_0.clear()



func _free_all_timer() -> void:
	for timer in get_children():
		if timer is Timer:
			timer.stop()
			timer.queue_free()



func _free_distant_children(distance_modulus: float) -> void:
	for child in get_children():
		if child is Mpara_Object:
			if child in _objects:
				if child.position.x > distance_modulus * spawn_position.x:
					_objects.erase(child)
					child.queue_free()



func _choose_memory() -> MemoryDef:
	# 根据 WorldAssembler 分配的的 weighted_tags 设定各tag素材生成的权重
	# 然后从 MemoryController 的 memories_by_tag 中选择对应的tag & pool中随机选择MemoryDef,并返还
	var available_tags: Array[Tags.Tag] = []
	var total_weight: float = 0.0

	for tag: Tags.Tag in weighted_tags:
		var weight: float = maxf(weighted_tags[tag], 0.0)
		if is_zero_approx(weight):
			continue
		if not memory_controller.memories_by_tag.has(tag):
			continue

		var memory_pools: MemoryController.MemoryPools = memory_controller.memories_by_tag[tag]
		if not memory_pools.by_pool.has(pool):
			continue

		var memory_list: MemoryController.MemoryList = memory_pools.by_pool[pool]
		if memory_list.memories.is_empty():
			continue

		available_tags.append(tag)
		total_weight += weight

	if available_tags.is_empty():
		push_warning("[MANUAL PARALLAX] 当前标签和 pool 没有可用的 MemoryDef：%s" % name)
		return null

	# 用“轮盘赌”方式，按照标签权重随机选出一个标签
	var selected_tag: Tags.Tag = available_tags.back()
	var random_weight := randf() * total_weight
	for tag: Tags.Tag in available_tags:
		random_weight -= maxf(weighted_tags[tag], 0.0)
		if random_weight <= 0.0:
			selected_tag = tag
			break

	var selected_pools: MemoryController.MemoryPools = memory_controller.memories_by_tag[selected_tag]
	var selected_list: MemoryController.MemoryList = selected_pools.by_pool[pool]
	return selected_list.memories.pick_random()



func _spawn_object(memory: MemoryDef = null) -> void:
	if memory == null:
		return
	# 根据Memory Def 生成 Mpara_Object，调用 initialize(memory) 初始化
	# spawn在 spawn_position 位置
	var object := MPARA_OBJECT_SCENE.instantiate() as Mpara_Object
	if object == null:
		push_error("[MANUAL PARALLAX] 无法实例化 MparaObject 场景")
		return

	object.initialize(memory)
	object.modulate = color
	add_child(object)
	object.position = spawn_position
	_objects.append(object)



func _update_spawn_timer(memory: MemoryDef = null) -> void:
	# 根据 memory 的 spawn_distance_ratio * texture宽度算出距离下个object的距离
	# 然后根据该ManualParallax的 scroll speed，算出下一个object spawn的 cooldown
	if memory == null or memory.texture == null:
		return

	var horizontal_speed := absf(scroll_speed.x)
	if is_zero_approx(horizontal_speed):
		push_warning("[MANUAL PARALLAX] 水平滚动速度为 0，无法计算生成间隔：%s" % name)
		return

	var spawn_distance := maxf(memory.spawn_distance_ratio, 0.0) * memory.texture.get_width()
	_spawn_cooldown = maxf(spawn_distance / horizontal_speed, 0.001)
	if is_instance_valid(_spawn_timer):
		_spawn_timer.wait_time = _spawn_cooldown




func _on_spawn_timer_timeout() -> void:
	var next_memory := _choose_memory()
	_spawn_object(next_memory)
	_update_spawn_timer(next_memory)




#region old_code

# func animation_popup(node: Sprite2D) -> void:
# 	# 在生成时播放一个简单的tween动画，scale从0变到目前的scale，持续0.5秒
# 	var tween = create_tween()
# 	var original_scale = node.scale
# 	node.scale = Vector2.ZERO
# 	tween.tween_property(node, "scale", original_scale, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# func _generate_random_texture(texture_pool: Array[Texture2D]) -> Texture2D:
# 	# 从 _textures 中随机选择一个texture
# 	if texture_pool.size() == 0:
# 		return null
# 	var index = randi() % texture_pool.size()
# 	return texture_pool[index]



# func _spawn_texture(texture_pool: Array[Texture2D]) -> void:
	
# 	if texture_pool == textures_0 or texture_pool == texture_0_sub:
# 			if randi() % 4 == 0:
# 				return # _0 25%概率不生成，增加随机性


# 	# 生成随机texture并spawn在场景右侧
# 	var texture = _generate_random_texture(texture_pool)
# 	if texture == null:
# 		return
# 	if world_assembler.texture_banned(texture.resource_path.get_file().get_basename()):
# 		print("[MANUAL PARALLAX] Texture '%s' is banned, skipping spawn" % texture.resource_path.get_file().get_basename())
# 		return

# 	var sprite = Sprite2D.new()
# 	sprite.texture = texture
# 	match texture_pool:
# 		textures_0:
# 			sprite.modulate = color_0
# 			sprite.scale = spawn_scale_0
# 			sprite.position = spawn_position_0
# 			_objects_0.append(sprite)
# 		texture_0_sub:
# 			sprite.modulate = color_0
# 			sprite.scale = spawn_scale_0_sub
# 			sprite.position = spawn_position_0_sub
# 			_objects_0.append(sprite)
# 		textures:
# 			sprite.modulate = color
# 			sprite.scale = spawn_scale
# 			sprite.position = spawn_position
# 			_objects.append(sprite)
# 		texture_sub:
# 			sprite.modulate = color
# 			sprite.scale = spawn_scale_sub
# 			sprite.position = spawn_position_sub
# 			_objects.append(sprite)
# 	add_child(sprite)

#endregion
