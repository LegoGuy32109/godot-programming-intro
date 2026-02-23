extends Node2D

const IMPASSABLE_CUSTOM_DATA := "IMPASSABLE"
const DOOR_PATTERN_INDEX := 1
const MIN_ENEMIES := 2
const MAX_ENEMIES := 6
const SPAWN_NODE_PREFIX := "RandomEnemySpawn_"

@onready var ground: TileMapLayer = $Ground
@onready var structures: TileMapLayer = $Structures

var _enemy_templates: Array[Sprite2D] = []

func _ready() -> void:
	randomize()
	_cache_enemy_templates()
	_clear_enemy_spawns()
	_clear_door_tiles()
	_spawn_random_enemies()
	_place_random_door_pattern()

func _cache_enemy_templates() -> void:
	if not _enemy_templates.is_empty():
		return

	for node in get_tree().get_nodes_in_group("Enemies"):
		var enemy := node as Sprite2D
		if enemy == null:
			continue
		if not is_ancestor_of(enemy):
			continue

		var template := enemy.duplicate() as Sprite2D
		if template != null:
			_enemy_templates.append(template)

func _clear_enemy_spawns() -> void:
	for node in get_tree().get_nodes_in_group("Enemies"):
		if not is_ancestor_of(node):
			continue
		node.queue_free()

	for child in get_children():
		if child is Node2D and child.name.begins_with(SPAWN_NODE_PREFIX):
			child.queue_free()

func _spawn_random_enemies() -> void:
	if _enemy_templates.is_empty() or ground == null:
		return

	var candidate_tiles := _collect_spawn_tiles()
	if candidate_tiles.is_empty():
		return

	candidate_tiles.shuffle()
	var spawn_count := mini(randi_range(MIN_ENEMIES, MAX_ENEMIES), candidate_tiles.size())
	for index in spawn_count:
		var tile: Vector2i = candidate_tiles[index]
		var spawn := Node2D.new()
		spawn.name = "%s%d" % [SPAWN_NODE_PREFIX, index]
		add_child(spawn)
		spawn.global_position = _tile_to_world(tile)

		var template := _enemy_templates[randi() % _enemy_templates.size()]
		var enemy := template.duplicate() as Sprite2D
		if enemy == null:
			continue

		spawn.add_child(enemy)
		enemy.position = Vector2.ZERO

func _collect_spawn_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for tile in ground.get_used_cells():
		if _is_impassable(tile):
			continue
		tiles.append(tile)
	return tiles

func _is_impassable(tile: Vector2i) -> bool:
	if structures == null:
		return false

	var tile_data := structures.get_cell_tile_data(tile)
	if tile_data == null:
		return false

	return bool(tile_data.get_custom_data(IMPASSABLE_CUSTOM_DATA))

func _clear_door_tiles() -> void:
	if structures == null:
		return

	for tile in structures.get_used_cells():
		var tile_data := structures.get_cell_tile_data(tile)
		if tile_data == null:
			continue
		if bool(tile_data.get_custom_data("DOOR")):
			structures.erase_cell(tile)

func _place_random_door_pattern() -> void:
	if structures == null or structures.tile_set == null:
		return
	if structures.tile_set.get_patterns_count() <= DOOR_PATTERN_INDEX:
		push_warning("RandomBattle: Door pattern index %d not available." % DOOR_PATTERN_INDEX)
		return

	var pattern := structures.tile_set.get_pattern(DOOR_PATTERN_INDEX)
	if pattern == null:
		return

	var anchor_tiles := _collect_spawn_tiles()
	if anchor_tiles.is_empty():
		return

	anchor_tiles.shuffle()
	for tile in anchor_tiles:
		structures.set_pattern(tile, pattern)
		return

func _tile_to_world(tile: Vector2i) -> Vector2:
	var local_position := ground.map_to_local(tile)
	return ground.to_global(local_position)
