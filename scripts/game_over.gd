extends PanelContainer

@onready var restart_button: Button = $ButtonControl/RestartButton
func _ready() -> void:
	call_deferred("_focus_restart_button")

func _focus_restart_button() -> void:
	if restart_button != null:
		restart_button.grab_focus()
