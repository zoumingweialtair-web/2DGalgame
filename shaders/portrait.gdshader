shader_type canvas_item;
render_mode unshaded;

uniform sampler2D closed_frame : source_color, filter_linear;
uniform float loop_time = 0.0;
uniform float blink = 0.0;
uniform float motion_strength = 1.0;

float ellipse_mask(vec2 p, vec2 center, vec2 radius, float feather) {
	float d = length((p - center) / radius);
	return 1.0 - smoothstep(1.0 - feather, 1.0, d);
}

void fragment() {
	vec2 size = vec2(1672.0, 941.0);
	vec2 p = UV * size;
	float phase = loop_time * 6.28318530718 / 12.0;
	float breathing = sin(phase * 3.0);
	vec2 delta = vec2(0.0);

	// Soft, spatially local deformations keep the camera and skyline still.
	float hair_edge = 535.0 - smoothstep(300.0, 920.0, p.y) * 133.0;
	float long_hair = smoothstep(210.0, 290.0, p.x)
		* (1.0 - smoothstep(hair_edge - 25.0, hair_edge + 40.0, p.x))
		* smoothstep(280.0, 510.0, p.y);
	float hair_flex = mix(0.35, 1.0, smoothstep(360.0, 900.0, p.y));
	delta.x += long_hair * hair_flex * (5.8 * sin(phase * 2.0 - p.y * 0.006) + 1.8 * sin(phase * 3.0 + p.y * 0.012));
	delta.y += long_hair * 1.1 * sin(phase * 2.0 + p.y * 0.008);

	float fringe = ellipse_mask(p, vec2(752.0, 230.0), vec2(65.0, 174.0), 0.5)
		* smoothstep(716.0, 759.0, p.x);
	delta.x += fringe * 2.1 * sin(phase * 2.0 - p.y * 0.01);
	float crown = ellipse_mask(p, vec2(565.0, 145.0), vec2(204.0, 122.0), 0.5);
	delta.x += crown * 0.65 * sin(phase * 2.0);

	float scarf_center = 675.0 + (p.y - 500.0) * 0.47;
	float scarf = (1.0 - smoothstep(36.0, 85.0, abs(p.x - scarf_center)))
		* smoothstep(480.0, 640.0, p.y) * (1.0 - smoothstep(825.0, 855.0, p.y));
	delta.x += scarf * (6.5 * sin(phase * 2.0 - p.y * 0.008) + 1.6 * sin(phase * 3.0));
	delta.y += scarf * 2.2 * sin(phase * 2.0 + 0.9);
	float chest = ellipse_mask(p, vec2(594.0, 690.0), vec2(206.0, 260.0), 0.55);
	delta.y += chest * 1.35 * breathing;
	vec2 sample_uv = (p - delta * motion_strength) / size;
	vec4 base = texture(TEXTURE, sample_uv);

	// Only small feathered eye regions use the registered closed-eye drawing.
	vec2 eye_p = sample_uv * size;
	float left_eye = ellipse_mask(eye_p, vec2(578.0, 303.0), vec2(49.0, 39.0), 0.24);
	float right_eye = ellipse_mask(eye_p, vec2(704.0, 282.0), vec2(39.0, 39.0), 0.24);
	// The upper lid sweeps down, instead of dissolving two visible eyes together.
	bool is_left = eye_p.x < 640.0;
	float travel = is_left ? 28.0 : 24.0;
	float closed_y = is_left ? 313.0 : 294.0;
	float center_x = is_left ? 578.0 : 704.0;
	float offset_y = (1.0 - blink) * travel;
	float lid_y = closed_y - offset_y - (eye_p.x - center_x) * 0.12;
	float sweep = 1.0 - smoothstep(lid_y + 1.0, lid_y + 5.0, eye_p.y);
	sweep = mix(sweep, 1.0, smoothstep(0.78, 0.98, blink));
	float eyelid = max(left_eye, right_eye) * sweep * smoothstep(0.0, 0.09, blink);
	vec2 lid_uv = sample_uv + vec2(0.0, offset_y / size.y);
	COLOR = mix(base, texture(closed_frame, lid_uv), eyelid);
}
