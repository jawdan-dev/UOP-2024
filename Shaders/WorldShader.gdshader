shader_type spatial;

uniform sampler2D text : source_color, filter_nearest, repeat_enable;

void fragment() {
	vec4 col = texture(text, UV);
	if (col.a < 0.1f) discard;
	ALBEDO.rgb = col.rgb;
}
