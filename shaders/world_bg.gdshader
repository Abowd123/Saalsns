shader_type canvas_item;
// World background: drifting glows + a slow aurora band + twinkling stars + vignette + grain.
// One pass, no textures. `motion` 0 = frozen (reduce motion / low quality),
// `detail` 0..1 scales the extras (aurora, stars, grain) per quality tier.
uniform vec4 base_color : source_color = vec4(0.055, 0.078, 0.141, 1.0);
uniform vec4 accent : source_color = vec4(0.173, 0.788, 0.710, 1.0);
uniform float strength = 0.18;
uniform float motion = 1.0;
uniform float detail = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float t = TIME * 0.08 * motion + 3.0;
	vec2 uv = UV;
	vec2 p1 = vec2(0.25 + 0.15 * sin(t * 1.3), 0.20 + 0.10 * cos(t));
	vec2 p2 = vec2(0.80 + 0.12 * cos(t * 0.9), 0.85 + 0.08 * sin(t * 1.7));
	float g = smoothstep(0.65, 0.0, distance(uv, p1)) + 0.6 * smoothstep(0.55, 0.0, distance(uv, p2));
	float n = noise(vec2(uv.x * 3.0 + t, uv.y * 1.5 - t * 0.5)) * 0.6 + noise(vec2(uv.x * 7.0 - t * 1.3, uv.y * 3.0)) * 0.4;
	float band = smoothstep(0.20, 0.0, abs(uv.y - 0.30 - 0.06 * sin(uv.x * 3.0 + t * 2.0) - (n - 0.5) * 0.18));
	vec3 col = base_color.rgb + accent.rgb * (g * strength + band * 0.17 * detail * (0.6 + 0.4 * n));
	vec2 sg = uv * vec2(36.0, 78.0);
	vec2 cell = floor(sg);
	float h = hash(cell);
	vec2 sp = fract(sg) - 0.5 - (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.6;
	float twinkle = 0.55 + 0.45 * sin(TIME * motion * 2.0 + h * 40.0);
	float star = step(0.92, h) * smoothstep(0.12, 0.0, length(sp)) * twinkle;
	col += vec3(star * 0.65 * detail);
	float v = smoothstep(1.15, 0.30, length((uv - vec2(0.5)) * vec2(1.0, 1.15)));
	col *= mix(0.70, 1.0, v);
	col += (hash(uv * vec2(731.0, 1213.0) + fract(TIME * motion)) - 0.5) * 0.016 * detail;
	COLOR = vec4(col, 1.0);
}
