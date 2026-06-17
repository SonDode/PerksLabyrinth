extends Node

# ============================================================================
#  GameManager.gd — Singleton global (Autoload)
#  Ține starea jocului care trebuie să supraviețuiască schimbării de scenă:
#  nivelul curent, viețile, perk-urile deblocate, blestemul, setările
#  (luminozitate, volum, sensibilitate). Comunică cu restul jocului prin semnale.
# ============================================================================

# --- Semnale: alte noduri (HUD, Game) se „abonează" la ele și reacționează ---
signal lives_changed(new_lives: int)            # s-a schimbat numărul de vieți
signal perk_unlocked(perk_name: String)         # s-a deblocat un perk
signal game_over()                              # ai rămas fără vieți
signal level_complete()                         # ai ajuns la ieșire
signal curse_timer_started(duration: float)     # a început blestemul
signal curse_timer_tick(remaining: float)       # tic de ceas al blestemului
signal curse_timer_ended()                      # blestemul s-a terminat

# --- Constante de joc ---
const MAX_LIVES: int = 3            # viețile cu care începi
const CURSE_DURATION: float = 15.0 # secundele de timer la blestem
const MAX_LEVEL: int = 2           # câte nivele are jocul

# --- Stare curentă ---
var current_level: int = 1
var lives: int = MAX_LIVES
var perks_unlocked: Dictionary = {
	"minimap": false,
	"tunnel_vision": false,
	"compass": false,
}
var items_collected: Array[String] = []   # istoricul obiectelor luate (statistici)

# --- Stare blestem ---
var curse_active: bool = false
var curse_time_remaining: float = 0.0
var _curse_timer: float = 0.0   # ceasul intern care numără invers

# --- Setări persistente (rămân între scene/sesiuni) ---
var brightness: float = 1.0                       # luminozitate (0.2 – 1.0)
var volume: float = 1.0                           # volum master (0.0 – 1.0)
const DEFAULT_MOUSE_SENS: float = 0.0025          # sensibilitate mouse implicită (rad/pixel)
var mouse_sensitivity: float = DEFAULT_MOUSE_SENS # valoarea curentă folosită de Player

func _ready() -> void:
	reset()
	_apply_volume()

# Rulează în fiecare cadru: scade ceasul blestemului dacă e activ
func _process(delta: float) -> void:
	if curse_active:
		_curse_timer -= delta
		curse_time_remaining = _curse_timer
		emit_signal("curse_timer_tick", _curse_timer)
		if _curse_timer <= 0.0:
			_on_curse_expired()

# Joc nou (din meniu): nivel 1, vieți pline, perks resetate
func start_new_game() -> void:
	current_level = 1
	reset()

# Avansare la nivelul următor: PĂSTRĂM viețile, dar reluăm perks-urile
# (trebuie redeblocate în noul labirint, mai mare) — face nivelul 2 mai greu
func next_level() -> void:
	current_level += 1
	_reset_perks()
	_reset_curse()
	items_collected.clear()

# Reia nivelul CURENT de la capăt (vieți pline, perks resetate), păstrând numărul nivelului
func restart_level() -> void:
	reset()   # reset() nu modifică current_level

# Reset complet al stării de joc (folosit la joc nou / restart / game over)
func reset() -> void:
	lives = MAX_LIVES
	_reset_perks()
	_reset_curse()
	items_collected.clear()

func _reset_perks() -> void:
	perks_unlocked = {
		"minimap": false,
		"tunnel_vision": false,
		"compass": false,
	}

func _reset_curse() -> void:
	curse_active = false
	_curse_timer = 0.0
	curse_time_remaining = 0.0

# --- Setare luminozitate ---
func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.2, 1.0)
	# Aplică imediat pe WorldEnvironment-ul scenei active, dacă există
	if get_tree() == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_apply_brightness_to_node(scene)

# Caută recursiv un WorldEnvironment în scenă și îi setează luminozitatea
func _apply_brightness_to_node(node: Node) -> void:
	for child in node.get_children():
		if child is WorldEnvironment:
			var we := child as WorldEnvironment
			if we.environment != null:
				we.environment.adjustment_enabled    = true
				we.environment.adjustment_brightness = brightness
			return
		_apply_brightness_to_node(child)

# Aplică luminozitatea pe un Environment nou-creat (apelat din Game.gd)
func apply_brightness_to_env(env: Environment) -> void:
	env.adjustment_enabled    = true
	env.adjustment_brightness = brightness

# --- Setare sensibilitate mouse (primește un multiplicator 0.25–3.0) ---
func set_mouse_sensitivity(multiplier: float) -> void:
	mouse_sensitivity = DEFAULT_MOUSE_SENS * clampf(multiplier, 0.25, 3.0)

func get_sensitivity_multiplier() -> float:
	return mouse_sensitivity / DEFAULT_MOUSE_SENS

# --- Setare volum (controlează bus-ul Master prin AudioServer) ---
func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()

func _apply_volume() -> void:
	var master: int = AudioServer.get_bus_index("Master")
	if master < 0:
		return
	if volume <= 0.001:
		AudioServer.set_bus_mute(master, true)        # 0% = mut complet
	else:
		AudioServer.set_bus_mute(master, false)
		AudioServer.set_bus_volume_db(master, linear_to_db(volume))  # liniar -> decibeli

# --- Vieți ---
func lose_life(reason: String = "") -> void:
	lives -= 1
	print("[GameManager] Viață pierdută (%s). Vieți rămase: %d" % [reason, lives])
	emit_signal("lives_changed", lives)
	if lives <= 0:
		emit_signal("game_over")

func gain_life() -> void:
	lives += 1   # fără plafon — fiecare perk de viață adaugă o viață
	emit_signal("lives_changed", lives)

# --- Perks ---
func unlock_perk(perk_name: String) -> void:
	if perks_unlocked.has(perk_name) and not perks_unlocked[perk_name]:
		perks_unlocked[perk_name] = true
		emit_signal("perk_unlocked", perk_name)
		print("[GameManager] Perk deblocat: ", perk_name)

func has_perk(perk_name: String) -> bool:
	return perks_unlocked.get(perk_name, false) as bool

# Centralizează efectul fiecărui tip de obiect cules
func collect_item(item_type: String) -> void:
	items_collected.append(item_type)
	match item_type:
		"minimap_perk":  unlock_perk("minimap")
		"tunnel_perk":   unlock_perk("tunnel_vision")
		"compass_perk":  unlock_perk("compass")
		"extra_life":    gain_life()
		"curse":         _start_curse()
		"trap":          lose_life("trap")
		"exit":          emit_signal("level_complete")

# --- Blestem ---
func _start_curse() -> void:
	curse_active = true
	_curse_timer = CURSE_DURATION
	curse_time_remaining = CURSE_DURATION
	emit_signal("curse_timer_started", CURSE_DURATION)

# Blestemul a expirat fără să fie anulat -> pierzi o viață
func _on_curse_expired() -> void:
	curse_active = false
	_curse_timer = 0.0
	curse_time_remaining = 0.0
	emit_signal("curse_timer_ended")
	lose_life("curse expired")

# Anulează blestemul (rezervat pentru un eventual item „leac")
func cancel_curse() -> void:
	if curse_active:
		curse_active = false
		_curse_timer = 0.0
		curse_time_remaining = 0.0
		emit_signal("curse_timer_ended")
