extends CanvasLayer

@onready var health_label: Label = $VBoxContainer/HealthLabel
@onready var ammo_label: Label = $VBoxContainer/AmmoLabel
@onready var kill_feed: VBoxContainer = $VBoxContainer/KillFeed
@onready var death_screen: Control = $DeathScreen
@onready var reload_label: Label = $VBoxContainer/ReloadLabel
@onready var timer_label: Label = $TopCenterContainer/TimerLabel
@onready var round_label: Label = $TopCenterContainer/RoundLabel
@onready var kill_label: Label = $TopCenterContainer/KillLabel
@onready var round_end_screen: Control = $RoundEndScreen
@onready var round_end_label: Label = $RoundEndScreen/RoundEndLabel
@onready var round_scores_label: Label = $RoundEndScreen/RoundScoresLabel
@onready var game_over_screen: Control = $GameOverScreen
@onready var game_over_label: Label = $GameOverScreen/GameOverLabel
@onready var winner_label: Label = $GameOverScreen/WinnerLabel
@onready var final_scores_label: Label = $GameOverScreen/FinalScoresLabel
@onready var pause_menu: Control = $PauseMenu
@onready var crosshair: Crosshair = $Crosshair
@onready var _gm = get_node("/root/GameManager")

const CROSSHAIR_SETTINGS_PATH := "user://crosshair_settings.cfg"
var _ch_panel: Control
var _ch_style_option: OptionButton
var _ch_color_btn: ColorPickerButton
var _ch_size_slider: HSlider
var _ch_size_label: Label
var _ch_thickness_slider: HSlider
var _ch_thickness_label: Label
var _ch_gap_slider: HSlider
var _ch_gap_label: Label
var _ch_opacity_slider: HSlider
var _ch_opacity_label: Label
var _ch_outline_check: CheckBox
var _ch_outline_color_btn: ColorPickerButton
var _ch_reset_btn: Button
var _ch_back_btn: Button


func _ready() -> void:
	$PauseMenu/VBoxContainer/ResumeBtn.pressed.connect(_on_resume_pressed)
	$PauseMenu/VBoxContainer/ExitBtn.pressed.connect(_on_exit_pressed)
	$PauseMenu/VBoxContainer/CrosshairBtn.pressed.connect(_on_crosshair_btn_pressed)
	var player: Node = get_parent()
	if player.has_signal("health_changed"):
		player.health_changed.connect(_update_health)
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(_update_ammo)
	if player.has_signal("died"):
		player.died.connect(_on_died)
	if player.has_signal("reloading_changed"):
		player.reloading_changed.connect(_on_reloading_changed)
	if player.has_signal("reloads_changed"):
		player.reloads_changed.connect(_on_reloads_changed)

	_gm.round_started.connect(_on_round_started)
	_gm.round_ended.connect(_on_round_ended)
	_gm.game_ended.connect(_on_game_ended)
	_gm.time_updated.connect(_on_time_updated)
	_gm.scores_updated.connect(_on_scores_updated)

	round_end_screen.visible = false
	game_over_screen.visible = false

	_build_crosshair_settings()
	_load_crosshair_settings()


func _update_health(new_health: int) -> void:
	health_label.text = "HP: %d/100" % new_health


func _update_ammo(new_ammo: int) -> void:
	ammo_label.text = "Ammo: %d/%d" % [new_ammo, PlayerCharacter.MAX_AMMO]


func _on_reloading_changed(is_reloading: bool) -> void:
	if is_reloading:
		ammo_label.text = "RELOADING..."
	else:
		var player: Node = get_parent()
		ammo_label.text = "Ammo: %d/%d" % [player.ammo, PlayerCharacter.MAX_AMMO]


func _on_reloads_changed(count: int) -> void:
	reload_label.text = "Reloads: %d/%d" % [count, PlayerCharacter.MAX_RELOADS]


func _on_died() -> void:
	death_screen.visible = true
	await get_tree().create_timer(2.0).timeout
	death_screen.visible = false


func _on_time_updated(time_left: float) -> void:
	var total_seconds: int = int(time_left)
	var mins: int = int(total_seconds / 60.0)
	var secs: int = total_seconds % 60
	timer_label.text = "%02d:%02d" % [mins, secs]


func _on_scores_updated(scores: Dictionary) -> void:
	var my_id: int = multiplayer.get_unique_id()
	var my_kills: int = scores.get(my_id, 0)
	kill_label.text = "Kills: %d" % my_kills


func _on_round_started(p_round: int) -> void:
	round_label.text = "Round %d/%d" % [p_round, _gm.MAX_ROUNDS]
	round_end_screen.visible = false
	game_over_screen.visible = false


func _on_round_ended(scores: Dictionary) -> void:
	round_end_screen.visible = true
	var round_num: int = _gm.current_round
	round_end_label.text = "Round %d Selesai!" % round_num

	var score_text: String = ""
	var sorted: Array = []
	for pid in scores:
		sorted.append({"id": pid, "kills": scores[pid]})
	sorted.sort_custom(func(a, b): return a.kills > b.kills)

	for entry in sorted:
		var pname: String = NetworkManager.get_player_name(entry.id)
		score_text += "%s: %d kill" % [pname, entry.kills]
		if entry.kills != 1:
			score_text += "s"
		score_text += "\n"

	if score_text.is_empty():
		score_text = "Tidak ada kill"
	round_scores_label.text = score_text


func _on_game_ended(winner_id: int, final_scores: Dictionary) -> void:
	round_end_screen.visible = false
	game_over_screen.visible = true

	game_over_label.text = "Permainan Selesai!"

	if winner_id == -1:
		winner_label.text = "Tidak ada pemenang"
	else:
		var wname: String = NetworkManager.get_player_name(winner_id)
		winner_label.text = "Pemenang: %s" % wname

	var score_text: String = ""
	var sorted: Array = []
	for pid in final_scores:
		sorted.append({"id": pid, "kills": final_scores[pid]})
	sorted.sort_custom(func(a, b): return a.kills > b.kills)

	for entry in sorted:
		var pname: String = NetworkManager.get_player_name(entry.id)
		score_text += "%s: %d kill" % [pname, entry.kills]
		if entry.kills != 1:
			score_text += "s"
		score_text += "\n"

	if score_text.is_empty():
		score_text = "Tidak ada kill"
	final_scores_label.text = score_text


func toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_menu.visible else Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	pause_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_exit_pressed() -> void:
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_crosshair_btn_pressed() -> void:
	$PauseMenu/VBoxContainer.visible = false
	_ch_panel.visible = true


func _on_ch_back_pressed() -> void:
	_ch_panel.visible = false
	$PauseMenu/VBoxContainer.visible = true


func _on_ch_reset_pressed() -> void:
	crosshair.style = Crosshair.Style.CROSS
	crosshair.crosshair_color = Color.WHITE
	crosshair.crosshair_size = 20.0
	crosshair.thickness = 4.0
	crosshair.gap = 6.0
	crosshair.crosshair_opacity = 0.8
	crosshair.outline = false
	crosshair.outline_color = Color.BLACK
	_update_ch_ui_from_crosshair()
	_save_crosshair_settings()


func _build_crosshair_settings() -> void:
	_ch_panel = Control.new()
	_ch_panel.name = "CrosshairSettings"
	_ch_panel.visible = false
	_ch_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$PauseMenu.add_child(_ch_panel)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ch_panel.add_child(bg)

	var main_vb := VBoxContainer.new()
	main_vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 10)
	main_vb.custom_minimum_size.x = 320
	_ch_panel.add_child(main_vb)

	var title := Label.new()
	title.text = "CROSSHAIR SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	main_vb.add_child(title)
	main_vb.add_child(HSeparator.new())

	# Style
	_ch_style_option = OptionButton.new()
	_ch_style_option.custom_minimum_size.x = 180
	for s in Crosshair.Style.values():
		_ch_style_option.add_item(Crosshair.Style.keys()[s].capitalize(), s)
	_ch_style_option.item_selected.connect(_on_ch_style_changed)
	_ch_add_row(main_vb, "Style:").add_child(_ch_style_option)

	# Color
	_ch_color_btn = ColorPickerButton.new()
	_ch_color_btn.custom_minimum_size.x = 180
	_ch_color_btn.color_changed.connect(_on_ch_color_changed)
	_ch_add_row(main_vb, "Color:").add_child(_ch_color_btn)

	# Size
	_ch_size_slider = HSlider.new()
	_ch_size_slider.min_value = 4.0
	_ch_size_slider.max_value = 40.0
	_ch_size_slider.step = 2.0
	_ch_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ch_size_slider.value_changed.connect(_on_ch_size_changed)
	_ch_size_label = Label.new()
	_ch_size_label.custom_minimum_size.x = 36
	var size_hb := _ch_add_row(main_vb, "Size:")
	size_hb.add_child(_ch_size_slider)
	size_hb.add_child(_ch_size_label)

	# Thickness
	_ch_thickness_slider = HSlider.new()
	_ch_thickness_slider.min_value = 1.0
	_ch_thickness_slider.max_value = 10.0
	_ch_thickness_slider.step = 1.0
	_ch_thickness_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ch_thickness_slider.value_changed.connect(_on_ch_thickness_changed)
	_ch_thickness_label = Label.new()
	_ch_thickness_label.custom_minimum_size.x = 36
	var thick_hb := _ch_add_row(main_vb, "Thickness:")
	thick_hb.add_child(_ch_thickness_slider)
	thick_hb.add_child(_ch_thickness_label)

	# Gap
	_ch_gap_slider = HSlider.new()
	_ch_gap_slider.min_value = 0.0
	_ch_gap_slider.max_value = 30.0
	_ch_gap_slider.step = 1.0
	_ch_gap_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ch_gap_slider.value_changed.connect(_on_ch_gap_changed)
	_ch_gap_label = Label.new()
	_ch_gap_label.custom_minimum_size.x = 36
	var gap_hb := _ch_add_row(main_vb, "Gap:")
	gap_hb.add_child(_ch_gap_slider)
	gap_hb.add_child(_ch_gap_label)

	# Opacity
	_ch_opacity_slider = HSlider.new()
	_ch_opacity_slider.min_value = 0.0
	_ch_opacity_slider.max_value = 100.0
	_ch_opacity_slider.step = 1.0
	_ch_opacity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ch_opacity_slider.value_changed.connect(_on_ch_opacity_changed)
	_ch_opacity_label = Label.new()
	_ch_opacity_label.custom_minimum_size.x = 40
	var op_hb := _ch_add_row(main_vb, "Opacity:")
	op_hb.add_child(_ch_opacity_slider)
	op_hb.add_child(_ch_opacity_label)

	# Outline
	_ch_outline_check = CheckBox.new()
	_ch_outline_check.toggled.connect(_on_ch_outline_toggled)
	_ch_add_row(main_vb, "Outline:").add_child(_ch_outline_check)

	# Outline Color
	_ch_outline_color_btn = ColorPickerButton.new()
	_ch_outline_color_btn.custom_minimum_size.x = 180
	_ch_outline_color_btn.color_changed.connect(_on_ch_outline_color_changed)
	_ch_add_row(main_vb, "Outline Color:").add_child(_ch_outline_color_btn)

	main_vb.add_child(HSeparator.new())

	# Reset & Back
	var btn_hb := HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	_ch_reset_btn = Button.new()
	_ch_reset_btn.text = "Reset to Defaults"
	_ch_reset_btn.pressed.connect(_on_ch_reset_pressed)
	_ch_back_btn = Button.new()
	_ch_back_btn.text = "Back"
	_ch_back_btn.pressed.connect(_on_ch_back_pressed)
	btn_hb.add_child(_ch_reset_btn)
	btn_hb.add_child(_ch_back_btn)
	main_vb.add_child(btn_hb)


func _ch_add_row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size.y = 28
	if not label_text.is_empty():
		var lb := Label.new()
		lb.text = label_text
		lb.custom_minimum_size.x = 100
		hb.add_child(lb)
	parent.add_child(hb)
	return hb


func _update_ch_ui_from_crosshair() -> void:
	_ch_style_option.select(crosshair.style)
	_ch_color_btn.color = crosshair.crosshair_color
	_ch_size_slider.value = crosshair.crosshair_size
	_ch_size_label.text = str(crosshair.crosshair_size)
	_ch_thickness_slider.value = crosshair.thickness
	_ch_thickness_label.text = str(crosshair.thickness)
	_ch_gap_slider.value = crosshair.gap
	_ch_gap_label.text = str(crosshair.gap)
	_ch_opacity_slider.value = crosshair.crosshair_opacity * 100.0
	_ch_opacity_label.text = str(crosshair.crosshair_opacity * 100.0) + "%"
	_ch_outline_check.button_pressed = crosshair.outline
	_ch_outline_color_btn.color = crosshair.outline_color
	_ch_outline_color_btn.disabled = not crosshair.outline


func _on_ch_style_changed(index: int) -> void:
	crosshair.style = index as Crosshair.Style
	_save_crosshair_settings()


func _on_ch_color_changed(color: Color) -> void:
	crosshair.crosshair_color = color
	_save_crosshair_settings()


func _on_ch_size_changed(value: float) -> void:
	crosshair.crosshair_size = value
	_ch_size_label.text = str(value)
	_save_crosshair_settings()


func _on_ch_thickness_changed(value: float) -> void:
	crosshair.thickness = value
	_ch_thickness_label.text = str(value)
	_save_crosshair_settings()


func _on_ch_gap_changed(value: float) -> void:
	crosshair.gap = value
	_ch_gap_label.text = str(value)
	_save_crosshair_settings()


func _on_ch_opacity_changed(value: float) -> void:
	var v := value / 100.0
	crosshair.crosshair_opacity = v
	_ch_opacity_label.text = str(value) + "%"
	_save_crosshair_settings()


func _on_ch_outline_toggled(pressed: bool) -> void:
	crosshair.outline = pressed
	_ch_outline_color_btn.disabled = not pressed
	_save_crosshair_settings()


func _on_ch_outline_color_changed(color: Color) -> void:
	crosshair.outline_color = color
	_save_crosshair_settings()


func _save_crosshair_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("crosshair", "style", crosshair.style)
	cfg.set_value("crosshair", "color", crosshair.crosshair_color.to_html())
	cfg.set_value("crosshair", "size", crosshair.crosshair_size)
	cfg.set_value("crosshair", "thickness", crosshair.thickness)
	cfg.set_value("crosshair", "gap", crosshair.gap)
	cfg.set_value("crosshair", "opacity", crosshair.crosshair_opacity)
	cfg.set_value("crosshair", "outline", crosshair.outline)
	cfg.set_value("crosshair", "outline_color", crosshair.outline_color.to_html())
	cfg.save(CROSSHAIR_SETTINGS_PATH)


func _load_crosshair_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CROSSHAIR_SETTINGS_PATH) != OK:
		_update_ch_ui_from_crosshair()
		return

	crosshair.style = cfg.get_value("crosshair", "style", crosshair.style) as Crosshair.Style
	crosshair.crosshair_color = Color(cfg.get_value("crosshair", "color", crosshair.crosshair_color.to_html()))
	crosshair.crosshair_size = cfg.get_value("crosshair", "size", crosshair.crosshair_size)
	crosshair.thickness = cfg.get_value("crosshair", "thickness", crosshair.thickness)
	crosshair.gap = cfg.get_value("crosshair", "gap", crosshair.gap)
	crosshair.crosshair_opacity = cfg.get_value("crosshair", "opacity", crosshair.crosshair_opacity)
	crosshair.outline = cfg.get_value("crosshair", "outline", crosshair.outline)
	crosshair.outline_color = Color(cfg.get_value("crosshair", "outline_color", crosshair.outline_color.to_html()))
	_update_ch_ui_from_crosshair()
