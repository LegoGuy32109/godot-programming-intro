extends Sprite2D

enum PatrolAxis {
	UP_DOWN,
	RIGHT_LEFT,
}

@export var patrol_axis: PatrolAxis = PatrolAxis.UP_DOWN
@export_range(0.05, 5.0, 0.05) var step_interval_seconds := 0.35
@export var impassable_custom_data_key := "IMPASSABLE"
@export var ground_path: NodePath = NodePath("../../Ground")
@export var structures_path: NodePath = NodePath("../../Structures")
@export var flip_h_on_direction_change := true

var _ground: TileMapLayer
var _structures: TileMapLayer
var _current_tile := Vector2i.ZERO
var _direction_sign := 1
var _step_timer := 0.0

func _ready() -> void:
	_ground = get_node_or_null(ground_path) as TileMapLayer
	_structures = get_node_or_null(structures_path) as TileMapLayer
	if _ground == null:
		push_warning("Patrol: Ground layer not found at path %s." % [ground_path])
		return

	_current_tile = _world_to_tile(global_position)
	_snap_to_tile(_current_tile)
	_update_facing()

func _process(delta: float) -> void:
	if _ground == null:
		return

	_step_timer += delta
	if _step_timer < step_interval_seconds:
		return
	_step_timer = 0.0

	_step()

func _step() -> void:
	var next_tile := _current_tile + _axis_step(_direction_sign)
	if _is_blocked(next_tile):
		_direction_sign *= -1
		_update_facing()
		next_tile = _current_tile + _axis_step(_direction_sign)
		if _is_blocked(next_tile):
			return

	_current_tile = next_tile
	_snap_to_tile(_current_tile)

func _axis_step(step_sign: int) -> Vector2i:
	if patrol_axis == PatrolAxis.RIGHT_LEFT:
		return Vector2i(step_sign, 0)
	return Vector2i(0, step_sign)

func _is_blocked(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0:
		return true

	if _ground.get_cell_source_id(tile) == -1:
		return true

	if _structures == null:
		return false

	var tile_data := _structures.get_cell_tile_data(tile)
	if tile_data == null:
		return false

	return bool(tile_data.get_custom_data(impassable_custom_data_key))

func _world_to_tile(world_position: Vector2) -> Vector2i:
	var local_position := _ground.to_local(world_position)
	return _ground.local_to_map(local_position)

func _snap_to_tile(tile: Vector2i) -> void:
	var local_position := _ground.map_to_local(tile)
	global_position = _ground.to_global(local_position)

func _update_facing() -> void:
	if not flip_h_on_direction_change:
		return

	flip_h = _direction_sign < 0
