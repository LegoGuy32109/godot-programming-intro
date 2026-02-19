extends Sprite2D

const IMPASSABLE_CUSTOM_DATA := "IMPASSABLE"
const STEP_INTERVAL_SECONDS := 0.35

@onready var ground: TileMapLayer = $"../../Ground"
@onready var structures: TileMapLayer = $"../../Structures"

var _current_tile := Vector2i.ZERO
var _vertical_direction := 1
var _step_timer := 0.0

func _ready() -> void:
	if ground == null:
		push_warning("Rat patrol: Ground layer not found.")
		return

	_current_tile = _world_to_tile(global_position)
	_snap_to_tile(_current_tile)
	_update_facing()

func _process(delta: float) -> void:
	if ground == null:
		return

	_step_timer += delta
	if _step_timer < STEP_INTERVAL_SECONDS:
		return
	_step_timer = 0.0

	_step()

func _step() -> void:
	var next_tile := _current_tile + Vector2i(0, _vertical_direction)
	if _is_blocked(next_tile):
		_vertical_direction *= -1
		_update_facing()
		next_tile = _current_tile + Vector2i(0, _vertical_direction)
		if _is_blocked(next_tile):
			return

	_current_tile = next_tile
	_snap_to_tile(_current_tile)

func _is_blocked(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0:
		return true

	if ground.get_cell_source_id(tile) == -1:
		return true

	if structures == null:
		return false

	var tile_data := structures.get_cell_tile_data(tile)
	if tile_data == null:
		return false

	return bool(tile_data.get_custom_data(IMPASSABLE_CUSTOM_DATA))

func _world_to_tile(world_position: Vector2) -> Vector2i:
	var local_position := ground.to_local(world_position)
	return ground.local_to_map(local_position)

func _snap_to_tile(tile: Vector2i) -> void:
	var local_position := ground.map_to_local(tile)
	global_position = ground.to_global(local_position)

func _update_facing() -> void:
	flip_h = _vertical_direction < 0
