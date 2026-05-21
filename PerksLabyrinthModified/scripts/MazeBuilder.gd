extends Node3D
class_name MazeBuilder

# MazeBuilder.gd - Godot 4.6 compatible

const CELL_SIZE: float = 4.0
const WALL_H:    float = 3.0
const WALL_T:    float = 0.3

@export var wall_material:  StandardMaterial3D
@export var floor_material: StandardMaterial3D
@export var ceil_material:  StandardMaterial3D

var _maze: MazeGenerator

func build(maze: MazeGenerator) -> void:
	_maze = maze
	_clear()
	for y: int in maze.height:
		for x: int in maze.width:
			var cell: MazeGenerator.MazeCell = maze.get_cell(x, y)
			_build_cell(cell)
	_add_floor_ceiling(maze)

func _clear() -> void:
	for child: Node in get_children():
		child.queue_free()

func _build_cell(cell: MazeGenerator.MazeCell) -> void:
	var cx: float = float(cell.x) * CELL_SIZE
	var cz: float = float(cell.y) * CELL_SIZE

	if cell.walls[0]: # North
		_add_wall(Vector3(cx, 0.0, cz - CELL_SIZE * 0.5), Vector3(CELL_SIZE, WALL_H, WALL_T))
	if cell.walls[1]: # East
		_add_wall(Vector3(cx + CELL_SIZE * 0.5, 0.0, cz), Vector3(WALL_T, WALL_H, CELL_SIZE))
	if cell.walls[2]: # South
		_add_wall(Vector3(cx, 0.0, cz + CELL_SIZE * 0.5), Vector3(CELL_SIZE, WALL_H, WALL_T))
	if cell.walls[3]: # West
		_add_wall(Vector3(cx - CELL_SIZE * 0.5, 0.0, cz), Vector3(WALL_T, WALL_H, CELL_SIZE))

func _add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var mesh_inst := MeshInstance3D.new()
	var col := CollisionShape3D.new()

	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_inst.mesh = box_mesh
	if wall_material != null:
		mesh_inst.material_override = wall_material

	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape

	body.add_child(mesh_inst)
	body.add_child(col)
	body.position = pos + Vector3(0.0, WALL_H * 0.5, 0.0)
	add_child(body)

func _add_floor_ceiling(maze: MazeGenerator) -> void:
	var total_w: float = float(maze.width)  * CELL_SIZE
	var total_h: float = float(maze.height) * CELL_SIZE
	var cx: float = float(maze.width  - 1) * CELL_SIZE * 0.5
	var cz: float = float(maze.height - 1) * CELL_SIZE * 0.5

	# Floor
	var floor_body := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var floor_col  := CollisionShape3D.new()
	var floor_box  := BoxMesh.new()
	floor_box.size = Vector3(total_w, 0.2, total_h)
	floor_mesh.mesh = floor_box
	if floor_material != null:
		floor_mesh.material_override = floor_material
	var fs := BoxShape3D.new()
	fs.size = Vector3(total_w, 0.2, total_h)
	floor_col.shape = fs
	floor_body.add_child(floor_mesh)
	floor_body.add_child(floor_col)
	floor_body.position = Vector3(cx, -0.1, cz)
	add_child(floor_body)

	# Ceiling
	var ceil_body := StaticBody3D.new()
	var ceil_mesh := MeshInstance3D.new()
	var ceil_col  := CollisionShape3D.new()
	var ceil_box  := BoxMesh.new()
	ceil_box.size = Vector3(total_w, 0.2, total_h)
	ceil_mesh.mesh = ceil_box
	if ceil_material != null:
		ceil_mesh.material_override = ceil_material
	var cs := BoxShape3D.new()
	cs.size = Vector3(total_w, 0.2, total_h)
	ceil_col.shape = cs
	ceil_body.add_child(ceil_mesh)
	ceil_body.add_child(ceil_col)
	ceil_body.position = Vector3(cx, WALL_H + 0.1, cz)
	add_child(ceil_body)

func get_world_pos(gx: int, gy: int) -> Vector3:
	return Vector3(float(gx) * CELL_SIZE, 0.0, float(gy) * CELL_SIZE)
