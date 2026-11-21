extends Control

var session: LocalSession = null
var auto_ai: bool = true

var _ai_timer: Timer = null
var _pending_guard_card: bool = false
var _steal_chooser: PanelContainer = null
var _steal_chooser_rows: VBoxContainer = null
var _steal_pending: Dictionary = {}
var _steal_victims: Array[int] = []
var _steal_victim_btns: Array[Button] = []
var _toast_layer: VBoxContainer = null
var _toast_labels: Array[Label] = []
var _offer_strip: PanelContainer = null
var _offer_strip_label: Label = null
var _offer_strip_chips: HBoxContainer = null
var _trade_close_btn: Button = null
var _trade_scroll: ScrollContainer = null
var _trade_last_ot_from: int = -1
var _last_steal_serial: int = 0
var _hand_count_hold: Dictionary = {}
var _res_hold: Dictionary = {}
var _scoreboard_mini_hands: Dictionary = {}
var _scoreboard_played: Dictionary = {}
var _steal_timer: SceneTreeTimer = null
var _steal_anim_serial: int = -1
var _steal_anim_turn: int = -1
var _steal_pending_anim: Dictionary = {}
var _blocker_anim_this_update: bool = false
var _last_fly_kind: String = ""
var _steal_flyer: CardFace = null
var _prev_flight_hands: Array = []
var _prev_flight_bank: Dictionary = {}
var _last_flights: Array = []
var _flight_seen_steal_serial: int = -1
var _flight_layer: Control = null
var _dice_show_active: bool = false
var _dice_show_phase: String = ""
var _dice_show_count: int = 0
var _dice_show_node: Control = null
var _dice_total_visible: bool = true
var _dice_show_t := 0.0
var _dice_show_hold := 1.5
var _dice_show_vals := Vector2i(0, 0)
var _dice_show_popped := false
var _dice_show_from: Array[Vector2] = []
var _dice_show_to: Array[Vector2] = []
var _dice_show_slot: Array[Vector2] = []
var _dice_show_spin: Array[float] = []
var _dice_show_apex: Array[float] = []
var _dice_show_face_k: Array[int] = [-1, -1]
var _dice_show_return_len := 0.4
var _dice_show_seat: int = -1
var _dice_show_face_t: Array[float] = [0.0, 0.0]
var _steal_hold_deadline_ms: int = 0
var _steal_delay_cb: Callable = Callable()
var _prev_blocker_tile: int = -1
var _scoreboard_row_panels: Dictionary = {}

# Top bar UI
var _phase_label: Label = null
var _dice_widget: DicePairWidget = null
var _menu_btn: Button = null
var _help_costs_btn: Button = null
var _costs_popup: PanelContainer = null
var _bar_extra_nodes: Array[Control] = []
var _splash_overlay: ColorRect = null
var _splash_title: Label = null
var _splash_banner: ColorRect = null
var _splash_rows: VBoxContainer = null
var _splash_turns: Label = null
var _splash_new_game_btn: Button = null
var _splash_lobby_btn: Button = null
var _splash_view_board_btn: Button = null
var _results_btn: Button = null
var _splash_shown: bool = false
var _menu_popup: PopupMenu = null
var _step_top_btn: Button = null

# Main split
var _board_view: BoardView = null
var _center_split: HSplitContainer = null
var _scoreboard_box: VBoxContainer = null
var _bank_faces: Dictionary = {}
var _bank_deck_face: CardFace = null
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
var _turn_banner_count: int = 0
var _turn_focus_pid: int = -1
var _bot_turn_started_ms: int = 0
var _turn_banner: Control = null
var _turn_banner_swatch: ColorRect = null
var _turn_banner_label: Label = null
var _turn_frame: Panel = null
var _turn_frame_style: StyleBoxFlat = null
var _last_flight_targets: Array = []
var _flight_spawn_serial: int = 0
var _flight_spawn_queue: Array = []
var _flight_spawn_timer: Timer = null
var _device_pass_cover: PanelContainer = null
var _device_pass_label: Label = null
var _device_pass_btn: Button = null

# Action buttons that must not be activated by the Space key
var _no_space_focus_btns: Array = []

# Discard panel
var _discard_mode_box: HBoxContainer = null
var _discard_heading: Label = null
var _discard_confirm_btn: Button = null
var _discard_auto_btn: Button = null
var _discard_minus_btns: Dictionary = {}
var _discard_pick: Dictionary = {}
var _discard_pick_pid: int = -1

# Action buttons
var _buy_card_btn: Button = null
var _cancel_pick_btn: Button = null
var _end_turn_btn: Button = null

# Build card rows: key -> {btn, marker, cost, name}
var _build_bubble: PanelContainer = null
var _build_bubble_title: Label = null
var _build_bubble_cost_box: HBoxContainer = null
var _build_bubble_build_btn: Button = null
var _build_bubble_cancel_btn: Button = null
var _build_pending: Dictionary = {}
var _hint_sig: String = ""

# Trade tray (compact panel in the layout flow, above the bottom bar)
const DEV_CARD_HELP := {
	GameTypes.DevCardType.GUARD: "Move the Blocker and steal 1 card from a founder there. 3 Guards played = Largest Guard (+2 points).",
	GameTypes.DevCardType.ROAD_WORK: "Build up to 2 roads for free.",
	GameTypes.DevCardType.HARVEST_BOUNTY: "Take any 2 resources from the bank.",
	GameTypes.DevCardType.TRADE_DECREE: "Name a resource: every other player gives you all of theirs.",
	GameTypes.DevCardType.CHARTER_POINT: "Worth 1 victory point. Kept secret until you win.",
}

var _trade_tray: PanelContainer = null
var _trade_content: VBoxContainer = null
var _trade_title_lbl: Label = null
var _trade_have_label: Label = null
var _trade_respond_view: VBoxContainer = null
var _trade_respond_row: HBoxContainer = null
var _trade_ro_get_box: HBoxContainer = null
var _trade_ro_give_box: HBoxContainer = null
var _trade_rows_col: VBoxContainer = null
var _trade_give_box: HBoxContainer = null
var _trade_get_faces: Dictionary = {}
var _trade_give_hint_lbl: Label = null
var _trade_btn_row: HBoxContainer = null
var _trade_counter_row: HBoxContainer = null
var _trade_give_counts: Dictionary = {}
var _trade_get_counts: Dictionary = {}
var _trade_ask_btn: Button = null
var _trade_ratio_btn: Button = null
var _trade_resend_btn: Button = null
var _trade_offers_lbl: Label = null
var _trade_clear_btn: Button = null
var _ot_accept_btn: Button = null
var _ot_decline_btn: Button = null
var _ot_counter_btn: Button = null
var _ot_send_btn: Button = null
var _ot_back_btn: Button = null
var _trade_partner_stack: VBoxContainer = null
var _trade_respond_mode: bool = false
var _trade_counter_mode: bool = false
var _trade_reopen_token: String = ""
var _declined_counters: Dictionary = {}
var _counter_cards_shown: bool = false
var _counter_offer_token: String = ""
var _counter_toasted: Dictionary = {}
var _trade_no_takers_lbl: Label = null
var _trade_last_ot_open: bool = false
var _trade_view_pid: int = -1
var _trade_opened_auto: bool = false
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
var _right_panel: PanelContainer = null
var _top_scroll: ScrollContainer = null
var _tray_height_recheck := false
var _log_restore_open: bool = false
var _skip_icon_tex: ImageTexture = null
var _chevron_down_tex: ImageTexture = null
var _chevron_up_tex: ImageTexture = null

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
var _settings_portnames_check: CheckBox = null
var _show_port_names: bool = false
var _hex_style: String = "rich"
var _token_style: String = "classic"
var _settings_hex_opt: OptionButton = null
var _settings_token_opt: OptionButton = null
var _settings_step_btn: Button = null
var _settings_ai_difficulty: int = 2
var _settings_muted: bool = false
var _settings_text_idx: int = 0
var _settings_speed_idx: int = 1
var _reduce_motion: bool = false

static var settings_path: String = "user://settings.cfg"
static var turn_min_seconds_override: float = -1.0
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
	if not _hand_count_hold.is_empty() and _steal_hold_deadline_ms > 0 and Time.get_ticks_msec() > _steal_hold_deadline_ms:
		_finish_steal_anim()
	if not auto_ai or session == null or session.state == null:
		return
	if _any_overlay_visible():
		return
	if session.is_ai_to_act():
		if _bot_must_wait(Time.get_ticks_msec()):
			var acting := session.get_acting_player_id()
			if acting >= 0 and acting < session.seats.size():
				var nxt: Dictionary = BotController.choose_action(session.state, acting, session.seats[acting].get_difficulty())
				if str(nxt.get("type", "")) == "end_turn":
					return
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
	_help_costs_btn = Button.new()
	_help_costs_btn.text = "?"
	_help_costs_btn.tooltip_text = "Build costs"
	_help_costs_btn.custom_minimum_size = Vector2(40, 40)
	_help_costs_btn.add_theme_font_size_override("font_size", 18)
	_style_button(_help_costs_btn, "ghost")
	_help_costs_btn.pressed.connect(_open_costs_popup)
	top_hbox.add_child(_help_costs_btn)
	_results_btn = Button.new()
	_results_btn.text = "Results"
	_results_btn.tooltip_text = "Show the final standings"
	_results_btn.custom_minimum_size = Vector2(70, 40)
	_results_btn.add_theme_font_size_override("font_size", 13)
	_style_button(_results_btn, "ghost")
	_results_btn.visible = false
	_results_btn.pressed.connect(func() -> void:
		if _splash_overlay != null and _splash_shown:
			_splash_overlay.visible = true
	)
	top_hbox.add_child(_results_btn)
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
	_board_view.background_clicked.connect(_on_board_background_clicked)
	left_column.add_child(_board_view)

	_turn_frame_style = StyleBoxFlat.new()
	_turn_frame_style.set_border_width_all(3)
	_turn_frame_style.bg_color = Color(0, 0, 0, 0)
	_turn_frame = Panel.new()
	_turn_frame.add_theme_stylebox_override("panel", _turn_frame_style)
	_turn_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_turn_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_frame.visible = false
	_board_view.add_child(_turn_frame)

	_turn_banner = Control.new()
	_turn_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_turn_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_banner.visible = false
	_board_view.add_child(_turn_banner)
	var tb_center := CenterContainer.new()
	tb_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_banner.add_child(tb_center)
	var tb_panel := PanelContainer.new()
	var tb_style := _paper_panel_style(true)
	tb_style.set_corner_radius_all(10)
	tb_style.set_border_width_all(2)
	tb_panel.add_theme_stylebox_override("panel", tb_style)
	tb_center.add_child(tb_panel)
	var tb_row := HBoxContainer.new()
	tb_row.add_theme_constant_override("separation", 8)
	tb_panel.add_child(tb_row)
	_turn_banner_swatch = ColorRect.new()
	_turn_banner_swatch.custom_minimum_size = Vector2(12, 12)
	_turn_banner_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tb_row.add_child(_turn_banner_swatch)
	_turn_banner_label = Label.new()
	_turn_banner_label.add_theme_font_size_override("font_size", 16)
	_turn_banner_label.add_theme_color_override("font_color", Palette.HEADING)
	tb_row.add_child(_turn_banner_label)

	_build_build_bubble()
	_build_steal_chooser()
	_build_costs_popup()
	_build_toast_layer()

	var right_panel := PanelContainer.new()
	_right_panel = right_panel
	right_panel.custom_minimum_size = Vector2(400, 0)
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
	_top_scroll = top_scroll
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

	# Bank supply section — how many resource cards are still in the bank.
	var bank_title := Label.new()
	bank_title.text = "BANK"
	bank_title.add_theme_font_size_override("font_size", 14)
	bank_title.add_theme_color_override("font_color", Palette.HEADING)
	top_vbox.add_child(bank_title)

	var bank_row := HBoxContainer.new()
	bank_row.add_theme_constant_override("separation", 6)
	top_vbox.add_child(bank_row)
	for r in GameTypes.ALL_RESOURCES:
		var bcol := VBoxContainer.new()
		bcol.add_theme_constant_override("separation", 3)
		bank_row.add_child(bcol)
		var bf := CardFace.new()
		bf.custom_minimum_size = Vector2(42, 42.0 / CardFace.RATIO)
		bf.focusable = false
		bf.count_badge = false
		bf.kind = "resource"
		bf.resource = r
		var res_id := r
		bf.tooltip_text = "%s in the bank" % GameTypes.resource_name(res_id)
		bcol.add_child(bf)
		bf.mouse_filter = Control.MOUSE_FILTER_PASS
		_bank_faces[r] = bf
	var deck_sep := VSeparator.new()
	deck_sep.custom_minimum_size = Vector2(8, 40)
	bank_row.add_child(deck_sep)
	var deck_col := VBoxContainer.new()
	deck_col.add_theme_constant_override("separation", 3)
	bank_row.add_child(deck_col)
	var deck_face := CardFace.new()
	deck_col.add_child(deck_face)
	deck_face.custom_minimum_size = Vector2(42, 42.0 / CardFace.RATIO)
	deck_face.focusable = false
	deck_face.count_badge = false
	deck_face.kind = "back"
	deck_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_face.tooltip_text = "Action Cards left in the deck"
	_bank_deck_face = deck_face
	deck_face.mouse_filter = Control.MOUSE_FILTER_PASS

	# Costs live in the "?" popover next to the menu; building happens on the board.

	_cancel_pick_btn = Button.new()
	_cancel_pick_btn.text = "Cancel Board Selection"
	_cancel_pick_btn.visible = false
	_cancel_pick_btn.tooltip_text = "Cancel the current board selection"
	_style_button(_cancel_pick_btn, "danger")
	_cancel_pick_btn.pressed.connect(_cancel_current_pick)
	_guard_action_button_focus(_cancel_pick_btn)
	top_vbox.add_child(_cancel_pick_btn)

	# Context sub-panels (Maritime, Barter, Bounty, Decree)
	_build_subpanels(top_vbox)

	# Trade panel lives in the sidebar between the bank section and the log,
	# so opening it never shrinks the board.
	_build_trade_tray(right_vbox)

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
	_log_toggle_btn.text = ""
	_log_toggle_btn.toggle_mode = true
	_log_toggle_btn.button_pressed = false
	_log_toggle_btn.tooltip_text = "Show the full log"
	_log_toggle_btn.icon = _chevron_icon(false)
	_log_toggle_btn.custom_minimum_size = Vector2(28, 28)
	_log_toggle_btn.expand_icon = true
	_style_button(_log_toggle_btn, "ghost")
	_log_toggle_btn.add_theme_color_override("icon_modulate", _log_toggle_btn.get_theme_color("font_color"))
	_log_toggle_btn.add_theme_color_override("icon_modulate:disabled", _log_toggle_btn.get_theme_color("font_disabled_color"))
	_log_toggle_btn.toggled.connect(_set_log_open)
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

	# 3. Bottom Visual Card Hand Bar (always visible), with the open-offer strip above it
	_build_offer_strip(root_vbox)
	_build_hand_bar(root_vbox)

	# 4. Modal Overlays (lobby, settings, help — help is topmost)
	_build_lobby_overlay()
	_build_settings_overlay()
	_build_help_overlay()
	_build_splash_overlay()


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
		var face := CardFace.new()
		face.custom_minimum_size = Vector2(62, 62.0 / CardFace.RATIO)
		face.focusable = false
		face.kind = "resource"
		face.resource = r
		face.tooltip_text = "Click to offer in a trade"
		var res_id := r
		face.pressed.connect(func() -> void: _on_resource_card_pressed(res_id))
		face.badge_pressed.connect(func() -> void: _discard_take_back(res_id))
		hb.add_child(face)
		_res_card_refs[r] = face

	_discard_mode_box = HBoxContainer.new()
	_discard_mode_box.add_theme_constant_override("separation", 6)
	_discard_mode_box.visible = false
	hb.add_child(_discard_mode_box)
	_discard_heading = Label.new()
	_discard_heading.add_theme_font_size_override("font_size", 14)
	_discard_heading.add_theme_color_override("font_color", Palette.ACCENT_RED.darkened(0.15))
	_discard_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_discard_heading.custom_minimum_size = Vector2(110, 0)
	_discard_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discard_heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_discard_mode_box.add_child(_discard_heading)
	_discard_confirm_btn = Button.new()
	_discard_confirm_btn.text = "Discard"
	_discard_confirm_btn.custom_minimum_size = Vector2(88, 40)
	_discard_confirm_btn.add_theme_font_size_override("font_size", 14)
	_discard_confirm_btn.tooltip_text = "Discard the picked cards"
	_style_button(_discard_confirm_btn, "danger")
	_discard_confirm_btn.disabled = true
	_discard_confirm_btn.pressed.connect(_on_discard_confirm_pressed)
	_guard_action_button_focus(_discard_confirm_btn)
	_discard_mode_box.add_child(_discard_confirm_btn)
	_discard_auto_btn = Button.new()
	_discard_auto_btn.text = "Pick for me"
	_discard_auto_btn.custom_minimum_size = Vector2(96, 40)
	_discard_auto_btn.add_theme_font_size_override("font_size", 14)
	_discard_auto_btn.tooltip_text = "Fill the selection with a sensible choice"
	_style_button(_discard_auto_btn, "normal")
	_discard_auto_btn.pressed.connect(_on_discard_auto_fill_pressed)
	_guard_action_button_focus(_discard_auto_btn)
	_discard_mode_box.add_child(_discard_auto_btn)

	var div0 := VSeparator.new()
	div0.add_theme_constant_override("separation", 4)
	hb.add_child(div0)
	_bar_extra_nodes.append(div0)

	var div := VSeparator.new()
	div.add_theme_constant_override("separation", 4)
	hb.add_child(div)
	_bar_extra_nodes.append(div)

	var chip_defs := [
		[GameTypes.DevCardType.GUARD, "Guard", Palette.SEA_DEEP],
		[GameTypes.DevCardType.ROAD_WORK, "Road Work", Palette.CLAY_SHADE],
		[GameTypes.DevCardType.HARVEST_BOUNTY, "Bounty", Palette.ACCENT_GOLD],
		[GameTypes.DevCardType.TRADE_DECREE, "Decree", Palette.MOUNTAIN_SHADE],
		[GameTypes.DevCardType.CHARTER_POINT, "Charter", Palette.ACCENT_GREEN],
	]
	for def in chip_defs:
		var ctype: int = int(def[0])
		var chip := CardFace.new()
		chip.custom_minimum_size = Vector2(62, 62.0 / CardFace.RATIO)
		chip.kind = "action"
		chip.action = ctype
		chip.disabled = true
		match ctype:
			GameTypes.DevCardType.GUARD:
				chip.pressed.connect(_on_play_guard_pressed)
			GameTypes.DevCardType.ROAD_WORK:
				chip.pressed.connect(_on_play_road_work_pressed)
			GameTypes.DevCardType.HARVEST_BOUNTY:
				chip.pressed.connect(_on_play_bounty_pressed)
			GameTypes.DevCardType.TRADE_DECREE:
				chip.pressed.connect(_on_play_decree_pressed)
		_guard_action_button_focus(chip)
		hb.add_child(chip)
		_action_chips[ctype] = chip
		_bar_extra_nodes.append(chip)

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
	_bar_extra_nodes.append(_buy_card_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)

	_dice_widget = DicePairWidget.new()
	_dice_widget.tooltip_text = "Last Roll"
	_dice_widget.pressed.connect(_on_roll_pressed)
	hb.add_child(_dice_widget)
	_bar_extra_nodes.append(_dice_widget)

	var dice_gap := Control.new()
	dice_gap.custom_minimum_size = Vector2(6, 0)
	dice_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(dice_gap)
	_bar_extra_nodes.append(dice_gap)

	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_style_button(_end_turn_btn, "normal")
	_end_turn_btn.icon = _skip_icon()
	_end_turn_btn.add_theme_constant_override("icon_spacing", 6)
	_end_turn_btn.custom_minimum_size = Vector2(130, 52)
	_end_turn_btn.add_theme_font_size_override("font_size", 16)
	_end_turn_btn.tooltip_text = "End your turn (E)"
	_end_turn_btn.add_theme_color_override("icon_modulate", _end_turn_btn.get_theme_color("font_color"))
	_end_turn_btn.add_theme_color_override("icon_modulate:disabled", _end_turn_btn.get_theme_color("font_disabled_color"))
	_end_turn_btn.disabled = true
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_guard_action_button_focus(_end_turn_btn)
	hb.add_child(_end_turn_btn)
	_bar_extra_nodes.append(_end_turn_btn)

	_build_device_pass_cover()
	_build_flight_layer()

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
func _build_cost_for(kind: String) -> Dictionary:
	match kind:
		"road":
			return {
				GameTypes.ResourceType.TIMBER: 1,
				GameTypes.ResourceType.CLAY: 1,
			}
		"settlement":
			return {
				GameTypes.ResourceType.TIMBER: 1,
				GameTypes.ResourceType.CLAY: 1,
				GameTypes.ResourceType.FLEECE: 1,
				GameTypes.ResourceType.GRAIN: 1,
			}
		"city":
			return {
				GameTypes.ResourceType.GRAIN: 2,
				GameTypes.ResourceType.IRON: 3,
			}
	return {}

func _build_costs_popup() -> void:
	_costs_popup = PanelContainer.new()
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(9)
	st.set_border_width_all(2)
	st.border_color = Palette.ACCENT_GOLD.darkened(0.15)
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 5
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	_costs_popup.add_theme_stylebox_override("panel", st)
	_costs_popup.visible = false
	add_child(_costs_popup)
	var costs_col := VBoxContainer.new()
	costs_col.add_theme_constant_override("separation", 6)
	_costs_popup.add_child(costs_col)
	for cost_def in [
		["Road", _build_cost_for("road")],
		["Settlement", _build_cost_for("settlement")],
		["City (upgrade)", _build_cost_for("city")],
		["Action Card", {
			GameTypes.ResourceType.FLEECE: 1,
			GameTypes.ResourceType.GRAIN: 1,
			GameTypes.ResourceType.IRON: 1,
		}],
	]:
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 10)
		costs_col.add_child(crow)
		var clbl := Label.new()
		clbl.text = str(cost_def[0])
		clbl.custom_minimum_size = Vector2(110, 0)
		clbl.add_theme_font_size_override("font_size", 14)
		clbl.add_theme_color_override("font_color", Palette.TEXT)
		crow.add_child(clbl)
		var ccost: Dictionary = cost_def[1]
		for r in GameTypes.ALL_RESOURCES:
			var amt: int = int(ccost.get(r, 0))
			if amt > 0:
				crow.add_child(_make_cost_cell(r, amt))
	var dev_head := Label.new()
	dev_head.text = "Action cards"
	dev_head.add_theme_font_size_override("font_size", 15)
	dev_head.add_theme_color_override("font_color", Palette.HEADING)
	costs_col.add_child(dev_head)
	var dev_names := [
		[GameTypes.DevCardType.GUARD, "Guard"],
		[GameTypes.DevCardType.ROAD_WORK, "Road Work"],
		[GameTypes.DevCardType.HARVEST_BOUNTY, "Harvest Bounty"],
		[GameTypes.DevCardType.TRADE_DECREE, "Trade Decree"],
		[GameTypes.DevCardType.CHARTER_POINT, "Charter"],
	]
	for dn in dev_names:
		var drow := HBoxContainer.new()
		drow.add_theme_constant_override("separation", 8)
		costs_col.add_child(drow)
		var dface := CardFace.new()
		dface.kind = "action"
		dface.action = int(dn[0])
		dface.emblem_only = true
		dface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dface.custom_minimum_size = Vector2(26, 26.0 / CardFace.RATIO)
		dface.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drow.add_child(dface)
		var dlbl := Label.new()
		dlbl.text = "%s — %s" % [str(dn[1]), str(DEV_CARD_HELP.get(int(dn[0]), ""))]
		dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dlbl.add_theme_font_size_override("font_size", 12)
		dlbl.add_theme_color_override("font_color", Palette.TEXT)
		dlbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drow.add_child(dlbl)
	var cost_hint := Label.new()
	cost_hint.text = "Click a glowing spot on the board to build."
	cost_hint.add_theme_font_size_override("font_size", 12)
	cost_hint.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	costs_col.add_child(cost_hint)
	var cost_help_btn := Button.new()
	cost_help_btn.text = "Full help (F1)"
	cost_help_btn.add_theme_font_size_override("font_size", 13)
	_style_button(cost_help_btn, "normal")
	cost_help_btn.pressed.connect(func() -> void:
		_costs_popup.visible = false
		_show_overlay("help")
	)
	costs_col.add_child(cost_help_btn)

func _open_costs_popup() -> void:
	_cancel_build_bubble()
	if _costs_popup.visible:
		_costs_popup.visible = false
		return
	_costs_popup.reset_size()
	var pos := _help_costs_btn.global_position + Vector2(0.0, _help_costs_btn.size.y + 4.0)
	var br := get_global_rect()
	var psize := _costs_popup.get_combined_minimum_size()
	pos.x = clampf(pos.x, br.position.x + 2, maxf(br.position.x + 2, br.end.x - psize.x - 2))
	pos.y = clampf(pos.y, br.position.y + 2, maxf(br.position.y + 2, br.end.y - psize.y - 2))
	_costs_popup.position = pos
	_costs_popup.visible = true

func _close_costs_popup() -> void:
	if _costs_popup != null:
		_costs_popup.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _costs_popup != null and _costs_popup.visible:
			var lp := _costs_popup.get_global_rect()
			var gp := get_global_mouse_position()
			if not lp.has_point(gp):
				_close_costs_popup()

func _open_menu_popup() -> void:
	_cancel_build_bubble()
	_close_costs_popup()
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
	return _lobby_overlay.visible or _settings_overlay.visible or _help_overlay.visible or (_splash_overlay != null and _splash_overlay.visible)

func _show_overlay(which: String) -> void:
	_cancel_build_bubble()
	_close_costs_popup()
	_lobby_overlay.visible = which == "lobby"
	_settings_overlay.visible = which == "settings"
	_help_overlay.visible = which == "help"

func _close_overlays() -> void:
	_show_overlay("none")

func _build_splash_overlay() -> void:
	_splash_overlay = ColorRect.new()
	_splash_overlay.z_index = 2
	_splash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash_overlay.color = Color(0.12, 0.09, 0.06, 0.62)
	_splash_overlay.visible = false
	add_child(_splash_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash_overlay.add_child(center)
	var panel := PanelContainer.new()
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(12)
	st.set_border_width_all(3)
	st.border_color = Palette.ACCENT_GOLD.darkened(0.1)
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 10
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_splash_banner = ColorRect.new()
	_splash_banner.custom_minimum_size = Vector2(360, 10)
	_splash_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_splash_banner)
	_splash_title = Label.new()
	_splash_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash_title.add_theme_font_size_override("font_size", 26)
	_splash_title.add_theme_color_override("font_color", Palette.HEADING)
	col.add_child(_splash_title)
	_splash_turns = Label.new()
	_splash_turns.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash_turns.add_theme_font_size_override("font_size", 13)
	_splash_turns.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	col.add_child(_splash_turns)
	_splash_rows = VBoxContainer.new()
	_splash_rows.add_theme_constant_override("separation", 4)
	col.add_child(_splash_rows)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btn_row)
	_splash_new_game_btn = Button.new()
	_splash_new_game_btn.text = "▶ New Game"
	_splash_new_game_btn.custom_minimum_size = Vector2(120, 40)
	_style_button(_splash_new_game_btn, "primary")
	_splash_new_game_btn.pressed.connect(func() -> void:
		_splash_overlay.visible = false
		_results_btn.visible = false
		_start_match_from_lobby_settings()
	)
	btn_row.add_child(_splash_new_game_btn)
	_splash_lobby_btn = Button.new()
	_splash_lobby_btn.text = "Back to Lobby"
	_splash_lobby_btn.custom_minimum_size = Vector2(120, 40)
	_style_button(_splash_lobby_btn, "ghost")
	_splash_lobby_btn.pressed.connect(_show_lobby)
	btn_row.add_child(_splash_lobby_btn)
	_splash_view_board_btn = Button.new()
	_splash_view_board_btn.text = "View Board"
	_splash_view_board_btn.tooltip_text = "Hide the results and look at the board"
	_splash_view_board_btn.custom_minimum_size = Vector2(120, 40)
	_style_button(_splash_view_board_btn, "ghost")
	_splash_view_board_btn.pressed.connect(func() -> void:
		_splash_overlay.visible = false
		_results_btn.visible = true
	)
	btn_row.add_child(_splash_view_board_btn)

func _show_splash(state: GameState) -> void:
	_splash_shown = true
	_finish_steal_anim()
	_reset_flight_state()
	var standings: Array = state.get_standings()
	var winner_pid: int = int(state.winner)
	var ordered: Array = []
	if winner_pid >= 0 and winner_pid < standings.size():
		for row0 in standings:
			if int(row0["pid"]) == winner_pid:
				ordered.append(row0)
	for row0 in standings:
		if not ordered.has(row0):
			ordered.append(row0)
	if ordered.is_empty():
		winner_pid = -1
	_splash_title.add_theme_color_override("font_color", Palette.HEADING)
	if _splash_banner != null:
		_splash_banner.color = GameTypes.PLAYER_COLORS[winner_pid].darkened(0.15) if winner_pid >= 0 else Palette.TEXT_MUTED
	_splash_title.text = "%s wins!" % (str(ordered[0]["name"]) if not ordered.is_empty() else "Nobody")
	_splash_turns.text = "Played %d turns" % state.turn_number
	for c in _splash_rows.get_children():
		c.queue_free()
	var ranks := ["1st", "2nd", "3rd", "4th"]
	for i in range(ordered.size()):
		var row: Dictionary = ordered[i]
		var pid: int = int(row["pid"])
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		_splash_rows.add_child(hbox)
		var rank_lbl := Label.new()
		rank_lbl.text = ranks[i] if i < ranks.size() else "%d." % (i + 1)
		rank_lbl.custom_minimum_size = Vector2(36, 0)
		rank_lbl.add_theme_font_size_override("font_size", 14)
		rank_lbl.add_theme_color_override("font_color", Palette.HEADING)
		hbox.add_child(rank_lbl)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(10, 22)
		sw.color = GameTypes.PLAYER_COLORS[pid]
		hbox.add_child(sw)
		var seat_kind := "AI"
		if pid < session.seats.size() and not session.seats[pid].is_ai():
			seat_kind = "Human"
		var name_lbl := Label.new()
		name_lbl.text = "%s (%s)" % [str(row["name"]), seat_kind]
		name_lbl.custom_minimum_size = Vector2(150, 0)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT)
		hbox.add_child(name_lbl)
		var vp_lbl := Label.new()
		vp_lbl.text = "%d VP" % int(row["vp"])
		vp_lbl.custom_minimum_size = Vector2(56, 0)
		vp_lbl.add_theme_font_size_override("font_size", 14)
		vp_lbl.add_theme_color_override("font_color", Palette.HEADING)
		hbox.add_child(vp_lbl)
		var s_n := int(row["settlements"])
		var c_n := int(row["cities"])
		var city_word := "city" if c_n == 1 else "cities"
		var detail := "%d settlement%s · %d %s" % [s_n, "" if s_n == 1 else "s", c_n, city_word]
		if bool(row["longest_route"]):
			detail += " | Longest Route"
		if bool(row["largest_guard"]):
			detail += " | Largest Guard"
		var ch_n := int(row["charters"])
		if ch_n > 0:
			detail += " | %d Charter point%s" % [ch_n, "" if ch_n == 1 else "s"]
		var detail_lbl := Label.new()
		detail_lbl.text = detail
		detail_lbl.add_theme_font_size_override("font_size", 12)
		detail_lbl.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		hbox.add_child(detail_lbl)
	_splash_overlay.visible = true
	_results_btn.visible = false
	_splash_new_game_btn.grab_focus()

func _show_lobby() -> void:
	_finish_steal_anim()
	_reset_flight_state()
	for i in range(_seat_type_opts.size()):
		var sel_type: int = 0 if i == 0 else _settings_ai_difficulty
		_seat_type_opts[i].select(_seat_type_opts[i].get_item_index(sel_type))
	_update_lobby_seat_rows()
	_lobby_cancel_btn.visible = session != null and session.state != null
	if _splash_overlay != null:
		_splash_overlay.visible = false
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
	_settings_overlay.z_index = 2
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

	_settings_portnames_check = CheckBox.new()
	_settings_portnames_check.text = "Show port names"
	_settings_portnames_check.tooltip_text = "Keep the '2:1 Fleece' text labels on the ports visible"
	_style_check(_settings_portnames_check)
	_settings_portnames_check.toggled.connect(func(on: bool) -> void:
		_show_port_names = on
		if _board_view != null:
			_board_view.show_port_names = on
			_board_view.queue_redraw()
		_save_settings()
	)
	_add_settings_row(vbox, "Ports:", "Show the text name of each port", _settings_portnames_check)

	_settings_hex_opt = OptionButton.new()
	var hex_labels: Array[String] = ["Rich landscape", "Classic"]
	for i in range(BoardView.HEX_STYLES.size()):
		_settings_hex_opt.add_item(hex_labels[i], i)
	_settings_hex_opt.custom_minimum_size = Vector2(150, 36)
	_settings_hex_opt.tooltip_text = "Concept look for the resource hex tiles"
	_style_option(_settings_hex_opt)
	_settings_hex_opt.item_selected.connect(func(idx: int) -> void:
		_hex_style = BoardView.HEX_STYLES[idx]
		if _board_view != null:
			_board_view.hex_style = _hex_style
		_save_settings()
	)
	_add_settings_row(vbox, "Hex style:", "Try a concept look for the hexes", _settings_hex_opt)

	_settings_token_opt = OptionButton.new()
	var token_labels: Array[String] = ["Classic", "Bold", "Scale with odds"]
	for i in range(BoardView.TOKEN_STYLES.size()):
		_settings_token_opt.add_item(token_labels[i], i)
	_settings_token_opt.custom_minimum_size = Vector2(150, 36)
	_settings_token_opt.tooltip_text = "Concept look for the number tokens"
	_style_option(_settings_token_opt)
	_settings_token_opt.item_selected.connect(func(idx: int) -> void:
		_token_style = BoardView.TOKEN_STYLES[idx]
		if _board_view != null:
			_board_view.token_style = _token_style
		_save_settings()
	)
	_add_settings_row(vbox, "Number tokens:", "Try a concept look for the chips", _settings_token_opt)

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
	_help_overlay.z_index = 2
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
		"On your turn click a resource card (or press T) to open the trade tray. Click cards to fill 'You give', pick cards for 'You get', then 'Ask players' posts your offer (max 3 per turn). Each player accepts, declines or counters; press Trade on an accepting player's card to complete.",
		"Closing the tray, pressing Esc or End Turn withdraws your own offer. Edit the rows while it is open and press 'Send new offer' to replace it in one click. The Bank/Port button swaps the chosen card: 4:1 by default, 3:1 with a 3:1 port, 2:1 for that port's own resource.",
		"When another player posts an offer your tray opens with Accept, Decline or Counter; Esc only hides it — click a card again to reopen it.",
		"",
		"[b][color=#1f5a52]The Blocker[/color][/b]",
		"When a 7 is rolled, every player holding more than 7 cards discards half of them. The roller then moves the Blocker to a new tile and steals a card from a player building there. A Guard card moves the Blocker without rolling.",
		"",
		"[b][color=#1f5a52]Action cards[/color][/b]",
		"Guard — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.GUARD, "")),
		"Road Work — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.ROAD_WORK, "")),
		"Harvest Bounty — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.HARVEST_BOUNTY, "")),
		"Trade Decree — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.TRADE_DECREE, "")),
		"Charter — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.CHARTER_POINT, "")),
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
		elif _costs_popup != null and _costs_popup.visible:
			_close_costs_popup()
		elif _steal_chooser != null and _steal_chooser.visible:
			_cancel_steal_chooser()
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

	if _steal_chooser != null and _steal_chooser.visible:
		if k.keycode >= KEY_1 and k.keycode <= KEY_9:
			var idx: int = k.keycode - KEY_1
			if idx < _steal_victims.size():
				_on_steal_victim_pressed(idx)
				get_viewport().set_input_as_handled()
		return

	if _discard_mode_active():
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			if not _discard_confirm_btn.disabled:
				_on_discard_confirm_pressed()
				get_viewport().set_input_as_handled()
				return
			return
		var slot := -1
		match k.keycode:
			KEY_1, KEY_KP_1: slot = 0
			KEY_2, KEY_KP_2: slot = 1
			KEY_3, KEY_KP_3: slot = 2
			KEY_4, KEY_KP_4: slot = 3
			KEY_5, KEY_KP_5: slot = 4
		if slot != -1:
			var slot_res: int = GameTypes.ALL_RESOURCES[slot]
			if k.shift_pressed or k.alt_pressed:
				_discard_take_back(slot_res)
			else:
				_discard_pick_one(slot_res)
			get_viewport().set_input_as_handled()
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
	_show_port_names = bool(cfg.get_value("settings", "port_names", false))
	_hex_style = str(cfg.get_value("settings", "hex_style", "rich"))
	_token_style = str(cfg.get_value("settings", "token_style", "classic"))
	if not BoardView.HEX_STYLES.has(_hex_style):
		_hex_style = "rich"
	if not BoardView.TOKEN_STYLES.has(_token_style):
		_token_style = "classic"

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "ai_difficulty", _settings_ai_difficulty)
	cfg.set_value("settings", "muted", _settings_muted)
	cfg.set_value("settings", "text_size", _settings_text_idx)
	cfg.set_value("settings", "bot_speed", _settings_speed_idx)
	cfg.set_value("settings", "reduce_motion", _reduce_motion)
	cfg.set_value("settings", "auto_ai", auto_ai)
	cfg.set_value("settings", "port_names", _show_port_names)
	cfg.set_value("settings", "hex_style", _hex_style)
	cfg.set_value("settings", "token_style", _token_style)
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
		_board_view.show_port_names = _show_port_names
		_board_view.hex_style = _hex_style
		_board_view.token_style = _token_style
		_board_view.anim_scale = 0.45 if _settings_speed_idx >= 2 else 1.0
	_settings_diff_opt.select(_settings_diff_opt.get_item_index(_settings_ai_difficulty))
	_settings_text_opt.select(_settings_text_idx)
	_settings_speed_opt.select(_settings_speed_idx)
	_settings_mute_check.button_pressed = _settings_muted
	_settings_motion_check.button_pressed = _reduce_motion
	_settings_portnames_check.button_pressed = _show_port_names
	var hidx := BoardView.HEX_STYLES.find(_hex_style)
	if hidx >= 0:
		_settings_hex_opt.select(hidx)
	var tidx := BoardView.TOKEN_STYLES.find(_token_style)
	if tidx >= 0:
		_settings_token_opt.select(tidx)
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
	_set_trade_hint(false)
	_reset_trade_counts()
	_last_seen_dice = Vector2i.ZERO
	_prev_dash_hand = {}
	_prev_dash_pid = -1
	_revealed_pid = -1
	_prev_view_pid = -1
	_sfx_prev_current = -1
	_sfx_won = false
	_last_steal_serial = 0
	_finish_steal_anim()
	_reset_flight_state()
	_splash_shown = false
	session.start_match(seed_val, configs, _balanced_check.button_pressed)

func _build_toast_layer() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.offset_top = 44
	add_child(center)
	_toast_layer = VBoxContainer.new()
	_toast_layer.add_theme_constant_override("separation", 4)
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_toast_layer)

func _show_turn_banner(state: GameState) -> void:
	if _turn_banner == null or _turn_banner_label == null:
		return
	var pid := state.current_player
	if pid < 0 or pid >= state.players.size():
		return
	_turn_banner_swatch.color = GameTypes.PLAYER_COLORS[pid % GameTypes.PLAYER_COLORS.size()]
	_turn_banner_label.text = "Your turn" if pid == _view_pid() else "%s's turn" % str(state.players[pid]["name"])
	_turn_banner.visible = true
	_turn_banner.modulate.a = 1.0
	if _reduce_motion:
		_turn_banner.position.y = 10.0
		var tw_s := _turn_banner.create_tween()
		tw_s.tween_interval(1.2)
		tw_s.tween_callback(func() -> void:
			if _turn_banner != null and is_instance_valid(_turn_banner):
				_turn_banner.visible = false
		)
	else:
		_turn_banner.position = Vector2(0.0, -48.0)
		var tw := _turn_banner.create_tween()
		tw.tween_property(_turn_banner, "position:y", 10.0, 0.18).set_trans(Tween.TRANS_CUBIC)
		tw.tween_interval(1.2)
		tw.tween_property(_turn_banner, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func() -> void:
			if _turn_banner != null and is_instance_valid(_turn_banner):
				_turn_banner.visible = false
		)

func _set_board_turn_frame(pid: int) -> void:
	if _turn_frame == null or _turn_frame_style == null:
		return
	if pid < 0:
		_turn_frame.visible = false
		return
	_turn_frame_style.border_color = GameTypes.PLAYER_COLORS[pid % GameTypes.PLAYER_COLORS.size()]
	_turn_frame.visible = true

func _bot_must_wait(now_ms: int) -> bool:
	var min_s: float = turn_min_seconds_override
	if min_s < 0.0:
		min_s = 1.0 if _settings_speed_idx >= BOT_SPEED_VALUES.size() - 1 else 2.0
	if min_s <= 0.001:
		return false
	if not auto_ai:
		return false
	if session == null or session.state == null:
		return false
	var st: GameState = session.state
	if st.phase != GameTypes.TurnPhase.TURN_ROLL and st.phase != GameTypes.TurnPhase.TURN_MAIN:
		return false
	if not st.open_trade.is_empty() or not st.pending_discards.is_empty():
		return false
	if st.current_player < 0 or st.current_player >= session.seats.size():
		return false
	if not session.seats[st.current_player].is_ai():
		return false
	if _bot_turn_started_ms <= 0:
		return false
	return float(now_ms - _bot_turn_started_ms) < min_s * 1000.0

func _show_toast(text: String, colour: Color, seconds: float = 3.0) -> void:
	if _toast_layer == null:
		return
	var panel := PanelContainer.new()
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(8)
	st.set_border_width_all(2)
	st.border_color = colour.darkened(0.15)
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 4
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", st)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	_toast_layer.add_child(panel)
	_toast_labels.append(label)
	while _toast_layer.get_child_count() > 3:
		var oldest := _toast_layer.get_child(0)
		if oldest == panel:
			break
		_toast_layer.remove_child(oldest)
		if oldest.get_child_count() > 0:
			_toast_labels.erase(oldest.get_child(0))
		oldest.queue_free()
	var tw := panel.create_tween()
	tw.tween_interval(maxf(0.5, seconds))
	tw.tween_property(panel, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void:
		if is_instance_valid(label):
			_toast_labels.erase(label)
		if is_instance_valid(panel):
			panel.queue_free()
	)

func _announce_steal(state: GameState) -> void:
	if session == null or state == null:
		return
	var serial := int(state.last_steal.get("serial", 0))
	if serial <= _last_steal_serial:
		return
	_last_steal_serial = serial
	var thief := int(state.last_steal.get("thief", -1))
	var victim := int(state.last_steal.get("victim", -1))
	if thief < 0 or victim < 0 or thief >= state.players.size() or victim >= state.players.size():
		return
	var thief_name := str(state.players[thief].get("name", GameTypes.PLAYER_NAMES[thief]))
	var victim_name := str(state.players[victim].get("name", GameTypes.PLAYER_NAMES[victim]))
	var v := _view_pid()
	if thief == victim:
		return
	if victim == v:
		var private := _human_seat_count() <= 1 or not _hand_hidden()
		if private:
			var res := int(state.last_steal.get("res", -1))
			_show_toast("%s stole 1 %s from you!" % [thief_name, GameTypes.resource_name(res)], Color(0.55, 0.18, 0.14), 3.5)
		else:
			_show_toast("%s stole a card from you!" % thief_name, Color(0.55, 0.18, 0.14), 3.5)
		if _sfx != null:
			_sfx.play("seven")
	elif thief == v:
		if _human_seat_count() <= 1:
			var res2 := int(state.last_steal.get("res", -1))
			_show_toast("You stole 1 %s from %s." % [GameTypes.resource_name(res2), victim_name], Color(0.18, 0.42, 0.2), 3.5)
		else:
			_show_toast("You stole a card from %s." % victim_name, Color(0.18, 0.42, 0.2), 3.5)
	else:
		_show_toast("%s stole a card from %s." % [thief_name, victim_name], Palette.ACCENT_GOLD.darkened(0.25))
	_start_steal_anim(victim, thief, int(state.last_steal.get("res", -1)), state)

func _on_state_updated(state: GameState, events: Array[String]) -> void:
	if _steal_anim_turn >= 0 and state.turn_number != _steal_anim_turn:
		_finish_steal_anim()
	if _dice_show_active and _dice_show_seat >= 0 and state.current_player != _dice_show_seat:
		_cut_dice_show_hold()
	_board_view.set_state(state)
	var rolled_now := false
	var built_now := false
	var traded_now := false
	for ev in events:
		_append_log(ev)
		if ev.contains("Match started with"):
			var first_name := str(state.players[state.start_player]["name"])
			_append_log("%s goes first." % first_name)
			_show_toast("%s goes first." % first_name, GameTypes.PLAYER_COLORS[state.start_player])
		if ev.contains("traded "):
			traded_now = true
			_board_view.spawn_trade_toast(ev)
			if ev.contains(" to ") and ev.contains(" for "):
				var a := str(ev.split(" traded ")[0])
				var b := str(ev.split(" to ")[1].split(" for ")[0])
				_show_toast("%s traded with %s." % [a, b], Palette.ACCENT_GOLD.darkened(0.25))
		elif ev.ends_with("withdrew the offer."):
			_show_toast(str(ev.split(" withdrew")[0]) + " withdrew the offer.", Color(0.45, 0.35, 0.2))
		if ev.contains("rolled "):
			rolled_now = true
		if ev.contains(" built a ") or ev.contains("upgraded "):
			built_now = true

	if rolled_now and state.last_dice.x > 0 and state.last_dice.y > 0:
		_roll_fx_count += 1
		_start_dice_roll_fx(state)
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

	if state.phase == GameTypes.TurnPhase.GAME_OVER:
		_turn_focus_pid = -1
		_bot_turn_started_ms = 0
		_set_board_turn_frame(-1)
	elif state.phase >= GameTypes.TurnPhase.TURN_ROLL and state.current_player != _turn_focus_pid:
		_turn_focus_pid = state.current_player
		_turn_banner_count += 1
		var now_ai := state.current_player < session.seats.size() and session.seats[state.current_player].is_ai()
		_bot_turn_started_ms = Time.get_ticks_msec() if now_ai else 0
		_show_turn_banner(state)
		_set_board_turn_frame(state.current_player)
	_animate_from_events(events, state)
	_announce_steal(state)
	if state.phase == GameTypes.TurnPhase.GAME_OVER and not _splash_shown:
		_show_splash(state)
	_prev_blocker_tile = state.blocker_tile
	_refresh_ui()
	_compute_flights(state)

func _animate_from_events(events: Array[String], state: GameState) -> void:
	_blocker_anim_this_update = false
	if _board_view == null or session == null:
		return
	for ev in events:
		var pid := _event_actor_pid(ev, state)
		var col: Color = GameTypes.PLAYER_COLORS[pid] if pid >= 0 and pid < GameTypes.PLAYER_COLORS.size() else Palette.ACCENT_GOLD
		if ev.contains(" at vertex "):
			var v := _event_int(ev, "vertex ")
			if v >= 0:
				_board_view.animate_build_vertex(v, col)
		elif ev.contains(" to a City"):
			var v2 := _event_int(ev, "vertex ")
			if v2 >= 0:
				_board_view.animate_build_vertex(v2, col)
		elif ev.contains(" on edge "):
			var e := _event_int(ev, "edge ")
			if e >= 0:
				_board_view.animate_build_edge(e, col)
		elif ev.contains("moved the Blocker to tile "):
			var t := _event_int(ev, "tile ")
			if t >= 0 and _prev_blocker_tile >= 0:
				_board_view.animate_blocker(_prev_blocker_tile)
				_blocker_anim_this_update = _board_view.blocker_anim_phase() != ""
		if pid >= 0 and pid < session.seats.size() and session.seats[pid].is_ai():
			_maybe_bot_toast(ev, pid, state)

func _event_actor_pid(ev: String, state: GameState) -> int:
	for p_id in range(state.players.size()):
		var nm := str(state.players[p_id].get("name", ""))
		if nm != "" and ev.begins_with(nm + " "):
			return p_id
	return -1

func _event_int(ev: String, marker: String) -> int:
	var idx := ev.find(marker)
	if idx == -1:
		return -1
	var rest := ev.substr(idx + marker.length())
	var digits := ""
	for ch in rest:
		if ch >= "0" and ch <= "9":
			digits += ch
		else:
			break
	return digits.to_int() if digits != "" else -1

func _maybe_bot_toast(ev: String, pid: int, state: GameState) -> void:
	if ev.contains("stole") or ev.contains("withdrew") or (ev.contains("traded ") and ev.contains(" to ")):
		return
	var nm := str(state.players[pid].get("name", GameTypes.PLAYER_NAMES[pid]))
	var col: Color = GameTypes.PLAYER_COLORS[pid]
	var t := ""
	if ev.contains("built a settlement at vertex"):
		t = nm + " built a settlement"
	elif ev.contains("placed a starting settlement"):
		t = nm + " claimed a starting settlement"
	elif ev.contains(" to a City"):
		t = nm + " upgraded to a City"
	elif ev.contains("placed a starting road"):
		t = nm + " built a road"
	elif ev.contains("road on edge"):
		t = nm + (" built a free road" if ev.contains("free road") else " built a road")
	elif ev.contains("bought an Action Card"):
		t = nm + " bought an Action Card"
	elif ev.contains("played a Guard"):
		t = nm + " played a Guard"
	elif ev.contains("played Road Work"):
		t = nm + " played Road Work"
	elif ev.contains("played Harvest Bounty"):
		t = nm + " played Harvest Bounty"
	elif ev.contains("played Trade Decree"):
		t = nm + " played Trade Decree"
	elif ev.contains("moved the Blocker"):
		t = nm + " moved the Blocker"
	elif ev.contains(":1)") and ev.contains(" for 1 "):
		t = nm + " traded with the bank"
	if t != "":
		_show_toast(t, col.darkened(0.2), 2.0)

func _fly_anchor(pid: int) -> Vector2:
	if pid == _view_pid() and _hand_bar_panel != null and _hand_bar_panel.visible:
		return _hand_bar_panel.get_global_rect().get_center()
	var raw: Variant = _scoreboard_row_panels.get(pid, null)
	if raw is Control and is_instance_valid(raw) and (raw as Control).visible and (raw as Control).is_inside_tree():
		return (raw as Control).get_global_rect().get_center()
	return Vector2.INF

func _to_ui_local(global_pos: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_pos

func _displayed_hand_count(pid: int) -> int:
	if session == null or session.state == null or pid < 0 or pid >= session.state.players.size():
		return 0
	var real: int = GameTypes.hand_total(session.state.players[pid].get("hand", {}))
	return maxi(0, real + int(_hand_count_hold.get(pid, 0)))

func _finish_steal_anim() -> void:
	if _steal_timer != null:
		if _steal_delay_cb.is_valid() and _steal_timer.timeout.is_connected(_steal_delay_cb):
			_steal_timer.timeout.disconnect(_steal_delay_cb)
		_steal_timer = null
	_steal_delay_cb = Callable()
	_steal_anim_serial = -1
	_steal_anim_turn = -1
	_steal_pending_anim = {}
	_steal_hold_deadline_ms = 0
	if is_instance_valid(_steal_flyer):
		_steal_flyer.queue_free()
	_steal_flyer = null
	if _hand_count_hold.is_empty() and _res_hold.is_empty():
		return
	_hand_count_hold.clear()
	_res_hold.clear()
	_refresh_ui()

func _start_steal_anim(victim: int, thief: int, res: int, state: GameState) -> void:
	_finish_steal_anim()
	if _reduce_motion or _board_view == null or victim < 0 or thief < 0:
		return
	_steal_anim_serial = _last_steal_serial
	_steal_anim_turn = state.turn_number
	_hand_count_hold[thief] = int(_hand_count_hold.get(thief, 0)) - 1
	_hand_count_hold[victim] = int(_hand_count_hold.get(victim, 0)) + 1
	if victim == _view_pid() and res >= 0 and not _hand_hidden():
		_res_hold[res] = 1
	elif thief == _view_pid() and res >= 0 and not _hand_hidden() and _human_seat_count() <= 1:
		_res_hold[res] = -1
	_refresh_ui()
	_steal_pending_anim = {"victim": victim, "thief": thief, "res": res}
	_steal_hold_deadline_ms = Time.get_ticks_msec() + int((_board_view.blocker_anim_duration() + 0.7 + 1.0) * 1000.0)
	var delay_serial := _steal_anim_serial
	var dur := _board_view.blocker_anim_duration()
	if _blocker_anim_this_update and dur > 0.0:
		_steal_timer = get_tree().create_timer(dur)
		_steal_delay_cb = _on_steal_delay_done.bind(delay_serial)
		_steal_timer.timeout.connect(_steal_delay_cb)
		return
	_launch_steal_flight(delay_serial)

func _on_steal_delay_done(serial: int) -> void:
	if serial != _steal_anim_serial or _steal_pending_anim.is_empty():
		return
	_steal_timer = null
	_launch_steal_flight(serial)

func _launch_steal_flight(serial: int) -> void:
	var data: Dictionary = _steal_pending_anim
	_steal_pending_anim = {}
	if data.is_empty() or serial != _steal_anim_serial:
		return
	var victim := int(data["victim"])
	var thief := int(data["thief"])
	var res := int(data["res"])
	if _hand_count_hold.has(victim):
		_hand_count_hold.erase(victim)
	if int(_res_hold.get(res, 0)) > 0:
		_res_hold.erase(res)
	_refresh_ui()
	var v := _view_pid()
	var single_human := _human_seat_count() <= 1
	var show_face := res >= 0 and not _hand_hidden() and (
		victim == v or (thief == v and single_human)
	)
	var from := Vector2.INF
	if victim == v and res >= 0 and not _hand_hidden():
		var vface: CardFace = _res_card_refs.get(res, null)
		if vface != null and vface.visible:
			from = _to_ui_local(vface.get_global_rect().get_center())
	if from == Vector2.INF:
		var a_from := _fly_anchor(victim)
		if a_from != Vector2.INF:
			from = _to_ui_local(a_from)
	var to := Vector2.INF
	if thief == v and res >= 0 and not _hand_hidden():
		var tface: CardFace = _res_card_refs.get(res, null)
		if tface != null and tface.visible:
			to = _to_ui_local(tface.get_global_rect().get_center())
	if to == Vector2.INF:
		var raw_stack: Variant = _scoreboard_mini_hands.get(thief, null)
		if raw_stack is MiniHandStack and is_instance_valid(raw_stack) and (raw_stack as Control).is_inside_tree():
			to = _to_ui_local((raw_stack as Control).get_global_rect().get_center())
	if from == Vector2.INF or to == Vector2.INF:
		_finish_steal_anim()
		return
	_spawn_steal_flyer(from, to, res if show_face else -1, thief, serial)

func _spawn_steal_flyer(from: Vector2, to: Vector2, res_id: int, thief_pid: int, serial: int) -> void:
	_last_fly_kind = "resource" if res_id >= 0 else "back"
	_steal_flyer = _spawn_card_flyer(from, to, res_id, 0.0, func() -> void: _on_steal_card_landed(thief_pid, serial), 44.0)


func _spawn_card_flyer(from: Vector2, to: Vector2, res_id: int, delay: float, on_landed: Callable, px := 44.0, outline_col := Color(0, 0, 0, 0), to_live: Callable = Callable()) -> CardFace:
	var f := CardFace.new()
	f.focusable = false
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if res_id >= 0:
		f.kind = "resource"
		f.resource = res_id
	else:
		f.kind = "back"
	f.custom_minimum_size = Vector2(px, px / CardFace.RATIO)
	var layer: Node = _flight_layer if _flight_layer != null and is_instance_valid(_flight_layer) else self
	layer.add_child(f)
	f.size = Vector2(px, px / CardFace.RATIO)
	f.pivot_offset = f.size * 0.5
	f.position = from - f.size * 0.5
	var o: Panel = null
	if outline_col.a > 0.0:
		var ost := StyleBoxFlat.new()
		ost.set_border_width_all(2)
		ost.border_color = outline_col
		ost.bg_color = Color(0, 0, 0, 0)
		o = Panel.new()
		o.add_theme_stylebox_override("panel", ost)
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		o.z_index = 2
		layer.add_child(o)
		o.size = f.size
		o.pivot_offset = f.size * 0.5
		o.position = f.position
	var dur := 0.7 * (0.45 if _settings_speed_idx >= 2 else 1.0)
	var arc_h := 46.0
	var tw := f.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(f):
			return
		var to_now := to
		if to_live.is_valid():
			var live: Vector2 = to_live.call()
			if live != Vector2.INF:
				to_now = live
		var p := from.lerp(to_now, ease(t, 1.2))
		p.y -= sin(t * PI) * arc_h
		f.position = p - f.size * 0.5
		if o != null and is_instance_valid(o):
			o.position = f.position
	, 0.0, 1.0, dur)
	tw.tween_property(f, "scale", Vector2(0.4, 0.4), 0.18)
	if o != null:
		tw.parallel().tween_property(o, "scale", Vector2(0.4, 0.4), 0.18)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 0.18)
	if o != null:
		tw.parallel().tween_property(o, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if is_instance_valid(f):
			f.queue_free()
		if o != null and is_instance_valid(o):
			o.queue_free()
		if on_landed.is_valid():
			on_landed.call()
	)
	return f


func _build_flight_layer() -> void:
	_flight_layer = Control.new()
	_flight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flight_layer.z_index = 1
	add_child(_flight_layer)


func _reset_flight_state() -> void:
	_flight_spawn_serial += 1
	_flight_spawn_queue = []
	_last_flight_targets = []
	_turn_focus_pid = -1
	_bot_turn_started_ms = 0
	if _turn_banner != null and is_instance_valid(_turn_banner):
		_turn_banner.visible = false
	_set_board_turn_frame(-1)
	_finish_dice_show()
	_prev_flight_hands = []
	_prev_flight_bank = {}
	_flight_seen_steal_serial = -1
	_last_flights = []
	if _flight_layer != null and is_instance_valid(_flight_layer):
		for c in _flight_layer.get_children():
			c.queue_free()


func _store_flight_state(state: GameState) -> void:
	_prev_flight_hands = []
	for p in state.players:
		_prev_flight_hands.append((p.get("hand", {}) as Dictionary).duplicate())
	_prev_flight_bank = (state.bank as Dictionary).duplicate()


func _flight_anchor(pid: int, res: int) -> Vector2:
	if pid == -1:
		var bf: CardFace = _bank_faces.get(res, null)
		if bf == null or not is_instance_valid(bf) or not bf.is_inside_tree():
			return Vector2.INF
		var g := bf.get_global_transform()
		return _to_ui_local(g * Vector2(bf.size.x * 0.5, minf(bf.size.y, bf.size.x / CardFace.RATIO) * 0.5))
	if pid == _view_pid() and not _hand_hidden():
		var face: CardFace = _res_card_refs.get(res, null)
		if face != null and is_instance_valid(face) and face.visible and face.is_inside_tree():
			return _to_ui_local(face.get_global_rect().get_center())
	var raw: Variant = _scoreboard_mini_hands.get(pid, null)
	if raw is MiniHandStack and is_instance_valid(raw) and (raw as Control).is_inside_tree():
		return _to_ui_local((raw as Control).get_global_rect().get_center())
	return Vector2.INF


func _flight_landed(to_pid: int, res: int) -> void:
	if to_pid == -1:
		var bf: CardFace = _bank_faces.get(res, null)
		if bf != null and is_instance_valid(bf):
			_pulse_card(bf)
		return
	if to_pid == _view_pid() and not _hand_hidden():
		var face: CardFace = _res_card_refs.get(res, null)
		if face != null and is_instance_valid(face):
			_pulse_card(face)
		return
	_pulse_mini_hand(to_pid)


func _compute_flights(state: GameState) -> void:
	if _prev_flight_hands.size() != state.players.size() or _prev_flight_bank.is_empty():
		_last_flights = []
		_store_flight_state(state)
		return
	var ls: Dictionary = state.last_steal
	var steal_active := false
	if not ls.is_empty() and int(ls.get("serial", -1)) != _flight_seen_steal_serial:
		steal_active = true
		_flight_seen_steal_serial = int(ls.get("serial", -1))
	var deltas: Array = []
	for p in range(state.players.size()):
		var before: Dictionary = _prev_flight_hands[p]
		var after: Dictionary = state.players[p].get("hand", {})
		var d: Dictionary = {}
		for r in GameTypes.ALL_RESOURCES:
			var dv := int(after.get(r, 0)) - int(before.get(r, 0))
			if dv != 0:
				d[r] = dv
		deltas.append(d)
	var bd: Dictionary = {}
	for r in GameTypes.ALL_RESOURCES:
		var dv2 := int(state.bank.get(r, 0)) - int(_prev_flight_bank.get(r, 0))
		if dv2 != 0:
			bd[r] = dv2
	if steal_active:
		var sr := int(ls.get("res", -1))
		var vic := int(ls.get("victim", -1))
		var thi := int(ls.get("thief", -1))
		if sr >= 0 and vic >= 0 and vic < deltas.size():
			(deltas[vic] as Dictionary)[sr] = int((deltas[vic] as Dictionary).get(sr, 0)) + 1
		if sr >= 0 and thi >= 0 and thi < deltas.size():
			(deltas[thi] as Dictionary)[sr] = int((deltas[thi] as Dictionary).get(sr, 0)) - 1
	var transfers: Array = []
	for r in GameTypes.ALL_RESOURCES:
		var sources: Array = []
		var sinks: Array = []
		var b := int(bd.get(r, 0))
		if b < 0:
			sources.append({"id": -1, "left": -b})
		elif b > 0:
			sinks.append({"id": -1, "left": b})
		for p in range(deltas.size()):
			var dv3 := int((deltas[p] as Dictionary).get(r, 0))
			if dv3 < 0:
				sources.append({"id": p, "left": -dv3})
			elif dv3 > 0:
				sinks.append({"id": p, "left": dv3})
		var si := 0
		while not sources.is_empty():
			var src: Dictionary = sources[0]
			while int(src["left"]) > 0 and si < sinks.size():
				var snk: Dictionary = sinks[si]
				var n := mini(int(src["left"]), int(snk["left"]))
				if n > 0:
					transfers.append({"from": int(src["id"]), "to": int(snk["id"]), "res": r, "n": n})
					src["left"] = int(src["left"]) - n
					snk["left"] = int(snk["left"]) - n
				if int(snk["left"]) <= 0:
					si += 1
			if int(src["left"]) <= 0:
				sources.pop_front()
			elif si >= sinks.size():
				break
	_last_flights = transfers
	_store_flight_state(state)
	if _reduce_motion:
		return
	_schedule_flight_spawn(transfers)

func _schedule_flight_spawn(transfers: Array) -> void:
	_flight_spawn_serial += 1
	_flight_spawn_queue = transfers
	if _flight_spawn_timer == null:
		_flight_spawn_timer = Timer.new()
		_flight_spawn_timer.one_shot = true
		_flight_spawn_timer.wait_time = 0.02
		_flight_spawn_timer.timeout.connect(_flush_flight_spawn)
		add_child(_flight_spawn_timer)
	_flight_spawn_timer.start()

func _flight_outline_col(from_pid: int, to_pid: int) -> Color:
	if to_pid >= 0 and to_pid < GameTypes.PLAYER_COLORS.size():
		return GameTypes.PLAYER_COLORS[to_pid]
	if from_pid >= 0 and from_pid < GameTypes.PLAYER_COLORS.size():
		return GameTypes.PLAYER_COLORS[from_pid]
	return Color(0.5, 0.5, 0.5)

func _flush_flight_spawn() -> void:
	var my := _flight_spawn_serial
	var transfers: Array = _flight_spawn_queue
	_flight_spawn_queue = []
	if my != _flight_spawn_serial or transfers.is_empty():
		return
	_last_flight_targets = []
	var spawned := 0
	var delay := 0.0
	for tr in transfers:
		if spawned >= 10:
			break
		var res_id := int(tr["res"])
		var from := _flight_anchor(int(tr["from"]), res_id)
		var to := _flight_anchor(int(tr["to"]), res_id)
		if from == Vector2.INF or to == Vector2.INF:
			continue
		var to_pid := int(tr["to"])
		var landed := func() -> void: _flight_landed(to_pid, res_id)
		var k := mini(int(tr["n"]), 3)
		for i in range(k):
			if spawned >= 10:
				break
			var fallback := to
			var ent := {"to": to_pid, "res": res_id, "end": to}
			var to_live := func() -> Vector2:
				var a := _flight_anchor(to_pid, res_id)
				if a == Vector2.INF:
					return fallback
				ent["end"] = a
				return a
			_spawn_card_flyer(from, to, res_id, delay, landed, 40.0, _flight_outline_col(int(tr["from"]), to_pid), to_live)
			_last_flight_targets.append(ent)
			delay += 0.07
			spawned += 1

func _on_steal_card_landed(thief_pid: int, serial: int) -> void:
	if serial != _steal_anim_serial:
		return
	_steal_anim_serial = -1
	_steal_anim_turn = -1
	_steal_flyer = null
	if _hand_count_hold.has(thief_pid):
		_hand_count_hold.erase(thief_pid)
	var stripped: Array = []
	for r in _res_hold.keys():
		if int(_res_hold[r]) < 0:
			stripped.append(r)
	for r in stripped:
		_res_hold.erase(r)
	_refresh_ui()
	_pulse_mini_hand(thief_pid)
	if _sfx != null:
		_sfx.play("click")

func _pulse_mini_hand(pid: int) -> void:
	if _reduce_motion:
		return
	var raw_stack: Variant = _scoreboard_mini_hands.get(pid, null)
	if not (raw_stack is Control) or not is_instance_valid(raw_stack) or not (raw_stack as Control).is_inside_tree():
		return
	var stack: Control = raw_stack
	stack.pivot_offset = stack.size * 0.5
	var tw := stack.create_tween()
	tw.tween_property(stack, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(stack, "scale", Vector2.ONE, 0.16)

func _spawn_production_popups(state: GameState) -> void:
	if _board_view == null:
		return
	var total: int = state.last_dice.x + state.last_dice.y
	var topo := HexMath.get_topology()
	var view_pid := _view_pid()
	for t_id in range(state.tile_terrains.size()):
		if t_id == state.blocker_tile:
			continue
		if t_id >= state.tile_numbers.size() or int(state.tile_numbers[t_id]) != total:
			continue
		var res := GameTypes.terrain_to_resource(int(state.tile_terrains[t_id]))
		if res < 0:
			continue
		var produced := 0
		var view_prod := 0
		if t_id < topo.tile_vertices.size():
			for v_id in topo.tile_vertices[t_id]:
				if v_id >= 0 and v_id < state.vertex_owner.size() and state.vertex_owner[v_id] >= 0:
					var b_type: int = state.vertex_building[v_id] if v_id < state.vertex_building.size() else GameTypes.BuildingType.NONE
					var gain := 0
					if b_type == GameTypes.BuildingType.SETTLEMENT:
						gain = 1
					elif b_type == GameTypes.BuildingType.CITY:
						gain = 2
					produced += gain
					if state.vertex_owner[v_id] == view_pid:
						view_prod += gain
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
func _guard_action_button_focus(btn: Control) -> void:
	_no_space_focus_btns.append(btn)
	if btn is Button:
		(btn as Button).button_up.connect(func() -> void:
			btn.release_focus()
		)
	else:
		btn.focus_exited.connect(func() -> void:
			pass
		)

func _build_device_pass_cover() -> void:
	_device_pass_cover = PanelContainer.new()
	_device_pass_cover.visible = false
	_device_pass_cover.z_index = 10
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
			return "Click a resource card (or T) to answer your offer."
		return "Pick a player card to trade — closing or End Turn withdraws."
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

	var ot_now: Dictionary = state.open_trade
	var ot_token := "" if ot_now.is_empty() else "%s|%d" % [_ot_token(ot_now), int(state.turn_number)]
	if ot_token != _counter_offer_token:
		_counter_offer_token = ot_token
		_declined_counters = {}
	var live_counters := {}
	if not ot_now.is_empty():
		var ot_resp: Dictionary = ot_now.get("responses", {})
		for rp_id in ot_resp:
			if str(((ot_resp[rp_id] as Dictionary)).get("status", "")) == "counter":
				live_counters[int(rp_id)] = true
	for ck in _counter_toasted.keys().duplicate():
		if not live_counters.has(ck):
			_counter_toasted.erase(ck)

	# Discard picker first, so every later section sees a fresh discard state
	var needs_discard := (
		state.phase == GameTypes.TurnPhase.TURN_DISCARD
		and state.pending_discards.has(acting_id)
		and human_acting
	)
	_refresh_discard_picker(state, acting_id, needs_discard, _hand_hidden())
	_refresh_bank_section(state)

	if _steal_chooser != null and _steal_chooser.visible:
		if not human_acting or _hand_hidden() or _board_view.interaction_mode != BoardView.InteractionMode.PICK_BLOCKER_TILE:
			_close_steal_chooser()

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
	_scoreboard_mini_hands.clear()
	_scoreboard_row_panels.clear()
	for k_order in range(state.num_players):
		var p_id: int = (state.start_player + k_order) % state.num_players
		var p_data: Dictionary = state.players[p_id]
		var seat_cfg: SeatConfig = session.seats[p_id] if p_id < session.seats.size() else null
		var is_active := (p_id == acting_id and state.phase != GameTypes.TurnPhase.GAME_OVER)
		var card_bg: Color = Palette.PANEL_BG_ALT if is_active else Palette.PANEL_BG
		var card := _make_compact_card(card_bg)
		if is_active:
			var act_sb = card.get_theme_stylebox("panel")
			if act_sb is StyleBoxFlat:
				var act2 := (act_sb as StyleBoxFlat).duplicate()
				act2.set_border_width_all(3)
				act2.border_color = GameTypes.PLAYER_COLORS[p_id]
				act2.shadow_color = Color(GameTypes.PLAYER_COLORS[p_id], 0.45)
				act2.shadow_size = 2
				card.add_theme_stylebox_override("panel", act2)
				if not _reduce_motion:
					var ptw := card.create_tween()
					ptw.set_loops()
					ptw.tween_method(func(v: float) -> void: act2.shadow_size = int(v), 2.0, 8.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
					ptw.tween_method(func(v: float) -> void: act2.shadow_size = int(v), 8.0, 2.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_scoreboard_box.add_child(card)
		_scoreboard_row_panels[p_id] = card

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		card.add_child(row)

		var pcol: Color = GameTypes.PLAYER_COLORS[p_id % GameTypes.PLAYER_COLORS.size()]
		var badge := Label.new()
		var vp_public := state.get_victory_points(p_id, false)
		var badge_text := str(vp_public)
		var tip_vp := "%d victory points" % vp_public
		if p_id == view_pid and (human_seat_n == 1 or p_id == acting_id):
			var hidden_gain: int = state.get_victory_points(p_id, true) - vp_public
			if hidden_gain > 0:
				badge_text = "%d(+%d)" % [vp_public, hidden_gain]
				tip_vp = "%d public + %d hidden (Charter cards) = %d" % [
					vp_public, hidden_gain, vp_public + hidden_gain
				]
		badge.text = badge_text
		badge.tooltip_text = tip_vp
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.custom_minimum_size = Vector2(34, 22)
		badge.add_theme_font_size_override("font_size", 11)
		var bst := StyleBoxFlat.new()
		bst.bg_color = pcol
		bst.set_corner_radius_all(6)
		bst.content_margin_left = 2
		bst.content_margin_right = 2
		badge.add_theme_stylebox_override("normal", bst)
		var lum := pcol.r * 0.299 + pcol.g * 0.587 + pcol.b * 0.114
		badge.add_theme_color_override("font_color", Color.WHITE if lum < 0.55 else Color(0.13, 0.11, 0.09))
		row.add_child(badge)

		var name_lbl := Label.new()
		name_lbl.text = ("▶ " if is_active else "") + str(p_data.get("name", GameTypes.PLAYER_NAMES[p_id]))
		name_lbl.custom_minimum_size = Vector2(78, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT)
		row.add_child(name_lbl)

		var seat_cell := CenterContainer.new()
		seat_cell.custom_minimum_size = Vector2(62, 0)
		seat_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(seat_cell)
		seat_cell.add_child(_make_pill(_seat_type_label(seat_cfg), Color(Palette.PANEL_BORDER, 0.28), Palette.TEXT_MUTED))

		var res_stack := MiniHandStack.new()
		res_stack.custom_minimum_size = Vector2(44, 26)
		res_stack.act_fan.visible = false
		res_stack.res_count = _displayed_hand_count(p_id)
		row.add_child(res_stack)
		_scoreboard_mini_hands[p_id] = res_stack

		var dev_cnt: int = p_data.get("dev_cards", []).size() + p_data.get("new_dev_cards", []).size()
		var act_stack := MiniHandStack.new()
		act_stack.custom_minimum_size = Vector2(44, 26)
		act_stack.res_fan.visible = false
		act_stack.act_count = dev_cnt
		row.add_child(act_stack)

		var award_cell := HBoxContainer.new()
		award_cell.add_theme_constant_override("separation", 3)
		award_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		award_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(award_cell)
		if state.longest_route_holder == p_id:
			award_cell.add_child(_make_pill("Route +2", Color(Palette.ACCENT_GREEN, 0.40), Palette.TEXT))
		if state.largest_guard_holder == p_id:
			award_cell.add_child(_make_pill("Guard +2", Color(Palette.MOUNTAIN_SHADE, 0.40), Palette.TEXT))

		var played_cell := HBoxContainer.new()
		played_cell.add_theme_constant_override("separation", 3)
		played_cell.custom_minimum_size = Vector2(96, 26)
		played_cell.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_child(played_cell)
		_scoreboard_played[p_id] = played_cell
		var played_dev: Dictionary = p_data.get("played_dev", {})
		var gcnt := int(played_dev.get(GameTypes.DevCardType.GUARD, 0))
		if gcnt <= 0:
			gcnt = int(p_data.get("played_guards", 0))
		if gcnt > 0:
			played_cell.add_child(_make_played_glyph(
				GameTypes.DevCardType.GUARD, gcnt, state.largest_guard_holder == p_id,
				"Guards played: %d" % gcnt
			))
		var played_names := {
			GameTypes.DevCardType.ROAD_WORK: "Road Work",
			GameTypes.DevCardType.HARVEST_BOUNTY: "Harvest Bounty",
			GameTypes.DevCardType.TRADE_DECREE: "Trade Decree",
		}
		for other_type in [
			GameTypes.DevCardType.ROAD_WORK,
			GameTypes.DevCardType.HARVEST_BOUNTY,
			GameTypes.DevCardType.TRADE_DECREE,
		]:
			var ocnt := int(played_dev.get(other_type, 0))
			if ocnt > 0:
				played_cell.add_child(_make_played_glyph(
					other_type, ocnt, false,
					"%s played: %d" % [str(played_names[other_type]), ocnt]
				))
		var route_len := int(p_data.get("longest_route_length", 0))
		if route_len > 0:
			played_cell.add_child(_make_road_glyph(route_len, state.longest_route_holder == p_id))

	var dash_pid := view_pid
	var dash_player: Dictionary = state.players[dash_pid]
	var hand: Dictionary = dash_player.get("hand", {})

	# Visual bottom hand bar refresh (discard display always derived from state)
	var pid_changed := (dash_pid != _prev_dash_pid)
	var discard_badges := needs_discard and (not hand_hidden)
	for r in GameTypes.ALL_RESOURCES:
		var face: CardFace = _res_card_refs.get(r, null)
		if face == null:
			continue
		face.hidden_card = hand_hidden
		face.tooltip_text = _hand_card_tooltip(state, r, hand_hidden, int(hand.get(r, 0)))
		if hand_hidden:
			face.count = 0
			face.badge = 0
			continue
		face.count = maxi(0, int(hand.get(r, 0)) + int(_res_hold.get(r, 0)))
		face.badge = int(_discard_pick.get(r, 0)) if discard_badges else 0
		if not pid_changed and face.count > int(_prev_dash_hand.get(r, 0)):
			_pulse_card(face)
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
		var chip: CardFace = _action_chips.get(ctype, null)
		if chip == null:
			continue
		chip.hidden_card = false
		var ccnt: int = int(card_counts.get(ctype, 0))
		chip.count = ccnt
		var help := str(DEV_CARD_HELP.get(ctype, ""))
		if ctype == GameTypes.DevCardType.CHARTER_POINT:
			chip.disabled = true
			chip.tooltip_text = "%s\nNever played — it scores when you win" % help
			continue
		if ccnt <= 0:
			chip.disabled = true
			chip.tooltip_text = "%s\nYou have no %s card" % [help, str(chip_names[ctype])]
			continue
		var new_cnt := 0
		for c in dash_player.get("new_dev_cards", []):
			if int(c) == int(ctype):
				new_cnt += 1
		var chk: Dictionary = RulesEngine.can_play_dev_card(state, dash_pid, int(ctype))
		var chk_ok := bool(chk.get("ok", false))
		chip.disabled = not chk_ok
		var tip := "Play %s\n%s" % [str(chip_names[ctype]), help]
		if new_cnt > 0:
			tip += " (new this turn)"
		chip.tooltip_text = tip if chk_ok else "%s\n%s" % [help, str(chk.get("reason", ""))]
	if hand_hidden:
		for ctype in _action_chips.keys():
			var hidden_chip: CardFace = _action_chips[ctype]
			hidden_chip.hidden_card = true
			hidden_chip.disabled = true
			hidden_chip.tooltip_text = ""

	_refresh_subpanels(state, acting_id, human_acting)

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
	_end_turn_btn.add_theme_color_override("icon_modulate", _end_turn_btn.get_theme_color("font_color"))
	_end_turn_btn.add_theme_color_override("icon_modulate:disabled", _end_turn_btn.get_theme_color("font_disabled_color"))

	_refresh_offer_strip(state)
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
	var cost := _build_cost_for(kind)
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

func _on_board_background_clicked() -> void:
	_close_costs_popup()
	if _trade_tray != null and _trade_tray.visible:
		_close_trade_tray_by_user()

func _on_board_tile_clicked(tile_id: int) -> void:
	if not _is_human_acting() or _hand_hidden():
		return
	if _board_view.interaction_mode == BoardView.InteractionMode.PICK_BLOCKER_TILE:
		var acting_id := session.get_acting_player_id()
		if _steal_chooser != null and _steal_chooser.visible:
			return
		var victims: Array[int] = RulesEngine.get_steal_victims(session.state, acting_id, tile_id)
		if victims.size() >= 2:
			_open_steal_chooser(tile_id, victims)
			return
		var target_opp: int = victims[0] if victims.size() == 1 else -1
		if _pending_guard_card:
			_submit_human_action(GameAction.play_guard(tile_id, target_opp))
		else:
			_submit_human_action(GameAction.move_blocker(tile_id, target_opp))

func _build_steal_chooser() -> void:
	_steal_chooser = PanelContainer.new()
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(9)
	st.set_border_width_all(2)
	st.border_color = Palette.ACCENT_GOLD.darkened(0.15)
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 5
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	_steal_chooser.add_theme_stylebox_override("panel", st)
	_steal_chooser.visible = false
	add_child(_steal_chooser)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_steal_chooser.add_child(col)
	var heading := Label.new()
	heading.text = "Steal from whom?"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Palette.HEADING)
	col.add_child(heading)
	_steal_chooser_rows = VBoxContainer.new()
	_steal_chooser_rows.add_theme_constant_override("separation", 3)
	col.add_child(_steal_chooser_rows)

func _open_steal_chooser(tile_id: int, victims: Array[int]) -> void:
	_steal_pending = {"tile_id": tile_id, "guard": _pending_guard_card}
	_steal_victims = victims.duplicate()
	for c in _steal_chooser_rows.get_children():
		c.queue_free()
	_steal_victim_btns.clear()
	for i in range(victims.size()):
		var pid: int = victims[i]
		var hand_n: int = GameTypes.hand_total(session.state.players[pid]["hand"])
		var b := Button.new()
		b.text = ""
		b.custom_minimum_size = Vector2(230, 34)
		_style_button(b, "normal")
		var vrow := HBoxContainer.new()
		vrow.add_theme_constant_override("separation", 7)
		vrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(vrow)
		var vsw := ColorRect.new()
		vsw.custom_minimum_size = Vector2(10, 20)
		vsw.color = GameTypes.PLAYER_COLORS[pid]
		vsw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vrow.add_child(vsw)
		var vlbl := Label.new()
		vlbl.text = "%d. %s — %d card%s" % [i + 1, str(session.state.players[pid].get("name", GameTypes.PLAYER_NAMES[pid])), hand_n, "" if hand_n == 1 else "s"]
		vlbl.add_theme_font_size_override("font_size", 13)
		vlbl.add_theme_color_override("font_color", Palette.TEXT)
		vlbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vrow.add_child(vlbl)
		b.pressed.connect(_on_steal_victim_pressed.bind(i))
		_guard_action_button_focus(b)
		_steal_chooser_rows.add_child(b)
		_steal_victim_btns.append(b)
	_position_steal_chooser()
	_steal_chooser.visible = true
	if not _steal_victim_btns.is_empty():
		_steal_victim_btns[0].grab_focus()
	_set_banner("Choose who to steal from — keys 1-%d, Esc picks another tile" % victims.size())

func _position_steal_chooser() -> void:
	_steal_chooser.reset_size()
	var bsize := _steal_chooser.get_combined_minimum_size()
	var spot := _board_view.global_position + _board_view.get_spot_screen_position("tile", int(_steal_pending.get("tile_id", -1)))
	var pos := spot - bsize * 0.5
	var br := _board_view.get_global_rect()
	pos.x = clampf(pos.x, br.position.x + 2, br.end.x - bsize.x - 2)
	pos.y = clampf(pos.y, br.position.y + 2, br.end.y - bsize.y - 2)
	_steal_chooser.position = pos

func _on_steal_victim_pressed(index: int) -> void:
	if _steal_pending.is_empty() or not _is_human_acting() or _hand_hidden():
		return
	if index < 0 or index >= _steal_victims.size():
		return
	var tile_id := int(_steal_pending.get("tile_id", -1))
	var victim: int = _steal_victims[index]
	var guard := bool(_steal_pending.get("guard", false))
	_close_steal_chooser()
	if guard:
		_submit_human_action(GameAction.play_guard(tile_id, victim))
	else:
		_submit_human_action(GameAction.move_blocker(tile_id, victim))

func _close_steal_chooser() -> void:
	_steal_pending = {}
	_steal_victims = []
	_steal_victim_btns.clear()
	if _steal_chooser != null:
		_steal_chooser.visible = false

func _cancel_steal_chooser() -> void:
	_close_steal_chooser()
	_refresh_ui()

# Toolbar button handlers
func _on_roll_pressed() -> void:
	_submit_human_action(GameAction.roll_dice())

func _on_end_turn_pressed() -> void:
	if session != null and session.state != null:
		var st := session.state
		var ot: Dictionary = st.open_trade
		if (
			not ot.is_empty()
			and _is_human_acting()
			and int(ot.get("from", -1)) == session.get_acting_player_id()
		):
			var cancel_res: Dictionary = session.submit_action(
				session.get_acting_player_id(), GameAction.cancel_open_trade()
			)
			if not bool(cancel_res.get("ok", false)):
				return
	_submit_human_action(GameAction.end_turn())

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

func _discard_mode_active() -> bool:
	if session == null or session.state == null:
		return false
	return (
		_discard_mode_box != null
		and _discard_mode_box.visible
		and not _hand_hidden()
	)

func _refresh_bank_section(state: GameState) -> void:
	if _bank_faces.is_empty() or state == null:
		return
	for r in GameTypes.ALL_RESOURCES:
		var bf: CardFace = _bank_faces.get(r, null)
		if bf == null:
			continue
		var cnt := int(state.bank.get(r, 0))
		bf.count = cnt
		bf.pile_count = cnt
		bf.pile_low_tint = cnt <= 4
		bf.tooltip_text = "%s in the bank: %d" % [GameTypes.resource_name(r), cnt]
	if _bank_deck_face != null:
		var dcnt := state.dev_deck.size()
		_bank_deck_face.count = dcnt
		_bank_deck_face.pile_count = dcnt
		_bank_deck_face.pile_low_tint = dcnt <= 4
		_bank_deck_face.tooltip_text = "Action Cards left: %d" % dcnt


func _refresh_discard_picker(state: GameState, acting_id: int, needs_discard: bool, hand_hidden: bool) -> void:
	if not needs_discard or acting_id != _discard_pick_pid:
		_discard_pick = {}
		_discard_pick_pid = acting_id if needs_discard else -1
	_discard_mode_box.visible = needs_discard
	for n in _bar_extra_nodes:
		if is_instance_valid(n):
			n.visible = not needs_discard
	if not needs_discard:
		return
	var req_cnt := int(state.pending_discards.get(acting_id, 0))
	var hand: Dictionary = state.players[acting_id].get("hand", {})
	# cap picks to what is actually in hand (e.g. after viewer changes)
	for r in GameTypes.ALL_RESOURCES:
		_discard_pick[r] = clampi(int(_discard_pick.get(r, 0)), 0, int(hand.get(r, 0)))
	var picked := _discard_picked_total()
	if picked > req_cnt:
		_discard_pick = _trim_discard_pick(picked - req_cnt)
		picked = _discard_picked_total()
	_discard_heading.text = "Discard %d cards (picked %d of %d)" % [req_cnt, picked, req_cnt]
	_discard_confirm_btn.disabled = picked != req_cnt or hand_hidden
	_discard_auto_btn.disabled = hand_hidden

func _discard_picked_total() -> int:
	var total := 0
	for r in GameTypes.ALL_RESOURCES:
		total += int(_discard_pick.get(r, 0))
	return total

func _trim_discard_pick(excess: int) -> Dictionary:
	var trimmed := _discard_pick.duplicate()
	for r in GameTypes.ALL_RESOURCES:
		if excess <= 0:
			break
		var have := int(trimmed.get(r, 0))
		var cut := mini(have, excess)
		trimmed[r] = have - cut
		excess -= cut
	return trimmed

func _discard_pick_one(res: int) -> void:
	if not _discard_mode_active() or session == null or session.state == null:
		return
	var acting_id := session.get_acting_player_id()
	var req_cnt := int(session.state.pending_discards.get(acting_id, 0))
	var hand: Dictionary = session.state.players[acting_id].get("hand", {})
	if _discard_picked_total() >= req_cnt:
		return
	if int(_discard_pick.get(res, 0)) >= int(hand.get(res, 0)):
		return
	_discard_pick[res] = int(_discard_pick.get(res, 0)) + 1
	_refresh_ui()

func _discard_take_back(res: int) -> void:
	if not _discard_mode_active():
		return
	if int(_discard_pick.get(res, 0)) <= 0:
		return
	_discard_pick[res] = int(_discard_pick.get(res, 0)) - 1
	_refresh_ui()

func _on_discard_confirm_pressed() -> void:
	if not _discard_mode_active() or session == null or session.state == null:
		return
	var acting_id := session.get_acting_player_id()
	var req_cnt := int(session.state.pending_discards.get(acting_id, 0))
	if _discard_picked_total() != req_cnt:
		return
	_submit_human_action(GameAction.discard_resources(_discard_pick.duplicate()))

func _on_discard_auto_fill_pressed() -> void:
	if not _discard_mode_active() or session == null or session.state == null:
		return
	var acting_id := session.get_acting_player_id()
	var req_cnt := int(session.state.pending_discards.get(acting_id, 0))
	if req_cnt <= 0:
		return
	var hand: Dictionary = session.state.players[acting_id].get("hand", {}).duplicate()
	var choice := GameTypes.empty_hand()
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
		choice[best_res] = int(choice[best_res]) + 1
		remaining -= 1
	_discard_pick = choice
	_refresh_ui()

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
	_trade_tray.size_flags_vertical = Control.SIZE_FILL
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(10)
	st.set_border_width_all(2)
	st.border_color = Palette.PANEL_BORDER
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 4
	st.content_margin_left = 7
	st.content_margin_right = 7
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	_trade_tray.add_theme_stylebox_override("panel", st)
	_trade_tray.clip_contents = true
	parent_column.add_child(_trade_tray)

	_trade_scroll = ScrollContainer.new()
	_trade_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trade_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_trade_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_trade_tray.add_child(_trade_scroll)
	_trade_content = VBoxContainer.new()
	_trade_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_content.add_theme_constant_override("separation", 3)
	_trade_scroll.add_child(_trade_content)

	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 6)
	_trade_content.add_child(head_row)
	_trade_title_lbl = Label.new()
	_trade_title_lbl.text = "Trade"
	_trade_title_lbl.add_theme_font_size_override("font_size", 12)
	_trade_title_lbl.add_theme_color_override("font_color", Palette.HEADING)
	_trade_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_title_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trade_title_lbl.clip_text = true
	_trade_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head_row.add_child(_trade_title_lbl)
	_trade_close_btn = Button.new()
	_trade_close_btn.text = "\u2715"
	_trade_close_btn.tooltip_text = "Close (Esc) \u2014 withdraws your offer"
	_trade_close_btn.custom_minimum_size = Vector2(24, 24)
	_trade_close_btn.add_theme_font_size_override("font_size", 11)
	_style_button(_trade_close_btn, "ghost")
	_flatten_trade_button(_trade_close_btn)
	_trade_close_btn.pressed.connect(_close_trade_tray_by_user)
	_guard_action_button_focus(_trade_close_btn)
	head_row.add_child(_trade_close_btn)

	# Respond view: the incoming offer as read-only card rows + answer buttons.
	_trade_respond_view = VBoxContainer.new()
	_trade_respond_view.add_theme_constant_override("separation", 4)
	_trade_respond_view.visible = false
	_trade_content.add_child(_trade_respond_view)
	var ro_get_row := _make_ro_row("You get", _trade_ro_get_box)
	_trade_ro_get_box = ro_get_row[1]
	_trade_respond_view.add_child(ro_get_row[0])
	var ro_give_row := _make_ro_row("You give", _trade_ro_give_box)
	_trade_ro_give_box = ro_give_row[1]
	_trade_respond_view.add_child(ro_give_row[0])
	_trade_have_label = Label.new()
	_trade_have_label.add_theme_font_size_override("font_size", 12)
	_trade_have_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_trade_have_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_respond_view.add_child(_trade_have_label)
	_trade_respond_row = HBoxContainer.new()
	_trade_respond_row.add_theme_constant_override("separation", 6)
	_trade_respond_view.add_child(_trade_respond_row)
	_ot_accept_btn = _make_tray_button("Accept", "primary", "Accept this offer")
	_ot_accept_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ot_accept_btn.pressed.connect(_on_accept_offer_pressed)
	_trade_respond_row.add_child(_ot_accept_btn)
	_ot_decline_btn = _make_tray_button("Decline", "ghost", "Decline this offer")
	_ot_decline_btn.pressed.connect(_on_decline_offer_pressed)
	_trade_respond_row.add_child(_ot_decline_btn)
	_ot_counter_btn = _make_tray_button("Counter\u2026", "normal", "Propose different terms")
	_ot_counter_btn.pressed.connect(_on_counter_offer_pressed)
	_trade_respond_row.add_child(_ot_counter_btn)

	# Editor rows (propose / edit own offer / counter draft)
	_trade_rows_col = VBoxContainer.new()
	_trade_rows_col.add_theme_constant_override("separation", 4)
	_trade_content.add_child(_trade_rows_col)
	_build_trade_card_rows()

	_trade_btn_row = HBoxContainer.new()
	_trade_btn_row.add_theme_constant_override("separation", 4)
	_trade_content.add_child(_trade_btn_row)
	_trade_ask_btn = _make_tray_button("Ask players", "primary", "Post this offer to every other player")
	_trade_ask_btn.pressed.connect(_on_ask_players_pressed)
	_trade_btn_row.add_child(_trade_ask_btn)
	_trade_resend_btn = _make_tray_button("Send new offer", "primary", "Cancel this offer and post the new one")
	_trade_resend_btn.visible = false
	_trade_resend_btn.pressed.connect(_on_resend_offer_pressed)
	_trade_btn_row.add_child(_trade_resend_btn)
	_trade_ratio_btn = _make_tray_button("Bank 4:1", "normal", "Swap these cards with the bank at this ratio")
	_trade_ratio_btn.visible = false
	_trade_ratio_btn.pressed.connect(_on_bank_trade_pressed)
	_trade_btn_row.add_child(_trade_ratio_btn)
	_trade_clear_btn = _make_tray_button("Clear", "ghost", "Reset both sides of the offer")
	_trade_clear_btn.pressed.connect(_on_clear_trade_pressed)
	_trade_btn_row.add_child(_trade_clear_btn)
	_trade_offers_lbl = Label.new()
	_trade_offers_lbl.add_theme_font_size_override("font_size", 10)
	_trade_offers_lbl.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_trade_offers_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_offers_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_trade_offers_lbl.visible = false
	_trade_btn_row.add_child(_trade_offers_lbl)

	_trade_counter_row = HBoxContainer.new()
	_trade_counter_row.add_theme_constant_override("separation", 4)
	_trade_counter_row.visible = false
	_trade_content.add_child(_trade_counter_row)
	_ot_send_btn = _make_tray_button("Send counter", "primary", "Send your counter-offer")
	_ot_send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ot_send_btn.pressed.connect(_on_send_counter_pressed)
	_trade_counter_row.add_child(_ot_send_btn)
	_ot_back_btn = _make_tray_button("Back", "ghost", "Go back without countering")
	_ot_back_btn.pressed.connect(_on_counter_back_pressed)
	_trade_counter_row.add_child(_ot_back_btn)

	_trade_partner_stack = VBoxContainer.new()
	_trade_partner_stack.add_theme_constant_override("separation", 3)
	_trade_partner_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_partner_stack.visible = false
	_trade_content.add_child(_trade_partner_stack)

	_trade_no_takers_lbl = Label.new()
	_trade_no_takers_lbl.text = "No takers \u2014 withdraw or change your offer"
	_trade_no_takers_lbl.add_theme_font_size_override("font_size", 12)
	_trade_no_takers_lbl.add_theme_color_override("font_color", Palette.ACCENT_RED.darkened(0.1))
	_trade_no_takers_lbl.visible = false
	_trade_no_takers_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_content.add_child(_trade_no_takers_lbl)

	for r in GameTypes.ALL_RESOURCES:
		_trade_give_counts[r] = 0
		_trade_get_counts[r] = 0

func _make_ro_row(caption: String, _existing: HBoxContainer) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", Palette.HEADING)
	cap.custom_minimum_size = Vector2(52, 0)
	row.add_child(cap)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	return [row, box]

const _TRADE_CHIP := Vector2(34, 32)

func _fill_ro_row(box: HBoxContainer, bundle: Dictionary, missing: Dictionary) -> void:
	for c in box.get_children():
		c.queue_free()
	var any_shown := false
	for r in GameTypes.ALL_RESOURCES:
		var want := int(bundle.get(r, 0))
		if want <= 0:
			continue
		any_shown = true
		var f := CardFace.new()
		f.kind = "resource"
		f.resource = r
		f.custom_minimum_size = _TRADE_CHIP
		f.count = want
		f.show_name = false
		f.vivid = true
		f.focusable = false
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.disabled = missing.has(r)
		f.tooltip_text = "%s \u00d7%d" % [GameTypes.resource_name(r), want]
		box.add_child(f)
	if not any_shown:
		var none := Label.new()
		none.text = "nothing"
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(none)

func _build_trade_card_rows() -> void:
	var g_row := HBoxContainer.new()
	g_row.add_theme_constant_override("separation", 5)
	_trade_rows_col.add_child(g_row)
	var g_cap := Label.new()
	g_cap.text = "You give"
	g_cap.add_theme_font_size_override("font_size", 12)
	g_cap.add_theme_color_override("font_color", Palette.HEADING)
	g_cap.custom_minimum_size = Vector2(52, 0)
	g_row.add_child(g_cap)
	_trade_give_box = HBoxContainer.new()
	_trade_give_box.add_theme_constant_override("separation", 3)
	_trade_give_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g_row.add_child(_trade_give_box)
	_trade_give_hint_lbl = Label.new()
	_trade_give_hint_lbl.text = "Click your cards below"
	_trade_give_hint_lbl.add_theme_font_size_override("font_size", 11)
	_trade_give_hint_lbl.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_trade_give_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g_row.add_child(_trade_give_hint_lbl)

	var t_row := HBoxContainer.new()
	t_row.add_theme_constant_override("separation", 5)
	_trade_rows_col.add_child(t_row)
	var t_cap := Label.new()
	t_cap.text = "You get"
	t_cap.add_theme_font_size_override("font_size", 12)
	t_cap.add_theme_color_override("font_color", Palette.HEADING)
	t_cap.custom_minimum_size = Vector2(52, 0)
	t_row.add_child(t_cap)
	var face_box := HBoxContainer.new()
	face_box.add_theme_constant_override("separation", 3)
	face_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_row.add_child(face_box)
	for r in GameTypes.ALL_RESOURCES:
		var face := CardFace.new()
		face.kind = "resource"
		face.resource = r
		face.custom_minimum_size = _TRADE_CHIP
		face.show_name = false
		face.vivid = true
		var res := r
		face.pressed.connect(func() -> void:
			var sel_now := int(_trade_get_counts.get(res, 0))
			_adjust_trade_count(false, res, -1 if sel_now > 0 else 1)
		)
		face.right_pressed.connect(func() -> void: _adjust_trade_count(false, res, 1))
		face_box.add_child(face)
		_trade_get_faces[r] = face

func _rebuild_trade_chip_rows(unlocked: bool) -> void:
	for c in _trade_give_box.get_children():
		c.queue_free()
	for r in GameTypes.ALL_RESOURCES:
		var cnt: int = int(_trade_give_counts.get(r, 0))
		if cnt <= 0:
			continue
		var chip := CardFace.new()
		chip.kind = "resource"
		chip.resource = r
		chip.custom_minimum_size = _TRADE_CHIP
		chip.count = cnt
		chip.show_name = false
		chip.vivid = true
		chip.selected = true
		chip.disabled = not unlocked
		chip.tooltip_text = "Click to take one %s back \u00b7 right-click to add another" % GameTypes.resource_name(r)
		var res_g := r
		chip.pressed.connect(func() -> void: _adjust_trade_count(true, res_g, -1))
		chip.right_pressed.connect(func() -> void: _adjust_trade_count(true, res_g, 1))
		_trade_give_box.add_child(chip)
	var give_total := 0
	for r in GameTypes.ALL_RESOURCES:
		give_total += int(_trade_give_counts.get(r, 0))
	if _trade_give_hint_lbl != null:
		_trade_give_hint_lbl.visible = give_total <= 0 and unlocked
	for r in GameTypes.ALL_RESOURCES:
		var face: CardFace = _trade_get_faces.get(r, null)
		if face == null:
			continue
		var sel: int = int(_trade_get_counts.get(r, 0))
		face.selected = sel > 0
		face.count = sel
		face.disabled = not unlocked
		if sel > 0:
			face.tooltip_text = "Click to take one %s back \u00b7 right-click to add another" % GameTypes.resource_name(r)
		else:
			face.tooltip_text = "Click to ask for one %s \u00b7 right-click asks for more" % GameTypes.resource_name(r)

func _make_tray_button(btn_text: String, kind: String, tip: String) -> Button:
	var b := Button.new()
	b.text = btn_text
	b.custom_minimum_size = Vector2(0, 24)
	b.add_theme_font_size_override("font_size", 12)
	b.tooltip_text = tip
	_style_button(b, kind)
	_flatten_trade_button(b)
	return b

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

func _trade_side_key(is_give: bool) -> String:
	var counts: Dictionary = _trade_give_counts if is_give else _trade_get_counts
	var parts: Array[String] = []
	for r in GameTypes.ALL_RESOURCES:
		parts.append(str(int(counts.get(r, 0))))
	return "".join(parts)

func _trade_offer_key(bundle: Variant) -> String:
	var parts: Array[String] = []
	for r in GameTypes.ALL_RESOURCES:
		parts.append(str(int((bundle as Dictionary).get(r, 0))))
	return "".join(parts)

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
	if _reduce_motion:
		on = false
	if on:
		if _trade_hint_tween != null and _trade_hint_tween.is_valid():
			return
		for r in GameTypes.ALL_RESOURCES:
			var face: CardFace = _res_card_refs.get(r, null)
			if face != null and is_instance_valid(face):
				face.pivot_offset = face.size * 0.5
		_trade_hint_tween = create_tween()
		_trade_hint_tween.set_loops()
		for _cycle in range(1):
			for r in GameTypes.ALL_RESOURCES:
				var face: CardFace = _res_card_refs.get(r, null)
				if face != null and is_instance_valid(face):
					_trade_hint_tween.tween_property(face, "scale", Vector2(1.05, 1.05), 0.55).set_trans(Tween.TRANS_SINE)
					_trade_hint_tween.tween_property(face, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
	else:
		if _trade_hint_tween != null and _trade_hint_tween.is_valid():
			_trade_hint_tween.kill()
		_trade_hint_tween = null
		for r in GameTypes.ALL_RESOURCES:
			var face: CardFace = _res_card_refs.get(r, null)
			if face != null and is_instance_valid(face):
				face.scale = Vector2.ONE
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
	_set_tray_panel_visible(true)
	_trade_opened_auto = false
	_trade_reopen_token = ""
	_set_trade_hint(false)
	_refresh_ui()

func _release_tray_focus() -> void:
	if _trade_tray == null:
		return
	var fo := get_viewport().gui_get_focus_owner()
	if fo != null and is_instance_valid(fo) and _trade_tray.is_ancestor_of(fo):
		fo.release_focus()

func _close_trade_tray_by_user() -> void:
	if _trade_tray == null or not _trade_tray.visible:
		return
	if session != null and session.state != null:
		var st := session.state
		var ot: Dictionary = st.open_trade
		var from_p := int(ot.get("from", -1))
		if (
			not ot.is_empty()
			and _is_human_acting()
			and from_p == _view_pid()
			and session.get_acting_player_id() == from_p
		):
			var res: Dictionary = session.submit_action(session.get_acting_player_id(), GameAction.cancel_open_trade())
			if not bool(res.get("ok", false)):
				return
			_set_tray_panel_visible(false)
			_release_tray_focus()
			_set_trade_hint(false)
			_trade_reopen_token = ""
			_trade_counter_mode = false
			return
	_set_tray_panel_visible(false)
	_release_tray_focus()
	_trade_counter_mode = false
	if session != null and session.state != null:
		var st2 := session.state
		_trade_reopen_token = _ot_dismiss_key(st2.open_trade, _view_pid())

func _set_tray_panel_visible(v: bool) -> void:
	if _trade_tray == null or _trade_tray.visible == v:
		return
	_trade_tray.visible = v
	if v:
		# Give the panel room: collapse the event log, restore it on close.
		if _log_toggle_btn != null and _log_toggle_btn.button_pressed:
			_log_restore_open = true
			_set_log_open(false)
	else:
		if _log_restore_open:
			_log_restore_open = false
			_set_log_open(true)

func _update_tray_height() -> void:
	if _trade_tray == null:
		return
	if not _trade_tray.visible:
		_trade_tray.custom_minimum_size.y = 0.0
		return
	var nat := _trade_content.get_combined_minimum_size().y + 12.0
	var sidebar_h := 0.0
	if _right_panel != null:
		sidebar_h = _right_panel.size.y
	var keep := 170.0
	var cap := sidebar_h - keep
	if sidebar_h <= keep + 220.0:
		cap = nat
	var target := minf(nat, maxf(cap, 140.0))
	if not is_equal_approx(_trade_tray.custom_minimum_size.y, target):
		_trade_tray.custom_minimum_size.y = target
	if not _tray_height_recheck:
		_tray_height_recheck = true
		var t := get_tree().create_timer(0.05)
		t.timeout.connect(func() -> void:
			_tray_height_recheck = false
			_update_tray_height()
		)

func _set_log_open(on: bool) -> void:
	_log_toggle_btn.set_pressed_no_signal(on)
	_log_toggle_btn.icon = _chevron_icon(on)
	_log_toggle_btn.tooltip_text = "Hide the log" if on else "Show the full log"
	if on:
		_log_panel.custom_minimum_size = Vector2(0, 200)
		_log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		_log_panel.custom_minimum_size = Vector2(0, 48)
		_log_panel.size_flags_vertical = Control.SIZE_FILL

func _build_offer_strip(root_vbox: VBoxContainer) -> void:
	_offer_strip = PanelContainer.new()
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(0)
	st.shadow_size = 0
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	_offer_strip.add_theme_stylebox_override("panel", st)
	_offer_strip.visible = false
	root_vbox.add_child(_offer_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_offer_strip.add_child(row)
	_offer_strip_label = Label.new()
	_offer_strip_label.add_theme_font_size_override("font_size", 13)
	_offer_strip_label.add_theme_color_override("font_color", Palette.HEADING)
	row.add_child(_offer_strip_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_offer_strip_chips = HBoxContainer.new()
	_offer_strip_chips.add_theme_constant_override("separation", 6)
	row.add_child(_offer_strip_chips)

func _refresh_offer_strip(state: GameState) -> void:
	if _offer_strip == null:
		return
	var ot: Dictionary = state.open_trade
	var ot_open := not ot.is_empty()
	_offer_strip.visible = ot_open
	if not ot_open:
		return
	var from_p := int(ot.get("from", -1))
	var from_name := GameTypes.PLAYER_NAMES[from_p] if from_p >= 0 and from_p < state.players.size() else "?"
	if from_p >= 0 and from_p < state.players.size():
		from_name = str(state.players[from_p].get("name", GameTypes.PLAYER_NAMES[from_p]))
	_offer_strip_label.text = "%s offers %s for %s" % [
		from_name,
		_format_resource_bundle(ot.get("offer", {})),
		_format_resource_bundle(ot.get("request", {})),
	]
	for c in _offer_strip_chips.get_children():
		c.queue_free()
	var responses: Dictionary = ot.get("responses", {})
	for p_id in range(state.players.size()):
		if p_id == from_p:
			continue
		var pname := str(state.players[p_id].get("name", GameTypes.PLAYER_NAMES[p_id]))
		if not responses.has(p_id):
			_offer_strip_chips.add_child(_make_pill("%s: waiting…" % pname, Palette.PAPER_DARK, Palette.TEXT_MUTED))
			continue
		var resp: Dictionary = responses[p_id]
		match str(resp.get("status", "")):
			"accept":
				_offer_strip_chips.add_child(_make_pill("%s: ✓ accepts" % pname, Palette.PAPER_DARK, Palette.ACCENT_GREEN.darkened(0.25)))
			"decline":
				_offer_strip_chips.add_child(_make_pill("%s: ✗ declines" % pname, Palette.PAPER_DARK, Palette.ACCENT_RED.darkened(0.1)))
			"counter":
				if _declined_counters.has(p_id):
					_offer_strip_chips.add_child(_make_pill(
						"%s: ✗ counter declined" % pname, Palette.PAPER_DARK, Palette.ACCENT_RED.darkened(0.1)
					))
				else:
					_offer_strip_chips.add_child(_make_pill(
						"%s: ↺ counters" % pname, Palette.PAPER_DARK, Palette.HEADING
					))

func _refresh_trade_tray(state: GameState, acting_id: int, human_acting: bool) -> void:
	if _trade_tray == null:
		return
	var ot: Dictionary = state.open_trade
	var ot_open := not ot.is_empty()
	if _trade_last_ot_open and not ot_open:
		_reset_trade_counts()
		_trade_reopen_token = ""
		_set_trade_hint(false)
		var was_my_offer := _trade_last_ot_from == _view_pid()
		if (_trade_opened_auto or was_my_offer) and _trade_tray.visible:
			_set_tray_panel_visible(false)
			_release_tray_focus()
		_trade_opened_auto = false
		_trade_last_ot_from = -1
	_trade_last_ot_open = ot_open
	var from_p := int(ot.get("from", -1))
	var my_pid := _view_pid()
	var from_me_show := ot_open and from_p == my_pid
	var respond := ot_open and human_acting and from_p != acting_id

	# The tray is the viewed human's workspace: once they are neither the
	# proposer nor the acting responder (their turn ended, bots negotiate on
	# their own), it closes — the offer strip keeps the news visible.
	if ot_open and _trade_tray.visible and from_p != my_pid and acting_id != my_pid:
		_set_tray_panel_visible(false)
		_release_tray_focus()
	if not respond:
		_set_trade_hint(false)
	if ot_open:
		_trade_last_ot_from = from_p
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
		if from_me:
			_trade_reopen_token = ""
			_set_trade_hint(false)
			_set_tray_panel_visible(true)
		elif _trade_reopen_token != _ot_dismiss_key(ot, my_pid):
			var was_tray_open := _trade_tray.visible
			_set_tray_panel_visible(true)
			if respond and not was_tray_open:
				_trade_opened_auto = true
	if respond and not _trade_tray.visible and acting_id == my_pid:
		_set_trade_hint(true)

	var counter := respond and _trade_counter_mode
	var propose_idle := (not respond) and (not from_me_show)
	var editing_own_offer := from_me and (not counter)

	var title := "Trade"
	if respond:
		var from_name := str(state.players[from_p].get("name", GameTypes.PLAYER_NAMES[from_p]))
		title = "%s offers %s for %s" % [
			from_name,
			_format_resource_bundle(ot.get("offer", {})),
			_format_resource_bundle(ot.get("request", {})),
		]
	elif from_me_show:
		title = "Your offer: %s for %s" % [
			_format_resource_bundle(ot.get("offer", {})),
			_format_resource_bundle(ot.get("request", {})),
		]
	_trade_title_lbl.text = title

	_trade_respond_view.visible = respond and (not counter)
	if respond and (not counter):
		_fill_ro_row(_trade_ro_get_box, ot.get("offer", {}), {})
		_fill_ro_row(_trade_ro_give_box, ot.get("request", {}), _missing_for_bundle(state, ot.get("request", {})))
		var have_parts: Array[String] = []
		var hand: Dictionary = state.players[acting_id].get("hand", {})
		for r in GameTypes.ALL_RESOURCES:
			var want_amt: int = int(ot.get("request", {}).get(r, 0))
			if want_amt > 0:
				have_parts.append("%d %s" % [int(hand.get(r, 0)), GameTypes.resource_name(r)])
		_trade_have_label.text = "You have: %s" % " + ".join(have_parts)

	var own_has_answer := false
	if ot_open and from_me:
		own_has_answer = not (ot.get("responses", {}) as Dictionary).is_empty()
	_trade_rows_col.visible = (
		propose_idle or counter or (editing_own_offer and not own_has_answer)
	)
	_trade_partner_stack.visible = (not respond) and (not counter)

	var propose_ok := (
		human_acting
		and state.phase == GameTypes.TurnPhase.TURN_MAIN
		and not ot_open
	)
	var unlocked := propose_ok or counter or from_me
	if unlocked:
		var hand2: Dictionary = state.players[acting_id].get("hand", {}) if human_acting else _trade_hand()
		for r in GameTypes.ALL_RESOURCES:
			_trade_give_counts[r] = clampi(int(_trade_give_counts.get(r, 0)), 0, int(hand2.get(r, 0)))
	_rebuild_trade_chip_rows(unlocked and state.phase == GameTypes.TurnPhase.TURN_MAIN)

	var give_total := _trade_side_total(_trade_give_counts)
	var get_total := _trade_side_total(_trade_get_counts)

	_trade_btn_row.visible = propose_idle or editing_own_offer or counter
	_trade_ask_btn.visible = propose_idle
	_trade_counter_row.visible = counter
	_ot_send_btn.visible = counter
	_ot_back_btn.visible = counter
	var offer_cap_hit := state.open_trades_this_turn >= RulesEngine.MAX_OPEN_TRADES_PER_TURN
	var sides_differ := _trade_side_key(true) != _trade_side_key(false)
	_trade_ask_btn.disabled = not (propose_ok and give_total > 0 and get_total > 0 and sides_differ) or (propose_ok and offer_cap_hit)
	if propose_ok and offer_cap_hit:
		_trade_ask_btn.tooltip_text = "No offers left this turn"
	else:
		_trade_ask_btn.tooltip_text = "Post this offer to every other player"
	_trade_ratio_btn.visible = propose_idle and unlocked and not _bank_selection_check(state, my_pid).is_empty()
	if _trade_ratio_btn.visible:
		var ratio_res := _trade_side_resource(_trade_give_counts)
		var ratio_v := state.get_trade_ratio(my_pid, ratio_res)
		_trade_ratio_btn.text = "Port 2:1" if ratio_v == 2 else ("Port 3:1" if ratio_v == 3 else "Bank 4:1")
	_trade_resend_btn.visible = editing_own_offer and not own_has_answer
	if editing_own_offer:
		var ot_key := "%s>%s" % [
			_trade_offer_key(ot.get("offer", {})),
			_trade_offer_key(ot.get("request", {})),
		]
		var draft_key := "%s>%s" % [_trade_side_key(true), _trade_side_key(false)]
		var changed := draft_key != ot_key
		_trade_resend_btn.disabled = (
			offer_cap_hit or give_total <= 0 or get_total <= 0 or (not sides_differ) or (not changed)
		)
		if offer_cap_hit:
			_trade_resend_btn.tooltip_text = "No offers left this turn"
		else:
			_trade_resend_btn.tooltip_text = "Cancel this offer and post the new one"
	_trade_offers_lbl.visible = propose_idle or editing_own_offer
	if _trade_offers_lbl.visible:
		if offer_cap_hit:
			_trade_offers_lbl.text = "%d of %d offers used" % [
				RulesEngine.MAX_OPEN_TRADES_PER_TURN, RulesEngine.MAX_OPEN_TRADES_PER_TURN
			]
		else:
			_trade_offers_lbl.text = "Offers this turn: %d of %d" % [
				state.open_trades_this_turn, RulesEngine.MAX_OPEN_TRADES_PER_TURN
			]
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
	if _hand_hidden() and _trade_tray.visible:
		_set_tray_panel_visible(false)
	if _trade_tray.visible:
		_update_tray_height.call_deferred()

func _rebuild_partner_cards(state: GameState, ot: Dictionary, ot_open: bool, human_can_pick: bool, _show_bank: bool) -> void:
	if _trade_partner_stack == null:
		return
	for c in _trade_partner_stack.get_children():
		c.queue_free()
	var takers_checked := 0
	var takers_declined := 0
	var any_counter := false
	var self_id := _trade_dash_pid()
	for idx in range(state.players.size()):
		if idx == self_id:
			continue
		var p_data: Dictionary = state.players[idx]
		var p_id: int = int(p_data.get("id", idx))
		var status := "\u2014"
		var status_color := Palette.TEXT_MUTED
		var can_trade := false
		var counter_resp: Dictionary = {}
		if ot_open:
			if p_id == int(ot.get("from", -1)):
				status = "Offering\u2026"
				status_color = Palette.HEADING
			else:
				takers_checked += 1
				var responses: Dictionary = ot.get("responses", {})
				if not responses.has(p_id):
					status = "Waiting\u2026"
					status_color = Palette.TEXT_MUTED
				else:
					var resp: Dictionary = responses[p_id]
					var st_str := str(resp.get("status", ""))
					if st_str == "accept":
						status = "\u2713 Accepts"
						status_color = Palette.ACCENT_GREEN.darkened(0.25)
						can_trade = true
					elif st_str == "decline":
						status = "\u2717 Declines"
						status_color = Palette.ACCENT_RED.darkened(0.1)
						takers_declined += 1
					elif st_str == "counter":
						counter_resp = resp
						any_counter = true
						if bool(_declined_counters.get(p_id, false)):
							takers_declined += 1
		var pname := str(p_data.get("name", GameTypes.PLAYER_NAMES[p_id]))
		var pcol: Color = GameTypes.PLAYER_COLORS[p_id]
		if not counter_resp.is_empty():
			if int(ot.get("from", -1)) == _view_pid() and not _counter_toasted.has(p_id):
				_counter_toasted[p_id] = true
				_show_toast("%s counters: wants %s for %s" % [
					pname,
					_format_resource_bundle(counter_resp.get("offer", {})),
					_format_resource_bundle(counter_resp.get("request", {})),
				], Palette.ACCENT_GOLD.darkened(0.2))
			_trade_partner_stack.add_child(
				_make_counter_partner_card(pname, pcol, p_id, counter_resp, state, bool(_declined_counters.get(p_id, false)))
			)
			continue
		var parts := _make_partner_panel(pname, pcol, Palette.PANEL_BORDER)
		var row1: HBoxContainer = parts[2]
		var st_lbl := Label.new()
		st_lbl.text = status
		st_lbl.add_theme_font_size_override("font_size", 10)
		st_lbl.add_theme_color_override("font_color", status_color)
		st_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		st_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		st_lbl.clip_text = true
		st_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row1.add_child(st_lbl)
		var t_btn := _make_card_trade_button("Complete the trade with %s" % pname)
		t_btn.visible = can_trade
		t_btn.disabled = not can_trade or not human_can_pick
		if can_trade:
			var partner := p_id
			t_btn.pressed.connect(func() -> void: _submit_human_action(GameAction.finalize_open_trade(partner)))
		row1.add_child(t_btn)
		(parts[0] as Control).tooltip_text = "%s \u2014 %s" % [pname, status]
		_trade_partner_stack.add_child(parts[0])
	var no_takers := (
		ot_open and int(ot.get("from", -1)) == _view_pid()
		and takers_checked > 0 and takers_declined == takers_checked
	)
	if _trade_no_takers_lbl != null:
		_trade_no_takers_lbl.visible = no_takers
	_counter_cards_shown = any_counter

func _missing_for_bundle(state: GameState, bundle: Dictionary) -> Dictionary:
	var missing := {}
	var hand: Dictionary = state.players[_view_pid()].get("hand", {})
	for r in GameTypes.ALL_RESOURCES:
		var want := int(bundle.get(r, 0))
		if want <= 0:
			continue
		var short := want - int(hand.get(r, 0))
		if short > 0:
			missing[r] = short
	return missing


func _make_partner_panel(pname: String, swatch_color: Color, border: Color) -> Array:
	var card := PanelContainer.new()
	var cst := _paper_panel_style(true)
	cst.set_corner_radius_all(7)
	cst.set_border_width_all(1)
	cst.border_color = border
	cst.shadow_color = Color(0, 0, 0, 0)
	cst.content_margin_left = 5
	cst.content_margin_right = 5
	cst.content_margin_top = 2
	cst.content_margin_bottom = 2
	card.add_theme_stylebox_override("panel", cst)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 5)
	col.add_child(row1)
	var sw := ColorRect.new()
	sw.custom_minimum_size = Vector2(10, 10)
	sw.color = swatch_color
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(sw)
	var name_lbl := Label.new()
	name_lbl.text = pname
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	name_lbl.custom_minimum_size = Vector2(48, 0)
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(name_lbl)
	return [card, col, row1]

func _mini_trade_face(res: int, cnt: int, missing: bool) -> CardFace:
	var f := CardFace.new()
	f.kind = "resource"
	f.resource = res
	f.custom_minimum_size = Vector2(26, 32)
	f.show_name = false
	f.vivid = true
	f.focusable = false
	f.focus_mode = Control.FOCUS_NONE
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.disabled = missing
	f.tooltip_text = "%s \u00d7%d" % [GameTypes.resource_name(res), cnt]
	return f

func _add_mini_side(box: HBoxContainer, title: String, bundle: Dictionary, missing: Dictionary) -> void:
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 9)
	t.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(t)
	for r in GameTypes.ALL_RESOURCES:
		var want := int(bundle.get(r, 0))
		if want <= 0:
			continue
		box.add_child(_mini_trade_face(r, want, missing.has(r)))
		if want > 1:
			var xn := Label.new()
			xn.text = "\u00d7%d" % want
			xn.add_theme_font_size_override("font_size", 9)
			xn.add_theme_color_override("font_color", Palette.TEXT)
			xn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			xn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(xn)

func _make_counter_partner_card(
	pname: String,
	pcol: Color,
	p_id: int,
	resp: Dictionary,
	state: GameState,
	declined: bool
) -> PanelContainer:
	var parts := _make_partner_panel(pname, pcol, Palette.ACCENT_GOLD)
	var card: PanelContainer = parts[0]
	var col: VBoxContainer = parts[1]
	var row1: HBoxContainer = parts[2]
	var cst: StyleBoxFlat = (card.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	cst.set_border_width_all(2)
	cst.border_color = Palette.ACCENT_GOLD
	card.add_theme_stylebox_override("panel", cst)
	var tag := Label.new()
	tag.text = "COUNTER-OFFER"
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", Palette.HEADING.darkened(0.15))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(tag)
	var missing := _missing_for_bundle(state, resp.get("offer", {}))
	card.tooltip_text = "%s \u2014 counter-offer: gives %s for your %s" % [
		pname,
		_format_resource_bundle(resp.get("request", {})),
		_format_resource_bundle(resp.get("offer", {})),
	]
	if declined:
		var dl := Label.new()
		dl.text = "\u2717 Counter declined"
		dl.add_theme_font_size_override("font_size", 10)
		dl.add_theme_color_override("font_color", Palette.ACCENT_RED.darkened(0.1))
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(dl)
		return card
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 3)
	col.add_child(row2)
	_add_mini_side(row2, "You give", resp.get("offer", {}), missing)
	var arrow := Label.new()
	arrow.text = "\u2192"
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_child(arrow)
	_add_mini_side(row2, "You get", resp.get("request", {}), {})
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(spacer)
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(58, 24)
	accept_btn.add_theme_font_size_override("font_size", 10)
	_style_button(accept_btn, "primary")
	_flatten_trade_button(accept_btn)
	if missing.is_empty():
		accept_btn.tooltip_text = "Accept %s's counter-offer" % pname
		accept_btn.pressed.connect(func() -> void: _submit_human_action(GameAction.finalize_open_trade(p_id)))
	else:
		accept_btn.disabled = true
		accept_btn.tooltip_text = "You don't have %s" % _format_resource_bundle(missing)
	row2.add_child(accept_btn)
	var decline_btn := Button.new()
	decline_btn.text = "Decline"
	decline_btn.custom_minimum_size = Vector2(56, 24)
	decline_btn.add_theme_font_size_override("font_size", 10)
	_style_button(decline_btn, "ghost")
	_flatten_trade_button(decline_btn)
	decline_btn.tooltip_text = "Dismiss %s's counter-offer" % pname
	decline_btn.pressed.connect(func() -> void:
		_declined_counters[p_id] = true
		_refresh_ui()
	)
	row2.add_child(decline_btn)
	return card

func _make_card_trade_button(tip: String) -> Button:
	var b := Button.new()
	b.text = "Trade"
	b.custom_minimum_size = Vector2(0, 24)
	b.add_theme_font_size_override("font_size", 10)
	b.tooltip_text = tip
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_button(b, "primary")
	_flatten_trade_button(b)
	return b

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
	if _trade_side_key(true) == _trade_side_key(false):
		return
	_submit_human_action(GameAction.open_trade(_trade_give_counts.duplicate(), _trade_get_counts.duplicate()))

func _on_resend_offer_pressed() -> void:
	if session == null or session.state == null:
		return
	var st := session.state
	var ot: Dictionary = st.open_trade
	if ot.is_empty() or int(ot.get("from", -1)) != session.get_acting_player_id():
		return
	if _trade_side_total(_trade_give_counts) <= 0 or _trade_side_total(_trade_get_counts) <= 0:
		return
	var give_draft := _trade_give_counts.duplicate()
	var get_draft := _trade_get_counts.duplicate()
	var cancel_res: Dictionary = session.submit_action(session.get_acting_player_id(), GameAction.cancel_open_trade())
	if not bool(cancel_res.get("ok", false)):
		return
	session.submit_action(session.get_acting_player_id(), GameAction.open_trade(give_draft, get_draft))

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

func _hand_card_tooltip(state: GameState, res: int, hand_hidden: bool, held: int) -> String:
	if hand_hidden:
		return "Hand is hidden"
	if state.phase == GameTypes.TurnPhase.TURN_DISCARD:
		return "Click to pick a card to discard"
	if not _is_human_acting():
		return "Not your turn"
	if state.phase == GameTypes.TurnPhase.TURN_ROLL:
		return "Roll first"
	if not state.open_trade.is_empty():
		return "Reply to the open offer first"
	if held <= 0:
		return "No %s in hand" % GameTypes.resource_name(res)
	return "Click to offer in a trade"


func _on_resource_card_pressed(res: int) -> void:
	if session == null or session.state == null:
		return
	if _hand_hidden():
		return
	var st := session.state
	if st.phase == GameTypes.TurnPhase.TURN_DISCARD:
		_discard_pick_one(res)
		return
	if not (
		_is_human_acting()
		and st.phase == GameTypes.TurnPhase.TURN_MAIN
	):
		return
	if not st.open_trade.is_empty():
		if int(st.open_trade.get("from", -1)) != session.get_acting_player_id():
			if not _trade_tray.visible:
				_trade_reopen_token = ""
				_set_trade_hint(false)
				_set_tray_panel_visible(true)
				_refresh_ui()
			return
	if not _trade_tray.visible:
		_toggle_trade_tray()
		if not _trade_tray.visible:
			return
	_adjust_trade_count(true, res, 1)

func _cancel_current_pick() -> void:
	_close_steal_chooser()
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

static func _seg_dist(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var vx := bx - ax
	var vy := by - ay
	var wx := px - ax
	var wy := py - ay
	var tt := clampf((wx * vx + wy * vy) / maxf(0.0001, vx * vx + vy * vy), 0.0, 1.0)
	var dx := px - (ax + vx * tt)
	var dy := py - (ay + vy * tt)
	return sqrt(dx * dx + dy * dy)

func _make_icon_tex(size_px: int, half: float, paint: Callable) -> ImageTexture:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	for py in range(size_px):
		for px in range(size_px):
			var cov := 0
			for sy in range(4):
				for sx in range(4):
					var fx := float(px) + (float(sx) + 0.5) / 4.0
					var fy := float(py) + (float(sy) + 0.5) / 4.0
					if bool(paint.call(fx - half, fy - half)):
						cov += 1
			img.set_pixel(px, py, Color(1.0, 1.0, 1.0, float(cov) / 16.0))
	var tex := ImageTexture.create_from_image(img)
	return tex

func _skip_icon() -> ImageTexture:
	if _skip_icon_tex == null:
		_skip_icon_tex = _make_icon_tex(16, 8.0, func(x: float, y: float) -> bool:
			if x >= 2.5 and x <= 4.0 and y >= -5.0 and y <= 5.0:
				return true
			if x < -5.0 or x > 1.5:
				return false
			var lim := (1.5 - x) * (5.0 / 6.5)
			return y >= -lim and y <= lim
		)
	return _skip_icon_tex

func _chevron_icon(up: bool) -> ImageTexture:
	if up:
		if _chevron_up_tex == null:
			_chevron_up_tex = _make_icon_tex(16, 8.0, func(x: float, y: float) -> bool:
				return _seg_dist(x, y, -4.5, 2.0, 0.0, -2.5) < 1.7 or _seg_dist(x, y, 0.0, -2.5, 4.5, 2.0) < 1.7
			)
		return _chevron_up_tex
	if _chevron_down_tex == null:
		_chevron_down_tex = _make_icon_tex(16, 8.0, func(x: float, y: float) -> bool:
			return _seg_dist(x, y, -4.5, -2.0, 0.0, 2.5) < 1.7 or _seg_dist(x, y, 0.0, 2.5, 4.5, -2.0) < 1.7
		)
	return _chevron_down_tex

func _make_played_glyph(card_type: int, cnt: int, highlight: bool, tip: String) -> Control:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 1)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.tooltip_text = tip
	var face := CardFace.new()
	face.kind = "action"
	face.action = card_type
	face.emblem_only = true
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.custom_minimum_size = Vector2(18, 18.0 / CardFace.RATIO)
	cell.add_child(face)
	var cnt_lbl := Label.new()
	cnt_lbl.text = str(cnt)
	cnt_lbl.add_theme_font_size_override("font_size", 10)
	cnt_lbl.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	cnt_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(cnt_lbl)
	if not highlight:
		return cell
	var wrap := PanelContainer.new()
	var ws := StyleBoxFlat.new()
	ws.border_color = Palette.ACCENT_GOLD
	ws.set_border_width_all(2)
	ws.set_corner_radius_all(6)
	ws.content_margin_left = 1
	ws.content_margin_right = 1
	ws.content_margin_top = 0
	ws.content_margin_bottom = 0
	wrap.add_theme_stylebox_override("panel", ws)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.tooltip_text = tip
	wrap.add_child(cell)
	return wrap

func _make_road_glyph(route_len: int, highlight: bool) -> Control:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 1)
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.tooltip_text = "Longest route: %d roads" % route_len
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(16, 24)
	var pts := PackedVector2Array([Vector2(3, 18), Vector2(13, 6)])
	var outline := Line2D.new()
	outline.points = pts
	outline.width = 8.0
	outline.default_color = Palette.INK
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	icon.add_child(outline)
	var fill := Line2D.new()
	fill.points = pts
	fill.width = 4.5
	fill.default_color = Color(0.58, 0.44, 0.30)
	fill.begin_cap_mode = Line2D.LINE_CAP_ROUND
	fill.end_cap_mode = Line2D.LINE_CAP_ROUND
	icon.add_child(fill)
	cell.add_child(icon)
	var cnt_lbl := Label.new()
	cnt_lbl.text = str(route_len)
	cnt_lbl.add_theme_font_size_override("font_size", 10)
	cnt_lbl.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	cnt_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(cnt_lbl)
	if not highlight:
		return cell
	var wrap := PanelContainer.new()
	var ws := StyleBoxFlat.new()
	ws.border_color = Palette.ACCENT_GOLD
	ws.set_border_width_all(2)
	ws.set_corner_radius_all(6)
	ws.content_margin_left = 1
	ws.content_margin_right = 1
	ws.content_margin_top = 0
	ws.content_margin_bottom = 0
	wrap.add_theme_stylebox_override("panel", ws)
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.tooltip_text = "Longest route: %d roads" % route_len
	wrap.add_child(cell)
	return wrap

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

func _flatten_trade_button(btn: Button) -> void:
	for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb: StyleBoxFlat = (btn.get_theme_stylebox(st_name) as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
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


func _start_dice_roll_fx(state: GameState) -> void:
	var a := int(state.last_dice.x)
	var b := int(state.last_dice.y)
	if _reduce_motion or _flight_layer == null or _board_view == null or _dice_widget == null or not _dice_widget.is_inside_tree():
		_dice_widget.set_motion_enabled(not _reduce_motion)
		_dice_widget.animate_roll(a, b)
		return
	var bot_rolled := false
	var cur := int(state.current_player)
	if cur >= 0 and cur < session.seats.size() and session.seats[cur].is_ai():
		bot_rolled = true
	var hold_s := 0.6 if (bot_rolled and _settings_speed_idx >= 2) else 1.5
	_start_dice_show(a, b, hold_s)

func _start_dice_show(a: int, b: int, hold_s: float) -> void:
	if _dice_show_active:
		_finish_dice_show()
	_dice_show_count += 1
	_dice_show_active = true
	_dice_show_phase = "throw"
	_dice_total_visible = false
	_dice_widget.total_visible = false
	_dice_show_seat = session.state.current_player if session != null and session.state != null else -1
	_dice_show_return_len = 0.4
	_dice_show_vals = Vector2i(a, b)
	_dice_show_hold = hold_s
	_dice_show_t = 0.0
	_dice_show_popped = false
	_dice_show_face_k = [-1, -1]
	_dice_show_face_t = [0.0, 0.0]
	var fx := DiceShowFX.new()
	fx.show_caption = false
	fx.focus_mode = Control.FOCUS_NONE
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flight_layer.add_child(fx)
	fx.size = fx.custom_minimum_size
	_dice_show_node = fx
	var from_c := _to_ui_local(_dice_widget.get_global_rect().get_center())
	var br := _board_view.get_global_rect()
	var half := fx.size * 0.5
	var tx := br.position.x + br.size.x * 0.84
	var ty := br.position.y + br.size.y * 0.84
	if br.size.x > half.x * 2.0 + 8.0:
		tx = clampf(tx, br.position.x + half.x + 4.0, br.end.x - half.x - 4.0)
	else:
		tx = br.position.x + br.size.x * 0.5
	if br.size.y > half.y * 2.0 + 8.0:
		ty = clampf(ty, br.position.y + half.y + 4.0, br.end.y - half.y - 4.0)
	else:
		ty = br.position.y + br.size.y * 0.5
	var to_c := _to_ui_local(Vector2(tx, ty))
	var dw := DiceShowFX.DICE_SIZE
	_dice_show_from = [
		from_c + Vector2(-(dw * 0.5 + 6.5), 0.0),
		from_c + Vector2(dw * 0.5 + 6.5, 0.0),
	]
	_dice_show_to = [
		to_c + Vector2(-dw * 0.8, 0.0),
		to_c + Vector2(dw * 0.8, 0.0),
	]
	_dice_show_slot = [
		from_c + Vector2(-(dw * 0.5 + 6.5), 0.0),
		from_c + Vector2(dw * 0.5 + 6.5, 0.0),
	]
	_dice_show_spin = [TAU * 2.5, -TAU * 2.2]
	_dice_show_apex = [dw * 2.6, dw * 2.1]
	fx.ground_y = [_dice_show_to[0].y, _dice_show_to[1].y]
	_advance_dice_show(0.0)

func _process(delta: float) -> void:
	if _dice_show_active:
		_advance_dice_show(delta)

func _cut_dice_show_hold() -> void:
	if not _dice_show_active:
		return
	if _dice_show_phase == "return" or _dice_show_phase == "":
		return
	_dice_show_hold = maxf(0.0, _dice_show_t - 1.10)
	_dice_show_return_len = 0.25

func _advance_dice_show(dt: float) -> void:
	if not _dice_show_active:
		return
	var fx := _dice_show_node as DiceShowFX
	if fx == null or not is_instance_valid(fx):
		_finish_dice_show()
		return
	_dice_show_t += dt
	var t := _dice_show_t
	var throw_end := 0.45
	var bounce_end := 0.95
	var settle_end := 1.10
	var hold_end := settle_end + _dice_show_hold
	var return_end := hold_end + _dice_show_return_len
	if t >= return_end:
		_end_dice_show(fx)
		return
	if t < throw_end:
		_dice_show_phase = "throw"
	elif t < bounce_end:
		_dice_show_phase = "bounce"
	elif t < settle_end:
		_dice_show_phase = "settle"
	elif t < hold_end:
		_dice_show_phase = "hold"
	else:
		_dice_show_phase = "return"
	var a := _dice_show_vals.x
	var b := _dice_show_vals.y
	var finals := [a, b]
	var dw := DiceShowFX.DICE_SIZE
	for i in range(2):
		var stagger := 0.0 if i == 0 else 0.05
		var local := t - stagger
		var spin: float = _dice_show_spin[i]
		var apex: float = _dice_show_apex[i]
		var center: Vector2 = _dice_show_to[i]
		var rot := 0.0
		var sc := Vector2(1.3, 1.3)
		var hfrac := 0.0
		if local < 0.0:
			center = _dice_show_from[i]
			fx.faces[i] = finals[i]
			fx.centers[i] = center
			fx.rots[i] = 0.0
			fx.scales[i] = Vector2.ONE
			fx.heights[i] = 0.0
			continue
		if t < throw_end:
			var u := clampf(local / throw_end, 0.0, 1.0)
			center = _dice_show_from[i].lerp(_dice_show_to[i], u * u * (3.0 - 2.0 * u))
			var arc := sin(PI * u) * apex
			center.y -= arc
			hfrac = clampf(arc / maxf(apex, 1.0), 0.0, 1.0)
			rot = spin * u
			sc = Vector2.ONE.lerp(Vector2(1.3, 1.3), u)
			var k := int(local / 0.06)
			if k != _dice_show_face_k[i]:
				_dice_show_face_k[i] = k
				_dice_show_face_t[i] = local
				fx.faces[i] = randi_range(1, 6)
		elif t < bounce_end:
			var tb := local - (throw_end - stagger)
			var arc2 := 0.0
			if tb < 0.28:
				arc2 = sin(PI * clampf(tb / 0.28, 0.0, 1.0)) * dw * 0.5
			elif tb < 0.56:
				arc2 = sin(PI * clampf((tb - 0.28) / 0.28, 0.0, 1.0)) * dw * 0.2
			hfrac = clampf(arc2 / maxf(dw * 0.5, 1.0), 0.0, 1.0)
			rot = spin * 0.06 * sin(tb * 14.0)
			var squish := Vector2.ONE
			if absf(tb - 0.28) < 0.05 or absf(tb - 0.56) < 0.05:
				squish = Vector2(1.08, 0.88)
			sc = Vector2(1.3, 1.3) * squish
			var interval := lerpf(0.06, 0.14, clampf(tb / 0.56, 0.0, 1.0))
			if tb >= _dice_show_face_t[i] + interval:
				_dice_show_face_t[i] = tb
				fx.faces[i] = randi_range(1, 6)
		elif t < settle_end:
			var su := clampf((local - (bounce_end - stagger)) / 0.15, 0.0, 1.0)
			rot = fx.rots[i] * (1.0 - su)
			center = _dice_show_to[i]
			fx.faces[i] = finals[i]
		elif t < hold_end:
			var hu := clampf((t - settle_end) / 0.15, 0.0, 1.0)
			sc = Vector2(1.3, 1.3).lerp(Vector2(1.25, 1.25), hu)
			fx.faces[i] = finals[i]
			if a == b:
				fx.outline = Color(Palette.ACCENT_GOLD, 0.55 + 0.4 * sin(_dice_show_t * 12.0))
			elif a + b == 7:
				fx.outline = Color(Palette.ACCENT_RED, 0.75)
		else:
			var ru := clampf((t - hold_end) / maxf(_dice_show_return_len, 0.05), 0.0, 1.0)
			var ease := ru * ru * (3.0 - 2.0 * ru)
			center = _dice_show_to[i].lerp(_dice_show_slot[i], ease)
			sc = Vector2(1.25, 1.25).lerp(Vector2.ONE, ease)
			fx.faces[i] = finals[i]
			fx.outline = Color(0, 0, 0, 0)
		fx.centers[i] = center
		fx.rots[i] = rot
		fx.scales[i] = sc
		fx.heights[i] = hfrac
	fx.queue_redraw()

func _end_dice_show(w: Control) -> void:
	_dice_show_node = null
	_dice_show_active = false
	_dice_show_phase = ""
	_dice_total_visible = true
	if _dice_widget != null and is_instance_valid(_dice_widget):
		_dice_widget.d1 = _dice_show_vals.x
		_dice_widget.d2 = _dice_show_vals.y
		_dice_widget.total_visible = true
		_dice_show_popped = true
		_dice_widget.pill_pop_t = 0.0
		_dice_widget.queue_redraw()
	_restore_dice_bar()
	if is_instance_valid(w):
		w.free()

func _finish_dice_show() -> void:
	if _dice_show_node != null and is_instance_valid(_dice_show_node):
		_dice_show_node.free()
	_dice_show_node = null
	_dice_show_active = false
	_dice_show_phase = ""
	_dice_total_visible = true
	if _dice_widget != null and is_instance_valid(_dice_widget):
		_dice_widget.d1 = _dice_show_vals.x if _dice_show_vals.x > 0 else _dice_widget.d1
		_dice_widget.d2 = _dice_show_vals.y if _dice_show_vals.y > 0 else _dice_widget.d2
		_dice_widget.total_visible = true
	_restore_dice_bar()

class DiceShowFX extends DicePairWidget:
	var faces: Array[int] = [1, 1]
	var centers: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	var rots: Array[float] = [0.0, 0.0]
	var scales: Array[Vector2] = [Vector2.ONE, Vector2.ONE]
	var heights: Array[float] = [0.0, 0.0]
	var outline: Color = Color(0, 0, 0, 0)
	var ground_y: Array[float] = [0.0, 0.0]

	func _draw() -> void:
		var half := DICE_SIZE * 0.5
		for i in range(2):
			var c: Vector2 = centers[i]
			var h: float = heights[i]
			var sx := half * (1.0 - 0.35 * h)
			var sy := half * (0.52 - 0.16 * h)
			var sa := 0.42 * (1.0 - 0.30 * h)
			var gy: float = maxf(ground_y[i], c.y)
			var ground := Vector2(c.x, gy + half * 1.18)
			var poly := PackedVector2Array()
			for k in range(12):
				var a2 := TAU * float(k) / 12.0
				poly.append(ground + Vector2(cos(a2) * sx, sin(a2) * sy))
			draw_colored_polygon(poly, Color(0.12, 0.09, 0.06, sa))
		for i in range(2):
			var c2: Vector2 = centers[i]
			draw_set_transform(c2, rots[i], scales[i])
			_draw_die(Vector2(-half, -half), faces[i])
			if outline.a > 0.01:
				draw_rect(Rect2(-half - 2.5, -half - 2.5, DICE_SIZE + 5.0, DICE_SIZE + 5.0), outline, false, 2.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _restore_dice_bar() -> void:
	if _dice_widget != null and is_instance_valid(_dice_widget):
		_dice_widget.modulate.a = 1.0
		_dice_widget.mouse_filter = Control.MOUSE_FILTER_STOP

# =====================================================================
# Custom drawn 2d6 dice widget (the roll control)
# =====================================================================
class DicePairWidget extends Control:
	const DICE_SIZE := 44.0
	const DICE_GAP := 13.0
	const PILL_W := 70.0
	const PILL_H := 34.0

	signal pressed

	var d1: int = 0
	var d2: int = 0
	var motion_enabled := true
	var show_caption := true
	var _rolling := false
	var _roll_enabled := false
	var _roll_timer: Timer = null
	var _ticks_left := 0
	var _final_d1 := 0
	var _final_d2 := 0
	var _pulse_alpha := 0.55
	var _pulse_tween: Tween = null
	var total_visible := true
	var pill_pop_t := -1.0

	func pill_text() -> String:
		if not total_visible:
			return "\u2026"
		var s := d1 + d2
		return str(s) if s > 0 else "-"

	func _process(delta: float) -> void:
		if pill_pop_t >= 0.0:
			pill_pop_t += delta
			if pill_pop_t > 0.2:
				pill_pop_t = -1.0
			queue_redraw()

	func _ready() -> void:
		var full_w := DICE_SIZE * 2.0 + DICE_GAP + 8.0 + PILL_W + 10.0
		custom_minimum_size = Vector2(full_w, 78.0)
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
		var bf1 := d1 if total_visible else 0
		var bf2 := d2 if total_visible else 0
		_draw_die(Vector2(0.0, top), bf1)
		_draw_die(Vector2(DICE_SIZE + DICE_GAP, top), bf2)
		if not total_visible:
			draw_rect(Rect2(Vector2(-2.0, top - 2.0), Vector2(DICE_SIZE * 2.0 + DICE_GAP + 4.0, DICE_SIZE + 4.0)), Color(Palette.PAPER, 0.55))

		var pill_pos := Vector2(DICE_SIZE * 2.0 + DICE_GAP + 8.0, top + (DICE_SIZE - PILL_H) * 0.5)
		var pill_rect := Rect2(pill_pos, Vector2(PILL_W, PILL_H))
		var pbox := StyleBoxFlat.new()
		if _rolling:
			pbox.bg_color = Color(Palette.ACCENT_GOLD, 0.55)
		else:
			pbox.bg_color = Palette.PAPER_DARK
		pbox.border_color = Palette.INK if total_visible else Color(Palette.INK, 0.55)
		pbox.set_border_width_all(2)
		pbox.set_corner_radius_all(int(PILL_H * 0.5))

		var font := ThemeDB.fallback_font
		if font == null:
			_redraw_rings()
			return
		if not total_visible:
			draw_style_box(pbox, pill_rect)
			for k in range(3):
				draw_circle(pill_rect.get_center() + Vector2((float(k) - 1.0) * 9.0, 0.0), 2.4, Color(Palette.INK, 0.65))
			if show_caption and _roll_enabled:
				draw_string(font, Vector2(0.0, size.y - 4.0), "Click to roll", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.HEADING)
			_redraw_rings()
			return
		var txt := pill_text()
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 19)
		var ps := 1.0
		if pill_pop_t >= 0.0:
			ps = 1.0 + 0.2 * sin(PI * clampf(pill_pop_t / 0.2, 0.0, 1.0))
		draw_set_transform(pill_rect.get_center(), 0.0, Vector2(ps, ps))
		draw_style_box(pbox, Rect2(-pill_rect.size * 0.5, pill_rect.size))
		draw_string(
			font,
			Vector2(-pill_rect.size.x * 0.5, ts.y * 0.30),
			txt,
			HORIZONTAL_ALIGNMENT_CENTER,
			pill_rect.size.x,
			19,
			Palette.INK
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		if show_caption and total_visible:
			if _roll_enabled:
				draw_string(font, Vector2(0.0, size.y - 4.0), "Click to roll", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.HEADING)
			elif d1 + d2 > 0:
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
