shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D spring_offsets : filter_nearest, repeat_disable;
uniform vec3 gravity_direction = vec3(0.0, -1.0, 0.0);
uniform vec3 depth_direction = vec3(0.0, 0.0, 1.0);
uniform vec4 web_color : source_color = vec4(1.0);
uniform int contact_count = 0;
uniform vec4 contact_meta[64];
uniform vec4 contact_bends[64];
uniform float maximum_bend = 0.08;

void vertex() {
	float strand = floor(UV.x);
	float t = fract(UV.x) / 0.999;
	vec2 a = texelFetch(spring_offsets, ivec2(int(UV.y), 0), 0).rg;
	vec2 b = texelFetch(spring_offsets, ivec2(int(UV2.x), 0), 0).rg;
	vec2 spring = mix(a, b, UV2.y);
	vec3 pull = vec3(0.0);
	for (int i = 0; i < contact_count; i++) {
		vec4 grip = contact_meta[i];
		if (abs(grip.x - strand) > 0.1) {
			continue;
		}
		float amount = 1.0 - smoothstep(0.0, grip.z, abs(t - grip.y));
		amount *= smoothstep(0.0, min(grip.z, grip.y), t);
		amount *= smoothstep(0.0, min(grip.z, 1.0 - grip.y), 1.0 - t);
		pull += contact_bends[i].xyz * amount;
	}
	float pull_length = length(pull);
	if (pull_length > maximum_bend && pull_length > 0.0) {
		pull *= maximum_bend / pull_length;
	}
	VERTEX += gravity_direction * spring.x + depth_direction * spring.y + pull;
}

void fragment() {
	ALBEDO = web_color.rgb;
}
