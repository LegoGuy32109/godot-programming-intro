extends Node2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

var _resolving := false

func resolve_impact() -> void:
	if _resolving:
		return
	_resolving = true

	visible = false
	if _sprite != null:
		_sprite.stop()

	if _audio != null and _audio.playing:
		await _audio.finished

	queue_free()
