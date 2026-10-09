shader_type spatial;
uniform vec4 wood_color : source_color = vec4(0.27,0.15,0.08,1.0);
void fragment() {
	vec2 p = UV;
	float wave = sin(p.y * 24.0 + sin(p.x * 18.0) * 0.7);
	float grain = sin(p.x * 155.0 + wave * 3.0) * 0.5 + 0.5;
	float fine = sin(p.x * 460.0 + wave * 6.0) * 0.5 + 0.5;
	ALBEDO = wood_color.rgb * (0.62 + grain * 0.34 + fine * 0.07);
	ROUGHNESS = 0.48 + grain * 0.16;
}
