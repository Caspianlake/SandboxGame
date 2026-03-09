shader_type spatial;

// 3-Texture Array System
uniform sampler2DArray texture_albedo : source_color; // RGB: Albedo
uniform sampler2DArray texture_normal : hint_normal;   // RGB: Normal (BC5 optimized)
uniform sampler2DArray texture_orm    : hint_default_white; // R: AO, G: Roughness, B: Metallic

uniform float sharpness : hint_range(0.0, 50.0) = 10.0;
uniform float uv_scale = 0.5;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_mat_data; // R: ID1, G: ID2, B: Blend, A: Vertex AO

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_world_normal = abs(NORMAL); 
    v_mat_data = COLOR; 
}

// Helper for RGB Triplanar (Albedo or ORM)
vec3 sample_triplanar_rgb(sampler2DArray tex, vec3 pos, vec3 weights, float id) {
    vec3 x = texture(tex, vec3(pos.zy, id)).rgb;
    vec3 y = texture(tex, vec3(pos.xz, id)).rgb;
    vec3 z = texture(tex, vec3(pos.xy, id)).rgb;
    return x * weights.x + y * weights.y + z * weights.z;
}

// Optimized Normal Triplanar for BC5
vec3 sample_triplanar_normal(sampler2DArray tex, vec3 pos, vec3 weights, vec3 flat_normal, float id) {
    // 1. Sample Raw (BC5 stores R and G)
    vec4 nX_raw = texture(tex, vec3(pos.zy, id));
    vec4 nY_raw = texture(tex, vec3(pos.xz, id));
    vec4 nZ_raw = texture(tex, vec3(pos.xy, id));

    // 2. Reconstruct Z for BC5 (z = sqrt(1 - x^2 - y^2))
    vec3 nX = vec3(nX_raw.rg * 2.0 - 1.0, 0.0);
    nX.z = sqrt(max(0.0, 1.0 - dot(nX.xy, nX.xy)));
    
    vec3 nY = vec3(nY_raw.rg * 2.0 - 1.0, 0.0);
    nY.z = sqrt(max(0.0, 1.0 - dot(nY.xy, nY.xy)));
    
    vec3 nZ = vec3(nZ_raw.rg * 2.0 - 1.0, 0.0);
    nZ.z = sqrt(max(0.0, 1.0 - dot(nZ.xy, nZ.xy)));

    // 3. Reorient to World Space
    nX = vec3(nX.xy + flat_normal.zy, nX.z * flat_normal.x);
    nY = vec3(nY.xy + flat_normal.xz, nY.z * flat_normal.y);
    nZ = vec3(nZ.xy + flat_normal.xy, nZ.z * flat_normal.z);

    return normalize(nX.zyx * weights.x + nY.xzy * weights.y + nZ.xyz * weights.z);
}

void fragment() {
    // Calculate Weights
    vec3 weights = pow(v_world_normal, vec3(sharpness));
    weights /= (weights.x + weights.y + weights.z);
    
    vec3 tri_pos = v_world_pos * uv_scale;
    vec3 world_normal_sign = sign(NORMAL); 

    // Material 1 Sampling
    vec3 alb1 = sample_triplanar_rgb(texture_albedo, tri_pos, weights, v_mat_data.r);
    vec3 orm1 = sample_triplanar_rgb(texture_orm, tri_pos, weights, v_mat_data.r);
    vec3 norm1 = sample_triplanar_normal(texture_normal, tri_pos, weights, world_normal_sign, v_mat_data.r);

    // Material 2 Sampling
    vec3 alb2 = sample_triplanar_rgb(texture_albedo, tri_pos, weights, v_mat_data.g);
    vec3 orm2 = sample_triplanar_rgb(texture_orm, tri_pos, weights, v_mat_data.g);
    vec3 norm2 = sample_triplanar_normal(texture_normal, tri_pos, weights, world_normal_sign, v_mat_data.g);

    // Interpolation (Blends between Mat 1 and Mat 2)
    vec3 final_alb = mix(alb1, alb2, v_mat_data.b);
    vec3 final_orm = mix(orm1, orm2, v_mat_data.b);
    vec3 final_norm = normalize(mix(norm1, norm2, v_mat_data.b));

    // Assignment
    ALBEDO = final_alb;
    AO = final_orm.r * v_mat_data.a; // Texture AO * Vertex AO
    ROUGHNESS = final_orm.g;
    METALLIC = final_orm.b;
    NORMAL = (VIEW_MATRIX * vec4(final_norm, 0.0)).xyz;
}