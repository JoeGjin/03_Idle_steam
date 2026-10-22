shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

varying vec4 modulate_color;

void vertex() {
    modulate_color = COLOR;
}

void fragment() {
    vec4 effect = texture(TEXTURE, UV) * modulate_color;
    // RGB 保留原加法混合的贡献；输出 Alpha 为 0，让预乘混合保留目标 Alpha。
    // 天空叠加效果因此不会将 HDR 视口的覆盖度从 1 累加到 2。
    COLOR = vec4(effect.rgb * effect.a, 0.0);
}
