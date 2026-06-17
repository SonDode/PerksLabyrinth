extends CanvasLayer
class_name HUD

# ============================================================================
#  HUD.gd — Interfața din timpul jocului (Head-Up Display)
#  Afișează viețile, nivelul, busola, bara de blestem, minimapa, notificările
#  și promptul de interacțiune. Reacționează la semnalele din GameManager.
# ============================================================================

@onready var level_label:        Label       = $MarginContainer/VBox/TopRow/LevelLabel
@onready var lives_label:        Label       = $MarginContainer/VBox/TopRow/LivesLabel
@onready var curse_bar:          ProgressBar = $MarginContainer/VBox/CurseBar
@onready var curse_label:        Label       = $MarginContainer/VBox/CurseBar/CurseLabel
@onready var notification_label: Label       = $NotificationLabel
@onready var compass_label:      Label       = $MarginContainer/VBox/TopRow/CompassLabel
@onready var minimap_container:  Control     = $MinimapContainer
@onready var minimap:            MinimapUI   = $MinimapContainer/Minimap
@onready var interact_label:     Label       = $InteractLabel

var _notify_tween: Tween = null              # tween-ul curent de notificare (apariție/dispariție)
var _prev_lives:   int   = GameManager.MAX_LIVES  # ca să știm dacă viața a crescut sau a scăzut

func _ready() -> void:
	add_to_group("hud")   # ca ItemPickup/Guardian să ne găsească prin grup
	# Ne abonăm la semnalele jocului
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.perk_unlocked.connect(_on_perk_unlocked)
	GameManager.curse_timer_started.connect(_on_curse_started)
	GameManager.curse_timer_tick.connect(_on_curse_tick)
	GameManager.curse_timer_ended.connect(_on_curse_ended)

	# Stare inițială: ascundem elementele care apar doar la nevoie
	curse_bar.visible      = false
	compass_label.visible  = false
	interact_label.visible = false
	notification_label.modulate.a = 0.0
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD

	_prev_lives = GameManager.lives
	_update_lives(GameManager.lives)

func set_level(n: int) -> void:
	level_label.text = "NIVEL %d  " % n

# Promptul „[ E ] ..." când ești lângă un obiect bun
func show_interact_prompt(visible_state: bool, item_type: String) -> void:
	interact_label.visible = visible_state
	if visible_state:
		var label_map: Dictionary = {
			"minimap_perk":  "Hartă",
			"tunnel_perk":   "Viziune Tunel",
			"compass_perk":  "Busolă",
			"extra_life":    "❤ Viață",
			"curse":         "☠ Blestem!",
			"trap":          "⚠ Capcană!",
			"exit":          "Ieșire",
		}
		interact_label.text = "[ E ]  " + label_map.get(item_type, item_type)

# Reacție la schimbarea vieților: sunet potrivit (pierdere/câștig) + actualizare afișaj
func _on_lives_changed(new_lives: int) -> void:
	if new_lives < _prev_lives:
		AudioManager.play_life_lost()
	elif new_lives > _prev_lives:
		AudioManager.play_collect_life()
		show_notification("❤ +1 VIAȚĂ!  (acum %d)" % new_lives, Color(1.0, 0.3, 0.3))
	_prev_lives = new_lives
	_update_lives(new_lives)

# Desenează viețile ca inimi (roșii = vieți curente, negre = pierdute până la maxim)
func _update_lives(n: int) -> void:
	var hearts: String = ""
	for _i: int in n:
		hearts += "❤ "
	for _i: int in (GameManager.MAX_LIVES - n):   # dacă ai > MAX, bucla nu rulează
		hearts += "🖤 "
	lives_label.text = "VIEȚI: " + hearts

# Notificare + efect vizibil când deblochezi un perk
func _on_perk_unlocked(perk_name: String) -> void:
	AudioManager.play_collect_perk()
	match perk_name:
		"minimap":
			show_notification("🗺 HARTĂ DEBLOCATĂ!", Color(0.2, 0.8, 1.0))
			minimap_container.visible = true
		"tunnel_vision":
			show_notification("👁 VIZIUNE TUNEL! Fundăturile vizibile pe hartă.", Color(0.5, 0.2, 1.0))
		"compass_perk", "compass":
			show_notification("🧭 BUSOLĂ DEBLOCATĂ!", Color(0.2, 1.0, 0.5))
			compass_label.visible = true

# Blestemul a început: arată bara cu timerul
func _on_curse_started(duration: float) -> void:
	AudioManager.play_curse_start()
	curse_bar.visible   = true
	curse_bar.max_value = duration
	curse_bar.value     = duration
	curse_label.text    = "☠ BLESTEMAT! %.0fs" % duration
	show_notification("☠ EȘTI BLESTEMAT! Găsește ieșirea sau pierzi o viață!", Color(0.8, 0.0, 1.0))

# Tic de timer: scade bara și o face să pulseze roșu în ultimele 5 secunde
func _on_curse_tick(remaining: float) -> void:
	curse_bar.value  = remaining
	curse_label.text = "☠ BLESTEMAT! %.1fs" % remaining
	if remaining < 5.0:
		var alpha: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.01)
		curse_bar.modulate = Color(1.0, alpha * 0.3, alpha * 0.3)

func _on_curse_ended() -> void:
	curse_bar.visible  = false
	curse_bar.modulate = Color.WHITE

# Afișează un mesaj central care apare, stă 2.5s, apoi dispare (tween pe transparență)
func show_notification(text: String, color: Color = Color.WHITE) -> void:
	notification_label.text     = text
	notification_label.modulate = color

	if _notify_tween != null:
		_notify_tween.kill()   # oprește o notificare anterioară încă în desfășurare
	_notify_tween = create_tween()
	_notify_tween.tween_property(notification_label, "modulate:a", 1.0, 0.2)
	_notify_tween.tween_interval(2.5)
	_notify_tween.tween_property(notification_label, "modulate:a", 0.0, 0.5)

func update_player_cell(gx: int, gy: int) -> void:
	if minimap != null:
		minimap.update_player(gx, gy)

# Calculează săgeata busolei: direcția spre ieșire raportată la direcția privirii
func update_compass(yaw_rad: float, exit_gx: int, exit_gy: int, player_gx: int, player_gy: int) -> void:
	if not GameManager.has_perk("compass"):
		return
	var dx: float = float(exit_gx - player_gx)
	var dz: float = float(exit_gy - player_gy)
	if absf(dx) < 0.01 and absf(dz) < 0.01:
		compass_label.text = "🧭 ●"   # ai ajuns la ieșire
		return
	# Unghiul spre ieșire și unghiul de privire, ambele în planul XZ
	var angle_to_exit: float = atan2(dz, dx)
	var fx: float            = -sin(yaw_rad)
	var fz: float            = -cos(yaw_rad)
	var facing_angle: float  = atan2(fz, fx)
	# Diferența relativă (0..360) decide ce săgeată afișăm
	var rel: float           = fmod(rad_to_deg(angle_to_exit - facing_angle) + 360.0, 360.0)
	var arrow: String        = "↑"
	if   rel < 45.0 or rel >= 315.0: arrow = "↑"   # în față
	elif rel < 135.0:                 arrow = "→"   # dreapta
	elif rel < 225.0:                 arrow = "↓"   # în spate
	else:                             arrow = "←"   # stânga
	compass_label.text = "🧭 " + arrow

# Pregătește minimapa; pe nivelul 2 caseta e cu 30% mai mare (160 → 208)
func setup_minimap(maze: MazeGenerator) -> void:
	var box: float = 208.0 if GameManager.current_level >= 2 else 160.0
	minimap_container.offset_left   = -10.0 - box   # ancorat în colțul dreapta-sus
	minimap_container.offset_bottom = 10.0 + box
	if minimap != null:
		minimap.setup(maze, box - 13.0)   # lăsăm loc pentru titlul minimapei

# Cheat admin: forțează afișarea minimapei cu tot labirintul + ieșirea
func force_show_minimap() -> void:
	minimap_container.visible = true
	if minimap != null:
		minimap.reveal_all()
