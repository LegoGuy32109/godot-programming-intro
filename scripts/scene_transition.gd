extends CanvasLayer

const TRANSITION_RADIUS_OPEN := 1.5
const TRANSITION_RADIUS_CLOSED := 0.0
const TRANSITION_DURATION := 0.35

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
	await _animate_radius(TRANSITION_RADIUS_OPEN, TRANSITION_RADIUS_CLOSED)

	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error != OK:
		push_error("SceneTransition: failed to load %s (error %d)" % [scene_path, change_error])
		await _animate_radius(TRANSITION_RADIUS_CLOSED, TRANSITION_RADIUS_OPEN)
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false
		return

	await get_tree().process_frame
	await _animate_radius(TRANSITION_RADIUS_CLOSED, TRANSITION_RADIUS_OPEN)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _animate_radius(from_radius: float, to_radius: float) -> void:
	_shader_material.set_shader_parameter("radius", from_radius)
	var tween := create_tween()
	tween.tween_property(_shader_material, "shader_parameter/radius", to_radius, TRANSITION_DURATION)
	await tween.finished
