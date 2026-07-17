# 氛围环境定义资源

extends Resource
class_name TagSceneDef


@export var tag_name: Tags.Tag

@export var ambient_audio: AudioStream = null

@export var sky_main_color: Color = Color(0.318, 0.353, 0.612, 1) 
@export var sky_star_texture: Texture2D
@export var sky_effect_texture: Texture2D

@export var poi_color: Color = Color(1, 1, 1, 1)
@export var poi_scroll_speed: Vector2 = Vector2(-10, 0)

@export var ground_main_color: Color = Color(0.318, 0.353, 0.612, 1) 
@export var ground_effect_texture: Texture2D

@export var cloud_color: Color = Color(1, 1, 1, 1)
@export var cloud_scroll_speed: Vector2 = Vector2(-20, 0)
@export var cloud_speed_ratio: float = 1.5 # 从远到近速度的乘数

@export var landform_color: Color = Color(1, 1, 1, 1)
@export var landform_scroll_speed: Vector2 = Vector2(-40, 0)
@export var landform_speed_ratio: float = 2.0 # 从远到近速度的乘数

@export var component_color: Color = Color(1, 1, 1, 1)
@export var component_scroll_speed: Vector2 = Vector2(-60, 0)
@export var component_speed_ratio: float = 2.5 # 从远到近速度的乘数
