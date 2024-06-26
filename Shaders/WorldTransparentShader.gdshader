shader_type spatial;
render_mode world_vertex_coords;

uniform sampler2D text : source_color, filter_nearest, repeat_enable;

const float roundFactor = 0.1;
void vertex() {
	vec3 vert = VERTEX;
	vert /= roundFactor;
	VERTEX = vec3(round(vert.x), round(vert.y), round(vert.z)) * roundFactor;
}

void fragment() {
	vec4 col = texture(text, UV);
	ALPHA = col.a;
	ALBEDO.rgb = col.rgb;
}
