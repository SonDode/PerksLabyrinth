extends Node3D

# ============================================================================
#  Game.gd — Coordonatorul scenei de joc
#  Leagă toate piesele: generează nivelul (labirint + obiecte + gardian),
#  configurează mediul/luminile în funcție de nivel, conectează semnalele și
#  gestionează game over / trecerea la nivelul următor / comanda admin.
# ============================================================================

@onready var maze_builder: MazeBuilder        = $MazeBuilder
@onready var player:       Player             = $Player
@onready var hud:          HUD                = $HUD
@onready var item_root:    Node3D             = $Items
@onready var world_env:    WorldEnvironment   = $WorldEnvironment
@onready var dir_light:    DirectionalLight3D = $DirectionalLight3D

# Configurația fiecărui nivel: nivelul 1 = tutorial ușor, nivelul 2 = mare, întunecat, dificil.
# size = dimensiunea labirintului; light/ambient/dir = cât de luminos e; enemy_speed = viteza gardianului.
const LEVEL_CONFIG: Dictionary = {
	1: {
		"size": 8, "extra_life": 2, "curse": 1, "trap": 2,
		"light_range": 9.0, "light_energy": 3.0, "dir_energy": 0.6,
		"ambient": 0.5, "enemy_speed": 3.0,
	},
	2: {
		"size": 16, "extra_life": 2, "curse": 3, "trap": 9,
		"light_range": 6.0, "light_energy": 2.8, "dir_energy": 0.15,
		"ambient": 0.18, "enemy_speed": 4.0,
	},
}

var _maze_gen:    MazeGenerator = MazeGenerator.new()
var _game_active: bool          = false   # cât timp jocul rulează efectiv
var _guardian:    Guardian      = null

# Configurația nivelului curent (fallback la nivelul 2 dacă cumva e mai mare)
func _cfg() -> Dictionary:
	return LEVEL_CONFIG.get(GameManager.current_level, LEVEL_CONFIG[2])

func _ready() -> void:
	# NU resetăm aici (ar șterge nivelul/viețile la trecerea între nivele).
	# Resetul complet se face din MainMenu (joc nou) / GameOver / Victory.
	_setup_environment()
	_connect_signals()
	_generate_level()

# Creează mediul (ceață/lumină ambientală) după nivel + aplică luminozitatea din setări
func _setup_environment() -> void:
	var cfg: Dictionary = _cfg()
	var env := Environment.new()
	env.background_mode        = Environment.BG_COLOR
	env.background_color       = Color(0.04, 0.04, 0.08)
	env.ambient_light_source   = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color    = Color(0.15, 0.15, 0.2)
	env.ambient_light_energy   = cfg["ambient"]
	GameManager.apply_brightness_to_env(env)
	world_env.environment = env
	dir_light.light_energy = cfg["dir_energy"]   # nivelul 2 = lumină globală slabă (mai întuneric)

# Conectează semnalele din GameManager și Player la funcțiile locale
func _connect_signals() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.level_complete.connect(_on_level_complete)
	player.cell_entered.connect(_on_player_cell_entered)

# Construiește efectiv nivelul: labirint, geometrie, jucător, obiecte, gardian, HUD
func _generate_level() -> void:
	var cfg: Dictionary = _cfg()
	var size: int = cfg["size"]
	_maze_gen.generate(size, size, cfg["extra_life"], cfg["curse"], cfg["trap"])
	maze_builder.build(_maze_gen)                       # construiește pereții/podeaua 3D
	var start: MazeGenerator.MazeCell = _maze_gen.start_cell
	player.setup(_maze_gen, start.x, start.y)
	player.set_light(cfg["light_range"], cfg["light_energy"])
	_spawn_items()
	_spawn_guardian(cfg)
	hud.setup_minimap(_maze_gen)
	hud.set_level(GameManager.current_level)
	hud.update_player_cell(start.x, start.y)            # dezvăluie celula de start pe minimapă
	_game_active = true
	_show_intro()

# Mesajul de intro, diferit pe fiecare nivel
func _show_intro() -> void:
	if GameManager.current_level == 1:
		hud.show_notification(
			"NIVEL 1 — TUTORIAL\nGăsește IEȘIREA! W/S = mers, A/D = strafe, Mouse = privire, E = interacționează, Space = sari. Ferește-te de Gardian!",
			Color(0.7, 0.9, 1.0))
	else:
		hud.show_notification(
			"NIVEL %d — Labirint mare și întunecat. Capcane multe și Gardianul te urmărește mai rapid!" % GameManager.current_level,
			Color(1.0, 0.6, 0.4))

# Creează un nod 3D pentru fiecare obiect din labirint (perks, capcane, ieșire)
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

# Creează gardianul (NPC) dacă nivelul are enemy_speed > 0
func _spawn_guardian(cfg: Dictionary) -> void:
	var speed: float = cfg.get("enemy_speed", 0.0)
	if speed <= 0.0:
		return
	# Apare lângă ieșire (departe de start) și pornește în urmărirea jucătorului
	var exit_cell: MazeGenerator.MazeCell = _maze_gen.exit_cell
	_guardian = Guardian.new()
	add_child(_guardian)
	_guardian.setup(_maze_gen, player, exit_cell.x, exit_cell.y, speed)

# Plasează un obiect în lume, la centrul celulei (gx, gy)
func _create_item_at(item_type: String, gx: int, gy: int) -> void:
	var pickup: ItemPickup = _make_pickup_node(item_type)
	pickup.position = Vector3(float(gx) * 4.0, 1.2, float(gy) * 4.0)
	item_root.add_child(pickup)

# Construiește prin cod nodul unui obiect: sferă strălucitoare + coliziune + etichetă
func _make_pickup_node(item_type: String) -> ItemPickup:
	var area := ItemPickup.new()
	area.item_type = item_type

	# Mesh-ul vizibil (sferă mică)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	mesh_inst.mesh = sphere

	# Materialul: culoare specifică tipului + textură de marmură + strălucire
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
	# Fiecare tip de obiect are textura lui (CC0), colorată cu tenta lui
	var tex_map: Dictionary = {
		"minimap_perk": "res://assets/textures/perk_color.jpg",    # marmură
		"tunnel_perk":  "res://assets/textures/perk_crystal.jpg",  # rocă/cristal
		"compass_perk": "res://assets/textures/perk_metal.jpg",    # metal
		"extra_life":   "res://assets/textures/perk_marble2.jpg",  # marmură albă
		"exit":         "res://assets/textures/perk_crystal.jpg",
		"curse":        "res://assets/textures/perk_color.jpg",
		"trap":         "res://assets/textures/perk_metal.jpg",
	}
	# Tentă slabă (mai mult alb) ca textura să se vadă clar; culoarea rămâne doar accent
	mat.albedo_color = col.lerp(Color.WHITE, 0.6)
	var tex_path: String = tex_map.get(item_type, "res://assets/textures/perk_color.jpg")
	var tex: Texture2D = load(tex_path) as Texture2D
	if tex != null:
		mat.albedo_texture   = tex
		mat.emission_texture = tex   # strălucirea urmează textura → modelul e clar vizibil
	mat.emission_enabled           = true
	mat.emission                   = col.lerp(Color.WHITE, 0.3)
	mat.emission_energy_multiplier = 0.8   # strălucire redusă ca să nu acopere textura
	mesh_inst.material_override = mat
	area.add_child(mesh_inst)

	# Forma de coliziune = raza în care apare promptul „[ E ]"
	var col_shape  := CollisionShape3D.new()
	var sph_shape  := SphereShape3D.new()
	sph_shape.radius = 1.2   # raza de interacțiune
	col_shape.shape  = sph_shape
	area.add_child(col_shape)

	# Eticheta 3D care arată mereu spre cameră (billboard)
	var label := Label3D.new()
	label.name      = "Label3D"
	label.text      = _item_label(item_type)
	label.position  = Vector3(0.0, 0.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.modulate  = col
	area.add_child(label)

	return area

# Textul afișat deasupra fiecărui obiect
func _item_label(t: String) -> String:
	match t:
		"minimap_perk":  return "HARTĂ"
		"tunnel_perk":   return "TUNEL"
		"compass_perk":  return "BUSOLĂ"
		"extra_life":    return "+VIAȚĂ"
		"curse":         return "BLESTEM!"
		"trap":          return "CAPCANĂ!"
		"exit":          return "IEȘIRE"
	return t

# În fiecare cadru actualizăm busola (rotația e continuă, nu pe celule)
func _process(_delta: float) -> void:
	if not _game_active:
		return
	var exit_c: MazeGenerator.MazeCell = _maze_gen.exit_cell
	hud.update_compass(player.get_facing_yaw(), exit_c.x, exit_c.y, player.grid_x, player.grid_y)

# Jucătorul a intrat într-o celulă nouă → actualizează minimapa
func _on_player_cell_entered(gx: int, gy: int) -> void:
	if not _game_active:
		return
	hud.update_player_cell(gx, gy)

# Ai rămas fără vieți: oprește gardianul, sunet, apoi ecranul Game Over
func _on_game_over() -> void:
	_game_active = false
	if _guardian != null:
		_guardian.stop()
	AudioManager.play_game_over()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")

# Ai ajuns la ieșire: dacă mai sunt nivele avansezi, altfel câștigi jocul
func _on_level_complete() -> void:
	_game_active = false
	if _guardian != null:
		_guardian.stop()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if GameManager.current_level < GameManager.MAX_LEVEL:
		# Mai sunt nivele — avansăm (păstrăm viețile)
		AudioManager.play_collect_life()
		hud.show_notification("✓ NIVEL %d COMPLET! Urmează nivelul %d..." %
			[GameManager.current_level, GameManager.current_level + 1], Color(0.2, 1.0, 0.5))
		GameManager.next_level()
		await get_tree().create_timer(1.6).timeout
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
	else:
		# Ultimul nivel terminat — ai câștigat jocul
		AudioManager.play_victory()
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/Victory.tscn")

# Intrare brută: doar comanda admin (ESC e gestionat de PauseMenu)
func _input(event: InputEvent) -> void:
	# Comandă admin: Ctrl+Shift+M dezvăluie minimapa + ieșirea (ca să poți termina jocul)
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_M and k.ctrl_pressed and k.shift_pressed:
			_admin_reveal()

func _admin_reveal() -> void:
	hud.force_show_minimap()
	hud.show_notification("🔓 ADMIN: minimapă + ieșire dezvăluite (Ctrl+Shift+M)", Color(1.0, 0.9, 0.2))
