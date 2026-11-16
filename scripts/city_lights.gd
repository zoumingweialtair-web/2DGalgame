extends Node2D
## Source-aligned, deterministic 12-second city lighting overlays.
## Call configure(base_texture) after add_child(), then set_time(seconds).

const LOOP_SECONDS := 12.0
const SOURCE_SIZE := Vector2(1672.0, 941.0)

# Coordinates are measured on the approved 1672 x 941 illustration.
const BEACONS := [
	Vector2(125, 230), Vector2(139, 240), Vector2(114, 272),
	Vector2(145, 273), Vector2(117, 335), Vector2(142, 336),
	Vector2(173, 407), Vector2(239, 405),
	Vector2(1248, 284), Vector2(1273, 280), Vector2(1318, 284),
	Vector2(1511, 305), Vector2(1548, 322), Vector2(1640, 298),
	Vector2(1116, 391), Vector2(876, 426), Vector2(833, 426),
]

# Tight patches of existing warm window groups, never sky or the foreground rail.
const WINDOWS := [
	Rect2(1252, 373, 12, 10), Rect2(1282, 377, 12, 9),
	Rect2(1302, 381, 12, 10), Rect2(1250, 391, 15, 10),
	Rect2(1283, 408, 12, 10), Rect2(1300, 409, 13, 9),
	Rect2(1252, 419, 13, 11), Rect2(1283, 432, 12, 12),
	Rect2(1251, 440, 17, 11), Rect2(1316, 441, 10, 14),
	Rect2(1253, 453, 14, 11), Rect2(1281, 461, 12, 11),
	Rect2(1316, 465, 11, 12), Rect2(1250, 475, 19, 14),
	Rect2(1410, 438, 18, 27), Rect2(1432, 436, 17, 29),
	Rect2(1453, 435, 19, 29), Rect2(1475, 434, 20, 29),
	Rect2(1499, 433, 18, 28),
	Rect2(1454, 487, 19, 37), Rect2(1478, 486, 20, 38),
	Rect2(1503, 485, 20, 38), Rect2(1528, 484, 19, 39),
	Rect2(1551, 482, 18, 39),
	Rect2(1187, 526, 10, 12), Rect2(1204, 526, 10, 12),
	Rect2(1151, 576, 11, 12), Rect2(1166, 577, 11, 12),
]

# A sparse selection avoids making the entire facade appear to breathe.
const ACTIVE_WINDOW_INDICES := [14, 15, 16, 17, 19, 20, 21, 22]
const WINDOW_PHASES := [0.0, 2.0, 4.5, 7.0, 9.0, 1.3, 5.5, 10.0]

const WINDOW_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform float darkness = 0.0;
uniform vec4 patch_bounds;
uniform vec2 source_size = vec2(1672.0, 941.0);
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec2 p = UV * source_size;
	vec2 edge_distance = min(p - patch_bounds.xy, patch_bounds.xy + patch_bounds.zw - p);
	float feather = smoothstep(0.0, 1.0, min(edge_distance.x, edge_distance.y));
	float luminance = dot(src.rgb, vec3(0.33, 0.51, 0.16));
	float warm = smoothstep(0.01, 0.10, src.r - src.b);
	float bright = smoothstep(0.30, 0.60, luminance);
	float white_light = smoothstep(0.75, 0.90, luminance);
	float mask = max(warm * bright, white_light) * feather;
	// Unlit rooms retain cool skylight, rather than turning into black cutouts.
	vec3 unlit = vec3(0.20, 0.22, 0.29) + src.rgb * 0.12;
	COLOR = vec4(unlit, darkness * mask);
}
"""

const BEACON_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 center_px;
uniform vec2 source_size = vec2(1672.0, 941.0);
uniform float pulse = 1.0;
void fragment() {
	vec2 p = UV * source_size;
	float d = distance(p, center_px);
	vec3 src = texture(TEXTURE, UV).rgb;
	float red_chroma = smoothstep(0.035, 0.20, src.r - max(src.g, src.b));
	float luminous = smoothstep(0.48, 0.83, max(src.r, src.g));
	float white_core = (1.0 - smoothstep(0.9, 2.8, d)) * smoothstep(0.75, 0.93, src.r);
	float radial = 1.0 - smoothstep(2.5, 9.5, d);
	float mask = radial * max(red_chroma * luminous, white_core);
	// Restore ambient color only underneath emissive pixels, not the full patch.
	// This extinguishes the light without multiplying its core into a black dot.
	vec2 c = center_px / source_size;
	vec3 ambient = (
		texture(TEXTURE, c + vec2(-12.0, -11.0) / source_size).rgb +
		texture(TEXTURE, c + vec2(12.0, -11.0) / source_size).rgb
	) * 0.5;
	COLOR = vec4(mix(src, ambient, (1.0 - pulse) * 0.96), mask);
}
"""

var render_time := 0.0
var _window_materials: Array[ShaderMaterial] = []
var _beacon_materials: Array[ShaderMaterial] = []


func configure(source_texture: Texture2D) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_window_materials.clear()
	_beacon_materials.clear()
	var window_shader := Shader.new()
	window_shader.code = WINDOW_SHADER
	var beacon_shader := Shader.new()
	beacon_shader.code = BEACON_SHADER
	for index: int in ACTIVE_WINDOW_INDICES:
		var area: Rect2 = WINDOWS[index]
		var mat := ShaderMaterial.new()
		mat.shader = window_shader
		mat.set_shader_parameter("patch_bounds", Vector4(area.position.x, area.position.y, area.size.x, area.size.y))
		_add_patch(source_texture, area, mat)
		_window_materials.append(mat)
	for point: Vector2 in BEACONS:
		var mat := ShaderMaterial.new()
		mat.shader = beacon_shader
		mat.set_shader_parameter("center_px", point)
		_add_patch(source_texture, Rect2(point - Vector2(11, 11), Vector2(22, 22)), mat)
		_beacon_materials.append(mat)
	set_time(render_time)


func _add_patch(source_texture: Texture2D, area: Rect2, shader_material: ShaderMaterial) -> void:
	var patch := Sprite2D.new()
	patch.centered = false
	patch.texture = source_texture
	patch.region_enabled = true
	patch.region_rect = area
	patch.position = area.position
	patch.material = shader_material
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(patch)


func set_time(seconds: float) -> void:
	render_time = fposmod(seconds, LOOP_SECONDS)
	for i in _window_materials.size():
		# Eight visible rooms switch independently, with long on/off holds.
		var phase: float = WINDOW_PHASES[i]
		var local := fposmod(render_time + phase, LOOP_SECONDS)
		var fade := 0.45 + float(i % 3) * 0.10
		var hold_end := 4.8 + float(i % 3) * 0.30
		var amount := smoothstep(0.65, 0.65 + fade, local) * (1.0 - smoothstep(hold_end, hold_end + fade, local))
		_window_materials[i].set_shader_parameter("darkness", amount)
	for i in _beacon_materials.size():
		# Tower-mates flash together; 3/4/6-second periods all divide the full loop.
		var group := 0 if i < 6 else (1 if i < 8 else (2 if i < 11 else (3 if i < 14 else 4)))
		var periods := [3.0, 4.0, 3.0, 6.0, 4.0]
		var offsets := [0.18, 1.1, 0.74, 2.4, 1.8]
		var wave := 0.5 + 0.5 * cos(TAU * (render_time + offsets[group]) / periods[group])
		var pulse := smoothstep(0.34, 0.78, wave)
		_beacon_materials[i].set_shader_parameter("pulse", pulse)
	queue_redraw()
