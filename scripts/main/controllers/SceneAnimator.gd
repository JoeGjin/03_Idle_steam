extends Node

class_name SceneAnimator

@export var sky : Parallax2D
@export var background : Parallax2D
@export var midground : Parallax2D
@export var foreground : Parallax2D


var _background_speed: Vector2
var _midground_speed: Vector2
var _foreground_speed: Vector2
var _sky_speed: Vector2


func setup_initial_speed():
	_background_speed = background.autoscroll
	_midground_speed = midground.autoscroll
	_foreground_speed = foreground.autoscroll
	_sky_speed = sky.autoscroll

func stop_para_animation() -> void:
	background.autoscroll = Vector2.ZERO
	midground.autoscroll = Vector2.ZERO
	foreground.autoscroll = Vector2.ZERO
	sky.autoscroll = Vector2.ZERO

func continue_para_animation() -> void:
	background.autoscroll = _background_speed
	midground.autoscroll = _midground_speed
	foreground.autoscroll = _foreground_speed
	sky.autoscroll = _sky_speed
