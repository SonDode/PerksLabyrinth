extends Node3D

# Game.gd - Godot 4.6 compatible

@onready var maze_builder: MazeBuilder = $MazeBuilder
@onready var player:       Player      = $Player
@onready var hud:          HUD         = $HUD
@onready var item_root:    Node3D      = $Items

var _maze_gen: MazeGenerator = MazeGenerator.new()
var _game_active: bool = false

func _ready() -> void:
	GameManager.reset()
	_connect_signals()
	_generate_level()
	_apply_brightness()

func _apply_brightness() -> void:
	var brightness: float = ProjectSettings.get_setting("display/brightness", 1.0) as float
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.04, 0.08)
	environment.adjustment_enabled = true
	environment.adjustment_brightness = brightness
	env.environment = environment
	add_child(env)

func _connect_signals() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.level_complete.connect(_on_level_complete)
	player.cell_entered.connect(_on_player_cell_entered)

func _generate_level() -> void:
	_maze_gen.generate(12, 12)
	maze_builder.build(_maze_gen)
	var start: MazeGenerator.MazeCell = _maze_gen.start_cell
	player.setup(_maze_gen, start.x, start.y)
	_spawn_items()
	hud.setup_minimap(_maze_gen)
	_game_active = true
	hud.show_notification("Find the EXIT to escape! (%d lives)" % GameManager.MAX_LIVES, Color.WHITE)

func _spawn_items() -> void:
	for child: Node in item_root.get_children():
		child.queue_free()

	for y: int in _maze_gen.height:
		for x: int in _maze_gen.width:
			var cell: MazeGenerator.MazeCell = _maze_gen.get_cell(x, y)
			if cell.item == "" or cell.item == "exit":
				continue
			_create_item_at(cell.item, x, y)

	var exit_cell: MazeGenerator.MazeCell = _maze_gen.exit_cell
	_create_item_at("exit", exit_cell.x, exit_cell.y)

func _create_item_at(item_type: String, gx: int, gy: int) -> void:
	var pickup: ItemPickup = _make_pickup_node(item_type)
	pickup.position = Vector3(float(gx) * 4.0, 1.2, float(gy) * 4.0)
	item_root.add_child(pickup)

func _make_pickup_node(item_type: String) -> ItemPickup:
	var area := ItemPickup.new()
	area.item_type = item_type

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_inst.mesh = sphere

	var mat := StandardMaterial3D.new()
	var color_map: Dictionary = {
		"minimap_perk": Color(0.2, 0.8, 1.0),
		"tunnel_perk":  Color(0.5, 0.2, 1.0),
		"compass_perk": Color(0.2, 1.0, 0.5),
		"extra_life":   Color(1.0, 0.2, 0.2),
		"curse":        Color(0.6, 0.0, 0.8),
		"trap":         Color(1.0, 0.5, 0.0),
		"exit":         Color(0.0, 1.0, 0.3),
	}
	var col: Color = color_map.get(item_type, Color.WHITE) as Color
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	area.add_child(mesh_inst)

	var col_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.6
	col_shape.shape = sphere_shape
	area.add_child(col_shape)

	var label := Label3D.new()
	label.name = "Label3D"
	label.text = _item_label(item_type)
	label.position = Vector3(0.0, 0.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.modulate = col
	area.add_child(label)

	return area

func _item_label(t: String) -> String:
	match t:
		"minimap_perk":  return "MINIMAP"
		"tunnel_perk":   return "TUNNEL"
		"compass_perk":  return "COMPASS"
		"extra_life":    return "+LIFE"
		"curse":         return "CURSE!"
		"trap":          return "TRAP!"
		"exit":          return "EXIT"
	return t

func _on_player_cell_entered(gx: int, gy: int) -> void:
	if not _game_active:
		return
	hud.update_player_cell(gx, gy)
	var exit_c: MazeGenerator.MazeCell = _maze_gen.exit_cell
	hud.update_compass(player._facing_dir, exit_c.x, exit_c.y, gx, gy)

func _on_game_over() -> void:
	_game_active = false
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

func _on_level_complete() -> void:
	_game_active = false
	get_tree().change_scene_to_file("res://scenes/Victory.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
