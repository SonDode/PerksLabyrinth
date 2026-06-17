extends Area3D
class_name ItemPickup

# ============================================================================
#  ItemPickup.gd — Un obiect de pe jos (perk, capcană, blestem, ieșire)
#  Plutește și se rotește. Obiectele BUNE se iau cu E (apare prompt); cele RELE
#  (capcană, blestem) se declanșează automat când intri în ele. Efectul concret
#  e decis în GameManager.collect_item().
# ============================================================================

@export var item_type: String = "trap"   # tipul, setat la creare în Game.gd

var _bob_time:      float = 0.0   # faza animației de plutire
var _collected:     bool  = false
var _player_nearby: bool  = false

# (referință de culori, păstrată pentru claritate)
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
	# Area3D ne anunță când un corp (jucătorul) intră/iese din rază
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Animație: plutire sus-jos + rotație
func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta * 2.0
	position.y = 1.2 + sin(_bob_time) * 0.2
	rotation_degrees.y += delta * 60.0

# Obiectele „rele" (capcană, blestem) se declanșează automat la contact —
# nu are sens să le „echipezi" cu E.
func _is_auto_trigger() -> bool:
	return item_type == "trap" or item_type == "curse"

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body is Player:
		if _is_auto_trigger():
			_collect(false)   # pas pe ea = se declanșează direct
			return
		# Obiect bun: memorăm că jucătorul e aproape și arătăm promptul „[ E ]"
		_player_nearby = true
		body.set_nearby_item(self)
		var hud := _find_hud()
		if hud:
			hud.show_interact_prompt(true, item_type)

func _on_body_exited(body: Node3D) -> void:
	if _is_auto_trigger():
		return
	if body is Player:
		_player_nearby = false
		body.set_nearby_item(null)
		var hud := _find_hud()
		if hud:
			hud.show_interact_prompt(false, "")

# Apelat la apăsarea E (doar pentru obiecte bune: perks, +viață, ieșire)
func interact() -> void:
	if _collected or not _player_nearby:
		return
	_collect(true)

# Culege obiectul: sunet, aplică efectul, apoi dispare cu o mică animație
func _collect(play_blip: bool) -> void:
	_collected = true
	set_deferred("monitoring", false)   # oprește semnale ulterioare cât dispare
	# Dezactivează coliziunea ca fizica să nu mai folosească transformul în timpul micșorării
	for c: Node in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)

	if play_blip:
		AudioManager.play_interact()

	var hud := _find_hud()
	if hud:
		hud.show_interact_prompt(false, "")

	GameManager.collect_item(item_type)   # aici se întâmplă efectul concret

	# Micșorăm spre o valoare MICĂ non-zero (nu exact 0) ca să evităm „invert: det == 0"
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.02, 0.02, 0.02), 0.3)
	tween.tween_callback(queue_free)

# Găsește HUD-ul prin grupul „hud" (mai robust decât o cale fixă)
func _find_hud() -> HUD:
	var tree := get_tree()
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("hud")
	if nodes.size() > 0:
		return nodes[0] as HUD
	return null
