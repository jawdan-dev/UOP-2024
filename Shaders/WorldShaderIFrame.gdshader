shader_type spatial;
render_mode unshaded;

uniform sampler2D text : source_color, filter_nearest, repeat_enable;

uniform vec3 iFrameColor = vec3(1.0, 1.0, 1.0);
uniform float iFrameFlashRate = 4.0;

void fragment() {
	vec4 texCol = texture(text, UV);
	vec3 col = mix(texCol.rgb, iFrameColor, (-cos(TIME * iFrameFlashRate * TAU) + 1.0) * 0.5 * 0.7);
	if (texCol.a < 0.1f) discard;
	ALBEDO.rgb = col;
}
