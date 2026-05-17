extends Node2D

class_name ManualParallax


@export var scroll_speed: Vector2 = Vector2.ZERO


@export var spawn_cooldown_0: float = 1.0
@export var spawn_position_0: Vector2 = Vector2.ZERO
@export var spawn_scale_0: Vector2 = Vector2.ONE
@export var textures_0: Array[Texture2D] = []
@export var color_0: Color = Color(1, 1, 1, 1)
@export_range(0.0, 1.0, 0.01) var spawn_randomness_0: float = 0.1


@export var spawn_cooldown: float = 1.0
@export var spawn_position: Vector2 = Vector2.ZERO
@export var spawn_scale: Vector2 = Vector2.ONE
@export var textures: Array[Texture2D] = []
@export var color: Color = Color(1, 1, 1, 1)
@export_range(0.0, 1.0, 0.01) var spawn_randomness: float = 0.1

@export var texture_0_sub: Array[Texture2D] = []
@export var spawn_position_0_sub: Vector2 = Vector2.ZERO
@export var spawn_scale_0_sub: Vector2 = Vector2.ONE
@export var texture_sub: Array[Texture2D] = []
@export var spawn_position_sub: Vector2 = Vector2.ZERO
@export var spawn_scale_sub: Vector2 = Vector2.ONE
@export var weight_sub: float = 0.0 # 0-1之间，表示子贴图在随机选择时的权重，0表示不使用子贴图，1表示只使用子贴图


var _objects_0: Array[Sprite2D] = []
var _objects: Array[Sprite2D] = []
var _is_scrolling: bool = true
var _spawn_timer: Timer


#非Parallex2D 手动滚动program开始运行（生成随机texture，移动，到尽头自动释放，间隔时长后重复）
# 目录
# 1.外部调用func
#  1.1 开始滚动
#  1.2 停止滚动
#  1.3 继续滚动
# 2.内部调用func
#  2.0 queue_free所有子节点
#  2.1 初始化计时器
#  2.2 生成随机texture
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


	_spawn_texture(textures_0)
	_spawn_texture(textures)
	
	_spawn_timer.start()
	_is_scrolling = true

func stop_manual_scroll() -> void:
	_is_scrolling = false
	_spawn_timer.stop()

func resume_manual_scroll() -> void:
	if not _is_scrolling:
		_spawn_timer.start()
		_is_scrolling = true



func _free_all_children() -> void:
	for child in get_children():
		# if child is Sprite2D:
		child.queue_free()
	_objects.clear()
	_objects_0.clear()

func _free_all_timer() -> void:
	for timer in get_children():
		if timer is Timer:
			timer.stop()
			timer.queue_free()

func _free_distant_children(distance_modulus: float) -> void:
	for child in get_children():
		if child is Sprite2D:
			if child in _objects:
				if child.position.x > distance_modulus * spawn_position.x:
					_objects.erase(child)
					child.queue_free()
			elif child in _objects_0:
				if child.position.x > distance_modulus * spawn_position_0.x:
					_objects_0.erase(child)
					child.queue_free()

func _initialize_timer() -> void:
	# 初始化计时器
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = spawn_cooldown
	_spawn_timer.one_shot = false
	_spawn_timer.autostart = false
	add_child(_spawn_timer)
	_spawn_timer.connect("timeout", Callable(self, "_on_spawn_timer_timeout"))

func _generate_random_texture(texture_pool: Array[Texture2D]) -> Texture2D:
	# 从 _textures 中随机选择一个texture
	if texture_pool.size() == 0:
		return null
	var index = randi() % texture_pool.size()
	return texture_pool[index]

func _spawn_texture(texture_pool: Array[Texture2D]) -> void:
	
	if texture_pool == textures_0 or texture_pool == texture_0_sub:
			if randi() % 4 == 0:
				return # _0 25%概率不生成，增加随机性


	# 生成随机texture并spawn在场景右侧
	var texture = _generate_random_texture(texture_pool)
	if texture == null:
		return
	var sprite = Sprite2D.new()
	sprite.texture = texture
	match texture_pool:
		textures_0:
			sprite.modulate = color_0
			sprite.scale = spawn_scale_0
			sprite.position = spawn_position_0
			_objects_0.append(sprite)
		texture_0_sub:
			sprite.modulate = color_0
			sprite.scale = spawn_scale_0_sub
			sprite.position = spawn_position_0_sub
			_objects_0.append(sprite)
		textures:
			sprite.modulate = color
			sprite.scale = spawn_scale
			sprite.position = spawn_position
			_objects.append(sprite)
		texture_sub:
			sprite.modulate = color
			sprite.scale = spawn_scale_sub
			sprite.position = spawn_position_sub
			_objects.append(sprite)
	add_child(sprite)


func _process(delta: float) -> void:
	# 移动所有子节点
	_move_textures(delta)

func _move_textures(delta: float) -> void:
	# 移动所有子节点
	if _is_scrolling:
		for object in _objects:
			_move_and_release(object, delta, _objects)
		for object in _objects_0:
			_move_and_release(object, delta, _objects_0)

func _move_and_release(object: Sprite2D, delta: float, object_list: Array[Sprite2D]) -> void:
	object.position += scroll_speed * delta
	# 如果从场景左侧出去，自动释放
	if object.position.x < -4000:
		object_list.erase(object)
		object.queue_free()


func _on_spawn_timer_timeout() -> void:

	if randf() < weight_sub:
		_spawn_texture(texture_0_sub)
		_spawn_texture(texture_sub)
		# print(str(self.name) + ": spawn sub texture")
	else:
		_spawn_texture(textures_0)
		_spawn_texture(textures)