extends Node2D
## Every effect uses a shared analytical clock, including offline captures.

const LOOP_SECONDS := 12.0
const FPS := 30.0
const SOURCE := preload("res://assets/animation/balcony_open.png")
const CLOSED := preload("res://assets/animation/balcony_closed.png")
const Ambient := preload("res://scripts/ambient.gd")
const CityLights := preload("res://scripts/city_lights.gd")

var clock := 0.0
var paused := false
var capture_frame := 0
var recording := false
var portrait_material: ShaderMaterial
var ambient: Node2D
var city_lights: Node2D
var still_time := -1.0
var still_path := ""
var capture_wait := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for argument in args:
		if argument.begins_with("--still-time="):
			still_time = argument.trim_prefix("--still-time=").to_float()
		if argument.begins_with("--still-path="):
			still_path = argument.trim_prefix("--still-path=")
	recording = OS.get_cmdline_args().has("--write-movie")
	var portrait := Sprite2D.new()
	portrait.texture = SOURCE
	portrait.centered = false
	portrait_material = ShaderMaterial.new()
	portrait_material.shader = preload("res://shaders/portrait.gdshader")
	portrait_material.set_shader_parameter("closed_frame", CLOSED)
	portrait.material = portrait_material
	add_child(portrait)
	city_lights = CityLights.new()
	add_child(city_lights)
	city_lights.configure(SOURCE)
	ambient = Ambient.new()
	add_child(ambient)
	_update_frame(0.0)


func _process(delta: float) -> void:
	if still_time >= 0.0:
		_update_frame(still_time)
		capture_wait += 1
		if capture_wait == 4:
			_save_still.call_deferred()
		return
	if recording:
		clock = float(capture_frame) / FPS
		capture_frame += 1
	elif not paused:
		clock += delta
	_update_frame(fposmod(clock, LOOP_SECONDS))


func _update_frame(seconds: float) -> void:
	var t := fposmod(seconds, LOOP_SECONDS)
	portrait_material.set_shader_parameter("loop_time", t)
	portrait_material.set_shader_parameter("blink", blink_at(t))
	city_lights.set_time(t)
	ambient.set_time(t)


func blink_at(t: float) -> float:
	var amount := 0.0
	# Close in 0.22 s, rest for 0.12 s, reopen gently over 0.34 s.
	# Two relaxed blinks per loop, without the former quick double blink.
	for start in [2.65, 8.05]:
		var elapsed: float = t - start
		var close_amount: float = smoothstep(0.0, 0.22, elapsed)
		var open_amount: float = 1.0 - smoothstep(0.34, 0.68, elapsed)
		amount = maxf(amount, close_amount * open_amount)
	return amount


func _save_still() -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(still_path)
	if result != OK:
		push_error("Could not save preview frame: " + still_path)
	get_tree().quit(result)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventKey:
		match event.physical_keycode:
			KEY_SPACE:
				paused = not paused
			KEY_R:
				clock = 0.0
			KEY_F:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
