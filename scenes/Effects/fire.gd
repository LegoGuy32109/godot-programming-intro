extends Node2D

@onready var _audio: AudioStreamPlayer2D = $AnimatedSprite2D/AudioStreamPlayer2D

func _ready() -> void:
	if _audio != null and _audio.playing:
		await _audio.finished
	queue_free()
