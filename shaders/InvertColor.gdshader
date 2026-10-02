shader_type canvas_item;

uniform float invert_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 modulate_color;

void vertex() {
    modulate_color = COLOR;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    vec3 inverted = vec3(1.0) - tex.rgb;
    // 0.0 = 原色
    // 1.0 = 完全反色
    tex.rgb = mix(tex.rgb, inverted, invert_amount);

    COLOR = tex * modulate_color;
}