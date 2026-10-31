shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D artwork : source_color, filter_linear_mipmap;
void fragment() {
    vec4 ink = texture(artwork, UV);
    float brightness = dot(ink.rgb, vec3(0.299, 0.587, 0.114));
    ALBEDO = vec3(0.2, 0.55, 1.0) * brightness * 1.5;
    ALPHA = ink.a;
}
