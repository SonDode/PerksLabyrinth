extends Node

# GameManager.gd - Godot 4.6 compatible Autoload Singleton

signal lives_changed(new_lives: int)
signal perk_unlocked(perk_name: String)
signal game_over()
signal level_complete()
signal curse_timer_started(duration: float)
signal curse_timer_tick(remaining: float)
signal curse_timer_ended()

const MAX_LIVES: int = 3
const CURSE_DURATION: float = 15.0

var lives: int = MAX_LIVES
var perks_unlocked: Dictionary = {
	"minimap": false,
	"tunnel_vision": false,
	"compass": false,
}
var items_collected: Array[String] = []

var curse_active: bool = false
var curse_time_remaining: float = 0.0
var _curse_timer: float = 0.0

func _ready() -> void:
	reset()

func _process(delta: float) -> void:
	if curse_active:
		_curse_timer -= delta
		curse_time_remaining = _curse_timer
		emit_signal("curse_timer_tick", _curse_timer)
		if _curse_timer <= 0.0:
			_on_curse_expired()

func reset() -> void:
	lives = MAX_LIVES
	perks_unlocked = {
		"minimap": false,
		"tunnel_vision": false,
		"compass": false,
	}
	items_collected.clear()
	curse_active = false
	_curse_timer = 0.0
	curse_time_remaining = 0.0

func lose_life(reason: String = "") -> void:
	lives -= 1
	print("[GameManager] Life lost (%s). Lives remaining: %d" % [reason, lives])
	emit_signal("lives_changed", lives)
	if lives <= 0:
		emit_signal("game_over")

func gain_life() -> void:
	lives = mini(lives + 1, MAX_LIVES)
	emit_signal("lives_changed", lives)

func unlock_perk(perk_name: String) -> void:
	if perks_unlocked.has(perk_name) and not perks_unlocked[perk_name]:
		perks_unlocked[perk_name] = true
		emit_signal("perk_unlocked", perk_name)
		print("[GameManager] Perk unlocked: ", perk_name)

func has_perk(perk_name: String) -> bool:
	return perks_unlocked.get(perk_name, false) as bool

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

func _start_curse() -> void:
	curse_active = true
	_curse_timer = CURSE_DURATION
	curse_time_remaining = CURSE_DURATION
	emit_signal("curse_timer_started", CURSE_DURATION)

func _on_curse_expired() -> void:
	curse_active = false
	_curse_timer = 0.0
	curse_time_remaining = 0.0
	emit_signal("curse_timer_ended")
	lose_life("curse expired")

func cancel_curse() -> void:
	if curse_active:
		curse_active = false
		_curse_timer = 0.0
		curse_time_remaining = 0.0
		emit_signal("curse_timer_ended")
