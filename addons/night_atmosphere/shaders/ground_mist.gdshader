shader_type spatial;
// A sheet of low mist. One plane, scrolling noise, soft edges, and a depth fade so
// it sinks into geometry rather than cutting a line across it.
//
// The depth fade is the part that matters. Without it this is a visible rectangle.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

group_uniforms look;
uniform vec4 mist_color : source_color = vec4(0.72, 0.78, 0.86, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.32;
// Meters of fade where the mist meets solid geometry.
uniform float soft_fade : hint_range(0.05, 4.0) = 1.1;
// Fades out close to the camera, so you never fly through a visible sheet.
uniform float near_fade : hint_range(0.0, 12.0) = 3.5;

group_uniforms motion;
uniform float noise_scale = 0.09;
uniform vec2 drift = vec2(0.012, 0.006);
// A second layer at another scale and speed. One layer alone reads as a scrolling
// texture; two crossing layers read as drifting.
uniform float layer2_scale = 0.21;
uniform float layer2_speed = 2.3;
// Above about 2 this starts finding hard edges in the noise.
uniform float contrast : hint_range(0.5, 4.0) = 1.5;

group_uniforms shape;
// How far in from the plane's edge the mist fades to nothing, in UV.
uniform float edge_fade : hint_range(0.0, 0.5) = 0.22;

varying vec3 world_pos;

// Hash, interpolation and octave handling all matter here. Mist is a large area of
// slowly changing value, which is the worst case for a cheap noise: every flaw
// shows up as a flat cell you can see the edges of.
float hash21(vec2 p) {
	// Avoids fract(sin(dot(...))), which loses precision at large coordinates. The
	// mist samples in world space, so a plane far from the origin gets big inputs.
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

const float LATTICE = 512.0;

float vnoise(vec2 p) {
	vec2 i = mod(floor(p), LATTICE);
	vec2 f = fract(p);
	// Quintic. Cubic smoothstep leaves a discontinuous second derivative at the
	// cell edges, which on a soft shape reads as a faint grid.
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash21(i), hash21(mod(i + vec2(1, 0), LATTICE)), u.x),
		mix(hash21(mod(i + vec2(0, 1), LATTICE)),
			hash21(mod(i + vec2(1, 1), LATTICE)), u.x), u.y);
}

// Octaves are rotated as well as scaled. Scaling alone stacks every octave on the
// same axis-aligned lattice, which is most of why value-noise fbm looks square.
const mat2 OCTAVE_ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += vnoise(p) * a;
		p = OCTAVE_ROT * p * 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Sampled in world space so adjacent planes share one continuous field.
	vec2 p = world_pos.xz;
	// Domain warp: sample the field at a position offset by the field itself. This
	// is what gives the mist billows and tendrils rather than even blobs, and it is
	// the single biggest difference between "fog" and "noise".
	vec2 w = vec2(fbm(p * noise_scale * 0.5 + 11.3),
		fbm(p * noise_scale * 0.5 + 71.9)) - 0.5;
	float a = fbm(p * noise_scale + w * 1.2 + drift * TIME);
	float b = fbm(p * layer2_scale - drift * TIME * layer2_speed);
	float n = pow(clamp(a * 0.65 + b * 0.5, 0.0, 1.0), contrast);

	// Rectangular fade in from the plane's own edges.
	vec2 e = smoothstep(vec2(0.0), vec2(edge_fade), UV)
		* smoothstep(vec2(0.0), vec2(edge_fade), 1.0 - UV);
	float alpha = n * density * e.x * e.y;

	// Linear view depth in meters. Raw buffer depth is non-linear and reversed in
	// Godot 4, so it cannot be compared directly.
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(vec3(SCREEN_UV * 2.0 - 1.0, raw), 1.0);
	v.xyz /= v.w;
	float scene_depth = -v.z;
	float here = -VERTEX.z;
	alpha *= clamp((scene_depth - here) / soft_fade, 0.0, 1.0);
	if (near_fade > 0.0) {
		alpha *= clamp(here / near_fade, 0.0, 1.0);
	}

	ALBEDO = mist_color.rgb;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
