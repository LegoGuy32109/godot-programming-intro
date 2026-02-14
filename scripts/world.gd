extends Node

const TEXT_BUBBLE_SCENE := preload("res://scenes/text_bubble.tscn")
const DEFAULT_VISIBLE_SECONDS := 3.0
const DEFAULT_FADE_SECONDS := 0.35

func say(message: String, visible_seconds: float = DEFAULT_VISIBLE_SECONDS, fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	var container := _get_text_bubble_container()
	if container == null:
		push_warning("World.say: Could not find Player/TextBubble container.")
		return

	var bubble := TEXT_BUBBLE_SCENE.instantiate() as Control
	if bubble == null:
		push_warning("World.say: text bubble scene root is not a Control.")
		return

	var label := bubble.get_node_or_null("MarginContainer/Label") as Label
	if label != null:
		label.text = message

	container.add_child(bubble)

	bubble.modulate.a = 0.0

	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(bubble, "modulate:a", 1.0, 0.4)

	var fade_tween := create_tween()
	fade_tween.tween_interval(maxf(visible_seconds, 0.0))
	fade_tween.tween_property(bubble, "modulate:a", 0.0, maxf(fade_seconds, 0.01))
	fade_tween.finished.connect(func() -> void:
		if is_instance_valid(bubble):
			bubble.queue_free()
	)

func _get_text_bubble_container() -> VBoxContainer:
	var scene := get_tree().current_scene
	if scene == null:
		return null

	var container := scene.get_node_or_null("%TextBubble") as VBoxContainer
	return container
