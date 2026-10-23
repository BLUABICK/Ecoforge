shader_type canvas_item;
render_mode unshaded;
uniform float wind_strength : hint_range(0.0, 1.5) = 0.85;
uniform float wind_clock = -1.0;
varying vec2 world_pixel;
void vertex() {
	world_pixel = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
bool is_grass(vec3 color) {
	return color.r > 0.25 && color.r > color.g * 1.35 && color.r > color.b * 1.4;
}
void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 result = base;
	if (is_grass(base.rgb)) {
		float time = wind_clock >= 0.0 ? wind_clock : TIME;
		float gust = sin(time * 1.35 + world_pixel.x * 0.019 + world_pixel.y * 0.011);
		float ripple = sin(time * 2.0 + world_pixel.y * 0.095) * 0.18;
		vec2 atlas_size = vec2(textureSize(TEXTURE, 0));
		vec2 pixel = UV * atlas_size;
		vec2 tile_start = floor(pixel / 16.0) * 16.0;
		vec2 bent = pixel + vec2((gust + ripple) * wind_strength, 0.0);
		bent = clamp(bent, tile_start + vec2(0.5), tile_start + vec2(15.5));
		vec4 moved = texture(TEXTURE, bent / atlas_size);
		// Keep the terrain boundary and shoreline fixed; only move red blade detail.
		if (is_grass(moved.rgb)) { result = mix(base, moved, 0.8); }
		result.rgb *= 1.0 + gust * 0.018;
	}
	COLOR = result;
}
