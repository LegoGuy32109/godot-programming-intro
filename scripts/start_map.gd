extends Node2D

const GRID_WIDTH := 18
const GRID_HEIGHT := 10

const CELL_FLOOR := 0
const CELL_PLAYER := 1
const IMPASSABLE_CUSTOM_DATA := "IMPASSABLE"
const DOOR_CUSTOM_DATA := "DOOR"
const INTRO_SCENE_PATH := "res://scenes/Levels/intro.tscn"
const FIRST_BATTLE_SCENE_PATH := "res://scenes/Levels/first_battle.tscn"
const RANDOM_BATTLE_SCENE_PATH := "res://scenes/Levels/random_battle.tscn"
const BATTLE_CLOSED_DOOR_ATLAS_COORDS := Vector2i(9, 3)
const BATTLE_OPEN_DOOR_ATLAS_COORDS := Vector2i(9, 0)

const SceneTransition := preload("res://scripts/scene_transition.gd")

@onready var level_container: Node2D = $LevelContainer
@onready var player: Node2D = $PlayerContainer/Player
@onready var player_sprite: Sprite2D = $PlayerContainer/Player/Sprite

var world_grid: Array[Array] = []
var player_tile: Vector2i = Vector2i.ZERO
var is_transitioning := false
var _battle_exit_opened := false

func _ready() -> void:
	_build_world_grid()
	player_tile = _clamp_tile(_world_to_tile(player.global_position))
	_set_cell(player_tile, CELL_PLAYER)
	_snap_player_to_tile()
	World.set_last_player_direction(Vector2i.RIGHT)

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return
	if _is_player_dead():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var direction := _key_to_direction(event.physical_keycode)
		if direction != Vector2i.ZERO:
			_take_turn(direction)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_transitioning:
		return

	_try_open_battle_exit()

func _build_world_grid() -> void:
	world_grid.clear()
	for y in GRID_HEIGHT:
		var row: Array[int] = []
		row.resize(GRID_WIDTH)
		row.fill(CELL_FLOOR)
		world_grid.append(row)

func _key_to_direction(keycode: Key) -> Vector2i:
	match keycode:
		KEY_W, KEY_UP:
			return Vector2i.UP
		KEY_S, KEY_DOWN:
			return Vector2i.DOWN
		KEY_A, KEY_LEFT:
			return Vector2i.LEFT
		KEY_D, KEY_RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.ZERO

func _take_turn(direction: Vector2i) -> void:
	if is_transitioning:
		return
	if _is_player_dead():
		return

	var target_tile := player_tile + direction
	if not _is_in_bounds(target_tile):
		return
	if not _can_move_to(target_tile):
		return

	_update_player_facing(direction)
	World.set_last_player_direction(direction)
	_set_cell(player_tile, CELL_FLOOR)
	player_tile = target_tile
	_set_cell(player_tile, CELL_PLAYER)
	_snap_player_to_tile()

	if _is_door(player_tile):
		is_transitioning = true
		var transition: CanvasLayer = SceneTransition.get_or_create(get_tree())
		await transition.transition_replace_level(level_container, _next_level_on_door(), _player_screen_uv())
		_battle_exit_opened = false
		is_transitioning = false

func _try_open_battle_exit() -> void:
	if _battle_exit_opened:
		return

	var active_level := _get_active_level()
	if active_level == null:
		return
	if not _is_battle_scene(active_level.scene_file_path):
		return
	if _has_enemies_in_level(active_level):
		return

	var structures := _get_structures_layer()
	if structures == null:
		return

	_battle_exit_opened = _open_exit_door(structures)

func _has_enemies_in_level(level: Node) -> bool:
	for node in get_tree().get_nodes_in_group("Enemies"):
		if not is_instance_valid(node):
			continue
		if node.is_queued_for_deletion():
			continue
		if level.is_ancestor_of(node):
			return true

	return false

func _update_player_facing(direction: Vector2i) -> void:
	if direction.x < 0:
		player_sprite.flip_h = true
	elif direction.x > 0:
		player_sprite.flip_h = false

func _can_move_to(tile: Vector2i) -> bool:
	var active_level := _get_active_level()
	if active_level != null and _is_battle_scene(active_level.scene_file_path):
		if _is_door(tile) and _has_enemies_in_level(active_level):
			return false

	return _get_cell(tile) == CELL_FLOOR and not _is_impassable(tile)

func _is_impassable(tile: Vector2i) -> bool:
	var current_structures := _get_structures_layer()
	if current_structures == null:
		return false

	var tile_data := current_structures.get_cell_tile_data(tile)
	if tile_data == null:
		return false

	return bool(tile_data.get_custom_data(IMPASSABLE_CUSTOM_DATA))

func _is_door(tile: Vector2i) -> bool:
	var current_structures := _get_structures_layer()
	if current_structures == null:
		return false

	var tile_data := current_structures.get_cell_tile_data(tile)
	if tile_data == null:
		return false

	return bool(tile_data.get_custom_data(DOOR_CUSTOM_DATA))

func _is_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < GRID_WIDTH and tile.y >= 0 and tile.y < GRID_HEIGHT

func _get_cell(tile: Vector2i) -> int:
	return world_grid[tile.y][tile.x]

func _set_cell(tile: Vector2i, value: int) -> void:
	world_grid[tile.y][tile.x] = value

func _clamp_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(tile.x, 0, GRID_WIDTH - 1),
		clampi(tile.y, 0, GRID_HEIGHT - 1)
	)

func _world_to_tile(world_position: Vector2) -> Vector2i:
	var current_ground := _get_ground_layer()
	if current_ground == null:
		return Vector2i.ZERO

	var ground_local := current_ground.to_local(world_position)
	return current_ground.local_to_map(ground_local)

func _snap_player_to_tile() -> void:
	var current_ground := _get_ground_layer()
	if current_ground == null:
		return

	var tile_local_position := current_ground.map_to_local(player_tile)
	player.global_position = current_ground.to_global(tile_local_position)

func _get_active_level() -> Node:
	if level_container == null or level_container.get_child_count() == 0:
		return null

	return level_container.get_child(0)

func _get_ground_layer() -> TileMapLayer:
	var active_level := _get_active_level()
	if active_level == null:
		return null

	return active_level.get_node_or_null("Ground") as TileMapLayer

func _get_structures_layer() -> TileMapLayer:
	var active_level := _get_active_level()
	if active_level == null:
		return null

	return active_level.get_node_or_null("Structures") as TileMapLayer

func _player_screen_uv() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)

	var screen_position := get_viewport().get_canvas_transform() * player.global_position
	return Vector2(
		clampf(screen_position.x / viewport_size.x, 0.0, 1.0),
		clampf(screen_position.y / viewport_size.y, 0.0, 1.0)
	)

func _next_level_on_door() -> String:
	var active_level := _get_active_level()
	if active_level == null:
		return FIRST_BATTLE_SCENE_PATH

	match active_level.scene_file_path:
		FIRST_BATTLE_SCENE_PATH:
			return RANDOM_BATTLE_SCENE_PATH
		RANDOM_BATTLE_SCENE_PATH:
			return RANDOM_BATTLE_SCENE_PATH
		_:
			return FIRST_BATTLE_SCENE_PATH

func _is_battle_scene(scene_path: String) -> bool:
	return scene_path == FIRST_BATTLE_SCENE_PATH or scene_path == RANDOM_BATTLE_SCENE_PATH

func _open_exit_door(structures: TileMapLayer) -> bool:
	for tile in structures.get_used_cells():
		if structures.get_cell_atlas_coords(tile) != BATTLE_CLOSED_DOOR_ATLAS_COORDS:
			continue

		var source_id := structures.get_cell_source_id(tile)
		if source_id == -1:
			continue

		var alternative := structures.get_cell_alternative_tile(tile)
		structures.set_cell(tile, source_id, BATTLE_OPEN_DOOR_ATLAS_COORDS, alternative)
		return true

	for tile in structures.get_used_cells():
		var tile_data := structures.get_cell_tile_data(tile)
		if tile_data == null:
			continue
		if not bool(tile_data.get_custom_data(DOOR_CUSTOM_DATA)):
			continue

		var source_id := structures.get_cell_source_id(tile)
		if source_id == -1:
			continue

		var alternative := structures.get_cell_alternative_tile(tile)
		structures.set_cell(tile, source_id, BATTLE_OPEN_DOOR_ATLAS_COORDS, alternative)
		return true

	return false

func _is_player_dead() -> bool:
	if player == null:
		return false

	var player_controller := player.get_node_or_null("Controller")
	if player_controller == null:
		return false
	if not player_controller.has_method("is_dead"):
		return false

	return bool(player_controller.call("is_dead"))
