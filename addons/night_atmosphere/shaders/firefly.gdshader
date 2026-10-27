shader_type spatial;
// One glowing mote, drawn as a billboarded quad from a MultiMesh.
//
// Brightness arrives as the instance color, so blink timing lives in the script
// where it can be read and tuned, and this only draws the glow.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float size_scale : hint_range(0.1, 6.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(0.80, 1.0, 0.45, 1.0);
// Radius of the hot center, in UV. Small keeps it a spark rather than a blob.
uniform float core : hint_range(0.0, 0.6) = 0.16;
uniform float falloff : hint_range(0.5, 6.0) = 2.6;
uniform float brightness : hint_range(0.0, 12.0) = 4.0;

varying vec4 inst;

void vertex() {
	// Instance color: rgb is the tint, alpha is the current brightness.
	inst = COLOR;

	// Full billboard. A point of light has no up direction worth keeping, so the
	// basis is replaced outright and only scale is carried across.
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz));
	mat4 m = MODEL_MATRIX;
	m[0] = vec4(INV_VIEW_MATRIX[0].xyz * s.x, 0.0);
	m[1] = vec4(INV_VIEW_MATRIX[1].xyz * s.y, 0.0);
	m[2] = vec4(INV_VIEW_MATRIX[2].xyz * s.z, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * m * vec4(VERTEX * size_scale, 1.0);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	// Wide halo plus a small hot core. Either alone reads as a blob or a pixel.
	float halo = pow(clamp(1.0 - d, 0.0, 1.0), falloff);
	float hot = 1.0 - smoothstep(0.0, core, d);
	float a = (halo + hot) * inst.a;

	// Unshaded means the output is ALBEDO alone. EMISSION is part of lighting and
	// is discarded here, so the color has to go in ALBEDO.
	//
	// blend_add already multiplies by ALPHA, so the falloff goes in ALPHA only.
	ALBEDO = glow_color.rgb * inst.rgb * brightness;
	ALPHA = clamp(a, 0.0, 1.0);
}
