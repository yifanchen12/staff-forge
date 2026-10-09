shader_type spatial;
uniform vec4 stone_color : source_color = vec4(0.25, 0.29, 0.3, 1.0);
uniform float tiles = 12.0;
uniform bool floor_tiles = false;
uniform float polish = 0.65;
varying vec3 world_pos;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL,0.0)).xyz);
}
void fragment() {
	vec3 n = abs(world_normal);
	vec2 surface = n.y > 0.6 ? world_pos.xz : (n.x > 0.6 ? world_pos.zy : world_pos.xy);
	vec2 p = surface * (1.2 + tiles * 0.025);
	p.y *= floor_tiles ? 1.0 : 1.9;
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float edge = min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
	float mortar = smoothstep(0.008,0.032,edge);
	float vein = sin(surface.x * 7.0 + surface.y * 4.2 + sin(surface.y * 3.0) * 1.4);
	float marble = pow(abs(vein),24.0) * 0.12;
	float grain = hash(floor(surface * 350.0)) * 0.035;
	ALBEDO = stone_color.rgb * mix(0.30,0.80+hash(cell)*0.18+grain+marble,mortar);
	ROUGHNESS = polish + (1.0-mortar)*0.16;
	METALLIC = floor_tiles ? 0.15 : 0.04;
}
