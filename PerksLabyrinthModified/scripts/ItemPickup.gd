extends Area3D
class_name ItemPickup

# ItemPickup.gd - Godot 4.6 compatible

@export var item_type: String = "trap"

var _bob_time: float = 0.0
var _collected: bool = false
var _player_nearby: bool = false

const ITEM_COLORS: Dictionary = {
	"minimap_perk":  Color(0.2, 0.8, 1.0),
	"tunnel_perk":   Color(0.5, 0.2, 1.0),
	"compass_perk":  Color(0.2, 1.0, 0.5),
	"extra_life":    Color(1.0, 0.3, 0.3),
	"curse":         Color(0.6, 0.0, 0.8),
	"trap":          Color(1.0, 0.5, 0.0),
	"exit":          Color(0.0, 1.0, 0.3),
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta * 2.0
	position.y = 1.2 + sin(_bob_time) * 0.2
	rotation_degrees.y += delta * 60.0

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body is Player:
		_player_nearby = true
		body.set_nearby_item(self)
		# Show interact prompt via HUD
		var hud := _find_hud()
		if hud:
			hud.show_interact_prompt(true, item_type)

func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		_player_nearby = false
		body.set_nearby_item(null)
		var hud := _find_hud()
		if hud:
			hud.show_interact_prompt(false, "")

func interact() -> void:
	if _collected or not _player_nearby:
		return
	_collected = true
	# Hide prompt
	var hud := _find_hud()
	if hud:
		hud.show_interact_prompt(false, "")
	GameManager.collect_item(item_type)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)

func _find_hud() -> HUD:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("hud")
	if nodes.size() > 0:
		return nodes[0] as HUD
	return null
