# 世界环境定义资源

extends Resource
class_name WorldDef

@export var id: int = 0
@export var name: String = "xxxxx"

@export var sky_texture: Texture2D
@export var sky_repeat_size: Vector2 = Vector2.ZERO
@export var sky_scroll_speed: Vector2 = Vector2.ZERO

@export var cloud_texture: Texture2D
@export var cloud_repeat_size: Vector2 = Vector2.ZERO
@export var cloud_scroll_speed: Vector2 = Vector2.ZERO

@export var background_texture: Texture2D
@export var background_repeat_size: Vector2 = Vector2.ZERO
@export var background_scroll_speed: Vector2 = Vector2.ZERO

@export var midground_texture: Texture2D
@export var midground_repeat_size: Vector2 = Vector2.ZERO
@export var midground_scroll_speed: Vector2 = Vector2.ZERO

@export var foreground_texture: Texture2D
@export var foreground_repeat_size: Vector2 = Vector2.ZERO
@export var foreground_scroll_speed: Vector2 = Vector2.ZERO


