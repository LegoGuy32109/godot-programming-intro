extends Sprite2D

func _process(_delta: float) -> void:
	if Utils.space_pressed():
		if visible: 
			visible = false
		else:
			visible = true
			World.say("Boo!!")
