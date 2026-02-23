extends PanelContainer

const START_SCENE_PATH := "res://scenes/start.tscn"
const FOCUS_DELAY_SECONDS := 2.0

@onready var restart_button: Button = $ButtonControl/RestartButton

func _ready() -> void:
	add_to_group("GameOverOverlay")
	restart_button.pressed.connect(_on_restart_button_pressed)
	restart_button.focus_mode = Control.FOCUS_NONE
	call_deferred("_focus_restart_button")

func _focus_restart_button() -> void:
	await get_tree().create_timer(FOCUS_DELAY_SECONDS).timeout
	restart_button.focus_mode = Control.FOCUS_ALL
	if restart_button != null:
		restart_button.grab_focus()

func _on_restart_button_pressed() -> void:
	restart_button.disabled = true
	var error := get_tree().change_scene_to_file(START_SCENE_PATH)
	if error != OK:
		restart_button.disabled = false
		push_error("GameOver: failed to load %s (error %d)" % [START_SCENE_PATH, error])
		return

	queue_free()
