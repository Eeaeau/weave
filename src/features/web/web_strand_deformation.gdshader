shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D spring_offsets : filter_nearest, repeat_disable;
uniform vec3 gravity_direction = vec3(0.0, -1.0, 0.0);
uniform vec3 depth_direction = vec3(0.0, 0.0, 1.0);
uniform ivec2 field_size = ivec2(1);
uniform vec4 web_color : source_color = vec4(1.0);
uniform int contact_count = 0;
uniform vec4 contact_meta[64];
uniform vec4 contact_bends[64];
uniform float maximum_bend = 0.08;

void vertex() {
	float strand = floor(UV.x);
	float t = fract(UV.x) / 0.999;
	vec2 cell = clamp(UV2, vec2(0.0), vec2(field_size - ivec2(1)));
	ivec2 start = ivec2(floor(cell));
	ivec2 finish = min(start + ivec2(1), field_size - ivec2(1));
	vec2 fraction = fract(cell);
	vec2 top = mix(texelFetch(spring_offsets, start, 0).rg,
		texelFetch(spring_offsets, ivec2(finish.x, start.y), 0).rg, fraction.x);
	vec2 bottom = mix(texelFetch(spring_offsets, ivec2(start.x, finish.y), 0).rg,
		texelFetch(spring_offsets, finish, 0).rg, fraction.x);
	vec2 spring = mix(top, bottom, fraction.y) * UV.y;
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
