shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform float lod : hint_range(0.0, 5.0, 0.1) = 1.5;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
    // 分组视口中的颜色已预乘 Alpha；一起滤波并替换原图，避免残留清晰轮廓。
    COLOR = textureLod(screen_texture, SCREEN_UV, lod);
}
