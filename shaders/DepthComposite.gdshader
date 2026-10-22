shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    // RGB 保留预乘颜色和 HDR 亮度；覆盖度限制在有效范围，避免反向混合后方内容。
    COLOR = vec4(col.rgb, clamp(col.a, 0.0, 1.0));
}
