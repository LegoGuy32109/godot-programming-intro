extends Node

const TEXT_BUBBLE_SCENE := preload("res://scenes/text_bubble.tscn")
const FIREBALL_SCENE := preload("res://scenes/Effects/fireball.tscn")
const FIRE_SCENE := preload("res://scenes/Effects/fire.tscn")

const DEFAULT_VISIBLE_SECONDS := 3.0
const DEFAULT_FADE_SECONDS := 0.35
const FIREBALL_STEP_SECONDS := 0.1
const IMPASSABLE_CUSTOM_DATA := "IMPASSABLE"

var _last_player_direction := Vector2i.RIGHT

func set_last_player_direction(direction: Vector2i) -> void:
	if direction == Vector2i.ZERO:
		return

	_last_player_direction = Vector2i(signi(direction.x), signi(direction.y))

func cast(spell: int) -> void:
	match spell:
		Spells.Fireball:
			_cast_fireball()
		_:
			push_warning("World.cast: Unknown spell id: %s" % spell)

func _cast_fireball() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return

	var player := scene.get_node_or_null("PlayerContainer/Player") as Node2D
	if player == null:
		player = scene.find_child("Player", true, false) as Node2D
	if player == null:
		push_warning("World.cast: Could not find Player node.")
		return

	var ground := _get_ground_layer(scene)
	if ground == null:
		push_warning("World.cast: Could not find Ground tile layer.")
		return

	var structures := _get_structures_layer(scene)
	var start_tile := _world_to_tile(ground, player.global_position)
	var direction := _last_player_direction
	var first_tile := start_tile + direction

	if _is_blocked_for_fireball(ground, structures, first_tile):
		return

	var fireball := FIREBALL_SCENE.instantiate() as Node2D
	if fireball == null:
		push_warning("World.cast: fireball scene root is not Node2D.")
		return

	scene.add_child(fireball)
	fireball.rotation = Vector2.RIGHT.angle_to(Vector2(direction))
	fireball.global_position = _tile_to_world(ground, first_tile)
	if _try_hit_enemy_on_tile(scene, ground, first_tile):
		if fireball.has_method("resolve_impact"):
			fireball.call("resolve_impact")
		else:
			fireball.queue_free()
		return

	_travel_fireball(scene, fireball, ground, structures, first_tile, direction)

func _travel_fireball(
	scene: Node,
	fireball: Node2D,
	ground: TileMapLayer,
	structures: TileMapLayer,
	start_tile: Vector2i,
	direction: Vector2i
) -> void:
	var tile := start_tile

	while true:
		if not is_instance_valid(fireball):
			return

		await get_tree().create_timer(FIREBALL_STEP_SECONDS).timeout

		var next_tile := tile + direction
		if _is_blocked_for_fireball(ground, structures, next_tile):
			break

		tile = next_tile
		fireball.global_position = _tile_to_world(ground, tile)
		if _try_hit_enemy_on_tile(scene, ground, tile):
			break

	if is_instance_valid(fireball):
		if fireball.has_method("resolve_impact"):
			fireball.call("resolve_impact")
		else:
			fireball.queue_free()

func _try_hit_enemy_on_tile(scene: Node, ground: TileMapLayer, tile: Vector2i) -> bool:
	var enemy := _find_enemy_on_tile(scene, ground, tile)
	if enemy == null:
		return false

	var fire := FIRE_SCENE.instantiate() as Node2D
	if fire != null:
		scene.add_child(fire)
		fire.global_position = _tile_to_world(ground, tile)

	enemy.queue_free()
	return true

func _find_enemy_on_tile(scene: Node, ground: TileMapLayer, tile: Vector2i) -> Node2D:
	for node in get_tree().get_nodes_in_group("Enemies"):
		if not scene.is_ancestor_of(node):
			continue

		var enemy := node as Node2D
		if enemy == null or enemy.is_queued_for_deletion():
			continue

		if _world_to_tile(ground, enemy.global_position) == tile:
			return enemy

	return null

func _is_blocked_for_fireball(ground: TileMapLayer, structures: TileMapLayer, tile: Vector2i) -> bool:
	if ground.get_cell_source_id(tile) == -1:
		return true

	if structures == null:
		return false

	var tile_data := structures.get_cell_tile_data(tile)
	if tile_data == null:
		return false

	return bool(tile_data.get_custom_data(IMPASSABLE_CUSTOM_DATA))

func _world_to_tile(ground: TileMapLayer, world_position: Vector2) -> Vector2i:
	var local_position := ground.to_local(world_position)
	return ground.local_to_map(local_position)

func _tile_to_world(ground: TileMapLayer, tile: Vector2i) -> Vector2:
	var local_position := ground.map_to_local(tile)
	return ground.to_global(local_position)

func say(message: String, visible_seconds: float = DEFAULT_VISIBLE_SECONDS, fade_seconds: float = DEFAULT_FADE_SECONDS) -> void:
	var container := _get_text_bubble_container()
	if container == null:
		push_warning("World.say: Could not find TextBubble container.")
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

	var direct := scene.get_node_or_null("PlayerContainer/Player/ScrollContainer/TextBubble") as VBoxContainer
	if direct != null:
		return direct

	var fallback := scene.find_child("TextBubble", true, false) as VBoxContainer
	return fallback

func _get_ground_layer(scene: Node) -> TileMapLayer:
	var level_container := scene.get_node_or_null("LevelContainer")
	if level_container == null or level_container.get_child_count() == 0:
		return null

	var active_level := level_container.get_child(0)
	return active_level.get_node_or_null("Ground") as TileMapLayer

func _get_structures_layer(scene: Node) -> TileMapLayer:
	var level_container := scene.get_node_or_null("LevelContainer")
	if level_container == null or level_container.get_child_count() == 0:
		return null

	var active_level := level_container.get_child(0)
	return active_level.get_node_or_null("Structures") as TileMapLayer
