shader_type canvas_item;
// Scene transition: radial wipe with a noisy, glowing edge. progress 0 = clear, 1 = covered.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origin = vec2(0.5, 0.5);
uniform vec4 tint : source_color = vec4(0.055, 0.078, 0.141, 1.0);
uniform vec4 rim : source_color = vec4(0.173, 0.788, 0.710, 1.0);
uniform float aspect = 0.4615;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 d = UV - origin;
	d.x *= aspect;
	float a = atan(d.y, d.x);
	float wob = (noise(vec2(a * 3.0, progress * 4.0)) - 0.5) * 0.07 + (noise(UV * vec2(9.0, 9.0 / aspect)) - 0.5) * 0.03;
	float r = length(d) + wob;
	float edge = progress * 1.3;
	float cover = 1.0 - smoothstep(edge - 0.015, edge, r);
	float ring = smoothstep(edge - 0.12, edge - 0.01, r) * cover;
	float outer = smoothstep(edge + 0.06, edge, r) * (1.0 - cover) * step(0.001, progress) * step(progress, 0.999);
	vec3 col = mix(tint.rgb, rim.rgb, ring * 0.85);
	COLOR = vec4(col + rim.rgb * outer * 0.6, max(cover, outer * 0.5));
}
