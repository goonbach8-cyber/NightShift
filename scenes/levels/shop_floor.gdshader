shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_pos.xz / 0.65;
	vec2 cell = floor(p);
	vec2 edge = min(fract(p), 1.0 - fract(p));
	float grout = 1.0 - smoothstep(0.003, 0.014, min(edge.x, edge.y));
	float variation = fract(sin(dot(cell, vec2(12.9898,78.233))) * 43758.5453);
	vec3 tile = mix(vec3(0.26,0.29,0.28), vec3(0.33,0.35,0.32), variation);

	ALBEDO = mix(tile, vec3(0.16,0.18,0.17), grout);
	ROUGHNESS = mix(0.68,0.95,grout);
}
