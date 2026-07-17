# 世界环境定义资源

extends Resource
class_name WorldDef


@export var id: int = 0
@export var name: String = "xxxxx"

@export var ambient_audio: AudioStream = null

@export var sky_repeat_size: Vector2 = Vector2(4542.0, 0)
@export var sky_scroll_speed: Vector2 = Vector2(-10.0, 0)
@export var sky_main_texture: Texture2D = preload("res://assets/worldroot/world/stage/x_sky_main.png")
@export var sky_main_color: Color = Color(0.318, 0.353, 0.612, 1) 
@export var sky_effect_texture: Texture2D
@export var sky_effect_color: Color = Color(1, 1, 1, 1)


@export var moon_repeat_size: Vector2 = Vector2.ZERO
@export var moon_scroll_speed: Vector2 = Vector2.ZERO
@export var moon_main_texture: Texture2D
@export var moon_main_color: Color = Color(1, 1, 1, 1)
@export var moon_effect_texture: Texture2D
@export var moon_effect_color: Color = Color(1, 1, 1, 1)


@export var far_0_textures: Array[Texture2D] = []
@export var far_0_color: Color = Color(1, 1, 1, 1)
@export var far_1_textures: Array[Texture2D] = []
@export var far_1_color: Color = Color(1, 1, 1, 1)
@export var far_2_textures: Array[Texture2D] = []
@export var far_2_color: Color = Color(1, 1, 1, 1)

@export var far_0_spawn_scale: Vector2 = Vector2.ONE 
@export var far_0_spawn_position: Vector2 = Vector2(1000,0) 
# @export var far_0_spawn_cooldown: float = 100.0 # 
@export_range(0.0, 1.0, 0.01) var far_0_spawn_randomness: float = 0.1 

@export var far_1_scroll_speed: Vector2 = Vector2(-20.0, 0)
@export var far_1_spawn_scale: Vector2 = Vector2.ONE
@export var far_1_spawn_position: Vector2 = Vector2(1000,0)
@export var far_1_spawn_cooldown: float = 100.0
@export_range(0.0, 1.0, 0.01) var far_1_spawn_randomness: float = 0.1

@export var far_2_scroll_speed: Vector2 = Vector2(-30.0, 0)
@export var far_2_spawn_scale: Vector2 = Vector2.ONE
@export var far_2_spawn_position: Vector2 = Vector2(1000,0)
@export var far_2_spawn_cooldown: float = 100.0
@export_range(0.0, 1.0, 0.01) var far_2_spawn_randomness: float = 0.1


@export var land_repeat_size: Vector2 = Vector2(4542.0, 0)
@export var land_scroll_speed: Vector2 = Vector2(-40, 0)
@export var land_main_texture: Texture2D = preload("res://assets/worldroot/world/stage/x_land_main.png")
@export var land_main_color: Color = Color(1, 1, 1, 1)
@export var land_effect_texture: Texture2D
@export var land_effect_color: Color = Color(1, 1, 1, 1)

@export var sea_repeat_size: Vector2 = Vector2(3028, 0)
@export var sea_scroll_speed: Vector2 = Vector2(-20, 0)
@export var sea_main_texture: Texture2D = preload("res://assets/worldroot/world/stage/x_sea_main.png")
@export var sea_main_color: Color = Color(1, 1, 1, 1)
@export var sea_effect_texture: Texture2D
@export var sea_effect_color: Color = Color(1, 1, 1, 1)


@export var mid_0_textures: Array[Texture2D] = []
@export var mid_0_color: Color = Color(1, 1, 1, 1)
@export var mid_1_textures: Array[Texture2D] = []
@export var mid_1_color: Color = Color(1, 1, 1, 1)
@export var mid_2_textures: Array[Texture2D] = []
@export var mid_2_color: Color = Color(1, 1, 1, 1)

@export var mid_0_spawn_scale: Vector2 = Vector2.ONE 
@export var mid_0_spawn_position: Vector2 = Vector2(1000,0) 
# @export var mid_0_spawn_cooldown: float = 100.0
@export_range(0.0, 1.0, 0.01) var mid_0_spawn_randomness: float = 0.1 

@export var mid_1_scroll_speed: Vector2 = Vector2(-50.0, 0)
@export var mid_1_spawn_scale: Vector2 = Vector2.ONE
@export var mid_1_spawn_position: Vector2 = Vector2(1200,0)
@export var mid_1_spawn_cooldown: float = 40.0
@export_range(0.0, 1.0, 0.01) var mid_1_spawn_randomness: float = 0.1

@export var mid_2_scroll_speed: Vector2 = Vector2(-60.0, 0)
@export var mid_2_spawn_scale: Vector2 = Vector2.ONE
@export var mid_2_spawn_position: Vector2 = Vector2(1200,0)
@export var mid_2_spawn_cooldown: float = 40.0
@export_range(0.0, 1.0, 0.01) var mid_2_spawn_randomness: float = 0.1


@export var front_0_textures: Array[Texture2D] = []
@export var front_0_color: Color = Color(1, 1, 1, 1)
@export var front_1_textures: Array[Texture2D] = []
@export var front_1_color: Color = Color(1, 1, 1, 1)
@export var front_2_textures: Array[Texture2D] = []
@export var front_2_color: Color = Color(1, 1, 1, 1)

@export var front_0_spawn_scale: Vector2 = Vector2.ONE
@export var front_0_spawn_position: Vector2 = Vector2(1000,0) 
# @export var front_0_spawn_cooldown: float = 100.0
@export_range(0.0, 1.0, 0.01) var front_0_spawn_randomness: float = 0.1

@export var front_1_scroll_speed: Vector2 = Vector2(-100.0, 0)
@export var front_1_spawn_scale: Vector2 = Vector2.ONE
@export var front_1_spawn_position: Vector2 = Vector2(1500,0)
@export var front_1_spawn_cooldown: float = 10.0
@export_range(0.0, 1.0, 0.01) var front_1_spawn_randomness: float = 0.1

@export var front_2_scroll_speed: Vector2 = Vector2(-130.0, 0)
@export var front_2_spawn_scale: Vector2 = Vector2.ONE
@export var front_2_spawn_position: Vector2 = Vector2(1500,0)
@export var front_2_spawn_cooldown: float = 10.0
@export_range(0.0, 1.0, 0.01) var front_2_spawn_randomness: float = 0.1


@export var light_repeat_size: Vector2 = Vector2.ZERO
@export var light_scroll_speed: Vector2 = Vector2.ZERO
@export var light_main_texture: Texture2D
@export var light_main_color: Color = Color(1, 1, 1, 1)
@export var light_effect_texture: Texture2D
@export var light_effect_color: Color = Color(1, 1, 1, 1)
