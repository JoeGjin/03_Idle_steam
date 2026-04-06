# 世界组装器，负责将世界环境定义资源转换为实际的场景节点

extends Node

class_name WorldAssembler


@export var world_root: Node2D
@export var world_defs: Array[WorldDef] = []
@export var current_world_id: int = 0

var _sky: Parallax2D
var _moon: Parallax2D
var _far_1: Node2D
var _far_2: Node2D
var _land: Parallax2D
var _sea: Parallax2D
var _mid_1: Node2D
var _mid_2: Node2D
var _front_1: Node2D
var _front_2: Node2D
var _light: Parallax2D

var _world_player: AnimationPlayer


signal world_changed(new_world_id: int)




func initiate() -> void:
	_sky = world_root.get_node("%Sky")
	_moon = world_root.get_node("%Moon")
	_far_1 = world_root.get_node("%Far_1")
	_far_2 = world_root.get_node("%Far_2")
	_sea = world_root.get_node("%Sea")
	_mid_1 = world_root.get_node("%Mid_1")
	_mid_2 = world_root.get_node("%Mid_2")
	_land = world_root.get_node("%Land")
	_front_1 = world_root.get_node("%Front_1")
	_front_2 = world_root.get_node("%Front_2")
	_light = world_root.get_node("%Light")
	_world_player = world_root.get_node("%WorldPlayer")



func assemble_world(world_id: int) -> void:
	# _world_player.stop() # 切换世界时先停止动画
	
	var target_world = world_defs[world_id]
	
	# 1. load所有texture和texture array到对应的节点上，设置好repeat_size、autoscroll等参数(Parallex2D 滚动)
	#   1.1 func defs_to_scene
	# 2. 非Parallex2D 手动滚动program开始运行（生成随机texture，移动，到尽头自动释放，间隔时长后重复）
	#   2.1 func start_manual_scroll (非Parallex2D节点相同script调用各自参数)
	# 3. 播放world player动画（如果有的话）
	#   3.1 func play_world_animation (world player根据world def切换


# func _transition_to_world(new_world_id: int) -> void:
	# 1. target_world = world_defs[new_world_id]
	# 2. 非Parallex2D节点texture开始渐变
	# 3. Parallex2D节点颜色开始渐变
	# 4. moon开始移出场景，新的moon移入（moon完成及transition完成）
