shader_type sky;
// Night sky: gradient, stars, a milky-way band, a moon with a phase, and thin
// cloud that is only visible where the moon lights it.
//
// Sky shaders have no geometry. Everything is derived from EYEDIR, the world-space
// direction of the pixel being drawn, which is why the moon is a dot product
// against a direction rather than an object placed in the scene.

group_uniforms sky_gradient;
uniform vec3 zenith_color : source_color = vec3(0.010, 0.018, 0.045);
uniform vec3 horizon_color : source_color = vec3(0.045, 0.062, 0.105);
uniform vec3 ground_color : source_color = vec3(0.008, 0.010, 0.016);
// How tightly the horizon color hugs the horizon.
uniform float horizon_falloff : hint_range(0.5, 12.0) = 3.2;

group_uniforms stars;
uniform float star_density : hint_range(20.0, 400.0) = 160.0;
// Fraction of cells that hold a star. Low, or the sky reads as noise.
uniform float star_amount : hint_range(0.0, 0.2) = 0.035;
uniform float star_brightness : hint_range(0.0, 6.0) = 1.6;
uniform float twinkle_speed : hint_range(0.0, 8.0) = 1.6;
uniform vec3 star_warm : source_color = vec3(1.0, 0.86, 0.72);
uniform vec3 star_cool : source_color = vec3(0.72, 0.82, 1.0);
// Stars thin out toward the horizon, where real haze eats them.
uniform float star_horizon_fade : hint_range(0.0, 1.0) = 0.75;

group_uniforms milky_way;
uniform float band_strength : hint_range(0.0, 2.0) = 0.35;
// The band's axis. Any direction; the band is drawn perpendicular to it.
uniform vec3 band_axis = vec3(0.4, 0.55, -0.73);
uniform vec3 band_color : source_color = vec3(0.36, 0.40, 0.62);

group_uniforms moon;
// Direction FROM the viewer TO the moon. Point this the opposite way to your
// MoonRig's light and the shafts will come from where the moon actually is.
uniform vec3 moon_direction = vec3(0.35, 0.45, -0.82);
uniform float moon_size : hint_range(0.002, 0.15) = 0.035;
uniform vec3 moon_color : source_color = vec3(1.0, 0.97, 0.90);
uniform float moon_brightness : hint_range(0.0, 8.0) = 3.0;
// -1 to 1. 0 is full; either extreme is a thin crescent. The terminator is a
// second sphere offset sideways, which is how a real phase works.
uniform float moon_phase : hint_range(-1.0, 1.0) = -0.35;
// Soft halo around it. This is what makes the moon feel like a light source
// rather than a sticker.
uniform float halo_size : hint_range(1.0, 400.0) = 60.0;
uniform float halo_strength : hint_range(0.0, 3.0) = 0.55;

group_uniforms clouds;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.42;
uniform float cloud_scale : hint_range(0.2, 8.0) = 1.6;
uniform vec2 cloud_drift = vec2(0.006, 0.002);
// Barely-there is the point: cloud is only visible where the moon lights it.
uniform float cloud_brightness : hint_range(0.0, 2.0) = 0.30;
uniform float cloud_moonlight : hint_range(0.0, 4.0) = 1.6;
// Above about 2 this starts finding hard edges in the noise again. 1.4 is a soft
// overcast; 2.5 is broken cloud with defined shapes.
uniform float cloud_sharpness : hint_range(0.5, 4.0) = 1.5;
// How far up the sky the cloud deck fades in from. Raise it if you can still see
// streaking along the horizon; lower it to bring cloud further down.
uniform float cloud_horizon_fade : hint_range(0.05, 0.9) = 0.45;
// Flattens the perspective divide. 0 is a true plane projection, which stretches
// to infinity at the horizon; 1 wraps the cloud onto the sky dome with no stretch
// at all but no sense of a deck overhead either. Between the two is the sweet spot.
uniform float cloud_dome : hint_range(0.0, 1.0) = 0.35;

// --- noise -------------------------------------------------------------------
// Avoids fract(sin(dot(...))). That hash loses precision at large coordinates, and
// the cloud projection divides by dir.y, so values near the horizon get big enough
// to break it into visible blocks.
float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float h31(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

// Lattice cells wrap at this many units before being hashed. Any hash degrades as
// its input grows, and the cloud projection divides by dir.y, so the coordinate
// climbs steeply toward the horizon - which is where the last seams were. Wrapping
// the CELL (not the interpolation) bounds what the hash ever sees.
//
// The field repeats every 512 cells. At any sane cloud_scale that is far outside
// the visible sky, so the repeat is never reachable.
const float LATTICE = 512.0;

float vnoise(vec2 p) {
	vec2 i = mod(floor(p), LATTICE);
	vec2 f = fract(p);
	// Quintic rather than cubic. Cubic leaves a discontinuous second derivative at
	// the cell edges, which reads as a faint grid across large soft shapes.
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	// Neighbours wrap too, or the seam moves to the wrap boundary instead of
	// disappearing.
	return mix(mix(h21(i), h21(mod(i + vec2(1, 0), LATTICE)), u.x),
		mix(h21(mod(i + vec2(0, 1), LATTICE)), h21(mod(i + vec2(1, 1), LATTICE)), u.x),
		u.y);
}

// Octaves are rotated as well as scaled. Frequency doubling alone leaves every
// octave on the same axis-aligned lattice, which is most of why value-noise fbm
// looks square.
const mat2 OCTAVE_ROT = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += vnoise(p) * a;
		p = OCTAVE_ROT * p * 2.03;
		a *= 0.5;
	}
	return v;
}

// Domain warp: sample the field at a position offset by the field itself. Costs
// one extra fbm and is what gives the cloud billows instead of even static.
float cloud_noise(vec2 p) {
	vec2 w = vec2(fbm(p * 0.5 + 11.3), fbm(p * 0.5 + 71.9)) - 0.5;
	// 1.0 rather than 1.4. A warp strong enough to fold the field back over itself
	// creases, and the crease reads as a hard line rather than as cloud.
	return fbm(p + w * 1.0);
}

// Stars sit on a grid in direction space rather than a projected plane, so they do
// not stretch or bunch together overhead.
float starfield(vec3 dir, float t) {
	vec3 g = dir * star_density;
	vec3 cell = floor(g);
	vec3 f = fract(g) - 0.5;
	float r = h31(cell);
	if (r > star_amount) {
		return 0.0;
	}
	// Random position within the cell, or every star sits on a lattice.
	vec3 jitter = vec3(h31(cell + 11.0), h31(cell + 23.0), h31(cell + 37.0)) - 0.5;
	float d = length(f - jitter * 0.7);
	// Varied magnitudes. Uniform brightness reads as a printed texture.
	float mag = pow(h31(cell + 51.0), 2.2);
	float tw = 0.65 + 0.35 * sin(t * twinkle_speed + r * 100.0);
	return smoothstep(0.16, 0.0, d) * mag * tw;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;

	// --- gradient -------------------------------------------------------------
	float h = pow(clamp(1.0 - abs(up), 0.0, 1.0), horizon_falloff);
	vec3 col = mix(zenith_color, horizon_color, h);
	col = mix(col, ground_color, smoothstep(0.0, -0.12, up));

	float above = smoothstep(-0.05, 0.18, up);

	// --- milky way ------------------------------------------------------------
	// Distance from the plane perpendicular to band_axis, so the band wraps the
	// sky as a great circle.
	float band_d = abs(dot(dir, normalize(band_axis)));
	float band = pow(1.0 - clamp(band_d * 2.2, 0.0, 1.0), 3.0);
	band *= 0.55 + fbm(dir.xz * 3.0 + dir.y * 2.0) * 0.9;
	col += band_color * band * band_strength * above;

	// --- stars ----------------------------------------------------------------
	float s = starfield(dir, TIME);
	// The band is denser in stars, which is what a milky way actually is.
	s *= 1.0 + band * 2.5;
	s *= mix(1.0 - star_horizon_fade, 1.0, above);
	vec3 star_tint = mix(star_cool, star_warm, h31(floor(dir * star_density) + 5.0));
	col += star_tint * s * star_brightness;

	// --- moon -----------------------------------------------------------------
	vec3 md = normalize(moon_direction);
	float md_dot = dot(dir, md);
	// Angular distance from the moon center, small-angle, so `moon_size` reads as
	// a radius rather than as a cosine.
	float ang = acos(clamp(md_dot, -1.0, 1.0));
	float disc = 1.0 - smoothstep(moon_size * 0.94, moon_size, ang);

	// Phase comes from testing against a second direction offset sideways, which
	// gives a curved terminator instead of a straight cut.
	vec3 side = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
	float shadow_ang = acos(clamp(dot(dir, normalize(md + side * moon_phase * 0.9)),
		-1.0, 1.0));
	float lit = smoothstep(moon_size * 0.9, moon_size * 1.02, shadow_ang);
	// A little of the dark limb stays visible - earthshine.
	disc *= mix(0.06, 1.0, lit);

	// Surface mottling, so it is not a flat circle.
	float mottle = 0.82 + fbm(dir.xz * 220.0) * 0.36;
	col += moon_color * disc * moon_brightness * mottle;

	float halo = pow(max(md_dot, 0.0), halo_size);
	col += moon_color * halo * halo_strength;

	// --- cloud ----------------------------------------------------------------
	// Projected onto a plane overhead. Dividing by dir.y stretches it toward the
	// horizon, which is exactly what perspective does to a real cloud deck.
	if (cloud_amount > 0.0 && up > 0.0) {
		// dir.xz / up is the exact projection of a flat deck and diverges at the
		// horizon, smearing cells into vertical streaks. Adding a constant to the
		// divisor bounds the stretch and stays smooth. cloud_dome mixes toward
		// plain direction, which has no stretch at all.
		float divisor = mix(up * 0.92 + 0.22, 1.0, cloud_dome);
		vec2 cuv = dir.xz / divisor * cloud_scale + cloud_drift * TIME;
		float n = cloud_noise(cuv);
		// A wide threshold band. Narrow bands turn the noise into a hard mask and
		// every lattice edge becomes a visible step.
		float c = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.55, n);
		c = pow(c, cloud_sharpness);
		// Fade out before the horizon. No plane projection behaves in the last few
		// degrees, so the remaining stretch is hidden rather than corrected.
		c *= smoothstep(0.0, cloud_horizon_fade, up);
		// Lit only near the moon. Elsewhere the cloud reads as a gap in the stars
		// rather than a bright shape.
		float moonlit = pow(max(md_dot, 0.0), 3.0) * cloud_moonlight;
		vec3 cloud_col = moon_color * (cloud_brightness * (0.25 + moonlit));
		col = mix(col, cloud_col, clamp(c, 0.0, 1.0));
	}

	COLOR = col;
}
