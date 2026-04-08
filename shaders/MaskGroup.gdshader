shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// 新增：遮罩总开关：0=不遮盖，1=正常遮盖（也可用 0~1 做渐变）
uniform float mask_enable : hint_range(0.0, 1.0, 0.01) = 1.0;

// --- center_uv 拆成两个 float（0..1） ---
uniform float center_u : hint_range(0.0, 1.0, 0.001) = 0.5;
uniform float center_v : hint_range(0.0, 1.0, 0.001) = 0.5;

// --- radius_uv 拆成两个 float（0..1） ---
uniform float radius_u : hint_range(0.0, 1.0, 0.001) = 0.5;
uniform float radius_v : hint_range(0.0, 1.0, 0.001) = 0.5;

// 基础羽化（像素）
uniform float feather_px : hint_range(0.0, 50.0, 0.1) = 2.0;

// 烟雾开关：0=关，1=开（也可用 0~1 当强度）
uniform float smoke_enable : hint_range(0.0, 1.0, 0.01) = 1.0;

// 烟雾效果参数（范围已翻倍）
uniform float smoke_band_px : hint_range(0.0, 240.0, 0.1) = 18.0;
uniform float smoke_amp_px  : hint_range(0.0, 120.0, 0.1) = 8.0;
uniform float smoke_scale   : hint_range(1.0, 80.0, 0.1)  = 20.0;

// --- smoke_speed 拆成两个 float（给一个更好用的范围） ---
uniform float smoke_speed_x : hint_range(-2.0, 2.0, 0.001) = 0.12;
uniform float smoke_speed_y : hint_range(-2.0, 2.0, 0.001) = -0.08;


// --- 简单2D value noise（不用贴图） ---
float hash12(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    float a = hash12(i + vec2(0.0, 0.0));
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int k = 0; k < 4; k++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec4 col = texture(screen_texture, SCREEN_UV);

    vec2 center_uv = vec2(center_u, center_v);
    vec2 radius_uv = vec2(max(radius_u, 0.0001), max(radius_v, 0.0001)); // 防止除0
    vec2 smoke_speed = vec2(smoke_speed_x, smoke_speed_y);

    // 椭圆归一化距离（d=1边界）
    vec2 p = (SCREEN_UV - center_uv) / radius_uv;
    float d = sqrt(dot(p, p));

    float px_to_uv = max(SCREEN_PIXEL_SIZE.x, SCREEN_PIXEL_SIZE.y);
    float feather_uv = feather_px * px_to_uv;

    float jitter = 0.0;
    if (smoke_enable > 0.0) {
        float band_uv = smoke_band_px * px_to_uv;

        float edge_w = 1.0 - smoothstep(0.0, band_uv, abs(d - 1.0));

        vec2 n_uv = SCREEN_UV * smoke_scale + TIME * smoke_speed;
        float n = fbm(n_uv);
        n = n * 2.0 - 1.0;

        float amp_uv = smoke_amp_px * px_to_uv;
        jitter = n * amp_uv * edge_w * smoke_enable;
    }

    float mask = 1.0 - smoothstep(1.0 + jitter, 1.0 + feather_uv + jitter, d);

    //：mask_enable=0 => mask=1（不遮盖）；mask_enable=1 => 原 mask
    mask = mix(1.0, mask, clamp(mask_enable, 0.0, 1.0));

    COLOR = vec4(col.rgb, col.a * mask);
}