extends Node2D
## Analytically timed snow and breath. Coordinates match the 1672 x 941 artwork.
## The parent owns time: call set_time(seconds) every frame or during movie export.

const LOOP_SECONDS: float = 12.0
const ART_SIZE: Vector2 = Vector2(1672.0, 941.0)
const SNOW_MARGIN: float = 32.0

@export var show_snow: bool = true
@export var show_breath: bool = true
@export var mouth_origin: Vector2 = Vector2(660.0, 379.0)
@export_range(0.0, 2.0) var breath_strength: float = 1.0

var render_time: float = 0.0
var _snow: Array[Dictionary] = []
var _soft_spot: GradientTexture2D


func _ready() -> void:
	_build_soft_spot()
	_build_snow()
	queue_redraw()


func set_time(seconds: float) -> void:
	render_time = fposmod(seconds, LOOP_SECONDS)
	queue_redraw()


func _build_soft_spot() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.20, 0.53, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.82),
		Color(1.0, 1.0, 1.0, 0.31),
		Color(1.0, 1.0, 1.0, 0.065),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_soft_spot = GradientTexture2D.new()
	_soft_spot.width = 64
	_soft_spot.height = 64
	_soft_spot.fill = GradientTexture2D.FILL_RADIAL
	_soft_spot.fill_from = Vector2(0.5, 0.5)
	_soft_spot.fill_to = Vector2(1.0, 0.5)
	_soft_spot.gradient = gradient


func _build_snow() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 261116
	_snow.clear()
	# Integer screen traversals and harmonics guarantee an exact 12-second loop.
	# Near particles fall faster and catch more light than the distant fine snow.
	var populations: Array[int] = [116, 48, 15]
	for layer in range(populations.size()):
		for index in range(populations[layer]):
			_snow.append({
				"x": random.randf_range(-25.0, ART_SIZE.x + 25.0),
				"offset": random.randf(),
				"angle": random.randf_range(0.0, TAU),
				"cycles": float(layer + 1),
				"sway": random.randf_range(6.0, 16.0) * float(layer + 1),
				"radius": random.randf_range(1.05, 1.8) + float(layer) * 1.25,
				"alpha": random.randf_range(0.18, 0.38) + float(layer) * 0.17,
				"layer": layer,
			})


func _draw() -> void:
	if _soft_spot == null:
		return
	if show_snow:
		_draw_snow()
	if show_breath:
		_draw_breath()


func _draw_snow() -> void:
	var angle: float = TAU * render_time / LOOP_SECONDS
	var height: float = ART_SIZE.y + SNOW_MARGIN * 2.0
	for flake in _snow:
		var phase: float = fposmod(
			render_time / LOOP_SECONDS * float(flake["cycles"]) + float(flake["offset"]),
			1.0
		)
		var x: float = float(flake["x"]) + sin(angle + float(flake["angle"])) * float(flake["sway"])
		x += sin(angle * 2.0 + float(flake["angle"]) * 0.7) * 4.0
		var y: float = -SNOW_MARGIN + height * phase
		var radius: float = float(flake["radius"])
		var alpha: float = float(flake["alpha"]) * (0.90 + 0.10 * sin(angle * 2.0 + float(flake["angle"])))
		var flake_size := Vector2(radius * 2.0, radius * 2.2)
		draw_texture_rect(
			_soft_spot,
			Rect2(Vector2(x, y) - flake_size * 0.5, flake_size),
			false,
			Color(0.92, 0.95, 1.0, alpha)
		)


func _draw_breath() -> void:
	# A short exhalation every four seconds: overlapping wisps spread and dissolve.
	# The mouth stays clear; no opaque circles or continuous smoke column.
	var cycle_time: float = fposmod(render_time, 4.0)
	for index in range(9):
		var delay: float = 0.12 + float(index) * 0.07
		var age: float = cycle_time - delay
		var lifetime: float = 1.80 + float(index % 3) * 0.10
		if age <= 0.0 or age >= lifetime:
			continue
		var progress: float = age / lifetime
		var fade_in: float = smoothstep(0.0, 0.12, age)
		var fade_out: float = 1.0 - smoothstep(0.22, 1.0, progress)
		var opacity: float = 0.17 * fade_in * fade_out * breath_strength
		var travel: float = 7.0 + progress * 140.0
		var lift: float = -2.0 - progress * 24.0
		lift += sin(progress * 4.5 + float(index) * 0.72) * (1.0 + progress * 4.0)
		var center: Vector2 = mouth_origin + Vector2(travel, lift)
		var spread: Vector2 = Vector2(16.0 + progress * 42.0, 9.0 + progress * 25.0)
		_draw_wisp(center, spread, opacity)
		# Offset lobes make the vapor diffuse into irregular soft filaments.
		_draw_wisp(center + Vector2(-4.0, -4.0 - progress * 2.0), spread * Vector2(0.62, 0.50), opacity * 0.58)
		_draw_wisp(center + Vector2(3.0, 3.0), spread * Vector2(0.55, 0.43), opacity * 0.40)


func _draw_wisp(center: Vector2, size: Vector2, opacity: float) -> void:
	draw_texture_rect(
		_soft_spot,
		Rect2(center - size * 0.5, size),
		false,
		Color(0.89, 0.91, 0.97, opacity)
	)
