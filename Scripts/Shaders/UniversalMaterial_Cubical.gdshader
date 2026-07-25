shader_type spatial;

// ---------------------------------------------------------------------------
// Biplanar projection variant (formerly "cubical").
//
// Iteration history, for context:
//   1. Original shader: full TRIPLANAR mapping. Samples all 3 world axes,
//      blends all 3 with normal-based weights. Smooth, but 3 texture
//      fetches per map.
//   2. First "cubical" pass: hard-selected a single dominant axis per pixel,
//      no blending at all. Cheap (1 fetch), but on curved geometry (e.g. a
//      rounded hull) this produces a visible hard seam wherever the
//      dominant axis flips, since there's no falloff to hide the jump.
//   3. This version: BIPLANAR mapping. Drops only the single WEAKEST axis
//      (the one whose normal component is smallest) and blends between the
//      remaining two. This is 2 texture fetches per map instead of 3, and
//      critically still blends continuously across the transition where
//      the dropped axis changes - so no hard seam on curved surfaces.
//      (An unblended 2-axis pick is NOT a fix for the seam - dropping the
//      blend collapses back to the same hard selection as step 2, just
//      arrived at from 2 candidates instead of 3. Blending is what removes
//      the seam, not the axis count.)
//
// horizontal_grain: on the two "wall" axes (X-facing and Z-facing), U and V
// are swapped compared to a naive projection so that plank/grain lines run
// horizontally across side faces (matching Roblox's Wood material), rather
// than vertically. The top/bottom (Y-facing) contribution is left as-is,
// since it has no "up" direction to be vertical or horizontal relative to.
// ---------------------------------------------------------------------------

uniform sampler2DArray texture_albedo : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2DArray texture_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2DArray texture_orm    : hint_default_white, repeat_enable, filter_linear_mipmap;

uniform sampler2D material_tint_lut : source_color, filter_nearest;
uniform sampler2D material_base_id_lut : filter_nearest;

uniform float lut_size = 512.0;

uniform float cubical_scale = 1.0;
uniform float blend_sharpness = 4.0;
uniform bool horizontal_grain = true;

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

    vec3 n = normalize(v_normal);
    vec3 axis_sign = sign(n);
    vec3 an = abs(n);

    // Drop only the single weakest axis; keep the other two for blending.
    bool use_x = true;
    bool use_y = true;
    bool use_z = true;
    if (an.x <= an.y && an.x <= an.z) {
        use_x = false;
    } else if (an.y <= an.x && an.y <= an.z) {
        use_y = false;
    } else {
        use_z = false;
    }

    vec3 raw_weight = vec3(
        use_x ? pow(an.x, blend_sharpness) : 0.0,
        use_y ? pow(an.y, blend_sharpness) : 0.0,
        use_z ? pow(an.z, blend_sharpness) : 0.0
    );
    vec3 blend = raw_weight / dot(raw_weight, vec3(1.0));

    vec3 albedo_final = vec3(0.0);
    vec3 orm_final = vec3(0.0);
    vec3 normal_x_ws = vec3(0.0);
    vec3 normal_y_ws = vec3(0.0);
    vec3 normal_z_ws = vec3(0.0);

    if (use_x) {
        // X-facing wall: in-plane axis is Z, vertical axis is Y.
        vec2 uv_x = vec2(-v_vertex.z * axis_sign.x, v_vertex.y);
        vec3 base_normal_x = vec3(-n.z * axis_sign.x, n.y, n.x * axis_sign.x);
        if (horizontal_grain) {
            uv_x = uv_x.yx;
            base_normal_x = vec3(base_normal_x.y, base_normal_x.x, base_normal_x.z);
        }
        uv_x *= cubical_scale;

        vec3 albedo_x = texture(texture_albedo, vec3(uv_x, base_mat_id)).rgb;
        vec3 orm_x = texture(texture_orm, vec3(uv_x, base_mat_id)).rgb;
        vec3 normal_sample_x = normalize(texture(texture_normal, vec3(uv_x, base_mat_id)).rgb * 2.0 - 1.0);

        vec3 nt_x = blend_rnm(base_normal_x, normal_sample_x);
        if (horizontal_grain) {
            nt_x = vec3(nt_x.y, nt_x.x, nt_x.z);
        }
        normal_x_ws = vec3(nt_x.z * axis_sign.x, nt_x.y, -nt_x.x * axis_sign.x);

        albedo_final += albedo_x * blend.x;
        orm_final += orm_x * blend.x;
    }

    if (use_y) {
        // Top/bottom face: no up-direction, mapping left unchanged.
        vec2 uv_y = vec2(-v_vertex.x * axis_sign.y, v_vertex.z) * cubical_scale;
        vec3 base_normal_y = vec3(-n.x * axis_sign.y, n.z, n.y * axis_sign.y);

        vec3 albedo_y = texture(texture_albedo, vec3(uv_y, base_mat_id)).rgb;
        vec3 orm_y = texture(texture_orm, vec3(uv_y, base_mat_id)).rgb;
        vec3 normal_sample_y = normalize(texture(texture_normal, vec3(uv_y, base_mat_id)).rgb * 2.0 - 1.0);

        vec3 nt_y = blend_rnm(base_normal_y, normal_sample_y);
        normal_y_ws = vec3(-nt_y.x * axis_sign.y, nt_y.z * axis_sign.y, nt_y.y);

        albedo_final += albedo_y * blend.y;
        orm_final += orm_y * blend.y;
    }

    if (use_z) {
        // Z-facing wall: in-plane axis is X, vertical axis is Y.
        vec2 uv_z = vec2(v_vertex.x * axis_sign.z, v_vertex.y);
        vec3 base_normal_z = vec3(n.x * axis_sign.z, n.y, n.z * axis_sign.z);
        if (horizontal_grain) {
            uv_z = uv_z.yx;
            base_normal_z = vec3(base_normal_z.y, base_normal_z.x, base_normal_z.z);
        }
        uv_z *= cubical_scale;

        vec3 albedo_z = texture(texture_albedo, vec3(uv_z, base_mat_id)).rgb;
        vec3 orm_z = texture(texture_orm, vec3(uv_z, base_mat_id)).rgb;
        vec3 normal_sample_z = normalize(texture(texture_normal, vec3(uv_z, base_mat_id)).rgb * 2.0 - 1.0);

        vec3 nt_z = blend_rnm(base_normal_z, normal_sample_z);
        if (horizontal_grain) {
            nt_z = vec3(nt_z.y, nt_z.x, nt_z.z);
        }
        normal_z_ws = vec3(nt_z.x * axis_sign.z, nt_z.y, nt_z.z * axis_sign.z);

        albedo_final += albedo_z * blend.z;
        orm_final += orm_z * blend.z;
    }

    albedo_final *= tint;

    vec3 normal_final = normalize(
        normal_x_ws * blend.x + normal_y_ws * blend.y + normal_z_ws * blend.z
    );

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
