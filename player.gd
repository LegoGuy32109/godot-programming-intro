extends Sprite2D

func _process(_delta: float) -> void:
	if Utils.space_pressed():
		World.say("I love you Karly")
