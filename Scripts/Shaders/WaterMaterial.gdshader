shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// === ТЕКСТУРЫ ===
uniform sampler2D normal_map : source_color;      // анимированная normal map (рябь)
uniform sampler2D flow_map : source_color;         // направление течения (R=X, G=Y)
uniform sampler2D base_texture : source_color;     // мусор, тина, пена (альфа = отражение)
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture;

// === ПАРАМЕТРЫ ===
uniform vec3 water_color : source_color = vec3(0.1, 0.3, 0.4);
uniform vec3 deep_color : source_color = vec3(0.0, 0.05, 0.1);
uniform float fog_start = 0.5;
uniform float fog_end = 10.0;
uniform float wave_speed = 0.3;
uniform float wave_strength = 0.05;
uniform float flow_strength = 0.5;
uniform float refraction_strength = 0.05;
uniform float reflectivity = 0.6;
uniform float roughness_val = 0.05;

// === ВЕРШИННЫЕ ВОЛНЫ ===
void vertex() {
    vec2 uv_flow = UV + TIME * wave_speed * 0.1;
    float wave = sin(UV.x * 20.0 + TIME * 2.0) * cos(UV.y * 15.0 + TIME * 1.5);
    VERTEX.y += wave * wave_strength;
}

// === ФРАГМЕНТ ===
void fragment() {
    // --- Flow map (течение как в Source 2) ---
    vec2 flow_dir = texture(flow_map, UV).rg * 2.0 - 1.0;
    vec2 uv1 = UV + flow_dir * flow_strength * TIME * 0.05;
    vec2 uv2 = UV + flow_dir * flow_strength * (TIME * 0.05 + 0.5);

    // --- Анимированная normal map ---
    vec3 n1 = texture(normal_map, uv1).rgb;
    vec3 n2 = texture(normal_map, uv2).rgb;
    vec3 blended_normal = normalize(n1 + n2 - vec3(1.0));
    NORMAL_MAP = blended_normal;
    NORMAL_MAP_DEPTH = 1.0;

    // --- Преломление (refraction) ---
    vec2 refraction_offset = blended_normal.xy * refraction_strength;
    vec3 refracted = texture(screen_texture, SCREEN_UV + refraction_offset).rgb;

    // --- Глубина (fog под водой) ---
    float depth = texture(depth_texture, SCREEN_UV).r;
    vec4 world_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
    world_pos.xyz /= world_pos.w;
    float water_depth = VERTEX.z - world_pos.z; // приблизительная глубина
    float fog_factor = clamp((water_depth - fog_start) / (fog_end - fog_start), 0.0, 1.0);

    // --- Цвет воды с туманом ---
    vec3 final_color = mix(water_color, deep_color, fog_factor);
    final_color = mix(refracted, final_color, fog_factor * 0.8);

    // --- Base texture (мусор/тина) ---
    vec4 base = texture(base_texture, uv1);
    final_color = mix(final_color, base.rgb, base.a * 0.5);

    // --- Отражение (через ReflectionProbe или env) ---
    // В Godot 4 ReflectionProbe подхватывается автоматически,
    // если roughness низкий. Можно усилить через fresnel:
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    float reflect_amount = mix(reflectivity, 1.0, fresnel);

    ALBEDO = final_color;
    ROUGHNESS = roughness_val;
    METALLIC = 0.0;
    ALPHA = 0.85 + reflect_amount * 0.15;
}