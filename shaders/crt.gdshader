// Efeito de monitor CRT: curvatura, scanlines, aberração cromática,
// vinheta, ruído e glitch controlado pelo jogo.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.07;
uniform float vignette : hint_range(0.0, 2.0) = 0.55;
uniform float aberration : hint_range(0.0, 0.01) = 0.0006;
uniform float curvature : hint_range(0.0, 0.2) = 0.015;
uniform float noise : hint_range(0.0, 0.2) = 0.008;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	c *= 1.0 + curvature * dot(c, c);
	vec2 uv = c * 0.5 + 0.5;

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		if (glitch > 0.0) {
			float band = floor(uv.y * 36.0);
			float n = rand(vec2(band, floor(TIME * 24.0)));
			if (n < glitch * 0.6) {
				uv.x += (rand(vec2(band, TIME)) - 0.5) * 0.08 * glitch;
			}
		}

		float ab = aberration + glitch * 0.008;
		vec3 col;
		col.r = texture(screen_texture, uv + vec2(ab, 0.0)).r;
		col.g = texture(screen_texture, uv).g;
		col.b = texture(screen_texture, uv - vec2(ab, 0.0)).b;

		float line = sin(uv.y / SCREEN_PIXEL_SIZE.y * 3.14159) * 0.5 + 0.5;
		col *= 1.0 - scanline_strength * line;

		float v = 1.0 - vignette * 0.35 * dot(c, c);
		col *= clamp(v, 0.0, 1.0);

		col += (rand(uv + fract(TIME)) - 0.5) * noise;
		COLOR = vec4(col, 1.0);
	}
}
