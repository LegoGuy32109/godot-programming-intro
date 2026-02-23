extends CanvasLayer

const TRANSITION_RADIUS_OPEN := 2.0
const TRANSITION_RADIUS_CLOSED := 0.0
const TRANSITION_DURATION := 0.35
const OPEN_RADIUS_MARGIN := 0.05

var _overlay: ColorRect
var _shader_material: ShaderMaterial
var _busy := false

static func get_or_create(tree: SceneTree):
	var existing := tree.root.get_node_or_null("SceneTransition")
	if existing != null:
		return existing as CanvasLayer

	var transition := preload("res://scripts/scene_transition.gd").new()
	transition.name = "SceneTransition"
	tree.root.add_child(transition)
	return transition

func _ready() -> void:
	layer = 100

	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color("ba6f42")
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius = 1.5;
uniform vec4 wipe_color : source_color = vec4(0.7294, 0.4353, 0.2588, 1.0);

void fragment() {
	vec2 delta = SCREEN_UV - center;
	delta.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float dist = length(delta);
	float alpha = step(radius, dist);
	COLOR = vec4(wipe_color.rgb, wipe_color.a * alpha);
}
"""

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("radius", TRANSITION_RADIUS_OPEN)
	_shader_material.set_shader_parameter("wipe_color", Color("ba6f42"))
	_overlay.material = _shader_material

func transition_to_scene(scene_path: String, center_uv: Vector2 = Vector2(0.5, 0.5)) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_shader_material.set_shader_parameter("center", center_uv)
	var open_radius := _get_open_radius(center_uv)
	await _animate_radius(open_radius, TRANSITION_RADIUS_CLOSED)

	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error("SceneTransition: failed to load %s (error %d)" % [scene_path, change_error])
		await _animate_radius(TRANSITION_RADIUS_CLOSED, open_radius)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
		return

	await get_tree().process_frame
	await _animate_radius(TRANSITION_RADIUS_CLOSED, open_radius)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func transition_to_scene_fade(scene_path: String, duration_seconds: float = 4.0, fade_color: Color = Color.BLACK) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_overlay.material = null
	_overlay.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)

	var fade_out := create_tween()
	fade_out.tween_property(_overlay, "color:a", 1.0, duration_seconds)
	await fade_out.finished

	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error("SceneTransition: failed to load %s (error %d)" % [scene_path, change_error])
		var recover := create_tween()
		recover.tween_property(_overlay, "color:a", 0.0, 0.2)
		await recover.finished
		_restore_wipe_material()
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
		return

	await get_tree().process_frame
	_overlay.color.a = 0.0
	_restore_wipe_material()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func transition_replace_level(level_container: Node, scene_path: String, center_uv: Vector2 = Vector2(0.5, 0.5)) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	_shader_material.set_shader_parameter("center", center_uv)
	var open_radius := _get_open_radius(center_uv)
	await _animate_radius(open_radius, TRANSITION_RADIUS_CLOSED)

	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("SceneTransition: failed to load packed scene %s" % scene_path)
		await _animate_radius(TRANSITION_RADIUS_CLOSED, open_radius)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
		return

	if level_container != null and level_container.get_child_count() > 0:
		level_container.get_child(0).queue_free()

	if level_container != null:
		level_container.add_child(packed_scene.instantiate())
	else:
		push_error("SceneTransition: level_container is null.")

	await get_tree().process_frame
	await _animate_radius(TRANSITION_RADIUS_CLOSED, open_radius)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _animate_radius(from_radius: float, to_radius: float) -> void:
	_shader_material.set_shader_parameter("radius", from_radius)
	var tween := create_tween()
	tween.tween_property(_shader_material, "shader_parameter/radius", to_radius, TRANSITION_DURATION)
	await tween.finished

func _get_open_radius(center_uv: Vector2) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return TRANSITION_RADIUS_OPEN

	var aspect := viewport_size.x / viewport_size.y
	var corners: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
	]
	var max_distance := 0.0
	for corner: Vector2 in corners:
		var delta: Vector2 = corner - center_uv
		delta.x *= aspect
		max_distance = maxf(max_distance, delta.length())

	return max_distance + OPEN_RADIUS_MARGIN

func _restore_wipe_material() -> void:
	_overlay.material = _shader_material
	_overlay.color = Color("ba6f42")
	_shader_material.set_shader_parameter("radius", TRANSITION_RADIUS_OPEN)
	_shader_material.set_shader_parameter("wipe_color", Color("ba6f42"))
