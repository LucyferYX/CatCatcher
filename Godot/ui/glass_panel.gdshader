shader_type canvas_item;
// Frosted glass for UI panels.
// Blurs whatever is already drawn behind the panel, then lays the panel's own
// colour (from the theme's StyleBoxFlat: background, border) on top of it.
// The shadow around the panel is drawn normally (not blurred).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 rect_size = vec2(100.0);       // panel size in pixels (set by glass_panel.gd)
uniform vec4 corner_radii = vec4(0.0);      // top-left, top-right, bottom-right, bottom-left
uniform float blur_px = 12.0;               // how far the blur reaches, in screen pixels
uniform float frost = 0.06;                 // a little white haze, makes it look like glass

varying vec2 local_pos;                     // pixel position inside the panel

void vertex() {
	local_pos = VERTEX;
}

// Distance to the edge of a rounded rectangle (negative = inside).
float rounded_box(vec2 p, vec2 half_size, vec4 r) {
	float rad = p.x < 0.0 ? (p.y < 0.0 ? r.x : r.w) : (p.y < 0.0 ? r.y : r.z);
	vec2 q = abs(p) - half_size + rad;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rad;
}

// Average of 32 screen samples spread over a disc (a cheap single-pass blur).
vec3 blurred(vec2 uv, vec2 px) {
	vec3 sum = vec3(0.0);
	float wsum = 0.0;
	for (int i = 0; i < 32; i++) {
		float t = (float(i) + 0.5) / 32.0;
		float angle = float(i) * 2.39996;            // golden angle spreads samples evenly
		vec2 offset = vec2(cos(angle), sin(angle)) * sqrt(t) * blur_px * px;
		float w = 1.0 - 0.6 * t;                     // closer samples count more
		sum += texture(screen_tex, uv + offset).rgb * w;
		wsum += w;
	}
	return sum / wsum;
}

void fragment() {
	vec4 c = COLOR;   // what the StyleBoxFlat wants to draw here
	float d = rounded_box(local_pos - rect_size * 0.5, rect_size * 0.5, corner_radii);
	float inside = clamp(0.5 - d, 0.0, 1.0);   // 1 inside the panel, 0 outside, soft edge
	if (inside > 0.0) {
		vec3 glass = mix(blurred(SCREEN_UV, SCREEN_PIXEL_SIZE), vec3(1.0), frost);
		vec4 frosted = vec4(mix(glass, c.rgb, c.a), 1.0);
		COLOR = mix(c, frosted, inside);
	}
}
