extends Node2D

const MAX_HEALTH := 100.0
const HIT_DAMAGE := 20.0
const INVULNERABILITY_SECONDS := 0.5
const HIT_FLASH_COLOR := Color(1.0, 0.2, 0.2, 1.0)
const GAME_OVER_FADE_SECONDS := 4.0
const GAME_OVER_OVERLAY_LAYER := 1000
const GameOverScene := preload("res://scenes/game_over.tscn")

@onready var health_bar: TextureProgressBar = $HealthBar
@onready var player_sprite: Sprite2D = $Sprite
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var death_sound: AudioStreamPlayer2D = $DeathSound

var _health := MAX_HEALTH
var _invulnerable_until := 0.0
var _hit_fade_tween: Tween
var _is_dead := false

func _ready() -> void:
	_update_health_bar()

func _process(_delta: float) -> void:
	if _is_dead:
		return

	_try_take_enemy_hit()

func _try_take_enemy_hit() -> void:
	if _is_invulnerable():
		return

	for node in get_tree().get_nodes_in_group("Enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.global_position.is_equal_approx(global_position):
			_take_hit()
			return

func _take_hit() -> void:
	if _is_dead:
		return

	_health = clampf(_health - HIT_DAMAGE, 0.0, MAX_HEALTH)
	if hurt_sound != null:
		hurt_sound.play()
	_update_health_bar()
	if _health <= 0.0:
		_die()
		return

	_invulnerable_until = Time.get_ticks_msec() / 1000.0 + INVULNERABILITY_SECONDS
	_play_hit_flash()

func _die() -> void:
	_is_dead = true
	_invulnerable_until = Time.get_ticks_msec() / 1000.0 + INVULNERABILITY_SECONDS
	if _hit_fade_tween != null:
		_hit_fade_tween.kill()

	player_sprite.rotation_degrees = 90.0
	player_sprite.self_modulate = HIT_FLASH_COLOR
	if death_sound != null:
		death_sound.play()

	var game_over_overlay := GameOverScene.instantiate() as Control
	if game_over_overlay == null:
		return

	game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_overlay.offset_left = 0.0
	game_over_overlay.offset_top = 0.0
	game_over_overlay.offset_right = 0.0
	game_over_overlay.offset_bottom = 0.0
	game_over_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "GameOverOverlayLayer"
	overlay_layer.layer = GAME_OVER_OVERLAY_LAYER
	overlay_layer.add_child(game_over_overlay)

	var overlay_host := get_tree().current_scene
	if overlay_host != null:
		overlay_host.add_child(overlay_layer)
	else:
		get_tree().root.add_child(overlay_layer)

	var fade_in := create_tween()
	fade_in.tween_property(game_over_overlay, "modulate:a", 1.0, GAME_OVER_FADE_SECONDS)

func _play_hit_flash() -> void:
	if _hit_fade_tween != null:
		_hit_fade_tween.kill()

	player_sprite.self_modulate = HIT_FLASH_COLOR
	_hit_fade_tween = create_tween()
	_hit_fade_tween.tween_property(player_sprite, "self_modulate", Color.WHITE, INVULNERABILITY_SECONDS)

func _update_health_bar() -> void:
	health_bar.max_value = MAX_HEALTH
	health_bar.value = _health
	health_bar.visible = _health < MAX_HEALTH

func _is_invulnerable() -> bool:
	return Time.get_ticks_msec() / 1000.0 < _invulnerable_until

func is_dead() -> bool:
	return _is_dead
