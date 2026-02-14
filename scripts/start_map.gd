extends Node2D

const GRID_WIDTH := 18
const GRID_HEIGHT := 10

const CELL_FLOOR := 0
const CELL_PLAYER := 1

@onready var ground: TileMapLayer = $Ground
@onready var player: Sprite2D = $Spawn/Player

var world_grid: Array[Array] = []
var player_tile: Vector2i = Vector2i.ZERO

func _ready() -> void:
	_build_world_grid()
	player_tile = _clamp_tile(_world_to_tile(player.global_position))
	_set_cell(player_tile, CELL_PLAYER)
	_snap_player_to_tile()

func _unhandled_input(event: InputEvent) -> void:
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
	var target_tile := player_tile + direction
	if not _is_in_bounds(target_tile):
		return
	if not _can_move_to(target_tile):
		return

	_set_cell(player_tile, CELL_FLOOR)
	player_tile = target_tile
	_set_cell(player_tile, CELL_PLAYER)
	_snap_player_to_tile()

func _can_move_to(tile: Vector2i) -> bool:
	return _get_cell(tile) == CELL_FLOOR

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
