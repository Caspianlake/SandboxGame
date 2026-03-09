shader_type spatial;


uniform sampler2DArray texture_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2DArray texture_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2DArray texture_orm    : hint_default_white, repeat_enable, filter_linear_mipmap;

uniform float layer_index : hint_range(0.0, 100.0, 1.0) = 0.0;
uniform float triplanar_scale : hint_range(0.0, 5.0) = 1.0;
uniform float triplanar_sharpness : hint_range(0.1, 50.0) = 10.0;
uniform vec3 triplanar_offset;

uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.5;

varying vec3 v_obj_pos;
varying vec3 v_obj_normal;
varying vec3 v_obj_scale;

void vertex() {
    v_obj_scale = vec3(
        length(MODEL_MATRIX[0].xyz),
        length(MODEL_MATRIX[1].xyz),
        length(MODEL_MATRIX[2].xyz)
    );
    
    v_obj_pos = VERTEX;

    v_obj_normal = NORMAL; 
}

void fragment() {

    vec3 abs_normal = abs(v_obj_normal);
    vec3 blending = pow(abs_normal, vec3(triplanar_sharpness));
    blending /= (blending.x + blending.y + blending.z);
    

    vec3 tri_pos = (v_obj_pos * v_obj_scale + triplanar_offset) * triplanar_scale;


    vec4 albedo_x = texture(texture_albedo, vec3(tri_pos.zy, layer_index));
    vec4 albedo_y = texture(texture_albedo, vec3(tri_pos.xz, layer_index));
    vec4 albedo_z = texture(texture_albedo, vec3(tri_pos.xy, layer_index));
    ALBEDO = (albedo_x * blending.x + albedo_y * blending.y + albedo_z * blending.z).rgb;


    vec3 nm_x = texture(texture_normal, vec3(tri_pos.zy, layer_index)).rgb * 2.0 - 1.0;
    vec3 nm_y = texture(texture_normal, vec3(tri_pos.xz, layer_index)).rgb * 2.0 - 1.0;
    vec3 nm_z = texture(texture_normal, vec3(tri_pos.xy, layer_index)).rgb * 2.0 - 1.0;
    

    nm_x = vec3(nm_x.xy, nm_x.z) * vec3(sign(v_obj_normal.x), 1.0, 1.0);
    nm_y = vec3(nm_y.xy, nm_y.z) * vec3(sign(v_obj_normal.y), 1.0, 1.0);
    nm_z = vec3(nm_z.xy, nm_z.z) * vec3(sign(v_obj_normal.z), 1.0, 1.0);
    
    vec3 combined_normal = nm_x * blending.x + nm_y * blending.y + nm_z * blending.z;
    NORMAL_MAP = combined_normal * 0.5 + 0.5;

    // --- ORM & AO ---
    vec4 orm_x = texture(texture_orm, vec3(tri_pos.zy, layer_index));
    vec4 orm_y = texture(texture_orm, vec3(tri_pos.xz, layer_index));
    vec4 orm_z = texture(texture_orm, vec3(tri_pos.xy, layer_index));
    vec4 orm_tex = orm_x * blending.x + orm_y * blending.y + orm_z * blending.z;
    
    ROUGHNESS = orm_tex.g;
    METALLIC = metallic;
    AO = 1.0;
    AO_LIGHT_AFFECT = ao_light_affect;
}