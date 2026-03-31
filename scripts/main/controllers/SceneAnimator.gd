# 负责组装好的世界进行动画控制，提供暂停和继续动画的接口

extends Node

class_name SceneAnimator

@export var world_root: Node2D
@export var world_defs: Array[WorldDef] = []
@export var current_world_id: int = 0

var _sky: Parallax2D
var _moon: Parallax2D
var _far_1: Node2D
var _far_2: Node2D
var _sea: Parallax2D
var _mid_1: Node2D
var _mid_2: Node2D
var _land: Parallax2D
var _front_1: Node2D
var _front_2: Node2D
var _light: Parallax2D

var _world_player: AnimationPlayer


func initiate() -> void:
	return
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


func setup_initial_speed():
	pass
	# _sky_speed = sky.autoscroll

func stop_para_animation() -> void:
	pass
	# sky.autoscroll = Vector2.ZERO

func continue_para_animation() -> void:
	pass
	# sky.autoscroll = _sky_speed

