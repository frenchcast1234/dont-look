shader_type spatial;
// A stylized flame on a single quad, no textures.
//
// render_mode, line by line:
//   unshaded          fire emits light rather than receiving it
//   blend_add         reads as light against a dark scene
//   cull_disabled     one quad, so it has to survive being seen from behind
//   depth_draw_never  or two overlapping cards punch holes in each other
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Billboarded in the vertex stage rather than with the material flag. The flag
// also billboards the Y axis, which tips the flame toward a downward-looking
// camera. Only the horizontal facing is replaced here, so up stays up.
uniform bool billboard = true;

group_uniforms shape;
// Where the flame pinches in toward the tip. Lower is a taller, thinner flame.
uniform float taper : hint_range(0.1, 3.0) = 1.15;
// How wide it is at the base, in UV.
uniform float width : hint_range(0.1, 1.0) = 0.62;
// How much the noise eats into the silhouette. This is what makes it look like
// flame rather than a leaf.
uniform float bite : hint_range(0.0, 1.0) = 0.42;
// Sharpness of the edge. High is a cel-shaded flame, low is a soft glow.
uniform float edge : hint_range(0.5, 40.0) = 9.0;
// Fraction of the height faded out at the very tip and the very base.
//
// The silhouette already tapers to a point at the top, so the tip fade only exists
// to stop the noise leaving a hard speck up there. Anything large enough to be
// worth calling a fade eats the point before it forms, which is invisible on a
// candle and obvious the moment the flame is scaled up.
uniform float tip_fade : hint_range(0.0, 0.4) = 0.05;
uniform float base_fade : hint_range(0.0, 0.4) = 0.12;

group_uniforms motion;
uniform float rise_speed = 1.6;
uniform float noise_scale = 3.2;
// Sideways sway of the whole flame, in UV.
uniform float sway = 0.06;
uniform float sway_speed = 1.9;
// Offsets this flame in the noise field so a row of candles is not synchronized.
uniform float seed = 0.0;

group_uniforms color;
uniform vec3 core_color : source_color = vec3(1.0, 0.96, 0.80);
uniform vec3 mid_color : source_color = vec3(1.0, 0.63, 0.18);
uniform vec3 rim_color : source_color = vec3(0.85, 0.19, 0.03);
uniform float brightness : hint_range(0.0, 6.0) = 2.4;

// --- value noise -------------------------------------------------------------
// Procedural rather than a texture, so there is nothing to import and it tiles by
// construction.
float hash(vec2 p) {
	// Avoids fract(sin(dot(...))). That hash breaks down once the coordinate gets
	// large, and TIME scrolls this field indefinitely.
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

const float LATTICE = 512.0;

float value_noise(vec2 p) {
	vec2 i = mod(floor(p), LATTICE);
	vec2 f = fract(p);
	// Quintic. Cubic leaves a discontinuous second derivative at the cell edges,
	// which shows as a diamond grid once the flame is scaled up.
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(hash(i), hash(mod(i + vec2(1.0, 0.0), LATTICE)), u.x),
		mix(hash(mod(i + vec2(0.0, 1.0), LATTICE)),
			hash(mod(i + vec2(1.0, 1.0), LATTICE)), u.x), u.y);
}

// Rotated between octaves, not just scaled. Scaling alone keeps every octave on
// the same axis-aligned lattice, which is what makes value-noise fbm look square.
const mat2 OCTAVE_ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.6;
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * a;
		p = OCTAVE_ROT * p * 2.17;
		a *= 0.5;
	}
	// Four octaves at 0.6 falloff sums to about 1.125, so normalize or `bite`
	// means something different than it did.
	return v / 1.125;
}

void vertex() {
	if (billboard) {
		// Keep the model up vector, take the other two axes from the camera. Column
		// lengths are carried across or a scaled quad would snap back to 1.
		vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
			length(MODEL_MATRIX[2].xyz));
		vec3 up = normalize(MODEL_MATRIX[1].xyz);
		vec3 to_cam = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
		vec3 right = normalize(cross(up, to_cam));
		vec3 fwd = cross(right, up);
		mat4 m = mat4(vec4(right * scale.x, 0.0), vec4(up * scale.y, 0.0),
			vec4(fwd * scale.z, 0.0), MODEL_MATRIX[3]);
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * m * vec4(VERTEX, 1.0);
	}
}

void fragment() {
	// v runs 0 at the base to 1 at the tip; u is -1..1 across.
	//
	// Flipped because QuadMesh puts UV (0,0) at the top left, so v grows downward.
	// Using UV.y raw builds the flame upside down.
	float v = 1.0 - UV.y;
	float u = UV.x * 2.0 - 1.0;

	// Leans more at the tip than the base. A uniform sway looks like a swinging sign.
	float lean = sin(TIME * sway_speed + seed) * sway * v * v;
	u -= lean * 4.0;

	// Silhouette: a cone that pinches toward the tip.
	float shape = pow(1.0 - v, taper);
	// Noise scrolls DOWNWARD in UV so the flame appears to rise.
	float n = fbm(vec2(u * noise_scale + seed, v * noise_scale - TIME * rise_speed));

	// The noise SCALES the width rather than being subtracted from it.
	//
	// Subtracting took a fixed amount off, and the amount grew toward the tip while
	// the width there shrank to zero - so the noise always removed more than was
	// left and the point never formed, at any size. Scaling keeps the bite
	// proportional, so the silhouette still ripples but converges where it should.
	float wobble = (n - 0.5) * bite * (0.25 + v) * 2.0;
	float half_width = max(width * shape * (1.0 - wobble), 0.0);

	float d = abs(u) - half_width;
	float mask = clamp(1.0 - d * edge, 0.0, 1.0);
	// Fade the base so it does not sit on the wick as a flat cut, and take the last
	// sliver off the tip so the noise cannot leave a speck floating there.
	//
	// Written as 1.0 - smoothstep(lo, hi, v) rather than smoothstep(hi, lo, v).
	// GLSL leaves the result UNDEFINED when edge0 >= edge1; it happens to work on
	// most drivers, which makes it a bug that turns up on someone else's machine.
	mask *= smoothstep(0.0, max(base_fade, 0.001), v);
	mask *= 1.0 - smoothstep(1.0 - max(tip_fade, 0.001), 1.0, v);

	if (mask <= 0.001) {
		discard;
	}

	// Colored by depth inside the silhouette rather than by height. Height gives a
	// gradient that reads as a painted decal.
	float depth = clamp(-d / max(half_width, 0.001), 0.0, 1.0);
	vec3 col = mix(rim_color, mid_color, smoothstep(0.0, 0.45, depth));
	col = mix(col, core_color, smoothstep(0.5, 1.0, depth) * (1.0 - v * 0.55));

	// Unshaded discards EMISSION, so the color goes in ALBEDO. blend_add already
	// multiplies by ALPHA, so mask is not applied twice.
	ALBEDO = col * brightness;
	ALPHA = mask;
}
