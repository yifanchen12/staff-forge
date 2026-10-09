shader_type spatial;
render_mode cull_disabled;
void fragment() {
	vec2 p = vec2((UV.x-0.5)*2.0,(UV.y-0.55)*1.6);
	float a = atan(p.y,p.x);
	float r = length(p);
	float petal = abs(sin(a*6.0+r*5.0));
	float lead = smoothstep(0.04,0.075,petal);
	float ring = smoothstep(0.012,0.025,abs(r-0.34));
	vec3 blue = mix(vec3(0.03,0.11,0.19),vec3(0.12,0.28,0.37),step(0.6,petal));
	vec3 glass = mix(blue,vec3(0.32,0.21,0.08),1.0-smoothstep(0.0,0.15,r));
	ALBEDO = mix(vec3(0.025,0.03,0.05),glass,lead*ring);
	EMISSION = glass * lead * ring * 0.40;
	ROUGHNESS = 0.3;
	METALLIC = 0.18;
}
