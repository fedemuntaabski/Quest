shader_type canvas_item;

// Hit feedback: blends the sprite towards pure white (modulate can't exceed 1).
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a) * COLOR;
}
