// UniversalMaterial.gdshader
shader_type spatial;

uniform sampler2DArray texture_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2DArray texture_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2DArray texture_orm    : hint_default_white, repeat_enable, filter_linear_mipmap;

// Dual 512x512 Lookup Tables
uniform sampler2D material_tint_lut : source_color, filter_nearest;
uniform sampler2D material_base_id_lut : filter_nearest;

uniform float lut_size = 512.0;

uniform float triplanar_scale = 1.0;
uniform float triplanar_sharpness = 4.0;

// Overrides
uniform bool use_override_tint = false;
uniform vec3 override_tint : source_color = vec3(1.0);

uniform bool use_override_base_id = false;
uniform float override_base_id = 0.0;

varying vec3 v_vertex;
varying vec3 v_normal;

// Flat prevents hardware interpolation of integer bits
flat varying uint v_material_id; 

void vertex() {
    v_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
    
    // Decode the integer MaterialID from RGB
    uint r = uint(round(COLOR.r * 255.0));
    uint g = uint(round(COLOR.g * 255.0));
    uint b = uint(round(COLOR.b * 255.0));
    
    v_material_id = r | (g << 8) | (b << 16);
}

void fragment() {
    // 1. Convert 1D Material ID to 2D UV coordinates for the 512x512 LUT
    float id_f = float(v_material_id);
    float pixel_x = mod(id_f, lut_size);
    float pixel_y = floor(id_f / lut_size);
    
    // Add 0.5 to sample the exact center of the texel
    vec2 lut_uv = vec2(pixel_x + 0.5, pixel_y + 0.5) / lut_size;
    
    // 2. Retrieve Data from LUTs
    vec3 tint = texture(material_tint_lut, lut_uv).rgb;
    vec2 base_id_data = texture(material_base_id_lut, lut_uv).rg;
    
    // Decode BaseMaterial ID from RG8 (R = low byte, G = high byte)
    float base_mat_id = round(base_id_data.r * 255.0) + (round(base_id_data.g * 255.0) * 256.0);
    
    // 3. Apply Overrides
    if (use_override_tint) {
        tint = override_tint;
    }
    if (use_override_base_id) {
        base_mat_id = override_base_id;
    }
    
    // 4. Triplanar Blending Weights
    vec3 blend = abs(v_normal);
    blend = pow(blend, vec3(triplanar_sharpness));
    blend /= dot(blend, vec3(1.0)); // Normalize
    
    // 5. Triplanar UV Coordinates
    vec2 uv_x = v_vertex.zy * triplanar_scale;
    vec2 uv_y = v_vertex.xz * triplanar_scale;
    vec2 uv_z = v_vertex.xy * triplanar_scale;
    
    // 6. Sample Albedo
    vec3 albedo_x = texture(texture_albedo, vec3(uv_x, base_mat_id)).rgb;
    vec3 albedo_y = texture(texture_albedo, vec3(uv_y, base_mat_id)).rgb;
    vec3 albedo_z = texture(texture_albedo, vec3(uv_z, base_mat_id)).rgb;
    vec3 albedo_final = (albedo_x * blend.x + albedo_y * blend.y + albedo_z * blend.z) * tint;
    
    // 7. Sample ORM (Occlusion, Roughness, Metallic)
    vec3 orm_x = texture(texture_orm, vec3(uv_x, base_mat_id)).rgb;
    vec3 orm_y = texture(texture_orm, vec3(uv_y, base_mat_id)).rgb;
    vec3 orm_z = texture(texture_orm, vec3(uv_z, base_mat_id)).rgb;
    vec3 orm_final = orm_x * blend.x + orm_y * blend.y + orm_z * blend.z;
    
    // 8. Sample Normal
    vec3 normal_x = texture(texture_normal, vec3(uv_x, base_mat_id)).rgb * 2.0 - 1.0;
    vec3 normal_y = texture(texture_normal, vec3(uv_y, base_mat_id)).rgb * 2.0 - 1.0;
    vec3 normal_z = texture(texture_normal, vec3(uv_z, base_mat_id)).rgb * 2.0 - 1.0;
    
    // Triplanar normal mapping adjustments
    normal_x = vec3(normal_x.xy + v_normal.zy, normal_x.z);
    normal_y = vec3(normal_y.xy + v_normal.xz, normal_y.z);
    normal_z = vec3(normal_z.xy + v_normal.xy, normal_z.z);
    vec3 normal_final = normalize(normal_x * blend.x + normal_y * blend.y + normal_z * blend.z);

    // 9. Output Assignment
    ALBEDO = albedo_final;
    NORMAL = normal_final;
    AO = orm_final.r;
    ROUGHNESS = orm_final.g;
    METALLIC = orm_final.b;
}