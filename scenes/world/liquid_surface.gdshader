shader_type canvas_item;
render_mode unshaded;
uniform sampler2D terrain_atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 region_px = vec4(8.0, 136.0, 32.0, 32.0);
uniform vec2 atlas_size = vec2(192.0, 272.0);
uniform vec2 pool_size = vec2(192.0, 128.0);
uniform bool is_acid = false;
void fragment() {
	vec2 pixel = floor(UV * pool_size);
	vec2 drift = vec2(sin(pixel.y * 0.09 + TIME * 0.7), cos(pixel.x * 0.07 + TIME * 0.55));
	vec2 tile_pixel = mod(floor(pixel + drift * 0.8 + vec2(TIME * 0.65, TIME * 0.3)), region_px.zw);
	vec2 atlas_uv = (region_px.xy + tile_pixel + vec2(0.5)) / atlas_size;
	vec4 surface = texture(terrain_atlas, atlas_uv);
	float shimmer = sin(pixel.x * 0.19 + pixel.y * 0.11 + TIME * 1.0) * 0.045;
	surface.rgb *= 1.0 + shimmer;
	if (is_acid) {
		vec2 cell = floor(pixel / 22.0);
		float phase = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		float cycle = fract(TIME * 0.22 + phase);
		float d = length(mod(pixel, 22.0) - vec2(11.0));
		float ring = step(abs(d - cycle * 4.0), 0.65) * step(cycle, 0.75) * step(0.45, phase);
		surface.rgb = mix(surface.rgb, vec3(1.0, 0.94, 0.38), ring * 0.65);
	}
	COLOR = vec4(surface.rgb, 1.0);
}
