shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D sprite_texture : source_color;
uniform vec3 world_offset = vec3(0.0);

void vertex() {
	VERTEX += (inverse(MODEL_MATRIX) * vec4(world_offset, 0.0)).xyz;
}

void fragment() {
	vec4 pixel = texture(sprite_texture, UV) * COLOR;
	ALBEDO = pixel.rgb;
	ALPHA = pixel.a;
}
