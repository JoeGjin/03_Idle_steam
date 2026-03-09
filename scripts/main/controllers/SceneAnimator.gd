extends Node

class_name SceneAnimator

@export var sky : Parallax2D
@export var cloud : Parallax2D
@export var background : Parallax2D
@export var midground : Parallax2D
@export var foreground : Parallax2D
@export var transition_player: AnimationPlayer


var _background_speed: Vector2
var _midground_speed: Vector2
var _foreground_speed: Vector2
var _sky_speed: Vector2
var _cloud_speed: Vector2


func setup_initial_speed():
	_background_speed = background.autoscroll
	_midground_speed = midground.autoscroll
	_foreground_speed = foreground.autoscroll
	_sky_speed = sky.autoscroll
	_cloud_speed = cloud.autoscroll

func stop_para_animation() -> void:
	background.autoscroll = Vector2.ZERO
	midground.autoscroll = Vector2.ZERO
	foreground.autoscroll = Vector2.ZERO
	sky.autoscroll = Vector2.ZERO
	cloud.autoscroll = _cloud_speed * 0.5 # 云层减速到原来的一半，保持一定的动态感

func continue_para_animation() -> void:
	background.autoscroll = _background_speed
	midground.autoscroll = _midground_speed
	foreground.autoscroll = _foreground_speed
	sky.autoscroll = _sky_speed
	cloud.autoscroll = _cloud_speed

func play_world_transition() -> void:
	transition_player.play("Transition")