# 世界环境定义资源

extends Resource
class_name WorldDef


@export var id: int = 0
@export var name: String = "xxxxx"


@export var sky_repeat_size: Vector2 = Vector2.ZERO
@export var sky_scroll_speed: Vector2 = Vector2.ZERO
@export var sky_main_texture: Texture2D
@export var sky_main_color: Color = Color(1, 1, 1, 1)
@export var sky_effect_texture: Texture2D
@export var sky_effect_color: Color = Color(1, 1, 1, 1)


@export var moon_repeat_size: Vector2 = Vector2.ZERO
@export var moon_scroll_speed: Vector2 = Vector2.ZERO
@export var moon_main_texture: Texture2D
@export var moon_main_color: Color = Color(1, 1, 1, 1)
@export var moon_effect_texture: Texture2D
@export var moon_effect_color: Color = Color(1, 1, 1, 1)


@export var far_0_texture: Texture2D
@export var far_0_color: Color = Color(1, 1, 1, 1)

@export var far_1_scroll_speed: Vector2 = Vector2.ZERO
@export var far_1_textures: Array[Texture2D] = []
@export var far_1_colors: Color = Color(1, 1, 1, 1)
@export var far_1_spwan_scale: Vector2 = Vector2.ONE
@export var far_1_spwan_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var far_1_spwan_randomness: float = 0.1

@export var far_2_scroll_speed: Vector2 = Vector2.ZERO
@export var far_2_textures: Array[Texture2D] = []
@export var far_2_colors: Color = Color(1, 1, 1, 1)
@export var far_2_spwan_scale: Vector2 = Vector2.ONE
@export var far_2_spwan_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var far_2_spwan_randomness: float = 0.1


@export var land_repeat_size: Vector2 = Vector2.ZERO
@export var land_scroll_speed: Vector2 = Vector2.ZERO
@export var land_main_texture: Texture2D
@export var land_main_color: Color = Color(1, 1, 1, 1)
@export var land_effect_texture: Texture2D
@export var land_effect_color: Color = Color(1, 1, 1, 1)

@export var sea_repeat_size: Vector2 = Vector2.ZERO
@export var sea_scroll_speed: Vector2 = Vector2.ZERO
@export var sea_main_texture: Texture2D
@export var sea_main_color: Color = Color(1, 1, 1, 1)
@export var sea_effect_texture: Texture2D
@export var sea_effect_color: Color = Color(1, 1, 1, 1)


@export var mid_0_texture: Texture2D
@export var mid_0_color: Color = Color(1, 1, 1, 1)

@export var mid_1_scroll_speed: Vector2 = Vector2.ZERO
@export var mid_1_textures: Array[Texture2D] = []
@export var mid_1_colors: Color = Color(1, 1, 1, 1)
@export var mid_1_spwan_scale: Vector2 = Vector2.ONE
@export var mid_1_spwan_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var mid_1_spwan_randomness: float = 0.1

@export var mid_2_scroll_speed: Vector2 = Vector2.ZERO
@export var mid_2_textures: Array[Texture2D] = []
@export var mid_2_colors: Color = Color(1, 1, 1, 1)
@export var mid_2_spwan_scale: Vector2 = Vector2.ONE
@export var mid_2_spwan_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var mid_2_spwan_randomness: float = 0.1


@export var front_0_texture: Texture2D
@export var front_0_color: Color = Color(1, 1, 1, 1)

@export var front_1_scroll_speed: Vector2 = Vector2.ZERO
@export var front_1_textures: Array[Texture2D] = []
@export var front_1_colors: Color = Color(1, 1, 1, 1)
@export var front_1_spwan_scale: Vector2 = Vector2.ONE
@export var front_1_spwan_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var front_1_spwan_randomness: float = 0.1

@export var front_2_scroll_speed: Vector2 = Vector2.ZERO
@export var front_2_textures: Array[Texture2D] = []
@export var front_2_colors: Color = Color(1, 1, 1, 1)
@export var front_2_spwan_scale: Vector2 = Vector2.ONE
@export var front_2_spwan_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var front_2_spwan_randomness: float = 0.1


@export var light_repeat_size: Vector2 = Vector2.ZERO
@export var light_scroll_speed: Vector2 = Vector2.ZERO
@export var light_main_texture: Texture2D
@export var light_main_color: Color = Color(1, 1, 1, 1)
@export var light_effect_texture: Texture2D
@export var light_effect_color: Color = Color(1, 1, 1, 1)
