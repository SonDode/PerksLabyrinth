extends CanvasLayer
class_name HUD

# HUD.gd - Godot 4.6 compatible

@onready var lives_label:        Label       = $MarginContainer/VBox/TopRow/LivesLabel
@onready var curse_bar:          ProgressBar = $MarginContainer/VBox/CurseBar
@onready var curse_label:        Label       = $MarginContainer/VBox/CurseBar/CurseLabel
@onready var notification_label: Label       = $NotificationLabel
@onready var compass_label:      Label       = $MarginContainer/VBox/TopRow/CompassLabel
@onready var minimap_container:  Control     = $MinimapContainer
@onready var minimap:            MinimapUI   = $MinimapContainer/Minimap
@onready var interact_label:     Label       = $InteractLabel

var _notify_tween: Tween = null

func _ready() -> void:
	add_to_group("hud")
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.perk_unlocked.connect(_on_perk_unlocked)
	GameManager.curse_timer_started.connect(_on_curse_started)
	GameManager.curse_timer_tick.connect(_on_curse_tick)
	GameManager.curse_timer_ended.connect(_on_curse_ended)

	curse_bar.visible = false
	compass_label.visible = false
	notification_label.modulate.a = 0.0
	interact_label.visible = false

	_update_lives(GameManager.lives)

func show_interact_prompt(visible_state: bool, item_type: String) -> void:
	interact_label.visible = visible_state
	if visible_state:
		var label_map: Dictionary = {
			"minimap_perk":  "🗺 Hartă",
			"tunnel_perk":   "👁 Tunel",
			"compass_perk":  "🧭 Busolă",
			"extra_life":    "❤ Viață",
			"curse":         "☠ Blestem!",
			"trap":          "⚠ Capcană!",
			"exit":          "🚪 Ieșire",
		}
		var item_name: String = label_map.get(item_type, item_type)
		interact_label.text = "[ E ] " + item_name

func _on_lives_changed(new_lives: int) -> void:
	_update_lives(new_lives)

func _update_lives(n: int) -> void:
	var hearts: String = ""
	for i: int in n:
		hearts += "❤ "
	for _i: int in (GameManager.MAX_LIVES - n):
		hearts += "🖤 "
	lives_label.text = "LIVES: " + hearts

func _on_perk_unlocked(perk_name: String) -> void:
	match perk_name:
		"minimap":
			show_notification("🗺 MINIMAP DEBLOCAT!", Color(0.2, 0.8, 1.0))
			minimap_container.visible = true
		"tunnel_vision":
			show_notification("👁 VIZIUNE TUNEL! Fundăturile vizibile pe hartă.", Color(0.5, 0.2, 1.0))
		"compass_perk", "compass":
			show_notification("🧭 BUSOLĂ DEBLOCATĂ!", Color(0.2, 1.0, 0.5))
			compass_label.visible = true

func _on_curse_started(duration: float) -> void:
	curse_bar.visible = true
	curse_bar.max_value = duration
	curse_bar.value = duration
	curse_label.text = "☠ BLESTEMAT! %.0fs" % duration
	show_notification("☠ EȘTI BLESTEMAT! Găsește o cale sau pierzi o viață!", Color(0.8, 0.0, 1.0))

func _on_curse_tick(remaining: float) -> void:
	curse_bar.value = remaining
	curse_label.text = "☠ BLESTEMAT! %.1fs" % remaining
	if remaining < 5.0:
		var alpha: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.01)
		curse_bar.modulate = Color(1.0, alpha * 0.3, alpha * 0.3)

func _on_curse_ended() -> void:
	curse_bar.visible = false

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	notification_label.text = text
	notification_label.modulate = color

	if _notify_tween != null:
		_notify_tween.kill()
	_notify_tween = create_tween()
	_notify_tween.tween_property(notification_label, "modulate:a", 1.0, 0.2)
	_notify_tween.tween_interval(2.5)
	_notify_tween.tween_property(notification_label, "modulate:a", 0.0, 0.5)

func update_player_cell(gx: int, gy: int) -> void:
	if minimap != null:
		minimap.update_player(gx, gy)

func update_compass(facing_dir: int, exit_gx: int, exit_gy: int, player_gx: int, player_gy: int) -> void:
	if not GameManager.has_perk("compass"):
		return
	var dx: int = exit_gx - player_gx
	var dy: int = exit_gy - player_gy
	var angle_to_exit: float = rad_to_deg(atan2(float(dy), float(dx)))
	var facing_angles: Array[float] = [270.0, 0.0, 90.0, 180.0]
	var rel: float = fmod(angle_to_exit - facing_angles[facing_dir] + 360.0, 360.0)
	var arrow: String = "↑"
	if rel < 45.0 or rel > 315.0:
		arrow = "↑"
	elif rel < 135.0:
		arrow = "→"
	elif rel < 225.0:
		arrow = "↓"
	else:
		arrow = "←"
	compass_label.text = "🧭 " + arrow

func setup_minimap(maze: MazeGenerator) -> void:
	if minimap != null:
		minimap.setup(maze)
