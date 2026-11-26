extends Control

var session: LocalSession = null
var auto_ai: bool = true

var _ai_timer: Timer = null
var _pending_guard_card: bool = false
var _steal_pending: Dictionary = {}
var _steal_victims: Array[int] = []
const FPS_ACTIVE := 60
const FPS_IDLE := 30
const FPS_IDLE_AFTER_S := 2.0
const CARD_FLIGHT_SECONDS := 0.7
const STEAL_FLIGHT_SECONDS := 1.0
const SCOREBOARD_ROW_SHADOW_SIZE := 1
const SCOREBOARD_ROW_BORDER := 1

static var fps_cap_override: int = -1

var _fps_idle_timer := 0.0

var _toast_layer: VBoxContainer = null
var _toast_labels: Array[Label] = []
var _offer_strip: PanelContainer = null
var _offer_strip_row: HBoxContainer = null
var _offer_strip_spacer: Control = null
var _offer_strip_label: Label = null
var _offer_strip_chips: HBoxContainer = null
var _trade_close_btn: Button = null
var _offer_strip_respond_btn: Button = null
var _ro_pools: Dictionary = {}
var _ro_none_labels: Dictionary = {}
var _give_chip_pool: Array[CardFace] = []
var _partner_rebuild_key := ""
var _partner_rebuild_deferred := false
var _strip_rebuild_key := ""
var _chip_hover_texts: Dictionary = {}
var _banner_hover_active := false
var _trade_scroll: ScrollContainer = null
var _trade_last_ot_from: int = -1
var _last_steal_serial: int = 0
var _hand_count_hold: Dictionary = {}
var _res_hold: Dictionary = {}
var _scoreboard_mini_hands: Dictionary = {}
var _scoreboard_mini_acts: Dictionary = {}
var _prev_dev_counts: Array = []
var _dev_spawn_queue: Array = []
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
var _splash_quit_btn: Button = null
var _splash_review_btn: Button = null
var _review_active := false
var _real_session: LocalSession = null
var _review_session: ReviewSession = null
var _review_replay: MatchReplay = null
var _review_step := 0
var _review_view_pid := 0
var _review_playing := false
var _review_play_acc := 0.0
var _review_speed := 1
var _review_applying := false
var _review_bar: HBoxContainer = null
var _review_bar_box: VBoxContainer = null
var _review_prev_banner := ""
var _review_saved_log_lines: Array[String] = []
var _review_slider_ticks: ReviewSliderTicks = null
var _review_from_list := false
var _splash_save_btn: Button = null
var _review_save_btn: Button = null
var _replay_saved_path := ""
var _replays_overlay: ColorRect = null
var _replays_list_box: VBoxContainer = null
var _review_slider: HSlider = null
var _review_step_lbl: Label = null
var _review_caption: Label = null
var _review_play_btn: Button = null
var _review_speed_opt: OptionButton = null
var _review_hidden_nodes: Array[Control] = []
var _review_hidden_was: Array[bool] = []
var _sb_row_slot_pid: Dictionary = {}
var _results_btn: Button = null
var _splash_shown: bool = false
var _menu_popup: PopupMenu = null
var _style_btn: Button = null
var _step_top_btn: Button = null

# Main split
var _board_view: BoardView = null
var _center_split: HBoxContainer = null
var _scoreboard_box: VBoxContainer = null
var _sb_focus_overlay: ScoreboardFocusOverlay = null
var _sb_focus_tween: Tween = null
var _sb_focus_card: Control = null
var _sb_focus_pcol: Color = Color(0, 0, 0, 0)
var _bank_faces: Dictionary = {}
var _bank_deck_face: CardFace = null
var _status_banner_label: Label = null

# Bottom visual card hand bar
var _hand_bar_panel: PanelContainer = null
var _res_card_refs: Dictionary = {}
var _action_chips: Dictionary = {}
var _sidebar_box: VBoxContainer = null
var _header_panel: Control = null
var _sea_band: Control = null
var _header_pill: PanelContainer = null
var _toast_host: Control = null
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
var _trade_watch_col: VBoxContainer = null
var _watch_terms_give_box: HBoxContainer = null
var _watch_terms_get_box: HBoxContainer = null
var _watch_rows_col: VBoxContainer = null
var _watch_rows_key: String = ""
var _watch_row_prev_status: Dictionary = {}
var _watch_row_prev_ticks: Dictionary = {}
var _revise_reopened_token: String = ""
var _trade_revise_pid: int = -1
var _trade_was_answerer := false
var _rev_badge_anim: Dictionary = {}
var _rev_badge_token: String = ""
var _rev_pulsed: Dictionary = {}
var _rev_spin_taken: Dictionary = {}
var _seen_win_size := Vector2(-1, -1)
var _rev_pulse_wraps: Array = []
var _rev_wrap_by_pid: Dictionary = {}
var _rev_pulse_pending_pid := -1
var _layout_needs_apply := true
var _ot_pace_token := ""
var _ot_pace_seen_count := -1
var _ot_hold_until_ms := 0
var _ot_snap_token := ""
var _ot_snap: Dictionary = {}
var _ot_result_active := false
var _ot_result_until_ms := 0
var _ot_result_header := ""
var _ot_result_rows: Array = []
var _ot_result_made_pid := -1
var _blocker_ghost: Panel = null
var _ot_result_give: Dictionary = {}
var _ot_result_get: Dictionary = {}
var _trade_respond_row: HBoxContainer = null
var _trade_ro_get_box: HBoxContainer = null
var _trade_ro_give_box: HBoxContainer = null
var _trade_rows_col: VBoxContainer = null
var _trade_give_box: HBoxContainer = null
var _trade_get_faces: Dictionary = {}
var _trade_give_hint_lbl: Label = null
var _trade_get_box: HBoxContainer = null
var _trade_body_row: HBoxContainer = null
var _trade_rail_w := 150.0
var _trade_left_col: VBoxContainer = null
var _trade_right_col: VBoxContainer = null
var _band_side: Dictionary = {}
var _band_stack: Dictionary = {}
var _band_box_a: Dictionary = {}
var _band_box_b: Dictionary = {}
var _band_side_a: Dictionary = {}
var _band_side_b: Dictionary = {}
var _band_row_a: Dictionary = {}
var _band_row_b: Dictionary = {}
var _band_gate: Dictionary = {}
var _band_cap_a := {}
var _band_cap_b := {}
var _band_st_cap_a := {}
var _band_st_cap_b := {}
var _box_n: Dictionary = {}
var _trade_btn_row: HBoxContainer = null
var _trade_counter_row: HBoxContainer = null
var _trade_give_counts: Dictionary = {}
var _trade_get_counts: Dictionary = {}
var _trade_ask_btn: Button = null
var _trade_ratio_btn: Button = null
var _trade_resend_btn: Button = null
var _trade_offers_lbl: Label = null
var _trade_clear_btn: Button = null
# p50c: the bank button's holder (see _make_tray_button_slot) and the measured
# width it reserves while a plain offer is being drafted.
var _trade_ratio_slot: MarginContainer = null
var _trade_bank_slot_width := 0.0
var _trade_bank_slot_reserve := false
const TRADE_BANK_LABELS: Array[String] = ["Bank 4:1", "Port 2:1", "Port 3:1", "Bank / Port"]
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
var _no_takers_since_ms: int = 0
var _no_takers_token: String = ""
var _no_takers_keep_draft: bool = false
var _fresh_trade_next_click: bool = false
var _trade_view_pid: int = -1
var _trade_opened_auto: bool = false
var _trade_hint_tween: Tween = null

# Context sub-panels (Harvest Bounty, Trade Decree)
var _subpanel_container: PanelContainer = null
var _subpanel_owner_pid: int = -1
var _subpanel_scrim: Control = null
var _popup_chip_by_type: Dictionary = {}
var _subpanel_chip: Control = null

var _bounty_box: VBoxContainer = null
var _bounty_res1_opt: OptionButton = null
var _bounty_res2_opt: OptionButton = null

var _decree_box: VBoxContainer = null
var _decree_res_opt: OptionButton = null

# Event log
const LOG_MAX_LINES := 400
const LOG_TRIM_SLACK := 50

var _log_lines: Array[String] = []

var _event_log: RichTextLabel = null
var _log_panel: PanelContainer = null
var _log_toggle_btn: Button = null
var _right_panel: PanelContainer = null
var _trade_slot: PanelContainer = null
var _trade_frame: Panel = null
var _trade_idle_lbl: Label = null
var _trade_host: Control = null
var _trade_chip_size_dirty := false
var _log_popup: PanelContainer = null
var _log_popup_text: RichTextLabel = null
var _hand_overlay: Control = null
var _bar_locked := false
var _scoreboard_row_slots: Array[Control] = []
var _sb_row_key := ""
var _scoreboard_row_parts: Dictionary = {}
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
var _help_text: RichTextLabel = null
var _help_heading_hex: String = ""
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
var _ui_style: String = "paper"
var _settings_hex_opt: OptionButton = null
var _settings_token_opt: OptionButton = null
var _settings_step_btn: Button = null
var _settings_ai_difficulty: int = 2
var _settings_muted: bool = false
var _settings_text_idx: int = 0
var _settings_speed_idx: int = 1
var _reduce_motion: bool = false
var _win_stage: int = 0
var _win_stage_t: float = 0.0
var _win_scale: float = 1.0
var _win_pid: int = -1
var _win_layer: Control = null
var _win_skip_catcher: ColorRect = null
var _win_banner: ColorRect = null
var _win_banner_label: Label = null
var _win_rows: Array[Control] = []
var _win_vp_labels: Array[Label] = []
var _win_vp_values: Array[int] = []
var _win_winner_row: int = -1
var _win_charter_total: int = 0
var _win_charter_nodes: Array[CardFace] = []
var _win_charter_starts: Array[Vector2] = []
var _win_charter_landed: Array[bool] = []
var _win_plus_one_nodes: Array[Label] = []
var _win_plus_one_land_at: Array[float] = []
var _win_plus_one_spawned: int = 0
var _win_elapsed: float = 0.0
var _win_confetti = null
var _win_confetti_t0: float = 0.0
var _splash_center: CenterContainer = null
var _splash_panel: PanelContainer = null
var _splash_btn_row: HBoxContainer = null

static var settings_path: String = "user://settings.cfg"
static var turn_min_seconds_override: float = -1.0
static var trade_pace_override: float = -1.0
static var DEV_WINDOW_WIDTH_OVERRIDE: float = 0.0
const TEXT_SCALE_VALUES: Array[float] = [1.0, 1.15, 1.3]
const BOT_SPEED_VALUES: Array[float] = [0.6, 0.25, 0.08]

# Win sequence timings, all in seconds at normal speed. Stage numbers: 0 = none,
# 1..4 = the stages, 5 = done. Every duration below is scaled once, at the start of
# the run, by WIN_SPEED_MULTIPLIER (fastest bot speed) and by win_sequence_override
# (tests), so the stage bodies only ever see these raw numbers.
const WIN_STAGE_NONE := 0
const WIN_STAGE_SPOTLIGHT := 1
const WIN_STAGE_CHARTERS := 2
const WIN_STAGE_BANNER := 3
const WIN_STAGE_STANDINGS := 4
const WIN_STAGE_DONE := 5
const WIN_SPOTLIGHT_SECONDS := 0.8
const WIN_SPOTLIGHT_FADE_SECONDS := 0.25
const WIN_CHARTER_SECONDS_EACH := 0.45
const WIN_CHARTER_HOLD_SECONDS := 0.35
const WIN_CHARTER_FLY_SECONDS := 0.4
const WIN_CHARTER_MAX_FAN := 5
const WIN_CHARTER_CARD_PX := 96.0
const WIN_CHARTER_SPACING_PX := 108.0
const WIN_CHARTER_FAN_MARGIN_PX := 12.0
const WIN_CHARTER_FAN_MIN_SCALE := 0.02
const WIN_CHARTER_ARC_PX := 30.0
const WIN_CHARTER_POP_SECONDS := 0.16
const WIN_CHARTER_POP_SCALE := 0.12
const WIN_CHARTER_FADE_SECONDS := 0.25
const WIN_PLUS_ONE_FONT_SIZE := 30
const WIN_PLUS_ONE_SECONDS := 0.6
const WIN_PLUS_ONE_FLOAT_PX := 28.0
const WIN_BANNER_SECONDS := 0.5
const WIN_CONFETTI_SECONDS := 1.6
const WIN_CONFETTI_COUNT := 90
const WIN_CONFETTI_SPAWN_SECONDS := 0.5
const WIN_CONFETTI_PIECE_W := 6.0
const WIN_CONFETTI_PIECE_H := 10.0
const WIN_CONFETTI_CREAM := Color(0.97, 0.93, 0.83)
const WIN_BANNER_MIN_CONTRAST := 4.5
const WIN_BANNER_SPLIT_LUMINANCE := 0.2
const WIN_BANNER_TEXT_CREAM := Color(0.97, 0.93, 0.83)
const WIN_BANNER_TEXT_WHITE := Color(1.0, 1.0, 1.0)
const WIN_BANNER_TEXT_INK := Color(0.29, 0.22, 0.169)
const WIN_BANNER_TEXT_NEAR_BLACK := Color(0.10, 0.07, 0.05)
const WIN_STANDINGS_SECONDS := 1.6
const WIN_BANNER_EXIT_SECONDS := 0.25
const WIN_PANEL_RISE_SECONDS := 0.3
const WIN_ROW_STAGGER_SECONDS := 0.25
const WIN_ROW_FADE_SECONDS := 0.2
const WIN_VP_COUNT_SECONDS := 0.4
const WIN_BUTTONS_FADE_SECONDS := 0.2
const WIN_ROW_POP_SECONDS := 0.24
const WIN_SPEED_MULTIPLIER := 0.6
const WIN_PANEL_RISE_PX := 24.0
const WIN_BANNER_HEIGHT_PX := 128.0
const WIN_BANNER_ABOVE_MIDDLE_PX := 40.0
const WIN_BANNER_FONT_SIZE := 46
const WIN_BANNER_FIT_FONT_MIN := 28
const WIN_BANNER_FIT_MARGIN_PX := 24.0
const WIN_BANNER_TITLE_OUTLINE_PX := 6
const WIN_BANNER_START_SCALE := 0.6
const WIN_ROW_POP_SCALE := 1.06
static var win_sequence_override: float = -1.0

func _ready() -> void:
	_sfx = Sfx.new()
	_sfx.name = "Sfx"
	add_child(_sfx)
	randomize()
	_load_settings()
	Palette.apply_style(_ui_style)
	_build_ui_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session = LocalSession.new()
	session.state_updated.connect(_on_state_updated)
	session.action_rejected.connect(_on_action_rejected)

	_build_ui()
	resized.connect(_on_window_resized)
	var _init_win := get_window()
	if _init_win != null:
		_init_win.size_changed.connect(_apply_trade_chip_sizes)
	call_deferred("_apply_window_layout")
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
	_maybe_withdraw_dead_offer()
	if _steal_anim_active():
		return
	if not auto_ai or session == null or session.state == null:
		return
	if _any_overlay_visible():
		return
	if session.is_ai_to_act():
		if _trade_hold_active():
			return
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

	# p40: the header band paints nothing, so this layer — drawn below
	# root_vbox but above the flat SEA background — continues the board's
	# painted sea (same foam rings and wave arcs, same geometry) up to y = 0
	# across the full window width and behind the sidebar's rounded top
	# corners. The opaque board/sidebar/hand cover it everywhere else, so the
	# only visible parts are the band and the two corner cut-outs, and the
	# rings cross y = 52 without a seam. Clicks pass through to the band as
	# before.
	_sea_band = Control.new()
	_sea_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sea_band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sea_band.draw.connect(_on_sea_band_draw)
	add_child(_sea_band)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	# 1. Top Bar: p40 removes the 52 px band's paint entirely (nothing is drawn
	# by the band itself; the sea behind it continues to y = 0, see _sea_band)
	# and floats one rounded pill inside it, island-style, with large side
	# margins.
	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	top_panel.custom_minimum_size = Vector2(0, 52)
	_header_panel = top_panel
	_header_panel.resized.connect(_apply_window_layout)
	_header_panel.resized.connect(_layout_top_bar)
	root_vbox.add_child(top_panel)
	var top_host := Control.new()
	top_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_child(top_host)
	_header_pill = PanelContainer.new()
	var pill_style := _paper_panel_style(true)
	pill_style.bg_color = Palette.SURFACE_RAISED
	pill_style.set_corner_radius_all(20)
	pill_style.set_border_width_all(1)
	pill_style.border_color = Palette.PANEL_LINE
	pill_style.shadow_color = Palette.SHADOW_RAISED
	# The 6 px gap under the pill only fits a shadow reach of offset 1 + size 4
	# (the raised boxes' 7+2 = 9 px would run past the band), so the pill uses
	# the same shadow colour with a reduced size.
	pill_style.shadow_size = 4
	pill_style.shadow_offset = Vector2(0, 1)
	pill_style.content_margin_left = 14
	pill_style.content_margin_right = 14
	pill_style.content_margin_top = 0
	pill_style.content_margin_bottom = 0
	_header_pill.add_theme_stylebox_override("panel", pill_style)
	top_host.add_child(_header_pill)
	_layout_top_bar()

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	_header_pill.add_child(top_hbox)

	_menu_btn = Button.new()
	_menu_btn.text = "☰"
	_menu_btn.tooltip_text = "Menu (M)"
	_menu_btn.custom_minimum_size = Vector2(44, 34)
	_menu_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_help_costs_btn.custom_minimum_size = Vector2(40, 34)
	_help_costs_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_help_costs_btn.add_theme_font_size_override("font_size", 18)
	_style_button(_help_costs_btn, "ghost")
	_help_costs_btn.pressed.connect(_open_costs_popup)
	top_hbox.add_child(_help_costs_btn)
	_results_btn = Button.new()
	_results_btn.text = "Results"
	_results_btn.tooltip_text = "Show the final standings"
	_results_btn.custom_minimum_size = Vector2(70, 34)
	_results_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_results_btn.add_theme_font_size_override("font_size", 13)
	_style_button(_results_btn, "ghost")
	_results_btn.visible = false
	_results_btn.pressed.connect(func() -> void:
		if _splash_overlay != null and _splash_shown:
			_splash_overlay.visible = true
	)
	var results_slot := Control.new()
	results_slot.custom_minimum_size = Vector2(74, 40)
	results_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_slot.add_child(_results_btn)
	top_hbox.add_child(results_slot)
	var title_lbl := Label.new()
	title_lbl.text = "Founders: Barter & Block"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Palette.HEADING)
	title_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_hbox.add_child(title_lbl)

	_status_banner_label = Label.new()
	_status_banner_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_status_banner_label.clip_text = true
	_status_banner_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_set_banner("Your turn — click the dice to roll.")
	_status_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_banner_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_banner_label.add_theme_font_size_override("font_size", 16)
	_status_banner_label.add_theme_color_override("font_color", Palette.TEXT)
	top_hbox.add_child(_status_banner_label)

	_phase_label = Label.new()
	_phase_label.custom_minimum_size = Vector2(58, 0)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_phase_label.text = "Turn 1"
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_phase_label.add_theme_font_size_override("font_size", 13)
	# p36: on the raised pill the muted colour drops to 3.9:1 in Dark, so the
	# turn counter uses the full text colour.
	_phase_label.add_theme_color_override("font_color", Palette.TEXT)
	top_hbox.add_child(_phase_label)

	_step_top_btn = Button.new()
	_step_top_btn.text = "Step bot"
	_step_top_btn.tooltip_text = "Make the current bot take one action"
	_step_top_btn.custom_minimum_size = Vector2(0, 34)
	_step_top_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_step_top_btn.add_theme_font_size_override("font_size", 13)
	_style_button(_step_top_btn, "ghost")
	_step_top_btn.visible = false
	_step_top_btn.pressed.connect(_step_bot_now)
	top_hbox.add_child(_step_top_btn)

	_style_btn = Button.new()
	_style_btn.text = ""
	_style_btn.custom_minimum_size = Vector2(44, 34)
	_style_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_btn.expand_icon = false
	_style_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_btn.clip_text = true
	_style_btn.add_theme_font_size_override("font_size", 13)
	_style_button(_style_btn, "ghost")
	_style_btn.pressed.connect(_toggle_ui_style)
	_refresh_style_btn()
	top_hbox.add_child(_style_btn)

	# 2. Center Split (left column: board + trade tray | right panel)
	_center_split = HBoxContainer.new()
	_center_split.add_theme_constant_override("separation", 0)
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
	_board_view.steal_target_clicked.connect(_on_steal_target_clicked)
	_board_view.build_spot_clicked.connect(_on_build_spot_clicked)
	_board_view.background_clicked.connect(_on_board_background_clicked)
	_board_view.resized.connect(_refresh_sea_band)
	left_column.add_child(_board_view)

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
	_build_costs_popup()
	_build_toast_layer()

	var right_panel := PanelContainer.new()
	_right_panel = right_panel
	right_panel.custom_minimum_size = Vector2(520, 0)
	var right_style := _paper_panel_style(true)
	right_style.set_corner_radius_all(0)
	# p40: the sidebar begins below the sea-filled header band, so its two top
	# corners are rounded (bottom stays square) and the sea shows through the
	# cut-off corner pixels.
	right_style.corner_radius_top_left = 12
	right_style.corner_radius_top_right = 12
	right_style.shadow_size = 0
	right_style.border_width_top = 0
	right_style.border_width_right = 0
	right_style.border_width_bottom = 0
	right_style.border_width_left = 1
	right_style.border_color = Palette.PANEL_LINE
	# The 12/10 px insets moved from the panel stylebox to the sidebar box's
	# theme margins, so the scroll viewport (the shadow clip) now spans the
	# whole panel while every box keeps its exact global rect.
	right_style.content_margin_left = 0
	right_style.content_margin_right = 0
	right_style.content_margin_top = 0
	right_style.content_margin_bottom = 0
	right_panel.add_theme_stylebox_override("panel", right_style)
	_center_split.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	_sidebar_box = right_vbox
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# 1 px, not 3: with a trade panel open the sidebar's fixed parts
	# (scoreboard, bank, headers, trade slot, event log at idle height)
	# need every pixel of the 1280x800 column, or a scrollbar appears.
	right_vbox.add_theme_constant_override("separation", 1)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sidebar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_panel.add_child(sidebar_scroll)
	# The 12/10 px insets live on this empty-stylebox wrapper instead of the
	# panel stylebox, so the scroll viewport (which clips drawing) spans the
	# whole panel and the raised boxes' drop shadows have room to render
	# while every box keeps its exact global rect.
	var sidebar_inset := PanelContainer.new()
	sidebar_inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inset_style := StyleBoxEmpty.new()
	inset_style.content_margin_left = 12
	inset_style.content_margin_right = 12
	inset_style.content_margin_top = 10
	inset_style.content_margin_bottom = 10
	sidebar_inset.add_theme_stylebox_override("panel", inset_style)
	sidebar_scroll.add_child(sidebar_inset)
	sidebar_inset.add_child(right_vbox)

	_hand_overlay = Control.new()
	_hand_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Player Scoreboard Section
	var sb_title := Label.new()
	sb_title.text = "PLAYER SCOREBOARD"
	sb_title.add_theme_font_size_override("font_size", 14)
	sb_title.add_theme_color_override("font_color", Palette.HEADING)
	sb_title.custom_minimum_size = Vector2(0, 18)
	sb_title.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	sb_title.add_theme_constant_override("line_spacing", -18)
	right_vbox.add_child(sb_title)

	_scoreboard_box = VBoxContainer.new()
	_scoreboard_box.add_theme_constant_override("separation", 4)
	_scoreboard_box.custom_minimum_size = Vector2(0, 148)
	right_vbox.add_child(_scoreboard_box)

	# Turn focus ring drawn ABOVE all scoreboard rows (later sibling of the
	# center split, so sidebar/scroll clipping cannot cut its outset edges).
	_sb_focus_overlay = ScoreboardFocusOverlay.new()
	_sb_focus_overlay.name = "ScoreboardFocusOverlay"
	_sb_focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb_focus_overlay.visible = false
	add_child(_sb_focus_overlay)
	_sb_focus_tween = _sb_focus_overlay.create_tween()
	_sb_focus_tween.set_loops()
	_sb_focus_tween.tween_method(_set_sb_focus_glow, 3.0, 9.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sb_focus_tween.tween_method(_set_sb_focus_glow, 9.0, 3.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sb_focus_tween.pause()

	# Bank supply section — how many resource cards are still in the bank.
	var bank_title := Label.new()
	bank_title.text = "BANK"
	bank_title.add_theme_font_size_override("font_size", 14)
	bank_title.add_theme_color_override("font_color", Palette.HEADING)
	bank_title.custom_minimum_size = Vector2(0, 18)
	bank_title.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	bank_title.add_theme_constant_override("line_spacing", -18)
	right_vbox.add_child(bank_title)

	var bank_row := HBoxContainer.new()
	bank_row.add_theme_constant_override("separation", 6)
	bank_row.custom_minimum_size = Vector2(0, 36.0 / CardFace.RATIO + CardFace.PILE_RESERVE)
	right_vbox.add_child(bank_row)
	for r in GameTypes.ALL_RESOURCES:
		var bcol := VBoxContainer.new()
		bcol.add_theme_constant_override("separation", 3)
		bank_row.add_child(bcol)
		var bf := CardFace.new()
		bf.custom_minimum_size = Vector2(36, 36.0 / CardFace.RATIO + CardFace.PILE_RESERVE)
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
	deck_face.custom_minimum_size = Vector2(42, 42.0 / CardFace.RATIO + CardFace.PILE_RESERVE)
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
	_cancel_pick_btn.custom_minimum_size = Vector2(0, 40)

	# Context sub-panels (Maritime, Barter, Bounty, Decree)
	_build_subpanels(_hand_overlay)

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
	log_title.custom_minimum_size = Vector2(0, 18)
	log_title.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	log_title.add_theme_constant_override("line_spacing", -18)
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
	_log_toggle_btn.toggled.connect(_set_log_open)
	log_header.add_child(_log_toggle_btn)

	_log_panel = _make_card_panel(Palette.SURFACE_RAISED)
	_log_panel.custom_minimum_size = Vector2(0, 64)
	right_vbox.add_child(_log_panel)

	_event_log = RichTextLabel.new()
	_event_log.bbcode_enabled = true
	_event_log.scroll_following = true
	_event_log.selection_enabled = true
	_event_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_rich_label(_event_log)
	_log_panel.add_child(_event_log)
	_apply_raised_card(_log_panel)

	# 3. Bottom Visual Card Hand Bar (always visible), with the open-offer strip above it
	_build_offer_strip(root_vbox)
	_build_hand_bar(root_vbox)
	add_child(_hand_overlay)
	_build_log_popup()

	# 4. Modal Overlays (lobby, settings, help — help is topmost)
	_build_lobby_overlay()
	_build_settings_overlay()
	_build_help_overlay()
	_build_replays_overlay()
	_build_splash_overlay()


func _build_hand_bar(root_vbox: VBoxContainer) -> void:
	_hand_bar_panel = PanelContainer.new()
	var st := _paper_panel_style()
	st.set_corner_radius_all(0)
	st.shadow_size = 0
	st.border_width_left = 0
	st.border_width_right = 0
	st.border_width_bottom = 0
	st.border_width_top = 1
	st.border_color = Palette.PANEL_LINE
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	_hand_bar_panel.add_theme_stylebox_override("panel", st)
	root_vbox.add_child(_hand_bar_panel)

	var bar_box := VBoxContainer.new()
	bar_box.add_theme_constant_override("separation", 2)
	_hand_bar_panel.add_child(bar_box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	bar_box.add_child(hb)
	_review_bar_box = bar_box

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

	# Discard prompt lives in the offer strip above the hand bar (never over
	# the hand cards): prompt text left, actions right.
	_discard_mode_box = HBoxContainer.new()
	_discard_mode_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_discard_mode_box.add_theme_constant_override("separation", 6)
	_discard_mode_box.visible = false
	_discard_mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_strip_row.add_child(_discard_mode_box)
	_discard_heading = Label.new()
	_discard_heading.add_theme_font_size_override("font_size", 14)
	_discard_heading.add_theme_color_override("font_color", Palette.TEXT)
	_discard_heading.clip_text = true
	_discard_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_discard_heading.custom_minimum_size = Vector2(110, 0)
	_discard_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discard_heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_discard_mode_box.add_child(_discard_heading)
	_discard_confirm_btn = Button.new()
	_discard_confirm_btn.text = "Discard"
	_discard_confirm_btn.custom_minimum_size = Vector2(80, 22)
	_discard_confirm_btn.add_theme_font_size_override("font_size", 12)
	_discard_confirm_btn.tooltip_text = "Discard the picked cards"
	_style_button(_discard_confirm_btn, "danger")
	_discard_confirm_btn.disabled = true
	_discard_confirm_btn.pressed.connect(_on_discard_confirm_pressed)
	_guard_action_button_focus(_discard_confirm_btn)
	_discard_auto_btn = Button.new()
	_discard_auto_btn.text = "Pick for me"
	_discard_auto_btn.custom_minimum_size = Vector2(88, 22)
	_discard_auto_btn.add_theme_font_size_override("font_size", 12)
	_discard_auto_btn.tooltip_text = "Fill the selection with a sensible choice"
	_style_button(_discard_auto_btn, "normal")
	_discard_auto_btn.pressed.connect(_on_discard_auto_fill_pressed)
	_guard_action_button_focus(_discard_auto_btn)
	_discard_mode_box.add_child(_discard_auto_btn)
	_discard_mode_box.add_child(_discard_confirm_btn)

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
		chip.mouse_entered.connect(_on_action_chip_hover.bind(ctype))
		chip.mouse_exited.connect(_on_action_chip_leave)
		hb.add_child(chip)
		_popup_chip_by_type[ctype] = chip
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
	_end_turn_btn.disabled = true
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	_guard_action_button_focus(_end_turn_btn)
	hb.add_child(_end_turn_btn)
	_build_review_bar(_review_bar_box)
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

func _make_subpanel_close() -> Button:
	# Same look as the round "x" on the trade panel's title line.
	var b := Button.new()
	b.name = "SubpanelClose"
	b.text = "\u2715"
	b.tooltip_text = "Close (Esc)"
	b.add_theme_font_size_override("font_size", 11)
	b.custom_minimum_size = Vector2(22, 22)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_button(b, "ghost")
	_flatten_trade_button(b)
	b.pressed.connect(_close_subpanel_from_outside)
	_guard_action_button_focus(b)
	return b

func _layout_subpanel() -> void:
	if _subpanel_container == null or not _subpanel_container.visible:
		return
	if _hand_bar_panel == null:
		return
	var br := _hand_bar_panel.get_global_rect()
	if br.size.y < 10.0:
		return
	var win := get_viewport_rect().size
	var w := minf(400.0, win.x - 8.0)
	_subpanel_container.custom_minimum_size = Vector2(w, 0)
	var mins := _subpanel_container.get_combined_minimum_size()
	var h := maxf(mins.y, 60.0)
	var cx := br.get_center().x
	if _subpanel_chip != null and is_instance_valid(_subpanel_chip) and _subpanel_chip.is_visible_in_tree():
		cx = _subpanel_chip.get_global_rect().get_center().x
	var x := clampf(cx - w * 0.5, 4.0, maxf(4.0, win.x - w - 4.0))
	var y := maxf(4.0, br.position.y - h - 4.0)
	_subpanel_container.size = Vector2(w, h)
	_subpanel_container.position = Vector2(x, y)

func _build_subpanels(parent: Control) -> void:
	# Full-window click-catcher under the sub-panel: any press outside the
	# sub-panel (board, sidebar, title bar, empty space) closes it and is
	# swallowed, so the closing click never also acts on the board.
	# Clicks inside the panel pass straight through; clicks on the hand bar
	# pass through untouched so action cards keep their own open/close and
	# play behaviour.
	_subpanel_scrim = Control.new()
	_subpanel_scrim.name = "SubpanelScrim"
	_subpanel_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_subpanel_scrim.visible = false
	_subpanel_scrim.gui_input.connect(_on_subpanel_scrim_input)
	parent.add_child(_subpanel_scrim)
	_subpanel_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_subpanel_container = _make_card_panel(Palette.PANEL_BG_ALT)
	_subpanel_container.visible = false
	parent.add_child(_subpanel_container)
	_subpanel_container.visibility_changed.connect(func() -> void:
		if _subpanel_scrim != null and is_instance_valid(_subpanel_scrim):
			_subpanel_scrim.visible = _subpanel_container.visible and _subpanel_container.is_visible_in_tree()
		if _subpanel_container.visible:
			_layout_subpanel()
	)

	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	_subpanel_container.add_child(holder)

	# Harvest Bounty subpanel
	_bounty_box = VBoxContainer.new()
	_bounty_box.visible = false
	holder.add_child(_bounty_box)
	var hb_head := HBoxContainer.new()
	hb_head.add_theme_constant_override("separation", 6)
	_bounty_box.add_child(hb_head)
	var hb_lbl := Label.new()
	hb_lbl.name = "BountyTitle"
	hb_lbl.text = "Harvest Bounty: Pick 2 Free Resources"
	hb_lbl.add_theme_font_size_override("font_size", 14)
	hb_lbl.add_theme_color_override("font_color", Palette.HEADING)
	hb_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb_head.add_child(hb_lbl)
	hb_head.add_child(_make_subpanel_close())
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
	var td_head := HBoxContainer.new()
	td_head.add_theme_constant_override("separation", 6)
	_decree_box.add_child(td_head)
	var td_lbl := Label.new()
	td_lbl.name = "DecreeTitle"
	td_lbl.text = "Trade Decree: Claim All of 1 Resource Type"
	td_lbl.add_theme_font_size_override("font_size", 14)
	td_lbl.add_theme_color_override("font_color", Palette.HEADING)
	td_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	td_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	td_head.add_child(td_lbl)
	td_head.add_child(_make_subpanel_close())
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
	_lobby_overlay.color = Color(Palette.SCRIM, 0.62)
	_lobby_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_lobby_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lobby_overlay.add_child(center)

	var modal := _make_card_panel(Palette.PANEL_BG, true)
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
		var sw := _make_seat_swatch(Vector2(18, 18))
		_set_seat_swatch_color(sw, GameTypes.PLAYER_COLORS[i])
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
	var replays_btn := Button.new()
	replays_btn.text = "Saved replays"
	replays_btn.tooltip_text = "Open matches you saved for later"
	replays_btn.custom_minimum_size = Vector2(120, 40)
	_style_button(replays_btn, "ghost")
	replays_btn.pressed.connect(_open_replays_list)
	btn_row.add_child(replays_btn)

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
	st.set_border_width_all(1)
	st.border_color = Palette.PANEL_LINE
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

func _toggle_ui_style() -> void:
	set_ui_style(Palette.next_style(Palette.current_style))


func _refresh_style_btn() -> void:
	if _style_btn == null:
		return
	_style_btn.icon = _style_toggle_icon()
	_style_btn.tooltip_text = "Switch to %s style" % Palette.style_label(Palette.next_style(Palette.current_style))


func _style_toggle_icon() -> ImageTexture:
	var kind := String(Palette.style_option("icon", "sun"))
	var paint := func(x: float, y: float) -> bool:
		var dist := sqrt(x * x + y * y)
		if kind == "moon":
			var ox := x - 7.0
			var oy := y + 6.5
			return dist <= 15.0 and not (ox * ox + oy * oy <= 13.5 * 13.5)
		if dist <= 12.5:
			return true
		if dist > 19.5:
			return false
		for a in [0.0, PI / 4.0, PI / 2.0, 3.0 * PI / 4.0]:
			var dx := cos(a)
			var dy := sin(a)
			var along := absf(x * dx + y * dy)
			var cross := absf(x * dy - y * dx)
			if along >= 15.0 and cross <= 2.4:
				return true
		return false
	var tex := _make_icon_tex(40, 20.0, paint)
	var img: Image = tex.get_image().duplicate()
	img.resize(20, 20)
	return ImageTexture.create_from_image(img)


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
	return _lobby_overlay.visible or _settings_overlay.visible or _help_overlay.visible or (_replays_overlay != null and _replays_overlay.visible) or (_splash_overlay != null and _splash_overlay.visible)

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
	_splash_overlay.color = Color(Palette.SPLASH_SCRIM, 0.62)
	_splash_overlay.visible = false
	add_child(_splash_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash_overlay.add_child(center)
	_splash_center = center
	var panel := PanelContainer.new()
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(12)
	st.set_border_width_all(1)
	st.border_color = Palette.PANEL_LINE
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
	_splash_review_btn = Button.new()
	_splash_review_btn.text = "Review match"
	_splash_review_btn.tooltip_text = "Step through the finished match with a slider"
	_splash_review_btn.custom_minimum_size = Vector2(120, 40)
	_style_button(_splash_review_btn, "ghost")
	_splash_review_btn.pressed.connect(_enter_review)
	btn_row.add_child(_splash_review_btn)
	_splash_save_btn = Button.new()
	_splash_save_btn.text = "Save for later"
	_splash_save_btn.tooltip_text = "Write this match to your saved replays"
	_splash_save_btn.custom_minimum_size = Vector2(140, 40)
	_style_button(_splash_save_btn, "ghost")
	_splash_save_btn.pressed.connect(_save_replay_pressed)
	btn_row.add_child(_splash_save_btn)
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
	_splash_quit_btn = Button.new()
	_splash_quit_btn.text = "Quit"
	_splash_quit_btn.tooltip_text = "Close the game"
	_splash_quit_btn.custom_minimum_size = Vector2(120, 40)
	_style_button(_splash_quit_btn, "ghost")
	_splash_quit_btn.pressed.connect(func() -> void:
		_win_sequence_cancel()
		get_tree().quit()
	)
	btn_row.add_child(_splash_quit_btn)
	_splash_btn_row = btn_row
	_splash_panel = panel
	_build_win_sequence_layer()

func _build_win_sequence_layer() -> void:
	_win_layer = Control.new()
	_win_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_layer.z_index = 3
	_win_layer.visible = false
	add_child(_win_layer)
	_win_skip_catcher = ColorRect.new()
	_win_skip_catcher.color = Color(0.0, 0.0, 0.0, 0.0)
	_win_skip_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_win_skip_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_win_skip_catcher.z_index = 4
	_win_skip_catcher.visible = false
	_win_skip_catcher.gui_input.connect(_on_win_catcher_input)
	add_child(_win_skip_catcher)

func _on_win_catcher_input(event: InputEvent) -> void:
	if _win_stage <= WIN_STAGE_NONE or _win_stage >= WIN_STAGE_DONE:
		return
	var hit := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		hit = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		hit = (event as InputEventScreenTouch).pressed
	if hit:
		_win_sequence_skip()
		get_viewport().set_input_as_handled()

# True when only one seat is human and the winner is a bot: the loss variant
# (no confetti, the shorter descending clip). 0 or 2+ human seats always celebrate.
func _win_is_win_variant() -> bool:
	return _win_variant_for_pid(_win_pid)

# The same decision for a given pid, usable before the splash build has set
# `_win_pid` (the GAME_OVER sound asks with `state.winner`).
func _win_variant_for_pid(pid: int) -> bool:
	if session == null or session.state == null:
		return true
	var humans := 0
	for s in session.seats:
		if s != null and not s.is_ai():
			humans += 1
	if humans != 1:
		return true
	return not (pid >= 0 and pid < session.seats.size() and session.seats[pid].is_ai())

# WIN_CONFETTI_COUNT small rectangles (winner colour, gold and cream) fall across the
# window for WIN_CONFETTI_SECONDS, drawn by one Control (see WinConfetti below) and
# added after the banner so they fall in front of it. The faller sits on `_win_layer`
# (z 3), above the results panel (z 2): the pieces are small, sparse and gone before
# the count-in ends, and every other temporary node of the sequence lives there too.
# Piece paths are pure functions of elapsed time over an RNG seeded from the match
# seed, so two runs of one seed land every piece in the same place. Never spawned by
# reduce motion, the instant override or the loss variant (this hook only runs in the
# win variant, and the instant paths never reach stage 3).
func _win_confetti_begin() -> void:
	if _reduce_motion or _win_layer == null or not is_instance_valid(_win_layer):
		return
	if session == null or session.state == null:
		return
	var win_size := get_viewport().get_visible_rect().size
	var cols: Array = []
	cols.append(GameTypes.PLAYER_COLORS[_win_pid] if _win_pid >= 0 else Palette.ACCENT_GOLD)
	cols.append(Palette.ACCENT_GOLD)
	cols.append(WIN_CONFETTI_CREAM)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(session.state.seed_val)
	var c := WinConfetti.new()
	c.piece_w = WIN_CONFETTI_PIECE_W
	c.piece_h = WIN_CONFETTI_PIECE_H
	for i in range(WIN_CONFETTI_COUNT):
		c.pieces.append({
			"x": rng.randf() * win_size.x,
			"y": -12.0 - rng.randf() * 30.0,
			"vx": (rng.randf() - 0.5) * 70.0,
			"vy": (win_size.y + 80.0) / WIN_CONFETTI_SECONDS * (0.85 + rng.randf() * 0.3),
			"spawn": rng.randf() * WIN_CONFETTI_SPAWN_SECONDS,
			"rot": rng.randf() * TAU,
			"spin": (rng.randf() - 0.5) * 9.0,
			"phase": rng.randf() * TAU,
			"sway": 2.5 + rng.randf() * 2.0,
			"col": cols[i % 3],
		})
	_win_layer.add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.z_index = 5
	_win_confetti = c
	_win_confetti_t0 = _win_elapsed

# Drives the faller from the sequence clock and frees it the frame its fall is over.
func _win_confetti_tick(e: float) -> void:
	if _win_confetti == null or not is_instance_valid(_win_confetti):
		return
	if e >= WIN_CONFETTI_SECONDS:
		var c: Node = _win_confetti
		_win_confetti = null
		_win_retire(c)
		return
	_win_confetti.set_elapsed(e)

func _show_splash(state: GameState) -> void:
	_splash_shown = true
	_replay_saved_path = ""
	_apply_save_buttons()
	_finish_steal_anim()
	_reset_flight_state()
	_build_splash_results(state)
	if _reduce_motion or (win_sequence_override >= 0.0 and win_sequence_override <= 0.001):
		_win_sequence_finish()
		return
	_win_sequence_start()

# Fills the results panel: title, turns line and one standings row per seat, winner
# first. Shared by the sequence and by every instant show, so both end in exactly the
# same node and text state.
func _build_splash_results(state: GameState) -> void:
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
	_win_pid = winner_pid
	_win_winner_row = 0 if winner_pid >= 0 else -1
	_win_rows.clear()
	_win_vp_labels.clear()
	_win_vp_values.clear()
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
		var sw := _make_seat_swatch(Vector2(10, 22))
		_set_seat_swatch_color(sw, GameTypes.PLAYER_COLORS[pid])
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
		_win_rows.append(hbox)
		_win_vp_labels.append(vp_lbl)
		_win_vp_values.append(int(row["vp"]))
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

# ---------------------------------------------------------------- win sequence
# One stage variable (`_win_stage`: 0 none, 1..4 the stages, 5 done) and one
# function that moves it forward (`_advance_win_sequence`). Each stage owns its
# _win_stage_*_begin/_apply/_end trio; every animation is computed from stage time.

func _win_sequence_start() -> void:
	_win_scale = win_sequence_override if win_sequence_override > 0.001 else 1.0
	if _settings_speed_idx >= 2:
		_win_scale *= WIN_SPEED_MULTIPLIER
	_splash_overlay.visible = false
	_results_btn.visible = false
	_win_set_splash_buttons_enabled(false)
	if _win_layer != null and is_instance_valid(_win_layer):
		_win_layer.visible = true
	if _win_skip_catcher != null and is_instance_valid(_win_skip_catcher):
		_win_skip_catcher.visible = true
	_win_charter_total = 0
	_win_charter_nodes.clear()
	_win_charter_starts.clear()
	_win_charter_landed.clear()
	_win_plus_one_nodes.clear()
	_win_plus_one_land_at.clear()
	_win_plus_one_spawned = 0
	_win_confetti = null
	_win_confetti_t0 = 0.0
	_win_elapsed = 0.0
	_win_stage = WIN_STAGE_SPOTLIGHT
	_win_stage_t = 0.0
	_win_enter_stage()
	_advance_win_sequence(0.0)

# Seconds the current stage runs at raw speed. Stage 2 lasts one card slot per held
# Charter card plus the hold; a winner without Charter cards gets 0 s, which the
# advance loop skips through inside one frame (the stage is then never observed).
func _win_stage_seconds() -> float:
	match _win_stage:
		WIN_STAGE_SPOTLIGHT:
			return WIN_SPOTLIGHT_SECONDS
		WIN_STAGE_CHARTERS:
			if _win_charter_total <= 0:
				return 0.0
			return WIN_CHARTER_SECONDS_EACH * float(_win_charter_total) + WIN_CHARTER_HOLD_SECONDS
		WIN_STAGE_BANNER:
			return WIN_BANNER_SECONDS
		WIN_STAGE_STANDINGS:
			return WIN_STANDINGS_SECONDS
		_:
			return 0.0

func _win_enter_stage() -> void:
	match _win_stage:
		WIN_STAGE_SPOTLIGHT:
			_win_stage_spotlight_begin()
		WIN_STAGE_CHARTERS:
			_win_stage_charters_begin()
		WIN_STAGE_BANNER:
			_win_stage_banner_begin()
		WIN_STAGE_STANDINGS:
			_win_stage_standings_begin()
		_:
			pass

func _win_leave_stage() -> void:
	match _win_stage:
		WIN_STAGE_SPOTLIGHT:
			_win_stage_spotlight_end()
		WIN_STAGE_CHARTERS:
			_win_stage_charters_end()
		WIN_STAGE_BANNER:
			_win_stage_banner_end()
		WIN_STAGE_STANDINGS:
			_win_stage_standings_end()
		_:
			pass

# The only function that advances the stage. `_win_stage_t` counts raw seconds since
# the current stage began and `_win_elapsed` raw seconds since the sequence began (the
# scale is applied to delta here), so the stage bodies only see the constants and
# animations that outlive a stage (the "+1" floaters, the confetti) can clock off
# `_win_elapsed`.
func _advance_win_sequence(delta: float) -> void:
	if _win_stage <= WIN_STAGE_NONE or _win_stage >= WIN_STAGE_DONE:
		return
	_win_stage_t += delta / maxf(_win_scale, 0.0001)
	_win_elapsed += delta / maxf(_win_scale, 0.0001)
	var guard := 0
	while _win_stage > WIN_STAGE_NONE and _win_stage < WIN_STAGE_DONE and guard < 12:
		guard += 1
		var dur := _win_stage_seconds()
		if _win_stage_t < dur:
			_win_apply_stage()
			return
		_win_stage_t -= dur
		_win_leave_stage()
		_win_stage += 1
		if _win_stage >= WIN_STAGE_DONE:
			_win_sequence_finish()
			return
		_win_enter_stage()
	if _win_stage > WIN_STAGE_NONE and _win_stage < WIN_STAGE_DONE:
		_win_apply_stage()

func _win_apply_stage() -> void:
	match _win_stage:
		WIN_STAGE_SPOTLIGHT:
			_win_stage_spotlight_apply(_win_stage_t)
		WIN_STAGE_CHARTERS:
			_win_stage_charters_apply(_win_stage_t)
		WIN_STAGE_BANNER:
			_win_stage_banner_apply(clampf(_win_stage_t / WIN_BANNER_SECONDS, 0.0, 1.0))
			_win_charter_fade_apply(_win_stage_t)
			_win_plus_one_apply(_win_elapsed)
			_win_confetti_tick(_win_elapsed - _win_confetti_t0)
		WIN_STAGE_STANDINGS:
			_win_stage_standings_apply(_win_stage_t)
			_win_plus_one_apply(_win_elapsed)
			_win_confetti_tick(_win_elapsed - _win_confetti_t0)
		_:
			pass

# Stage 1, board spotlight (WIN_SPOTLIGHT_SECONDS): strength fades 0 -> 1 over
# the first WIN_SPOTLIGHT_FADE_SECONDS and holds; the spotlight then stays on
# through stages 2 and 3 and is cleared by the step that starts stage 4 or by
# any early exit (finish / skip / cancel). No winner: nothing to light up.
func _win_stage_spotlight_begin() -> void:
	if _win_pid < 0:
		return
	_win_stage_spotlight_apply(0.0)

func _win_stage_spotlight_apply(t: float) -> void:
	if _board_view == null or not is_instance_valid(_board_view) or _win_pid < 0:
		return
	var k := clampf(t / WIN_SPOTLIGHT_FADE_SECONDS, 0.0, 1.0)
	_board_view.set_spotlight(_win_pid, k)

func _win_clear_spotlight() -> void:
	if _board_view != null and is_instance_valid(_board_view):
		_board_view.clear_spotlight()

# Leaving stage 1 keeps the spotlight: it stays on through stages 2 and 3 and is
# cleared when stage 4 begins or on any early exit.
func _win_stage_spotlight_end() -> void:
	pass

# Stage 2, charter reveal: one face-up Charter card per held card (cap of
# WIN_CHARTER_MAX_FAN) starts WIN_CHARTER_SECONDS_EACH apart, flies in
# WIN_CHARTER_FLY_SECONDS from the winner's action-card anchor to a
# WIN_CHARTER_SPACING_PX-spaced fan centred on the board view, lands with a small
# pop and holds. Each landing spawns a "+1" in the winner's colour that floats up
# and fades over WIN_PLUS_ONE_SECONDS. A fan of the full five cards is
# WIN_CHARTER_CARD_PX + 4 * WIN_CHARTER_SPACING_PX wide; when that (or the actual
# fan width, for fewer cards) would not fit the board view's live rect with a
# WIN_CHARTER_FAN_MARGIN_PX margin, card size and spacing scale down together just
# enough to fit (_win_charter_fan_scale). Slot positions and sizes are recomputed
# from the live rect every frame while the stage runs and during the fade, so a
# resize mid-stage keeps the fan centred and inside the board. The cards and labels
# live on `_win_layer`, not the flight layer: `_flight_layer` belongs to gameplay
# and `_reset_flight_state()` frees everything in it (a new match or lobby visit
# mid-sequence would kill the cards early), while `_win_layer_cleanup()` already
# frees every `_win_layer` child on finish, skip and cancel. Every position is
# computed from stage time here, never tweened, so nothing free-running is left.
func _win_stage_charters_begin() -> void:
	_win_charter_total = mini(_count_win_charters(), WIN_CHARTER_MAX_FAN)
	_win_charter_nodes.clear()
	_win_charter_starts.clear()
	_win_charter_landed.clear()
	_win_plus_one_nodes.clear()
	_win_plus_one_land_at.clear()
	if _win_charter_total <= 0 or _win_pid < 0 or _win_layer == null or not is_instance_valid(_win_layer):
		_win_charter_total = 0
		return
	var card_size := _win_charter_card_size()
	for i in range(_win_charter_total):
		_win_charter_starts.append(_win_charter_from(_win_pid))
		_win_charter_landed.append(false)
		var f := CardFace.new()
		f.focusable = false
		f.kind = "action"
		f.action = GameTypes.DevCardType.CHARTER_POINT
		f.show_name = false
		f.custom_minimum_size = card_size
		_win_layer.add_child(f)
		_set_ignore_tree(f)
		f.size = card_size
		f.pivot_offset = card_size * 0.5
		f.position = Vector2(_win_charter_starts[i]) - card_size * 0.5
		f.visible = i == 0
		f.z_index = 2
		_win_charter_nodes.append(f)
	_win_stage_charters_apply(0.0)

func _win_stage_charters_apply(t: float) -> void:
	for i in range(_win_charter_nodes.size()):
		var f: CardFace = _win_charter_nodes[i]
		if f == null or not is_instance_valid(f):
			continue
		var launch := float(i) * WIN_CHARTER_SECONDS_EACH
		if t < launch:
			if f.visible:
				f.visible = false
			continue
		if not f.visible:
			f.visible = true
		_win_charter_sync_size(f)
		var from: Vector2 = _win_charter_starts[i]
		var to: Vector2 = _win_charter_slot(i)
		var u := (t - launch) / WIN_CHARTER_FLY_SECONDS
		var pos := to
		if u < 1.0:
			pos = from.lerp(to, ease(u, 1.2))
			pos.y -= sin(u * PI) * WIN_CHARTER_ARC_PX
		else:
			var pt := t - (launch + WIN_CHARTER_FLY_SECONDS)
			var sc := 1.0
			if pt < WIN_CHARTER_POP_SECONDS:
				sc = 1.0 + WIN_CHARTER_POP_SCALE * sin(PI * pt / WIN_CHARTER_POP_SECONDS)
			f.scale = Vector2(sc, sc)
			if not bool(_win_charter_landed[i]):
				_win_charter_landed[i] = true
				_spawn_win_plus_one(i, _win_elapsed)
		f.position = pos - f.size * 0.5
	_win_plus_one_apply(_win_elapsed)

# The winner's held Charter cards, counted across played-so-far and bought-this-turn.
func _count_win_charters() -> int:
	if session == null or session.state == null or _win_pid < 0 or _win_pid >= session.state.players.size():
		return 0
	var p: Dictionary = session.state.players[_win_pid]
	var n := 0
	for c in p.get("dev_cards", []):
		if int(c) == GameTypes.DevCardType.CHARTER_POINT:
			n += 1
	for c in p.get("new_dev_cards", []):
		if int(c) == GameTypes.DevCardType.CHARTER_POINT:
			n += 1
	return n

func _win_charter_point_ok(p: Vector2) -> bool:
	return is_finite(p.x) and is_finite(p.y) and p != Vector2.INF and p != Vector2.ZERO

# Where the winner's action cards are shown; never (0,0) or an INF point: the
# scoreboard row centre takes over when the anchor is unavailable, the window
# centre is the last resort.
func _win_charter_from(pid: int) -> Vector2:
	var p := _dev_anchor(pid, GameTypes.DevCardType.CHARTER_POINT)
	if _win_charter_point_ok(p):
		return p
	var raw: Variant = _scoreboard_row_panels.get(pid, null)
	if raw is Control and is_instance_valid(raw) and (raw as Control).is_inside_tree():
		var row := _to_ui_local((raw as Control).get_global_rect().get_center())
		if _win_charter_point_ok(row):
			return row
	var vs := get_viewport().get_visible_rect().size
	if _win_charter_point_ok(vs * Vector2(0.5, 0.75)):
		return vs * Vector2(0.5, 0.75)
	return Vector2(8.0, 8.0)

# The board view's rect in layer coordinates; the window centre stands in when the
# board view is not in the tree (a cancel mid-sequence, a degenerate window).
func _win_charter_board_rect() -> Rect2:
	if _board_view != null and is_instance_valid(_board_view) and _board_view.is_inside_tree():
		var gr := _board_view.get_global_rect()
		return Rect2(_to_ui_local(gr.position), gr.size)
	return Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)

func _win_charter_fan_center() -> Vector2:
	return _win_charter_board_rect().get_center()

# How far the fan may grow: card width and spacing scale by this factor so a fan of
# `_win_charter_total` cards (worst case WIN_CHARTER_MAX_FAN) fits the board view's
# live width with WIN_CHARTER_FAN_MARGIN_PX on both sides. Never exceeds 1.0, never
# drops below WIN_CHARTER_FAN_MIN_SCALE (a degenerate tiny window keeps the nodes
# well-formed).
func _win_charter_fan_scale() -> float:
	if _win_charter_total <= 0:
		return 1.0
	var fan_w := WIN_CHARTER_CARD_PX + float(_win_charter_total - 1) * WIN_CHARTER_SPACING_PX
	var room := _win_charter_board_rect().size.x - 2.0 * WIN_CHARTER_FAN_MARGIN_PX
	return clampf(room / maxf(fan_w, 1.0), WIN_CHARTER_FAN_MIN_SCALE, 1.0)

func _win_charter_card_size() -> Vector2:
	var w := WIN_CHARTER_CARD_PX * _win_charter_fan_scale()
	return Vector2(w, w / CardFace.RATIO)

# Live centre of card i's fan slot; recomputed every frame so a resize mid-stage
# (and mid-fade) keeps the fan centred on the board.
func _win_charter_slot(i: int) -> Vector2:
	var fit := _win_charter_fan_scale()
	var offset := (float(i) - float(_win_charter_total - 1) * 0.5) * WIN_CHARTER_SPACING_PX * fit
	return _win_charter_fan_center() + Vector2(offset, 0.0)

func _win_charter_sync_size(f: Control) -> void:
	var s := _win_charter_card_size()
	if f.size != s:
		f.size = s
	if f.pivot_offset != s * 0.5:
		f.pivot_offset = s * 0.5

func _spawn_win_plus_one(i: int, at: float) -> void:
	if _win_layer == null or not is_instance_valid(_win_layer) or i >= _win_charter_total:
		return
	var l := Label.new()
	l.text = "+1"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", WIN_PLUS_ONE_FONT_SIZE)
	l.add_theme_color_override("font_color", GameTypes.PLAYER_COLORS[_win_pid] if _win_pid >= 0 else Palette.HEADING)
	l.add_theme_color_override("font_outline_color", WIN_BANNER_TEXT_NEAR_BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_layer.add_child(l)
	l.z_index = 3
	l.size = Vector2(64, 36)
	_win_plus_one_nodes.append(l)
	_win_plus_one_land_at.append(at)
	_win_plus_one_spawned += 1

# Floater position and fade, clocked off `_win_elapsed` so it runs past the end of
# stage 2; retired the frame its float is over. Anchored on the card's live fan
# slot, so the floaters follow the fan across a resize too.
func _win_plus_one_apply(now: float) -> void:
	for j in range(_win_plus_one_nodes.size()):
		var l: Label = _win_plus_one_nodes[j]
		if l == null or not is_instance_valid(l):
			continue
		var u := (now - float(_win_plus_one_land_at[j])) / WIN_PLUS_ONE_SECONDS
		if u >= 1.0:
			_win_retire(l)
			_win_plus_one_nodes[j] = null
			continue
		if j >= _win_charter_total:
			continue
		var slot: Vector2 = _win_charter_slot(j)
		var card_h := _win_charter_card_size().y
		l.position = Vector2(slot.x - l.size.x * 0.5, slot.y - card_h * 0.5 - 28.0 - WIN_PLUS_ONE_FLOAT_PX * clampf(u, 0.0, 1.0))
		l.modulate = Color(1.0, 1.0, 1.0, 1.0 - clampf(u, 0.0, 1.0))

# The Charter cards stay through the hold and fade over the first
# WIN_CHARTER_FADE_SECONDS of stage 3; a fully faded card is freed then. The fade
# keeps re-sloting them on the live board rect, so a resize during the fade moves
# the fan with the board.
func _win_charter_fade_apply(t3: float) -> void:
	if _win_charter_nodes.is_empty():
		return
	var k := clampf(t3 / WIN_CHARTER_FADE_SECONDS, 0.0, 1.0)
	for i in range(_win_charter_nodes.size()):
		var f: CardFace = _win_charter_nodes[i]
		if f == null or not is_instance_valid(f):
			continue
		if k >= 1.0:
			_win_retire(f)
			_win_charter_nodes[i] = null
		else:
			_win_charter_sync_size(f)
			f.position = _win_charter_slot(i) - f.size * 0.5
			f.modulate = Color(1.0, 1.0, 1.0, 1.0 - k)

# Removes and frees one sequence node right away (the layer cleanup covers anything
# still around at finish, skip or cancel).
func _win_retire(n: Node) -> void:
	if n != null and is_instance_valid(n):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		n.free()

# Leaving stage 2 keeps the cards and labels: they fade over the first frames of
# stage 3 (_win_charter_fade_apply, _win_plus_one_apply) and cleanup frees the rest.
func _win_stage_charters_end() -> void:
	pass

# Stage 3, banner sweep: the winner-coloured band wipes in from the left while the
# "<Name> wins!" title scales up on it. The confetti hooks in here (win variant only).
# The title colour is chosen from the band's luminance so every seat colour stays
# legible (see _win_banner_text_choice).
func _win_stage_banner_begin() -> void:
	_win_banner = ColorRect.new()
	var band_col: Color = GameTypes.PLAYER_COLORS[_win_pid].darkened(0.15) if _win_pid >= 0 else Palette.TEXT_MUTED
	_win_banner.color = band_col
	_win_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_banner.clip_contents = true
	_win_layer.add_child(_win_banner)
	_win_banner_label = Label.new()
	_win_banner_label.text = _splash_title.text
	_win_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_win_banner_label.add_theme_font_size_override("font_size", _win_banner_fit_font_size(str(_splash_title.text), get_viewport().get_visible_rect().size.x))
	var pick := _win_banner_text_choice(band_col)
	_win_banner_label.add_theme_color_override("font_color", pick["fill"])
	_win_banner_label.add_theme_color_override("font_outline_color", pick["outline"])
	_win_banner_label.add_theme_constant_override("outline_size", WIN_BANNER_TITLE_OUTLINE_PX)
	_win_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_banner.add_child(_win_banner_label)
	_win_banner.visible = true
	if _win_is_win_variant():
		_win_confetti_begin()
	_win_stage_banner_apply(0.0)

# Title font size: WIN_BANNER_FONT_SIZE normally, shrunk one point at a time (never
# below WIN_BANNER_FIT_FONT_MIN) until "<Name> wins!" plus its outline fits the
# window width with WIN_BANNER_FIT_MARGIN_PX on both sides. The longest name the
# game can show is the longest of GameTypes.PLAYER_NAMES ("Crimson", 7 chars —
# names are not player-editable and no max_length applies to them).
func _win_banner_fit_font_size(title: String, win_w: float) -> int:
	var font := ThemeDB.fallback_font
	if font == null:
		return WIN_BANNER_FONT_SIZE
	var limit := win_w - 2.0 * WIN_BANNER_FIT_MARGIN_PX
	var size := WIN_BANNER_FONT_SIZE
	while size > WIN_BANNER_FIT_FONT_MIN and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + 2.0 * float(WIN_BANNER_TITLE_OUTLINE_PX) > limit:
		size -= 1
	return size

# WCAG-style relative luminance and contrast ratio.
static func _wcag_luminance(c: Color) -> float:
	var chans: Array[float] = [c.r, c.g, c.b]
	var weights: Array[float] = [0.2126, 0.7152, 0.0722]
	var sum := 0.0
	for i in range(3):
		var v := chans[i]
		sum += weights[i] * (v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return sum

static func _wcag_contrast(a: Color, b: Color) -> float:
	var la := _wcag_luminance(a)
	var lb := _wcag_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

# Title colour for a banner band: cream on dark bands, the darkest palette ink on
# light ones (split at WIN_BANNER_SPLIT_LUMINANCE), each with its darker fallback so
# the fill reaches at least WIN_BANNER_MIN_CONTRAST against the band. The outline is
# the opposite tone. Cream fails on Red (4.49) and Blue (4.19) once the banner
# darkens the seat colour, and Palette.INK fails on Orange (3.67), so the fallbacks
# carry White / near-black; the ratios the choice settles on are Red 5.22 (white),
# Blue 4.88 (white), Orange 6.13 (near-black), Ivory 6.61 (ink).
static func _win_banner_text_choice(band: Color) -> Dictionary:
	if _wcag_luminance(band) < WIN_BANNER_SPLIT_LUMINANCE:
		if _wcag_contrast(WIN_BANNER_TEXT_CREAM, band) >= WIN_BANNER_MIN_CONTRAST:
			return {"fill": WIN_BANNER_TEXT_CREAM, "outline": WIN_BANNER_TEXT_NEAR_BLACK}
		return {"fill": WIN_BANNER_TEXT_WHITE, "outline": WIN_BANNER_TEXT_NEAR_BLACK}
	if _wcag_contrast(WIN_BANNER_TEXT_INK, band) >= WIN_BANNER_MIN_CONTRAST:
		return {"fill": WIN_BANNER_TEXT_INK, "outline": WIN_BANNER_TEXT_CREAM}
	return {"fill": WIN_BANNER_TEXT_NEAR_BLACK, "outline": WIN_BANNER_TEXT_CREAM}

func _win_stage_banner_apply(k: float) -> void:
	if _win_banner == null or not is_instance_valid(_win_banner):
		return
	var win_size := get_viewport().get_visible_rect().size
	var band_y := win_size.y * 0.5 - WIN_BANNER_HEIGHT_PX * 0.5 - WIN_BANNER_ABOVE_MIDDLE_PX
	_win_banner.position = Vector2(0.0, band_y)
	_win_banner.size = Vector2(win_size.x * k, WIN_BANNER_HEIGHT_PX)
	if _win_banner_label == null or not is_instance_valid(_win_banner_label):
		return
	_win_banner_label.size = Vector2(win_size.x, WIN_BANNER_HEIGHT_PX)
	_win_banner_label.pivot_offset = Vector2(win_size.x * 0.5, WIN_BANNER_HEIGHT_PX * 0.5)
	var grow := 1.0 - pow(1.0 - k, 3.0)
	var s := lerpf(WIN_BANNER_START_SCALE, 1.0, grow)
	_win_banner_label.scale = Vector2(s, s)

# The banner is not freed here: it shrinks and fades away over the first
# WIN_BANNER_EXIT_SECONDS of stage 4, which frees it.
func _win_stage_banner_end() -> void:
	pass

# Stage 4, standings: the panel fades and rises into place while the rows land one at
# a time from last place up to 1st, each counting its VP up, and the button row fades
# in last and becomes enabled only as the stage ends.
func _win_stage_standings_begin() -> void:
	_win_clear_spotlight()
	_win_center_offset_y(WIN_PANEL_RISE_PX)
	if _splash_panel != null and is_instance_valid(_splash_panel):
		_splash_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	for r in _win_rows:
		if r != null and is_instance_valid(r):
			r.visible = false
			r.modulate = Color(1.0, 1.0, 1.0, 0.0)
			r.scale = Vector2.ONE
	for l in _win_vp_labels:
		if l != null and is_instance_valid(l):
			l.text = "0 VP"
	if _splash_btn_row != null and is_instance_valid(_splash_btn_row):
		_splash_btn_row.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_win_set_splash_buttons_enabled(false)
	_splash_overlay.visible = true
	_results_btn.visible = false

func _win_stage_standings_apply(t: float) -> void:
	_win_banner_exit(t)
	var pk := clampf(t / WIN_PANEL_RISE_SECONDS, 0.0, 1.0)
	if _splash_panel != null and is_instance_valid(_splash_panel):
		_splash_panel.modulate = Color(1.0, 1.0, 1.0, pk)
	_win_center_offset_y(WIN_PANEL_RISE_PX * (1.0 - pk))
	for i in range(_win_rows.size()):
		_win_apply_row(i, t)
	var bt := t - (WIN_STANDINGS_SECONDS - WIN_BUTTONS_FADE_SECONDS)
	if _splash_btn_row != null and is_instance_valid(_splash_btn_row):
		_splash_btn_row.modulate = Color(1.0, 1.0, 1.0, clampf(bt / WIN_BUTTONS_FADE_SECONDS, 0.0, 1.0))

func _win_banner_exit(t: float) -> void:
	if _win_banner == null or not is_instance_valid(_win_banner):
		return
	var k := clampf(t / WIN_BANNER_EXIT_SECONDS, 0.0, 1.0)
	if k >= 1.0:
		_win_free_banner()
		return
	var win_size := get_viewport().get_visible_rect().size
	var mid_y := win_size.y * 0.5 - WIN_BANNER_ABOVE_MIDDLE_PX
	var h := WIN_BANNER_HEIGHT_PX * (1.0 - k)
	_win_banner.position = Vector2(0.0, mid_y - h * 0.5)
	_win_banner.size = Vector2(win_size.x, h)
	_win_banner.modulate = Color(1.0, 1.0, 1.0, 1.0 - k)

func _win_apply_row(i: int, t: float) -> void:
	if i >= _win_rows.size():
		return
	var row: Control = _win_rows[i]
	if row == null or not is_instance_valid(row):
		return
	var start := float(_win_rows.size() - 1 - i) * WIN_ROW_STAGGER_SECONDS
	if t < start:
		return
	var rt := t - start
	if not bool(row.visible):
		row.visible = true
	row.modulate = Color(1.0, 1.0, 1.0, clampf(rt / WIN_ROW_FADE_SECONDS, 0.0, 1.0))
	if i == _win_winner_row:
		row.pivot_offset = row.size * 0.5
		var pop := 1.0
		if rt < WIN_ROW_POP_SECONDS:
			pop = 1.0 + (WIN_ROW_POP_SCALE - 1.0) * sin(PI * (rt / WIN_ROW_POP_SECONDS))
		row.scale = Vector2(pop, pop)
	if i < _win_vp_labels.size() and i < _win_vp_values.size():
		var vp: Label = _win_vp_labels[i]
		if vp != null and is_instance_valid(vp):
			var vk := clampf(rt / WIN_VP_COUNT_SECONDS, 0.0, 1.0)
			vp.text = "%d VP" % int(round(float(int(_win_vp_values[i])) * vk))

func _win_stage_standings_end() -> void:
	pass

func _win_center_offset_y(px: float) -> void:
	if _splash_center == null or not is_instance_valid(_splash_center):
		return
	_splash_center.offset_top = px
	_splash_center.offset_bottom = px

func _win_free_banner() -> void:
	var b := _win_banner
	_win_banner = null
	_win_banner_label = null
	if b != null and is_instance_valid(b):
		if b.get_parent() != null:
			b.get_parent().remove_child(b)
		b.free()

func _win_splash_buttons() -> Array:
	return [_splash_review_btn, _splash_save_btn, _splash_new_game_btn, _splash_lobby_btn, _splash_view_board_btn, _splash_quit_btn]

func _win_set_splash_buttons_enabled(on: bool) -> void:
	for b in _win_splash_buttons():
		if b != null and is_instance_valid(b):
			(b as Button).disabled = not on
	if on:
		_apply_save_buttons()

# Puts every results node back the way an instant _show_splash leaves it.
func _win_reset_results_presentation() -> void:
	_win_center_offset_y(0.0)
	if _splash_panel != null and is_instance_valid(_splash_panel):
		_splash_panel.modulate = Color(1, 1, 1, 1)
	if _splash_btn_row != null and is_instance_valid(_splash_btn_row):
		_splash_btn_row.modulate = Color(1, 1, 1, 1)
	for r in _win_rows:
		if r != null and is_instance_valid(r):
			r.visible = true
			r.modulate = Color(1, 1, 1, 1)
			r.scale = Vector2.ONE
	for i in range(_win_vp_labels.size()):
		if i < _win_vp_values.size():
			var l: Label = _win_vp_labels[i]
			if l != null and is_instance_valid(l):
				l.text = "%d VP" % int(_win_vp_values[i])
	_win_set_splash_buttons_enabled(true)

func _win_layer_cleanup() -> void:
	if _win_layer != null and is_instance_valid(_win_layer):
		for c in _win_layer.get_children():
			if c.get_parent() == _win_layer:
				_win_layer.remove_child(c)
			c.free()
		_win_layer.visible = false
	_win_banner = null
	_win_banner_label = null
	_win_confetti = null
	_win_charter_nodes.clear()
	_win_plus_one_nodes.clear()
	if _win_skip_catcher != null and is_instance_valid(_win_skip_catcher):
		_win_skip_catcher.visible = false

# The final state: exactly what _show_splash showed before the sequence existed.
func _win_sequence_finish() -> void:
	_win_stage = WIN_STAGE_DONE
	_win_stage_t = 0.0
	_win_clear_spotlight()
	_win_layer_cleanup()
	_win_reset_results_presentation()
	_splash_overlay.visible = true
	_results_btn.visible = false
	_splash_new_game_btn.grab_focus()

# A click or Esc/Enter/Space at any stage jumps to the final state in this frame.
func _win_sequence_skip() -> void:
	if _win_stage <= WIN_STAGE_NONE or _win_stage >= WIN_STAGE_DONE:
		return
	_win_sequence_finish()

# The same teardown as a skip, for a match that is going away: the results stay hidden.
func _win_sequence_cancel() -> void:
	_win_clear_spotlight()
	var busy := _win_stage > WIN_STAGE_NONE and _win_stage < WIN_STAGE_DONE
	var leftovers := _win_layer != null and is_instance_valid(_win_layer) and _win_layer.get_child_count() > 0
	if not busy and not leftovers:
		return
	_win_stage = WIN_STAGE_NONE
	_win_stage_t = 0.0
	_win_layer_cleanup()
	_win_reset_results_presentation()

# Esc / Enter / Space skips the win sequence; true when the key was consumed.
func _win_skip_from_key(k: InputEventKey) -> bool:
	if _win_stage <= WIN_STAGE_NONE or _win_stage >= WIN_STAGE_DONE:
		return false
	if not k.pressed or k.echo:
		return false
	if k.keycode != KEY_ESCAPE and k.keycode != KEY_ENTER and k.keycode != KEY_KP_ENTER and k.keycode != KEY_SPACE:
		return false
	_win_sequence_skip()
	return true

# True while stages 1..4 run: the results are still hidden, so _any_overlay_visible()
# is false and the shortcut handlers in _input and _unhandled_key_input (Esc, F1,
# digits, Space/R/E/T/B/M ...) would run behind the sequence. Checked right after
# _win_skip_from_key in both paths: every key is either a skip or swallowed.
func _win_stage_blocks_keys() -> bool:
	return _win_stage > WIN_STAGE_NONE and _win_stage < WIN_STAGE_DONE

func _show_lobby() -> void:
	_finish_steal_anim()
	_reset_flight_state()
	for i in range(_seat_type_opts.size()):
		var sel_type: int = 0 if i == 0 else _settings_ai_difficulty
		_seat_type_opts[i].select(_seat_type_opts[i].get_item_index(sel_type))
	_update_lobby_seat_rows()
	_lobby_cancel_btn.visible = session != null and session.state != null
	_win_sequence_cancel()
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
	_settings_overlay.color = Color(Palette.SCRIM, 0.62)
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	add_child(_settings_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)

	var modal := _make_card_panel(Palette.PANEL_BG, true)
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
		_update_scoreboard_focus_overlay()
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
	_help_overlay.color = Color(Palette.SCRIM, 0.62)
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.visible = false
	add_child(_help_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(center)

	var modal := _make_card_panel(Palette.PANEL_BG, true)
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
	_help_text = rtl
	_help_heading_hex = Palette.HELP_HEADING.to_html(false)
	var hh := _help_heading_hex
	rtl.text = "\n".join([
		("[b][color=#%s]Goal[/color][/b] — first player to 10 victory points wins." % hh),
		"",
		("[b][color=#%s]Your turn[/color][/b]" % hh),
		"1. Click the dice to roll.",
		"2. Trade, build and play Action Cards.",
		"3. Press End Turn.",
		"",
		("[b][color=#%s]Building[/color][/b]" % hh),
		"Glowing spots on the board show what you can build now — click one and confirm.",
		"Road: 1 Timber + 1 Clay",
		"Settlement: 1 Timber + 1 Clay + 1 Fleece + 1 Grain",
		"City: 2 Grain + 3 Iron",
		"Action card: 1 Fleece + 1 Grain + 1 Iron",
		"",
		("[b][color=#%s]Trading[/color][/b]" % hh),
		"On your turn click a resource card (or press T) to open the trade tray. Click cards to fill 'You give', pick cards for 'You get', then 'Ask players' posts your offer (max 3 per turn). Each player accepts, declines or counters; press Trade on an accepting player's card to complete.",
		"Closing the tray, pressing Esc or End Turn withdraws your own offer. Edit the rows while it is open and press 'Send new offer' to replace it in one click. The Bank/Port button swaps the chosen card: 4:1 by default, 3:1 with a 3:1 port, 2:1 for that port's own resource.",
		"When another player posts an offer your tray opens with Accept, Decline or Counter; Esc only hides it — click a card again to reopen it.",
		"",
		("[b][color=#%s]The Blocker[/color][/b]" % hh),
		"When a 7 is rolled, every player holding more than 7 cards discards half of them. The roller then moves the Blocker to a new tile and steals a card from a player building there. A Guard card moves the Blocker without rolling.",
		"",
		("[b][color=#%s]Action cards[/color][/b]" % hh),
		"Guard — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.GUARD, "")),
		"Road Work — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.ROAD_WORK, "")),
		"Harvest Bounty — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.HARVEST_BOUNTY, "")),
		"Trade Decree — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.TRADE_DECREE, "")),
		"Charter — " + str(DEV_CARD_HELP.get(GameTypes.DevCardType.CHARTER_POINT, "")),
		"",
		("[b][color=#%s]Keyboard[/color][/b]" % hh),
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
	if (
		event is InputEventMouse
		or event is InputEventKey
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
	):
		_fps_idle_timer = 0.0
	if _review_active and event is InputEventKey:
		var rk := event as InputEventKey
		if rk.pressed and not rk.echo:
			_handle_review_key(rk.keycode)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and _win_skip_from_key(event as InputEventKey):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and _win_stage_blocks_keys():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and _subpanel_container != null and _subpanel_container.visible:
		var ek := event as InputEventKey
		if ek.pressed and not ek.echo and ek.keycode == KEY_ESCAPE:
			_close_subpanel_from_outside()
			get_viewport().set_input_as_handled()
			return
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
	if _review_active:
		_handle_review_key(k.keycode)
		get_viewport().set_input_as_handled()
		return
	if _win_skip_from_key(k):
		get_viewport().set_input_as_handled()
		return
	if _win_stage_blocks_keys():
		get_viewport().set_input_as_handled()
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
		elif _replays_overlay != null and _replays_overlay.visible:
			_replays_overlay.visible = false
		elif _lobby_overlay != null and _lobby_overlay.visible:
			_close_overlays()
		elif _costs_popup != null and _costs_popup.visible:
			_close_costs_popup()
		elif not _steal_pending.is_empty():
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

	if not _steal_pending.is_empty():
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
	_ui_style = str(cfg.get_value("settings", "ui_style", "paper"))
	if not Palette.STYLE_IDS.has(_ui_style):
		_ui_style = "paper"

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
	cfg.set_value("settings", "ui_style", _ui_style)
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

func set_ui_style(id: String) -> void:
	if not Palette.STYLES.has(id) or id == Palette.current_style:
		return
	var table := Palette.remap_table(Palette.current_style, id)
	Palette.apply_style(id)
	_ui_style = id
	Palette.restyle_tree(self, table)
	# The rebuild caches (_sb_row_key, _hint_sig, _strip_rebuild_key, _partner_rebuild_key)
	# stay untouched: rebuilding those rows resizes the trade tray and the scoreboard, and a
	# style switch may not move anything. Every colour they would re-bake lives in a stylebox,
	# a theme override or a script colour that the walk above already carried over.
	if _check_theme != null:
		_build_check_theme()
	_build_ui_theme()
	for optn in find_children("*", "OptionButton", true, false):
		_style_option(optn as OptionButton)
	if _log_toggle_btn != null and is_instance_valid(_log_toggle_btn):
		_style_button(_log_toggle_btn, "ghost")
	if _style_btn != null and is_instance_valid(_style_btn):
		_style_button(_style_btn, "ghost")
	if _review_slider_ticks != null and is_instance_valid(_review_slider_ticks):
		_review_slider_ticks.queue_redraw()
	_refresh_sea_band()
	for toast_label in _toast_labels:
		if is_instance_valid(toast_label) and toast_label.has_meta("toast_tint"):
			var tint := Palette.remap(toast_label.get_meta("toast_tint") as Color, table)
			toast_label.set_meta("toast_tint", tint)
			toast_label.add_theme_color_override("font_color", _toast_text_on_pill(tint))
			var host := toast_label.get_parent()
			if host != null and host is PanelContainer:
				host.set_meta("toast_tint", tint)
				var tbox := (host as Control).get_theme_stylebox("panel") as StyleBoxFlat
				if tbox != null:
					tbox.border_color = tint.darkened(0.15)
	if _help_text != null and is_instance_valid(_help_text):
		var new_hx := Palette.HELP_HEADING.to_html(false)
		_help_text.text = _help_text.text.replace("#" + _help_heading_hex, "#" + new_hx)
		_help_heading_hex = new_hx
	if _event_log != null:
		_rebuild_log_label(_event_log)
	if _log_popup_text != null:
		_rebuild_log_label(_log_popup_text)
	_refresh_style_btn()
	_refresh_ui()
	_save_settings()

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
	_log_lines.clear()
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
	_win_sequence_cancel()
	_splash_shown = false
	session.start_match(seed_val, configs, _balanced_check.button_pressed)
	_replay_saved_path = ""
	_apply_save_buttons()

func _build_toast_layer() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_host = host
	add_child(host)
	_toast_layer = VBoxContainer.new()
	_toast_layer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast_layer.offset_left = 0.0
	_toast_layer.offset_right = 0.0
	_toast_layer.offset_top = 0.0
	_toast_layer.offset_bottom = 0.0
	_toast_layer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_layer.add_theme_constant_override("separation", 4)
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_toast_layer)

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

func _steal_anim_active() -> bool:
	if not _steal_pending_anim.is_empty():
		return true
	if _steal_flyer != null and is_instance_valid(_steal_flyer):
		return true
	return false

func _bot_must_wait(now_ms: int) -> bool:
	if _steal_anim_active():
		return true
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

func _trade_pace_ms() -> float:
	var ov: float = trade_pace_override
	if ov >= 0.0:
		return ov * 1000.0
	if _reduce_motion:
		return 0.0
	if turn_min_seconds_override >= 0.0 and turn_min_seconds_override <= 0.001:
		return 0.0
	var idx: int = clampi(_settings_speed_idx, 0, BOT_SPEED_VALUES.size() - 1)
	return 700.0 * BOT_SPEED_VALUES[idx] / BOT_SPEED_VALUES[1]

func _trade_hold_active() -> bool:
	if session == null or session.state == null:
		return false
	var st: GameState = session.state
	if not st.open_trade.is_empty():
		if _trade_pace_ms() <= 0.0:
			return false
		return Time.get_ticks_msec() < _ot_hold_until_ms
	if _ot_result_active:
		return Time.get_ticks_msec() < _ot_result_until_ms
	return false

func _trade_watch_pacing() -> void:
	if session == null or session.state == null:
		return
	var st: GameState = session.state
	var now := Time.get_ticks_msec()
	if _ot_result_active and now >= _ot_result_until_ms:
		_ot_result_active = false
		if (
			_trade_tray != null and _trade_tray.visible
			and _trade_watch_col.visible and session.state.open_trade.is_empty()
		):
			_set_tray_panel_visible(false)
			_release_tray_focus()
		_refresh_ui()
	var ot: Dictionary = st.open_trade
	if ot.is_empty():
		_ot_pace_token = ""
		_ot_pace_seen_count = -1
		return
	var tok := _ot_token(ot)
	var cnt := RulesEngine._trade_resp_total(ot)
	_ot_snap = ot.duplicate(true)
	_ot_snap_token = tok
	var pace := _trade_pace_ms()
	if pace <= 0.0:
		_ot_hold_until_ms = 0
		return
	if tok != _ot_pace_token:
		_ot_pace_token = tok
		_ot_pace_seen_count = cnt
		_ot_hold_until_ms = now + int(pace)
	elif cnt > _ot_pace_seen_count:
		_ot_pace_seen_count = cnt
		_ot_hold_until_ms = now + int(pace)

func _sync_toast_host_rect() -> void:
	if _toast_host == null or _board_view == null:
		return
	var brect := _board_view.get_global_rect()
	if brect.size.x <= 40.0:
		return
	_toast_host.offset_left = brect.position.x + 8.0
	_toast_host.offset_right = brect.position.x + brect.size.x - 8.0
	_toast_host.offset_top = brect.position.y + 58.0
	_toast_host.offset_bottom = _toast_host.offset_top

func _toast_inner_width() -> float:
	if _toast_host != null and _toast_host.size.x > 80.0:
		return _toast_host.size.x
	if _board_view != null and _board_view.get_global_rect().size.x > 100.0:
		return _board_view.get_global_rect().size.x - 16.0
	return maxf(320.0, get_viewport_rect().size.x - 200.0)

func _show_toast(text: String, colour: Color, seconds: float = 3.0) -> void:
	if _toast_layer == null:
		return
	_sync_toast_host_rect()
	var inner_w: float = maxf(160.0, _toast_inner_width())
	var panel := PanelContainer.new()
	var st := _paper_panel_style(true)
	st.bg_color = Palette.TOAST_PILL_BG
	st.set_corner_radius_all(8)
	st.set_border_width_all(1)
	st.border_color = colour.darkened(0.15)
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 4
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", st)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := 14
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	while font_size > 11 and text_w + 28.0 > inner_w:
		font_size -= 1
		text_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	label.add_theme_font_size_override("font_size", font_size)
	panel.set_meta("toast_tint", colour)
	label.set_meta("toast_tint", colour)
	label.add_theme_color_override("font_color", _toast_text_on_pill(colour))
	if text_w + 28.0 > inner_w:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(maxf(80.0, inner_w - 28.0), 0.0)
	else:
		label.custom_minimum_size = Vector2(minf(text_w + 2.0, inner_w - 28.0), 0.0)
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

func _toast_text_on_pill(col: Color) -> Color:
	var min_contrast := float(Palette.style_option("toast_text_min_contrast", 0.0))
	if min_contrast <= 0.0:
		return col
	var out := col
	var step := 0.0
	while step < 1.0 and _pill_text_ratio(out, Palette.TOAST_PILL_BG) < min_contrast:
		step = minf(1.0, step + 0.04)
		out = col.lerp(Palette.INK, step)
	return out


func _vp_badge_colors(pcol: Color) -> Array[Color]:
	if _pill_text_ratio(Palette.BADGE_TEXT, pcol) >= 4.5:
		return [pcol, Palette.BADGE_TEXT]
	if _pill_text_ratio(Color.WHITE, pcol) >= 4.5:
		return [pcol, Color.WHITE]
	var fill := pcol
	var step := 0.0
	while step < 1.0 and _pill_text_ratio(Color.WHITE, fill) < 4.65:
		step = minf(1.0, step + 0.01)
		fill = pcol.lerp(Palette.BADGE_TEXT, step)
	return [fill, Color.WHITE]


func _pill_text_ratio(fg: Color, bg: Color) -> float:
	var mix := bg.lerp(fg, fg.a) if fg.a < 0.999 else fg
	var lum_a := _text_luminance(mix)
	var lum_b := _text_luminance(bg)
	return (maxf(lum_a, lum_b) + 0.05) / (minf(lum_a, lum_b) + 0.05)


func _text_luminance(c: Color) -> float:
	var total := 0.0
	var weights := [0.2126, 0.7152, 0.0722]
	var channels := [c.r, c.g, c.b]
	for i in range(3):
		var v := float(channels[i])
		total += (v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)) * float(weights[i])
	return total


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
			_show_toast("%s stole 1 %s from you!" % [thief_name, GameTypes.resource_name(res)], Palette.TOAST_STEAL_BAD, 3.5)
		else:
			_show_toast("%s stole a card from you!" % thief_name, Palette.TOAST_STEAL_BAD, 3.5)
		if _sfx != null:
			_sfx.play("seven")
	elif thief == v:
		if _human_seat_count() <= 1:
			var res2 := int(state.last_steal.get("res", -1))
			_show_toast("You stole 1 %s from %s." % [GameTypes.resource_name(res2), victim_name], Palette.TOAST_STEAL_GOOD, 3.5)
		else:
			_show_toast("You stole a card from %s." % victim_name, Palette.TOAST_STEAL_GOOD, 3.5)
	else:
		_show_toast("%s stole a card from %s." % [thief_name, victim_name], Palette.TOAST_WARN_BG)
	if thief == v and _board_view != null:
		var conf_v := _pick_steal_vertex(victim, int(state.blocker_tile))
		if conf_v >= 0:
			var conf_res := int(state.last_steal.get("res", -1))
			var conf_label: String = ""
			if _human_seat_count() <= 1 and conf_res >= 0:
				conf_label = "%s · stolen: %s" % [victim_name, GameTypes.resource_name(conf_res)]
			else:
				conf_label = "%s · stolen 1 card" % victim_name
			_board_view.show_steal_confirmation(conf_v, GameTypes.PLAYER_COLORS[victim], conf_label)
	_start_steal_anim(victim, thief, int(state.last_steal.get("res", -1)), state)

func _on_state_updated(state: GameState, events: Array[String]) -> void:
	if _review_active:
		return
	if _dice_show_active and _dice_show_seat >= 0 and state.current_player != _dice_show_seat:
		_cut_dice_show_hold()
	_note_revision_anim(events, state)
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
			if ev.contains(" to ") and ev.contains(" for "):
				_show_toast(str(ev).trim_suffix("."), Palette.TOAST_TRADE_BG)
			elif ev.contains(":1)") and ev.contains(" for 1 "):
				_show_toast(str(ev).trim_suffix("."), Palette.TOAST_NEUTRAL)
			else:
				_board_view.spawn_trade_toast(ev)
		elif ev.ends_with("withdrew the offer."):
			_show_toast(str(ev.split(" withdrew")[0]) + " withdrew the offer.", Palette.TOAST_NEUTRAL)
		if ev.contains("rolled "):
			rolled_now = true
		if ev.contains(" built a ") or ev.contains("upgraded "):
			built_now = true

	if _ot_snap_token != "":
		for ev_fin in events:
			var ef := str(ev_fin)
			if ef.contains("traded ") and ef.contains(" to ") and ef.contains(" for "):
				_ot_begin_trade_result(ef)
				break
			elif ef.ends_with("withdrew the offer."):
				_ot_begin_no_deal_result()
				break
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
				clip = "win" if _win_variant_for_pid(int(state.winner)) else "lose"
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
	elif state.phase >= GameTypes.TurnPhase.TURN_ROLL and state.current_player != _turn_focus_pid:
		_turn_focus_pid = state.current_player
		_turn_banner_count += 1
		var now_ai := state.current_player < session.seats.size() and session.seats[state.current_player].is_ai()
		_bot_turn_started_ms = Time.get_ticks_msec() if now_ai else 0
		_show_turn_banner(state)
	_animate_from_events(events, state)
	_announce_steal(state)
	if state.phase == GameTypes.TurnPhase.GAME_OVER and not _splash_shown:
		_show_splash(state)
	_prev_blocker_tile = state.blocker_tile
	_refresh_ui()
	_compute_flights(state)
	_compute_dev_flights(state)

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
	if t != "":
		_show_toast(t, col.darkened(0.2), 2.0)

func _fly_anchor(pid: int) -> Vector2:
	if pid == _view_pid() and _hand_bar_panel != null and _hand_bar_panel.visible:
		var hb: Rect2 = _hand_bar_panel.get_global_rect()
		if hb.size.x >= 4.0 and hb.size.y >= 4.0:
			return hb.get_center()
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
	_steal_hold_deadline_ms = Time.get_ticks_msec() + int((_board_view.blocker_anim_duration() + STEAL_FLIGHT_SECONDS + 1.0) * 1000.0)
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
		from = _hand_card_center_ui(res)
	if from == Vector2.INF:
		# Scoreboard-to-scoreboard fallback: even for the viewer, an
		# unresolvable (hidden or un-laid-out) hand must not turn the hand bar
		# into an endpoint.
		var row_from: Variant = _scoreboard_row_panels.get(victim, null)
		if row_from is Control and is_instance_valid(row_from) and (row_from as Control).visible and (row_from as Control).is_inside_tree():
			from = _to_ui_local((row_from as Control).get_global_rect().get_center())
		else:
			var a_from := _fly_anchor(victim)
			if a_from != Vector2.INF:
				from = _to_ui_local(a_from)
	var to := Vector2.INF
	if thief == v and res >= 0 and not _hand_hidden():
		if show_face:
			to = _hand_card_center_ui(res)
		else:
			# Hot-seat: the resource is not revealed to this viewer, so the
			# face-down card must not name it by its position either.
			to = _hand_resource_group_center_ui()
	if to == Vector2.INF:
		var raw_stack: Variant = _scoreboard_mini_hands.get(thief, null)
		if raw_stack is MiniHandStack and is_instance_valid(raw_stack) and (raw_stack as Control).is_inside_tree():
			to = _to_ui_local((raw_stack as Control).get_global_rect().get_center())
	if from == Vector2.INF or to == Vector2.INF:
		_finish_steal_anim()
		return
	_spawn_steal_flyer(from, to, res if show_face else -1, thief, serial)

# Centre of one resource card in the viewer's hand bar (ui-local), or INF
# while the bar is hidden or has not been laid out yet (no zero-size rects,
# so a flight can never start or land at (0,0)).
func _hand_card_center_ui(res: int) -> Vector2:
	var face: CardFace = _res_card_refs.get(res, null)
	if face == null or not face.visible:
		return Vector2.INF
	var r: Rect2 = face.get_global_rect()
	if r.size.x < 4.0 or r.size.y < 4.0:
		return Vector2.INF
	return _to_ui_local(r.get_center())

func _hand_resource_group_center_ui() -> Vector2:
	var acc: Rect2 = Rect2()
	var seen := false
	for rr in GameTypes.ALL_RESOURCES:
		var face: CardFace = _res_card_refs.get(int(rr), null)
		if face == null or not face.visible:
			continue
		var r: Rect2 = face.get_global_rect()
		if r.size.x < 4.0 or r.size.y < 4.0:
			continue
		if not seen:
			acc = r
			seen = true
		else:
			acc = acc.merge(r)
	if not seen:
		return Vector2.INF
	return _to_ui_local(acc.get_center())

func _spawn_steal_flyer(from: Vector2, to: Vector2, res_id: int, thief_pid: int, serial: int) -> void:
	_last_fly_kind = "resource" if res_id >= 0 else "back"
	_steal_flyer = _spawn_card_flyer(from, to, res_id, 0.0, func() -> void: _on_steal_card_landed(thief_pid, serial), 44.0, Color(0, 0, 0, 0), Callable(), -2, 0.0, STEAL_FLIGHT_SECONDS)


func _spawn_card_flyer(from: Vector2, to: Vector2, res_id: int, delay: float, on_landed: Callable, px := 44.0, outline_col := Color(0, 0, 0, 0), to_live: Callable = Callable(), action_id := -2, hold_fade := 0.0, base_seconds := CARD_FLIGHT_SECONDS) -> CardFace:
	var f := CardFace.new()
	f.focusable = false
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if action_id >= 0:
		f.kind = "action"
		f.action = action_id
		f.show_name = false
	elif action_id == -1 or res_id < 0:
		f.kind = "back"
	else:
		f.kind = "resource"
		f.resource = res_id
	f.custom_minimum_size = Vector2(px, px / CardFace.RATIO)
	_add_to_flight_layer(f)
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
		_add_to_flight_layer(o)
		o.size = f.size
		o.pivot_offset = f.size * 0.5
		o.position = f.position
	var dur := base_seconds * (0.45 if _settings_speed_idx >= 2 else 1.0)
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
	if hold_fade > 0.0:
		if on_landed.is_valid():
			tw.tween_callback(on_landed)
		tw.tween_property(f, "modulate:a", 0.0, hold_fade)
		if o != null:
			tw.parallel().tween_property(o, "modulate:a", 0.0, hold_fade)
	else:
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
		if on_landed.is_valid() and hold_fade <= 0.0:
			on_landed.call()
	)
	return f


func _build_flight_layer() -> void:
	_flight_layer = Control.new()
	_flight_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flight_layer.z_index = 1
	add_child(_flight_layer)

# Every node shown in the flight layer must stay click-transparent for its
# whole life: CardFace._ready and DicePairWidget._ready run during add_child
# and reset mouse_filter, so the IGNORE is (re-)applied to the full subtree
# right after the node enters the tree.
func _add_to_flight_layer(node: Node) -> void:
	var layer: Node = _flight_layer if _flight_layer != null and is_instance_valid(_flight_layer) else self
	layer.add_child(node)
	_set_ignore_tree(node)

func _set_ignore_tree(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_set_ignore_tree(c)


func _reset_flight_state() -> void:
	_flight_spawn_serial += 1
	_flight_spawn_queue = []
	_dev_spawn_queue = []
	_prev_dev_counts = []
	_last_flight_targets = []
	_turn_focus_pid = -1
	_bot_turn_started_ms = 0
	if _turn_banner != null and is_instance_valid(_turn_banner):
		_turn_banner.visible = false
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
					transfers.append({"from": int(src["id"]), "to": int(snk["id"]), "res": r, "n": n, "kind": "resource"})
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

func _dev_counts_for(p_data: Dictionary) -> Dictionary:
	var out := {}
	for c in p_data.get("dev_cards", []):
		out[int(c)] = int(out.get(int(c), 0)) + 1
	for c in p_data.get("new_dev_cards", []):
		out[int(c)] = int(out.get(int(c), 0)) + 1
	return out

func _dev_anchor(pid: int, ctype: int) -> Vector2:
	if pid == _view_pid() and not _hand_hidden():
		var chip: CardFace = _action_chips.get(ctype, null)
		if chip != null and is_instance_valid(chip) and chip.visible and chip.is_inside_tree():
			return _to_ui_local(chip.get_global_rect().get_center())
	var raw: Variant = _scoreboard_mini_acts.get(pid, null)
	if raw is Control and is_instance_valid(raw) and (raw as Control).is_inside_tree():
		return _to_ui_local((raw as Control).get_global_rect().get_center())
	return Vector2.INF

func _pulse_mini_act(pid: int) -> void:
	if _reduce_motion:
		return
	var raw: Variant = _scoreboard_mini_acts.get(pid, null)
	if not (raw is Control) or not is_instance_valid(raw) or not (raw as Control).is_inside_tree():
		return
	var stack: Control = raw
	stack.pivot_offset = stack.size * 0.5
	var tw := stack.create_tween()
	tw.tween_property(stack, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(stack, "scale", Vector2.ONE, 0.16)

func _compute_dev_flights(state: GameState) -> void:
	var now: Array = []
	for p_data in state.players:
		now.append(_dev_counts_for(p_data))
	if _prev_dev_counts.size() != now.size():
		_prev_dev_counts = now
		return
	var show_back_to_me := _hand_hidden()
	for p in range(now.size()):
		var before: Dictionary = _prev_dev_counts[p]
		var after: Dictionary = now[p]
		for t in before.keys():
			var dv := int(after.get(t, 0)) - int(before.get(t, 0))
			if dv < 0:
				_last_flights.append({"from": p, "to": -1, "res": -1, "n": 1, "kind": "action"})
				if not _reduce_motion:
					_dev_spawn_queue.append({"buy": false, "pid": p, "type": int(t), "back": false})
		for t in after.keys():
			var dv2 := int(after.get(t, 0)) - int(before.get(t, 0))
			if dv2 > 0:
				_last_flights.append({"from": -1, "to": p, "res": -1, "n": 1, "kind": "action"})
				if not _reduce_motion:
					var reveal := (p == _view_pid()) and not show_back_to_me
					_dev_spawn_queue.append({"buy": true, "pid": p, "type": int(t), "back": not reveal})
	_prev_dev_counts = now
	if not _dev_spawn_queue.is_empty():
		# Playing or buying a card rides along with the resource transfers this
		# same update already queued, so re-arm the timer with that queue rather
		# than replacing it and dropping the resource flyers.
		_schedule_flight_spawn(_flight_spawn_queue)

func _spawn_dev_flights() -> void:
	var reqs: Array = _dev_spawn_queue
	_dev_spawn_queue = []
	var deck_from := Vector2.INF
	if _bank_deck_face != null and is_instance_valid(_bank_deck_face) and _bank_deck_face.visible and _bank_deck_face.is_inside_tree():
		deck_from = _to_ui_local(_bank_deck_face.get_global_rect().get_center())
	elif _buy_card_btn != null and is_instance_valid(_buy_card_btn) and _buy_card_btn.is_inside_tree():
		deck_from = _to_ui_local(_buy_card_btn.get_global_rect().get_center())
	var delay := 0.0
	for req in reqs:
		var pid := int(req["pid"])
		var t := int(req["type"])
		if bool(req["buy"]):
			if deck_from == Vector2.INF:
				continue
			var to := _dev_anchor(pid, t)
			if to == Vector2.INF:
				continue
			var back := bool(req["back"])
			var landed := func() -> void:
				if pid == _view_pid() and not _hand_hidden():
					var chip: CardFace = _action_chips.get(t, null)
					if chip != null and is_instance_valid(chip):
						_pulse_card(chip)
				else:
					_pulse_mini_act(pid)
			_spawn_card_flyer(deck_from, to, -1, delay, landed, 40.0, GameTypes.PLAYER_COLORS[pid], Callable(), -1 if back else t)
			delay += 0.07
		else:
			if _board_view == null or not is_instance_valid(_board_view):
				continue
			var pf := _dev_anchor(pid, t)
			if pf == Vector2.INF:
				pf = _flight_anchor(pid, -1)
			if pf == Vector2.INF:
				continue
			var center := _to_ui_local(_board_view.get_global_rect().get_center())
			_spawn_card_flyer(pf, center, -1, delay, Callable(), 44.0, Color(0, 0, 0, 0), Callable(), t, 0.5)
			delay += 0.07

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
	if my != _flight_spawn_serial:
		_dev_spawn_queue = []
		return
	_spawn_dev_flights()
	if transfers.is_empty():
		return
	_last_flight_targets = []
	var spawned := 0
	var delay := 0.0
	for tr in transfers:
		if str(tr.get("kind", "")) != "resource":
			continue
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
	if _review_active:
		return
	_append_log("[color=#%s][Seat %d Invalid Action] %s[/color]" % [Palette.LOG_ERROR_TEXT.to_html(false), player_id + 1, error])
	_refresh_ui()

func _log_display_text(msg: String) -> String:
	# the engine logs "X counters: gives A for B." — render the same wording
	# the panel row, strip pill and toast use: "X counters: gives A, wants B."
	if msg.contains(" counters: gives ") and msg.contains(" for "):
		var head := str(msg.split(" counters: gives ")[0])
		var rest := str(msg.split(" counters: gives ")[1])
		if rest.contains(" for "):
			var gives_part := str(rest.split(" for ")[0])
			var wants_part := str(rest.substr(rest.find(" for ") + 5))
			return "%s counters: gives %s, wants %s" % [head, gives_part, wants_part]
	return msg

func _append_log(msg: String) -> void:
	if _event_log == null:
		return
	msg = _log_display_text(msg)
	var line := "\u2022 " + msg
	_log_lines.append(line)
	_event_log.append_text(line + "\n")
	var popup_open := _log_popup != null and _log_popup.visible and _log_popup_text != null
	if popup_open:
		_log_popup_text.append_text(line + "\n")
	if _log_lines.size() > LOG_MAX_LINES + LOG_TRIM_SLACK:
		_log_lines = _log_lines.slice(_log_lines.size() - LOG_MAX_LINES)
		_rebuild_log_label(_event_log)
		if popup_open:
			_rebuild_log_label(_log_popup_text)

func _rebuild_log_label(rtl: RichTextLabel) -> void:
	rtl.clear()
	if not _log_lines.is_empty():
		var joined := "\n".join(_log_lines)
		var hx := Palette.LOG_ERROR_TEXT.to_html(false)
		for style_id in Palette.STYLE_IDS:
			joined = joined.replace("#" + (Palette.STYLES[style_id]["LOG_ERROR_TEXT"] as Color).to_html(false), "#" + hx)
		rtl.append_text(joined + "\n")

func _get_setup_anchor_vertex(state: GameState) -> int:
	return state.setup_anchor_vertex

func _is_human_acting() -> bool:
	if _review_active:
		return false
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
	if _review_active:
		return _review_view_pid
	if session == null or session.state == null:
		return 0
	if _is_human_acting():
		return session.get_acting_player_id()
	var cur: int = session.state.current_player
	if cur >= 0 and cur < session.seats.size() and not session.seats[cur].is_ai():
		return cur
	return _find_first_human_seat()

func _on_action_chip_hover(ctype: int) -> void:
	if _review_active:
		return
	var t := str(_chip_hover_texts.get(ctype, ""))
	if t.is_empty():
		return
	_banner_hover_active = true
	_set_banner(t)

func _on_action_chip_leave() -> void:
	if not _banner_hover_active:
		return
	_banner_hover_active = false
	if session != null and session.state != null:
		_set_banner(_compute_instruction(session.state, session.get_acting_player_id(), _is_human_acting()))

func _dev_deck_summary(state: GameState) -> String:
	var counts := {}
	for c in state.dev_deck:
		counts[int(c)] = int(counts.get(int(c), 0)) + 1
	var parts: Array[String] = []
	var pairs := [
		[GameTypes.DevCardType.GUARD, "Guard"],
		[GameTypes.DevCardType.ROAD_WORK, "Road Work"],
		[GameTypes.DevCardType.HARVEST_BOUNTY, "Bounty"],
		[GameTypes.DevCardType.TRADE_DECREE, "Decree"],
		[GameTypes.DevCardType.CHARTER_POINT, "Charter"],
	]
	for pair in pairs:
		var n := int(counts.get(int(pair[0]), 0))
		if n > 0:
			parts.append("%s x%d" % [str(pair[1]), n])
	return ", ".join(parts)

func _set_banner(text: String) -> void:
	if _status_banner_label == null:
		return
	_status_banner_label.tooltip_text = text
	if _human_seat_count() >= 2:
		var v := _view_pid()
		if session != null and session.state != null and session.state.phase != GameTypes.TurnPhase.GAME_OVER and v >= 0 and v < session.state.players.size():
			_status_banner_label.text = "%s — %s" % [
				str(session.state.players[v].get("name", GameTypes.PLAYER_NAMES[v])), text
			]
			return
	_status_banner_label.text = text

const OPEN_TRADE_BLOCK_REASON := "An open trade offer is awaiting responses."

func _own_offer_open(st: GameState, pid: int) -> bool:
	return st != null and not st.open_trade.is_empty() and int(st.open_trade.get("from", -1)) == pid

# Rules checks that treat the viewed player's OWN open offer as non-blocking:
# any action they take withdraws it first (see _submit_human_action).
func _dev_card_ok_tolerant(state: GameState, pid: int, ctype: int) -> Dictionary:
	var chk: Dictionary = RulesEngine.can_play_dev_card(state, pid, ctype)
	if bool(chk.get("ok", false)):
		return chk
	if _own_offer_open(state, pid) and str(chk.get("reason", "")) in [OPEN_TRADE_BLOCK_REASON, "It is not your turn."]:
		return {"ok": true, "reason": ""}
	return chk

# A human's offer where every other player declined (or their counter was
# declined) — nobody can answer it anymore, so it withdraws itself.
func _own_offer_dead(st: GameState) -> bool:
	if st == null or not _own_offer_open(st, _view_pid()):
		return false
	var from_p := int(st.open_trade.get("from", -1))
	var responses: Dictionary = st.open_trade.get("responses", {})
	var takers := 0
	var dead := 0
	for p_id in range(st.players.size()):
		if p_id == from_p:
			continue
		takers += 1
		if not responses.has(p_id):
			continue
		var resp: Dictionary = responses[p_id]
		var st_str := str(resp.get("status", ""))
		if st_str == "decline" or (st_str == "counter" and bool(_declined_counters.get(p_id, false))):
			dead += 1
	return takers > 0 and dead == takers

# After "No takers" has been visible for ~1.2 s the dead offer withdraws
# itself so the player is never locked out of acting. The editor keeps the
# same give/get draft (spec: panel returns to the editor).
func _maybe_withdraw_dead_offer() -> void:
	if session == null or session.state == null:
		return
	if _no_takers_since_ms == 0 or _no_takers_token == "":
		return
	var st := session.state
	if st.open_trade.is_empty() or _ot_token(st.open_trade) != _no_takers_token:
		_no_takers_since_ms = 0
		_no_takers_token = ""
		return
	if Time.get_ticks_msec() - _no_takers_since_ms < 1200:
		return
	_no_takers_since_ms = 0
	_no_takers_token = ""
	_no_takers_keep_draft = true
	_fresh_trade_next_click = true
	var res: Dictionary = session.submit_action(
		int(st.open_trade.get("from", -1)), GameAction.cancel_open_trade()
	)
	if not bool(res.get("ok", false)):
		_no_takers_keep_draft = false
		_fresh_trade_next_click = false

func _own_offer_takeover() -> bool:
	return (
		session != null
		and session.state != null
		and _own_offer_open(session.state, _view_pid())
		and not _hand_hidden()
	)

func _submit_human_action(action: Dictionary, force_pid: int = -1) -> void:
	if session == null or session.state == null:
		return
	if _hand_hidden():
		return
	var acting_id := session.get_acting_player_id()
	if force_pid >= 0:
		acting_id = force_pid
	var trade_types := ["open_trade", "respond_open_trade", "cancel_open_trade", "finalize_open_trade"]
	if not trade_types.has(str(action.get("type", ""))):
		var ot_now: Dictionary = session.state.open_trade
		if not ot_now.is_empty() and int(ot_now.get("from", -1)) == _view_pid():
			# Any action the proposer takes withdraws their own offer first —
			# even while a responder has not answered yet.
			acting_id = _view_pid()
			session.submit_action(acting_id, GameAction.cancel_open_trade())
			if session.state == null:
				return
		if str(action.get("type", "")) == "open_trade":
			_fresh_trade_next_click = false
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
	if _review_active:
		return false
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

func _seat_display_name(pid: int) -> String:
	if session == null or pid < 0 or pid >= session.state.players.size():
		return GameTypes.PLAYER_NAMES[clampi(pid, 0, GameTypes.PLAYER_NAMES.size() - 1)]
	return str(session.state.players[pid].get("name", GameTypes.PLAYER_NAMES[pid]))

func _compute_instruction(state: GameState, acting_id: int, human_acting: bool) -> String:
	if not _steal_pending.is_empty():
		return "Click a marked player to steal from, or click another hex — keys 1-%d, Esc picks another tile" % _steal_victims.size()
	if state.phase == GameTypes.TurnPhase.GAME_OVER:
		if state.winner != -1:
			return "%s wins!" % GameTypes.PLAYER_NAMES[state.winner]
		return "Game over."
	if not state.open_trade.is_empty():
		var ot_from0: int = int(state.open_trade.get("from", -1))
		if not human_acting and ot_from0 == _view_pid():
			return "Waiting for answers to your offer…"
		if _early_answer_pid() >= 0:
			return "%s wants to trade — accept, decline or counter." % _seat_display_name(ot_from0)
	if not human_acting:
		return "%s is thinking…" % _seat_display_name(acting_id)
	if not state.open_trade.is_empty():
		var ot_from: int = int(state.open_trade.get("from", -1))
		if ot_from != acting_id:
			return "%s wants to trade — accept, decline or counter." % _seat_display_name(ot_from)
		if _trade_tray != null and not _trade_tray.visible:
			return "Click a resource card (or T) to answer your offer."
		return "Pick a player card to trade \u2014 any action, closing or End Turn withdraws it."
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

func _sb_layout_key(state: GameState) -> String:
	return "%d:%d" % [state.start_player, state.num_players]

func _reset_scoreboard_rows() -> void:
	for child in _scoreboard_box.get_children():
		child.free()
	_scoreboard_row_slots.clear()
	_scoreboard_row_parts.clear()
	_scoreboard_mini_hands.clear()
	_scoreboard_mini_acts.clear()
	_scoreboard_row_panels.clear()
	_scoreboard_played.clear()

func _build_scoreboard_row(slot: Control) -> Dictionary:
	var card := _make_compact_card(Palette.ROW_BG)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(card)
	var st := (card.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	st.set_border_width_all(SCOREBOARD_ROW_BORDER)
	st.border_color = Color(0, 0, 0, 0)
	st.shadow_color = Palette.ROW_SHADOW
	st.shadow_size = SCOREBOARD_ROW_SHADOW_SIZE
	st.shadow_offset = Vector2(0, 1)
	card.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var badge_w := Control.new()
	badge_w.custom_minimum_size = Vector2(34, 26)
	badge_w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge_w)
	var badge := Label.new()
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	var bst := StyleBoxFlat.new()
	bst.set_corner_radius_all(6)
	bst.content_margin_left = 2
	bst.content_margin_right = 2
	badge.add_theme_stylebox_override("normal", bst)
	badge_w.add_child(badge)
	var name_w := Control.new()
	name_w.custom_minimum_size = Vector2(88, 0)
	name_w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_w)
	var name_lbl := Label.new()
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	name_w.add_child(name_lbl)
	var seat_w := Control.new()
	seat_w.custom_minimum_size = Vector2(76, 0)
	seat_w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(seat_w)
	var seat_cell := CenterContainer.new()
	seat_cell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	seat_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat_w.add_child(seat_cell)
	var seat_pill := _make_pill("", Color(Palette.PANEL_BORDER, 0.28), Palette.TEXT)
	seat_cell.add_child(seat_pill)
	var res_w := Control.new()
	res_w.custom_minimum_size = Vector2(52, 26)
	res_w.clip_contents = true
	row.add_child(res_w)
	var res_stack := MiniHandStack.new()
	res_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	res_stack.act_fan.visible = false
	res_w.add_child(res_stack)
	var act_w := Control.new()
	act_w.custom_minimum_size = Vector2(52, 26)
	act_w.clip_contents = true
	row.add_child(act_w)
	var act_stack := MiniHandStack.new()
	act_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	act_stack.res_fan.visible = false
	act_w.add_child(act_stack)
	var played_cell := Control.new()
	played_cell.custom_minimum_size = Vector2(84, 26)
	played_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	played_cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	played_cell.clip_contents = true
	row.add_child(played_cell)
	var played_wrap := HBoxContainer.new()
	played_wrap.add_theme_constant_override("separation", 3)
	played_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	played_wrap.alignment = BoxContainer.ALIGNMENT_BEGIN
	played_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	played_cell.add_child(played_wrap)
	var awards_wrap := played_wrap
	var tw := card.create_tween()
	tw.set_loops()
	tw.tween_method(func(v: float) -> void: st.shadow_size = int(v), 2.0, 8.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(v: float) -> void: st.shadow_size = int(v), 8.0, 2.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.pause()
	var row_click := ColorRect.new()
	row_click.name = "RowClick"
	row_click.color = Color(0, 0, 0, 0)
	row_click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row_click.mouse_filter = Control.MOUSE_FILTER_STOP
	row_click.visible = false
	card.add_child(row_click)
	return {
		"card": card, "style": st, "tween": tw, "badge": badge, "badge_style": bst,
		"name": name_lbl, "seat": seat_pill.get_child(0), "res": res_stack, "act": act_stack,
		"awards": awards_wrap, "played": played_wrap, "played_cell": played_cell,
	}

func _sync_scoreboard_rows(state: GameState, view_pid: int, human_seat_n: int, acting_id: int) -> void:
	_sb_focus_card = null
	if _sb_row_key != _sb_layout_key(state):
		_sb_row_key = _sb_layout_key(state)
		_reset_scoreboard_rows()
	if _scoreboard_row_slots.is_empty():
		for k in range(4):
			var slot := Control.new()
			slot.custom_minimum_size = Vector2(0, 34)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_scoreboard_box.add_child(slot)
			_scoreboard_row_slots.append(slot)
			_scoreboard_row_parts[k] = _build_scoreboard_row(slot)
			var _rc := (( _scoreboard_row_parts[k] as Dictionary)["card"] as Control).get_node_or_null("RowClick") as Control
			if _rc != null:
				_rc.gui_input.connect(_on_sb_row_gui.bind(k))
	var focus_pid: int = -1 if state.phase == GameTypes.TurnPhase.GAME_OVER else state.current_player
	for k in range(4):
		var parts: Dictionary = _scoreboard_row_parts[k]
		if k >= state.num_players:
			(parts["card"] as Control).visible = false
			_sb_row_slot_pid[k] = -1
			continue
		(parts["card"] as Control).visible = true
		var p_id: int = (state.start_player + k) % state.num_players
		_sb_row_slot_pid[k] = p_id
		var p_data: Dictionary = state.players[p_id]
		var seat_cfg: SeatConfig = session.seats[p_id] if p_id < session.seats.size() else null
		var is_active := (p_id == acting_id and state.phase != GameTypes.TurnPhase.GAME_OVER)
		var pcol: Color = GameTypes.PLAYER_COLORS[p_id % GameTypes.PLAYER_COLORS.size()]
		var card: PanelContainer = parts["card"]
		var st: StyleBoxFlat = parts["style"]
		st.bg_color = Palette.ROW_BG_ACTIVE if is_active else Palette.ROW_BG
		st.border_color = Color(0, 0, 0, 0)
		st.shadow_color = Palette.ROW_SHADOW
		var tw: Tween = parts["tween"]
		tw.pause()
		st.shadow_size = SCOREBOARD_ROW_SHADOW_SIZE
		if p_id == focus_pid:
			_sb_focus_card = card
			_sb_focus_pcol = pcol
		var badge: Label = parts["badge"]
		var bst: StyleBoxFlat = parts["badge_style"]
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
		var badge_pair := _vp_badge_colors(pcol)
		bst.bg_color = badge_pair[0]
		badge.add_theme_color_override("font_color", badge_pair[1])
		(parts["name"] as Label).text = ("▶ " if is_active else "") + str(p_data.get("name", GameTypes.PLAYER_NAMES[p_id]))
		(parts["seat"] as Label).text = _seat_type_label(seat_cfg)
		var res_stack: MiniHandStack = parts["res"]
		res_stack.res_count = _displayed_hand_count(p_id)
		var act_stack: MiniHandStack = parts["act"]
		act_stack.act_count = p_data.get("dev_cards", []).size() + p_data.get("new_dev_cards", []).size()
		var played: HBoxContainer = parts["played"]
		for c in played.get_children():
			c.free()
		var played_dev: Dictionary = p_data.get("played_dev", {})
		var gcnt := int(played_dev.get(GameTypes.DevCardType.GUARD, 0))
		if gcnt <= 0:
			gcnt = int(p_data.get("played_guards", 0))
		if gcnt > 0:
			played.add_child(_make_played_glyph(
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
				played.add_child(_make_played_glyph(
					other_type, ocnt, false,
					"%s played: %d" % [str(played_names[other_type]), ocnt]
				))
		var route_len := int(p_data.get("longest_route_length", 0))
		if route_len > 0:
			played.add_child(_make_road_glyph(route_len, state.longest_route_holder == p_id))
		if state.longest_route_holder == p_id:
			played.add_child(_make_pill("Route +2", Color(Palette.ACCENT_GREEN, 0.40), Palette.TEXT))
		if state.largest_guard_holder == p_id:
			played.add_child(_make_pill("Guard +2", Palette.AWARD_GUARD_PILL_BG, Palette.AWARD_GUARD_PILL_TEXT))
		_scoreboard_row_panels[p_id] = card
		_scoreboard_mini_hands[p_id] = res_stack
		_scoreboard_mini_acts[p_id] = act_stack
		_scoreboard_played[p_id] = played
	_update_scoreboard_focus_overlay()

func _set_sb_focus_glow(v: float) -> void:
	if _sb_focus_overlay == null or not is_instance_valid(_sb_focus_overlay):
		return
	_sb_focus_overlay.glow = v
	if _sb_focus_overlay.visible:
		_sb_focus_overlay.queue_redraw()

func _update_scoreboard_focus_overlay() -> void:
	if _sb_focus_overlay == null or not is_instance_valid(_sb_focus_overlay):
		return
	if _sb_focus_card == null or not is_instance_valid(_sb_focus_card):
		_sb_focus_overlay.visible = false
		if _sb_focus_tween != null and _sb_focus_tween.is_valid():
			_sb_focus_tween.pause()
		return
	_sb_focus_overlay.visible = true
	_sb_focus_overlay.ring_color = _sb_focus_pcol
	var r: Rect2 = _sb_focus_card.get_global_rect().grow(2.0)
	_sb_focus_overlay.global_position = r.position
	_sb_focus_overlay.size = r.size
	if _reduce_motion:
		_sb_focus_overlay.glow = 5.0
		if _sb_focus_tween != null and _sb_focus_tween.is_valid():
			_sb_focus_tween.pause()
	else:
		if _sb_focus_tween != null and _sb_focus_tween.is_valid():
			_sb_focus_tween.play()
	_sb_focus_overlay.queue_redraw()

class ScoreboardFocusOverlay extends Control:
	var ring_color: Color = Color(0, 0, 0, 0)
	var glow: float = 5.0
	func _draw() -> void:
		if ring_color.a <= 0.0 or size.x < 10.0:
			return
		var r: Rect2 = Rect2(Vector2.ZERO, size).grow(-1.5)
		var pts: PackedVector2Array = ScoreboardFocusOverlay.ring_points(r, 9.5)
		draw_polyline(pts, Color(ring_color, 0.05), glow + 3.0, true)
		draw_polyline(pts, Color(ring_color, 0.10), glow, true)
		draw_polyline(pts, ring_color, 3.0, true)

	static func ring_points(r: Rect2, radius: float, steps: int = 8) -> PackedVector2Array:
		var rad: float = minf(radius, minf(r.size.x, r.size.y) * 0.5)
		var pts := PackedVector2Array()
		var centers := [
			Vector2(r.position.x + rad, r.position.y + rad),
			Vector2(r.end.x - rad, r.position.y + rad),
			Vector2(r.end.x - rad, r.end.y - rad),
			Vector2(r.position.x + rad, r.end.y - rad),
		]
		var starts := [PI, PI * 1.5, PI * 2.0, PI * 2.5]
		for i in 4:
			var c: Vector2 = centers[i]
			var a0: float = starts[i]
			for s in steps + 1:
				var ang: float = a0 + PI * 0.5 * float(s) / float(steps)
				pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
		pts.append(pts[0])
		return pts

func _refresh_ui() -> void:
	if session == null or session.state == null:
		return
	var state := session.state
	var acting_id := session.get_acting_player_id()
	var human_acting := _is_human_acting()
	# While the viewed human's own offer is still on the table they remain the
	# one who can act: any action withdraws the offer first (_submit_human_action).
	var own_ot_open := not human_acting and _own_offer_open(state, _view_pid()) and not _hand_hidden()
	var bar_pid := _view_pid() if own_ot_open else acting_id
	var bar_human := human_acting or own_ot_open

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
		and int(state.pending_discards.get(acting_id, 0)) > 0
		and human_acting
	)
	_refresh_discard_picker(state, acting_id, needs_discard, _hand_hidden())
	_refresh_bank_section(state)

	if not _steal_pending.is_empty():
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
	_sync_scoreboard_rows(state, view_pid, human_seat_n, acting_id)

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
		face.mouse_default_cursor_shape = _hand_res_cursor(state, int(hand.get(r, 0)), hand_hidden)
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

	var show_view := human_seat_n >= 2 or _review_active
	if _hand_view_swatch != null:
		_hand_view_swatch.visible = true
		_hand_view_swatch.color = (
			GameTypes.PLAYER_COLORS[dash_pid]
			if show_view and not hand_hidden
			else Color(0, 0, 0, 0)
		)
	if _hand_view_name != null:
		_hand_view_name.visible = true
		if _review_active:
			_hand_view_name.text = "Viewing: %s" % str(dash_player.get("name", GameTypes.PLAYER_NAMES[dash_pid]))
		elif not show_view:
			_hand_view_name.text = ""
		elif hand_hidden:
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
			chip.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if human_acting else Control.CURSOR_ARROW
			chip.tooltip_text = "%s\nNever played — it scores when you win" % help
			_chip_hover_texts[ctype] = "%s \u2014 %s \u00b7 never played; it scores when you win" % [str(chip_names[ctype]), help]
			continue
		if ccnt <= 0:
			chip.disabled = true
			chip.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if human_acting else Control.CURSOR_ARROW
			chip.tooltip_text = "%s\nYou have no %s card" % [help, str(chip_names[ctype])]
			_chip_hover_texts[ctype] = "%s \u2014 %s \u00b7 you have no %s card" % [str(chip_names[ctype]), help, str(chip_names[ctype])]
			continue
		var new_cnt := 0
		for c in dash_player.get("new_dev_cards", []):
			if int(c) == int(ctype):
				new_cnt += 1
		var chk: Dictionary = _dev_card_ok_tolerant(state, dash_pid, int(ctype))
		var chk_ok := bool(chk.get("ok", false))
		chip.disabled = not chk_ok or _bar_locked
		chip.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if (human_acting and chk_ok)
			else (Control.CURSOR_FORBIDDEN if human_acting else Control.CURSOR_ARROW)
		)
		var tip := "Play %s\n%s" % [str(chip_names[ctype]), help]
		if new_cnt > 0:
			tip += " (new this turn)"
		chip.tooltip_text = tip if chk_ok else "%s\n%s" % [help, str(chk.get("reason", ""))]
		if chk_ok:
			_chip_hover_texts[ctype] = "%s \u2014 %s" % [str(chip_names[ctype]), help]
		else:
			_chip_hover_texts[ctype] = "%s \u2014 %s \u00b7 %s" % [str(chip_names[ctype]), help, str(chk.get("reason", ""))]
	if hand_hidden:
		for ctype in _action_chips.keys():
			var hidden_chip: CardFace = _action_chips[ctype]
			hidden_chip.hidden_card = true
			hidden_chip.disabled = true
			hidden_chip.mouse_default_cursor_shape = Control.CURSOR_ARROW
			hidden_chip.tooltip_text = ""
			_chip_hover_texts[ctype] = ""

	_refresh_subpanels(state, bar_pid, bar_human)

	# Auto board highlights for mandatory placement phases
	_update_mandatory_board_highlights(state, bar_pid, bar_human)

	# Bottom bar controls
	var in_main := (
		bar_human
		and state.phase == GameTypes.TurnPhase.TURN_MAIN
		and (
			state.open_trade.is_empty()
			or int(state.open_trade.get("from", -1)) == bar_pid
		)
	)
	var in_roll := (human_acting and state.phase == GameTypes.TurnPhase.TURN_ROLL)

	_dice_widget.set_roll_enabled(in_roll and not _bar_locked)

	var in_road_work := human_acting and state.phase == GameTypes.TurnPhase.TURN_ROAD_WORK
	_end_turn_btn.disabled = not (in_main or in_road_work) or _bar_locked
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
			not RulesEngine.can_afford(state, bar_pid, "road")
			and not RulesEngine.can_afford(state, bar_pid, "settlement")
			and not RulesEngine.can_afford(state, bar_pid, "city")
			and not RulesEngine.can_afford(state, bar_pid, "dev_card")
		)
	if end_done:
		_style_button(_end_turn_btn, "primary")
		for st_name in ["normal", "hover", "pressed"]:
			var gbox: StyleBoxFlat = (_end_turn_btn.get_theme_stylebox(st_name) as StyleBoxFlat).duplicate() as StyleBoxFlat
			match st_name:
				"normal":
					gbox.bg_color = Palette.ACCENT_GREEN
				"hover":
					gbox.bg_color = Palette.BUTTON_GREEN_HOVER
				_:
					gbox.bg_color = Palette.BUTTON_GREEN_PRESSED
			_end_turn_btn.add_theme_stylebox_override(st_name, gbox)
		_end_turn_btn.add_theme_color_override("font_color", Palette.BUTTON_TEXT_ON_GREEN)
		_end_turn_btn.add_theme_color_override("font_hover_color", Palette.BUTTON_TEXT_ON_GREEN)
		_end_turn_btn.add_theme_color_override("font_pressed_color", Palette.BUTTON_TEXT_ON_GREEN)
		_end_turn_btn.add_theme_color_override("icon_normal_color", Palette.BUTTON_TEXT_ON_GREEN)
		_end_turn_btn.add_theme_color_override("icon_hover_color", Palette.BUTTON_TEXT_ON_GREEN)
		_end_turn_btn.add_theme_color_override("icon_pressed_color", Palette.BUTTON_TEXT_ON_GREEN)
		_end_turn_btn.add_theme_color_override("icon_hover_pressed_color", Palette.BUTTON_TEXT_ON_GREEN)
	else:
		_style_button(_end_turn_btn, "normal")

	_refresh_offer_strip(state)
	_refresh_trade_tray(state, acting_id, human_acting)
	if not state.open_trade.is_empty() and (bar_human or _early_answer_pid() >= 0):
		if _board_view.interaction_mode == BoardView.InteractionMode.NONE and not _pending_guard_card:
			_set_banner(_compute_instruction(state, acting_id, human_acting))

	var can_buy := in_main and RulesEngine.can_afford(state, bar_pid, "dev_card") and not state.dev_deck.is_empty()
	_buy_card_btn.disabled = not can_buy or _bar_locked
	if can_buy:
		_buy_card_btn.tooltip_text = "Buy an Action Card: 1 Fleece + 1 Grain + 1 Iron \u00b7 deck left: %s" % _dev_deck_summary(state)
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
			_buy_card_btn.tooltip_text = "Buy an Action Card: 1 Fleece + 1 Grain + 1 Iron \u00b7 deck left: %s" % _dev_deck_summary(state)
	else:
		_buy_card_btn.tooltip_text = _blocked_reason(state, human_acting)


func _update_mandatory_board_highlights(state: GameState, acting_id: int, human_acting: bool) -> void:
	if not _steal_pending.is_empty():
		return
	if not human_acting:
		_cancel_build_bubble()
		_board_view.clear_highlights()
		_hint_sig = ""
		var waiting_for_my_offer := (
			not state.open_trade.is_empty()
			and int(state.open_trade.get("from", -1)) == _view_pid()
		)
		if state.phase != GameTypes.TurnPhase.GAME_OVER and not waiting_for_my_offer:
			_set_banner("%s is thinking…" % _seat_display_name(acting_id))
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
	var trade_blocks_builds := (
		not state.open_trade.is_empty()
		and int(state.open_trade.get("from", -1)) != acting_id
	)
	if trade_blocks_builds or _pending_guard_card or _any_overlay_visible():
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
	st.border_color = Palette.ACCENT_GOLD_BORDER
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
	if not (_is_human_acting() or _own_offer_takeover()) or session.state.phase != GameTypes.TurnPhase.TURN_MAIN:
		return
	if (
		not session.state.open_trade.is_empty()
		and int(session.state.open_trade.get("from", -1)) != _view_pid()
	) or _board_view.interaction_mode != BoardView.InteractionMode.BUILD_ANY:
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
	if _build_pending.is_empty() or not (_is_human_acting() or _own_offer_takeover()):
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
	if not (_is_human_acting() or _own_offer_takeover()):
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
	if _ot_awaits_view():
		return
	if _trade_tray != null and _trade_tray.visible:
		_close_trade_tray_by_user()

func _on_board_tile_clicked(tile_id: int) -> void:
	if _review_active:
		return
	if not (_is_human_acting() or _own_offer_takeover()):
		return
	if _board_view.interaction_mode == BoardView.InteractionMode.PICK_BLOCKER_TILE:
		var acting_id := session.get_acting_player_id()
		if not _steal_pending.is_empty():
			if tile_id == int(_steal_pending.get("tile_id", -1)):
				return
			if not _board_view.highlighted_tiles.has(tile_id):
				return
			_close_steal_chooser()
		var victims: Array[int] = RulesEngine.get_steal_victims(session.state, acting_id, tile_id)
		if victims.size() >= 2:
			_show_steal_targets(tile_id, victims)
			return
		var target_opp: int = victims[0] if victims.size() == 1 else -1
		var tile_before := int(session.state.blocker_tile)
		if _pending_guard_card:
			_submit_human_action(GameAction.play_guard(tile_id, target_opp))
		else:
			_submit_human_action(GameAction.move_blocker(tile_id, target_opp))
		# The info toast only when the move really happened: a rejected action
		# leaves the Blocker elsewhere. Guard plays move the Blocker too
		# (_execute_blocker_move), so the same check covers both branches.
		if victims.is_empty() and int(session.state.blocker_tile) == tile_id and tile_id != tile_before:
			_show_toast("Blocker moved — no one there to steal from.", Palette.TOAST_NEUTRAL, 3.5)

func _show_blocker_ghost(tile_id: int) -> void:
	if _blocker_ghost == null:
		_blocker_ghost = Panel.new()
		var gs := StyleBoxFlat.new()
		gs.set_corner_radius_all(18)
		gs.bg_color = Color(Palette.BLOCKER_GHOST_BG, 0.6)
		gs.border_color = Palette.ACCENT_GOLD
		gs.set_border_width_all(3)
		gs.shadow_color = Color(0, 0, 0, 0.35)
		gs.shadow_size = 6
		_blocker_ghost.add_theme_stylebox_override("panel", gs)
		_blocker_ghost.custom_minimum_size = Vector2(36, 36)
		_blocker_ghost.size = Vector2(36, 36)
		_blocker_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_blocker_ghost.z_index = 40
		add_child(_blocker_ghost)
	_blocker_ghost.visible = true
	if _board_view != null and tile_id >= 0:
		var spot := _board_view.global_position + _board_view.get_spot_screen_position("tile", tile_id)
		_blocker_ghost.global_position = spot - Vector2(18, 18)

func _show_steal_targets(tile_id: int, victims: Array[int]) -> void:
	_steal_pending = {"tile_id": tile_id, "guard": _pending_guard_card}
	_steal_victims = victims.duplicate()
	var targets: Array = []
	for i in range(victims.size()):
		var pid: int = victims[i]
		var hand_n: int = GameTypes.hand_total(session.state.players[pid]["hand"])
		targets.append({
			"pid": pid,
			"vertex": _pick_steal_vertex(pid, tile_id),
			"label": "%s · %d card%s" % [str(session.state.players[pid].get("name", GameTypes.PLAYER_NAMES[pid])), hand_n, "" if hand_n == 1 else "s"],
			"color": GameTypes.PLAYER_COLORS[pid],
			"key": i + 1,
		})
	_board_view.set_steal_targets(targets, tile_id)
	_show_blocker_ghost(tile_id)
	_set_banner("Click a marked player to steal from, or click another hex — keys 1-%d, Esc picks another tile" % victims.size())

func _pick_steal_vertex(pid: int, tile_id: int) -> int:
	var topo := HexMath.get_topology()
	var best := -1
	var best_score := -1000000
	for v in topo.tile_vertices[tile_id]:
		if int(session.state.vertex_owner[v]) != pid:
			continue
		var score := 0
		if int(session.state.vertex_building[v]) == int(GameTypes.BuildingType.CITY):
			score += 100000000
		var room := _board_view.get_spot_screen_position("vertex", int(v)).distance_to(_board_view.size * 0.5)
		score += int(room * 1000.0)
		score -= int(v)
		if score > best_score:
			best_score = score
			best = int(v)
	return best

func _on_steal_target_clicked(player_id: int) -> void:
	if _steal_pending.is_empty() or not _is_human_acting() or _hand_hidden():
		return
	var idx := _steal_victims.find(player_id)
	if idx < 0:
		return
	_on_steal_victim_pressed(idx)

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
	if _board_view != null:
		_board_view.set_steal_targets([], -1)
	if _blocker_ghost != null:
		_blocker_ghost.visible = false

func _cancel_steal_chooser() -> void:
	_close_steal_chooser()
	_refresh_ui()

# Toolbar button handlers
func _on_roll_pressed() -> void:
	if _review_active:
		return
	_submit_human_action(GameAction.roll_dice())

func _on_end_turn_pressed() -> void:
	if _review_active:
		return
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
	if _review_active:
		return
	_submit_human_action(GameAction.buy_dev_card())

func _on_play_guard_pressed() -> void:
	if _review_active:
		return
	if not (_is_human_acting() or _own_offer_takeover()):
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
	if _review_active:
		return
	_submit_human_action(GameAction.play_road_work())

func _on_play_bounty_pressed() -> void:
	if _review_active:
		return
	_on_toggle_bounty_panel()

func _on_play_decree_pressed() -> void:
	if _review_active:
		return
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
	if _offer_strip_spacer != null:
		_offer_strip_spacer.visible = not needs_discard
	_bar_locked = needs_discard
	_layout_hand_overlay()
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
	_discard_heading.text = "Discard %d cards: click cards in your hand (picked %d of %d)" % [req_cnt, picked, req_cnt]
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
	if _review_active:
		return
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

func _close_subpanel_from_outside() -> void:
	# Pure dismissal: no card is played and no game state changes.
	_hide_all_subpanels()
	if _subpanel_container != null and is_instance_valid(_subpanel_container):
		_subpanel_container.visible = false
	_subpanel_owner_pid = -1

# The scrim is on top of everything except the popup itself (which is a
# later sibling and takes its own clicks), so it decides what an outside
# press means: the same card toggles closed, the other popup card swaps in
# one click, and every other press (board, sidebar, empty hand bar, End
# Turn, resource cards) only closes - the press is consumed, so the closing
# click never also acts on what is underneath it.
func _on_subpanel_scrim_input(event: InputEvent) -> void:
	if _subpanel_container == null or not _subpanel_container.visible:
		return
	var g: Vector2 = Vector2.INF
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		g = mb.global_position
	elif event is InputEventScreenTouch:
		var st_ev := event as InputEventScreenTouch
		if not st_ev.pressed:
			return
		g = st_ev.global_position
	else:
		return
	if _subpanel_container.get_global_rect().has_point(g):
		return
	var bounty_chip: CardFace = _popup_chip_by_type.get(GameTypes.DevCardType.HARVEST_BOUNTY)
	var decree_chip: CardFace = _popup_chip_by_type.get(GameTypes.DevCardType.TRADE_DECREE)
	if bounty_chip != null and is_instance_valid(bounty_chip) and bounty_chip.is_visible_in_tree() and bounty_chip.get_global_rect().has_point(g):
		if _bounty_box.visible:
			_close_subpanel_from_outside()
		else:
			_on_toggle_bounty_panel()
		get_viewport().set_input_as_handled()
		return
	if decree_chip != null and is_instance_valid(decree_chip) and decree_chip.is_visible_in_tree() and decree_chip.get_global_rect().has_point(g):
		if _decree_box.visible:
			_close_subpanel_from_outside()
		else:
			_on_toggle_decree_panel()
		get_viewport().set_input_as_handled()
		return
	_close_subpanel_from_outside()
	get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------
# Trade tray (open trade: propose to all, respond, bank as one partner)
# ---------------------------------------------------------------------
func _build_trade_tray(parent_column: VBoxContainer) -> void:
	_trade_slot = PanelContainer.new()
	# p39: the slot no longer clips. Its square clip rect cut the frame's soft
	# shadow at the top-left corner into a hard wedge; the frame's shadow is
	# small (7 px, offset 2) and the neighbours only receive soft shading.
	var sst := StyleBoxEmpty.new()
	sst.content_margin_left = 8
	sst.content_margin_right = 8
	sst.content_margin_top = 5
	sst.content_margin_bottom = 5
	_trade_slot.add_theme_stylebox_override("panel", sst)
	_trade_slot.custom_minimum_size = Vector2(0, 214)
	parent_column.add_child(_trade_slot)
	_trade_host = Control.new()
	_trade_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_slot.add_child(_trade_host)
	_trade_frame = Panel.new()
	_trade_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_raised_card(_trade_frame)
	_trade_host.add_child(_trade_frame)
	_trade_slot.resized.connect(_layout_trade_slot)
	_trade_idle_lbl = Label.new()
	_trade_idle_lbl.text = ""
	_trade_idle_lbl.visible = false
	_trade_idle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trade_idle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trade_idle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_idle_lbl.add_theme_font_size_override("font_size", 12)
	_trade_idle_lbl.add_theme_color_override("font_color", Palette.TEXT)
	_trade_idle_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_trade_host.add_child(_trade_idle_lbl)
	_trade_tray = PanelContainer.new()
	_trade_tray.visible = false
	_trade_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_tray.size_flags_vertical = Control.SIZE_FILL
	var st := _paper_panel_style(true)
	st.bg_color = Palette.SURFACE_RAISED
	st.set_corner_radius_all(8)
	st.set_border_width_all(0)
	st.border_color = Color(0, 0, 0, 0)
	st.shadow_size = 0
	st.content_margin_left = 0
	st.content_margin_right = 0
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	_trade_tray.add_theme_stylebox_override("panel", st)
	_trade_tray.clip_contents = true
	_trade_tray.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_trade_host.add_child(_trade_tray)
	_layout_trade_slot()

	_trade_scroll = ScrollContainer.new()
	_trade_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trade_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_trade_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_trade_tray.add_child(_trade_scroll)
	_trade_content = VBoxContainer.new()
	_trade_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_content.add_theme_constant_override("separation", 2)
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
	_trade_close_btn.custom_minimum_size = Vector2(22, 22)
	_trade_close_btn.add_theme_font_size_override("font_size", 11)
	_style_button(_trade_close_btn, "ghost")
	_flatten_trade_button(_trade_close_btn)
	_trade_close_btn.pressed.connect(_close_trade_tray_by_user)
	_guard_action_button_focus(_trade_close_btn)
	head_row.add_child(_trade_close_btn)

	# Body: card bands on the left, the status rows in a narrow right rail, so
	# the bigger resource cards fit the fixed panel frame in every view.
	_trade_body_row = HBoxContainer.new()
	_trade_body_row.add_theme_constant_override("separation", 8)
	_trade_body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A worst-case trade body (five resource kinds on one side) must never
	# widen the tray: host the row in a horizontal scroll so its minimum width
	# cannot propagate up into the sidebar layout.
	var body_scroll := ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(_trade_body_row)
	_trade_content.add_child(body_scroll)
	_trade_left_col = VBoxContainer.new()
	_trade_left_col.add_theme_constant_override("separation", 2)
	_trade_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_body_row.add_child(_trade_left_col)
	_trade_right_col = VBoxContainer.new()
	_trade_right_col.add_theme_constant_override("separation", 2)
	_trade_right_col.custom_minimum_size = Vector2(150, 0)
	_trade_right_col.visible = false
	_trade_body_row.add_child(_trade_right_col)
	var rail_pad := Control.new()
	rail_pad.custom_minimum_size = Vector2(8, 0)
	rail_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_body_row.add_child(rail_pad)

	# Editor rows (propose / edit own offer / counter draft)
	_trade_rows_col = VBoxContainer.new()
	_trade_rows_col.add_theme_constant_override("separation", 2)
	_trade_left_col.add_child(_trade_rows_col)

	# Respond view: the incoming offer as a read-only band + answer buttons.
	_trade_respond_view = VBoxContainer.new()
	_trade_respond_view.add_theme_constant_override("separation", 2)
	_trade_respond_view.visible = false
	_trade_left_col.add_child(_trade_respond_view)

	# Watch view: someone else's offer, read-only band; answers in the rail.
	_trade_watch_col = VBoxContainer.new()
	_trade_watch_col.add_theme_constant_override("separation", 2)
	_trade_watch_col.visible = false
	_trade_left_col.add_child(_trade_watch_col)

	_build_trade_bands()
	_build_trade_card_rows()

	_trade_respond_row = HBoxContainer.new()
	_trade_respond_row.add_theme_constant_override("separation", 6)
	_trade_respond_view.add_child(_trade_respond_row)
	_ot_accept_btn = _make_tray_button("Accept", "primary", "Accept this offer")
	_ot_accept_btn.pressed.connect(_on_accept_offer_pressed)
	_trade_respond_row.add_child(_ot_accept_btn)
	_ot_decline_btn = _make_tray_button("Decline", "ghost", "Decline this offer")
	_ot_decline_btn.pressed.connect(_on_decline_offer_pressed)
	_trade_respond_row.add_child(_ot_decline_btn)
	_ot_counter_btn = _make_tray_button("Counter\u2026", "normal", "Propose different terms")
	_ot_counter_btn.pressed.connect(_on_counter_offer_pressed)
	_trade_respond_row.add_child(_ot_counter_btn)
	_trade_have_label = Label.new()
	_trade_have_label.add_theme_font_size_override("font_size", 10)
	_trade_have_label.add_theme_color_override("font_color", Palette.TEXT)
	_trade_have_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_have_label.custom_minimum_size = Vector2(280, 0)
	_trade_have_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_trade_have_label.max_lines_visible = 2
	_trade_respond_view.add_child(_trade_have_label)

	_trade_btn_row = HBoxContainer.new()
	_trade_btn_row.add_theme_constant_override("separation", 4)
	_trade_left_col.add_child(_trade_btn_row)
	_trade_ask_btn = _make_tray_button("Ask players", "primary", "Post this offer to every other player")
	# p50c: a offers label that wraps makes the row taller; SHRINK_BEGIN keeps every
	# button 24 px high at the row's top edge whatever the row's height.
	_trade_ask_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trade_ask_btn.pressed.connect(_on_ask_players_pressed)
	_trade_btn_row.add_child(_trade_ask_btn)
	_trade_resend_btn = _make_tray_button("Send new offer", "primary", "Cancel this offer and post the new one")
	_trade_resend_btn.visible = false
	_trade_resend_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trade_resend_btn.pressed.connect(_on_resend_offer_pressed)
	_trade_btn_row.add_child(_trade_resend_btn)
	_trade_clear_btn = _make_tray_button("Clear", "ghost", "Reset both sides of the offer")
	_trade_clear_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trade_clear_btn.pressed.connect(_on_clear_trade_pressed)
	_trade_btn_row.add_child(_trade_clear_btn)
	_trade_ratio_btn = _make_tray_button("Bank 4:1", "normal", "Swap these cards with the bank at this ratio")
	_trade_ratio_btn.visible = false
	_trade_ratio_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trade_ratio_btn.pressed.connect(_on_bank_trade_pressed)
	# p50c: the bank button sits after Clear and, while a plain offer is drafted,
	# lives in a slot that reserves its longest label's measured width, so Clear
	# and the relabelling button never slide (see _set_bank_slot_reserve).
	_trade_ratio_slot = _make_tray_button_slot(_trade_btn_row, [_trade_ratio_btn], TRADE_BANK_LABELS)
	_trade_ratio_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_trade_bank_slot_width = _trade_ratio_slot.custom_minimum_size.x
	_trade_ratio_slot.custom_minimum_size = Vector2(0.0, 0.0)
	_trade_offers_lbl = Label.new()
	_trade_offers_lbl.add_theme_font_size_override("font_size", 10)
	_trade_offers_lbl.add_theme_color_override("font_color", Palette.TEXT)
	_trade_offers_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_offers_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_offers_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# p50c: the normal offers text is the short "Offers 0/3" form, so the whole
	# sentence lives in the tooltip and a Label must take the mouse to show it.
	_trade_offers_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_trade_offers_lbl.visible = false
	_trade_btn_row.add_child(_trade_offers_lbl)

	_trade_counter_row = HBoxContainer.new()
	_trade_counter_row.add_theme_constant_override("separation", 4)
	_trade_counter_row.visible = false
	_trade_left_col.add_child(_trade_counter_row)
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
	_trade_right_col.add_child(_trade_partner_stack)

	_watch_rows_col = VBoxContainer.new()
	_watch_rows_col.add_theme_constant_override("separation", 2)
	_watch_rows_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_watch_rows_col.visible = false
	_trade_right_col.add_child(_watch_rows_col)

	_trade_no_takers_lbl = Label.new()
	_trade_no_takers_lbl.text = "No takers \u2014 withdraw or change your offer"
	_trade_no_takers_lbl.add_theme_font_size_override("font_size", 11)
	_trade_no_takers_lbl.add_theme_color_override("font_color", Palette.STATUS_BAD_TEXT)
	_trade_no_takers_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_no_takers_lbl.visible = false
	_trade_no_takers_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_left_col.add_child(_trade_no_takers_lbl)

	for r in GameTypes.ALL_RESOURCES:
		_trade_give_counts[r] = 0
		_trade_get_counts[r] = 0

func _band_caption(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Palette.HEADING)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_trade_bands() -> void:
	_build_one_band("ed", "You give", "You get", _trade_rows_col)
	_build_one_band("ro", "You get", "You give", _trade_respond_view)
	_build_one_band("wa", "offers", "wants", _trade_watch_col)
	_trade_give_box = _band_box_a["ed"]
	_trade_get_box = _band_box_b["ed"]
	_trade_ro_get_box = _band_box_a["ro"]
	_trade_ro_give_box = _band_box_b["ro"]
	_watch_terms_get_box = _band_box_a["wa"]
	_watch_terms_give_box = _band_box_b["wa"]

func _build_one_band(ctx: String, cap_a: String, cap_b: String, host: Control) -> void:
	var side := HBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.visible = false
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col_a := VBoxContainer.new()
	col_a.add_theme_constant_override("separation", 2)
	col_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var la := _band_caption(cap_a)
	col_a.add_child(la)
	var box_a := HBoxContainer.new()
	box_a.add_theme_constant_override("separation", 2)
	box_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_a.add_child(box_a)
	side.add_child(col_a)
	var arrow := Label.new()
	arrow.text = "\u2192"
	arrow.add_theme_font_size_override("font_size", 14)
	arrow.add_theme_color_override("font_color", Palette.TEXT)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(arrow)
	var col_b := VBoxContainer.new()
	col_b.add_theme_constant_override("separation", 2)
	col_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb := _band_caption(cap_b)
	col_b.add_child(lb)
	var box_b := HBoxContainer.new()
	box_b.add_theme_constant_override("separation", 2)
	box_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_b.add_child(box_b)
	side.add_child(col_b)
	host.add_child(side)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	stack.visible = false
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row_a := HBoxContainer.new()
	row_a.add_theme_constant_override("separation", 5)
	row_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ca := _band_caption(cap_a)
	ca.custom_minimum_size = Vector2(52, 0)
	ca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row_a.add_child(ca)
	stack.add_child(row_a)
	var row_b := HBoxContainer.new()
	row_b.add_theme_constant_override("separation", 5)
	row_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cb := _band_caption(cap_b)
	cb.custom_minimum_size = Vector2(52, 0)
	cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row_b.add_child(cb)
	stack.add_child(row_b)
	host.add_child(stack)
	_band_side[ctx] = side
	_band_stack[ctx] = stack
	_band_side_a[ctx] = col_a
	_band_side_b[ctx] = col_b
	_band_row_a[ctx] = row_a
	_band_row_b[ctx] = row_b
	_band_box_a[ctx] = box_a
	_band_box_b[ctx] = box_b
	_band_gate[ctx] = true
	_band_cap_a[ctx] = la
	_band_cap_b[ctx] = lb
	_band_st_cap_a[ctx] = ca
	_band_st_cap_b[ctx] = cb

func _set_band_captions(ctx: String, a_txt: String, b_txt: String) -> void:
	for d in [_band_cap_a, _band_cap_b, _band_st_cap_a, _band_st_cap_b]:
		var lbl: Label = d.get(ctx) as Label
		if lbl != null:
			lbl.text = a_txt if d == _band_cap_a or d == _band_st_cap_a else b_txt

const _TRADE_CARD_MAX_W := 44.0
const _TRADE_CARD_MIN_W := 44.0
const _TRADE_CARD_MIN_H := 58.0

func _band_box_count(box: Control) -> int:
	if box == null:
		return 1
	return maxi(1, int(_box_n.get(box.get_instance_id(), 0)))

func _set_band_mode(ctx: String, side: bool) -> void:
	var ba := _band_box_a.get(ctx) as Control
	var bb := _band_box_b.get(ctx) as Control
	if ba == null or bb == null:
		return
	if side:
		if ba.get_parent() != _band_side_a.get(ctx):
			ba.reparent(_band_side_a[ctx] as Control, true)
		if bb.get_parent() != _band_side_b.get(ctx):
			bb.reparent(_band_side_b[ctx] as Control, true)
	else:
		if ba.get_parent() != _band_row_a.get(ctx):
			ba.reparent(_band_row_a[ctx] as Control, true)
		if bb.get_parent() != _band_row_b.get(ctx):
			bb.reparent(_band_row_b[ctx] as Control, true)
	if ctx == "ed" and _trade_give_hint_lbl != null:
		var tgt := (_band_side_a[ctx] if side else _band_row_a[ctx]) as Control
		if _trade_give_hint_lbl.get_parent() != tgt:
			_trade_give_hint_lbl.reparent(tgt, true)
	var gate: bool = bool(_band_gate.get(ctx, true))
	(_band_side[ctx] as Control).visible = side and gate
	(_band_stack[ctx] as Control).visible = (not side) and gate

func _apply_band_px(ctx: String, n_a: int, n_b: int, avail: float) -> void:
	n_a = clampi(n_a, 0, 5)
	n_b = clampi(n_b, 0, 5)
	var gw := 0.0
	var tw := 0.0
	var w := _TRADE_CARD_MAX_W
	while true:
		gw = maxf(52.0, float(n_a) * w + 3.0 * float(maxi(0, n_a - 1)))
		tw = float(n_b) * w + 3.0 * float(maxi(0, n_b - 1))
		if gw + 20.0 + tw <= avail or w <= _TRADE_CARD_MIN_W:
			break
		w -= 1.0
	var stacked := gw + 20.0 + tw > avail
	var px := Vector2(_TRADE_CARD_MIN_W, _TRADE_CARD_MIN_H) if stacked else Vector2(w, w / CardFace.RATIO)
	for box_v in [_band_box_a.get(ctx), _band_box_b.get(ctx)]:
		var box := box_v as Control
		if box == null:
			continue
		for c in box.get_children():
			if c is CardFace:
				var cf := c as CardFace
				if cf.custom_minimum_size != px:
					cf.custom_minimum_size = px
	_set_band_mode(ctx, not stacked)

func _retune_trade_chip_sizes() -> void:
	if not _trade_chip_size_dirty:
		return
	_trade_chip_size_dirty = false
	_apply_trade_chip_sizes()

func _apply_trade_rail_width() -> void:
	# The answers rail (partner/counter cards, watch rows) is short in
	# height and wide in content; give it the free panel width so counter
	# cards and icon rows read on one line and never spill past the panel.
	if _trade_right_col == null:
		return
	var rail_w := 150.0
	if _trade_right_col.visible and _trade_left_col != null:
		var left_w: float = _trade_left_col.get_combined_minimum_size().x if _trade_left_col.visible else 0.0
		var avail_w: float = _trade_scroll.size.x if _trade_scroll != null and _trade_scroll.size.x > 0.0 else _trade_content.size.x
		if avail_w <= 0.0:
			avail_w = 460.0
		# -32: 16 px of panel inset plus the scroll content's side margins;
		# the body row's minimum must stay under the viewport width or the
		# panel grows a horizontal scrollbar.
		rail_w = clampf(avail_w - 32.0 - left_w, 150.0, 320.0)
	_trade_rail_w = rail_w
	_trade_right_col.custom_minimum_size = Vector2(rail_w, 0)
	if _trade_have_label != null:
		# The 280 px floor for the "You have: ..." line only applies when the
		# rail is hidden; side by side it would squeeze the rows out of the
		# panel (the text wraps fine in the narrower column).
		var have_w := 280.0 if not _trade_right_col.visible else 160.0
		if absf(_trade_have_label.custom_minimum_size.x - have_w) > 0.5:
			_trade_have_label.custom_minimum_size = Vector2(have_w, 0)

func _apply_trade_chip_sizes() -> void:
	if _band_side.is_empty():
		return
	var right_shown := _trade_right_col != null and _trade_right_col.visible
	var cw := 474.0
	# Chip minimums widen the tray content, and sizing from that content feeds the
	# width back into the chips, so every plain refresh grew the tray ~5 px (479,
	# 484, 489, 494, 499, 509...). 474 is the design width of the tray column.
	if _trade_content != null and _trade_content.size.x > 100.0:
		cw = minf(_trade_content.size.x, 474.0)
	var avail := cw - (166.0 if right_shown else 0.0)
	var ed_a := 0
	for r in GameTypes.ALL_RESOURCES:
		if int(_trade_give_counts.get(r, 0)) > 0:
			ed_a += 1
	_apply_band_px("ed", ed_a, 5, avail)
	_apply_band_px("ro", _band_box_count(_trade_ro_get_box), _band_box_count(_trade_ro_give_box), avail)
	_apply_band_px("wa", _band_box_count(_watch_terms_get_box), _band_box_count(_watch_terms_give_box), avail)

func _fill_ro_row(box: HBoxContainer, bundle: Dictionary, missing: Dictionary) -> void:
	var bid := box.get_instance_id()
	if not _ro_pools.has(bid):
		var pool: Array[CardFace] = []
		for r in GameTypes.ALL_RESOURCES:
			var f := CardFace.new()
			f.kind = "resource"
			f.resource = r
			f.custom_minimum_size = Vector2(_TRADE_CARD_MIN_W, _TRADE_CARD_MIN_H)
			f.show_name = false
			f.vivid = true
			f.focusable = false
			f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			f.visible = false
			f.count_badge = false
			box.add_child(f)
			pool.append(f)
		var none := Label.new()
		none.text = "nothing"
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", Palette.TEXT)
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		none.visible = false
		box.add_child(none)
		_ro_pools[bid] = pool
		_ro_none_labels[bid] = none
	var pool2: Array = _ro_pools[bid]
	var any_shown := false
	var shown_kinds := 0
	var idx := 0
	for r in GameTypes.ALL_RESOURCES:
		var f: CardFace = pool2[idx]
		idx += 1
		var want := int(bundle.get(r, 0))
		f.visible = want > 0
		if want > 0:
			any_shown = true
			shown_kinds += 1
			f.resource = r
			f.count = want
			f.count_badge = want > 0
			f.disabled = missing.has(r)
			f.tooltip_text = "%s \u00d7%d" % [GameTypes.resource_name(r), want]
		else:
			f.count = 0
			f.count_badge = false
			f.disabled = false
		(_ro_none_labels[bid] as Label).visible = not any_shown
	_box_n[bid] = shown_kinds

func _build_trade_card_rows() -> void:
	for r in GameTypes.ALL_RESOURCES:
		var chip := CardFace.new()
		chip.kind = "resource"
		chip.resource = r
		chip.custom_minimum_size = Vector2(_TRADE_CARD_MIN_W, _TRADE_CARD_MIN_H)
		chip.show_name = false
		chip.vivid = true
		chip.selected = true
		chip.focus_mode = Control.FOCUS_NONE
		chip.visible = false
		chip.count_clickable = true
		chip.pressed.connect(func() -> void: _adjust_trade_count(true, chip.resource, 1))
		chip.count_pressed.connect(func() -> void: _adjust_trade_count(true, chip.resource, -1))
		chip.right_pressed.connect(func() -> void: _adjust_trade_count(true, chip.resource, -1))
		_trade_give_box.add_child(chip)
		_give_chip_pool.append(chip)
	_trade_give_hint_lbl = Label.new()
	_trade_give_hint_lbl.text = "Click your cards below"
	_trade_give_hint_lbl.add_theme_font_size_override("font_size", 10)
	_trade_give_hint_lbl.add_theme_color_override("font_color", Palette.TEXT)
	_trade_give_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trade_give_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trade_give_hint_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	(_band_side_a["ed"] as Control).add_child(_trade_give_hint_lbl)
	for r in GameTypes.ALL_RESOURCES:
		var face := CardFace.new()
		face.kind = "resource"
		face.resource = r
		face.custom_minimum_size = Vector2(_TRADE_CARD_MIN_W, _TRADE_CARD_MIN_H)
		face.show_name = false
		face.vivid = true
		face.count_clickable = true
		var res := r
		face.pressed.connect(func() -> void: _adjust_trade_count(false, res, 1))
		face.count_pressed.connect(func() -> void: _adjust_trade_count(false, res, -1))
		face.right_pressed.connect(func() -> void: _adjust_trade_count(false, res, -1))
		_trade_get_box.add_child(face)
		_trade_get_faces[r] = face

func _rebuild_trade_chip_rows(unlocked: bool) -> void:
	_apply_trade_chip_sizes()
	var slot := 0
	for r in GameTypes.ALL_RESOURCES:
		var cnt: int = int(_trade_give_counts.get(r, 0))
		if cnt <= 0:
			continue
		if slot >= _give_chip_pool.size():
			break
		var chip: CardFace = _give_chip_pool[slot]
		slot += 1
		chip.visible = true
		chip.resource = r
		chip.count = cnt
		chip.count_badge = cnt > 0
		chip.disabled = not unlocked
		chip.tooltip_text = "Tap the card to add one \u2014 tap the count to remove one"
	for i in range(slot, _give_chip_pool.size()):
		var hidden_chip2: CardFace = _give_chip_pool[i]
		hidden_chip2.visible = false
		hidden_chip2.count = 0
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
		# p51: the badge headroom is reserved whether or not this face has a count,
		# so all five get cards in the row share one drawn frame; the badge itself
		# is only drawn when count > 0 (CardFace._draw_badges).
		face.count_badge = true
		face.disabled = not unlocked
		face.tooltip_text = "Tap the card to add one \u2014 tap the count to remove one"

func _make_tray_button(btn_text: String, kind: String, tip: String) -> Button:
	var b := Button.new()
	b.text = btn_text
	b.custom_minimum_size = Vector2(0, 24)
	b.add_theme_font_size_override("font_size", 12)
	b.tooltip_text = tip
	_style_button(b, kind)
	_flatten_trade_button(b)
	return b

# p50c: a fixed-width holder inside the compose row for the bank button, whose
# label changes (Bank 4:1 / Port 2:1 / Port 3:1 / Bank / Port) and which shows and
# hides with the drafted offer. The width is measured from the button itself,
# never guessed; _set_bank_slot_reserve decides when the slot reserves it.
func _make_tray_button_slot(parent_row: HBoxContainer, buttons: Array, labels: Array[String]) -> MarginContainer:
	var slot := MarginContainer.new()
	for m in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		slot.add_theme_constant_override(m, 0)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_row.add_child(slot)
	for b in buttons:
		slot.add_child(b as Control)
	slot.custom_minimum_size = Vector2(_widest_button_text_width(buttons[0] as Button, labels), 0.0)
	return slot

# The widest minimum the button itself asks for across every label it can be given,
# read at the font it really renders with (the caller keeps the buttons in the tree).
func _widest_button_text_width(btn: Button, labels: Array[String]) -> float:
	var keep := btn.text
	var widest := 0.0
	for t in labels:
		btn.text = t
		btn.update_minimum_size()
		widest = maxf(widest, btn.get_combined_minimum_size().x)
	btn.text = keep
	btn.update_minimum_size()
	return widest

# p50c: the slot reserves the measured width only while a plain offer is being
# drafted (propose_idle and the offer cap not hit); every other state keeps the
# row exactly as before and shows the slot only together with its button, at the
# button's own width. The reserve flag is remembered so a resize re-applies it.
func _set_bank_slot_reserve(reserve: bool) -> void:
	if _trade_ratio_slot == null or not is_instance_valid(_trade_ratio_slot):
		return
	if _trade_ratio_btn == null or not is_instance_valid(_trade_ratio_btn):
		return
	_trade_bank_slot_reserve = reserve
	var want_w := _trade_bank_slot_width if reserve else 0.0
	if not is_equal_approx(_trade_ratio_slot.custom_minimum_size.x, want_w):
		_trade_ratio_slot.custom_minimum_size = Vector2(want_w, 0.0)
	var want_vis := reserve or _trade_ratio_btn.visible
	if _trade_ratio_slot.visible != want_vis:
		_trade_ratio_slot.visible = want_vis

# p50c: a window resize or a style switch changes the metrics the slot was
# measured with, so the width is measured again when the tray is laid out.
func _sync_compose_slot_widths() -> void:
	if _trade_ratio_slot == null or not is_instance_valid(_trade_ratio_slot):
		return
	if _trade_ratio_btn == null or not is_instance_valid(_trade_ratio_btn):
		return
	var w := _widest_button_text_width(_trade_ratio_btn, TRADE_BANK_LABELS)
	if is_equal_approx(w, _trade_bank_slot_width):
		return
	_trade_bank_slot_width = w
	if _trade_bank_slot_reserve:
		_trade_ratio_slot.custom_minimum_size = Vector2(w, 0.0)

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

func _ot_token(ot: Dictionary) -> String:
	if ot.is_empty():
		return ""
	return "%d|%s|%s" % [int(ot.get("from", -1)), str(ot.get("offer", {})), str(ot.get("request", {}))]

# The human seat that has already answered an open offer and may revise its
# answer while the offer is still live (-1 when nobody can).
func _trade_revise_pid_calc() -> int:
	if session == null or session.state == null or _review_active:
		return -1
	var st: GameState = session.state
	var ot: Dictionary = st.open_trade
	if ot.is_empty():
		return -1
	var from_p := int(ot.get("from", -1))
	var my_pid := _view_pid()
	if my_pid < 0 or my_pid >= st.num_players or my_pid == from_p:
		return -1
	if my_pid < session.seats.size() and session.seats[my_pid].is_ai():
		return -1
	var responses: Dictionary = ot.get("responses", {})
	if not responses.has(my_pid):
		return -1
	return my_pid

# p47: in a single-human game the human may answer an AI's offer right away,
# before the paced AI answer wave reaches them. Returns the human's pid in
# that state, -1 otherwise. Hot-seat games keep the old watch-only behaviour.
func _early_answer_pid() -> int:
	if _review_active:
		return -1
	if session == null or session.state == null:
		return -1
	if _human_seat_count() != 1:
		return -1
	var st: GameState = session.state
	var ot: Dictionary = st.open_trade
	if ot.is_empty():
		return -1
	var my_pid := _view_pid()
	if my_pid < 0 or my_pid >= st.num_players or my_pid >= session.seats.size():
		return -1
	if session.seats[my_pid].is_ai():
		return -1
	if int(ot.get("from", -1)) == my_pid:
		return -1
	if _is_human_acting():
		return -1
	if _hand_hidden():
		return -1
	var responses: Dictionary = ot.get("responses", {})
	if responses.has(my_pid):
		return -1
	return my_pid

func _ot_awaits_view() -> bool:
	if session == null or session.state == null:
		return false
	var st := session.state
	var ot: Dictionary = st.open_trade
	if ot.is_empty():
		return false
	if _early_answer_pid() >= 0:
		return true
	if not _is_human_acting():
		return false
	if int(ot.get("from", -1)) == _view_pid():
		return false
	if session.get_acting_player_id() != _view_pid():
		return false
	var responses: Dictionary = ot.get("responses", {})
	return not responses.has(_view_pid())

func _human_can_progress() -> bool:
	if session == null or session.state == null:
		return true
	var st := session.state
	if st.phase == GameTypes.TurnPhase.GAME_OVER:
		return true
	if not _is_human_acting():
		return true
	if _hand_hidden():
		return true
	if _can_roll_now() and _dice_widget != null and is_instance_valid(_dice_widget) and _dice_widget.visible:
		return true
	if _end_turn_btn != null and _end_turn_btn.visible and not _end_turn_btn.disabled:
		return true
	if _cancel_pick_btn != null and _cancel_pick_btn.visible:
		return true
	if _offer_strip_respond_btn != null and _offer_strip_respond_btn.visible and not _offer_strip_respond_btn.disabled:
		return true
	if _trade_tray != null and _trade_tray.visible:
		for b in [_ot_accept_btn, _ot_decline_btn, _ot_counter_btn, _ot_send_btn, _ot_back_btn, _trade_ask_btn, _trade_ratio_btn, _trade_resend_btn]:
			if b != null and b.visible and not b.disabled:
				return true
	return false

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
	if st.phase == GameTypes.TurnPhase.GAME_OVER:
		return false
	if _early_answer_pid() >= 0:
		return true
	if not _is_human_acting():
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
	if _ot_awaits_view():
		var answer_pid := _early_answer_pid()
		if answer_pid < 0:
			answer_pid = session.get_acting_player_id()
		session.submit_action(answer_pid, GameAction.respond_open_trade("decline"))
		_set_tray_panel_visible(false)
		_release_tray_focus()
		_trade_counter_mode = false
		_trade_reopen_token = ""
		return
	_set_tray_panel_visible(false)
	_release_tray_focus()
	if _log_toggle_btn != null and _log_toggle_btn.button_pressed:
		_set_log_open(false)
	_trade_counter_mode = false
	if session != null and session.state != null:
		var st2 := session.state
		_trade_reopen_token = _ot_dismiss_key(st2.open_trade, _view_pid())

func _set_tray_panel_visible(v: bool) -> void:
	if _trade_tray == null or _trade_tray.visible == v:
		return
	_trade_tray.visible = v
	if v and _log_popup != null and _log_popup.visible:
		_set_log_open(false)
	_refresh_trade_idle_hint()

func _refresh_trade_idle_hint() -> void:
	if _trade_slot == null or _trade_idle_lbl == null or _trade_tray == null:
		return
	var show_hint := false
	if not _trade_tray.visible and session != null and session.state != null:
		var st := session.state
		if (
			st.phase == GameTypes.TurnPhase.TURN_MAIN
			and int(st.current_player) == _view_pid()
			and not _hand_hidden()
		):
			show_hint = true
	_trade_idle_lbl.text = "Click one of your cards to trade" if show_hint else ""
	_trade_idle_lbl.visible = show_hint

func _set_log_open(on: bool) -> void:
	_log_toggle_btn.set_pressed_no_signal(on)
	_log_toggle_btn.icon = _chevron_icon(on)
	_log_toggle_btn.tooltip_text = "Hide the log" if on else "Show the full log"
	if on:
		_open_log_popup()
	else:
		_close_log_popup()

func _build_log_popup() -> void:
	_log_popup = PanelContainer.new()
	_log_popup.visible = false
	_log_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(10)
	st.set_border_width_all(1)
	st.border_color = Palette.PANEL_LINE
	st.shadow_color = Palette.PAPER_SHADOW
	st.shadow_size = 6
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	_log_popup.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_log_popup.add_child(col)
	var close_row := HBoxContainer.new()
	var cl := Label.new()
	cl.text = "EVENT LOG"
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.add_theme_font_size_override("font_size", 14)
	cl.add_theme_color_override("font_color", Palette.HEADING)
	close_row.add_child(cl)
	var close_btn := Button.new()
	close_btn.text = "Close"
	_style_button(close_btn, "ghost")
	close_btn.pressed.connect(_set_log_open.bind(false))
	_guard_action_button_focus(close_btn)
	close_row.add_child(close_btn)
	col.add_child(close_row)
	_log_popup_text = RichTextLabel.new()
	_log_popup_text.bbcode_enabled = true
	_log_popup_text.scroll_following = true
	_log_popup_text.selection_enabled = true
	_log_popup_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_popup_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_style_rich_label(_log_popup_text)
	col.add_child(_log_popup_text)
	add_child(_log_popup)

func _open_log_popup() -> void:
	if _log_popup == null or _event_log == null:
		return
	_log_popup_text.text = ""
	_rebuild_log_label(_log_popup_text)
	_log_popup.visible = true
	_layout_log_popup()
	_log_popup.move_to_front()

func _close_log_popup() -> void:
	if _log_popup != null:
		_log_popup.visible = false

func _layout_log_popup() -> void:
	if _log_popup == null or not _log_popup.visible:
		return
	if _right_panel == null or _right_panel.size.x < 10.0:
		return
	var r := _right_panel.get_global_rect().grow(-6.0)
	_log_popup.position = r.position
	_log_popup.size = r.size

func _on_window_resized() -> void:
	_apply_trade_chip_sizes()
	_layout_needs_apply = true
	_apply_window_layout()

func _top_bar_margin(width: float) -> float:
	return clampf(width * 0.0375, 24.0, 96.0)

func _on_sea_band_draw() -> void:
	if _board_view == null or not is_instance_valid(_board_view) or _sea_band == null:
		return
	_board_view.paint_sea_band(_sea_band)

func _refresh_sea_band() -> void:
	if _sea_band != null and is_instance_valid(_sea_band):
		_sea_band.queue_redraw()

func _layout_top_bar() -> void:
	if _header_panel == null or _header_pill == null:
		return
	var w := _header_panel.size.x
	if w <= 0.0:
		return
	var m := _top_bar_margin(w)
	_header_pill.position = Vector2(m, 6.0)
	_header_pill.size = Vector2(maxf(w - 2.0 * m, 80.0), 40.0)

func _apply_window_layout() -> void:
	if _right_panel == null:
		return
	var base := get_viewport().get_visible_rect().size
	if base.x < 100.0:
		return
	var sidebar_w: float = clampf(base.x * 0.35, 520.0, 680.0)
	_right_panel.custom_minimum_size = Vector2(sidebar_w, 0)
	_refresh_sea_band()
	var content_h: float = _right_panel.size.y - 20.0
	if content_h < 320.0:
		return
	var sb_h: float = 34.0 * 4.0 + 3.0 * 4.0
	var others := 0.0
	if _sidebar_box != null and is_instance_valid(_sidebar_box):
		for c in _sidebar_box.get_children():
			if not (c is Control):
				continue
			var cc := c as Control
			if cc == _trade_slot or cc == _log_panel:
				continue
			others += cc.get_combined_minimum_size().y
		others += 1.0 * maxf(0.0, float(_sidebar_box.get_child_count()) - 1.0)
	var line_h := 24.0
	if _event_log != null and is_instance_valid(_event_log) and _right_panel != null:
		var meas := RichTextLabel.new()
		meas.bbcode_enabled = true
		_style_rich_label(meas)
		_right_panel.add_child(meas)
		meas.size = Vector2(400, 400)
		meas.append_text("one\ntwo\nthree\nfour")
		var meas_h: float = meas.get_content_height()
		if meas_h > 8.0:
			line_h = meas_h / 4.0
		_right_panel.remove_child(meas)
		meas.free()
	var pad := 14.0
	var lcs := _log_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if lcs != null:
		pad = lcs.content_margin_top + lcs.content_margin_bottom + 2.0
	var avail: float = content_h - others
	var log_target := 4.0 * line_h + pad
	# One trade slot height per window size (never content-driven), so the
	# EVENT LOG below it never moves while the trade panel changes states.
	# 192 px is the tallest trade view (the offer editor), so the log gives
	# ground first (floor 57 px, it scrolls internally) and the two always
	# sum to `avail`, which keeps the sidebar itself scroll-free.
	var log_h: float = clampf(avail - 192.0, 57.0, log_target)
	var trade_h: float = avail - log_h
	_sync_toast_host_rect()
	if _scoreboard_box != null:
		_scoreboard_box.custom_minimum_size = Vector2(0, sb_h)
	if _trade_slot != null:
		_trade_slot.custom_minimum_size = Vector2(0, trade_h)
	if _log_panel != null:
		_log_panel.custom_minimum_size = Vector2(0, log_h)
	_layout_hand_overlay()
	_layout_log_popup()
	_update_scoreboard_focus_overlay()

func _layout_trade_slot() -> void:
	if _trade_slot == null or _trade_tray == null or _trade_frame == null:
		return
	# p34r/p39: the frame paints the card (fill, 1 px line, radius 8, drop
	# shadow) inset 9 px (= shadow size 7 + offset 2) from the slot's bottom.
	# The slot no longer clips (p39), so the top/left shadow fades softly
	# instead of being cut into a wedge; the positions keep the p34 pixels.
	# The tray keeps its 478 px width and moves 3 px up; at slot_height-15 it
	# still clears the 176 px worst-case (5+5) editor and ends 2 px above the
	# frame's bottom line.
	_trade_frame.position = Vector2(-8.0, -5.0)
	_trade_frame.size = _trade_slot.size - Vector2(0.0, 9.0)
	_trade_tray.position = Vector2(8.0, -2.0)
	_trade_tray.size = _trade_slot.size - Vector2(18.0, 15.0)
	# p50c: the measured width of the bank slot follows the new metrics.
	_sync_compose_slot_widths()

func _layout_hand_overlay() -> void:
	if _hand_overlay == null or _hand_bar_panel == null:
		return
	var br := _hand_bar_panel.get_global_rect()
	if br.size.y < 10.0:
		return
	_layout_subpanel()

func _build_offer_strip(root_vbox: VBoxContainer) -> void:
	_offer_strip = PanelContainer.new()
	var st := _paper_panel_style(true)
	st.set_corner_radius_all(0)
	st.set_border_width_all(1)
	st.border_color = Palette.PANEL_LINE
	st.shadow_size = 0
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	_offer_strip.add_theme_stylebox_override("panel", st)
	_offer_strip.custom_minimum_size = Vector2(0, 30)
	root_vbox.add_child(_offer_strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_offer_strip.add_child(row)
	_offer_strip_row = row
	_offer_strip_label = Label.new()
	_offer_strip_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_offer_strip_label.add_theme_constant_override("line_spacing", -18)
	_offer_strip_label.add_theme_font_size_override("font_size", 13)
	_offer_strip_label.add_theme_color_override("font_color", Palette.HEADING)
	row.add_child(_offer_strip_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_offer_strip_spacer = spacer
	_offer_strip_chips = HBoxContainer.new()
	_offer_strip_chips.add_theme_constant_override("separation", 6)
	row.add_child(_offer_strip_chips)
	_offer_strip_respond_btn = Button.new()
	_offer_strip_respond_btn.text = "Respond"
	_offer_strip_respond_btn.custom_minimum_size = Vector2(0, 24)
	_offer_strip_respond_btn.add_theme_font_size_override("font_size", 12)
	_offer_strip_respond_btn.tooltip_text = "Open the trade panel to answer this offer"
	_style_button(_offer_strip_respond_btn, "primary")
	_flatten_trade_button(_offer_strip_respond_btn)
	_offer_strip_respond_btn.visible = false
	_offer_strip_respond_btn.pressed.connect(func() -> void:
		_trade_reopen_token = ""
		_set_trade_hint(false)
		_set_tray_panel_visible(true)
		_refresh_ui()
	)
	_guard_action_button_focus(_offer_strip_respond_btn)
	row.add_child(_offer_strip_respond_btn)
	# The board-selection cancel button lives at the right end of the strip so
	# it never covers the hand cards.
	if _cancel_pick_btn != null:
		_cancel_pick_btn.custom_minimum_size = Vector2(0, 22)
		_cancel_pick_btn.add_theme_font_size_override("font_size", 12)
		row.add_child(_cancel_pick_btn)

func _refresh_offer_strip(state: GameState) -> void:
	if _offer_strip == null:
		return
	var ot: Dictionary = state.open_trade
	var ot_open := not ot.is_empty()
	_offer_strip_label.visible = ot_open
	_offer_strip_chips.visible = ot_open
	_offer_strip_respond_btn.visible = false
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
	if _offer_strip_respond_btn != null:
		_offer_strip_respond_btn.visible = _ot_awaits_view() and not _hand_hidden()
	var responses: Dictionary = ot.get("responses", {})
	var revs: Dictionary = ot.get("revisions", {})
	_sync_rev_badge_token(_ot_token(ot))
	var skey_parts: Array[String] = [str(state.turn_number), _ot_token(ot), str(_declined_counters)]
	for p_id in range(state.players.size()):
		if p_id == from_p:
			continue
		skey_parts.append("%d%s!%d" % [
			p_id,
			str((responses.get(p_id, {}) as Dictionary).get("status", "")),
			int(revs.get(p_id, 0)),
		])
	var skey := "|".join(skey_parts)
	if skey == _strip_rebuild_key:
		return
	_strip_rebuild_key = skey
	for c in _offer_strip_chips.get_children():
		c.queue_free()
	for p_id in range(state.players.size()):
		if p_id == from_p:
			continue
		var pname := str(state.players[p_id].get("name", GameTypes.PLAYER_NAMES[p_id]))
		if not responses.has(p_id):
			_offer_strip_chips.add_child(_make_pill("%s: waiting…" % pname, Palette.PAPER_DARK, Palette.TEXT_MUTED))
			continue
		var resp: Dictionary = responses[p_id]
		var chip_text := ""
		var chip_col: Color = Palette.TEXT_MUTED
		match str(resp.get("status", "")):
			"accept":
				chip_text = "%s: ✓ accepts" % pname
				chip_col = Palette.STATUS_GOOD_TEXT
			"decline":
				chip_text = "%s: ✗ declines" % pname
				chip_col = Palette.STATUS_BAD_TEXT
			"counter":
				if _declined_counters.has(p_id):
					chip_text = "%s: ✗ counter declined" % pname
					chip_col = Palette.STATUS_BAD_TEXT
				else:
					chip_text = "%s %s" % [pname, _counter_phrase(resp)]
					chip_col = Palette.HEADING
			_:
				continue
		var pill := _make_pill(chip_text, Palette.PAPER_DARK, chip_col)
		if int(revs.get(p_id, 0)) > 0:
			_pill_attach_badge(pill, p_id, GameTypes.PLAYER_COLORS[p_id])
		_offer_strip_chips.add_child(pill)

func _refresh_trade_tray(state: GameState, acting_id: int, human_acting: bool) -> void:
	if _trade_tray == null:
		return
	var ot: Dictionary = state.open_trade
	var ot_open := not ot.is_empty()
	if _trade_last_ot_open and not ot_open:
		var keep_draft := _no_takers_keep_draft
		_no_takers_keep_draft = false
		_watch_rows_key = ""
		if not keep_draft:
			_reset_trade_counts()
			_fresh_trade_next_click = false
		_trade_reopen_token = ""
		_revise_reopened_token = ""
		_set_trade_hint(false)
		var was_my_offer := _trade_last_ot_from == _view_pid()
		var was_responder := _trade_respond_mode or _trade_was_answerer
		if (not keep_draft) and (_trade_opened_auto or was_my_offer or was_responder) and _trade_tray.visible and not _ot_result_active:
			_set_tray_panel_visible(false)
			_release_tray_focus()
		_trade_opened_auto = false
		_trade_was_answerer = false
		_trade_last_ot_from = -1
	_trade_last_ot_open = ot_open
	if ot_open and _own_offer_dead(state):
		var dead_token := _ot_token(ot)
		if _no_takers_token != dead_token:
			_no_takers_token = dead_token
			_no_takers_since_ms = Time.get_ticks_msec()
	elif _no_takers_since_ms != 0:
		_no_takers_since_ms = 0
		_no_takers_token = ""
	var from_p := int(ot.get("from", -1))
	var my_pid := _view_pid()
	var from_me_show := ot_open and from_p == my_pid
	# p47: a single human may answer an AI's offer out of turn, before the
	# paced AI answer wave reaches them. `answer_pid` is the seat the answer
	# buttons submit for; `watch` stays false so the tray shows answer mode.
	var early_pid := _early_answer_pid()
	var respond := (ot_open and human_acting and from_p != acting_id) or early_pid >= 0
	var answer_pid := early_pid if early_pid >= 0 else acting_id

	# The tray is the viewed human's workspace. When they are neither the
	# proposer nor the acting responder they watch the negotiation read-only:
	# a new offer opens the panel once (a dismissal sticks for that offer).
	var watch := ot_open and from_p != my_pid and acting_id != my_pid and early_pid < 0
	if ot_open and watch and not _trade_tray.visible and not _hand_hidden():
		if _trade_reopen_token != _ot_dismiss_key(ot, my_pid):
			_set_tray_panel_visible(true)
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
	if ot_open and (human_acting or early_pid >= 0):
		if from_me:
			_trade_reopen_token = ""
			_set_trade_hint(false)
			_set_tray_panel_visible(true)
		elif (respond and answer_pid == my_pid and (ot.get("responses", {}) as Dictionary).is_empty()) or _trade_reopen_token != _ot_dismiss_key(ot, my_pid):
			var was_tray_open := _trade_tray.visible
			if respond and answer_pid == my_pid and (ot.get("responses", {}) as Dictionary).is_empty():
				_trade_reopen_token = ""
			_set_tray_panel_visible(true)
			if respond and not was_tray_open:
				_trade_opened_auto = true
	if respond and not _trade_tray.visible and answer_pid == my_pid:
		_set_trade_hint(true)

	_trade_revise_pid = _trade_revise_pid_calc()
	if respond or _trade_revise_pid >= 0:
		_trade_was_answerer = true
	var revise := _trade_revise_pid >= 0 and not from_me_show and not respond
	var revise_left := 0
	if revise:
		revise_left = RulesEngine.MAX_TRADE_RESPONSE_REVISIONS - int(ot.get("revisions", {}).get(_trade_revise_pid, 0))
		var tok_rev := _ot_token(ot)
		if not _trade_tray.visible and not _hand_hidden() and _revise_reopened_token != tok_rev:
			_revise_reopened_token = tok_rev
			_set_tray_panel_visible(true)
	var counter := (respond or revise) and _trade_counter_mode
	var propose_idle := (not respond) and (not from_me_show) and (not watch)
	var editing_own_offer := from_me and (not counter)

	var title := "Trade"
	if respond or watch:
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
	if _trade_close_btn != null:
		if respond and answer_pid == my_pid:
			_trade_close_btn.tooltip_text = "Decline and close (Esc)"
		elif from_me_show:
			_trade_close_btn.tooltip_text = "Close (Esc) \u2014 withdraws your offer"
		else:
			_trade_close_btn.tooltip_text = "Close (Esc)"

	_trade_respond_view.visible = (respond or revise) and (not counter)
	if (respond or revise) and (not counter):
		var band_pid: int = answer_pid if respond else _trade_revise_pid
		_fill_ro_row(_trade_ro_get_box, ot.get("offer", {}), {})
		_fill_ro_row(_trade_ro_give_box, ot.get("request", {}), _missing_for_bundle(state, ot.get("request", {})))
		var have_parts: Array[String] = []
		var hand: Dictionary = state.players[band_pid].get("hand", {})
		for r in GameTypes.ALL_RESOURCES:
			var want_amt: int = int(ot.get("request", {}).get(r, 0))
			if want_amt > 0:
				have_parts.append("%d %s" % [int(hand.get(r, 0)), GameTypes.resource_name(r)])
		if respond:
			_trade_have_label.text = "You have: %s" % " + ".join(have_parts)
		else:
			var my_ans := str(((ot.get("responses", {}) as Dictionary).get(_trade_revise_pid, {}) as Dictionary).get("status", ""))
			var ans_word := "accepted" if my_ans == "accept" else ("declined" if my_ans == "decline" else "countered")
			_trade_have_label.text = "You %s — changes left: %d of %d." % [
				ans_word, revise_left, RulesEngine.MAX_TRADE_RESPONSE_REVISIONS
			]

	var own_has_answer := false
	if ot_open and from_me:
		own_has_answer = not (ot.get("responses", {}) as Dictionary).is_empty()
	_trade_rows_col.visible = (
		propose_idle or counter or (editing_own_offer and not own_has_answer)
	)
	_trade_partner_stack.visible = (not respond) and (not counter) and (not watch)

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
	_rebuild_trade_chip_rows(unlocked and (state.phase == GameTypes.TurnPhase.TURN_MAIN or counter))

	var give_total := _trade_side_total(_trade_give_counts)
	var get_total := _trade_side_total(_trade_get_counts)

	_trade_btn_row.visible = propose_idle or editing_own_offer
	_trade_ask_btn.visible = propose_idle
	_trade_counter_row.visible = counter
	_ot_send_btn.visible = counter
	_ot_back_btn.visible = counter
	var offer_cap_hit := state.open_trades_this_turn >= RulesEngine.MAX_OPEN_TRADES_PER_TURN
	var sides_differ := _trade_side_key(true) != _trade_side_key(false)
	_trade_ask_btn.disabled = not (propose_ok and give_total > 0 and get_total > 0 and sides_differ) or (propose_ok and offer_cap_hit)
	if propose_ok and offer_cap_hit:
		_trade_ask_btn.tooltip_text = "No player offers left this turn (3 of 3). Bank and port trades still work."
	else:
		_trade_ask_btn.tooltip_text = "Post this offer to every other player"
	_trade_ratio_btn.visible = propose_idle and unlocked and not _bank_selection_check(state, my_pid).is_empty()
	if _trade_ratio_btn.visible:
		var plan_ratios: Array[int] = []
		for r in GameTypes.ALL_RESOURCES:
			if int(_trade_give_counts.get(r, 0)) > 0:
				var rv := state.get_trade_ratio(my_pid, r)
				if not plan_ratios.has(rv):
					plan_ratios.append(rv)
		if plan_ratios.size() == 1:
			_trade_ratio_btn.text = "Port 2:1" if plan_ratios[0] == 2 else ("Port 3:1" if plan_ratios[0] == 3 else "Bank 4:1")
		else:
			_trade_ratio_btn.text = "Bank / Port"
	# p50c: the slot holds its measured width only while a plain offer is drafted.
	_set_bank_slot_reserve(propose_idle and not offer_cap_hit)
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
			_trade_resend_btn.tooltip_text = "No player offers left this turn (3 of 3). Bank and port trades still work."
		else:
			_trade_resend_btn.tooltip_text = "Cancel this offer and post the new one"
	_trade_offers_lbl.visible = propose_idle or editing_own_offer
	if _trade_offers_lbl.visible:
		# p50c: the row has room for one short token, so the running count shows as
		# "Offers 0/3" and the full sentence drops to the tooltip; the cap keeps the
		# whole sentence as its warning and (as before) no tooltip.
		if offer_cap_hit:
			_trade_offers_lbl.text = "No player offers left this turn (3 of 3). Bank and port trades still work."
			_trade_offers_lbl.tooltip_text = ""
		else:
			_trade_offers_lbl.text = "Offers %d/%d" % [
				state.open_trades_this_turn, RulesEngine.MAX_OPEN_TRADES_PER_TURN
			]
			_trade_offers_lbl.tooltip_text = "Offers this turn: %d of %d" % [
				state.open_trades_this_turn, RulesEngine.MAX_OPEN_TRADES_PER_TURN
			]
	_trade_clear_btn.disabled = (give_total == 0 and get_total == 0) or not (propose_idle or counter)
	_ot_send_btn.visible = counter
	_ot_back_btn.visible = counter
	_ot_send_btn.disabled = not (give_total > 0 and get_total > 0)
	if (respond or revise) and not counter:
		var gate_pid: int = answer_pid if respond else _trade_revise_pid
		var limit_hit: bool = revise and revise_left <= 0
		if limit_hit:
			for b in [_ot_accept_btn, _ot_decline_btn, _ot_counter_btn]:
				(b as Button).disabled = true
				(b as Button).tooltip_text = "You have used all %d changes for this offer." % RulesEngine.MAX_TRADE_RESPONSE_REVISIONS
		else:
			var need_hand: Dictionary = state.players[gate_pid].get("hand", {})
			var missing := _missing_resources(need_hand, ot.get("request", {}))
			_ot_accept_btn.disabled = not missing.is_empty()
			if not missing.is_empty():
				_ot_accept_btn.tooltip_text = missing
			else:
				_ot_accept_btn.tooltip_text = "Accept this offer"
			_ot_decline_btn.disabled = false
			_ot_decline_btn.tooltip_text = "Decline this offer"
			_ot_counter_btn.disabled = false
			_ot_counter_btn.tooltip_text = "Propose different terms"
		var sel_status := ""
		if revise:
			sel_status = str(
				((ot.get("responses", {}) as Dictionary).get(_trade_revise_pid, {}) as Dictionary).get("status", "")
			)
		_apply_answer_selection(sel_status)

	var showing_result := ot.is_empty() and _ot_result_active
	var own_view := ot_open and from_me_show and (not counter)
	var result_band := showing_result and not _ot_result_give.is_empty()
	# Size the rail before the rows are rebuilt so a wide counter row is
	# measured against the width it will actually get.
	_trade_right_col.visible = bool(_trade_partner_stack.visible) or bool(_watch_rows_col.visible)
	_apply_trade_rail_width()
	_trade_watch_col.visible = (
		((watch or respond or revise) and (not counter)) or showing_result or own_view
	)
	_band_gate["wa"] = bool((watch and not revise) or own_view or result_band)
	_band_gate["ro"] = true
	_watch_rows_col.visible = ((watch or respond or revise) and (not counter)) or showing_result
	if showing_result:
		_trade_title_lbl.text = _ot_result_header
		_rebuild_result_rows()
		_trade_rows_col.visible = false
		_trade_partner_stack.visible = false
		_trade_offers_lbl.visible = false
		_trade_ask_btn.visible = false
		_trade_clear_btn.visible = false
		if result_band:
			_set_band_captions("wa", "gave", "got")
			_fill_ro_row(_watch_terms_get_box, _ot_result_give, {})
			_fill_ro_row(_watch_terms_give_box, _ot_result_get, {})
	else:
		if watch or own_view:
			_set_band_captions("wa", "You give" if own_view else "offers", "You get" if own_view else "wants")
			_fill_ro_row(_watch_terms_get_box, ot.get("offer", {}), {})
			_fill_ro_row(_watch_terms_give_box, ot.get("request", {}), {})
		_rebuild_watch_rows(state, ot, respond and (not counter))
		_trade_clear_btn.visible = true

	_rebuild_partner_cards(state, ot, ot_open, from_me, not ot_open)
	_trade_right_col.visible = bool(_trade_partner_stack.visible) or bool(_watch_rows_col.visible)
	_apply_trade_chip_sizes()
	_trade_chip_size_dirty = true
	call_deferred("_retune_trade_chip_sizes")
	if _hand_hidden() and _trade_tray.visible:
		_set_tray_panel_visible(false)
	_refresh_trade_idle_hint()
	_apply_trade_rail_width()

func _rebuild_partner_cards(state: GameState, ot: Dictionary, ot_open: bool, human_can_pick: bool, _show_bank: bool) -> void:
	if _trade_partner_stack == null:
		return
	var key_parts: Array[String] = [
		str(state.turn_number), _ot_token(ot), str(ot_open), str(human_can_pick), str(_trade_hand()), str(_declined_counters),
	]
	var pticks: Dictionary = ot.get("resp_ticks", {})
	var prv: Dictionary = ot.get("revisions", {})
	_sync_rev_badge_token(_ot_token(ot))
	for p in range(state.players.size()):
		var resp: Dictionary = (ot.get("responses", {}) as Dictionary).get(p, {})
		key_parts.append("%d:%s#%d!%d" % [p, str(resp.get("status", "")), int(pticks.get(p, 0)), int(prv.get(p, 0))])
	var key2 := "|".join(key_parts)
	if key2 == _partner_rebuild_key:
		_partner_rebuild_deferred = false
		return
	# p46: a partner response landing between press and release used to free
	# the counter card under the held pointer (queue_free below), so the click
	# was swallowed and the decline needed a second try. A button in the stack
	# holding a live press keeps the old cards up; _process flushes the
	# rebuild once the pointer is released.
	if _partner_stack_press_held():
		_partner_rebuild_deferred = true
		return
	_partner_rebuild_deferred = false
	_partner_rebuild_key = key2
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
						status_color = Palette.STATUS_GOOD_TEXT
						can_trade = true
					elif st_str == "decline":
						status = "\u2717 Declines"
						status_color = Palette.STATUS_BAD_TEXT
						takers_declined += 1
					elif st_str == "counter":
						counter_resp = resp
						any_counter = true
						if bool(_declined_counters.get(p_id, false)):
							takers_declined += 1
		var pname := str(p_data.get("name", GameTypes.PLAYER_NAMES[p_id]))
		var pcol: Color = GameTypes.PLAYER_COLORS[p_id]
		var pr_rev := int(prv.get(p_id, 0))
		var badge_pid := p_id if (pr_rev > 0 and ot_open) else -1
		if not counter_resp.is_empty():
			if int(ot.get("from", -1)) == _view_pid() and not _counter_toasted.has(p_id):
				_counter_toasted[p_id] = true
				_show_toast("%s %s" % [pname, _counter_phrase(counter_resp)], Palette.TOAST_COUNTER_BG)
			var ccard := _make_counter_partner_card(
				pname, pcol, p_id, counter_resp, state, bool(_declined_counters.get(p_id, false)), badge_pid
			)
			var cwrap := _wrap_row_bg(ccard)
			_trade_partner_stack.add_child(cwrap)
			if badge_pid >= 0:
				_maybe_pulse_rev(cwrap, p_id, pcol)
			continue
		var parts := _make_partner_panel(pname, pcol, Palette.PANEL_BORDER, badge_pid, pcol)
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
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if can_trade:
			var partner := p_id
			t_btn.pressed.connect(func() -> void: _submit_human_action(GameAction.finalize_open_trade(partner)))
		(parts[1] as VBoxContainer).add_child(t_btn)
		(parts[0] as Control).tooltip_text = "%s \u2014 %s" % [pname, status]
		var swrap := _wrap_row_bg(parts[0] as Control)
		_trade_partner_stack.add_child(swrap)
		if badge_pid >= 0:
			_maybe_pulse_rev(swrap, p_id, pcol)
	var no_takers := (
		ot_open and int(ot.get("from", -1)) == _view_pid()
		and takers_checked > 0 and takers_declined == takers_checked
	)
	if _trade_no_takers_lbl != null:
		_trade_no_takers_lbl.visible = no_takers
	_counter_cards_shown = any_counter

func _counter_phrase(resp: Dictionary) -> String:
	# one wording everywhere, from the countering player's point of view
	return "counters: gives %s, wants %s" % [
		_format_resource_bundle(resp.get("request", {})),
		_format_resource_bundle(resp.get("offer", {})),
	]

func _partner_stack_press_held() -> bool:
	if _trade_partner_stack == null or not is_instance_valid(_trade_partner_stack):
		return false
	return _node_subtree_press_held(_trade_partner_stack)

func _flush_partner_rebuild() -> void:
	if not _partner_rebuild_deferred:
		return
	if session == null or session.state == null or session.state.open_trade.is_empty():
		_partner_rebuild_deferred = false
		return
	if _trade_partner_stack == null or not is_instance_valid(_trade_partner_stack) or not _trade_partner_stack.visible:
		_partner_rebuild_deferred = false
		return
	if _partner_stack_press_held():
		return
	_refresh_trade_tray(session.state, session.get_acting_player_id(), _is_human_acting())

func _node_subtree_press_held(node: Node) -> bool:
	for child in node.get_children():
		if child is BaseButton and (child as BaseButton).is_pressed():
			return true
		if _node_subtree_press_held(child):
			return true
	return false

func _ot_begin_trade_result(ev: String) -> void:
	_ot_snap_token = ""
	var pace := _trade_pace_ms()
	if pace <= 0.0 or _ot_snap.is_empty():
		return
	var snap: Dictionary = _ot_snap
	var from_p := int(snap.get("from", -1))
	var responses: Dictionary = snap.get("responses", {})
	var rows: Array = []
	var made := -1
	for p_id in range(session.state.players.size()):
		if p_id == from_p:
			continue
		var resp: Dictionary = responses.get(p_id, {})
		var status := str(resp.get("status", "waiting")) if not resp.is_empty() else "waiting"
		if status == "accept":
			made = p_id
			if ev.contains(str(session.state.players[p_id].get("name", GameTypes.PLAYER_NAMES[p_id]))):
				made = p_id
		rows.append({"pid": p_id, "status": status, "resp": resp})
	_ot_result_rows = rows
	_ot_result_made_pid = made
	var from_name := "?"
	if from_p >= 0 and from_p < session.state.players.size():
		from_name = str(session.state.players[from_p].get("name", GameTypes.PLAYER_NAMES[from_p]))
	var partner_name := "?"
	if made >= 0 and made < session.state.players.size():
		partner_name = str(session.state.players[made].get("name", GameTypes.PLAYER_NAMES[made]))
	_ot_result_header = "%s traded with %s: %s for %s" % [
		from_name, partner_name,
		_format_resource_bundle(snap.get("offer", {})),
		_format_resource_bundle(snap.get("request", {})),
	]
	_ot_result_give = (snap.get("offer", {}) as Dictionary).duplicate(true)
	_ot_result_get = (snap.get("request", {}) as Dictionary).duplicate(true)
	_ot_result_active = true
	_ot_result_until_ms = Time.get_ticks_msec() + 1500
	_set_tray_panel_visible(true)
	_refresh_ui()

func _ot_begin_no_deal_result() -> void:
	_ot_snap_token = ""
	var pace := _trade_pace_ms()
	if pace <= 0.0 or _ot_snap.is_empty():
		return
	var snap: Dictionary = _ot_snap
	var from_p := int(snap.get("from", -1))
	var responses: Dictionary = snap.get("responses", {})
	var rows: Array = []
	for p_id in range(session.state.players.size()):
		if p_id == from_p:
			continue
		var resp: Dictionary = responses.get(p_id, {})
		var status := str(resp.get("status", "waiting")) if not resp.is_empty() else "waiting"
		rows.append({"pid": p_id, "status": status, "resp": resp})
	_ot_result_rows = rows
	_ot_result_made_pid = -1
	_ot_result_give = {}
	_ot_result_get = {}
	_ot_result_header = "No deal"
	_ot_result_active = true
	_ot_result_until_ms = Time.get_ticks_msec() + 1000
	_set_tray_panel_visible(true)
	_refresh_ui()

func _rebuild_result_rows() -> void:
	if _watch_rows_col == null:
		return
	var key := "res|" + _ot_result_header + "|" + str(_ot_result_rows.size())
	if key == _watch_rows_key:
		return
	_watch_rows_key = key
	for c in _watch_rows_col.get_children():
		c.queue_free()
	for row_data in _ot_result_rows:
		var pid := int(row_data.get("pid", -1))
		var status := str(row_data.get("status", "waiting"))
		var pname := str(session.state.players[pid].get("name", GameTypes.PLAYER_NAMES[pid]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var sw := _make_seat_swatch(Vector2(10, 10))
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_set_seat_swatch_color(sw, GameTypes.PLAYER_COLORS[pid])
		row.add_child(sw)
		var name_lbl := Label.new()
		name_lbl.text = pname
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT)
		name_lbl.custom_minimum_size = Vector2(40, 0)
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match status:
			"accept":
				if pid == _ot_result_made_pid:
					lbl.text = "\u2713 Trade made"
					lbl.add_theme_color_override("font_color", Palette.STATUS_GOLD_STRONG_TEXT)
				else:
					lbl.text = "\u2713 Accepted"
					lbl.add_theme_color_override("font_color", Palette.STATUS_GOOD_TEXT)
			"decline":
				lbl.text = "Declined"
				lbl.add_theme_color_override("font_color", Palette.STATUS_BAD_TEXT)
			"counter":
				lbl.text = _counter_phrase(row_data.get("resp", {}))
				lbl.add_theme_color_override("font_color", Palette.STATUS_WARN_TEXT)
			_:
				lbl.text = "Waiting\u2026"
				lbl.add_theme_color_override("font_color", Palette.TEXT)
		row.add_child(lbl)
		_watch_rows_col.add_child(row)

func _rebuild_watch_rows(state: GameState, ot: Dictionary, for_respond: bool) -> void:
	if _watch_rows_col == null:
		return
	var from_p := int(ot.get("from", -1))
	var responses: Dictionary = ot.get("responses", {})
	var ticks: Dictionary = ot.get("resp_ticks", {})
	var revisions: Dictionary = ot.get("revisions", {})
	_sync_rev_badge_token(_ot_token(ot))
	var parts: Array[String] = [str(state.turn_number), _ot_token(ot), str(for_respond)]
	for p_id in range(state.players.size()):
		parts.append("%d%s#%d!%d" % [
			p_id,
			str((responses.get(p_id, {}) as Dictionary).get("status", "")),
			int(ticks.get(p_id, 0)),
			int(revisions.get(p_id, 0)),
		])
	var key := "|".join(parts)
	if key == _watch_rows_key:
		return
	_watch_rows_key = key
	for c in _watch_rows_col.get_children():
		c.queue_free()
	var my_pid := _view_pid()
	var new_status: Dictionary = {}
	var new_ticks: Dictionary = {}
	var rows_by_pid: Dictionary = {}
	for p_id in range(state.players.size()):
		if p_id == from_p:
			continue
		if for_respond and p_id == my_pid:
			continue
		var p_data: Dictionary = state.players[p_id]
		var pname := str(p_data.get("name", GameTypes.PLAYER_NAMES[p_id]))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var sw := _make_seat_swatch(Vector2(10, 10))
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_set_seat_swatch_color(sw, GameTypes.PLAYER_COLORS[p_id])
		row.add_child(sw)
		var name_lbl := Label.new()
		name_lbl.text = pname
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Palette.TEXT)
		name_lbl.custom_minimum_size = Vector2(48, 0)
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)
		# Reserved badge slot after the name: constant width on every row (empty
		# when no badge) so rows never shift, and a >=3 px gap from the longest
		# seat name (the 48 px name column clears "Crimson" with room to spare).
		var rev_slot := Control.new()
		rev_slot.custom_minimum_size = Vector2(_REV_BADGE_SLOT_W, 13)
		rev_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rev_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var rev_cnt := int(revisions.get(p_id, 0))
		if rev_cnt > 0:
			var wb := _make_rev_badge_for(p_id, GameTypes.PLAYER_COLORS[p_id], true)
			wb.fixed_x = 0.0
			rev_slot.add_child(wb)
		row.add_child(rev_slot)
		if not responses.has(p_id):
			var wait_lbl := Label.new()
			wait_lbl.text = "Waiting\u2026"
			wait_lbl.add_theme_font_size_override("font_size", 11)
			wait_lbl.add_theme_color_override("font_color", Palette.TEXT)
			wait_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wait_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(wait_lbl)
			new_status[p_id] = ""
		else:
			var resp: Dictionary = responses[p_id]
			match str(resp.get("status", "")):
				"accept":
					var acc_lbl := Label.new()
					acc_lbl.text = "\u2713 Accepted"
					acc_lbl.add_theme_font_size_override("font_size", 11)
					acc_lbl.add_theme_color_override("font_color", Palette.STATUS_GOOD_TEXT)
					acc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					acc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					row.add_child(acc_lbl)
				"decline":
					var dec_lbl := Label.new()
					dec_lbl.text = "Declined"
					dec_lbl.add_theme_font_size_override("font_size", 11)
					dec_lbl.add_theme_color_override("font_color", Palette.STATUS_BAD_TEXT)
					dec_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					dec_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					row.add_child(dec_lbl)
				"counter":
					var give_b: Dictionary = resp.get("request", {})
					var want_b: Dictionary = resp.get("offer", {})
					var c_kinds := 0
					for r in GameTypes.ALL_RESOURCES:
						if int(give_b.get(r, 0)) > 0:
							c_kinds += 1
						if int(want_b.get(r, 0)) > 0:
							c_kinds += 1
					if c_kinds > 4:
						var cpre := Label.new()
						cpre.text = "Counter:"
						cpre.add_theme_font_size_override("font_size", 11)
						cpre.add_theme_color_override("font_color", Palette.STATUS_GOLD_STRONG_TEXT)
						cpre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
						cpre.mouse_filter = Control.MOUSE_FILTER_IGNORE
						row.add_child(cpre)
						var phrase := _counter_phrase(resp)
						var ctxt := Label.new()
						ctxt.text = phrase.substr(phrase.find(":") + 2)
						ctxt.add_theme_font_size_override("font_size", 10)
						ctxt.add_theme_color_override("font_color", Palette.STATUS_GOLD_SOFT_TEXT)
						ctxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						ctxt.clip_text = true
						ctxt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
						ctxt.mouse_filter = Control.MOUSE_FILTER_IGNORE
						row.add_child(ctxt)
					elif _trade_rail_w >= 300.0:
						_add_bundle_arrow(row, give_b, want_b, true)
					else:
						var brow := HBoxContainer.new()
						brow.add_theme_constant_override("separation", 5)
						_add_bundle_arrow(brow, give_b, want_b, true)
						var bouter := VBoxContainer.new()
						bouter.add_theme_constant_override("separation", 1)
						bouter.add_child(row)
						bouter.add_child(brow)
						var bwrap := _wrap_row_bg(bouter)
						rows_by_pid[p_id] = bwrap
						_watch_rows_col.add_child(bwrap)
						if rev_cnt > 0:
							_maybe_pulse_rev(bwrap, p_id, GameTypes.PLAYER_COLORS[p_id])
						bwrap.tooltip_text = "%s counter-offer: gives %s, wants %s" % [
							pname,
							_format_resource_bundle(give_b),
							_format_resource_bundle(want_b),
						]
						new_status[p_id] = "counter"
						new_ticks[p_id] = int(ticks.get(p_id, 0))
						continue
					var owrap := _wrap_row_bg(row)
					owrap.tooltip_text = "%s counter-offer: gives %s, wants %s" % [
						pname,
						_format_resource_bundle(give_b),
						_format_resource_bundle(want_b),
					]
					rows_by_pid[p_id] = owrap
					_watch_rows_col.add_child(owrap)
					if rev_cnt > 0:
						_maybe_pulse_rev(owrap, p_id, GameTypes.PLAYER_COLORS[p_id])
					new_status[p_id] = "counter"
					new_ticks[p_id] = int(ticks.get(p_id, 0))
					continue
				_:
					var dash_lbl := Label.new()
					dash_lbl.text = "\u2014"
					dash_lbl.add_theme_font_size_override("font_size", 11)
					dash_lbl.add_theme_color_override("font_color", Palette.TEXT)
					dash_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					row.add_child(dash_lbl)
			new_status[p_id] = str(resp.get("status", ""))
			new_ticks[p_id] = int(ticks.get(p_id, 0))
		var rwrap := _wrap_row_bg(row)
		rows_by_pid[p_id] = rwrap
		_watch_rows_col.add_child(rwrap)
		if rev_cnt > 0:
			_maybe_pulse_rev(rwrap, p_id, GameTypes.PLAYER_COLORS[p_id])
	for p_id in new_status.keys():
		var s_now := str(new_status[p_id])
		if s_now == "":
			continue
		var status_changed := str(_watch_row_prev_status.get(p_id, "")) != s_now
		var ticked := int(new_ticks.get(p_id, 0)) > int(_watch_row_prev_ticks.get(p_id, 0))
		if not status_changed and not ticked:
			continue
		var frow: Control = rows_by_pid.get(p_id, null)
		if frow == null or _reduce_motion:
			continue
		frow.modulate = Color(1.35, 1.22, 0.8)
		var ftw := frow.create_tween()
		ftw.tween_property(frow, "modulate", Color.WHITE, 0.6)
	_watch_row_prev_status = new_status
	_watch_row_prev_ticks = new_ticks

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


func _make_seat_swatch(min_size: Vector2) -> Panel:
	var sw := Panel.new()
	sw.custom_minimum_size = min_size
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sw

func _set_seat_swatch_color(sw: Control, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Palette.INK_OUTLINE
	sb.set_border_width_all(1)
	sw.add_theme_stylebox_override("panel", sb)

func _make_partner_panel(pname: String, swatch_color: Color, border: Color, badge_pid: int = -1, badge_col: Color = Color(0, 0, 0, -1)) -> Array:
	var card := PanelContainer.new()
	var cst := _paper_panel_style(true)
	cst.bg_color = Palette.ROW_BG
	cst.set_corner_radius_all(7)
	cst.set_border_width_all(1)
	cst.border_color = border
	cst.shadow_color = Palette.ROW_SHADOW
	cst.shadow_size = 3
	cst.shadow_offset = Vector2(0, 1)
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
	var sw := _make_seat_swatch(Vector2(10, 10))
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_seat_swatch_color(sw, swatch_color)
	row1.add_child(sw)
	var name_lbl := Label.new()
	name_lbl.text = pname
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Palette.TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(name_lbl)
	if badge_pid >= 0 and badge_col.a >= 0.0:
		var b := _make_rev_badge_for(badge_pid, badge_col)
		b.right_inset = 2.0
		name_lbl.add_child(b)
	return [card, col, row1]

func _bold_font() -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["DejaVu Sans", "Inter", "sans-serif"])
	sf.font_weight = 700  # TextServer.FONT_WEIGHT_BOLD
	return sf

func _mini_count_label(cnt: int) -> Label:
	var l := Label.new()
	l.name = "MiniCount"
	l.text = "%d\u00d7" % cnt
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Palette.TEXT)
	l.add_theme_font_override("font", _bold_font())
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _mini_trade_face(res: int, cnt: int, missing: bool) -> CardFace:
	var f := CardFace.new()
	f.kind = "resource"
	f.resource = res
	f.custom_minimum_size = Vector2(30, 42)
	f.show_name = false
	f.vivid = true
	f.focusable = false
	f.focus_mode = Control.FOCUS_NONE
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.disabled = missing
	f.count = cnt
	f.count_badge = false
	f.tooltip_text = "%s \u00d7%d" % [GameTypes.resource_name(res), cnt]
	return f

func _bundle_word_label(word: String) -> Label:
	var w := Label.new()
	w.text = word
	w.add_theme_font_size_override("font_size", 9)
	w.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w

func _add_bundle_arrow(box: HBoxContainer, give_b: Dictionary, want_b: Dictionary, with_words: bool = false) -> void:
	# "2x[Grain] -> 3x[Timber] 1x[Clay]" compact counter display for watch rows.
	if with_words:
		box.add_child(_bundle_word_label("gives"))
	var has_g := false
	for r in GameTypes.ALL_RESOURCES:
		var g_cnt := int(give_b.get(r, 0))
		if g_cnt > 0:
			box.add_child(_mini_count_label(g_cnt))
			box.add_child(_mini_trade_face(r, g_cnt, false))
			has_g = true
	if has_g:
		var ar := Label.new()
		ar.text = "\u2192"
		ar.add_theme_font_size_override("font_size", 12)
		ar.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(ar)
		if with_words:
			box.add_child(_bundle_word_label("wants"))
	for r in GameTypes.ALL_RESOURCES:
		var w_cnt := int(want_b.get(r, 0))
		if w_cnt > 0:
			box.add_child(_mini_count_label(w_cnt))
			box.add_child(_mini_trade_face(r, w_cnt, false))

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
		box.add_child(_mini_count_label(want))
		box.add_child(_mini_trade_face(r, want, missing.has(r)))

func _add_counter_sides(col: VBoxContainer, give_b: Dictionary, want_b: Dictionary, missing: Dictionary) -> void:
	# One "You give 2x[..] -> You get 3x[..] 1x[..]" line, so the counter
	# card is always one line tall and its Accept/Decline row stays visible.
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(line)
	_add_mini_side(line, "You give", give_b, missing)
	var arrow := Label.new()
	arrow.text = "\u2192"
	arrow.add_theme_font_size_override("font_size", 12)
	arrow.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(arrow)
	_add_mini_side(line, "You get", want_b, {})

func _make_counter_partner_card(
	pname: String,
	pcol: Color,
	p_id: int,
	resp: Dictionary,
	state: GameState,
	declined: bool,
	badge_pid: int = -1
) -> PanelContainer:
	var parts := _make_partner_panel(pname, pcol, Palette.ACCENT_GOLD, badge_pid, pcol)
	var card: PanelContainer = parts[0]
	var col: VBoxContainer = parts[1]
	var row1: HBoxContainer = parts[2]
	var cst: StyleBoxFlat = (card.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	cst.set_border_width_all(2)
	cst.border_color = Palette.ACCENT_GOLD
	card.add_theme_stylebox_override("panel", cst)
	# The card header also carries the tag and the two buttons; the name
	# must never wrap into the card body.
	for ch1 in row1.get_children():
		var nl := ch1 as Label
		if nl != null:
			nl.autowrap_mode = TextServer.AUTOWRAP_OFF
			nl.clip_text = true
			nl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			nl.custom_minimum_size = Vector2(40.0, 0.0)
	var tag := Label.new()
	tag.text = "COUNTER-OFFER"
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", Palette.SECTION_TAG_TEXT)
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
		dl.add_theme_color_override("font_color", Palette.STATUS_BAD_TEXT)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(dl)
		return card
	_add_counter_sides(col, resp.get("offer", {}), resp.get("request", {}), missing)
	var cspacer := Control.new()
	cspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cspacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_child(cspacer)
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
	row1.add_child(accept_btn)
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
	row1.add_child(decline_btn)
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
	var units := 0
	var give_total := 0
	for r in GameTypes.ALL_RESOURCES:
		var c := int(_trade_give_counts.get(r, 0))
		if c <= 0:
			continue
		var ratio := state.get_trade_ratio(pid, r)
		if c % ratio != 0:
			return {}
		units += int(c / ratio)
		give_total += c
	if give_total <= 0:
		return {}
	for r in GameTypes.ALL_RESOURCES:
		if int(_trade_give_counts.get(r, 0)) > 0 and int(_trade_get_counts.get(r, 0)) > 0:
			return {}
		units -= int(_trade_get_counts.get(r, 0))
	if units != 0:
		return {}
	var pool: Array[int] = []
	for r in GameTypes.ALL_RESOURCES:
		var c := int(_trade_give_counts.get(r, 0))
		if c <= 0:
			continue
		for u in range(int(c / state.get_trade_ratio(pid, r))):
			pool.append(r)
	var swaps: Array[Dictionary] = []
	var idx := 0
	for r in GameTypes.ALL_RESOURCES:
		for u in range(int(_trade_get_counts.get(r, 0))):
			swaps.append({"give_res": pool[idx], "get_res": r})
			idx += 1
	return {"swaps": swaps}

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
	_fresh_trade_next_click = false
	var give_draft := _trade_give_counts.duplicate()
	var get_draft := _trade_get_counts.duplicate()
	var cancel_res: Dictionary = session.submit_action(session.get_acting_player_id(), GameAction.cancel_open_trade())
	if not bool(cancel_res.get("ok", false)):
		return
	session.submit_action(session.get_acting_player_id(), GameAction.open_trade(give_draft, get_draft))

func _on_clear_trade_pressed() -> void:
	_fresh_trade_next_click = false
	_reset_trade_counts()
	_refresh_trade_tray(session.state, session.get_acting_player_id(), _is_human_acting())

func _on_bank_trade_pressed() -> void:
	if session == null or session.state == null:
		return
	var pid := _trade_dash_pid()
	var sel := _bank_selection_check(session.state, pid)
	if sel.is_empty():
		return
	for s in (sel.get("swaps", []) as Array):
		var g := int((s as Dictionary).get("give_res", -1))
		var t := int((s as Dictionary).get("get_res", -1))
		var hand_before := int(session.state.players[pid]["hand"].get(g, 0))
		var bank_before := int(session.state.bank.get(t, 0))
		_submit_human_action(GameAction.maritime_trade(g, t))
		if session.state == null:
			break
		if int(session.state.players[pid]["hand"].get(g, 0)) == hand_before and int(session.state.bank.get(t, 0)) == bank_before:
			break
	_reset_trade_counts()

func _on_accept_offer_pressed() -> void:
	var answer_pid := _early_answer_pid()
	_submit_human_action(
		GameAction.respond_open_trade("accept"),
		answer_pid if answer_pid >= 0 else _trade_revise_pid
	)

func _on_decline_offer_pressed() -> void:
	var answer_pid := _early_answer_pid()
	_submit_human_action(
		GameAction.respond_open_trade("decline"),
		answer_pid if answer_pid >= 0 else _trade_revise_pid
	)

func _on_counter_offer_pressed() -> void:
	if session == null or session.state == null:
		return
	_trade_counter_mode = true
	_reset_trade_counts()
	var ot: Dictionary = session.state.open_trade
	var early_pid := _early_answer_pid()
	var answer_pid: int = (
		early_pid if early_pid >= 0
		else (_trade_revise_pid if _trade_revise_pid >= 0 else session.get_acting_player_id())
	)
	var hand: Dictionary = session.state.players[answer_pid].get("hand", {})
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
	var early_pid := _early_answer_pid()
	_submit_human_action(
		GameAction.respond_open_trade(
			"counter",
			_trade_get_counts.duplicate(),
			_trade_give_counts.duplicate()
		),
		early_pid if early_pid >= 0 else _trade_revise_pid
	)

func _on_counter_back_pressed() -> void:
	_trade_counter_mode = false
	_reset_trade_counts()
	_refresh_trade_tray(session.state, session.get_acting_player_id(), _is_human_acting())

func _hand_res_cursor(state: GameState, held: int, hand_hidden: bool) -> int:
	if hand_hidden or (not _is_human_acting() and _early_answer_pid() < 0):
		return Control.CURSOR_ARROW
	if state.phase == GameTypes.TurnPhase.TURN_DISCARD:
		return Control.CURSOR_POINTING_HAND
	if not _trade_allowed_now() or held <= 0:
		return Control.CURSOR_FORBIDDEN
	return Control.CURSOR_POINTING_HAND

func _hand_card_tooltip(state: GameState, res: int, hand_hidden: bool, held: int) -> String:
	if hand_hidden:
		return "Hand is hidden"
	if state.phase == GameTypes.TurnPhase.TURN_DISCARD:
		return "Click to pick a card to discard"
	if not _is_human_acting() and _early_answer_pid() < 0:
		return "Not your turn"
	if state.phase == GameTypes.TurnPhase.TURN_ROLL:
		return "Roll first"
	if not state.open_trade.is_empty():
		if _trade_counter_mode and _trade_respond_mode:
			return "Click to add %s to your counter" % GameTypes.resource_name(res)
		return "Reply to the open offer first"
	if held <= 0:
		return "No %s in hand" % GameTypes.resource_name(res)
	return "Click to offer in a trade"


func _on_resource_card_pressed(res: int) -> void:
	if _review_active:
		return
	if session == null or session.state == null:
		return
	if _hand_hidden():
		return
	var st := session.state
	if st.phase == GameTypes.TurnPhase.TURN_DISCARD:
		_discard_pick_one(res)
		return
	if not st.open_trade.is_empty():
		if not _is_human_acting() and not _own_offer_takeover() and _early_answer_pid() < 0:
			return
		var from_now := int(st.open_trade.get("from", -1))
		if from_now != session.get_acting_player_id() and from_now != _view_pid():
			if not _trade_tray.visible:
				_trade_reopen_token = ""
				_set_trade_hint(false)
				_set_tray_panel_visible(true)
				_refresh_ui()
				return
			if _trade_counter_mode and _trade_respond_mode:
				_adjust_trade_count(true, res, 1)
			return
		if _own_offer_dead(st):
			# Nobody can take this offer anymore: the click withdraws it and
			# starts a brand-new trade with the clicked card as the give.
			session.submit_action(int(st.open_trade.get("from", -1)), GameAction.cancel_open_trade())
			_no_takers_since_ms = 0
			_no_takers_token = ""
			_fresh_trade_next_click = false
			_reset_trade_counts()
			if _trade_tray != null and not _trade_tray.visible:
				_set_tray_panel_visible(true)
			_adjust_trade_count(true, res, 1)
			_refresh_ui()
			return
	if not (
		_is_human_acting()
		and st.phase == GameTypes.TurnPhase.TURN_MAIN
	):
		return
	if not _trade_tray.visible:
		_toggle_trade_tray()
		if not _trade_tray.visible:
			return
	if _fresh_trade_next_click:
		# The last offer died for lack of takers: this click starts fresh.
		_fresh_trade_next_click = false
		_reset_trade_counts()
	_adjust_trade_count(true, res, 1)

func _cancel_current_pick() -> void:
	_close_steal_chooser()
	_pending_guard_card = false
	_board_view.clear_highlights()
	_cancel_pick_btn.visible = false
	_refresh_ui()


func _on_toggle_bounty_panel() -> void:
	if not (_is_human_acting() or _own_offer_takeover()):
		return
	var was_vis := _subpanel_container.visible and _bounty_box.visible
	_hide_all_subpanels()
	_subpanel_chip = _popup_chip_by_type.get(GameTypes.DevCardType.HARVEST_BOUNTY)
	_bounty_box.visible = not was_vis
	_subpanel_container.visible = not was_vis
	_subpanel_owner_pid = session.get_acting_player_id() if not was_vis else -1

func _on_toggle_decree_panel() -> void:
	if not (_is_human_acting() or _own_offer_takeover()):
		return
	var was_vis := _subpanel_container.visible and _decree_box.visible
	_hide_all_subpanels()
	_subpanel_chip = _popup_chip_by_type.get(GameTypes.DevCardType.TRADE_DECREE)
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
			and bool(_dev_card_ok_tolerant(state, acting_id, GameTypes.DevCardType.HARVEST_BOUNTY).get("ok", false))
		)
		if not bounty_ok:
			_bounty_box.visible = false
	if _decree_box.visible:
		var decree_ok := (
			human_acting
			and acting_id == _subpanel_owner_pid
			and bool(_dev_card_ok_tolerant(state, acting_id, GameTypes.DevCardType.TRADE_DECREE).get("ok", false))
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
	cnt_lbl.add_theme_color_override("font_color", Palette.TEXT if highlight else Palette.TEXT_MUTED)
	cnt_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(cnt_lbl)
	if not highlight:
		return cell
	var wrap := PanelContainer.new()
	var ws := StyleBoxFlat.new()
	ws.bg_color = Palette.AWARD_HIGHLIGHT_BG
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
	outline.default_color = Palette.INK_OUTLINE
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	icon.add_child(outline)
	var fill := Line2D.new()
	fill.points = pts
	fill.width = 4.5
	fill.default_color = Palette.ROAD_ICON_FILL
	fill.begin_cap_mode = Line2D.LINE_CAP_ROUND
	fill.end_cap_mode = Line2D.LINE_CAP_ROUND
	icon.add_child(fill)
	cell.add_child(icon)
	var cnt_lbl := Label.new()
	cnt_lbl.text = str(route_len)
	cnt_lbl.add_theme_font_size_override("font_size", 10)
	cnt_lbl.add_theme_color_override("font_color", Palette.TEXT if highlight else Palette.TEXT_MUTED)
	cnt_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(cnt_lbl)
	if not highlight:
		return cell
	var wrap := PanelContainer.new()
	var ws := StyleBoxFlat.new()
	ws.bg_color = Palette.AWARD_HIGHLIGHT_BG
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
	if _review_active:
		return
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
# p39: ONE construction for the two raised cards (trade box, event log), so
# they cannot drift apart: fill SURFACE_RAISED, one 1 px PANEL_LINE line,
# radius 8, shared drop shadow. Measured with /tmp/opencode/p39/probe2.gd:
# the 4.3 raster border follows the quarter circle at the same visual weight
# as the straight edges (arc min 2.48 vs straight 2.54 paper; 1.13 vs 1.14
# dark); the two stacked fill variants dilute the semi-transparent line
# (1.79/1.11) and measure worse, so the single StyleBoxFlat stays. The
# reported "square corner + wedge" was the trade slot's clip cutting the
# shadow at its square corner - the slot does not clip anymore.
# p39r: corner_detail 16 + anti_aliasing_size 0.5 measured (probe 40x40
# corner crops vs a 16x LANCZOS ideal, /tmp/opencode/p39r) as the closest
# 1 px line to the ideal: RMS -19..-22 % paper, -10..-13 % dark, max pixel
# error -35 % paper, straight edges byte-identical; corner_detail alone and
# the _draw arc variants were worse (paper +71 % / faint broken line).
func _apply_raised_card(panel: Control) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.SURFACE_RAISED
	sb.set_border_width_all(1)
	sb.border_color = Palette.PANEL_LINE
	sb.set_corner_radius_all(8)
	sb.corner_detail = 16
	sb.anti_aliasing_size = 0.5
	sb.shadow_color = Palette.SHADOW_RAISED
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", sb)

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
			bg_h = Palette.BUTTON_PRIMARY_HOVER
			bg_p = Palette.BUTTON_PRIMARY_PRESSED
			fg = Palette.BUTTON_TEXT_ON_GOLD
		"danger":
			bg_n = Palette.ACCENT_RED
			bg_h = Palette.BUTTON_DANGER_HOVER
			bg_p = Palette.BUTTON_DANGER_PRESSED
			fg = Palette.BUTTON_TEXT_ON_RED
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
	st_p.border_color = Palette.BUTTON_BORDER_PRESSED
	btn.add_theme_stylebox_override("pressed", st_p)

	var st_d: StyleBoxFlat = st_n.duplicate() as StyleBoxFlat
	st_d.bg_color = Color(Palette.PANEL_BG, 0.0) if kind == "ghost" else Palette.BUTTON_BG_DISABLED
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
	btn.add_theme_color_override("icon_normal_color", fg)
	btn.add_theme_color_override("icon_hover_color", fg)
	btn.add_theme_color_override("icon_pressed_color", fg)
	btn.add_theme_color_override("icon_hover_pressed_color", fg)
	btn.add_theme_color_override("icon_focus_color", fg)
	btn.add_theme_color_override("icon_disabled_color", Palette.TEXT_MUTED)

func _style_option(opt: OptionButton) -> void:
	_style_button(opt, "normal")
	opt.add_theme_icon_override("arrow", _make_arrow_icon())
	_style_popup(opt.get_popup())

func _make_arrow_icon() -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.Format.FORMAT_RGBA8)
	var ink := Palette.TEXT
	var empty := Color(0, 0, 0, 0)
	var a := Vector2(8.0, 12.5)
	var b := Vector2(16.0, 20.0)
	var c := Vector2(24.0, 12.5)
	for y in range(size):
		for x in range(size):
			var px := Vector2(float(x) + 0.5, float(y) + 0.5)
			if _dist_to_seg(px, a, b) < 2.2 or _dist_to_seg(px, b, c) < 2.2:
				img.set_pixel(x, y, ink)
			else:
				img.set_pixel(x, y, empty)
	img.resize(16, 16)
	return ImageTexture.create_from_image(img)

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

func _apply_answer_selection(status: String) -> void:
	var entries: Array = [
		[_ot_accept_btn, "accept", "Accept", "primary"],
		[_ot_decline_btn, "decline", "Decline", "ghost"],
		[_ot_counter_btn, "counter", "Counter\u2026", "normal"],
	]
	for e in entries:
		var b := e[0] as Button
		if b == null:
			continue
		var base_kind := str(e[3])
		if status == "":
			_style_button(b, base_kind)
			_flatten_trade_button(b)
			b.text = str(e[2])
		elif str(e[1]) == status:
			_style_button(b, "primary")
			_flatten_trade_button(b)
			b.text = "\u2713 %s" % str(e[2])
		else:
			var kind := "normal" if base_kind == "primary" else base_kind
			_style_button(b, kind)
			_flatten_trade_button(b)
			b.text = str(e[2])

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
	p.add_theme_color_override("font_hover_color", Palette.OPTION_HOVER_TEXT)
	p.add_theme_font_size_override("font_size", 14)
	var mark := _make_popup_mark_icon("check", 1.0)
	var mark_d := _make_popup_mark_icon("check", 0.45)
	p.add_theme_icon_override("check", mark)
	p.add_theme_icon_override("check_disabled", mark_d)
	p.add_theme_icon_override("radio_checked", _make_popup_mark_icon("radio", 1.0))
	p.add_theme_icon_override("radio_unchecked", _make_popup_mark_icon("ring", 1.0))
	p.add_theme_icon_override("radio_checked_disabled", _make_popup_mark_icon("radio", 0.45))
	p.add_theme_icon_override("radio_unchecked_disabled", _make_popup_mark_icon("ring", 0.45))

func _make_popup_mark_icon(kind: String, strength: float) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.Format.FORMAT_RGBA8)
	var ink := Palette.TEXT
	ink.a = ink.a * strength
	var empty := Color(0, 0, 0, 0)
	for y in range(size):
		for x in range(size):
			var px := Vector2(float(x) + 0.5, float(y) + 0.5)
			var col := empty
			match kind:
				"check":
					var a := Vector2(5.0, 16.0)
					var b := Vector2(13.0, 24.0)
					var c := Vector2(27.0, 8.0)
					if _dist_to_seg(px, a, b) < 3.2 or _dist_to_seg(px, b, c) < 3.2:
						col = ink
				"ring", "radio":
					var center := Vector2(16.0, 16.0)
					var d := px.distance_to(center)
					if d < 11.0 and d > 7.5:
						col = ink
					if kind == "radio" and d < 5.0:
						col = ink
			img.set_pixel(x, y, col)
	img.resize(16, 16)
	return ImageTexture.create_from_image(img)

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
	le.add_theme_color_override("caret_color", Palette.TEXT_CARET)
	le.add_theme_color_override("selection_background_color", Palette.HEADING)
	le.add_theme_color_override("selection_foreground_color", Palette.PAPER)

var _check_theme: Theme = null
var _ui_theme: Theme = null

func _build_ui_theme() -> void:
	if _ui_theme == null:
		_ui_theme = Theme.new()
	var tip := StyleBoxFlat.new()
	tip.bg_color = Palette.SURFACE_RAISED
	tip.border_color = Palette.PANEL_LINE
	tip.set_border_width_all(1)
	tip.set_corner_radius_all(3)
	tip.content_margin_left = 4
	tip.content_margin_right = 4
	tip.content_margin_top = 2
	tip.content_margin_bottom = 2
	_ui_theme.set_stylebox("panel", "TooltipPanel", tip)
	_ui_theme.set_color("font_color", "TooltipLabel", Palette.TEXT)
	var track := StyleBoxFlat.new()
	track.bg_color = Palette.PANEL_BG_ALT
	track.border_color = Palette.PANEL_LINE
	track.set_border_width_all(1)
	track.set_corner_radius_all(4)
	track.content_margin_left = 2
	track.content_margin_right = 2
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var grab := StyleBoxFlat.new()
	grab.bg_color = Palette.PANEL_BORDER
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	grab.content_margin_top = 2
	grab.content_margin_bottom = 2
	var grab_hl: StyleBoxFlat = grab.duplicate() as StyleBoxFlat
	grab_hl.bg_color = Palette.HEADING
	var grab_pr: StyleBoxFlat = grab.duplicate() as StyleBoxFlat
	grab_pr.bg_color = Palette.HEADING
	var grab_dis: StyleBoxFlat = grab.duplicate() as StyleBoxFlat
	grab_dis.bg_color = Color(Palette.PANEL_BORDER, 0.5)
	for bar_name in ["VScrollBar", "HScrollBar"]:
		_ui_theme.set_stylebox("scroll", StringName(bar_name), track.duplicate() as StyleBoxFlat)
		_ui_theme.set_stylebox("grabber", StringName(bar_name), grab.duplicate() as StyleBoxFlat)
		_ui_theme.set_stylebox("grabber_highlight", StringName(bar_name), grab_hl.duplicate() as StyleBoxFlat)
		_ui_theme.set_stylebox("grabber_pressed", StringName(bar_name), grab_pr.duplicate() as StyleBoxFlat)
		_ui_theme.set_stylebox("grabber_disabled", StringName(bar_name), grab_dis.duplicate() as StyleBoxFlat)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Palette.PANEL_BG_ALT
	groove.border_color = Palette.PANEL_BORDER
	groove.set_border_width_all(1)
	groove.set_corner_radius_all(3)
	groove.content_margin_left = 2
	groove.content_margin_right = 2
	_ui_theme.set_stylebox("slider", "HSlider", groove)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.HEADING
	fill.set_corner_radius_all(3)
	var fill_hl: StyleBoxFlat = fill.duplicate() as StyleBoxFlat
	fill_hl.bg_color = Palette.ACCENT_GOLD
	_ui_theme.set_stylebox("grabber_area", "HSlider", fill)
	_ui_theme.set_stylebox("grabber_area_highlight", "HSlider", fill_hl)
	_ui_theme.set_stylebox("grabber", "HSlider", grab.duplicate() as StyleBoxFlat)
	_ui_theme.set_stylebox("grabber_highlight", "HSlider", grab_hl.duplicate() as StyleBoxFlat)
	_ui_theme.set_stylebox("grabber_disabled", "HSlider", grab_dis.duplicate() as StyleBoxFlat)
	_ui_theme.set_icon("grabber", "HSlider", _make_grabber_tex(Palette.PANEL_BORDER))
	_ui_theme.set_icon("grabber_highlight", "HSlider", _make_grabber_tex(Palette.HEADING))
	_ui_theme.set_icon("grabber_disabled", "HSlider", _make_grabber_tex(Color(Palette.PANEL_BORDER, 0.5)))
	for sep_name in ["VSeparator", "HSeparator"]:
		var line := StyleBoxLine.new()
		line.color = Palette.PANEL_BORDER
		line.thickness = 1
		line.vertical = sep_name == "VSeparator"
		_ui_theme.set_stylebox("line", StringName(sep_name), line)
	_ui_theme.emit_changed()
	theme = _ui_theme

func _make_grabber_tex(col: Color) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.Format.FORMAT_RGBA8)
	var center := Vector2(16.0, 16.0)
	for y in range(size):
		for x in range(size):
			var px := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d := px.distance_to(center)
			if d <= 15.0:
				img.set_pixel(x, y, col if d < 14.0 else Color(col.r, col.g, col.b, col.a * (15.0 - d)))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	img.resize(16, 16)
	return ImageTexture.create_from_image(img)

func _style_check(cb: BaseButton) -> void:
	_build_check_theme()
	cb.theme = _check_theme
	cb.add_theme_color_override("font_color", Palette.TEXT)
	cb.add_theme_color_override("font_hover_color", Palette.OPTION_HOVER_TEXT)
	cb.add_theme_color_override("font_pressed_color", Palette.OPTION_HOVER_TEXT)
	cb.add_theme_color_override("font_hover_pressed_color", Palette.OPTION_HOVER_TEXT)
	cb.add_theme_color_override("font_focus_color", Palette.OPTION_HOVER_TEXT)
	cb.add_theme_color_override("font_disabled_color", Palette.TEXT_MUTED)

func _build_check_theme() -> void:
	if _check_theme == null:
		_check_theme = Theme.new()
	var unchecked := StyleBoxFlat.new()
	unchecked.bg_color = Palette.CHECK_UNCHECKED_BG
	unchecked.border_color = Palette.CHECK_BORDER
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
	unchecked_d.border_color = Color(Palette.CHECK_BORDER, 0.5)

	var checked_d: StyleBoxFlat = checked.duplicate() as StyleBoxFlat
	checked_d.bg_color = Color(Palette.ACCENT_GREEN, 0.45)
	checked_d.border_color = Color(Palette.INK, 0.45)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(Palette.PANEL_BG, 0.0)
	focus.border_color = Palette.HEADING
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(4)

	for item_name in ["unchecked", "checked", "unchecked_disabled", "checked_disabled", "focus"]:
		var box: StyleBoxFlat = unchecked
		match item_name:
			"checked":
				box = checked
			"unchecked_disabled":
				box = unchecked_d
			"checked_disabled":
				box = checked_d
			"focus":
				box = focus
		_check_theme.set_stylebox(StringName(item_name), "CheckBox", box)
	for icon_name in ["unchecked", "checked", "unchecked_disabled", "checked_disabled"]:
		var checked_icon: bool = icon_name.begins_with("checked")
		var strength := 0.5 if icon_name.ends_with("_disabled") else 1.0
		if icon_name == "checked_disabled":
			strength = 0.45
		_check_theme.set_icon(StringName(icon_name), "CheckBox", _make_check_icon(checked_icon, strength))
	_check_theme.emit_changed()


func _make_check_icon(checked: bool, strength: float) -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.Format.FORMAT_RGBA8)
	var bg := Palette.ACCENT_GREEN if checked else Palette.CHECK_UNCHECKED_BG
	var border := (Palette.INK if checked else Palette.CHECK_BORDER)
	bg.a = bg.a * strength if checked else 1.0
	border.a = border.a * strength
	var radius := 7.0
	var mark := Palette.INK
	mark.a = mark.a * strength
	var p0 := Vector2(7.0, 16.0)
	var p1 := Vector2(13.0, 22.0)
	var p2 := Vector2(25.0, 9.0)
	for y in range(size):
		for x in range(size):
			var px := Vector2(float(x) + 0.5, float(y) + 0.5)
			var inside := _rounded_rect_contains(px, size, radius)
			if not inside:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var in_border := (
				px.x < 4.0 or px.y < 4.0 or px.x > float(size) - 4.0 or px.y > float(size) - 4.0
				or not _rounded_rect_contains(px, size - 4.0, radius)
			)
			var col := border if in_border else bg
			if checked and not in_border and (_dist_to_seg(px, p0, p1) < 3.0 or _dist_to_seg(px, p1, p2) < 3.0):
				col = mark
			img.set_pixel(x, y, col)
	img.resize(16, 16)
	return ImageTexture.create_from_image(img)


func _rounded_rect_contains(px: Vector2, size: float, radius: float) -> bool:
	if px.x < 0.0 or px.y < 0.0 or px.x > size or px.y > size:
		return false
	var c := Vector2(radius, radius)
	var corner := Vector2(size - radius, size - radius)
	if px.x < c.x and px.y < c.y:
		return px.distance_to(c) <= radius
	if px.x > corner.x and px.y < c.y:
		return px.distance_to(Vector2(corner.x, c.y)) <= radius
	if px.x < c.x and px.y > corner.y:
		return px.distance_to(Vector2(c.x, corner.y)) <= radius
	if px.x > corner.x and px.y > corner.y:
		return px.distance_to(corner) <= radius
	return true


func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _style_rich_label(rtl: RichTextLabel) -> void:
	rtl.add_theme_color_override("default_color", Palette.TEXT)
	rtl.add_theme_color_override("font_color", Palette.TEXT)
	rtl.add_theme_font_size_override("normal_font_size", 13)
	rtl.add_theme_font_size_override("bold_font_size", 13)
	var bg_empty := StyleBoxFlat.new()
	bg_empty.bg_color = Color(Palette.PANEL_BG, 0.0)
	rtl.add_theme_stylebox_override("background", bg_empty)

const _REV_BADGE_SLOT_W := 13

class RevBadge extends Control:
	# 0.9 s of wall-clock spin driven by the accumulated delta, so it is
	# 0.9 s at any frame rate and stays exact under --write-movie --fixed-fps.
	const SPIN_SECONDS := 0.9
	var ring_color := Color.WHITE
	var anim_start_ms := -1
	var spin_left := 0.0
	# >= 0: hug the parent's right inner edge (x = parent.width - inset - 13);
	# < 0: sit 3 px after the parent's right edge. Overlays never join a
	# container, so the host's minimum size (and the tray width) stays fixed.
	var right_inset := -1.0
	# >= -900: draw at this fixed x inside the parent (watch-row names keep a
	# fixed-width box, so the arrow sits in its unused tail).
	var fixed_x := -999.0

	func _init() -> void:
		custom_minimum_size = Vector2(13, 13)
		size = Vector2(13, 13)
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = "Changed their answer"

	func _process(d: float) -> void:
		if size != Vector2(13, 13):
			size = Vector2(13, 13)
		var host := get_parent() as Control
		if host != null:
			if fixed_x >= -900.0:
				position = Vector2(fixed_x, (host.size.y - 13.0) * 0.5)
			elif right_inset >= 0.0:
				position = Vector2(host.size.x - right_inset - 13.0, (host.size.y - 13.0) * 0.5)
			else:
				position = Vector2(host.size.x + 3.0, (host.size.y - 13.0) * 0.5)
		if anim_start_ms >= 0:
			spin_left = SPIN_SECONDS
			anim_start_ms = -2
		if spin_left > 0.0:
			spin_left = maxf(0.0, spin_left - d)
			queue_redraw()
		elif anim_start_ms == -2:
			anim_start_ms = -1

	func _draw() -> void:
		var spin_t := 0.0
		if anim_start_ms == -2 or spin_left > 0.0:
			spin_t = clampf((SPIN_SECONDS - spin_left) / SPIN_SECONDS, 0.0, 1.0)
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var rot := spin_t * TAU
		var a1 := rot + TAU * 0.30
		var a0 := rot - TAU * 0.30
		draw_arc(c, r, a0, a1, 20, ring_color, 2.0)
		var tip := c + Vector2(cos(a1), sin(a1)) * r
		var tang := Vector2(-sin(a1), cos(a1))
		var rad := Vector2(cos(a1), sin(a1))
		draw_polygon(
			PackedVector2Array([tip + tang * 4.0, tip - tang * 1.0 + rad * 3.0, tip - tang * 1.0 - rad * 3.0]),
			PackedColorArray([ring_color])
		)

# want_spin: only the answer-row badge spins on arrival; it consumes the
# arrival stamp so badges recreated by later rebuilds stay static.
func _make_rev_badge_for(p_id: int, pcol: Color, want_spin := false) -> Control:
	var b := RevBadge.new()
	b.ring_color = pcol
	if not _reduce_motion and want_spin and _rev_badge_anim.has(p_id):
		var stamp := int(_rev_badge_anim[p_id])
		if int(_rev_spin_taken.get(p_id, -1)) != stamp:
			_rev_spin_taken[p_id] = stamp
			b.anim_start_ms = stamp
	return b

func _wrap_row_bg(child: Control) -> PanelContainer:
	var wrap := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(0)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	wrap.add_theme_stylebox_override("panel", sb)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(child)
	return wrap

# Driven by the accumulated _process delta, not the wall clock and not a
# frame counter: the pulse spans exactly 0.9 s of played time at any frame
# rate (a clock-based pulse is invisible when frames are slower than the
# window; a frame-counted one lasts different times per frame rate).
const _REV_PULSE_SECONDS := 0.9
const _REV_PULSE_PEAK := 0.5

func _pulse_row_bg(wrap: PanelContainer, pcol: Color) -> void:
	var sb: StyleBoxFlat = wrap.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null or _reduce_motion:
		return
	sb.bg_color = Color(pcol.r, pcol.g, pcol.b, 0.0)
	_rev_pulse_wraps.append({"wrap": wrap, "sb": sb, "col": pcol, "pid": _rev_pulse_pending_pid, "t": 0.0})

func _tick_rev_pulse(delta: float) -> void:
	if _rev_pulse_wraps.is_empty():
		return
	var keep: Array = []
	for e in _rev_pulse_wraps:
		var wvar: Variant = e["wrap"]
		var wrap: PanelContainer = null
		if wvar != null and is_instance_valid(wvar):
			wrap = wvar
		if wrap == null:
			# The panel rebuilds free the wrapper; rebind to the fresh one.
			var fresh: Array = _rev_wrap_by_pid.get(int(e["pid"]), [])
			wrap = null
			for cand in fresh:
				if cand != null and is_instance_valid(cand):
					wrap = cand as PanelContainer
					break
			if wrap == null:
				continue
			var nsb: StyleBoxFlat = wrap.get_theme_stylebox("panel") as StyleBoxFlat
			if nsb == null:
				continue
			e["wrap"] = wrap
			e["sb"] = nsb
		var sb := e["sb"] as StyleBoxFlat
		var col := e["col"] as Color
		var t := float(e["t"]) + delta
		if t >= _REV_PULSE_SECONDS:
			sb.bg_color = Color(col.r, col.g, col.b, 0.0)
			continue
		e["t"] = t
		# Two triangular pulses: 0 -> peak -> 0, twice.
		var half := _REV_PULSE_SECONDS * 0.5
		var local := fmod(t, half) / half
		var tri := 1.0 - absf(local * 2.0 - 1.0)
		sb.bg_color = Color(col.r, col.g, col.b, _REV_PULSE_PEAK * tri)
		keep.append(e)
	_rev_pulse_wraps = keep

func _note_revision_anim(events: Array[String], state: GameState) -> void:
	if _reduce_motion:
		return
	var now := Time.get_ticks_msec()
	for ev in events:
		var e := str(ev)
		if not e.contains(" revises: "):
			continue
		for p_id in range(state.players.size()):
			var nm := str(state.players[p_id].get("name", GameTypes.PLAYER_NAMES[p_id]))
			if e.begins_with("%s revises:" % nm):
				_rev_badge_anim[p_id] = now
				break

func _sync_rev_badge_token(tok: String) -> void:
	if _rev_badge_token != tok:
		_rev_badge_token = tok
		_rev_badge_anim.clear()
		_rev_pulsed.clear()

func _maybe_pulse_rev(wrap: PanelContainer, p_id: int, pcol: Color) -> void:
	var live: Array = _rev_wrap_by_pid.get(p_id, [])
	if not live.has(wrap):
		live.append(wrap)
	_rev_wrap_by_pid[p_id] = live
	if _reduce_motion or not _rev_badge_anim.has(p_id):
		return
	var start_ms := int(_rev_badge_anim[p_id])
	if int(_rev_pulsed.get(p_id, -1)) == start_ms:
		return
	_rev_pulsed[p_id] = start_ms
	_rev_pulse_pending_pid = p_id
	_pulse_row_bg(wrap, pcol)

func _pill_attach_badge(pill: PanelContainer, p_id: int, pcol: Color) -> void:
	var b := _make_rev_badge_for(p_id, pcol)
	b.right_inset = 2.0
	var sbp: StyleBoxFlat = pill.get_theme_stylebox("panel") as StyleBoxFlat
	if sbp != null:
		sbp.content_margin_right = 20.0
	pill.add_child(b)

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

func _make_card_panel(bg_col: Color, fine_line: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var st := _paper_panel_style()
	st.bg_color = bg_col
	st.set_corner_radius_all(10)
	if fine_line:
		st.set_border_width_all(1)
		st.border_color = Palette.PANEL_LINE
	else:
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
	_add_to_flight_layer(fx)
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

func _game_is_active() -> bool:
	if session == null or session.state == null:
		return true
	if not _is_human_acting():
		return true
	if _dice_show_active:
		return true
	if _steal_anim_active():
		return true
	if _trade_hold_active():
		return true
	if _splash_overlay != null and _splash_overlay.visible:
		return true
	if _win_stage > WIN_STAGE_NONE and _win_stage < WIN_STAGE_DONE:
		return true
	if _flight_layer != null and not _flight_layer.get_children().is_empty():
		return true
	if _toast_layer != null and not _toast_layer.get_children().is_empty():
		return true
	if _board_view != null and _board_view.is_busy():
		return true
	for tw in get_tree().get_processed_tweens():
		if not tw.is_running():
			continue
		if tw == _trade_hint_tween or tw == _sb_focus_tween:
			continue
		if _dice_widget != null and tw == _dice_widget._pulse_tween:
			continue
		return true
	return false

func _wanted_fps() -> int:
	if _game_is_active() or _fps_idle_timer < FPS_IDLE_AFTER_S:
		return FPS_ACTIVE
	return FPS_IDLE

func _update_fps_cap(delta: float) -> void:
	if fps_cap_override >= 0:
		if Engine.max_fps != fps_cap_override:
			Engine.max_fps = fps_cap_override
		return
	if DisplayServer.get_name() == "headless" or OS.has_feature("movie"):
		return
	if _game_is_active():
		_fps_idle_timer = 0.0
	elif _fps_idle_timer < FPS_IDLE_AFTER_S:
		_fps_idle_timer = minf(FPS_IDLE_AFTER_S, _fps_idle_timer + delta)
	var want := FPS_IDLE if _fps_idle_timer >= FPS_IDLE_AFTER_S else FPS_ACTIVE
	if Engine.max_fps != want:
		Engine.max_fps = want

func _process(delta: float) -> void:
	var cur_win := get_viewport().get_visible_rect().size
	if cur_win != _seen_win_size:
		var first_seen := _seen_win_size == Vector2(-1, -1)
		_seen_win_size = cur_win
		# A programmatic window resize (tests, headless) never emits the OS
		# RESIZED signal; poll so the layout still follows the viewport.
		if not first_seen and cur_win.x >= 100.0 and cur_win.y >= 100.0:
			_layout_needs_apply = true
			_on_window_resized()
	# A resize that lands before the first layout pass sees zero container
	# sizes and bails out; retry until the sidebar actually has a height.
	if _layout_needs_apply and _right_panel != null and _right_panel.size.y > 340.0:
		_layout_needs_apply = false
		_apply_window_layout()
	if _dice_show_active:
		_advance_dice_show(delta)
	_advance_win_sequence(delta)
	if _sb_focus_overlay != null and _sb_focus_overlay.visible:
		_update_scoreboard_focus_overlay()
	_trade_watch_pacing()
	_flush_partner_rebuild()
	_tick_rev_pulse(delta)
	_review_tick(delta)
	_update_fps_cap(delta)

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


func _mk_review_btn(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_font_size_override("font_size", 12)
	_style_button(b, "ghost")
	return b

func _build_review_bar(bar_box: VBoxContainer) -> void:
	_review_bar = HBoxContainer.new()
	_review_bar.add_theme_constant_override("separation", 4)
	_review_bar.visible = false
	_review_bar.custom_minimum_size = Vector2(0, 30)
	bar_box.add_child(_review_bar)
	var b_first := _mk_review_btn("\u23ee", "First step (Home)")
	b_first.pressed.connect(func() -> void: _review_goto(0))
	_review_bar.add_child(b_first)
	var b_pturn := _mk_review_btn("\u25c0 Turn", "Previous turn")
	b_pturn.pressed.connect(_review_prev_turn)
	_review_bar.add_child(b_pturn)
	var b_prev := _mk_review_btn("\u25c0", "Previous step (Left)")
	b_prev.pressed.connect(func() -> void: _review_goto(_review_step - 1))
	_review_bar.add_child(b_prev)
	_review_play_btn = _mk_review_btn("Play", "Play / pause (Space)")
	_review_play_btn.pressed.connect(func() -> void: _review_set_play(not _review_playing))
	_review_bar.add_child(_review_play_btn)
	var b_next := _mk_review_btn("\u25b6", "Next step (Right)")
	b_next.pressed.connect(func() -> void: _review_goto(_review_step + 1))
	_review_bar.add_child(b_next)
	var b_nturn := _mk_review_btn("Turn \u25b6", "Next turn")
	b_nturn.pressed.connect(_review_next_turn)
	_review_bar.add_child(b_nturn)
	var b_last := _mk_review_btn("\u23ed", "Last step (End)")
	b_last.pressed.connect(func() -> void: _review_goto(_review_replay.step_count() if _review_replay != null else 0))
	_review_bar.add_child(b_last)
	_review_slider = HSlider.new()
	_review_slider.focus_mode = Control.FOCUS_NONE
	_review_slider.custom_minimum_size = Vector2(160, 20)
	_review_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_review_slider.value_changed.connect(_on_review_slider)
	_review_bar.add_child(_review_slider)
	_review_slider_ticks = ReviewSliderTicks.new()
	_review_slider_ticks.name = "TurnTicks"
	_review_slider_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_review_slider_ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_review_slider.add_child(_review_slider_ticks)
	_review_speed_opt = OptionButton.new()
	_review_speed_opt.focus_mode = Control.FOCUS_NONE
	_review_speed_opt.add_item("1x")
	_review_speed_opt.add_item("2x")
	_review_speed_opt.add_item("4x")
	_review_speed_opt.tooltip_text = "Playback speed"
	_review_speed_opt.select(0)
	_review_speed_opt.item_selected.connect(func(idx: int) -> void: _review_speed = [1, 2, 4][idx])
	_style_option(_review_speed_opt)
	_review_bar.add_child(_review_speed_opt)
	_review_step_lbl = Label.new()
	_review_step_lbl.add_theme_font_size_override("font_size", 12)
	_review_step_lbl.add_theme_color_override("font_color", Palette.HEADING)
	_review_step_lbl.custom_minimum_size = Vector2(240, 0)
	_review_bar.add_child(_review_step_lbl)
	_review_caption = Label.new()
	_review_caption.add_theme_font_size_override("font_size", 13)
	_review_caption.add_theme_color_override("font_color", Palette.TEXT)
	_review_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_review_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_review_caption.visible = false
	(bar_box.get_child(0) as HBoxContainer).add_child(_review_caption)
	_review_save_btn = _mk_review_btn("Save for later", "Write this match to your saved replays")
	_review_save_btn.pressed.connect(_save_replay_pressed)
	_review_bar.add_child(_review_save_btn)
	var b_exit := _mk_review_btn("Exit review", "Back to the results (Esc)")
	b_exit.pressed.connect(_exit_review)
	_review_bar.add_child(b_exit)
	var keep := {}
	keep[_hand_view_swatch] = true
	keep[_hand_view_name] = true
	for r in GameTypes.ALL_RESOURCES:
		keep[_res_card_refs.get(r, null)] = true
	for ctype in _action_chips.keys():
		keep[_action_chips[ctype]] = true
	keep[_review_caption] = true
	for c in (bar_box.get_child(0) as HBoxContainer).get_children():
		if keep.has(c):
			continue
		_review_hidden_nodes.append(c as Control)
		_review_hidden_was.append((c as Control).visible)

func _enter_review() -> void:
	if _review_active or session == null or session.replay == null or session.replay.step_count() <= 0:
		return
	_review_from_list = false
	_begin_review(session.replay, session.seats)

func _enter_review_from_replay(r: MatchReplay) -> void:
	if _review_active or r == null or r.step_count() <= 0:
		return
	var scs: Array[SeatConfig] = []
	for sd in r.seats:
		var d: Dictionary = sd
		var sc := SeatConfig.new()
		sc.seat_id = int(d.get("idx", scs.size()))
		sc.seat_type = int(d.get("type", SeatConfig.SeatType.AI_MEDIUM))
		sc.display_name = str(d.get("name", ""))
		scs.append(sc)
	_review_from_list = true
	_begin_review(r, scs)

func _begin_review(r: MatchReplay, seat_list: Array[SeatConfig]) -> void:
	_finish_steal_anim()
	_reset_flight_state()
	_win_sequence_cancel()
	_review_prev_banner = _turn_banner_label.text if _turn_banner_label != null else ""
	_review_saved_log_lines = _log_lines.duplicate()
	_real_session = session
	_review_replay = r
	_review_session = ReviewSession.new()
	_review_session.seats = seat_list
	_review_session.replay = _review_replay
	_review_active = true
	session = _review_session
	var fh := _find_first_human_seat()
	_review_view_pid = fh if fh >= 0 else 0
	for c in _review_hidden_nodes:
		_review_hidden_was[_review_hidden_nodes.find(c)] = c.visible
		c.visible = false
	_review_bar.visible = true
	_review_caption.visible = true
	_review_save_btn.visible = not _review_from_list
	_apply_save_buttons()
	_review_update_slider_ticks()
	_review_set_row_clickers(true)
	_review_slider.min_value = 0.0
	_review_slider.max_value = float(_review_replay.step_count())
	_review_slider.tick_count = 0
	_review_slider.step = 1.0
	_splash_overlay.visible = false
	_results_btn.visible = false
	if _review_from_list:
		_replays_overlay.visible = false
		_lobby_overlay.visible = false
	_review_set_play(false)
	_prev_dash_pid = -1
	_review_goto(0)

func _exit_review() -> void:
	if not _review_active:
		return
	_review_set_play(false)
	_review_active = false
	session = _real_session
	_real_session = null
	_review_session = null
	_review_replay = null
	_review_bar.visible = false
	_review_caption.visible = false
	for i in range(_review_hidden_nodes.size()):
		_review_hidden_nodes[i].visible = _review_hidden_was[i]
	_trade_tray.visible = false
	_trade_respond_mode = false
	_trade_counter_mode = false
	_trade_reopen_token = ""
	_trade_last_ot_open = false
	_trade_opened_auto = false
	_trade_view_pid = -1
	_set_trade_hint(false)
	_reset_trade_counts()
	_review_set_row_clickers(false)
	_log_lines = _review_saved_log_lines.duplicate()
	_rebuild_log_label(_event_log)
	if _log_popup != null and _log_popup.visible and _log_popup_text != null:
		_rebuild_log_label(_log_popup_text)
	if _review_from_list:
		_review_from_list = false
		_replays_overlay.visible = false
		_show_lobby()
	else:
		_splash_overlay.visible = true
	_results_btn.visible = false
	_prev_dash_pid = -1
	if _turn_banner_label != null:
		_turn_banner_label.text = _review_prev_banner
	_refresh_ui()

func _review_goto(step: int) -> void:
	if not _review_active or _review_replay == null:
		return
	_review_step = clampi(step, 0, _review_replay.step_count())
	var st := _review_replay.state_at(_review_step)
	_review_session.state = st
	_turn_focus_pid = -1 if st.phase == GameTypes.TurnPhase.GAME_OVER else st.current_player
	_board_view.set_state(st)
	_review_rebuild_log()
	_refresh_ui()
	_review_update_bar()
	_review_set_banner()

func _review_set_banner() -> void:
	if _review_session == null or _review_session.state == null:
		return
	var st: GameState = _review_session.state
	var who := str(st.players[st.current_player].get("name", "")) if st.current_player >= 0 and st.current_player < st.players.size() else "?"
	_set_banner("Reviewing match \u2014 %s's turn" % who)

func _review_update_bar() -> void:
	if _review_replay == null:
		return
	var n := _review_replay.step_count()
	_review_applying = true
	_review_slider.set_value_no_signal(float(_review_step))
	_review_applying = false
	var st: GameState = _review_session.state
	var who := str(st.players[st.current_player].get("name", "")) if st != null and st.current_player >= 0 and st.current_player < st.players.size() else ""
	_review_step_lbl.text = "Step %d / %d \u2014 Turn %d \u2014 %s" % [_review_step, n, _review_replay.turn_at(_review_step), who]
	var parts: Array[String] = []
	if _review_step == 0:
		parts.append("Match setup \u2014 before the first action")
	else:
		for ev in _review_replay.events_at(_review_step):
			parts.append(_log_display_text(str(ev)))
		if parts.is_empty() and _review_step <= _review_replay.entries.size():
			var entry: Dictionary = _review_replay.entries[_review_step - 1]
			if str((entry.get("a", {}) as Dictionary).get("type", "")) == "review_open_trade":
				var epid := int(entry.get("p", -1))
				var ename := "?"
				if st != null and epid >= 0 and epid < st.players.size():
					ename = str(st.players[epid].get("name", "?"))
				parts.append("%s keeps their answer." % ename)
	_review_caption.text = " \u00b7 ".join(parts) if not parts.is_empty() else "\u2014"
	_review_caption.tooltip_text = _review_caption.text
	_review_play_btn.text = "Pause" if _review_playing else "Play"

func _review_rebuild_log() -> void:
	_log_lines.clear()
	for s2 in range(1, _review_step + 1):
		for ev in _review_replay.events_at(s2):
			_log_lines.append("\u2022 " + _log_display_text(str(ev)))
	if _log_lines.size() > LOG_MAX_LINES:
		_log_lines = _log_lines.slice(_log_lines.size() - LOG_MAX_LINES)
	_rebuild_log_label(_event_log)
	if _log_popup != null and _log_popup.visible and _log_popup_text != null:
		_rebuild_log_label(_log_popup_text)

func _review_tick(delta: float) -> void:
	if not _review_playing or _review_replay == null:
		return
	_review_play_acc += delta
	var per := 0.6 / float(_review_speed)
	while _review_play_acc >= per:
		_review_play_acc -= per
		if _review_step >= _review_replay.step_count():
			_review_set_play(false)
			return
		_review_goto(_review_step + 1)

func _review_set_play(v: bool) -> void:
	_review_playing = v
	_review_play_acc = 0.0
	if _review_play_btn != null:
		_review_play_btn.text = "Pause" if v else "Play"

func _review_prev_turn() -> void:
	if _review_replay == null:
		return
	var t := _review_replay.turn_at(_review_step)
	for back in range(1, 3):
		var fs := _review_replay.first_step_of_turn(t - back)
		if fs >= 0 and fs < _review_step:
			_review_goto(fs)
			return

func _review_next_turn() -> void:
	if _review_replay == null:
		return
	var t := _review_replay.turn_at(_review_step)
	for fwd in range(1, 3):
		var fs := _review_replay.first_step_of_turn(t + fwd)
		if fs > _review_step:
			_review_goto(fs)
			return

func _review_set_view_pid(pid: int) -> void:
	if not _review_active or pid < 0:
		return
	_review_view_pid = pid
	_prev_dash_pid = -1
	_refresh_ui()
	_review_set_banner()

func _review_set_row_clickers(on: bool) -> void:
	for k in _scoreboard_row_parts.keys():
		var card := ((_scoreboard_row_parts[k] as Dictionary).get("card") as Control)
		if card == null or not is_instance_valid(card):
			continue
		var rc := card.get_node_or_null("RowClick") as Control
		if rc != null:
			rc.visible = on

func _on_sb_row_gui(ev: InputEvent, k: int) -> void:
	if not _review_active or not (ev is InputEventMouseButton):
		return
	var mb := ev as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var pid := int(_sb_row_slot_pid.get(k, -1))
		if pid >= 0:
			_review_set_view_pid(pid)
			get_viewport().set_input_as_handled()

func _review_update_slider_ticks() -> void:
	if _review_slider_ticks == null or _review_replay == null:
		return
	var marks: Array[float] = []
	var n := _review_replay.step_count()
	if n > 0:
		var t := _review_replay.turn_at(0)
		var t_end := _review_replay.turn_at(n)
		while t <= t_end:
			var fs := _review_replay.first_step_of_turn(t)
			if fs >= 0:
				marks.append(float(fs) / float(n))
			t += 1
	_review_slider_ticks.marks = marks
	_review_slider_ticks.queue_redraw()

func _on_review_slider(v: float) -> void:
	if _review_applying:
		return
	_review_goto(int(round(v)))

func _handle_review_key(keycode: int) -> void:
	match keycode:
		KEY_LEFT:
			_review_goto(_review_step - 1)
		KEY_RIGHT:
			_review_goto(_review_step + 1)
		KEY_HOME:
			_review_goto(0)
		KEY_END:
			if _review_replay != null:
				_review_goto(_review_replay.step_count())
		KEY_SPACE:
			_review_set_play(not _review_playing)
		KEY_ESCAPE:
			_exit_review()


func _save_replay_pressed() -> void:
	var r: MatchReplay = _review_replay if _review_active else (session.replay if session != null else null)
	if r == null or r.step_count() <= 0 or _replay_saved_path != "":
		return
	var derr := DirAccess.make_dir_recursive_absolute("user://replays")
	if derr != OK:
		_report_save_error(derr)
		return
	var dt := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d-%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	var path := "user://replays/%s_seed%d.json" % [stamp, r.seed_val]
	var err := r.save_to_file(path)
	if err != OK:
		_report_save_error(err)
		return
	_replay_saved_path = path
	_apply_save_buttons()

func _report_save_error(err: int) -> void:
	var msg := "Could not save the replay: %s" % error_string(err)
	for b in [_splash_save_btn, _review_save_btn]:
		if b != null:
			b.tooltip_text = msg
	_set_banner(msg)

func _apply_save_buttons() -> void:
	var saved := _replay_saved_path != ""
	for b in [_splash_save_btn, _review_save_btn]:
		if b == null:
			continue
		b.text = "Saved \u2713" if saved else "Save for later"
		b.disabled = saved

func _build_replays_overlay() -> void:
	_replays_overlay = ColorRect.new()
	_replays_overlay.z_index = 2
	_replays_overlay.color = Color(Palette.SCRIM, 0.62)
	_replays_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_replays_overlay.visible = false
	add_child(_replays_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_replays_overlay.add_child(center)
	var modal := _make_card_panel(Palette.PANEL_BG, true)
	modal.custom_minimum_size = Vector2(660, 340)
	center.add_child(modal)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	modal.add_child(vbox)
	var title := Label.new()
	title.text = "Saved replays"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Palette.HEADING)
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	_replays_list_box = VBoxContainer.new()
	_replays_list_box.add_theme_constant_override("separation", 4)
	_replays_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_replays_list_box)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 34)
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_button(close_btn, "ghost")
	close_btn.pressed.connect(func() -> void: _replays_overlay.visible = false)
	vbox.add_child(close_btn)

func _replay_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open("user://replays")
	if dir != null:
		for f in dir.get_files():
			if str(f).ends_with(".json"):
				files.append(str(f))
	files.sort()
	files.reverse()
	return files

func _open_replays_list() -> void:
	_replays_overlay.visible = true
	_rebuild_replays_rows()

func _rebuild_replays_rows() -> void:
	for c in _replays_list_box.get_children():
		c.queue_free()
	await get_tree().process_frame
	var files := _replay_files()
	if files.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No saved replays yet"
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Palette.TEXT_MUTED)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_replays_list_box.add_child(empty_lbl)
		return
	for f in files:
		var path := "user://replays/" + f
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var r := MatchReplay.load_from_file(path)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_theme_font_size_override("font_size", 13)
		info.add_theme_color_override("font_color", Palette.TEXT)
		info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if r == null:
			info.text = "Unreadable file \u2014 %s" % f
		else:
			var stamp := f.get_basename().split("_")[0]
			var pretty := stamp
			if stamp.length() >= 15:
				pretty = "%s-%s-%s %s:%s" % [stamp.substr(0, 4), stamp.substr(4, 2), stamp.substr(6, 2), stamp.substr(9, 2), stamp.substr(11, 2)]
			var wname := "?"
			if r.winner >= 0:
				wname = ""
				for rowd in r.standings:
					if int((rowd as Dictionary).get("pid", -1)) == int(r.winner):
						wname = str((rowd as Dictionary).get("name", ""))
						break
				if wname == "":
					for sd in r.seats:
						if int((sd as Dictionary).get("idx", -1)) == int(r.winner):
							wname = str((sd as Dictionary).get("name", ""))
							break
					if wname == "":
						wname = GameTypes.PLAYER_NAMES[int(r.winner)]
			info.text = "%s \u00b7 seed %d \u00b7 %d players \u00b7 %s wins \u00b7 %d turns" % [pretty, r.seed_val, r.seats.size(), wname, r.turn_at(r.step_count())]
		hbox.add_child(info)
		var rev := Button.new()
		rev.text = "Review"
		rev.focus_mode = Control.FOCUS_NONE
		_style_button(rev, "normal")
		rev.disabled = r == null
		var rp := r
		rev.pressed.connect(func() -> void:
			_replays_overlay.visible = false
			_enter_review_from_replay(rp)
		)
		hbox.add_child(rev)
		var del := Button.new()
		del.text = "Delete"
		del.focus_mode = Control.FOCUS_NONE
		_style_button(del, "ghost")
		var fpath := path
		del.pressed.connect(func() -> void:
			if str(del.text) != "Really delete?":
				del.text = "Really delete?"
				return
			DirAccess.remove_absolute(ProjectSettings.globalize_path(fpath))
			_rebuild_replays_rows()
		)
		hbox.add_child(del)
		_replays_list_box.add_child(hbox)

class ReviewSliderTicks extends Control:
	var marks: Array[float] = []
	var _p27_unused := 0

	func _draw() -> void:
		var inset := 9.0
		var w := size.x - inset * 2.0
		for m in marks:
			var x := inset + clampf(m, 0.0, 1.0) * w
			draw_rect(Rect2(x - 0.5, size.y - 8.0, 1.0, 7.0), Palette.PANEL_BORDER)

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
			draw_colored_polygon(poly, Color(Palette.SPLASH_SCRIM, sa))
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
		# A display-only copy (DiceShowFX) is added with FOCUS_NONE +
		# MOUSE_FILTER_IGNORE: honour that so it never eats focus or clicks
		# from the real widget underneath it.
		if focus_mode != Control.FOCUS_NONE:
			focus_mode = Control.FOCUS_ALL
		if mouse_filter != Control.MOUSE_FILTER_IGNORE:
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
			draw_rect(Rect2(Vector2(-2.0, top - 2.0), Vector2(DICE_SIZE * 2.0 + DICE_GAP + 4.0, DICE_SIZE + 4.0)), Color(Palette.ART_LIGHT, 0.55))

		var pill_pos := Vector2(DICE_SIZE * 2.0 + DICE_GAP + 8.0, top + (DICE_SIZE - PILL_H) * 0.5)
		var pill_rect := Rect2(pill_pos, Vector2(PILL_W, PILL_H))
		var pbox := StyleBoxFlat.new()
		if _rolling:
			pbox.bg_color = Color(Palette.ACCENT_GOLD, 0.55)
		else:
			pbox.bg_color = Palette.DICE_PILL_BG
		pbox.border_color = Palette.INK_OUTLINE if total_visible else Color(Palette.INK_OUTLINE, 0.55)
		pbox.set_border_width_all(2)
		pbox.set_corner_radius_all(int(PILL_H * 0.5))

		var font := ThemeDB.fallback_font
		if font == null:
			_redraw_rings()
			return
		if not total_visible:
			draw_style_box(pbox, pill_rect)
			for k in range(3):
				draw_circle(pill_rect.get_center() + Vector2((float(k) - 1.0) * 9.0, 0.0), 2.4, Color(Palette.NUMBER_TOKEN_TEXT, 0.65))
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
			Palette.NUMBER_TOKEN_TEXT
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
			ring.border_color = Color(Palette.DICE_PULSE_RING, _pulse_alpha)
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
		box.border_color = Palette.PANEL_BORDER
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

# The win-sequence confetti: WIN_CONFETTI_COUNT small rectangles drawn by this one
# Control's _draw (never a node per piece). A piece's place at time t is computed from
# its spawn data, not accumulated frame by frame, so a run is fully described by the
# piece list — which comes from a RandomNumberGenerator seeded with the match seed —
# and two runs of one seed agree piece for piece (piece_positions_at lets tests check
# that without waiting for frames).
class WinConfetti extends Control:
	var pieces: Array = []
	var piece_w := 6.0
	var piece_h := 10.0
	var elapsed := -1.0

	func set_elapsed(t: float) -> void:
		elapsed = t
		queue_redraw()

	func piece_pos(p: Dictionary, ft: float) -> Vector2:
		return Vector2(
			float(p["x"]) + float(p["vx"]) * ft + sin(ft * float(p["sway"]) + float(p["phase"])) * 8.0,
			float(p["y"]) + float(p["vy"]) * ft
		)

	func piece_positions_at(t: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pieces:
			var ft := t - float(p["spawn"])
			if ft < 0.0:
				ft = 0.0
			out.append(piece_pos(p, ft))
		return out

	func _draw() -> void:
		if elapsed < 0.0:
			return
		for p in pieces:
			var ft := elapsed - float(p["spawn"])
			if ft < 0.0:
				continue
			var pos := piece_pos(p, ft)
			if size.y > 4.0 and pos.y > size.y + piece_h:
				continue
			draw_set_transform(pos, float(p["rot"]) + float(p["spin"]) * ft, Vector2.ONE)
			draw_rect(Rect2(-piece_w * 0.5, -piece_h * 0.5, piece_w, piece_h), p["col"] as Color)
		draw_set_transform_matrix(Transform2D())
