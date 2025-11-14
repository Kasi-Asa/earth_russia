// reveal.shader
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0; // 0 = empty, 1 = full
uniform float edge : hint_range(0.0, 0.2) = 0.005;   // softness of the edge
uniform float min_alpha : hint_range(0.0, 1.0) = 0.2; // base transparency

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // Calculate alpha factor: 0 = hidden, 1 = visible, with soft edge
    float factor = smoothstep(progress - edge, progress, UV.x);

    // blend between min_alpha and 1 based on factor
    float alpha = mix(1.0, min_alpha, factor);

    tex_color.a *= alpha;

    COLOR = tex_color;
}
