shader_type spatial;
render_mode unshaded;
uniform vec4 gem_color : source_color = vec4(0.5,0.8,1.0,1.0);
void fragment() {
	float facet = max(0.0,dot(normalize(NORMAL),normalize(vec3(-0.4,0.7,0.6))));
	ALBEDO = gem_color.rgb * (0.34 + facet * 0.66);
	EMISSION = gem_color.rgb * 0.10;
}
