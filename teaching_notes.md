Go here [Godot Web Editor](https://editor.godotengine.org/releases/latest/) and load zip

# Syntax

GDscript uses indentation to indicate lines of code
Block based programming is like each line

## Printing

```gdscript
func _ready():
	print("Hello class!")
	print(visible)
	visible = false
	print(visible)
```

Hard to see? Ok, let's have the wizard say it.
```
	World.say("Hello class!")
```

## Comments

Using `#` to add comments in GDscript
it lets me know what I'm thinking
it can remove segments of code if i'm testing something

# Develop



## Modules

I want to hide the wizard if I press the spacebar

```
func _process():
	if Utils.space_pressed():
		hide()
```
```
	if Utils.space_pressed():
		if visible:
			hide()
		else:
			show()
```
```
	World.say("Boo")
```
