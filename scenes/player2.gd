extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	World.say("Hi!!")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Utils.key_just_pressed(KEY_J):
		World.say("I love you <3")
	if Utils.key_just_pressed(KEY_K):
		World.say("Hey Karly!!")
	pass
