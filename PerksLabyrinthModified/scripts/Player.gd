extends CharacterBody3D
class_name Player

# Player.gd - Godot 4.6 compatible

signal cell_entered(cell_x: int, cell_y: int)

@export var move_speed: float = 10.0
@export var turn_speed: float = 12.0
@export var cell_size: float = 4.0

@onready var camera: Camera3D = $Camera3D

var grid_x: int = 0
var grid_y: int = 0

var _target_position: Vector3 = Vector3.ZERO
var _target_rotation_y: float = 0.0
var _is_moving: bool = false
var _facing_dir: int = 1  # 0=N, 1=E, 2=S, 3=W

var _maze_ref: MazeGenerator = null

# Input repeat timing for smooth held-key movement
var _input_cooldown: float = 0.0
const INPUT_INITIAL_DELAY: float = 0.25
const INPUT_REPEAT_DELAY: float = 0.15
var _first_input: bool = true

# Item interaction
var _nearby_item: ItemPickup = null

# Direction vectors indexed by facing_dir
const DIR_DX: Array[int] = [0, 1, 0, -1]   # N E S W
const DIR_DY: Array[int] = [-1, 0, 1, 0]
const DIR_ANGLES: Array[float] = [0.0, -90.0, 180.0, 90.0]

func _ready() -> void:
	_target_position = global_position
	_target_rotation_y = rotation_degrees.y

func setup(maze: MazeGenerator, start_gx: int, start_gy: int) -> void:
	_maze_ref = maze
	grid_x = start_gx
	grid_y = start_gy
	global_position = Vector3(float(start_gx) * cell_size, 0.9, float(start_gy) * cell_size)
	_target_position = global_position
	_facing_dir = 1
	_target_rotation_y = DIR_ANGLES[_facing_dir]
	rotation_degrees.y = _target_rotation_y

func set_nearby_item(item: ItemPickup) -> void:
	_nearby_item = item

func _physics_process(delta: float) -> void:
	if _is_moving:
		_smooth_move(delta)
		_input_cooldown = 0.0
		return
	_handle_input(delta)

func _smooth_move(delta: float) -> void:
	global_position = global_position.lerp(_target_position, move_speed * delta)

	var cur: float = deg_to_rad(rotation_degrees.y)
	var target: float = deg_to_rad(_target_rotation_y)
	rotation_degrees.y = rad_to_deg(lerp_angle(cur, target, turn_speed * delta))

	if global_position.distance_to(_target_position) < 0.03:
		global_position = _target_position
		rotation_degrees.y = _target_rotation_y
		_is_moving = false
		emit_signal("cell_entered", grid_x, grid_y)

func _handle_input(delta: float) -> void:
	# Interact with E
	if Input.is_action_just_pressed("interact"):
		if _nearby_item != null:
			_nearby_item.interact()
		return

	var any_held: bool = (
		Input.is_action_pressed("move_forward") or
		Input.is_action_pressed("move_backward") or
		Input.is_action_pressed("turn_left") or
		Input.is_action_pressed("turn_right")
	)

	# On first press, act immediately and reset cooldown
	if (Input.is_action_just_pressed("move_forward") or
		Input.is_action_just_pressed("move_backward") or
		Input.is_action_just_pressed("turn_left") or
		Input.is_action_just_pressed("turn_right")):
		_first_input = true
		_input_cooldown = 0.0

	if not any_held:
		_input_cooldown = 0.0
		_first_input = true
		return

	_input_cooldown -= delta
	if _input_cooldown > 0.0:
		return

	# Execute input
	if Input.is_action_pressed("move_forward"):
		_try_move(_facing_dir)
	elif Input.is_action_pressed("move_backward"):
		_try_move((_facing_dir + 2) % 4)
	elif Input.is_action_pressed("turn_left"):
		_turn(-1)
	elif Input.is_action_pressed("turn_right"):
		_turn(1)

	_input_cooldown = INPUT_INITIAL_DELAY if _first_input else INPUT_REPEAT_DELAY
	_first_input = false

func _try_move(dir: int) -> void:
	if _maze_ref == null:
		return
	var cell: MazeGenerator.MazeCell = _maze_ref.get_cell(grid_x, grid_y)
	if cell == null:
		return
	if cell.walls[dir]:
		return
	var nx: int = grid_x + DIR_DX[dir]
	var ny: int = grid_y + DIR_DY[dir]
	if _maze_ref.get_cell(nx, ny) == null:
		return
	grid_x = nx
	grid_y = ny
	_target_position = Vector3(float(nx) * cell_size, 0.9, float(ny) * cell_size)
	_is_moving = true

func _turn(direction: int) -> void:
	_facing_dir = (_facing_dir + direction + 4) % 4
	_target_rotation_y = DIR_ANGLES[_facing_dir]
	_is_moving = true
