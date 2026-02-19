extends Node2D

const GRID_WIDTH := 18
const GRID_HEIGHT := 10

const CELL_FLOOR := 0
const CELL_PLAYER := 1
const IMPASSABLE_CUSTOM_DATA := "IMPASSABLE"
const DOOR_CUSTOM_DATA := "DOOR"
const BATTLE_SCENE_PATH := "res://scenes/first_battle.tscn"

const SceneTransition := preload("res://scripts/scene_transition.gd")

@onready var ground: TileMapLayer = $Ground
@onready var structures: TileMapLayer = $Structures
@onready var player: Sprite2D = $Spawn/Player

var world_grid: Array[Array] = []
var player_tile: Vector2i = Vector2i.ZERO
var is_transitioning := false

func _ready() -> void:
	_build_world_grid()
	player_tile = _clamp_tile(_world_to_tile(player.global_position))
	_set_cell(player_tile, CELL_PLAYER)
	_snap_player_to_tile()

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var direction := _key_to_direction(event.physical_keycode)
		if direction != Vector2i.ZERO:
			_take_turn(direction)
			get_viewport().set_input_as_handled()

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

	var target_tile := player_tile + direction
	if not _is_in_bounds(target_tile):
		return
	if not _can_move_to(target_tile):
		return

	_update_player_facing(direction)
	_set_cell(player_tile, CELL_FLOOR)
	player_tile = target_tile
	_set_cell(player_tile, CELL_PLAYER)
	_snap_player_to_tile()

	if _is_door(player_tile):
		is_transitioning = true
		var transition: CanvasLayer = SceneTransition.get_or_create(get_tree())
		await transition.transition_to_scene(BATTLE_SCENE_PATH, _player_screen_uv())
		is_transitioning = false

func _update_player_facing(direction: Vector2i) -> void:
	if direction.x < 0:
		player.flip_h = true
	elif direction.x > 0:
		player.flip_h = false

func _can_move_to(tile: Vector2i) -> bool:
	return _get_cell(tile) == CELL_FLOOR and not _is_impassable(tile)

func _is_impassable(tile: Vector2i) -> bool:
	var tile_data := structures.get_cell_tile_data(tile)
	if tile_data == null:
		return false

	return bool(tile_data.get_custom_data(IMPASSABLE_CUSTOM_DATA))

func _is_door(tile: Vector2i) -> bool:
	var tile_data := structures.get_cell_tile_data(tile)
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
	var ground_local := ground.to_local(world_position)
	return ground.local_to_map(ground_local)

func _snap_player_to_tile() -> void:
	var tile_local_position := ground.map_to_local(player_tile)
	player.global_position = ground.to_global(tile_local_position)

func _player_screen_uv() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2(0.5, 0.5)

	var screen_position := get_viewport().get_canvas_transform() * player.global_position
	return Vector2(
		clampf(screen_position.x / viewport_size.x, 0.0, 1.0),
		clampf(screen_position.y / viewport_size.y, 0.0, 1.0)
	)
