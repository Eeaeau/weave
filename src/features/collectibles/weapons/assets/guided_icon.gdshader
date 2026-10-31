shader_type canvas_item;
void fragment() {
    vec4 ink = texture(TEXTURE, UV);
    float brightness = dot(ink.rgb, vec3(0.299, 0.587, 0.114));
    COLOR *= vec4(vec3(0.2, 0.55, 1.0) * brightness * 1.5, ink.a);
}
