extends Control

var session: LocalSession = null
var auto_ai: bool = true

var _ai_timer: Timer = null
var _pending_guard_card: bool = false

# Top bar UI
var _phase_label: Label = null
var _dice_widget: DicePairWidget = null
var _menu_btn: Button = null
var _menu_popup: PopupMenu = null
var _step_top_btn: Button = null

# Main split
var _board_view: BoardView = null
var _center_split: HSplitContainer = null
var _scoreboard_box: VBoxContainer = null
var _status_banner_label: Label = null

# Bottom visual card hand bar
var _hand_bar_panel: PanelContainer = null
var _res_card_refs: Dictionary = {}
var _action_chips: Dictionary = {}
var _prev_dash_hand: Dictionary = {}
var _prev_dash_pid: int = -1

# Dice animation tracking
var _last_seen_dice: Vector2i = Vector2i.ZERO
var _roll_fx_count: int = 0
# Sound
var _sfx: Sfx = null
var _sfx_prev_current: int = -1
var _sfx_won: bool = false

# Hot-seat view indicator (hand bar)
var _hand_view_swatch: ColorRect = null
var _hand_view_name: Label = null

# Hot-seat device-pass privacy
var _revealed_pid: int = -1
var _prev_view_pid: int = -1
var _device_pass_cover: PanelContainer = null
var _device_pass_label: Label = null
var _device_pass_btn: Button = null

# Action buttons that must not be activated by the Space key
var _no_space_focus_btns: Array = []

# Discard panel
var _discard_panel: PanelContainer = null
var _discard_info_label: Label = null
var _auto_discard_btn: Button = null

# Action buttons
var _trade_btn: Button = null
var _buy_card_btn: Button = null
var _cancel_pick_btn: Button = null
var _end_turn_btn: Button = null

# Build card rows: key -> {btn, marker, cost, name}
var _build_rows: Dictionary = {}
var _build_bubble: PanelContainer = null
var _build_bubble_title: Label = null
var _build_bubble_cost_box: HBoxContainer = null
var _build_bubble_build_btn: Button = null
var _build_bubble_cancel_btn: Button = null
var _build_pending: Dictionary = {}
var _hint_sig: String = ""

# Trade tray (compact panel in the layout flow, above the bottom bar)
var _trade_tray: PanelContainer = null
var _trade_content: VBoxContainer = null
var _trade_headline: Label = null
var _trade_have_label: Label = null
var _trade_summary: Label = null
var _trade_respond_row: HBoxContainer = null
var _trade_propose_body: HBoxContainer = null
var _trade_summary_row: HBoxContainer = null
var _trade_steppers_col: VBoxContainer = null
var _trade_side_col: VBoxContainer = null
var _trade_ask_group: VBoxContainer = null
var _trade_give_counts: Dictionary = {}
var _trade_get_counts: Dictionary = {}
var _trade_give_gui: Dictionary = {}
var _trade_get_gui: Dictionary = {}
var _trade_ask_btn: Button = null
var _trade_withdraw_btn: Button = null
var _trade_clear_btn: Button = null
var _ot_accept_btn: Button = null
var _ot_decline_btn: Button = null
var _ot_counter_btn: Button = null
var _ot_send_btn: Button = null
var _ot_back_btn: Button = null
var _trade_bank_btn: Button = null
var _trade_partner_row: HBoxContainer = null
var _trade_respond_mode: bool = false
var _trade_counter_mode: bool = false
var _trade_reopen_token: String = ""
var _trade_last_ot_open: bool = false
var _trade_view_pid: int = -1
var _trade_ready_dismissed: bool = false
var _trade_opened_auto: bool = false
var _trade_proposer_hint: bool = false
var _trade_hint_tween: Tween = null

# Context sub-panels (Harvest Bounty, Trade Decree)
var _subpanel_container: PanelContainer = null
var _subpanel_owner_pid: int = -1

var _bounty_box: VBoxContainer = null
var _bounty_res1_opt: OptionButton = null
var _bounty_res2_opt: OptionButton = null

var _decree_box: VBoxContainer = null
var _decree_res_opt: OptionButton = null

# Event log
var _event_log: RichTextLabel = null
var _log_panel: PanelContainer = null
var _log_toggle_btn: Button = null

# Lobby modal
var _lobby_overlay: ColorRect = null
var _num_players_opt: OptionButton = null
var _seat_rows: Array[HBoxContainer] = []
var _seat_type_opts: Array[OptionButton] = []
var _seed_input: LineEdit = null
var _balanced_check: CheckBox = null
var _lobby_cancel_btn: Button = null

# Settings & Help overlays
var _settings_overlay: ColorRect = null
var _help_overlay: ColorRect = null
var _settings_diff_opt: OptionButton = null
var _settings_mute_check: CheckBox = null
var _settings_text_opt: OptionButton = null
var _settings_speed_opt: OptionButton = null
var _settings_motion_check: CheckBox = null
var _settings_auto_check: CheckBox = null
var _settings_step_btn: Button = null
var _settings_ai_difficulty: int = 2
var _settings_muted: bool = false
var _settings_text_idx: int = 0
var _settings_speed_idx: int = 1
var _reduce_motion: bool = false

static var settings_path: String = "user://settings.cfg"
const TEXT_SCALE_VALUES: Array[float] = [1.0, 1.15, 1.3]
const BOT_SPEED_VALUES: Array[float] = [0.6, 0.25, 0.08]

func _ready() -> void:
	_sfx = Sfx.new()
	_sfx.name = "Sfx"
	add_child(_sfx)
	randomize()
	_load_settings()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session = LocalSession.new()
	session.state_updated.connect(_on_state_updated)
	session.action_rejected.connect(_on_action_rejected)

	_build_ui()
	_setup_timer()
	_apply_settings()
	_start_match_from_lobby_settings()
	_lobby_overlay.visible = false

func _setup_timer() -> void:
	_ai_timer = Timer.new()
	_ai_timer.wait_time = 0.25
	_ai_timer.one_shot = false
	_ai_timer.autostart = true
	_ai_timer.timeout.connect(_on_ai_timer_tick)
	add_child(_ai_timer)

func _on_ai_timer_tick() -> void:
	if not auto_ai or session == null or session.state == null:
		return
	if _any_overlay_visible():
		return
	if session.is_ai_to_act():
		session.step_ai()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.SEA
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# 1. Top Bar: title + one-line instruction banner + muted turn counter
	var top_panel := PanelContainer.new()
	var top_style := _paper_panel_style()
	top_style.set_corner_radius_all(0)
	top_style.shadow_size = 0
	top_style.border_width_top = 0
	top_style.border_width_left = 0
	top_style.border_width_right = 0
	top_style.border_width_bottom = 3
	top_style.content_margin_left = 14
	top_style.content_margin_right = 14
	top_style.content_margin_top = 6
	top_style.content_margin_bottom = 6
	top_panel.add_theme_stylebox_override("panel", top_style)
	root_vbox.add_child(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_panel.add_child(top_hbox)

	_menu_btn = Button.new()
	_menu_btn.text = "☰"
	_menu_btn.tooltip_text = "Menu (M)"
	_menu_btn.custom_minimum_size = Vector2(44, 40)
	_menu_btn.add_theme_font_size_override("font_size", 18)
	_style_button(_menu_btn, "ghost")
	_menu_popup = PopupMenu.new()
	_menu_popup.add_item("New game…", 0)
	_menu_popup.set_item_tooltip(0, "Open the lobby to start a new match")
	_menu_popup.add_item("Settings…", 1)
	_menu_popup.set_item_tooltip(1, "Bots, sound, text size and motion")
	_menu_popup.add_item("How to play", 2)
	_menu_popup.set_item_tooltip(2, "Rules and keyboard shortcuts (F1)")
	_menu_popup.add_separator()
	_menu_popup.add_item("Quit", 4)
	_style_popup(_menu_popup)
	_menu_popup.id_pressed.connect(_on_menu_item)
	_menu_btn.add_child(_menu_popup)
	_menu_btn.pressed.connect(_open_menu_popup)
	top_hbox.add_child(_menu_btn)

	var title_lbl := Label.new()
	title_lbl.text = "Founders: Barter & Block"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Palette.HEADING)
	top_hbox.add_child(title_lbl)

	_status_banner_label = Label.new()
	_set_banner("Your turn — click the dice to roll.")
	_status_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_banner_label.add_theme_font_size_override("font_size", 16)
	_status_banner_label.add_theme_color_override("font_color", Palette.TEXT)
	top_hbox.add_child(_status_banner_label)

	_phase_label = Label.new()
	_phase_label.text = "Turn 1"
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 13)
	_phase_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	top_hbox.add_child(_phase_label)

	_step_top_btn = Button.new()
	_step_top_btn.text = "Step bot"
	_step_top_btn.tooltip_text = "Make the current bot take one action"
	_step_top_btn.custom_minimum_size = Vector2(0, 36)
	_step_top_btn.add_theme_font_size_override("font_size", 13)
	_style_button(_step_top_btn, "ghost")
	_step_top_btn.visible = false
	_step_top_btn.pressed.connect(_step_bot_now)
	top_hbox.add_child(_step_top_btn)

	# 2. Center Split (left column: board + trade tray | right panel)
	_center_split = HSplitContainer.new()
	_center_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_center_split)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 0)
	_center_split.add_child(left_column)

	_board_view = BoardView.new()
	_board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.vertex_clicked.connect(_on_board_vertex_clicked)
	_board_view.edge_clicked.connect(_on_board_edge_clicked)
	_board_view.tile_clicked.connect(_on_board_tile_clicked)
	_board_view.build_spot_clicked.connect(_on_build_spot_clicked)
	left_column.add_child(_board_view)

	_build_trade_tray(left_column)
	_build_build_bubble()

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(320, 0)
	var right_style := _paper_panel_style(true)
	right_style.set_corner_radius_all(0)
	right_style.shadow_size = 0
	right_style.border_width_top = 0
	right_style.border_width_right = 0
	right_style.border_width_bottom = 0
	right_style.border_width_left = 3
	right_style.content_margin_left = 12
	right_style.content_margin_right = 12
	right_style.content_margin_top = 10
	right_style.content_margin_bottom = 10
	right_panel.add_theme_stylebox_override("panel", right_style)
	_center_split.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	# Scrollable upper content (scoreboard, build, context panels)
	var top_scroll := ScrollContainer.new()
	top_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(top_scroll)

	var top_vbox := VBoxContainer.new()
	top_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_vbox.add_theme_constant_override("separation", 8)
	top_scroll.add_child(top_vbox)

	# Player Scoreboard Section
	var sb_title := Label.new()
	sb_title.text = "PLAYER SCOREBOARD"
	sb_title.add_theme_font_size_override("font_size", 14)
	sb_title.add_theme_color_override("font_color", Palette.HEADING)
	top_vbox.add_child(sb_title)

	_scoreboard_box = VBoxContainer.new()
	_scoreboard_box.add_theme_constant_override("separation", 4)
	top_vbox.add_child(_scoreboard_box)

	# Build card (Road / Settlement / City rows)
	var build_title := Label.new()
	build_title.text = "BUILD"
	build_title.add_theme_font_size_override("font_size", 14)
	build_title.add_theme_color_override("font_color", Palette.HEADING)
	top_vbox.add_child(build_title)

	_build_build_card(top_vbox)

	_cancel_pick_btn = Button.new()
	_cancel_pick_btn.text = "Cancel Board Selection"
	_cancel_pick_btn.visible = false
	_cancel_pick_btn.tooltip_text = "Cancel the current board selection"
	_style_button(_cancel_pick_btn, "danger")
	_cancel_pick_btn.pressed.connect(_cancel_current_pick)
	_guard_action_button_focus(_cancel_pick_btn)
	top_vbox.add_child(_cancel_pick_btn)

	# Discard Panel (on a 7 roll when Human has >7 cards)
	_discard_panel = _make_card_panel(Color(Palette.ACCENT_RED, 0.22))
	_discard_panel.visible = false
	top_vbox.add_child(_discard_panel)
	var disc_vbox := VBoxContainer.new()
	disc_vbox.add_theme_constant_override("separation", 6)
	_discard_panel.add_child(disc_vbox)
	_discard_info_label = Label.new()
	_discard_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_discard_info_label.add_theme_font_size_override("font_size", 13)
	_discard_info_label.add_theme_color_override("font_color", Palette.TEXT)
	disc_vbox.add_child(_discard_info_label)
	_auto_discard_btn = Button.new()
	_auto_discard_btn.text = "Auto-Discard Required Cards"
	_style_button(_auto_discard_btn, "danger")
	_auto_discard_btn.pressed.connect(_on_auto_discard_pressed)
	disc_vbox.add_child(_auto_discard_btn)

	# Context sub-panels (Maritime, Barter, Bounty, Decree)
	_build_subpanels(top_vbox)

	# Event Log (collapsed by default, expands into remaining height)
	var log_header := HBoxContainer.new()
	log_header.add_theme_constant_override("separation", 8)
	right_vbox.add_child(log_header)

	var log_title := Label.new()
	log_title.text = "EVENT LOG"
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_title.add_theme_font_size_override("font_size", 14)
	log_title.add_theme_color_override("font_color", Palette.HEADING)
	log_header.add_child(log_title)

	_log_toggle_btn = Button.new()
	_log_toggle_btn.text = "Show log"
	_log_toggle_btn.toggle_mode = true
	_log_toggle_btn.button_pressed = false
	_log_toggle_btn.tooltip_text = "Show or hide the event log"
	_log_toggle_btn.add_theme_font_size_override("font_size", 13)
	_style_button(_log_toggle_btn, "ghost")
	_log_toggle_btn.toggled.connect(func(on: bool) -> void:
		_log_toggle_btn.text = "Hide log" if on else "Show log"
		if on:
			_log_panel.custom_minimum_size = Vector2(0, 200)
			_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			_log_panel.custom_minimum_size = Vector2(0, 48)
			_log_panel.size_flags_vertical = Control.SIZE_FILL
	)
	log_header.add_child(_log_toggle_btn)

	_log_panel = _make_card_panel(Palette.PANEL_BG_ALT)
	_log_panel.custom_minimum_size = Vector2(0, 48)
	right_vbox.add_child(_log_panel)

	_event_log = RichTextLabel.new()
	_event_log.bbcode_enabled = true
	_event_log.scroll_following = true
	_event_log.selection_enabled = true
	_event_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_rich_label(_event_log)
	_log_panel.add_child(_event_log)

	# 3. Bottom Visual Card Hand Bar (always visible)
	_build_hand_bar(root_vbox)

	# 4. Modal Overlays (lobby, settings, help — help is topmost)
	_build_lobby_overlay()
	_build_settings_overlay()
	_build_help_overlay()

func _build_build_card(parent: VBoxContainer) -> void:
	var card := _make_card_panel(Palette.PANEL_BG_ALT)
	var card_style: StyleBoxFlat = card.get_theme_stylebox("panel")
	card_style.set_border_width_all(0)
	card_style.shadow_size = 0
	parent.add_child(card)

	var rows_vbox := VBoxContainer.new()
	rows_vbox.add_theme_constant_override("separation", 5)
	card.add_child(rows_vbox)

	var rows_def := [
		["road", "Road", {
			GameTypes.ResourceType.TIMBER: 1,
			GameTypes.ResourceType.CLAY: 1,
		}],
		["settlement", "Settlement", {
			GameTypes.ResourceType.TIMBER: 1,
			GameTypes.ResourceType.CLAY: 1,
			GameTypes.ResourceType.FLEECE: 1,
			GameTypes.ResourceType.GRAIN: 1,
		}],
		["city", "City", {
			GameTypes.ResourceType.GRAIN: 2,
			GameTypes.ResourceType.IRON: 3,
		}],
	]
	for def in rows_def:
		var key: String = str(def[0])
		var display_name: String = str(def[1])
		var cost: Dictionary = def[2]

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hbox := HBoxContainer.new()
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 10
		hbox.offset_right = -8
		hbox.offset_top = 4
		hbox.offset_bottom = -4
		hbox.add_theme_constant_override("separation", 6)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hbox)

		var row_labels: Array = []

		var name_lbl := Label.new()
		name_lbl.text = display_name
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		row_labels.append(name_lbl)

		var cost_box := HBoxContainer.new()
		cost_box.add_theme_constant_override("separation", 6)
		cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(cost_box)
		for r in GameTypes.ALL_RESOURCES:
			var amt: int = int(cost.get(r, 0))
			if amt <= 0:
				continue
			var cell := _make_cost_cell(r, amt)
			row_labels.append(cell.get_child(1))
			cost_box.add_child(cell)

		var marker := Label.new()
		marker.text = ""
		marker.custom_minimum_size = Vector2(18, 0)
		marker.add_theme_font_size_override("font_size", 15)
		marker.add_theme_color_override("font_color", Palette.ACCENT_GREEN)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(marker)

		match key:
			"road":
				btn.pressed.connect(_on_build_road_pressed)
			"settlement":
				btn.pressed.connect(_on_build_settlement_pressed)
			"city":
				btn.pressed.connect(_on_upgrade_city_pressed)
		_apply_build_row_style(btn, false)
		rows_vbox.add_child(btn)
		_guard_action_button_focus(btn)
		_build_rows[key] = {"btn": btn, "marker": marker, "cost": cost, "name": display_name, "labels": row_labels}

func _make_cost_cell(r: int, amt: int) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 3)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sq := Panel.new()
	sq.custom_minimum_size = Vector2(12, 12)
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sqs := StyleBoxFlat.new()
	sqs.bg_color = Palette.resource(r)
	sqs.border_color = Color(Palette.INK, 0.6)
	sqs.set_border_width_all(1)
	sqs.set_corner_radius_all(3)
	sq.add_theme_stylebox_override("panel", sqs)
	cell.add_child(sq)
	var cost_lbl := Label.new()
	cost_lbl.text = "%d %s" % [amt, GameTypes.resource_name(r).left(1)]
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Palette.TEXT)
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(cost_lbl)
	return cell

func _apply_build_row_style(btn: Button, enabled: bool) -> void:
	var st := StyleBoxFlat.new()
	if enabled:
		st.bg_color = Palette.PANEL_BG
		st.border_color = Palette.ACCENT_GREEN
	else:
		st.bg_color = Palette.BUTTON_BG_DISABLED
		st.border_color = Color(Palette.PANEL_BORDER, 0.5)
	st.border_width_left = 4
	st.border_width_top = 2
	st.border_width_right = 2
	st.border_width_bottom = 2
	st.set_corner_radius_all(8)
	st.content_margin_left = 8
	st.content_margin_right = 6
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", st)

	var st_h: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	if enabled:
		st_h.bg_color = Palette.PANEL_BG.lightened(0.03)
	btn.add_theme_stylebox_override("hover", st_h)

	var st_p: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	if enabled:
		st_p.bg_color = Palette.PAPER_DARK
	btn.add_theme_stylebox_override("pressed", st_p)

	var st_d: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	btn.add_theme_stylebox_override("disabled", st_d)

	var st_f: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	st_f.bg_color = Color(Palette.PANEL_BG, 0.0)
	st_f.border_color = Palette.HEADING
	st_f.border_width_top = 3
	st_f.border_width_right = 3
	st_f.border_width_bottom = 3
	btn.add_theme_stylebox_override("focus", st_f)

func _build_hand_bar(root_vbox: VBoxContainer) -> void:
	_hand_bar_panel = PanelContainer.new()
	var st := _paper_panel_style()
	st.set_corner_radius_all(0)
	st.shadow_size = 0
	st.border_width_left = 0
	st.border_width_right = 0
	st.border_width_bottom = 0
	st.border_width_top = 3
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	_hand_bar_panel.add_theme_stylebox_override("panel", st)
	root_vbox.add_child(_hand_bar_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	_hand_bar_panel.add_child(hb)

	_hand_view_swatch = ColorRect.new()
	_hand_view_swatch.custom_minimum_size = Vector2(10, 58)
	_hand_view_swatch.color = Palette.SEA
	_hand_view_swatch.visible = false
	_hand_view_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_hand_view_swatch)

	_hand_view_name = Label.new()
	_hand_view_name.add_theme_font_size_override("font_size", 13)
	_hand_view_name.add_theme_color_override("font_color", Palette.HEADING)
	_hand_view_name.visible = false
	_hand_view_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_hand_view_name)

	for r in GameTypes.ALL_RESOURCES:
		var card := Button.new()
		card.custom_minimum_size = Vector2(60, 58)
		_style_card_button(card)
		card.tooltip_text = "Click to offer in a trade"

		var cv_panel := PanelContainer.new()
		cv_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cv_panel.offset_left = 5
		cv_panel.offset_top = 4
		cv_panel.offset_right = -5
		cv_panel.offset_bottom = -4
		cv_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		card.add_child(cv_panel)

		var cv := VBoxContainer.new()
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_theme_constant_override("separation", 2)
		cv_panel.add_child(cv)

		var strip := ColorRect.new()
		strip.custom_minimum_size = Vector2(0, 8)
		strip.color = Palette.resource(r)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(strip)

		var name_lbl := Label.new()
		name_lbl.text = GameTypes.resource_name(r)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.text = "x0"
		count_lbl.add_theme_font_size_override("font_size", 16)
		count_lbl.add_theme_color_override("font_color", Palette.INK)
		count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(count_lbl)

		var res_id := r
		card.pressed.connect(func() -> void: _on_resource_card_pressed(res_id))
		hb.add_child(card)
		_res_card_refs[r] = {"card": card, "count": count_lbl}

	var div0 := VSeparator.new()
	div0.add_theme_constant_override("separation", 4)
	hb.add_child(div0)

	_trade_btn = Button.new()
	_trade_btn.text = "Trade"
	_trade_btn.custom_minimum_size = Vector2(76, 40)
	_trade_btn.add_theme_font_size_override("font_size", 14)
	_trade_btn.tooltip_text = "Open the trade panel (T)"
	_style_button(_trade_btn, "primary")
	_trade_btn.pressed.connect(_toggle_trade_tray)
	_guard_action_button_focus(_trade_btn)
	hb.add_child(_trade_btn)

	var div := VSeparator.new()
	div.add_theme_constant_override("separation", 4)
	hb.add_child(div)

	var chip_defs := [
		[GameTypes.DevCardType.GUARD, "Guard", Palette.SEA_DEEP],
		[GameTypes.DevCardType.ROAD_WORK, "Road Work", Palette.CLAY_SHADE],
		[GameTypes.DevCardType.HARVEST_BOUNTY, "Bounty", Palette.ACCENT_GOLD],
		[GameTypes.DevCardType.TRADE_DECREE, "Decree", Palette.MOUNTAIN_SHADE],
		[GameTypes.DevCardType.CHARTER_POINT, "Charter", Palette.ACCENT_GREEN],
	]
	for def in chip_defs:
		var ctype: int = int(def[0])
		var accent: Color = def[2]
		var chip := Button.new()
		chip.text = "%s x0" % str(def[1])
		chip.custom_minimum_size = Vector2(0, 40)
		chip.add_theme_font_size_override("font_size", 13)
		_style_button(chip, "normal")
		_tighten_button_margins(chip, 6)
		chip.add_theme_color_override("font_color", accent.darkened(0.25))
		chip.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)
		match ctype:
			GameTypes.DevCardType.GUARD:
				chip.pressed.connect(_on_play_guard_pressed)
			GameTypes.DevCardType.ROAD_WORK:
				chip.pressed.connect(_on_play_road_work_pressed)
			GameTypes.DevCardType.HARVEST_BOUNTY:
				chip.pressed.connect(_on_play_bounty_pressed)
			GameTypes.DevCardType.TRADE_DECREE:
				chip.pressed.connect(_on_play_decree_pressed)
		chip.disabled = true
		_guard_action_button_focus(chip)
		hb.add_child(chip)
		_action_chips[ctype] = chip

	_buy_card_btn = Button.new()
	_buy_card_btn.text = "Buy card"
	_buy_card_btn.custom_minimum_size = Vector2(0, 40)
	_buy_card_btn.add_theme_font_size_override("font_size", 13)
	_buy_card_btn.tooltip_text = "Buy an Action Card: 1 Fleece + 1 Grain + 1 Iron"
	_style_button(_buy_card_btn, "normal")
	_tighten_button_margins(_buy_card_btn, 6)
	_buy_card_btn.pressed.connect(_on_buy_dev_pressed)
	_buy_card_btn.disabled = true
	_guard_action_button_focus(_buy_card_btn)
	hb.add_child(_buy_card_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)

	_dice_widget = DicePairWidget.new()
	_dice_widget.tooltip_text = "Last Roll"
	_dice_widget.pressed.connect(_on_roll_pressed)
	hb.add_child(_dice_widget)

	var dice_gap := Control.new()
	dice_gap.custom_minimum_size = Vector2(6, 0)
	dice_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(dice_gap)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_end_turn_btn.custom_minimum_size = Vector2(130, 52)
	_end_turn_btn.add_theme_font_size_override("font_size", 16)
	_end_turn_btn.tooltip_text = "End your turn (E)"
	_style_button(_end_turn_btn, "normal")
	_end_turn_btn.disabled = true
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_guard_action_button_focus(_end_turn_btn)
	hb.add_child(_end_turn_btn)

	_build_device_pass_cover()

func _build_subpanels(parent: VBoxContainer) -> void:
	_subpanel_container = _make_card_panel(Palette.PANEL_BG_ALT)
	_subpanel_container.visible = false
	parent.add_child(_subpanel_container)

	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	_subpanel_container.add_child(holder)

	# Harvest Bounty subpanel
	_bounty_box = VBoxContainer.new()
	_bounty_box.visible = false
	holder.add_child(_bounty_box)
	var hb_lbl := Label.new()
	hb_lbl.text = "Harvest Bounty: Pick 2 Free Resources"
	hb_lbl.add_theme_font_size_override("font_size", 14)
	hb_lbl.add_theme_color_override("font_color", Palette.HEADING)
	_bounty_box.add_child(hb_lbl)
	var hb_row := HBoxContainer.new()
	_bounty_box.add_child(hb_row)
	_bounty_res1_opt = OptionButton.new()
	_bounty_res1_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option(_bounty_res1_opt)
	_bounty_res2_opt = OptionButton.new()
	_bounty_res2_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_option(_bounty_res2_opt)
	for r in GameTypes.ALL_RESOURCES:
		_bounty_res1_opt.add_item(GameTypes.resource_name(r), r)
		_bounty_res2_opt.add_item(GameTypes.resource_name(r), r)
	hb_row.add_child(_bounty_res1_opt)
	hb_row.add_child(_bounty_res2_opt)
	var hb_exec := Button.new()
	hb_exec.text = "Claim 2 Resources"
	_style_button(hb_exec, "primary")
	hb_exec.pressed.connect(func() -> void:
		if session == null or session.state == null or not _is_human_acting():
			return
		if session.get_acting_player_id() != _subpanel_owner_pid:
			_subpanel_container.visible = false
			_bounty_box.visible = false
			_subpanel_owner_pid = -1
			return
		var r1 := _bounty_res1_opt.get_selected_id()
		var r2 := _bounty_res2_opt.get_selected_id()
		_subpanel_container.visible = false
		_subpanel_owner_pid = -1
		_submit_human_action(GameAction.play_harvest_bounty(r1, r2))
	)
	_bounty_box.add_child(hb_exec)

	# Trade Decree subpanel
	_decree_box = VBoxContainer.new()
	_decree_box.visible = false
	holder.add_child(_decree_box)
	var td_lbl := Label.new()
	td_lbl.text = "Trade Decree: Claim All of 1 Resource Type"
	td_lbl.add_theme_font_size_override("font_size", 14)
	td_lbl.add_theme_color_override("font_color", Palette.HEADING)
	_decree_box.add_child(td_lbl)
	_decree_res_opt = OptionButton.new()
	for r in GameTypes.ALL_RESOURCES:
		_decree_res_opt.add_item(GameTypes.resource_name(r), r)
	_style_option(_decree_res_opt)
	_decree_box.add_child(_decree_res_opt)
	var td_exec := Button.new()
	td_exec.text = "Declare Trade Decree"
	_style_button(td_exec, "primary")
	td_exec.pressed.connect(func() -> void:
		if session == null or session.state == null or not _is_human_acting():
			return
		if session.get_acting_player_id() != _subpanel_owner_pid:
			_subpanel_container.visible = false
			_decree_box.visible = false
			_subpanel_owner_pid = -1
			return
		var r := _decree_res_opt.get_selected_id()
		_subpanel_container.visible = false
		_subpanel_owner_pid = -1
		_submit_human_action(GameAction.play_trade_decree(r))
	)
	_decree_box.add_child(td_exec)

func _build_lobby_overlay() -> void:
	_lobby_overlay = ColorRect.new()
	_lobby_overlay.color = Color(Palette.INK, 0.62)
	_lobby_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_lobby_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby_overlay.add_child(center)

	var modal := _make_card_panel(Palette.PANEL_BG)
	modal.custom_minimum_size = Vector2(460, 380)
	center.add_child(modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	modal.add_child(vbox)

	var title := Label.new()
	title.text = "New game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Palette.HEADING)
	vbox.add_child(title)

	var np_row := HBoxContainer.new()
	vbox.add_child(np_row)
	var np_lbl := Label.new()
	np_lbl.text = "Number of Seats:"
	np_lbl.add_theme_font_size_override("font_size", 14)
	np_lbl.add_theme_color_override("font_color", Palette.TEXT)
	np_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	np_row.add_child(np_lbl)
	_num_players_opt = OptionButton.new()
	_num_players_opt.add_item("2 Players", 2)
	_num_players_opt.add_item("3 Players", 3)
	_num_players_opt.add_item("4 Players", 4)
	_num_players_opt.select(2) # Default 4 players
	_style_option(_num_players_opt)
	_num_players_opt.item_selected.connect(func(_idx: int) -> void:
		_update_lobby_seat_rows()
	)
	np_row.add_child(_num_players_opt)

	_seat_rows.clear()
	_seat_type_opts.clear()
	for i in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(18, 18)
		sw.color = GameTypes.PLAYER_COLORS[i]
		row.add_child(sw)
		var s_lbl := Label.new()
		s_lbl.text = "Seat %d (%s):" % [i + 1, GameTypes.PLAYER_NAMES[i]]
		s_lbl.add_theme_font_size_override("font_size", 14)
		s_lbl.add_theme_color_override("font_color", Palette.TEXT)
		s_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(s_lbl)
		var opt := OptionButton.new()
		opt.add_item("Human", SeatConfig.SeatType.HUMAN)
		opt.add_item("AI (Easy)", SeatConfig.SeatType.AI_EASY)
		opt.add_item("AI (Medium)", SeatConfig.SeatType.AI_MEDIUM)
		opt.add_item("AI (Hard)", SeatConfig.SeatType.AI_HARD)
		var sel_type: int = 0 if i == 0 else _settings_ai_difficulty
		opt.select(opt.get_item_index(sel_type)) # Seat 0 = Human, bots use the settings difficulty
		_style_option(opt)
		row.add_child(opt)
		_seat_rows.append(row)
		_seat_type_opts.append(opt)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	vbox.add_child(seed_row)
	var seed_lbl := Label.new()
	seed_lbl.text = "Board Seed:"
	seed_lbl.add_theme_font_size_override("font_size", 14)
	seed_lbl.add_theme_color_override("font_color", Palette.TEXT)
	seed_row.add_child(seed_lbl)
	_seed_input = LineEdit.new()
	_seed_input.text = ""
	_seed_input.placeholder_text = "Random board"
	_seed_input.tooltip_text = "Leave empty for a random board; type a number to reproduce one"
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_line_edit(_seed_input)
	seed_row.add_child(_seed_input)

	_balanced_check = CheckBox.new()
	_balanced_check.text = "Balanced Number Tokens (No Adjacent 6 & 8)"
	_balanced_check.button_pressed = true
	_balanced_check.tooltip_text = "Avoid placing 6 and 8 next to each other"
	_style_check(_balanced_check)
	vbox.add_child(_balanced_check)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_lobby_cancel_btn = Button.new()
	_lobby_cancel_btn.text = "Cancel"
	_lobby_cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lobby_cancel_btn.tooltip_text = "Close the lobby and continue the current match"
	_lobby_cancel_btn.visible = false
	_style_button(_lobby_cancel_btn, "ghost")
	_lobby_cancel_btn.pressed.connect(_close_overlays)
	btn_row.add_child(_lobby_cancel_btn)

	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.tooltip_text = "Start a new match with these settings"
	_style_button(start_btn, "primary")
	start_btn.pressed.connect(func() -> void:
		_start_match_from_lobby_settings()
		_close_overlays()
	)
	btn_row.add_child(start_btn)

func _update_lobby_seat_rows() -> void:
	var n := _num_players_opt.get_selected_id()
	for i in range(_seat_rows.size()):
		_seat_rows[i].visible = (i < n)

# ---------------------------------------------------------------------
# Menu, overlays, settings persistence
# ---------------------------------------------------------------------
func _open_menu_popup() -> void:
	_cancel_build_bubble()
	_menu_popup.reset_size()
	var gp := _menu_btn.get_screen_position()
	var pop_pos := Vector2i(int(gp.x), int(gp.y + _menu_btn.size.y + 2))
	_menu_popup.popup(Rect2i(pop_pos, Vector2i.ZERO))

func _on_menu_item(id: int) -> void:
	match id:
		0:
			_show_lobby()
		1:
			_show_overlay("settings")
		2:
			_show_overlay("help")
		4:
			get_tree().quit()

func _any_overlay_visible() -> bool:
	return _lobby_overlay.visible or _settings_overlay.visible or _help_overlay.visible

func _show_overlay(which: String) -> void:
	_cancel_build_bubble()
	_lobby_overlay.visible = which == "lobby"
	_settings_overlay.visible = which == "settings"
	_help_overlay.visible = which == "help"

func _close_overlays() -> void:
	_show_overlay("none")

func _show_lobby() -> void:
	for i in range(_seat_type_opts.size()):
		var sel_type: int = 0 if i == 0 else _settings_ai_difficulty
		_seat_type_opts[i].select(_seat_type_opts[i].get_item_index(sel_type))
	_update_lobby_seat_rows()
	_lobby_cancel_btn.visible = session != null and session.state != null
	_show_overlay("lobby")

func _step_bot_now() -> void:
	if session != null and session.state != null and session.is_ai_to_act():
		session.step_ai()

func _add_settings_row(parent: VBoxContainer, label_text: String, hint_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Palette.TEXT)
	col.add_child(lbl)
	if not hint_text.is_empty():
		var hint := Label.new()
		hint.text = hint_text
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		col.add_child(hint)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)

func _build_settings_overlay() -> void:
	_settings_overlay = ColorRect.new()
	_settings_overlay.color = Color(Palette.INK, 0.62)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	add_child(_settings_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)

	var modal := _make_card_panel(Palette.PANEL_BG)
	modal.custom_minimum_size = Vector2(500, 0)
	center.add_child(modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	modal.add_child(vbox)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Palette.HEADING)
	vbox.add_child(title)

	_settings_diff_opt = OptionButton.new()
	_settings_diff_opt.add_item("Easier", 1)
	_settings_diff_opt.add_item("Normal", 2)
	_settings_diff_opt.add_item("Harder", 3)
	_settings_diff_opt.custom_minimum_size = Vector2(150, 36)
	_settings_diff_opt.tooltip_text = "How strong the bots play"
	_style_option(_settings_diff_opt)
	_settings_diff_opt.item_selected.connect(func(idx: int) -> void:
		_settings_ai_difficulty = _settings_diff_opt.get_item_id(idx)
		if session != null:
			session.set_ai_difficulty(_settings_ai_difficulty)
		_save_settings()
	)
	_add_settings_row(vbox, "Bot difficulty:", "Also the default for bot seats in the lobby", _settings_diff_opt)

	_settings_mute_check = CheckBox.new()
	_settings_mute_check.text = "Mute sound"
	_settings_mute_check.tooltip_text = "Silence all game audio"
	_style_check(_settings_mute_check)
	_settings_mute_check.toggled.connect(func(on: bool) -> void:
		_settings_muted = on
		AudioServer.set_bus_mute(0, on)
		_save_settings()
	)
	_add_settings_row(vbox, "Sound:", "", _settings_mute_check)

	_settings_text_opt = OptionButton.new()
	_settings_text_opt.add_item("Normal", 0)
	_settings_text_opt.add_item("Large", 1)
	_settings_text_opt.add_item("Extra large", 2)
	_settings_text_opt.custom_minimum_size = Vector2(150, 36)
	_settings_text_opt.tooltip_text = "Scale all text and controls"
	_style_option(_settings_text_opt)
	_settings_text_opt.item_selected.connect(func(idx: int) -> void:
		_settings_text_idx = _settings_text_opt.get_item_id(idx)
		get_window().content_scale_factor = TEXT_SCALE_VALUES[_settings_text_idx]
		_save_settings()
	)
	_add_settings_row(vbox, "Text size:", "", _settings_text_opt)

	_settings_speed_opt = OptionButton.new()
	_settings_speed_opt.add_item("Slow", 0)
	_settings_speed_opt.add_item("Normal", 1)
	_settings_speed_opt.add_item("Fast", 2)
	_settings_speed_opt.custom_minimum_size = Vector2(150, 36)
	_settings_speed_opt.tooltip_text = "How quickly the bots take their turns"
	_style_option(_settings_speed_opt)
	_settings_speed_opt.item_selected.connect(func(idx: int) -> void:
		_settings_speed_idx = _settings_speed_opt.get_item_id(idx)
		if _ai_timer != null:
			_ai_timer.wait_time = BOT_SPEED_VALUES[_settings_speed_idx]
		_save_settings()
	)
	_add_settings_row(vbox, "Bot speed:", "", _settings_speed_opt)

	_settings_motion_check = CheckBox.new()
	_settings_motion_check.text = "Reduce motion"
	_settings_motion_check.tooltip_text = "Skip the dice roll animation and card pulses"
	_style_check(_settings_motion_check)
	_settings_motion_check.toggled.connect(func(on: bool) -> void:
		_reduce_motion = on
		if _dice_widget != null:
			_dice_widget.set_motion_enabled(not on)
		if _board_view != null:
			_board_view.reduce_motion = on
		_save_settings()
	)
	_add_settings_row(vbox, "Motion:", "Dice and cards animate instantly when reduced", _settings_motion_check)

	_settings_auto_check = CheckBox.new()
	_settings_auto_check.text = "Bots play automatically"
	_settings_auto_check.tooltip_text = "Turn off to advance the bots one step at a time"
	_style_check(_settings_auto_check)
	_settings_auto_check.toggled.connect(func(on: bool) -> void:
		auto_ai = on
		_settings_step_btn.visible = not on
		_step_top_btn.visible = not on
		_save_settings()
	)
	_add_settings_row(vbox, "Bots:", "Turn off to step the bots manually", _settings_auto_check)

	_settings_step_btn = Button.new()
	_settings_step_btn.text = "Step bot"
	_settings_step_btn.tooltip_text = "Make the current bot take one action"
	_settings_step_btn.custom_minimum_size = Vector2(0, 36)
	_settings_step_btn.add_theme_font_size_override("font_size", 13)
	_settings_step_btn.visible = false
	_style_button(_settings_step_btn, "ghost")
	_settings_step_btn.pressed.connect(_step_bot_now)
	vbox.add_child(_settings_step_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.tooltip_text = "Close the settings"
	close_btn.custom_minimum_size = Vector2(0, 40)
	_style_button(close_btn, "primary")
	close_btn.pressed.connect(func() -> void: _settings_overlay.visible = false)
	vbox.add_child(close_btn)

func _build_help_overlay() -> void:
	_help_overlay = ColorRect.new()
	_help_overlay.color = Color(Palette.INK, 0.62)
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.visible = false
	add_child(_help_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(center)

	var modal := _make_card_panel(Palette.PANEL_BG)
	modal.custom_minimum_size = Vector2(560, 380)
	center.add_child(modal)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	modal.add_child(vbox)

	var title := Label.new()
	title.text = "How to play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Palette.HEADING)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.selection_enabled = true
	rtl.fit_content = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_color_override("default_color", Palette.TEXT)
	rtl.add_theme_font_size_override("normal_font_size", 14)
	var bg_empty := StyleBoxFlat.new()
	bg_empty.bg_color = Color(Palette.PANEL_BG, 0.0)
	rtl.add_theme_stylebox_override("background", bg_empty)
	rtl.text = "\n".join([
		"[b][color=#1f5a52]Goal[/color][/b] — first player to 10 victory points wins.",
		"",
		"[b][color=#1f5a52]Your turn[/color][/b]",
		"1. Click the dice to roll.",
		"2. Trade, build and play Action Cards.",
		"3. Press End Turn.",
		"",
		"[b][color=#1f5a52]Building[/color][/b]",
		"Glowing spots on the board show what you can build now — click one and confirm.",
		"Road: 1 Timber + 1 Clay",
		"Settlement: 1 Timber + 1 Clay + 1 Fleece + 1 Grain",
		"City: 2 Grain + 3 Iron",
		"Action card: 1 Fleece + 1 Grain + 1 Iron",
		"",
		"[b][color=#1f5a52]Trading[/color][/b]",
		"Open the Trade tray (button, T, or click a resource card). Set what you give and what you get, then 'Ask players' posts your offer to everyone (max 3 offers per turn). Each player accepts, declines or counters; press Trade on a player's card to complete with them, or Withdraw your offer.",
		"The Bank / Port card trades with the bank: 4:1 by default, 3:1 with a 3:1 port, 2:1 for that port's own resource.",
		"When another player posts an offer, your tray shows it and you can Accept, Decline or Counter.",
		"",
		"[b][color=#1f5a52]The Blocker[/color][/b]",
		"When a 7 is rolled, every player holding more than 7 cards discards half of them. The roller then moves the Blocker to a new tile and steals a card from a player building there. A Guard card moves the Blocker without rolling.",
		"",
		"[b][color=#1f5a52]Keyboard[/color][/b]",
		"Space or R — roll the dice · E — end turn · T — trade · B — buy an Action Card · M — menu · Esc — cancel / close · F1 — this help",
	])
	scroll.add_child(rtl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.tooltip_text = "Close this help"
	close_btn.custom_minimum_size = Vector2(0, 40)
	_style_button(close_btn, "primary")
	close_btn.pressed.connect(func() -> void: _help_overlay.visible = false)
	vbox.add_child(close_btn)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if k.keycode != KEY_SPACE:
		return
	var fo := get_viewport().gui_get_focus_owner()
	if fo is LineEdit or _any_overlay_visible():
		return
	if _can_roll_now():
		_on_roll_pressed()
		get_viewport().set_input_as_handled()
		return
	if _no_space_focus_btns.has(fo):
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	var fo := get_viewport().gui_get_focus_owner()
	var typing := fo is LineEdit

	if k.keycode == KEY_ESCAPE:
		if typing:
			return
		if _help_overlay != null and _help_overlay.visible:
			_help_overlay.visible = false
		elif _settings_overlay != null and _settings_overlay.visible:
			_settings_overlay.visible = false
		elif _lobby_overlay != null and _lobby_overlay.visible:
			_close_overlays()
		elif _build_bubble != null and _build_bubble.visible:
			_cancel_build_bubble()
		elif _trade_tray != null and _trade_tray.visible:
			_close_trade_tray_by_user()
		elif _cancel_pick_btn != null and _cancel_pick_btn.visible:
			_cancel_current_pick()
		else:
			return
		get_viewport().set_input_as_handled()
		return

	if k.keycode == KEY_F1:
		_show_overlay("help")
		get_viewport().set_input_as_handled()
		return

	if typing or _any_overlay_visible():
		return
	if _hand_hidden():
		return

	match k.keycode:
		KEY_SPACE, KEY_R:
			if _can_roll_now():
				_on_roll_pressed()
				get_viewport().set_input_as_handled()
		KEY_E:
			if _end_turn_btn != null and not _end_turn_btn.disabled:
				_on_end_turn_pressed()
				get_viewport().set_input_as_handled()
		KEY_T:
			if _trade_tray != null and _trade_allowed_now():
				_toggle_trade_tray()
				get_viewport().set_input_as_handled()
		KEY_B:
			if _buy_card_btn != null and not _buy_card_btn.disabled:
				_on_buy_dev_pressed()
				get_viewport().set_input_as_handled()
		KEY_M:
			_open_menu_popup()
			get_viewport().set_input_as_handled()

func _can_roll_now() -> bool:
	if session == null or session.state == null:
		return false
	if _hand_hidden():
		return false
	return _is_human_acting() and session.state.phase == GameTypes.TurnPhase.TURN_ROLL


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	_settings_ai_difficulty = clampi(int(cfg.get_value("settings", "ai_difficulty", 2)), 1, 3)
	_settings_muted = bool(cfg.get_value("settings", "muted", false))
	_settings_text_idx = clampi(int(cfg.get_value("settings", "text_size", 0)), 0, 2)
	_settings_speed_idx = clampi(int(cfg.get_value("settings", "bot_speed", 1)), 0, 2)
	_reduce_motion = bool(cfg.get_value("settings", "reduce_motion", false))
	auto_ai = bool(cfg.get_value("settings", "auto_ai", true))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "ai_difficulty", _settings_ai_difficulty)
	cfg.set_value("settings", "muted", _settings_muted)
	cfg.set_value("settings", "text_size", _settings_text_idx)
	cfg.set_value("settings", "bot_speed", _settings_speed_idx)
	cfg.set_value("settings", "reduce_motion", _reduce_motion)
	cfg.set_value("settings", "auto_ai", auto_ai)
	cfg.save(settings_path)

func _apply_settings() -> void:
	AudioServer.set_bus_mute(0, _settings_muted)
	get_window().content_scale_factor = TEXT_SCALE_VALUES[_settings_text_idx]
	if _ai_timer != null:
		_ai_timer.wait_time = BOT_SPEED_VALUES[_settings_speed_idx]
	if _dice_widget != null:
		_dice_widget.set_motion_enabled(not _reduce_motion)
	if _board_view != null:
		_board_view.reduce_motion = _reduce_motion
	_settings_diff_opt.select(_settings_diff_opt.get_item_index(_settings_ai_difficulty))
	_settings_text_opt.select(_settings_text_idx)
	_settings_speed_opt.select(_settings_speed_idx)
	_settings_mute_check.button_pressed = _settings_muted
	_settings_motion_check.button_pressed = _reduce_motion
	_settings_auto_check.button_pressed = auto_ai
	_settings_step_btn.visible = not auto_ai
	_step_top_btn.visible = not auto_ai

func _start_match_from_lobby_settings() -> void:
	var n := _num_players_opt.get_selected_id()
	var configs: Array[SeatConfig] = []
	for i in range(n):
		var sc := SeatConfig.new()
		sc.seat_id = i
		sc.seat_type = _seat_type_opts[i].get_selected_id()
		sc.display_name = GameTypes.PLAYER_NAMES[i]
		configs.append(sc)
	var seed_val := 0
	var seed_txt := _seed_input.text.strip_edges()
	if seed_txt.is_valid_int():
		seed_val = int(seed_txt)
	if seed_val <= 0:
		seed_val = randi() % 2147483646 + 1
	_event_log.clear()
	_pending_guard_card = false
	_cancel_build_bubble()
	_subpanel_container.visible = false
	_subpanel_owner_pid = -1
	_trade_tray.visible = false
	_trade_respond_mode = false
	_trade_counter_mode = false
	_trade_reopen_token = ""
	_trade_last_ot_open = false
	_trade_opened_auto = false
	_trade_view_pid = -1
	_trade_ready_dismissed = false
	_set_trade_hint(false)
	_reset_trade_counts()
	_last_seen_dice = Vector2i.ZERO
	_prev_dash_hand = {}
	_prev_dash_pid = -1
	_revealed_pid = -1
	_prev_view_pid = -1
	_sfx_prev_current = -1
	_sfx_won = false
	session.start_match(seed_val, configs, _balanced_check.button_pressed)

func _on_state_updated(state: GameState, events: Array[String]) -> void:
	_board_view.set_state(state)
	var rolled_now := false
	var built_now := false
	var traded_now := false
	for ev in events:
		_append_log(ev)
		if ev.contains("traded "):
			traded_now = true
			_board_view.spawn_trade_toast(ev)
		if ev.contains("rolled "):
			rolled_now = true
		if ev.contains(" built a ") or ev.contains("upgraded "):
			built_now = true

	if rolled_now and state.last_dice.x > 0 and state.last_dice.y > 0:
		_roll_fx_count += 1
		_dice_widget.animate_roll(state.last_dice.x, state.last_dice.y)
		if state.last_dice.x + state.last_dice.y != 7:
			_spawn_production_popups(state)
	_last_seen_dice = state.last_dice

	if _sfx != null and session != null:
		var clip := ""
		if state.phase == GameTypes.TurnPhase.GAME_OVER:
			if not _sfx_won:
				_sfx_won = true
				clip = "win"
		elif rolled_now:
			clip = "seven" if state.last_dice.x + state.last_dice.y == 7 else "roll"
		elif built_now:
			clip = "build"
		elif traded_now:
			clip = "trade"
		if clip != "":
			_sfx.play(clip)
		var turn_changed := state.current_player != _sfx_prev_current
		_sfx_prev_current = state.current_player
		if turn_changed and state.current_player >= 0 and state.current_player < session.seats.size() and not session.seats[state.current_player].is_ai() and state.phase != GameTypes.TurnPhase.GAME_OVER:
			_sfx.play("turn")

	_refresh_ui()

func _spawn_production_popups(state: GameState) -> void:
	if _board_view == null:
		return
	var total: int = state.last_dice.x + state.last_dice.y
	var topo := HexMath.get_topology()
	for t_id in range(state.tile_terrains.size()):
		if t_id == state.blocker_tile:
			continue
		if t_id >= state.tile_numbers.size() or int(state.tile_numbers[t_id]) != total:
			continue
		var res := GameTypes.terrain_to_resource(int(state.tile_terrains[t_id]))
		if res < 0:
			continue
		var produced := 0
		if t_id < topo.tile_vertices.size():
			for v_id in topo.tile_vertices[t_id]:
				if v_id >= 0 and v_id < state.vertex_owner.size() and state.vertex_owner[v_id] >= 0:
					var b_type: int = state.vertex_building[v_id] if v_id < state.vertex_building.size() else GameTypes.BuildingType.NONE
					if b_type == GameTypes.BuildingType.SETTLEMENT:
						produced += 1
					elif b_type == GameTypes.BuildingType.CITY:
						produced += 2
		if produced > 0:
			_board_view.spawn_tile_resource_popup(t_id, res, produced)

func _on_action_rejected(player_id: int, error: String) -> void:
	_append_log("[color=#7a2a20][Seat %d Invalid Action] %s[/color]" % [player_id + 1, error])
	_refresh_ui()

func _append_log(msg: String) -> void:
	if _event_log == null:
		return
	_event_log.append_text("• " + msg + "\n")

func _get_setup_anchor_vertex(state: GameState) -> int:
	return state.setup_anchor_vertex

func _is_human_acting() -> bool:
	if session == null or session.state == null:
		return false
	if session.state.phase == GameTypes.TurnPhase.GAME_OVER:
		return false
	return not session.is_ai_to_act()

func _human_seat_count() -> int:
	if session == null:
		return 0
	var n := 0
	for sc in session.seats:
		if not sc.is_ai():
			n += 1
	return n

# The human seat the UI represents: whoever must act if human, else the
# human whose turn it is, else the first human seat (hot-seat "me").
func _view_pid() -> int:
	if session == null or session.state == null:
		return 0
	if _is_human_acting():
		return session.get_acting_player_id()
	var cur: int = session.state.current_player
	if cur >= 0 and cur < session.seats.size() and not session.seats[cur].is_ai():
		return cur
	return _find_first_human_seat()

func _set_banner(text: String) -> void:
	if _status_banner_label == null:
		return
	if _human_seat_count() >= 2:
		var v := _view_pid()
		if session != null and session.state != null and session.state.phase != GameTypes.TurnPhase.GAME_OVER and v >= 0 and v < session.state.players.size():
			_status_banner_label.text = "%s — %s" % [
				str(session.state.players[v].get("name", GameTypes.PLAYER_NAMES[v])), text
			]
			return
	_status_banner_label.text = text

func _submit_human_action(action: Dictionary) -> void:
	if session == null or session.state == null:
		return
	if _hand_hidden():
		return
	var acting_id := session.get_acting_player_id()
	_pending_guard_card = false
	_cancel_pick_btn.visible = false
	_board_view.clear_highlights()
	session.submit_action(acting_id, action)

# A mouse click on an action button must not leave keyboard focus on it,
# otherwise the next Space would activate the button instead of rolling.
func _guard_action_button_focus(btn: Button) -> void:
	_no_space_focus_btns.append(btn)
	btn.button_up.connect(func() -> void:
		btn.release_focus()
	)

func _build_device_pass_cover() -> void:
	_device_pass_cover = PanelContainer.new()
	_device_pass_cover.visible = false
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.PANEL_BG
	st.set_border_width_all(2)
	st.border_color = Palette.PANEL_BORDER
	st.set_corner_radius_all(10)
	st.content_margin_left = 12.0
	st.content_margin_right = 12.0
	st.content_margin_top = 8.0
	st.content_margin_bottom = 8.0
	_device_pass_cover.add_theme_stylebox_override("panel", st)
	_hand_bar_panel.add_child(_device_pass_cover)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_device_pass_cover.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	center.add_child(row)

	_device_pass_label = Label.new()
	_device_pass_label.add_theme_font_size_override("font_size", 16)
	_device_pass_label.add_theme_color_override("font_color", Palette.HEADING)
	_device_pass_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_device_pass_label)

	_device_pass_btn = Button.new()
	_device_pass_btn.add_theme_font_size_override("font_size", 14)
	_style_button(_device_pass_btn, "primary")
	_device_pass_btn.pressed.connect(_on_device_pass_reveal)
	row.add_child(_device_pass_btn)

func _on_device_pass_reveal() -> void:
	if session == null or session.state == null:
		return
	if not _is_human_acting():
		return
	_revealed_pid = session.get_acting_player_id()
	_refresh_ui()

# With 2+ humans at one device, the hand stays hidden until the acting
# human confirms the device is in their hands.
func _hand_hidden() -> bool:
	if session == null or session.state == null:
		return false
	if _human_seat_count() < 2:
		return false
	if session.state.phase == GameTypes.TurnPhase.GAME_OVER:
		return true
	var cur: int = session.state.current_player
	var bot_turn: bool = cur >= 0 and cur < session.seats.size() and session.seats[cur].is_ai()
	if bot_turn and not _is_human_acting():
		return true
	return _revealed_pid != _view_pid()

func _update_device_pass_cover(hand_hidden: bool, view_pid: int) -> void:
	if _device_pass_cover == null:
		return
	var game_over := session != null and session.state != null and session.state.phase == GameTypes.TurnPhase.GAME_OVER
	if not hand_hidden or game_over:
		_device_pass_cover.visible = false
		return
	var human_acting := _is_human_acting()
	var was_visible := _device_pass_cover.visible
	var was_btn_visible := _device_pass_btn.visible
	if human_acting:
		var pname := str(session.state.players[view_pid].get("name", GameTypes.PLAYER_NAMES[view_pid]))
		_device_pass_label.text = "Pass the device to %s" % pname
		_device_pass_btn.text = "I'm %s — show my hand" % pname
		_device_pass_btn.visible = true
	else:
		var cur: int = session.state.current_player
		var cname: String = GameTypes.PLAYER_NAMES[cur]
		if cur >= 0 and cur < session.state.players.size():
			cname = str(session.state.players[cur].get("name", cname))
		_device_pass_label.text = "%s is playing — hands hidden" % cname
		_device_pass_btn.visible = false
	_device_pass_cover.visible = true
	if human_acting and (not was_visible or not was_btn_visible):
		_device_pass_btn.grab_focus()

func _compute_instruction(state: GameState, acting_id: int, human_acting: bool) -> String:
	if state.phase == GameTypes.TurnPhase.GAME_OVER:
		if state.winner != -1:
			return "%s wins!" % GameTypes.PLAYER_NAMES[state.winner]
		return "Game over."
	if not state.open_trade.is_empty():
		var ot_from0: int = int(state.open_trade.get("from", -1))
		if not human_acting and ot_from0 == _view_pid():
			return "Waiting for answers to your offer…"
	if not human_acting:
		return "%s is thinking…" % GameTypes.PLAYER_NAMES[acting_id]
	if not state.open_trade.is_empty():
		var ot_from: int = int(state.open_trade.get("from", -1))
		if ot_from != acting_id:
			return "%s wants to trade — accept, decline or counter." % GameTypes.PLAYER_NAMES[ot_from]
		if _trade_tray != null and not _trade_tray.visible:
			return "open Trade to pick a player or withdraw."
		return "Pick a player to trade with, or withdraw your offer."
	if state.phase == GameTypes.TurnPhase.TURN_DISCARD:
		var dcnt: int = int(state.pending_discards.get(acting_id, 0))
		return "A 7 was rolled — discard %d cards." % dcnt
	match state.phase:
		GameTypes.TurnPhase.SETUP_SETTLEMENT_1, GameTypes.TurnPhase.SETUP_SETTLEMENT_2:
			return "Place a settlement on a glowing spot."
		GameTypes.TurnPhase.SETUP_ROAD_1, GameTypes.TurnPhase.SETUP_ROAD_2:
			return "Place a road next to your settlement."
		GameTypes.TurnPhase.TURN_ROLL:
			return "Your turn — click the dice to roll."
		GameTypes.TurnPhase.TURN_MOVE_BLOCKER:
			return "Move the blocker: click a tile."
		GameTypes.TurnPhase.TURN_ROAD_WORK:
			return "Road Work: click a glowing edge for a free road."
		_:
			return "Build, trade, or end your turn."

func _blocked_reason(state: GameState, human_acting: bool) -> String:
	if state.phase == GameTypes.TurnPhase.GAME_OVER:
		return "The game is over"
	if not human_acting:
		return "Not your turn"
	match state.phase:
		GameTypes.TurnPhase.TURN_ROLL:
			return "Roll the dice first"
		GameTypes.TurnPhase.SETUP_SETTLEMENT_1, GameTypes.TurnPhase.SETUP_ROAD_1, GameTypes.TurnPhase.SETUP_SETTLEMENT_2, GameTypes.TurnPhase.SETUP_ROAD_2:
			return "Finish setup first"
		_:
			if not state.open_trade.is_empty():
				return "Resolve the open trade first"
			return "Finish the current step first"

func _missing_resources(hand: Dictionary, cost: Dictionary) -> String:
	var parts: Array[String] = []
	for r in GameTypes.ALL_RESOURCES:
		var need_amt: int = int(cost.get(r, 0))
		if need_amt <= 0:
			continue
		var have: int = int(hand.get(r, 0))
		if have < need_amt:
			parts.append("%d more %s" % [need_amt - have, GameTypes.resource_name(r)])
	if parts.is_empty():
		return ""
	return "Need " + ", ".join(parts)

func _refresh_ui() -> void:
	if session == null or session.state == null:
		return
	var state := session.state
	var acting_id := session.get_acting_player_id()
	var human_acting := _is_human_acting()

	# Top bar: muted turn counter + one-line instruction banner
	_phase_label.text = "Turn %d" % state.turn_number
	if _board_view.interaction_mode == BoardView.InteractionMode.NONE and not _pending_guard_card:
		_set_banner(_compute_instruction(state, acting_id, human_acting))

	_step_top_btn.visible = not auto_ai
	_step_top_btn.disabled = not session.is_ai_to_act()
	if _settings_step_btn != null:
		_settings_step_btn.disabled = not session.is_ai_to_act()

	# Rebuild compact Scoreboard pill cards
	var view_pid := _view_pid()
	var human_seat_n := _human_seat_count()
	if view_pid != _prev_view_pid:
		_prev_view_pid = view_pid
		_revealed_pid = -1
	var cur_pid: int = state.current_player
	if not human_acting and cur_pid >= 0 and cur_pid < session.seats.size() and session.seats[cur_pid].is_ai():
		_revealed_pid = -1
	var hand_hidden := _hand_hidden()
	_update_device_pass_cover(hand_hidden, view_pid)
	for child in _scoreboard_box.get_children():
		child.queue_free()
	for p_id in range(state.num_players):
		var p_data: Dictionary = state.players[p_id]
		var seat_cfg: SeatConfig = session.seats[p_id] if p_id < session.seats.size() else null
		var is_active := (p_id == acting_id and state.phase != GameTypes.TurnPhase.GAME_OVER)
		var card_bg: Color = Palette.PANEL_BG_ALT if is_active else Palette.PANEL_BG
		var card := _make_compact_card(card_bg)
		_scoreboard_box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)

		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(9, 22)
		swatch.color = GameTypes.PLAYER_COLORS[p_id]
		row.add_child(swatch)

		var name_lbl := Label.new()
		name_lbl.text = str(p_data.get("name", GameTypes.PLAYER_NAMES[p_id]))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT)
		row.add_child(name_lbl)

		var seat_tag := _seat_type_label(seat_cfg)
		row.add_child(_make_pill(seat_tag, Color(Palette.PANEL_BORDER, 0.28), Palette.TEXT_MUTED))

		var vp_public := state.get_victory_points(p_id, false)
		var vp_text := "%d VP" % vp_public
		if p_id == view_pid and (human_seat_n == 1 or p_id == acting_id):
			var hidden_gain: int = state.get_victory_points(p_id, true) - vp_public
			if hidden_gain > 0:
				vp_text = "%d VP (+%d hidden)" % [vp_public, hidden_gain]
		row.add_child(_make_pill(vp_text, Color(Palette.ACCENT_GOLD, 0.45), Palette.TEXT))

		var hand_cnt := GameTypes.hand_total(p_data.get("hand", {}))
		var dev_cnt: int = p_data.get("dev_cards", []).size() + p_data.get("new_dev_cards", []).size()
		row.add_child(_make_pill("%d/%d cards" % [hand_cnt, dev_cnt], Color(Palette.SEA, 0.35), Palette.TEXT))

		if state.longest_route_holder == p_id:
			row.add_child(_make_pill("Route +2", Color(Palette.ACCENT_GREEN, 0.40), Palette.TEXT))
		if state.largest_guard_holder == p_id:
			row.add_child(_make_pill("Guard +2", Color(Palette.MOUNTAIN_SHADE, 0.40), Palette.TEXT))

		if int(p_data.get("played_guards", 0)) > 0 or int(p_data.get("longest_route_length", 0)) > 0:
			var mini := Label.new()
			mini.text = "G%d/R%d" % [int(p_data.get("played_guards", 0)), int(p_data.get("longest_route_length", 0))]
			mini.add_theme_font_size_override("font_size", 13)
			mini.add_theme_color_override("font_color", Palette.TEXT_MUTED)
			row.add_child(mini)

	var dash_pid := view_pid
	var dash_player: Dictionary = state.players[dash_pid]
	var hand: Dictionary = dash_player.get("hand", {})

	# Visual bottom hand bar refresh
	var pid_changed := (dash_pid != _prev_dash_pid)
	for r in GameTypes.ALL_RESOURCES:
		var refs: Dictionary = _res_card_refs.get(r, {})
		if refs.is_empty():
			continue
		var count_lbl: Label = refs["count"]
		var card: Control = refs["card"]
		if hand_hidden:
			count_lbl.text = "—"
			card.modulate.a = 0.5
			continue
		var cnt := int(hand.get(r, 0))
		count_lbl.text = "x%d" % cnt
		card.modulate.a = 1.0 if cnt > 0 else 0.45
		if not pid_changed and cnt > int(_prev_dash_hand.get(r, 0)):
			_pulse_card(card)
	_prev_dash_hand = {} if hand_hidden else hand.duplicate()
	_prev_dash_pid = dash_pid

	var show_view := human_seat_n >= 2
	if _hand_view_swatch != null:
		_hand_view_swatch.visible = show_view and not hand_hidden
		_hand_view_swatch.color = GameTypes.PLAYER_COLORS[dash_pid]
	if _hand_view_name != null:
		_hand_view_name.visible = show_view
		if hand_hidden:
			_hand_view_name.text = "Hand hidden"
		else:
			_hand_view_name.text = str(dash_player.get("name", GameTypes.PLAYER_NAMES[dash_pid]))

	# Action card chips refresh
	var all_cards: Array = []
	all_cards.append_array(dash_player.get("dev_cards", []))
	all_cards.append_array(dash_player.get("new_dev_cards", []))
	var card_counts := {
		GameTypes.DevCardType.GUARD: 0,
		GameTypes.DevCardType.ROAD_WORK: 0,
		GameTypes.DevCardType.HARVEST_BOUNTY: 0,
		GameTypes.DevCardType.TRADE_DECREE: 0,
		GameTypes.DevCardType.CHARTER_POINT: 0,
	}
	for c in all_cards:
		card_counts[int(c)] = int(card_counts.get(int(c), 0)) + 1

	var chip_names := {
		GameTypes.DevCardType.GUARD: "Guard",
		GameTypes.DevCardType.ROAD_WORK: "Road Work",
		GameTypes.DevCardType.HARVEST_BOUNTY: "Bounty",
		GameTypes.DevCardType.TRADE_DECREE: "Decree",
		GameTypes.DevCardType.CHARTER_POINT: "Charter",
	}
	for ctype in chip_names.keys():
		var chip: Button = _action_chips.get(ctype, null)
		if chip == null:
			continue
		var ccnt: int = int(card_counts.get(ctype, 0))
		var chip_label := "%s x%d" % [chip_names[ctype], ccnt]
		if ctype == GameTypes.DevCardType.CHARTER_POINT:
			chip.text = chip_label
			chip.disabled = true
			chip.tooltip_text = "Charter Point: a hidden victory point — never playable"
			continue
		if ccnt <= 0:
			chip.text = chip_label
			chip.disabled = true
			chip.tooltip_text = "You have no %s card" % str(chip_names[ctype])
			continue
		var new_cnt := 0
		for c in dash_player.get("new_dev_cards", []):
			if int(c) == int(ctype):
				new_cnt += 1
		var chk: Dictionary = RulesEngine.can_play_dev_card(state, dash_pid, int(ctype))
		var chk_ok := bool(chk.get("ok", false))
		if new_cnt > 0:
			chip_label += " (new)"
		chip.text = chip_label
		chip.disabled = not chk_ok
		chip.tooltip_text = "Play %s" % str(chip_names[ctype]) if chk_ok else str(chk.get("reason", ""))
	if hand_hidden:
		for ctype in _action_chips.keys():
			var hidden_chip: Button = _action_chips[ctype]
			hidden_chip.disabled = true
			hidden_chip.text = "Hidden"
			hidden_chip.tooltip_text = ""

	_refresh_subpanels(state, acting_id, human_acting)

	# Discard check
	var needs_discard := (
		state.phase == GameTypes.TurnPhase.TURN_DISCARD
		and state.pending_discards.has(acting_id)
		and human_acting
	)
	_discard_panel.visible = needs_discard
	if needs_discard:
		var req_cnt: int = int(state.pending_discards[acting_id])
		_discard_info_label.text = "Rolled 7! %s must discard %d cards." % [GameTypes.PLAYER_NAMES[acting_id], req_cnt]

	# Auto board highlights for mandatory placement phases
	_update_mandatory_board_highlights(state, acting_id, human_acting)

	# Bottom bar controls
	var in_main := (
		human_acting
		and state.phase == GameTypes.TurnPhase.TURN_MAIN
		and state.open_trade.is_empty()
	)
	var in_roll := (human_acting and state.phase == GameTypes.TurnPhase.TURN_ROLL)

	_dice_widget.set_roll_enabled(in_roll)

	var in_road_work := human_acting and state.phase == GameTypes.TurnPhase.TURN_ROAD_WORK
	_end_turn_btn.disabled = not (in_main or in_road_work)
	if in_road_work:
		_end_turn_btn.text = "Skip roads"
		_end_turn_btn.tooltip_text = "Stop placing free roads and end your turn"
	else:
		_end_turn_btn.text = "End Turn"
		if not in_main:
			_end_turn_btn.tooltip_text = _blocked_reason(state, human_acting)
		else:
			_end_turn_btn.tooltip_text = "End your turn (E)"

	var end_done := false
	if in_main:
		end_done = (
			not RulesEngine.can_afford(state, acting_id, "road")
			and not RulesEngine.can_afford(state, acting_id, "settlement")
			and not RulesEngine.can_afford(state, acting_id, "city")
			and not RulesEngine.can_afford(state, acting_id, "dev_card")
		)
	if end_done:
		_style_button(_end_turn_btn, "primary")
		for st_name in ["normal", "hover", "pressed"]:
			var gbox: StyleBoxFlat = (_end_turn_btn.get_theme_stylebox(st_name) as StyleBoxFlat).duplicate() as StyleBoxFlat
			match st_name:
				"normal":
					gbox.bg_color = Palette.ACCENT_GREEN
				"hover":
					gbox.bg_color = Palette.ACCENT_GREEN.lightened(0.07)
				_:
					gbox.bg_color = Palette.ACCENT_GREEN.darkened(0.07)
			_end_turn_btn.add_theme_stylebox_override(st_name, gbox)
		_end_turn_btn.add_theme_color_override("font_color", Palette.TEXT_ON_DARK)
		_end_turn_btn.add_theme_color_override("font_hover_color", Palette.TEXT_ON_DARK)
		_end_turn_btn.add_theme_color_override("font_pressed_color", Palette.TEXT_ON_DARK)
	else:
		_style_button(_end_turn_btn, "normal")

	_trade_btn.disabled = not _trade_allowed_now()
	if not _trade_btn.disabled:
		_trade_btn.tooltip_text = "Open the trade panel (T)"
	else:
		_trade_btn.tooltip_text = _blocked_reason(state, human_acting)
	_refresh_trade_tray(state, acting_id, human_acting)
	if not state.open_trade.is_empty() and human_acting:
		if _board_view.interaction_mode == BoardView.InteractionMode.NONE and not _pending_guard_card:
			_set_banner(_compute_instruction(state, acting_id, human_acting))

	var can_buy := in_main and RulesEngine.can_afford(state, acting_id, "dev_card") and not state.dev_deck.is_empty()
	_buy_card_btn.disabled = not can_buy
	if can_buy:
		_buy_card_btn.tooltip_text = "Buy an Action Card: 1 Fleece + 1 Grain + 1 Iron"
	elif in_main:
		var buy_missing := _missing_resources(hand, {
			GameTypes.ResourceType.FLEECE: 1,
			GameTypes.ResourceType.GRAIN: 1,
			GameTypes.ResourceType.IRON: 1,
		})
		if not buy_missing.is_empty():
			_buy_card_btn.tooltip_text = buy_missing
		elif state.dev_deck.is_empty():
			_buy_card_btn.tooltip_text = "No Action Cards left in the deck"
		else:
			_buy_card_btn.tooltip_text = "Buy an Action Card: 1 Fleece + 1 Grain + 1 Iron"
	else:
		_buy_card_btn.tooltip_text = _blocked_reason(state, human_acting)

	_refresh_build_rows(state, acting_id, human_acting, in_main, hand)

func _refresh_build_rows(state: GameState, acting_id: int, human_acting: bool, in_main: bool, hand: Dictionary) -> void:
	for key in _build_rows.keys():
		var refs: Dictionary = _build_rows[key]
		var btn: Button = refs["btn"]
		var marker: Label = refs["marker"]
		var cost: Dictionary = refs["cost"]
		var display_name: String = str(refs["name"])
		var enabled := false
		var reason := ""
		if not human_acting:
			reason = "Not your turn"
		elif not in_main:
			reason = _blocked_reason(state, human_acting)
		else:
			if not RulesEngine.can_afford(state, acting_id, key):
				reason = _missing_resources(hand, cost)
			else:
				var p: Dictionary = state.players[acting_id]
				var no_spot := false
				match key:
					"road":
						if int(p.get("roads_left", 0)) <= 0:
							reason = "No roads left"
						else:
							no_spot = RulesEngine.get_valid_road_edges(state, acting_id, -1).is_empty()
					"settlement":
						if int(p.get("settlements_left", 0)) <= 0:
							reason = "No settlements left"
						else:
							no_spot = RulesEngine.get_valid_settlement_vertices(state, acting_id, false).is_empty()
					"city":
						if int(p.get("cities_left", 0)) <= 0:
							reason = "No cities left"
						else:
							no_spot = RulesEngine.get_valid_city_vertices(state, acting_id).is_empty()
				if no_spot and reason.is_empty():
					reason = "No free spot"
				elif reason.is_empty():
					enabled = true
		btn.disabled = not enabled
		if enabled:
			marker.text = "✓"
			btn.tooltip_text = "Build a %s: click, then click a highlighted spot on the board" % display_name
		else:
			marker.text = ""
			btn.tooltip_text = reason
		var row_lbls: Array = refs["labels"]
		for lb in row_lbls:
			var row_lbl: Label = lb
			if enabled:
				row_lbl.add_theme_color_override("font_color", Palette.TEXT)
			else:
				row_lbl.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		_apply_build_row_style(btn, enabled)

func _update_mandatory_board_highlights(state: GameState, acting_id: int, human_acting: bool) -> void:
	if not human_acting:
		_cancel_build_bubble()
		_board_view.clear_highlights()
		_hint_sig = ""
		var waiting_for_my_offer := (
			not state.open_trade.is_empty()
			and int(state.open_trade.get("from", -1)) == _view_pid()
		)
		if state.phase != GameTypes.TurnPhase.GAME_OVER and not waiting_for_my_offer:
			_set_banner("%s is thinking…" % GameTypes.PLAYER_NAMES[acting_id])
		return

	match state.phase:
		GameTypes.TurnPhase.SETUP_SETTLEMENT_1, GameTypes.TurnPhase.SETUP_SETTLEMENT_2:
			var verts := RulesEngine.get_valid_settlement_vertices(state, acting_id, true)
			_board_view.set_highlights(BoardView.InteractionMode.PICK_SETTLEMENT, verts, [], [])
			_set_banner("Place a settlement on a glowing spot.")
		GameTypes.TurnPhase.SETUP_ROAD_1, GameTypes.TurnPhase.SETUP_ROAD_2:
			var anchor := _get_setup_anchor_vertex(state)
			var edges := RulesEngine.get_valid_road_edges(state, acting_id, anchor)
			_board_view.set_highlights(BoardView.InteractionMode.PICK_ROAD, [], edges, [])
			_set_banner("Place a road next to your settlement.")
		GameTypes.TurnPhase.TURN_MOVE_BLOCKER:
			var tiles: Array[int] = []
			for t_id in range(state.tile_terrains.size()):
				if t_id != state.blocker_tile:
					tiles.append(t_id)
			_board_view.set_highlights(BoardView.InteractionMode.PICK_BLOCKER_TILE, [], [], tiles)
			_set_banner("Move the blocker: click a tile.")
		GameTypes.TurnPhase.TURN_ROAD_WORK:
			var edges := RulesEngine.get_valid_road_edges(state, acting_id, -1)
			_board_view.set_highlights(BoardView.InteractionMode.PICK_ROAD, [], edges, [])
			_set_banner("Road Work: place %d free road(s), or skip." % state.road_work_remaining)
		GameTypes.TurnPhase.TURN_ROLL:
			if not _pending_guard_card:
				_board_view.clear_highlights()
				_set_banner("Your turn — click the dice to roll.")
		GameTypes.TurnPhase.TURN_MAIN:
			_refresh_board_build_hints(state, acting_id, human_acting)

# Build-on-board hints + confirm bubble
func _compute_build_hint_lists(state: GameState, pid: int) -> Dictionary:
	var p: Dictionary = state.players[pid]
	var settlements: Array[int] = []
	var roads: Array[int] = []
	var cities: Array[int] = []
	if RulesEngine.can_afford(state, pid, "settlement") and int(p.get("settlements_left", 0)) > 0:
		settlements = RulesEngine.get_valid_settlement_vertices(state, pid, false)
	if RulesEngine.can_afford(state, pid, "road") and int(p.get("roads_left", 0)) > 0:
		roads = RulesEngine.get_valid_road_edges(state, pid, -1)
	if RulesEngine.can_afford(state, pid, "city") and int(p.get("cities_left", 0)) > 0:
		cities = RulesEngine.get_valid_city_vertices(state, pid)
	return {"settlements": settlements, "roads": roads, "cities": cities}

func _refresh_board_build_hints(state: GameState, acting_id: int, human_acting: bool) -> void:
	if _board_view.interaction_mode != BoardView.InteractionMode.NONE:
		if _cancel_pick_btn != null and _cancel_pick_btn.visible:
			# A Build-card PICK_* mode or guard pick owns the board.
			_cancel_build_bubble()
			return
		# Stale pick mode after its action completed: take the board back.
		_board_view.clear_highlights()
		_hint_sig = ""
	if not state.open_trade.is_empty() or _pending_guard_card or _any_overlay_visible():
		_cancel_build_bubble()
		if _board_view.interaction_mode == BoardView.InteractionMode.BUILD_ANY:
			_board_view.clear_highlights()
			_hint_sig = ""
		if state.open_trade.is_empty():
			_set_banner("Build, trade, or end your turn.")
		return
	var lists := _compute_build_hint_lists(state, acting_id)
	var settlements: Array[int] = lists["settlements"]
	var roads: Array[int] = lists["roads"]
	var cities: Array[int] = lists["cities"]
	if _build_bubble != null and _build_bubble.visible:
		if not _bubble_spot_still_valid(settlements, roads, cities):
			_cancel_build_bubble()
			return
		var sig := _hint_signature(settlements, roads, cities)
		if sig != _hint_sig:
			_hint_sig = sig
			_board_view.set_build_hints(settlements, roads, cities)
		_set_banner("Confirm to build, or cancel.")
		return
	_hint_sig = _hint_signature(settlements, roads, cities)
	if settlements.is_empty() and roads.is_empty() and cities.is_empty():
		_board_view.clear_highlights()
		_set_banner("Build, trade, or end your turn.")
	else:
		_board_view.set_build_hints(settlements, roads, cities)
		_set_banner("Click a glowing spot to build — or trade, or end your turn.")

func _hint_signature(settlements: Array[int], roads: Array[int], cities: Array[int]) -> String:
	var sv: Array[String] = []
	for v in settlements:
		sv.append(str(v))
	var ev: Array[String] = []
	for e in roads:
		ev.append(str(e))
	var cv: Array[String] = []
	for c in cities:
		cv.append(str(c))
	return "S%s|R%s|C%s" % [",".join(sv), ",".join(ev), ",".join(cv)]

func _bubble_spot_still_valid(settlements: Array[int], roads: Array[int], cities: Array[int]) -> bool:
	if _build_pending.is_empty():
		return true
	var kind := str(_build_pending.get("kind", ""))
	var id: int = int(_build_pending.get("id", -1))
	if kind == "road":
		return roads.has(id)
	if kind == "settlement":
		return settlements.has(id)
	if kind == "city":
		return cities.has(id)
	return false

func _build_build_bubble() -> void:
	_build_bubble = PanelContainer.new()
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(9)
	st.set_border_width_all(2)
	st.border_color = Palette.ACCENT_GOLD.darkened(0.15)
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 5
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 5
	st.content_margin_bottom = 5
	_build_bubble.add_theme_stylebox_override("panel", st)
	_build_bubble.visible = false
	add_child(_build_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_build_bubble.add_child(row)
	_build_bubble_title = Label.new()
	_build_bubble_title.add_theme_font_size_override("font_size", 13)
	_build_bubble_title.add_theme_color_override("font_color", Palette.HEADING)
	row.add_child(_build_bubble_title)
	_build_bubble_cost_box = HBoxContainer.new()
	_build_bubble_cost_box.add_theme_constant_override("separation", 6)
	row.add_child(_build_bubble_cost_box)
	_build_bubble_build_btn = Button.new()
	_build_bubble_build_btn.text = "✓ Build"
	_build_bubble_build_btn.custom_minimum_size = Vector2(44, 36)
	_build_bubble_build_btn.add_theme_font_size_override("font_size", 13)
	_style_button(_build_bubble_build_btn, "primary")
	_build_bubble_build_btn.pressed.connect(_on_bubble_build_pressed)
	_guard_action_button_focus(_build_bubble_build_btn)
	row.add_child(_build_bubble_build_btn)
	_build_bubble_cancel_btn = Button.new()
	_build_bubble_cancel_btn.text = "✕"
	_build_bubble_cancel_btn.custom_minimum_size = Vector2(32, 36)
	_build_bubble_cancel_btn.add_theme_font_size_override("font_size", 13)
	_build_bubble_cancel_btn.tooltip_text = "Cancel (Esc)"
	_style_button(_build_bubble_cancel_btn, "ghost")
	_build_bubble_cancel_btn.pressed.connect(_on_bubble_cancel_pressed)
	row.add_child(_build_bubble_cancel_btn)

func _on_build_spot_clicked(kind: String, id: int) -> void:
	if not _is_human_acting() or session.state.phase != GameTypes.TurnPhase.TURN_MAIN:
		return
	if not session.state.open_trade.is_empty() or _board_view.interaction_mode != BoardView.InteractionMode.BUILD_ANY:
		return
	_build_pending = {"kind": kind, "id": id}
	_board_view.set_pending_build(kind, id)
	_fill_build_bubble(kind)
	_position_build_bubble(kind, id)
	_build_bubble.visible = true
	_build_bubble_build_btn.grab_focus()
	_set_banner("Confirm to build, or cancel.")

func _fill_build_bubble(kind: String) -> void:
	for c in _build_bubble_cost_box.get_children():
		c.queue_free()
	var title := "Build road?"
	match kind:
		"settlement":
			title = "Build settlement?"
		"city":
			title = "Upgrade to city?"
	_build_bubble_title.text = title
	var refs: Dictionary = _build_rows.get(kind, {})
	var cost: Dictionary = refs.get("cost", {})
	for r in GameTypes.ALL_RESOURCES:
		var amt: int = int(cost.get(r, 0))
		if amt <= 0:
			continue
		_build_bubble_cost_box.add_child(_make_cost_cell(r, amt))

func _position_build_bubble(kind: String, id: int) -> void:
	_build_bubble.reset_size()
	var bsize := _build_bubble.get_combined_minimum_size()
	var spot := _board_view.global_position + _board_view.get_spot_screen_position(kind, id)
	var pos := spot + Vector2(18, -18) - Vector2(0, bsize.y)
	var br := _board_view.get_global_rect()
	pos.x = clampf(pos.x, br.position.x + 2, br.end.x - bsize.x - 2)
	pos.y = clampf(pos.y, br.position.y + 2, br.end.y - bsize.y - 2)
	_build_bubble.position = pos

func _on_bubble_cancel_pressed() -> void:
	_cancel_build_bubble()

func _cancel_build_bubble() -> void:
	if _build_bubble == null:
		return
	if _build_bubble.visible:
		_build_bubble.visible = false
		_board_view.clear_pending_build()
	_build_pending = {}

func _on_bubble_build_pressed() -> void:
	if _build_pending.is_empty() or not _is_human_acting():
		return
	var kind := str(_build_pending.get("kind", ""))
	var id: int = int(_build_pending.get("id", -1))
	var action: Dictionary = {}
	match kind:
		"road":
			action = GameAction.place_road(id)
		"settlement":
			action = GameAction.place_settlement(id)
		"city":
			action = GameAction.upgrade_city(id)
	if action.is_empty():
		_cancel_build_bubble()
		return
	_build_bubble.visible = false
	_board_view.clear_pending_build()
	_build_pending = {}
	_submit_human_action(action)

# Board click handlers
func _on_board_vertex_clicked(vertex_id: int) -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	var mode := _board_view.interaction_mode
	if mode == BoardView.InteractionMode.PICK_SETTLEMENT:
		_submit_human_action(GameAction.place_settlement(vertex_id))
	elif mode == BoardView.InteractionMode.PICK_CITY:
		_submit_human_action(GameAction.upgrade_city(vertex_id))

func _on_board_edge_clicked(edge_id: int) -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	if _board_view.interaction_mode == BoardView.InteractionMode.PICK_ROAD:
		_submit_human_action(GameAction.place_road(edge_id))

func _on_board_tile_clicked(tile_id: int) -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	if _board_view.interaction_mode == BoardView.InteractionMode.PICK_BLOCKER_TILE:
		var acting_id := session.get_acting_player_id()
		var target_opp := _choose_steal_target_on_tile(session.state, acting_id, tile_id)
		if _pending_guard_card:
			_submit_human_action(GameAction.play_guard(tile_id, target_opp))
		else:
			_submit_human_action(GameAction.move_blocker(tile_id, target_opp))

func _choose_steal_target_on_tile(state: GameState, acting_id: int, tile_id: int) -> int:
	var topo := HexMath.get_topology()
	var best_opp := -1
	var best_vp := -1
	for v_id in topo.tile_vertices[tile_id]:
		var owner_id: int = state.vertex_owner[v_id]
		if owner_id != -1 and owner_id != acting_id:
			var opp_hand: Dictionary = state.players[owner_id].get("hand", {})
			if GameTypes.hand_total(opp_hand) > 0:
				var vp := state.get_victory_points(owner_id, false)
				if vp > best_vp:
					best_vp = vp
					best_opp = owner_id
	return best_opp

# Toolbar button handlers
func _on_roll_pressed() -> void:
	_submit_human_action(GameAction.roll_dice())

func _on_end_turn_pressed() -> void:
	_submit_human_action(GameAction.end_turn())

func _on_build_road_pressed() -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	var acting_id := session.get_acting_player_id()
	var edges := RulesEngine.get_valid_road_edges(session.state, acting_id, -1)
	_board_view.set_highlights(BoardView.InteractionMode.PICK_ROAD, [], edges, [])
	_cancel_pick_btn.visible = true
	_set_banner("Select a highlighted edge on the board to build a Road.")

func _on_build_settlement_pressed() -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	var acting_id := session.get_acting_player_id()
	var verts := RulesEngine.get_valid_settlement_vertices(session.state, acting_id, false)
	_board_view.set_highlights(BoardView.InteractionMode.PICK_SETTLEMENT, verts, [], [])
	_cancel_pick_btn.visible = true
	_set_banner("Select a highlighted vertex on the board to build a Settlement.")

func _on_upgrade_city_pressed() -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	var acting_id := session.get_acting_player_id()
	var verts := RulesEngine.get_valid_city_vertices(session.state, acting_id)
	_board_view.set_highlights(BoardView.InteractionMode.PICK_CITY, verts, [], [])
	_cancel_pick_btn.visible = true
	_set_banner("Select one of your highlighted Settlements to upgrade to a City.")

func _on_buy_dev_pressed() -> void:
	_submit_human_action(GameAction.buy_dev_card())

func _on_play_guard_pressed() -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	_pending_guard_card = true
	var tiles: Array[int] = []
	for t_id in range(session.state.tile_terrains.size()):
		if t_id != session.state.blocker_tile:
			tiles.append(t_id)
	_board_view.set_highlights(BoardView.InteractionMode.PICK_BLOCKER_TILE, [], [], tiles)
	_cancel_pick_btn.visible = true
	_set_banner("Play Guard: Click a highlighted hex tile to move the Blocker.")

func _on_play_road_work_pressed() -> void:
	_submit_human_action(GameAction.play_road_work())

func _on_play_bounty_pressed() -> void:
	_on_toggle_bounty_panel()

func _on_play_decree_pressed() -> void:
	_on_toggle_decree_panel()

func _on_auto_discard_pressed() -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	var acting_id := session.get_acting_player_id()
	var req_cnt: int = int(session.state.pending_discards.get(acting_id, 0))
	if req_cnt <= 0:
		return
	var hand: Dictionary = session.state.players[acting_id].get("hand", {}).duplicate()
	var discard := GameTypes.empty_hand()
	var remaining := req_cnt
	while remaining > 0:
		var best_res := -1
		var best_amt := 0
		for r in GameTypes.ALL_RESOURCES:
			var amt := int(hand.get(r, 0))
			if amt > best_amt:
				best_amt = amt
				best_res = r
		if best_res == -1:
			break
		hand[best_res] = int(hand[best_res]) - 1
		discard[best_res] = int(discard[best_res]) + 1
		remaining -= 1
	_submit_human_action(GameAction.discard_resources(discard))

func _hide_all_subpanels() -> void:
	_bounty_box.visible = false
	_decree_box.visible = false

# ---------------------------------------------------------------------
# Trade tray (open trade: propose to all, respond, bank as one partner)
# ---------------------------------------------------------------------
func _build_trade_tray(parent_column: VBoxContainer) -> void:
	_trade_tray = PanelContainer.new()
	_trade_tray.visible = false
	_trade_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_tray.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(10)
	st.set_border_width_all(2)
	st.border_color = Palette.PANEL_BORDER
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 4
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	_trade_tray.add_theme_stylebox_override("panel", st)
	_trade_tray.clip_contents = true
	parent_column.add_child(_trade_tray)

	_trade_content = VBoxContainer.new()
	_trade_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_content.add_theme_constant_override("separation", 4)
	_trade_tray.add_child(_trade_content)

	_trade_headline = Label.new()
	_trade_headline.add_theme_font_size_override("font_size", 15)
	_trade_headline.add_theme_color_override("font_color", Palette.HEADING)
	_trade_headline.visible = false
	_trade_content.add_child(_trade_headline)

	_trade_have_label = Label.new()
	_trade_have_label.add_theme_font_size_override("font_size", 13)
	_trade_have_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_trade_have_label.visible = false
	_trade_content.add_child(_trade_have_label)

	# Respond-mode button row (headline + "You have" live above it)
	_trade_respond_row = HBoxContainer.new()
	_trade_respond_row.add_theme_constant_override("separation", 8)
	_trade_respond_row.visible = false
	_trade_content.add_child(_trade_respond_row)
	_ot_accept_btn = _make_tray_button("Accept", "primary", "Accept this offer")
	_ot_accept_btn.pressed.connect(_on_accept_offer_pressed)
	_trade_respond_row.add_child(_ot_accept_btn)
	_ot_decline_btn = _make_tray_button("Decline", "ghost", "Decline this offer")
	_ot_decline_btn.pressed.connect(_on_decline_offer_pressed)
	_trade_respond_row.add_child(_ot_decline_btn)
	_ot_counter_btn = _make_tray_button("Counter…", "normal", "Propose different terms")
	_ot_counter_btn.pressed.connect(_on_counter_offer_pressed)
	_trade_respond_row.add_child(_ot_counter_btn)

	# Open-offer row: summary text + Withdraw at the right end
	_trade_summary_row = HBoxContainer.new()
	_trade_summary_row.add_theme_constant_override("separation", 8)
	_trade_summary_row.visible = false
	_trade_content.add_child(_trade_summary_row)
	_trade_summary = Label.new()
	_trade_summary.add_theme_font_size_override("font_size", 15)
	_trade_summary.add_theme_color_override("font_color", Palette.HEADING)
	_trade_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trade_summary_row.add_child(_trade_summary)
	_trade_withdraw_btn = _make_tray_button("Withdraw offer", "danger", "Take your offer back")
	_trade_withdraw_btn.custom_minimum_size = Vector2(0, 32)
	_trade_withdraw_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_trade_withdraw_btn.pressed.connect(_on_withdraw_offer_pressed)
	_trade_summary_row.add_child(_trade_withdraw_btn)

	# Propose body: stepper rows at the left, Ask/Clear at the right end
	_trade_propose_body = HBoxContainer.new()
	_trade_propose_body.add_theme_constant_override("separation", 8)
	_trade_propose_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_propose_body.visible = false
	_trade_content.add_child(_trade_propose_body)

	_trade_steppers_col = VBoxContainer.new()
	_trade_steppers_col.add_theme_constant_override("separation", 2)
	_trade_steppers_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trade_propose_body.add_child(_trade_steppers_col)
	_build_trade_side_row(true)
	_build_trade_side_row(false)

	_trade_side_col = VBoxContainer.new()
	_trade_side_col.add_theme_constant_override("separation", 4)
	_trade_side_col.size_flags_horizontal = Control.SIZE_SHRINK_END
	_trade_side_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trade_propose_body.add_child(_trade_side_col)

	_trade_ask_group = VBoxContainer.new()
	_trade_ask_group.add_theme_constant_override("separation", 4)
	_trade_side_col.add_child(_trade_ask_group)
	_trade_ask_btn = _make_tray_button("Ask players", "primary", "Post this offer to every other player")
	_trade_ask_btn.custom_minimum_size = Vector2(118, 34)
	_trade_ask_btn.pressed.connect(_on_ask_players_pressed)
	_trade_ask_group.add_child(_trade_ask_btn)
	_trade_clear_btn = _make_tray_button("Clear", "ghost", "Reset both sides of the offer")
	_trade_clear_btn.custom_minimum_size = Vector2(118, 28)
	_trade_clear_btn.pressed.connect(_on_clear_trade_pressed)
	_trade_ask_group.add_child(_trade_clear_btn)

	_ot_send_btn = _make_tray_button("Send counter", "primary", "Send your counter-offer")
	_ot_send_btn.custom_minimum_size = Vector2(118, 34)
	_ot_send_btn.pressed.connect(_on_send_counter_pressed)
	_ot_send_btn.visible = false
	_trade_side_col.add_child(_ot_send_btn)
	_ot_back_btn = _make_tray_button("Back", "ghost", "Go back without countering")
	_ot_back_btn.custom_minimum_size = Vector2(118, 28)
	_ot_back_btn.pressed.connect(_on_counter_back_pressed)
	_ot_back_btn.visible = false
	_trade_side_col.add_child(_ot_back_btn)

	# Partner cards: one horizontal row of equal-width cards filling the tray
	_trade_partner_row = HBoxContainer.new()
	_trade_partner_row.add_theme_constant_override("separation", 6)
	_trade_partner_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_partner_row.visible = false
	_trade_content.add_child(_trade_partner_row)

	for r in GameTypes.ALL_RESOURCES:
		_trade_give_counts[r] = 0
		_trade_get_counts[r] = 0

	resized.connect(func() -> void: _update_tray_min_height())

func _build_trade_side_row(is_give: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	_trade_steppers_col.add_child(row)
	var cap := Label.new()
	cap.text = "You give" if is_give else "You get"
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", Palette.HEADING)
	row.add_child(cap)
	for r in GameTypes.ALL_RESOURCES:
		_build_trade_stepper(row, r, is_give)

func _resource_abbrev(res: int) -> String:
	return GameTypes.resource_name(res).substr(0, 3).to_upper()

func _make_tray_button(btn_text: String, kind: String, tip: String) -> Button:
	var b := Button.new()
	b.text = btn_text
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 13)
	b.tooltip_text = tip
	_style_button(b, kind)
	return b

func _build_trade_stepper(parent: HBoxContainer, res: int, is_give: bool) -> void:
	var grp := HBoxContainer.new()
	grp.add_theme_constant_override("separation", 1)
	parent.add_child(grp)

	var sq := ColorRect.new()
	sq.custom_minimum_size = Vector2(8, 8)
	sq.color = _resource_color(res)
	sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grp.add_child(sq)

	var name_lbl := Label.new()
	name_lbl.text = _resource_abbrev(res)
	name_lbl.tooltip_text = "%s: %s" % [
		GameTypes.resource_name(res),
		"add to your offer" if is_give else "add to your request",
	]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	grp.add_child(name_lbl)

	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(32, 32)
	minus.add_theme_font_size_override("font_size", 14)
	_style_button(minus, "ghost")
	_tighten_button_margins(minus, 2)
	minus.tooltip_text = "Remove one %s from %s" % [GameTypes.resource_name(res), "your offer" if is_give else "your request"]

	var cnt := Label.new()
	cnt.text = "0"
	cnt.custom_minimum_size = Vector2(12, 0)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.add_theme_font_size_override("font_size", 13)
	cnt.add_theme_color_override("font_color", Palette.INK)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(32, 32)
	plus.add_theme_font_size_override("font_size", 14)
	_style_button(plus, "ghost")
	_tighten_button_margins(plus, 2)
	plus.tooltip_text = "Add one %s to %s" % [GameTypes.resource_name(res), "your offer" if is_give else "your request"]

	minus.pressed.connect(func() -> void: _adjust_trade_count(is_give, res, -1))
	plus.pressed.connect(func() -> void: _adjust_trade_count(is_give, res, 1))

	grp.add_child(minus)
	grp.add_child(cnt)
	grp.add_child(plus)

	var store: Dictionary = _trade_give_gui if is_give else _trade_get_gui
	store[res] = {"minus": minus, "plus": plus, "count": cnt}

func _trade_dash_pid() -> int:
	return _view_pid()

func _trade_hand() -> Dictionary:
	if session == null or session.state == null:
		return {}
	return session.state.players[_trade_dash_pid()].get("hand", {})

func _adjust_trade_count(is_give: bool, res: int, delta: int) -> void:
	if session == null or session.state == null:
		return
	var counts: Dictionary = _trade_give_counts if is_give else _trade_get_counts
	var other: Dictionary = _trade_get_counts if is_give else _trade_give_counts
	var max_v := 9
	if is_give:
		max_v = int(_trade_hand().get(res, 0))
	var v := clampi(int(counts.get(res, 0)) + delta, 0, max_v)
	counts[res] = v
	if v > 0 and int(other.get(res, 0)) > 0:
		other[res] = 0
	_refresh_ui()

func _reset_trade_counts() -> void:
	for r in GameTypes.ALL_RESOURCES:
		_trade_give_counts[r] = 0
		_trade_get_counts[r] = 0
	_update_trade_stepper_labels()

func _update_trade_stepper_labels() -> void:
	for r in GameTypes.ALL_RESOURCES:
		var g: Dictionary = _trade_give_gui.get(r, {})
		if not g.is_empty():
			var gl: Label = g["count"]
			gl.text = str(int(_trade_give_counts.get(r, 0)))
		var t: Dictionary = _trade_get_gui.get(r, {})
		if not t.is_empty():
			var tl: Label = t["count"]
			tl.text = str(int(_trade_get_counts.get(r, 0)))

func _trade_side_total(counts: Dictionary) -> int:
	var total := 0
	for r in GameTypes.ALL_RESOURCES:
		total += int(counts.get(r, 0))
	return total

func _trade_side_resource(counts: Dictionary) -> int:
	var found := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(counts.get(r, 0)) > 0:
			if found != -1:
				return -2
			found = r
	return found

func _ot_token(ot: Dictionary) -> String:
	if ot.is_empty():
		return ""
	return "%d|%s|%s" % [int(ot.get("from", -1)), str(ot.get("offer", {})), str(ot.get("request", {}))]

func _ot_dismiss_key(ot: Dictionary, pid: int) -> String:
	return "%s|%d" % [_ot_token(ot), pid]

func _all_answers_in(state: GameState, from_p: int) -> bool:
	var responses: Dictionary = state.open_trade.get("responses", {})
	for p_id in range(state.num_players):
		if p_id != from_p and not responses.has(p_id):
			return false
	return true

func _set_trade_hint(on: bool) -> void:
	if on == _trade_proposer_hint:
		return
	_trade_proposer_hint = on
	if _trade_btn == null:
		return
	if on:
		if _reduce_motion or not _trade_btn.is_inside_tree():
			return
		_trade_btn.pivot_offset = _trade_btn.size * 0.5
		_trade_hint_tween = _trade_btn.create_tween()
		_trade_hint_tween.set_loops()
		_trade_hint_tween.tween_property(_trade_btn, "scale", Vector2(1.09, 1.09), 0.55)
		_trade_hint_tween.tween_property(_trade_btn, "scale", Vector2.ONE, 0.55)
	else:
		if _trade_hint_tween != null and _trade_hint_tween.is_valid():
			_trade_hint_tween.kill()
		_trade_hint_tween = null
		_trade_btn.scale = Vector2.ONE

func _trade_allowed_now() -> bool:
	if session == null or session.state == null:
		return false
	var st := session.state
	if st.phase == GameTypes.TurnPhase.GAME_OVER or not _is_human_acting():
		return false
	if st.phase == GameTypes.TurnPhase.TURN_MAIN:
		return true
	if not st.open_trade.is_empty():
		return int(st.open_trade.get("from", -1)) != session.get_acting_player_id()
	return false

func _toggle_trade_tray() -> void:
	if _trade_tray == null:
		return
	if _hand_hidden():
		return
	if _trade_tray.visible:
		_close_trade_tray_by_user()
		return
	if not _trade_allowed_now():
		return
	_cancel_build_bubble()
	_trade_tray.visible = true
	_trade_opened_auto = false
	_trade_reopen_token = ""
	_trade_ready_dismissed = false
	_set_trade_hint(false)
	_refresh_ui()

func _close_trade_tray_by_user() -> void:
	if _trade_tray == null or not _trade_tray.visible:
		return
	_trade_tray.visible = false
	_trade_counter_mode = false
	_trade_tray.custom_minimum_size.y = 0.0
	if session != null and session.state != null:
		var st := session.state
		var ot: Dictionary = st.open_trade
		var from_p := int(ot.get("from", -1))
		if (
			not ot.is_empty()
			and _is_human_acting()
			and from_p == _view_pid()
			and session.get_acting_player_id() == from_p
			and _all_answers_in(st, from_p)
		):
			_trade_ready_dismissed = true
			_set_trade_hint(true)
			if _board_view.interaction_mode == BoardView.InteractionMode.NONE and not _pending_guard_card:
				_set_banner(_compute_instruction(st, session.get_acting_player_id(), true))
		else:
			_trade_reopen_token = _ot_dismiss_key(ot, _view_pid())

# In-flow tray: it reserves its natural height so the board shrinks instead
# of being covered; in very short windows the reserved height is capped to
# what is left over the board's 480 px minimum and the tray scrolls inside.
func _update_tray_min_height() -> void:
	if _trade_tray == null:
		return
	if not _trade_tray.visible:
		_trade_tray.custom_minimum_size.y = 0.0
		return
	var nat := _trade_content.get_combined_minimum_size().y + 12.0
	var avail := 99999.0
	if _center_split != null and _center_split.size.y > 0.0:
		avail = _center_split.size.y - 480.0
	_trade_tray.custom_minimum_size.y = minf(nat, maxf(avail, 96.0))

func _refresh_trade_tray(state: GameState, acting_id: int, human_acting: bool) -> void:
	if _trade_tray == null:
		return
	var ot: Dictionary = state.open_trade
	var ot_open := not ot.is_empty()
	if _trade_last_ot_open and not ot_open:
		_reset_trade_counts()
		_trade_reopen_token = ""
		_trade_ready_dismissed = false
		_set_trade_hint(false)
		if _trade_opened_auto and _trade_tray.visible:
			_trade_tray.visible = false
		_trade_opened_auto = false
	_trade_last_ot_open = ot_open
	var from_p := int(ot.get("from", -1))
	var my_pid := _view_pid()
	var from_me_show := ot_open and from_p == my_pid
	var respond := ot_open and human_acting and from_p != acting_id
	var from_me := from_me_show and human_acting and acting_id == from_p

	# Hot-seat: a fresh viewer starts from a clean draft, not the previous
	# human's stepper counts or counter mode.
	if my_pid != _trade_view_pid:
		_trade_view_pid = my_pid
		_trade_counter_mode = false
		_reset_trade_counts()

	if respond and not _trade_respond_mode:
		_trade_respond_mode = true
		_trade_counter_mode = false
	if _trade_respond_mode and not respond:
		_trade_respond_mode = false
		_trade_counter_mode = false

	# The tray must follow the viewed human: whenever they act on an open
	# offer (responder or proposer) it must be open in their mode. A user
	# close is remembered per (offer, seat), but never silences the proposer
	# once every answer is in; a close at that stage keeps the Trade button
	# pulsing and the banner points at it.
	if ot_open and human_acting:
		if from_me and _all_answers_in(state, from_p):
			if _trade_ready_dismissed and not _trade_tray.visible:
				_set_trade_hint(true)
			else:
				_trade_reopen_token = ""
				_trade_ready_dismissed = false
				_set_trade_hint(false)
				_trade_tray.visible = true
		elif _trade_reopen_token != _ot_dismiss_key(ot, my_pid):
			var was_tray_open := _trade_tray.visible
			_trade_tray.visible = true
			if respond and not was_tray_open:
				_trade_opened_auto = true

	var counter := respond and _trade_counter_mode
	var propose_idle := (not respond) and (not from_me_show)

	_trade_headline.visible = respond
	_trade_have_label.visible = respond
	if respond:
		_trade_headline.text = "%s offers %s and wants %s" % [
			GameTypes.PLAYER_NAMES[from_p],
			_format_resource_bundle(ot.get("offer", {})),
			_format_resource_bundle(ot.get("request", {})),
		]
		var have_parts: Array[String] = []
		var hand: Dictionary = state.players[acting_id].get("hand", {})
		for r in GameTypes.ALL_RESOURCES:
			var want_amt: int = int(ot.get("request", {}).get(r, 0))
			if want_amt > 0:
				have_parts.append("%d %s" % [int(hand.get(r, 0)), GameTypes.resource_name(r)])
		_trade_have_label.text = "You have: %s" % " + ".join(have_parts)

	_trade_summary_row.visible = from_me_show and (not respond)
	if _trade_summary_row.visible:
		_trade_summary.text = "Your offer: %s for %s" % [
			_format_resource_bundle(ot.get("offer", {})),
			_format_resource_bundle(ot.get("request", {})),
		]

	_trade_respond_row.visible = respond and (not counter)
	_trade_propose_body.visible = propose_idle or counter
	_trade_partner_row.visible = (not respond) and (not counter)

	var propose_ok := (
		human_acting
		and state.phase == GameTypes.TurnPhase.TURN_MAIN
		and not ot_open
	)
	var unlocked := propose_ok or counter
	for side in [_trade_give_gui, _trade_get_gui]:
		for r in side.keys():
			var gui: Dictionary = side[r]
			(gui["minus"] as Button).disabled = not unlocked
			(gui["plus"] as Button).disabled = not unlocked

	if unlocked:
		var hand2: Dictionary = state.players[acting_id].get("hand", {}) if human_acting else _trade_hand()
		for r in GameTypes.ALL_RESOURCES:
			_trade_give_counts[r] = clampi(int(_trade_give_counts.get(r, 0)), 0, int(hand2.get(r, 0)))
		_update_trade_stepper_labels()

	var give_total := _trade_side_total(_trade_give_counts)
	var get_total := _trade_side_total(_trade_get_counts)

	_trade_ask_group.visible = propose_idle
	var offer_cap_hit := state.open_trades_this_turn >= RulesEngine.MAX_OPEN_TRADES_PER_TURN
	_trade_ask_btn.disabled = not (propose_ok and give_total > 0 and get_total > 0) or (propose_ok and offer_cap_hit)
	if propose_ok and offer_cap_hit:
		_trade_ask_btn.tooltip_text = "You can post at most %d offers per turn." % RulesEngine.MAX_OPEN_TRADES_PER_TURN
	else:
		_trade_ask_btn.tooltip_text = "Post this offer to every other player"
	_trade_withdraw_btn.disabled = not from_me
	_trade_clear_btn.disabled = (give_total == 0 and get_total == 0) or not unlocked
	_ot_send_btn.visible = counter
	_ot_back_btn.visible = counter
	_ot_send_btn.disabled = not (give_total > 0 and get_total > 0)
	if respond and not counter:
		var need_hand: Dictionary = state.players[acting_id].get("hand", {})
		var missing := _missing_resources(need_hand, ot.get("request", {}))
		_ot_accept_btn.disabled = not missing.is_empty()
		if not missing.is_empty():
			_ot_accept_btn.tooltip_text = missing
		else:
			_ot_accept_btn.tooltip_text = "Accept this offer"

	_rebuild_partner_cards(state, ot, ot_open, from_me, not ot_open)
	if _hand_hidden():
		_trade_tray.visible = false
	if _trade_tray.visible:
		_update_tray_min_height()

func _rebuild_partner_cards(state: GameState, ot: Dictionary, ot_open: bool, human_can_pick: bool, show_bank: bool) -> void:
	if _trade_partner_row == null:
		return
	for c in _trade_partner_row.get_children():
		c.queue_free()
	_trade_bank_btn = null

	if show_bank:
		var bank_card := _make_partner_card("Bank / Port", null)
		var ratio_text := _bank_ratio_label(state, _trade_dash_pid())
		var bank_lbl := _add_card_status(bank_card, ratio_text, Palette.TEXT_MUTED, 11)
		var bank_sel := _bank_selection_check(state, _trade_dash_pid())
		var hint := ""
		if bank_sel.is_empty():
			if _trade_side_resource(_trade_give_counts) == -2:
				hint = "Pick exactly ONE resource to give"
			elif _trade_side_resource(_trade_get_counts) == -2:
				hint = "Pick exactly ONE resource to get"
			elif _trade_side_resource(_trade_give_counts) >= 0:
				var g_res: int = _trade_side_resource(_trade_give_counts)
				var ratio := state.get_trade_ratio(_trade_dash_pid(), g_res)
				var want_name := "a different resource"
				var t_res: int = _trade_side_resource(_trade_get_counts)
				if t_res >= 0:
					want_name = GameTypes.resource_name(t_res)
				hint = "Give %d %s to get 1 %s" % [ratio, GameTypes.resource_name(g_res), want_name]
			else:
				hint = "Pick one resource to give"
		else:
			hint = "Give %d %s to get %d %s" % [
				int(bank_sel.get("give_count", 0)),
				GameTypes.resource_name(int(bank_sel.get("give_res", -1))),
				int(bank_sel.get("get_count", 0)),
				GameTypes.resource_name(int(bank_sel.get("get_res", -1))),
			]
		_add_card_status(bank_card, hint, Palette.ACCENT_GREEN.darkened(0.25) if not bank_sel.is_empty() else Palette.TEXT_MUTED, 12)
		bank_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_trade_bank_btn = _make_card_trade_button("Give %s: %s" % [hint, ratio_text])
		var bank_ok := _is_human_acting() and state.phase == GameTypes.TurnPhase.TURN_MAIN and state.open_trade.is_empty()
		_trade_bank_btn.visible = not bank_sel.is_empty()
		_trade_bank_btn.disabled = bank_sel.is_empty() or not bank_ok
		if not bank_sel.is_empty():
			_trade_bank_btn.pressed.connect(_on_bank_trade_pressed)
		(bank_card.get_child(0) as VBoxContainer).add_child(_trade_bank_btn)
		_trade_partner_row.add_child(bank_card)

	var self_id := _trade_dash_pid()
	for idx in range(state.players.size()):
		if idx == self_id:
			continue
		var p_data: Dictionary = state.players[idx]
		var p_id: int = int(p_data.get("id", idx))
		var status := "—"
		var status_color := Palette.TEXT_MUTED
		var can_trade := false
		if ot_open:
			if p_id == int(ot.get("from", -1)):
				status = "Offering…"
				status_color = Palette.HEADING
			else:
				var responses: Dictionary = ot.get("responses", {})
				if not responses.has(p_id):
					status = "Waiting…"
					status_color = Palette.TEXT_MUTED
				else:
					var resp: Dictionary = responses[p_id]
					var st_str := str(resp.get("status", ""))
					if st_str == "accept":
						status = "✓ Accepts"
						status_color = Palette.ACCENT_GREEN.darkened(0.25)
						can_trade = true
					elif st_str == "decline":
						status = "✗ Declines"
						status_color = Palette.ACCENT_RED.darkened(0.1)
					elif st_str == "counter":
						status = "↺ Counter: gives %s for %s" % [
							_format_resource_bundle(resp.get("request", {})),
							_format_resource_bundle(resp.get("offer", {})),
						]
						status_color = Palette.HEADING
						can_trade = true
		var pname := str(p_data.get("name", GameTypes.PLAYER_NAMES[p_id]))
		var card := _make_partner_card(pname, GameTypes.PLAYER_COLORS[p_id])
		card.tooltip_text = "%s — %s" % [pname, status]
		var st_lbl := _add_card_status(card, status, status_color, 12)
		st_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var t_btn := _make_card_trade_button("Complete the trade with %s" % pname)
		t_btn.visible = can_trade
		t_btn.disabled = not can_trade or not human_can_pick
		if can_trade:
			var partner := p_id
			t_btn.pressed.connect(func() -> void: _submit_human_action(GameAction.finalize_open_trade(partner)))
		(card.get_child(0) as VBoxContainer).add_child(t_btn)
		_trade_partner_row.add_child(card)

func _make_partner_card(title: String, swatch_color: Variant) -> PanelContainer:
	var card := PanelContainer.new()
	var cst := _paper_panel_style(true)
	cst.set_corner_radius_all(8)
	cst.set_border_width_all(1)
	cst.border_color = Palette.PANEL_BORDER
	cst.shadow_color = Color(0, 0, 0, 0)
	cst.content_margin_left = 5
	cst.content_margin_right = 5
	cst.content_margin_top = 4
	cst.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", cst)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 5)
	col.add_child(row1)
	if swatch_color != null:
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(10, 10)
		sw.color = swatch_color
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row1.add_child(sw)
	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row1.add_child(name_lbl)
	return card

func _add_card_status(card: PanelContainer, text: String, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.resized.connect(_update_tray_min_height)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(card.get_child(0) as VBoxContainer).add_child(lbl)
	return lbl

func _make_card_trade_button(tip: String) -> Button:
	var b := Button.new()
	b.text = "Trade"
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_font_size_override("font_size", 12)
	b.tooltip_text = tip
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_button(b, "primary")
	return b

func _bank_ratio_label(state: GameState, pid: int) -> String:
	var parts: Array[String] = ["Bank 4:1"]
	var generic := false
	var specials: Array[String] = []
	for r in GameTypes.ALL_RESOURCES:
		var ratio := state.get_trade_ratio(pid, r)
		if ratio == 2:
			specials.append("2:1 %s" % GameTypes.resource_name(r))
		elif ratio == 3:
			generic = true
	if generic:
		parts.append("Port 3:1")
	parts.append_array(specials)
	return " · ".join(parts)

func _bank_selection_check(state: GameState, pid: int) -> Dictionary:
	var g_res := _trade_side_resource(_trade_give_counts)
	var t_res := _trade_side_resource(_trade_get_counts)
	if g_res < 0 or t_res < 0:
		return {}
	var g_cnt := int(_trade_give_counts.get(g_res, 0))
	var t_cnt := int(_trade_get_counts.get(t_res, 0))
	var ratio := state.get_trade_ratio(pid, g_res)
	if g_cnt != ratio * t_cnt:
		return {}
	return {"give_res": g_res, "get_res": t_res, "give_count": g_cnt, "get_count": t_cnt}

func _on_ask_players_pressed() -> void:
	if session == null or session.state == null:
		return
	if _trade_side_total(_trade_give_counts) <= 0 or _trade_side_total(_trade_get_counts) <= 0:
		return
	_submit_human_action(GameAction.open_trade(_trade_give_counts.duplicate(), _trade_get_counts.duplicate()))

func _on_withdraw_offer_pressed() -> void:
	_submit_human_action(GameAction.cancel_open_trade())

func _on_clear_trade_pressed() -> void:
	_reset_trade_counts()
	_refresh_trade_tray(session.state, session.get_acting_player_id(), _is_human_acting())

func _on_bank_trade_pressed() -> void:
	if session == null or session.state == null:
		return
	var sel := _bank_selection_check(session.state, _trade_dash_pid())
	if sel.is_empty():
		return
	var times := int(sel.get("get_count", 0))
	for i in range(times):
		_submit_human_action(GameAction.maritime_trade(int(sel.get("give_res", -1)), int(sel.get("get_res", -1))))
	_reset_trade_counts()

func _on_accept_offer_pressed() -> void:
	_submit_human_action(GameAction.respond_open_trade("accept"))

func _on_decline_offer_pressed() -> void:
	_submit_human_action(GameAction.respond_open_trade("decline"))

func _on_counter_offer_pressed() -> void:
	if session == null or session.state == null:
		return
	_trade_counter_mode = true
	_reset_trade_counts()
	var ot: Dictionary = session.state.open_trade
	var hand: Dictionary = session.state.players[session.get_acting_player_id()].get("hand", {})
	for r in GameTypes.ALL_RESOURCES:
		var want_amt: int = clampi(int(ot.get("request", {}).get(r, 0)), 0, int(hand.get(r, 0)))
		_trade_give_counts[r] = want_amt
	for r in GameTypes.ALL_RESOURCES:
		_trade_get_counts[r] = clampi(int(ot.get("offer", {}).get(r, 0)), 0, 9)
		_update_trade_stepper_labels()
	_refresh_ui()

func _on_send_counter_pressed() -> void:
	if session == null or session.state == null:
		return
	if _trade_side_total(_trade_give_counts) <= 0 or _trade_side_total(_trade_get_counts) <= 0:
		return
	_submit_human_action(GameAction.respond_open_trade(
		"counter",
		_trade_get_counts.duplicate(),
		_trade_give_counts.duplicate()
	))

func _on_counter_back_pressed() -> void:
	_trade_counter_mode = false
	_reset_trade_counts()
	_refresh_trade_tray(session.state, session.get_acting_player_id(), _is_human_acting())

func _on_resource_card_pressed(res: int) -> void:
	if session == null or session.state == null:
		return
	if _hand_hidden():
		return
	var st := session.state
	if not (
		_is_human_acting()
		and st.phase == GameTypes.TurnPhase.TURN_MAIN
		and st.open_trade.is_empty()
	):
		return
	if _trade_respond_mode:
		return
	if not _trade_tray.visible:
		_trade_tray.visible = true
		_trade_opened_auto = false
		_trade_reopen_token = ""
	_adjust_trade_count(true, res, 1)

func _style_card_button(btn: Button) -> void:
	var st_n := StyleBoxFlat.new()
	st_n.bg_color = Palette.PAPER
	st_n.border_color = Palette.PANEL_BORDER
	st_n.set_border_width_all(2)
	st_n.set_corner_radius_all(8)
	st_n.shadow_color = Palette.PAPER_SHADOW
	st_n.shadow_size = 4
	btn.add_theme_stylebox_override("normal", st_n)

	var st_h: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_h.bg_color = Palette.PANEL_BG_ALT
	st_h.border_color = Palette.HEADING
	btn.add_theme_stylebox_override("hover", st_h)

	var st_p: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_p.bg_color = Palette.PANEL_BG_ALT.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", st_p)

	var st_d: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_d.bg_color = Palette.BUTTON_BG_DISABLED
	st_d.border_color = Color(Palette.PANEL_BORDER, 0.5)
	st_d.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", st_d)

	var st_f: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_f.border_color = Palette.HEADING
	st_f.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", st_f)

func _cancel_current_pick() -> void:
	_pending_guard_card = false
	_board_view.clear_highlights()
	_cancel_pick_btn.visible = false
	_refresh_ui()


func _on_toggle_bounty_panel() -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	var was_vis := _subpanel_container.visible and _bounty_box.visible
	_hide_all_subpanels()
	_bounty_box.visible = not was_vis
	_subpanel_container.visible = not was_vis
	_subpanel_owner_pid = session.get_acting_player_id() if not was_vis else -1

func _on_toggle_decree_panel() -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	var was_vis := _subpanel_container.visible and _decree_box.visible
	_hide_all_subpanels()
	_decree_box.visible = not was_vis
	_subpanel_container.visible = not was_vis
	_subpanel_owner_pid = session.get_acting_player_id() if not was_vis else -1

# Hide Bounty/Decree panels whenever the viewed human can no longer play
# that card; submittals are only honoured for the player who opened them.
func _refresh_subpanels(state: GameState, acting_id: int, human_acting: bool) -> void:
	if _subpanel_container == null or not _subpanel_container.visible:
		return
	if _bounty_box.visible:
		var bounty_ok := (
			human_acting
			and acting_id == _subpanel_owner_pid
			and bool(RulesEngine.can_play_dev_card(state, acting_id, GameTypes.DevCardType.HARVEST_BOUNTY).get("ok", false))
		)
		if not bounty_ok:
			_bounty_box.visible = false
	if _decree_box.visible:
		var decree_ok := (
			human_acting
			and acting_id == _subpanel_owner_pid
			and bool(RulesEngine.can_play_dev_card(state, acting_id, GameTypes.DevCardType.TRADE_DECREE).get("ok", false))
		)
		if not decree_ok:
			_decree_box.visible = false
	if not _bounty_box.visible and not _decree_box.visible:
		_subpanel_container.visible = false
		_subpanel_owner_pid = -1

# Helpers
func _find_first_human_seat() -> int:
	if session != null:
		for i in range(session.seats.size()):
			if not session.seats[i].is_ai():
				return i
	return 0

func _seat_type_label(cfg: SeatConfig) -> String:
	if cfg == null:
		return "Human"
	match cfg.seat_type:
		SeatConfig.SeatType.HUMAN: return "Human"
		SeatConfig.SeatType.AI_EASY: return "AI Easy"
		SeatConfig.SeatType.AI_MEDIUM: return "AI Med"
		SeatConfig.SeatType.AI_HARD: return "AI Hard"
		_: return "AI"

func _format_resource_bundle(bundle: Dictionary) -> String:
	var parts: Array[String] = []
	for r in GameTypes.ALL_RESOURCES:
		var cnt := int(bundle.get(r, 0))
		if cnt > 0:
			parts.append("%d %s" % [cnt, GameTypes.resource_name(r)])
	return " + ".join(parts) if not parts.is_empty() else "Nothing"

func _resource_color(res: int) -> Color:
	return Palette.resource(res)

func _pulse_card(node: Control) -> void:
	if _reduce_motion:
		return
	if node == null or not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.14, 1.14), 0.12)
	tw.tween_property(node, "scale", Vector2.ONE, 0.16)

# ---------------------------------------------------------------------
# Paper / watercolour styling helpers
# ---------------------------------------------------------------------
func _paper_panel_style(alt: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if alt:
		sb.bg_color = Palette.PANEL_BG_ALT
	else:
		sb.bg_color = Palette.PANEL_BG
	sb.border_color = Palette.PANEL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Palette.PAPER_SHADOW
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _style_button(btn: BaseButton, kind: String = "normal") -> void:
	var bg_n: Color = Palette.BUTTON_BG
	var bg_h: Color = Palette.BUTTON_BG_HOVER
	var bg_p: Color = Palette.BUTTON_BG_PRESSED
	var fg: Color = Palette.BUTTON_TEXT
	match kind:
		"primary":
			bg_n = Palette.ACCENT_GOLD
			bg_h = Palette.ACCENT_GOLD.lightened(0.08)
			bg_p = Palette.ACCENT_GOLD.darkened(0.08)
		"danger":
			bg_n = Palette.ACCENT_RED
			bg_h = Palette.ACCENT_RED.lightened(0.07)
			bg_p = Palette.ACCENT_RED.darkened(0.08)
			fg = Palette.TEXT_ON_DARK
		"ghost":
			bg_n = Color(Palette.PANEL_BG, 0.0)
			bg_h = Color(Palette.BUTTON_BG, 0.65)
			bg_p = Color(Palette.BUTTON_BG_PRESSED, 0.9)
		_:
			pass

	var st_n := StyleBoxFlat.new()
	st_n.bg_color = bg_n
	st_n.border_color = Palette.PANEL_BORDER
	st_n.set_border_width_all(2)
	st_n.set_corner_radius_all(8)
	st_n.content_margin_left = 8
	st_n.content_margin_right = 8
	st_n.content_margin_top = 4
	st_n.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", st_n)

	var st_h: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_h.bg_color = bg_h
	btn.add_theme_stylebox_override("hover", st_h)

	var st_p: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_p.bg_color = bg_p
	st_p.border_color = Palette.PANEL_BORDER.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", st_p)

	var st_d: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_d.bg_color = Palette.BUTTON_BG_DISABLED
	st_d.border_color = Color(Palette.PANEL_BORDER, 0.5)
	btn.add_theme_stylebox_override("disabled", st_d)

	var st_f: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_f.bg_color = Color(Palette.PANEL_BG, 0.0)
	st_f.border_color = Palette.HEADING
	st_f.set_border_width_all(3)
	btn.add_theme_stylebox_override("focus", st_f)

	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_color_override("font_focus_color", fg)
	btn.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)

func _style_option(opt: OptionButton) -> void:
	_style_button(opt, "normal")
	_style_popup(opt.get_popup())

func _tighten_button_margins(btn: Button, side_margin: int) -> void:
	for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = (btn.get_theme_stylebox(st_name) as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.content_margin_left = side_margin
		sb.content_margin_right = side_margin
		btn.add_theme_stylebox_override(st_name, sb)

func _style_popup(p: PopupMenu) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Palette.PANEL_BG
	panel.border_color = Palette.PANEL_BORDER
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.shadow_color = Palette.PAPER_SHADOW
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(0, 2)
	panel.content_margin_left = 4
	panel.content_margin_right = 4
	panel.content_margin_top = 4
	panel.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", panel)

	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(Palette.ACCENT_GOLD, 0.35)
	hov.set_corner_radius_all(6)
	hov.content_margin_left = 8
	hov.content_margin_right = 8
	hov.content_margin_top = 3
	hov.content_margin_bottom = 3
	p.add_theme_stylebox_override("hover", hov)

	p.add_theme_color_override("font_color", Palette.TEXT)
	p.add_theme_color_override("font_hover_color", Palette.INK)
	p.add_theme_font_size_override("font_size", 14)

func _style_line_edit(le: LineEdit) -> void:
	for state_name in ["normal", "focus", "read_only"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.PAPER
		if state_name == "focus":
			sb.border_color = Palette.HEADING
			sb.set_border_width_all(2)
		else:
			sb.border_color = Palette.PANEL_BORDER
			sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		le.add_theme_stylebox_override(state_name, sb)
	le.add_theme_color_override("font_color", Palette.TEXT)
	le.add_theme_color_override("font_placeholder_color", Palette.TEXT_MUTED)
	le.add_theme_color_override("font_readonly_color", Palette.TEXT_MUTED)
	le.add_theme_color_override("caret_color", Palette.INK)
	le.add_theme_color_override("selection_background_color", Palette.HEADING)
	le.add_theme_color_override("selection_foreground_color", Palette.PAPER)

func _style_check(cb: BaseButton) -> void:
	var unchecked := StyleBoxFlat.new()
	unchecked.bg_color = Palette.PAPER
	unchecked.border_color = Palette.PANEL_BORDER
	unchecked.set_border_width_all(2)
	unchecked.set_corner_radius_all(4)
	unchecked.content_margin_left = 7
	unchecked.content_margin_right = 7
	unchecked.content_margin_top = 7
	unchecked.content_margin_bottom = 7

	var checked: StyleBoxFlat = unchecked.duplicate() as StyleBoxFlat
	checked.bg_color = Palette.ACCENT_GREEN
	checked.border_color = Palette.INK

	var unchecked_d: StyleBoxFlat = unchecked.duplicate() as StyleBoxFlat
	unchecked_d.bg_color = Palette.BUTTON_BG_DISABLED
	unchecked_d.border_color = Color(Palette.PANEL_BORDER, 0.5)

	var checked_d: StyleBoxFlat = checked.duplicate() as StyleBoxFlat
	checked_d.bg_color = Color(Palette.ACCENT_GREEN, 0.45)
	checked_d.border_color = Color(Palette.INK, 0.45)

	cb.add_theme_stylebox_override("unchecked", unchecked)
	cb.add_theme_stylebox_override("checked", checked)
	cb.add_theme_stylebox_override("unchecked_disabled", unchecked_d)
	cb.add_theme_stylebox_override("checked_disabled", checked_d)
	cb.add_theme_stylebox_override("focus", _check_focus_box())

	cb.add_theme_color_override("font_color", Palette.TEXT)
	cb.add_theme_color_override("font_hover_color", Palette.INK)
	cb.add_theme_color_override("font_pressed_color", Palette.INK)
	cb.add_theme_color_override("font_focus_color", Palette.INK)
	cb.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)

func _check_focus_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.PANEL_BG, 0.0)
	sb.border_color = Palette.HEADING
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	return sb

func _style_rich_label(rtl: RichTextLabel) -> void:
	rtl.add_theme_color_override("default_color", Palette.TEXT)
	rtl.add_theme_color_override("font_color", Palette.TEXT)
	rtl.add_theme_font_size_override("normal_font_size", 13)
	rtl.add_theme_font_size_override("bold_font_size", 13)
	var bg_empty := StyleBoxFlat.new()
	bg_empty.bg_color = Color(Palette.PANEL_BG, 0.0)
	rtl.add_theme_stylebox_override("background", bg_empty)

func _make_pill(text: String, bg: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(8)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", fg)
	p.add_child(l)
	return p

func _make_compact_card(bg_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var st := _paper_panel_style()
	st.bg_color = bg_col
	st.set_corner_radius_all(8)
	st.shadow_size = 4
	st.set_border_width_all(2)
	st.border_color = Color(Palette.PANEL_BORDER, 0.8)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	return p

func _make_card_panel(bg_col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var st := _paper_panel_style()
	st.bg_color = bg_col
	st.set_corner_radius_all(10)
	st.set_border_width_all(2)
	st.border_color = Color(Palette.PANEL_BORDER, 0.85)
	p.add_theme_stylebox_override("panel", st)
	return p


# =====================================================================
# Custom drawn 2d6 dice widget (the roll control)
# =====================================================================
class DicePairWidget extends Control:
	const DICE_SIZE := 34.0
	const DICE_GAP := 10.0
	const PILL_W := 54.0
	const PILL_H := 26.0

	signal pressed

	var d1: int = 0
	var d2: int = 0
	var motion_enabled := true
	var _rolling := false
	var _roll_enabled := false
	var _roll_timer: Timer = null
	var _ticks_left := 0
	var _final_d1 := 0
	var _final_d2 := 0
	var _pulse_alpha := 0.55
	var _pulse_tween: Tween = null

	func _ready() -> void:
		var full_w := DICE_SIZE * 2.0 + DICE_GAP + 8.0 + PILL_W + 10.0
		custom_minimum_size = Vector2(full_w, 60.0)
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Last Roll"

	func set_motion_enabled(on: bool) -> void:
		motion_enabled = on
		if _roll_enabled:
			if on and is_inside_tree():
				_start_pulse()
			else:
				_stop_pulse()
				_pulse_alpha = 0.85
		queue_redraw()

	func set_roll_enabled(on: bool) -> void:
		if _roll_enabled == on:
			return
		_roll_enabled = on
		if on:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			tooltip_text = "Click to roll"
			if is_inside_tree():
				_start_pulse()
		else:
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			tooltip_text = "Last Roll"
			_stop_pulse()
		queue_redraw()

	func _start_pulse() -> void:
		_stop_pulse()
		if not motion_enabled:
			_pulse_alpha = 0.85
			queue_redraw()
			return
		_pulse_tween = create_tween()
		_pulse_tween.tween_method(_set_pulse, 0.25, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_method(_set_pulse, 1.0, 0.25, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.set_loops()

	func _stop_pulse() -> void:
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill()
		_pulse_tween = null

	func _set_pulse(a: float) -> void:
		_pulse_alpha = a
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if not _roll_enabled:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				accept_event()
				release_focus()
				pressed.emit()
		elif event is InputEventKey:
			var k := event as InputEventKey
			if k.pressed and not k.echo:
				if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
					accept_event()
					pressed.emit()

	func animate_roll(new_d1: int, new_d2: int) -> void:
		if not motion_enabled or not is_inside_tree():
			d1 = new_d1
			d2 = new_d2
			queue_redraw()
			return
		_final_d1 = new_d1
		_final_d2 = new_d2
		if _roll_timer == null:
			_roll_timer = Timer.new()
			_roll_timer.wait_time = 0.05
			_roll_timer.one_shot = false
			_roll_timer.timeout.connect(_on_roll_tick)
			add_child(_roll_timer)
		_rolling = true
		_ticks_left = 7
		_roll_timer.start()

	func _on_roll_tick() -> void:
		_ticks_left -= 1
		if _ticks_left <= 0:
			_roll_timer.stop()
			_rolling = false
			d1 = _final_d1
			d2 = _final_d2
		else:
			d1 = randi_range(1, 6)
			d2 = randi_range(1, 6)
		queue_redraw()

	func _draw() -> void:
		var top := 2.0
		_draw_die(Vector2(0.0, top), d1)
		_draw_die(Vector2(DICE_SIZE + DICE_GAP, top), d2)

		var pill_pos := Vector2(DICE_SIZE * 2.0 + DICE_GAP + 8.0, top + (DICE_SIZE - PILL_H) * 0.5)
		var pill_rect := Rect2(pill_pos, Vector2(PILL_W, PILL_H))
		var pbox := StyleBoxFlat.new()
		if _rolling:
			pbox.bg_color = Color(Palette.ACCENT_GOLD, 0.55)
		else:
			pbox.bg_color = Palette.PAPER_DARK
		pbox.border_color = Palette.INK
		pbox.set_border_width_all(2)
		pbox.set_corner_radius_all(int(PILL_H * 0.5))
		draw_style_box(pbox, pill_rect)

		var font := ThemeDB.fallback_font
		if font == null:
			_redraw_rings()
			return
		var sum := d1 + d2
		var txt := str(sum) if sum > 0 else "-"
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
		draw_string(
			font,
			pill_rect.position + Vector2(pill_rect.size.x * 0.5 - ts.x * 0.5, pill_rect.size.y * 0.5 + ts.y * 0.30),
			txt,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			15,
			Palette.INK
		)

		if _roll_enabled:
			draw_string(font, Vector2(0.0, size.y - 4.0), "Click to roll", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.HEADING)
		elif sum > 0:
			draw_string(font, Vector2(0.0, size.y - 4.0), "Last roll", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.TEXT_MUTED)
		_redraw_rings()

	func _redraw_rings() -> void:
		if _roll_enabled:
			var ring := StyleBoxFlat.new()
			ring.bg_color = Color(Palette.PANEL_BG, 0.0)
			ring.border_color = Color(Palette.HIGHLIGHT, _pulse_alpha)
			ring.set_border_width_all(3)
			ring.set_corner_radius_all(10)
			draw_style_box(ring, Rect2(Vector2(-2, -2), size + Vector2(4, 4)))
		if has_focus():
			var fr := StyleBoxFlat.new()
			fr.bg_color = Color(Palette.PANEL_BG, 0.0)
			fr.border_color = Palette.HEADING
			fr.set_border_width_all(2)
			fr.set_corner_radius_all(11)
			draw_style_box(fr, Rect2(Vector2(-3, -3), size + Vector2(6, 6)))

	func _draw_die(origin: Vector2, face: int) -> void:
		var rect := Rect2(origin, Vector2(DICE_SIZE, DICE_SIZE))
		var box := StyleBoxFlat.new()
		box.bg_color = Palette.DICE_FACE
		box.border_color = Palette.INK
		box.set_border_width_all(2)
		box.set_corner_radius_all(7)
		box.shadow_color = Palette.PAPER_SHADOW
		box.shadow_size = 4
		box.shadow_offset = Vector2(1, 2)
		draw_style_box(box, rect)

		if face < 1 or face > 6:
			return
		var pts: Array[Vector2] = []
		match face:
			1:
				pts = [Vector2(0.5, 0.5)]
			2:
				pts = [Vector2(0.25, 0.25), Vector2(0.75, 0.75)]
			3:
				pts = [Vector2(0.22, 0.22), Vector2(0.5, 0.5), Vector2(0.78, 0.78)]
			4:
				pts = [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)]
			5:
				pts = [Vector2(0.26, 0.26), Vector2(0.74, 0.26), Vector2(0.5, 0.5), Vector2(0.26, 0.74), Vector2(0.74, 0.74)]
			6:
				pts = [
					Vector2(0.29, 0.20), Vector2(0.71, 0.20),
					Vector2(0.29, 0.5), Vector2(0.71, 0.5),
					Vector2(0.29, 0.8), Vector2(0.71, 0.8),
				]
		var inset := 6.0
		var usable := DICE_SIZE - inset * 2.0
		for p in pts:
			draw_circle(origin + Vector2(inset + p.x * usable, inset + p.y * usable), 3.0, Palette.DICE_PIP)
