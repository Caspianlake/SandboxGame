shader_type spatial;

uniform sampler2DArray texture_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2DArray texture_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2DArray texture_orm    : hint_default_white, repeat_enable, filter_linear_mipmap;

uniform sampler2D material_tint_lut : source_color, filter_nearest;
uniform sampler2D material_base_id_lut : filter_nearest;

uniform float lut_size = 512.0;

uniform float triplanar_scale = 1.0;
uniform float triplanar_sharpness = 4.0;

uniform bool use_override_tint = false;
uniform vec3 override_tint : source_color = vec3(1.0);

uniform bool use_override_base_id = false;
uniform float override_base_id = 0.0;

varying vec3 v_vertex;
varying vec3 v_normal;

varying flat uint v_material_id;

void vertex() {
    vec3 world_scale = vec3(
        length(MODEL_MATRIX[0].xyz),
        length(MODEL_MATRIX[1].xyz),
        length(MODEL_MATRIX[2].xyz)
    );

    v_vertex = VERTEX * world_scale;
    v_normal = normalize(NORMAL);
    
    // Decode the integer MaterialID from RGB
    uint r = uint(round(COLOR.r * 255.0));
    uint g = uint(round(COLOR.g * 255.0));
    uint b = uint(round(COLOR.b * 255.0));
    
    v_material_id = r | (g << uint(8)) | (b << uint(16));
}

vec3 blend_rnm(vec3 base_normal, vec3 detail_normal) {
    vec3 t = base_normal + vec3(0.0, 0.0, 1.0);
    vec3 u = detail_normal * vec3(-1.0, -1.0, 1.0);
    return normalize(t * dot(t, u) - u * t.z);
}

void fragment() {
    float id_f = float(v_material_id);
    float pixel_x = mod(id_f, lut_size);
    float pixel_y = floor(id_f / lut_size);
    
    vec2 lut_uv = vec2(pixel_x + 0.5, pixel_y + 0.5) / lut_size;
    
    vec3 tint = texture(material_tint_lut, lut_uv).rgb;
    vec2 base_id_data = texture(material_base_id_lut, lut_uv).rg;
    
    float base_mat_id = round(base_id_data.r * 255.0) + (round(base_id_data.g * 255.0) * 256.0);
    
    if (use_override_tint) {
        tint = override_tint;
    }
    if (use_override_base_id) {
        base_mat_id = override_base_id;
    }
    
    vec3 triplanar_normal = normalize(v_normal);
    vec3 axis_sign = sign(triplanar_normal);

    vec3 blend = abs(triplanar_normal);
    blend = pow(blend, vec3(triplanar_sharpness));
    blend /= dot(blend, vec3(1.0)); 

    vec2 uv_x = vec2(-v_vertex.z * axis_sign.x, v_vertex.y) * triplanar_scale;
    vec2 uv_y = vec2(-v_vertex.x * axis_sign.y, v_vertex.z) * triplanar_scale;
    vec2 uv_z = vec2( v_vertex.x * axis_sign.z, v_vertex.y) * triplanar_scale;
    
    vec3 albedo_x = texture(texture_albedo, vec3(uv_x, base_mat_id)).rgb;
    vec3 albedo_y = texture(texture_albedo, vec3(uv_y, base_mat_id)).rgb;
    vec3 albedo_z = texture(texture_albedo, vec3(uv_z, base_mat_id)).rgb;
    vec3 albedo_final = (albedo_x * blend.x + albedo_y * blend.y + albedo_z * blend.z) * tint;
    
    vec3 orm_x = texture(texture_orm, vec3(uv_x, base_mat_id)).rgb;
    vec3 orm_y = texture(texture_orm, vec3(uv_y, base_mat_id)).rgb;
    vec3 orm_z = texture(texture_orm, vec3(uv_z, base_mat_id)).rgb;
    vec3 orm_final = orm_x * blend.x + orm_y * blend.y + orm_z * blend.z;
    
    vec3 normal_x = normalize(texture(texture_normal, vec3(uv_x, base_mat_id)).rgb * 2.0 - 1.0);
    vec3 normal_y = normalize(texture(texture_normal, vec3(uv_y, base_mat_id)).rgb * 2.0 - 1.0);
    vec3 normal_z = normalize(texture(texture_normal, vec3(uv_z, base_mat_id)).rgb * 2.0 - 1.0);

    vec3 base_normal_x = vec3(
        -triplanar_normal.z * axis_sign.x,
        triplanar_normal.y,
        triplanar_normal.x * axis_sign.x
    );
    vec3 base_normal_y = vec3(
        -triplanar_normal.x * axis_sign.y,
        triplanar_normal.z,
        triplanar_normal.y * axis_sign.y
    );
    vec3 base_normal_z = vec3(
        triplanar_normal.x * axis_sign.z,
        triplanar_normal.y,
        triplanar_normal.z * axis_sign.z
    );

    normal_x = blend_rnm(base_normal_x, normal_x);
    normal_y = blend_rnm(base_normal_y, normal_y);
    normal_z = blend_rnm(base_normal_z, normal_z);
    
    vec3 normal_x_ws = vec3(
        normal_x.z * axis_sign.x,
        normal_x.y,
        -normal_x.x * axis_sign.x
    );
    vec3 normal_y_ws = vec3(
        -normal_y.x * axis_sign.y,
        normal_y.z * axis_sign.y,
        normal_y.y
    );
    vec3 normal_z_ws = vec3(
        normal_z.x * axis_sign.z,
        normal_z.y,
        normal_z.z * axis_sign.z
    );
    
    vec3 normal_final = normalize(normal_x_ws * blend.x + normal_y_ws * blend.y + normal_z_ws * blend.z);

    mat3 model_rotation = mat3(
        normalize(MODEL_MATRIX[0].xyz),
        normalize(MODEL_MATRIX[1].xyz),
        normalize(MODEL_MATRIX[2].xyz)
    );
    vec3 normal_world = model_rotation * normal_final;
    vec3 normal_view = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);

    ALBEDO = albedo_final;
    NORMAL = normal_view;
    AO = orm_final.r;
    ROUGHNESS = orm_final.g;
    METALLIC = orm_final.b;
}
