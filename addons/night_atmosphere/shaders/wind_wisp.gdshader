shader_type spatial;
// A thin streak of drifting air: dust, pollen, seed fluff. The script stretches
// each instance along its own velocity, so this only draws a soft capsule that
// fades at both ends.
//
// Additive, because catching the light is the only way moving air is ever visible.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 wisp_color : source_color = vec4(0.75, 0.82, 0.95, 1.0);
uniform float brightness : hint_range(0.0, 6.0) = 1.3;
// How sharply it thins across its width.
uniform float thinness : hint_range(0.5, 6.0) = 2.2;
// Soft-fade against solid geometry, in meters, so a wisp passing a wall does not
// slice into it with a hard edge.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float soft_fade : hint_range(0.0, 2.0) = 0.35;

varying vec4 inst;

void vertex() {
	inst = COLOR;
	// Billboarded around the long axis only. A full billboard would discard the
	// alignment that makes the streak read as travel.
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	vec3 along = normalize(MODEL_MATRIX[0].xyz);
	vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
	vec3 up = normalize(cross(to_cam, along));
	vec3 fwd = cross(along, up);
	mat4 m = mat4(vec4(along * s.x, 0.0), vec4(up * s.y, 0.0),
		vec4(fwd * s.z, 0.0), MODEL_MATRIX[3]);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * m * vec4(VERTEX, 1.0);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// Taper along the length, fade across the width.
	float along_fade = pow(clamp(1.0 - abs(uv.x), 0.0, 1.0), 1.4);
	float across = pow(clamp(1.0 - abs(uv.y), 0.0, 1.0), thinness);
	float a = along_fade * across * inst.a;

	// Soft particles, using linear view depth via INV_PROJECTION_MATRIX. Raw buffer
	// depth is non-linear and reversed in Godot 4, so it cannot be compared directly.
	if (soft_fade > 0.0) {
		float raw = texture(depth_tex, SCREEN_UV).r;
		vec4 v = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV * 2.0 - 1.0, raw), 1.0);
		v.xyz /= v.w;
		a *= clamp((-v.z - (-VERTEX.z)) / soft_fade, 0.0, 1.0);
	}

	// Unshaded discards EMISSION. See firefly.gdshader.
	ALBEDO = wisp_color.rgb * inst.rgb * brightness;
	ALPHA = clamp(a, 0.0, 1.0);
}
