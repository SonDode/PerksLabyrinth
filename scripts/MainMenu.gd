extends Control

# ============================================================================
#  MainMenu.gd — Meniul principal
#  Butoane: Joacă / Setări / Ieșire. Panoul de setări are 3 slidere
#  (luminozitate, volum, sensibilitate) care se salvează în GameManager și
#  persistă între scene. Luminozitatea are preview live (un strat de întunecare).
# ============================================================================

@onready var settings_panel:    PanelContainer = $SettingsPanel
@onready var brightness_slider: HSlider        = $SettingsPanel/VBoxSettings/BrightnessSlider
@onready var brightness_value:  Label          = $SettingsPanel/VBoxSettings/BrightnessValue
@onready var menu_vbox:         VBoxContainer  = $VBox
@onready var dimmer:            ColorRect      = $Dimmer
@onready var volume_slider:     HSlider        = $SettingsPanel/VBoxSettings/VolumeSlider
@onready var volume_value:      Label          = $SettingsPanel/VBoxSettings/VolumeValue
@onready var sens_slider:       HSlider        = $SettingsPanel/VBoxSettings/SensSlider
@onready var sens_value:        Label          = $SettingsPanel/VBoxSettings/SensValue

func _ready() -> void:
	# Conectăm butoanele și sliderele la funcțiile lor
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/QuitButton.pressed.connect(_on_quit)
	$SettingsPanel/VBoxSettings/CloseButton.pressed.connect(_on_close_settings)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.drag_ended.connect(_on_volume_drag_ended)
	sens_slider.value_changed.connect(_on_sens_changed)

	settings_panel.visible = false

	# Încărcăm valorile salvate din GameManager (persistă între scene)
	var saved: float = GameManager.brightness
	brightness_slider.value = saved
	brightness_value.text   = "%d%%" % int(saved * 100)
	_update_dim()

	volume_slider.value = GameManager.volume
	volume_value.text   = "%d%%" % int(GameManager.volume * 100)

	var sens_mult: float = GameManager.get_sensitivity_multiplier()
	sens_slider.value = sens_mult
	sens_value.text   = "%d%%" % int(sens_mult * 100)

	# Titlul pulsează lent între două culori
	var tween = create_tween().set_loops()
	tween.tween_property($VBox/Title, "modulate", Color(0.5, 0.8, 1.0), 1.5)
	tween.tween_property($VBox/Title, "modulate", Color(0.8, 0.3, 1.0), 1.5)

func _on_play() -> void:
	GameManager.start_new_game()   # nivel 1, vieți pline, perks resetate
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_settings() -> void:
	settings_panel.visible = true
	menu_vbox.visible = false   # ascunde meniul ca să nu se suprapună peste setări

func _on_close_settings() -> void:
	settings_panel.visible = false
	menu_vbox.visible = true

func _on_brightness_changed(value: float) -> void:
	brightness_value.text  = "%d%%" % int(value * 100)
	GameManager.set_brightness(value)
	_update_dim()   # preview live: meniul se întunecă pe măsură ce scazi luminozitatea

func _update_dim() -> void:
	# brightness 1.0 → fără întunecare; 0.2 → întunecat (preview a ce vei vedea în joc)
	dimmer.color = Color(0.0, 0.0, 0.0, (1.0 - GameManager.brightness) * 0.7)

func _on_volume_changed(value: float) -> void:
	volume_value.text = "%d%%" % int(value * 100)
	GameManager.set_volume(value)

func _on_volume_drag_ended(_value_changed: bool) -> void:
	# Sunet de test la noul volum, ca să auzi nivelul ales
	AudioManager.play_interact()

func _on_sens_changed(value: float) -> void:
	sens_value.text = "%d%%" % int(value * 100)
	GameManager.set_mouse_sensitivity(value)

func _on_quit() -> void:
	get_tree().quit()
