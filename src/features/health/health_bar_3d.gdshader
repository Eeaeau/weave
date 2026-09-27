shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 health_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform vec4 no_health_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

uniform vec4 background_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);

uniform float health_progress : hint_range(0.0, 1.0) = 0.75;

void fragment() {
    if (UV.x < health_progress) {
        ALBEDO = mix(no_health_color.rgb, health_color.rgb, health_progress);
        ALPHA = health_color.a;
    } else {
        ALBEDO = background_color.rgb;
        ALPHA = background_color.a;
    }
}
