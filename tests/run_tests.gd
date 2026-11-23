extends SceneTree

var _passed: int = 0
var _failed: int = 0

const UI_SCRIPT_PATH := "res://scripts/main_ui.gd"
const TEST_SETTINGS_PATH := "user://test_settings.cfg"
const NO_EVENTS: Array[String] = []
var _ui_queue: Array[Callable] = []

func _init() -> void:
	print("=== Founders: Barter & Block - Headless Test Suite ===")
	if not _runner_setup():
		return
	root.size = Vector2i(1400, 1100)
	var ui_script = load(UI_SCRIPT_PATH)
	ui_script.settings_path = TEST_SETTINGS_PATH
	ui_script.turn_min_seconds_override = 0.0
	_run_plain(_test_topology)
	_run_plain(_test_board_generator)
	_run_plain(_test_setup_and_distance_rule)
	_run_plain(_test_longest_route_and_splitting)
	_run_plain(_test_seven_roll_discard_and_blocker)
	_run_plain(_test_maritime_trade_and_action_cards)
	_run_plain(_test_open_trade_flow)
	_run_plain(_test_full_4bot_simulated_match)
	_run_plain(_test_main_scene_load)
	_run_plain(_test_road_work_real)
	_run_plain(_test_full_bot_match_2p_and_3p)
	_run_plain(_test_victory_hidden_charter)
	_run_plain(_test_city_upgrade)
	_run_plain(_test_blocker_steal)
	_run_plain(_test_discard_validation)
	_run_plain(_test_trade_response_guards)
	_run_plain(_test_revisable_trade_responses)
	_run_plain(_test_revisable_session_and_bots)
	_run_plain(_test_step_guard_owner_only)
	_run_plain(_test_difficulty3_stronger)
	_run_plain(_test_bank_conservation_match)
	_run_plain(_test_bank_production_rule)
	_run_plain(_test_bank_maritime_empty)
	_run_plain(_test_steal_victim_choice)
	_run_plain(_test_standings)
	_run_plain(_test_played_dev_core)
	_run_plain(_test_start_player_rotation)
	_run_plain(_test_replay_engine)
	_run_plain(_test_token_number_legibility)
	_run_plain(_test_palette_styles)
	_run_plain(_test_palette_restyle_tree)
	_start_ui_tests()

var _settle_hold: int = 0
var _ui_tests: Array[Callable] = []
var _ui_current: Node = null
var _ui_body_started: bool = false
var _ui_body_running: bool = false
var _ui_sections_before: int = 0

# One UI test at a time: build the scene, call the body on the next frame, run the
# jobs the body queued (one per frame, never during a _ui_settle), and free the
# scene as soon as the body has returned and its queue is empty.
func _process(_delta: float) -> bool:
	if _run_abort:
		return true
	if _settle_hold > 0:
		return false
	if not _ui_queue.is_empty():
		var job: Callable = _ui_queue.pop_front()
		job.call()
		return false
	if _ui_body_running:
		return false
	_end_ui_test()
	if _ui_tests.is_empty():
		_finish_suite()
		return true
	_begin_ui_test(_ui_tests.pop_front())
	return false

func _queue_ui_test(_seats: Array[SeatConfig], body: Callable) -> void:
	if _runner_wants(body, true):
		_ui_tests.append(body)

# Tests that never set a window size themselves but only pass at 1280x800, the size
# the test before them used to leave behind.
const UI_TEST_WINDOW := {
	"_test_port_tags_fit_body": Vector2i(1280, 800),
	"_test_chip_hover_banner_body": Vector2i(1280, 800),
	"_test_layout_rect_lock_body": Vector2i(1280, 800),
	"_test_discard_prompt_strip_body": Vector2i(1280, 800),
}

func _begin_ui_test(body: Callable) -> void:
	_fps_before_test = Engine.max_fps
	# Every UI test starts from the same place whatever ran before it: no settings
	# file and the headless default window, or the window it names below.
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	root.size = UI_TEST_WINDOW.get(String(body.get_method()), Vector2i(1280, 800))
	var packed := ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	_assert(packed != null, "main.tscn should load for the UI test")
	if packed == null:
		return
	var ui: Node = packed.instantiate()
	ui.auto_ai = false
	root.add_child(ui)
	_ui_current = ui
	_ui_queue.append(func() -> void:
		if not ui.is_node_ready():
			_assert(false, "UI should be ready by the first processed frame")
			return
		_ui_sections_before = _sections_done
		_ui_body_started = true
		_run_ui_body(body, ui)
	)

func _run_ui_body(body: Callable, ui: Node) -> void:
	_ui_body_running = true
	# Headless inflates every text metric while the OS window is smaller than
	# the viewport (a 64 px window reports a 14 px font as 42 px), and the
	# inflation stays cached in every control until a window-resize lands and
	# minimum sizes are recomputed. The prep gives each UI test its real
	# window; wait for that resize to land, then recompute the whole tree's
	# cached minimums so headless tests measure the same text metrics as a
	# real window.
	await _ui_settle(3)
	_style_poke_theme(ui)
	await _ui_settle(2)
	await body.call(ui)
	_ui_body_running = false

func _end_ui_test() -> void:
	if _ui_body_started:
		_assert(_sections_done > _ui_sections_before, "The last UI test body must reach _pass_section (a SCRIPT ERROR may have aborted it)")
	_ui_body_started = false
	if _ui_current != null and is_instance_valid(_ui_current):
		_ui_current.free()
	_ui_current = null
	Engine.max_fps = _fps_before_test

# Headless frames are not throttled, so a few hundred of them pass in well under a
# second. A test that watches wall-clock behaviour (pacing timers, flight durations,
# the 300 ms touch guard) calls this first to get frames as long as the game's own;
# the runner lifts the cap again when the test ends.
func _use_real_frame_rate() -> void:
	Engine.max_fps = 60

func _ui_drive_until(ui: Node, predicate: Callable, max_steps: int = 6000) -> bool:
	for _step in range(max_steps):
		var st: GameState = ui.session.state
		if st.phase == GameTypes.TurnPhase.GAME_OVER:
			return false
		if bool(predicate.call(st)):
			return true
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
			continue
		var acting: int = ui.session.get_acting_player_id()
		var act: Dictionary = BotController.choose_action(st, acting, 2)
		ui.session.submit_action(acting, act)
	return bool(predicate.call(ui.session.state))

func _ui_hand_labels_hidden(ui: Node) -> bool:
	for r in GameTypes.ALL_RESOURCES:
		var face: CardFace = ui._res_card_refs[r]
		if not bool(face.hidden_card):
			return false
	return true

func _ui_settle(frames: int) -> void:
	_settle_hold += frames
	for _i in range(frames):
		await process_frame
	_settle_hold -= frames

func _ui_real_click(ctrl: Control) -> void:
	var center := root.get_screen_transform() * (ctrl.get_global_transform() * (ctrl.size * 0.5))
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.position = center
	press_ev.global_position = center
	root.push_input(press_ev)
	var release_ev := InputEventMouseButton.new()
	release_ev.button_index = MOUSE_BUTTON_LEFT
	release_ev.pressed = false
	release_ev.position = center
	release_ev.global_position = center
	root.push_input(release_ev)

func _ui_force_bot_offer(ui: Node) -> bool:
	var bot_main := _ui_drive_until(ui, func(st: GameState) -> bool:
		if not ui.session.is_ai_to_act() or st.phase != GameTypes.TurnPhase.TURN_MAIN:
			return false
		if not st.open_trade.is_empty():
			return false
		if GameTypes.hand_total(st.players[1]["hand"]) < 1:
			return false
		var g := -1
		var w := -1
		for r in GameTypes.ALL_RESOURCES:
			if int(st.players[1]["hand"].get(r, 0)) >= 1 and g == -1:
				g = r
			elif int(st.players[0]["hand"].get(r, 0)) >= 1 and w == -1 and r != g:
				w = r
		return g != -1 and w != -1
	)
	if not bot_main:
		return false
	var give_res := -1
	var get_res := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(ui.session.state.players[1]["hand"].get(r, 0)) >= 1 and give_res == -1:
			give_res = r
		elif int(ui.session.state.players[0]["hand"].get(r, 0)) >= 1 and get_res == -1 and r != give_res:
			get_res = r
	var opened: Dictionary = ui.session.submit_action(1, GameAction.open_trade({give_res: 1}, {get_res: 1}))
	if not bool(opened.get("ok", false)):
		return false
	var guard := 0
	while ui.session.is_ai_to_act() and not ui.session.state.open_trade.is_empty() and guard < 200:
		guard += 1
		ui.session.step_ai()
	return not ui.session.state.open_trade.is_empty()

func _finish_suite() -> void:
	if _run_list:
		print("Sections listed: %d of %d" % [_run_tests_selected, _run_tests_total])
		quit(0)
		return
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	load(UI_SCRIPT_PATH).settings_path = "user://settings.cfg"
	load(UI_SCRIPT_PATH).turn_min_seconds_override = -1.0
	print("======================================================")
	_runner_print_timing()
	print("Tests Passed: %d | Tests Failed: %d" % [_passed, _failed])
	if _failed > 0:
		print("RESULT: FAILED" + _runner_filter_note())
		quit(1)
	else:
		print("RESULT: ALL TESTS PASSED" + _runner_filter_note())
		quit(0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] " + msg)

var _sections_done: int = 0

func _pass_section(title: String) -> void:
	_sections_done += 1
	var now_ms := Time.get_ticks_msec()
	var secs := float(now_ms - _section_mark_ms) / 1000.0
	_section_mark_ms = now_ms
	_section_times.append([secs, title])
	# A UI test's last check (the body reached this line) runs right after it.
	var checks := _passed + _failed - _section_checks_mark + (1 if _ui_body_started else 0)
	_section_checks_mark = _passed + _failed + (1 if _ui_body_started else 0)
	print("[PASS] %s [%.1fs, %d checks]" % [title, secs, checks])

# ---- runner: timing, subset selection, shards ----
# Arguments go after "--":  godot4 --headless --path . --script tests/run_tests.gd -- <args>
#   --list            print the section titles the other arguments select, run nothing
#   --only=95,133     run these section numbers
#   --match=<text>    run sections whose title contains the text (any case)
#   --skip-slow       leave out the tests in SLOW_TEST_SECONDS (each is printed)
#   --shard=K/N       run shard K of N (0-based); tests without a UI all go to shard 0
# With no arguments the whole suite runs. A run with any of these says so in its
# RESULT line, so it cannot be mistaken for a full run. tests/run_fast.sh runs the
# shards in parallel and merges their results.
var _section_mark_ms: int = 0
var _section_checks_mark: int = 0
var _fps_before_test: int = 0
var _section_times: Array = []
var _run_tests_total: int = 0
var _run_tests_selected: int = 0
var _run_only: Dictionary = {}
var _run_match: String = ""
var _run_skip_slow: bool = false
var _run_list: bool = false
var _run_shard: int = -1
var _run_shards: int = 0
var _run_shard_load: Array[float] = []
var _run_filtered: bool = false
var _run_abort: bool = false
var _run_sections: Dictionary = {}

# Seconds each slower test takes in a full single-process run (measured, rounded up).
# --skip-slow leaves these out; --shard uses them to balance the shards. Every test
# not listed counts as 0.2 s.
const SLOW_TEST_SECONDS := {
	"_test_layout_rect_lock_body": 4,  # 95
	"_test_steal_flight_real_body": 4,  # 96
	"_test_dead_offer_autowithdraw_body": 2,  # 97
	"_test_fresh_trade_after_no_takers_body": 2,  # 99
	"_test_clear_button_states_body": 2,  # 100
	"_test_live_trade_pacing_body": 6,  # 104
	"_test_fps_cap_body": 4,  # 110
	"_test_review_mode_body": 5,  # 113
	"_test_saved_replays_body": 7,  # 114
	"_test_rev_anim_timing_body": 2,  # 123
	"_test_count_badge_remove_body": 3,  # 126
	"_test_style_layout_lock_body": 10,  # 132
	"_test_style_leftover_scan_body": 11,  # leftover scan (no number)
	"_test_style_contrast_body": 9,  # 133
}

func _runner_setup() -> bool:
	_section_mark_ms = Time.get_ticks_msec()
	print("user data dir: " + OS.get_user_data_dir())
	_runner_scan_sections()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			for part in arg.trim_prefix("--only=").split(",", false):
				_run_only[int(part)] = true
		elif arg.begins_with("--match="):
			_run_match = arg.trim_prefix("--match=").to_lower()
		elif arg == "--skip-slow":
			_run_skip_slow = true
		elif arg == "--list":
			_run_list = true
		elif arg.begins_with("--shard="):
			var bits := arg.trim_prefix("--shard=").split("/")
			if bits.size() != 2 or int(bits[1]) < 1 or int(bits[0]) < 0 or int(bits[0]) >= int(bits[1]):
				printerr("[FAIL] bad --shard value (want K/N with 0 <= K < N): " + arg)
				_run_abort = true
				quit(2)
				return false
			_run_shard = int(bits[0])
			_run_shards = int(bits[1])
			_run_shard_load.resize(_run_shards)
			_run_shard_load.fill(0.0)
		else:
			printerr("[FAIL] unknown argument: " + arg)
			_run_abort = true
			quit(2)
			return false
	_run_filtered = not _run_only.is_empty() or _run_match != "" or _run_skip_slow or _run_shards > 0
	for wanted in _run_only:
		var known := false
		for method in _run_sections:
			if (_run_sections[method]["numbers"] as Array).has(wanted):
				known = true
		if not known:
			printerr("[FAIL] --only names section %d, which does not exist" % int(wanted))
			_run_abort = true
			quit(2)
			return false
	return true

func _runner_scan_sections() -> void:
	var text := FileAccess.get_file_as_string((get_script() as Script).resource_path)
	var current := ""
	var func_rx := RegEx.create_from_string("^func (\\w+)\\(")
	var pass_rx := RegEx.create_from_string("^\\t+_pass_section\\(\"((?:(\\d+)\\. )?[^\"]*)\"")
	for line in text.split("\n"):
		var fm := func_rx.search(line)
		if fm != null:
			current = fm.get_string(1)
			continue
		var pm := pass_rx.search(line)
		if pm != null:
			if not _run_sections.has(current):
				_run_sections[current] = {"numbers": [], "title": pm.get_string(1)}
			var nums: Array = _run_sections[current]["numbers"]
			if pm.get_string(2) != "" and not nums.has(int(pm.get_string(2))):
				nums.append(int(pm.get_string(2)))

func _runner_wants(test: Callable, is_ui: bool) -> bool:
	var method := String(test.get_method())
	var info: Dictionary = _run_sections.get(method, {"numbers": [], "title": "(no pass line) " + method})
	var numbers: Array = info["numbers"]
	var title := String(info["title"])
	_run_tests_total += 1
	var is_slow := SLOW_TEST_SECONDS.has(method)
	var weight := float(SLOW_TEST_SECONDS.get(method, 0.2))
	var shard := 0
	if _run_shards > 0 and is_ui:
		for k in range(_run_shards):
			if _run_shard_load[k] < _run_shard_load[shard]:
				shard = k
	if _run_shards > 0:
		_run_shard_load[shard] += weight
	var wanted := true
	if not _run_only.is_empty():
		wanted = false
		for n in numbers:
			if _run_only.has(n):
				wanted = true
	if _run_match != "" and not title.to_lower().contains(_run_match):
		wanted = false
	if _run_shards > 0 and shard != _run_shard:
		wanted = false
	if wanted and _run_skip_slow and is_slow:
		print("[SKIP-SLOW] %s (about %d s)" % [title, int(weight)])
		wanted = false
	if _run_list:
		if wanted:
			_run_tests_selected += 1
			print("[LIST] " + title)
		return false
	if wanted:
		_run_tests_selected += 1
	return wanted

func _run_plain(test: Callable) -> void:
	if _runner_wants(test, false):
		test.call()

func _runner_filter_note() -> String:
	if not _run_filtered:
		return ""
	return " (filtered: %d of %d sections)" % [_run_tests_selected, _run_tests_total]

func _runner_print_timing() -> void:
	var total := float(Time.get_ticks_msec()) / 1000.0
	var order := _section_times.duplicate()
	order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	print("Slowest sections:")
	for i in range(mini(10, order.size())):
		print("  [SLOW] %7.1f s  %s" % [float(order[i][0]), String(order[i][1])])
	print("Sections run: %d of %d | Total time: %.1f s" % [_run_tests_selected, _run_tests_total, total])

func _test_topology() -> void:
	var topo := HexMath.get_topology()
	_assert(topo.tile_coords.size() == 19, "Topology should have 19 tiles, got %d" % topo.tile_coords.size())
	_assert(topo.vertex_positions.size() == 54, "Topology should have 54 vertices, got %d" % topo.vertex_positions.size())
	_assert(topo.edge_vertices.size() == 72, "Topology should have 72 edges, got %d" % topo.edge_vertices.size())
	_assert(topo.coastal_edges.size() == 30, "Topology should have 30 coastal edges, got %d" % topo.coastal_edges.size())
	_pass_section("1. Topology Test (19 tiles, 54 vertices, 72 edges, 30 coastal edges)")

func _test_board_generator() -> void:
	var board: Dictionary = BoardGenerator.generate(12345, true)
	var terrains: Array = board.get("tile_terrains", [])
	var numbers: Array = board.get("tile_numbers", [])
	var blocker: int = int(board.get("blocker_tile", -1))
	var vertex_ports: Array = board.get("vertex_ports", [])

	_assert(terrains.size() == 19, "BoardGenerator should place 19 terrains")
	_assert(numbers.size() == 19, "BoardGenerator should place 19 number entries")
	_assert(blocker >= 0 and blocker < 19, "BoardGenerator blocker_tile should be valid index")
	_assert(terrains[blocker] == GameTypes.TerrainType.BARREN, "Blocker tile should be BARREN terrain")
	_assert(numbers[blocker] == 0, "Barren tile should have number 0")

	var non_zero := 0
	for i in range(numbers.size()):
		if int(numbers[i]) != 0:
			non_zero += 1
	_assert(non_zero == 18, "BoardGenerator should have 18 non-zero numbers, got %d" % non_zero)

	var red_adjacent := false
	for t1 in range(19):
		if int(numbers[t1]) != 6 and int(numbers[t1]) != 8:
			continue
		for t2 in range(t1 + 1, 19):
			if int(numbers[t2]) == 6 or int(numbers[t2]) == 8:
				if HexMath.are_tiles_adjacent(t1, t2):
					red_adjacent = true
	_assert(not red_adjacent, "Balanced board should have no adjacent 6/8 tiles")

	_assert(vertex_ports.size() == 54, "vertex_ports should have size 54")
	var port_vertices := 0
	for v in range(vertex_ports.size()):
		if int(vertex_ports[v]) != -2:
			port_vertices += 1
	_assert(port_vertices == 18, "9 coastal ports should occupy 18 port vertices, got %d" % port_vertices)
	_pass_section("2. Board Generator Test (19 terrains, 18 numbers, barren=0, no adjacent 6/8, 9 ports)")

func _test_setup_and_distance_rule() -> void:
	var topo := HexMath.get_topology()
	var state := GameState.create_new_game(42, 4, true)
	var sp: int = state.start_player

	for step_idx in range(8):
		var p: int = (sp + step_idx) % 4 if step_idx < 4 else (sp + (7 - step_idx)) % 4
		var is_second_round: bool = step_idx >= 4
		_assert(state.current_player == p, "Setup step %d expected player %d, got %d" % [step_idx, p, state.current_player])
		var expected_settle_phase := GameTypes.TurnPhase.SETUP_SETTLEMENT_2 if is_second_round else GameTypes.TurnPhase.SETUP_SETTLEMENT_1
		_assert(state.phase == expected_settle_phase, "Setup step %d phase mismatch" % step_idx)

		var valid_verts: Array[int] = RulesEngine.get_valid_settlement_vertices(state, p, true)
		_assert(not valid_verts.is_empty(), "Valid setup vertices should not be empty at step %d" % step_idx)
		var chosen_v: int = valid_verts[0]

		var res_settle: Dictionary = RulesEngine.apply_action(state, p, GameAction.place_settlement(chosen_v))
		_assert(res_settle.get("ok", false) == true, "Setup settlement placement should succeed")

		if is_second_round:
			var expected_cards := 0
			for t_id in topo.vertex_tiles[chosen_v]:
				if state.tile_terrains[t_id] != GameTypes.TerrainType.BARREN:
					expected_cards += 1
			var actual_cards := GameTypes.hand_total(state.players[p]["hand"])
			_assert(actual_cards == expected_cards and actual_cards > 0, "2nd settlement should grant %d starting resources, got %d" % [expected_cards, actual_cards])

		var valid_edges: Array[int] = RulesEngine.get_valid_road_edges(state, p, chosen_v)
		_assert(not valid_edges.is_empty(), "Valid setup road edges should not be empty")
		var res_road: Dictionary = RulesEngine.apply_action(state, p, GameAction.place_road(valid_edges[0]))
		_assert(res_road.get("ok", false) == true, "Setup road placement should succeed")

		# On step 0, test that player 1 cannot place a settlement adjacent to player 0's settlement
		if step_idx == 0:
			var adj_v: int = topo.vertex_neighbors[chosen_v][0]
			var bad_res: Dictionary = RulesEngine.apply_action(state, 1, GameAction.place_settlement(adj_v))
			_assert(bad_res.get("ok", false) == false, "Distance rule must reject settlement adjacent to existing settlement")

	_assert(state.phase == GameTypes.TurnPhase.TURN_ROLL and state.current_player == sp, "After snake draft, the start player %d gets Turn 1" % sp)
	_pass_section("3. Setup & Distance Rule Test (snake draft from the start player, distance rule, starting resources)")

func _test_longest_route_and_splitting() -> void:
	var topo := HexMath.get_topology()
	var edge_owner: Array[int] = []
	edge_owner.resize(72)
	edge_owner.fill(-1)
	var vertex_owner: Array[int] = []
	vertex_owner.resize(54)
	vertex_owner.fill(-1)

	# Take 5 consecutive edges of tile 0
	var tile0_edges: Array = topo.tile_edges[0]
	var tile0_verts: Array = topo.tile_vertices[0]
	for i in range(5):
		edge_owner[tile0_edges[i]] = 0

	var len_before := HexMath.compute_longest_route(0, edge_owner, vertex_owner)
	_assert(len_before == 5, "5 consecutive hex edges should form route of length 5, got %d" % len_before)

	# Opponent places settlement on intermediate vertex tile0_verts[2] (splitting into 2 and 3)
	vertex_owner[tile0_verts[2]] = 1
	var len_after := HexMath.compute_longest_route(0, edge_owner, vertex_owner)
	_assert(len_after == 3, "Route split by opponent settlement at vertex 2 should drop to 3, got %d" % len_after)
	_pass_section("4. Longest Route & Road Splitting Test (length 5 drops to 3 when split)")

func _test_seven_roll_discard_and_blocker() -> void:
	var state := GameState.create_new_game(99, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_ROLL
	state.current_player = 0
	state.players[1]["hand"][GameTypes.ResourceType.TIMBER] = 8 # 8 cards > 7 -> must discard 4

	# Find an RNG seed that rolls a 7 on two d6 calls
	var seed_for_7 := 1
	while true:
		var tmp := RandomNumberGenerator.new()
		tmp.seed = seed_for_7
		if tmp.randi_range(1, 6) + tmp.randi_range(1, 6) == 7:
			state.rng = RandomNumberGenerator.new()
			state.rng.seed = seed_for_7
			break
		seed_for_7 += 1

	var roll_res: Dictionary = RulesEngine.apply_action(state, 0, GameAction.roll_dice())
	_assert(roll_res.get("ok", false) == true, "Rolling dice should succeed")
	_assert(state.phase == GameTypes.TurnPhase.TURN_DISCARD, "Rolling 7 with >7 hand should enter TURN_DISCARD")
	_assert(int(state.pending_discards.get(1, 0)) == 4, "Player 1 with 8 cards should have to discard 4")

	var disc_res: Dictionary = RulesEngine.apply_action(state, 1, GameAction.discard_resources({GameTypes.ResourceType.TIMBER: 4}))
	_assert(disc_res.get("ok", false) == true, "Discarding 4 Timber should succeed")
	_assert(state.phase == GameTypes.TurnPhase.TURN_MOVE_BLOCKER, "After all discards complete, phase should be TURN_MOVE_BLOCKER")

	var new_tile: int = (state.blocker_tile + 1) % 19
	var move_res: Dictionary = RulesEngine.apply_action(state, 0, GameAction.move_blocker(new_tile, -1))
	_assert(move_res.get("ok", false) == true, "Moving blocker to new tile should succeed")
	_assert(state.blocker_tile == new_tile, "Blocker tile should update to new_tile")
	_assert(state.phase == GameTypes.TurnPhase.TURN_MAIN, "After moving blocker, phase should be TURN_MAIN")
	_pass_section("5. 7 Roll Discard & Blocker Test (TURN_DISCARD -> TURN_MOVE_BLOCKER -> TURN_MAIN)")

func _test_maritime_trade_and_action_cards() -> void:
	var state := GameState.create_new_game(777, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0

	# Default 4:1 trade ratio
	_assert(state.get_trade_ratio(0, GameTypes.ResourceType.TIMBER) == 4, "Default trade ratio should be 4:1")

	# Find a 3:1 generic port vertex and a 2:1 Timber port vertex
	var v_generic := -1
	var v_timber := -1
	for v in range(54):
		if state.vertex_ports[v] == GameTypes.PortType.GENERIC_3_TO_1 and v_generic == -1:
			v_generic = v
		elif state.vertex_ports[v] == GameTypes.PortType.TIMBER_2_TO_1 and v_timber == -1:
			v_timber = v

	_assert(v_generic != -1 and v_timber != -1, "Board should have both GENERIC_3_TO_1 and TIMBER_2_TO_1 ports")
	state.vertex_owner[v_generic] = 0
	state.vertex_building[v_generic] = GameTypes.BuildingType.SETTLEMENT
	_assert(state.get_trade_ratio(0, GameTypes.ResourceType.TIMBER) == 3, "Owning 3:1 port should give ratio 3")

	state.vertex_owner[v_timber] = 0
	state.vertex_building[v_timber] = GameTypes.BuildingType.SETTLEMENT
	_assert(state.get_trade_ratio(0, GameTypes.ResourceType.TIMBER) == 2, "Owning 2:1 Timber port should give ratio 2 for Timber")

	# Execute 2:1 maritime trade
	state.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 2
	var trade_res: Dictionary = RulesEngine.apply_action(state, 0, GameAction.maritime_trade(GameTypes.ResourceType.TIMBER, GameTypes.ResourceType.CLAY))
	_assert(trade_res.get("ok", false) == true, "2:1 maritime trade should succeed")
	_assert(state.players[0]["hand"][GameTypes.ResourceType.TIMBER] == 0 and state.players[0]["hand"][GameTypes.ResourceType.CLAY] == 1, "Maritime trade should exchange 2 Timber for 1 Clay")

	# Buy Action Card
	state.players[0]["hand"][GameTypes.ResourceType.FLEECE] = 1
	state.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 1
	state.players[0]["hand"][GameTypes.ResourceType.IRON] = 1
	var buy_res: Dictionary = RulesEngine.apply_action(state, 0, GameAction.buy_dev_card())
	_assert(buy_res.get("ok", false) == true, "Buying Action card should succeed")
	var total_devs: int = state.players[0]["dev_cards"].size() + state.players[0]["new_dev_cards"].size()
	_assert(total_devs == 1, "Player 0 should have 1 dev card after purchase")

	# Play Harvest Bounty
	state.players[0]["dev_cards"].append(GameTypes.DevCardType.HARVEST_BOUNTY)
	state.players[0]["played_dev_this_turn"] = false
	var hb_res: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_harvest_bounty(GameTypes.ResourceType.GRAIN, GameTypes.ResourceType.IRON))
	_assert(hb_res.get("ok", false) == true, "Playing Harvest Bounty should succeed")
	_assert(state.players[0]["hand"][GameTypes.ResourceType.GRAIN] == 1 and state.players[0]["hand"][GameTypes.ResourceType.IRON] == 1, "Harvest Bounty should grant 1 Grain and 1 Iron")

	# Play Trade Decree
	state.players[0]["dev_cards"].append(GameTypes.DevCardType.TRADE_DECREE)
	state.players[0]["played_dev_this_turn"] = false
	state.players[1]["hand"][GameTypes.ResourceType.FLEECE] = 3
	var td_res: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_trade_decree(GameTypes.ResourceType.FLEECE))
	_assert(td_res.get("ok", false) == true, "Playing Trade Decree should succeed")
	_assert(state.players[1]["hand"][GameTypes.ResourceType.FLEECE] == 0 and state.players[0]["hand"][GameTypes.ResourceType.FLEECE] == 3, "Trade Decree should take all Fleece from opponents")

	# Play Guard
	state.players[0]["dev_cards"].append(GameTypes.DevCardType.GUARD)
	state.players[0]["played_dev_this_turn"] = false
	var g_res: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_guard((state.blocker_tile + 1) % 19, -1))
	_assert(g_res.get("ok", false) == true, "Playing Guard should succeed")
	_assert(int(state.players[0]["played_guards"]) == 1, "Played guards count should increment to 1")
	_pass_section("6. Maritime Trade & Action Card Test (4:1/3:1/2:1 ports, buy & play dev cards)")

func _test_open_trade_flow() -> void:
	var state := GameState.create_new_game(555, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	for i in range(4):
		state.players[i]["hand"] = GameTypes.empty_hand()
	state.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 3
	state.players[0]["hand"][GameTypes.ResourceType.CLAY] = 1
	state.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2
	state.players[2]["hand"][GameTypes.ResourceType.GRAIN] = 2

	var session := LocalSession.new()
	session.state = state

	var res_open: Dictionary = RulesEngine.apply_action(state, 0, GameAction.open_trade(
		{GameTypes.ResourceType.TIMBER: 1},
		{GameTypes.ResourceType.GRAIN: 1}
	))
	_assert(bool(res_open.get("ok", false)), "Opening a table-wide trade should succeed")
	_assert(not state.open_trade.is_empty(), "open_trade should be populated after opening")
	_assert(state.open_trades_this_turn == 1, "open_trades_this_turn should increment to 1")
	_assert(int(state.open_trade.get("from", -1)) == 0, "open_trade proposer should be player 0")

	var res_other_finalize: Dictionary = RulesEngine.apply_action(state, 1, GameAction.finalize_open_trade(1))
	_assert(not bool(res_other_finalize.get("ok", false)), "Non-proposer cannot finalize the trade")
	var res_self_respond: Dictionary = RulesEngine.apply_action(state, 0, GameAction.respond_open_trade("accept"))
	_assert(not bool(res_self_respond.get("ok", false)), "Proposer cannot respond to their own offer")

	var res_end: Dictionary = RulesEngine.apply_action(state, 0, GameAction.end_turn())
	_assert(not bool(res_end.get("ok", false)), "end_turn must be rejected while a trade is open")
	_assert(str(res_end.get("error", "")) == "An open trade offer is awaiting responses.", "Open-trade rejection message should match the contract")
	var res_road: Dictionary = RulesEngine.apply_action(state, 0, GameAction.place_road(0))
	_assert(not bool(res_road.get("ok", false)), "place_road must be rejected while a trade is open")

	_assert(session.get_acting_player_id() == 1, "With all-human seats the first responder is still the lowest seat")

	var res_bad_accept: Dictionary = RulesEngine.apply_action(state, 3, GameAction.respond_open_trade("accept"))
	_assert(not bool(res_bad_accept.get("ok", false)), "Accept must fail without the requested resources")
	var responses_after_bad: Dictionary = state.open_trade["responses"]
	_assert(not responses_after_bad.has(3), "Failed accept must not record a response")

	var res_finalize_unanswered: Dictionary = RulesEngine.apply_action(state, 0, GameAction.finalize_open_trade(3))
	_assert(not bool(res_finalize_unanswered.get("ok", false)), "Finalize must fail with a non-responder")

	var res_accept_1: Dictionary = RulesEngine.apply_action(state, 1, GameAction.respond_open_trade("accept"))
	_assert(bool(res_accept_1.get("ok", false)), "Player 1 accept should succeed")
	_assert(session.get_acting_player_id() == 2, "The human wave advances to seat 2 after seat 1 responds")
	var res_accept_2: Dictionary = RulesEngine.apply_action(state, 2, GameAction.respond_open_trade("accept"))
	_assert(bool(res_accept_2.get("ok", false)), "Player 2 accept should succeed")
	var res_decline_3: Dictionary = RulesEngine.apply_action(state, 3, GameAction.respond_open_trade("decline"))
	_assert(bool(res_decline_3.get("ok", false)), "Player 3 decline should succeed")
	_assert(session.get_acting_player_id() == 0, "Acting returns to the proposer once all have responded (no AI review seats here)")

	var res_finalize_decliner: Dictionary = RulesEngine.apply_action(state, 0, GameAction.finalize_open_trade(3))
	_assert(not bool(res_finalize_decliner.get("ok", false)), "Finalize must fail with a decliner")

	var p0_timber_before: int = int(state.players[0]["hand"][GameTypes.ResourceType.TIMBER])
	var p0_grain_before: int = int(state.players[0]["hand"][GameTypes.ResourceType.GRAIN])
	var p2_timber_before: int = int(state.players[2]["hand"][GameTypes.ResourceType.TIMBER])
	var p2_grain_before: int = int(state.players[2]["hand"][GameTypes.ResourceType.GRAIN])
	var res_finalize: Dictionary = RulesEngine.apply_action(state, 0, GameAction.finalize_open_trade(2))
	_assert(bool(res_finalize.get("ok", false)), "Finalizing with an accepting partner should succeed")
	_assert(state.open_trade.is_empty(), "Finalizing should clear open_trade")
	_assert(int(state.players[0]["hand"][GameTypes.ResourceType.TIMBER]) == p0_timber_before - 1, "Proposer should give 1 Timber")
	_assert(int(state.players[0]["hand"][GameTypes.ResourceType.GRAIN]) == p0_grain_before + 1, "Proposer should receive 1 Grain")
	_assert(int(state.players[2]["hand"][GameTypes.ResourceType.TIMBER]) == p2_timber_before + 1, "Partner should receive 1 Timber")
	_assert(int(state.players[2]["hand"][GameTypes.ResourceType.GRAIN]) == p2_grain_before - 1, "Partner should give 1 Grain")
	var finalize_events: Array = res_finalize.get("events", [])
	_assert(not finalize_events.is_empty() and str(finalize_events[0]).contains("traded"), "Finalize event should contain 'traded'")

	state.players[0]["hand"] = GameTypes.empty_hand()
	state.players[1]["hand"] = GameTypes.empty_hand()
	state.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 3
	state.players[0]["hand"][GameTypes.ResourceType.CLAY] = 1
	state.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2

	var res_open_counter: Dictionary = RulesEngine.apply_action(state, 0, GameAction.open_trade(
		{GameTypes.ResourceType.TIMBER: 1},
		{GameTypes.ResourceType.GRAIN: 1}
	))
	_assert(bool(res_open_counter.get("ok", false)), "Second open trade should succeed")
	var res_counter: Dictionary = RulesEngine.apply_action(state, 1, GameAction.respond_open_trade(
		"counter",
		{GameTypes.ResourceType.TIMBER: 1, GameTypes.ResourceType.CLAY: 1},
		{GameTypes.ResourceType.GRAIN: 1}
	))
	_assert(bool(res_counter.get("ok", false)), "Counter-offer should be accepted by the rules")
	var counter_response: Dictionary = state.open_trade["responses"].get(1, {})
	_assert(str(counter_response.get("status", "")) == "counter", "Response status should be counter")

	var c_p0_timber: int = int(state.players[0]["hand"][GameTypes.ResourceType.TIMBER])
	var c_p0_clay: int = int(state.players[0]["hand"][GameTypes.ResourceType.CLAY])
	var c_p0_grain: int = int(state.players[0]["hand"][GameTypes.ResourceType.GRAIN])
	var c_p1_timber: int = int(state.players[1]["hand"][GameTypes.ResourceType.TIMBER])
	var c_p1_clay: int = int(state.players[1]["hand"][GameTypes.ResourceType.CLAY])
	var c_p1_grain: int = int(state.players[1]["hand"][GameTypes.ResourceType.GRAIN])
	var res_finalize_counter: Dictionary = RulesEngine.apply_action(state, 0, GameAction.finalize_open_trade(1))
	_assert(bool(res_finalize_counter.get("ok", false)), "Finalizing a counter-offer should succeed")
	_assert(int(state.players[0]["hand"][GameTypes.ResourceType.TIMBER]) == c_p0_timber - 1, "Counter: proposer gives 1 Timber")
	_assert(int(state.players[0]["hand"][GameTypes.ResourceType.CLAY]) == c_p0_clay - 1, "Counter: proposer gives 1 Clay")
	_assert(int(state.players[0]["hand"][GameTypes.ResourceType.GRAIN]) == c_p0_grain + 1, "Counter: proposer receives 1 Grain")
	_assert(int(state.players[1]["hand"][GameTypes.ResourceType.TIMBER]) == c_p1_timber + 1, "Counter: partner receives 1 Timber")
	_assert(int(state.players[1]["hand"][GameTypes.ResourceType.CLAY]) == c_p1_clay + 1, "Counter: partner receives 1 Clay")
	_assert(int(state.players[1]["hand"][GameTypes.ResourceType.GRAIN]) == c_p1_grain - 1, "Counter: partner gives 1 Grain")

	state.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 1
	var res_open_cancel: Dictionary = RulesEngine.apply_action(state, 0, GameAction.open_trade(
		{GameTypes.ResourceType.TIMBER: 1},
		{GameTypes.ResourceType.GRAIN: 1}
	))
	_assert(bool(res_open_cancel.get("ok", false)), "Third open trade should succeed")
	var res_nonproposer_cancel: Dictionary = RulesEngine.apply_action(state, 1, GameAction.cancel_open_trade())
	_assert(not bool(res_nonproposer_cancel.get("ok", false)), "Non-proposer cannot cancel the offer")
	var res_cancel: Dictionary = RulesEngine.apply_action(state, 0, GameAction.cancel_open_trade())
	_assert(bool(res_cancel.get("ok", false)), "Proposer cancel should succeed")
	_assert(state.open_trade.is_empty(), "Cancel should clear open_trade")
	var cancel_events: Array = res_cancel.get("events", [])
	_assert(not cancel_events.is_empty() and str(cancel_events[0]).contains("withdrew"), "Cancel event should mention withdrawal")

	state.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 1
	var res_open_cap: Dictionary = RulesEngine.apply_action(state, 0, GameAction.open_trade(
		{GameTypes.ResourceType.TIMBER: 1},
		{GameTypes.ResourceType.GRAIN: 1}
	))
	_assert(not bool(res_open_cap.get("ok", false)), "Fourth open trade in one turn must be rejected")
	_assert(str(res_open_cap.get("error", "")) == "You can post at most 3 offers per turn.", "Offer-cap message should match the contract")
	_assert(state.open_trades_this_turn == RulesEngine.MAX_OPEN_TRADES_PER_TURN, "open_trades_this_turn should stay at the cap")
	var res_end_cap: Dictionary = RulesEngine.apply_action(state, 0, GameAction.end_turn())
	_assert(bool(res_end_cap.get("ok", false)), "end_turn should succeed after the offer was cancelled")
	_assert(state.open_trades_this_turn == 0, "open_trades_this_turn should reset on end_turn")

	var diff_session := LocalSession.new()
	var seats: Array[SeatConfig] = []
	seats.append(SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Human"))
	for i in range(1, 4):
		seats.append(SeatConfig.new(i, SeatConfig.SeatType.AI_EASY, "Bot %d" % i))
	diff_session.start_match(321, seats, true, 0)
	_assert(diff_session.get_ai_difficulty() == 1, "Initial AI difficulty should be 1 (easy)")
	diff_session.set_ai_difficulty(3)
	_assert(diff_session.get_ai_difficulty() == 3, "set_ai_difficulty(3) should make AI hard")
	_assert(diff_session.seats[0].seat_type == SeatConfig.SeatType.HUMAN, "Human seat must stay human")
	for i in range(1, 4):
		_assert(diff_session.seats[i].get_difficulty() == 3, "AI seat %d should be difficulty 3" % i)

	var human_session := LocalSession.new()
	var human_seats: Array[SeatConfig] = []
	for i in range(4):
		human_seats.append(SeatConfig.new(i, SeatConfig.SeatType.HUMAN, "H %d" % i))
	human_session.start_match(654, human_seats, true, 0)
	_assert(human_session.get_ai_difficulty() == 2, "get_ai_difficulty should default to 2 when there are no AI seats")

	_pass_section("7. Open Trade Flow Test (open/respond/counter/finalize/cancel, acting order, AI difficulty)")

func _test_full_4bot_simulated_match() -> void:
	var session := LocalSession.new()
	var seats: Array[SeatConfig] = []
	for i in range(4):
		var sc := SeatConfig.new()
		sc.seat_id = i
		sc.seat_type = SeatConfig.SeatType.AI_MEDIUM
		sc.display_name = "Bot %d" % i
		seats.append(sc)

	session.start_match(2026, seats, true, 0)
	var max_steps := 10000
	var steps := 0
	var invalid_actions := 0
	while session.state.phase != GameTypes.TurnPhase.GAME_OVER and steps < max_steps and session.state.turn_number < 400:
		var res: Dictionary = session.step_ai()
		if not res.get("ok", false):
			invalid_actions += 1
			printerr("Bot invalid action at step %d: %s" % [steps, str(res)])
			break
		steps += 1

	_assert(invalid_actions == 0, "Simulated match should have 0 invalid fallback results")
	_assert(session.ai_rejected_count == 0, "Simulated match should have 0 rejected bot actions")
	_assert(session.state.phase == GameTypes.TurnPhase.GAME_OVER, "Match should reach TurnPhase.GAME_OVER (stopped at turn %d, steps %d)" % [session.state.turn_number, steps])
	_assert(session.state.turn_number < 400, "Match should finish in < 400 turns, took %d turns" % session.state.turn_number)
	var w: int = session.state.winner
	_assert(w >= 0 and w < 4, "Winner should be valid player index 0..3, got %d" % w)
	var win_vp: int = session.state.get_victory_points(w, true) if w >= 0 else 0
	_assert(win_vp >= 10, "Winner (player %d) should have >= 10 VP, got %d" % [w, win_vp])
	_assert(session.state.resource_totals_ok(), "Bank + hands must still be 19 of every resource at match end")
	_pass_section("8. Full 4-Bot Simulated Match Test (Winner=Player %d (%s) with %d VP in %d turns / %d steps)" % [w, GameTypes.PLAYER_NAMES[w] if w >= 0 else "None", win_vp, session.state.turn_number, steps])

func _test_main_scene_load() -> void:
	var packed := ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	_assert(packed != null, "res://scenes/main.tscn should load as PackedScene")
	if packed != null:
		var instance := packed.instantiate()
		_assert(instance != null, "main.tscn should instantiate cleanly")
		if instance != null:
			root.add_child(instance)
			instance.free()
			_pass_section("9. Main Scene Load Test (res://scenes/main.tscn instantiated cleanly)")

func _test_road_work_real() -> void:
	var state := GameState.create_new_game(777, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	var verts0: Array[int] = RulesEngine.get_valid_settlement_vertices(state, 0, true)
	_assert(not verts0.is_empty(), "Fresh board should offer setup settlement vertices")
	state.vertex_owner[verts0[0]] = 0
	state.vertex_building[verts0[0]] = GameTypes.BuildingType.SETTLEMENT
	state.players[0]["dev_cards"].append(GameTypes.DevCardType.ROAD_WORK)

	var play1: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_road_work())
	_assert(bool(play1.get("ok", false)), "Playing Road Work with roads and legal edges should succeed")
	_assert(state.phase == GameTypes.TurnPhase.TURN_ROAD_WORK, "Road Work should enter TURN_ROAD_WORK")
	_assert(state.road_work_remaining == 2, "Road Work should grant 2 free roads")

	var edges1: Array[int] = RulesEngine.get_valid_road_edges(state, 0, -1)
	_assert(not edges1.is_empty(), "There should be a legal free-road edge next to the settlement")
	var road1: Dictionary = RulesEngine.apply_action(state, 0, GameAction.place_road(edges1[0]))
	_assert(bool(road1.get("ok", false)), "First free road should be placeable")
	_assert(state.phase == GameTypes.TurnPhase.TURN_ROAD_WORK, "After 1 of 2 free roads still in TURN_ROAD_WORK")

	# one action card per turn: a second card is refused while the turn is busy
	state.players[0]["dev_cards"].append(GameTypes.DevCardType.HARVEST_BOUNTY)
	var second_card_now: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_harvest_bounty(GameTypes.ResourceType.GRAIN, GameTypes.ResourceType.IRON))
	_assert(not bool(second_card_now.get("ok", false)), "A second Action Card must be refused while Road Work is pending")

	# skipping the remaining free road ends the turn (rules allow end_turn here)
	var skip: Dictionary = RulesEngine.apply_action(state, 0, GameAction.end_turn())
	_assert(bool(skip.get("ok", false)), "end_turn during TURN_ROAD_WORK should be allowed")
	_assert(state.current_player == 1 and state.phase == GameTypes.TurnPhase.TURN_ROLL, "Skipping roads passes play to the next player's roll")
	_assert(state.road_work_remaining == 0, "Skipping roads zeroes road_work_remaining")

	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	state.players[0]["played_dev_this_turn"] = false

	# 1-card-per-turn rule in the main phase
	var bounty_second: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_harvest_bounty(GameTypes.ResourceType.GRAIN, GameTypes.ResourceType.IRON))
	_assert(bool(bounty_second.get("ok", false)), "First Action Card in the main phase should succeed")
	var bounty_again: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_harvest_bounty(GameTypes.ResourceType.GRAIN, GameTypes.ResourceType.IRON))
	_assert(not bool(bounty_again.get("ok", false)), "A second Action Card in one turn must be refused")
	state.players[0]["played_dev_this_turn"] = false
	state.players[0]["new_dev_cards"].clear()
	state.players[0]["dev_cards"].clear()
	state.players[0]["dev_cards"].append(GameTypes.DevCardType.ROAD_WORK)

	# no road pieces left: fail with the card kept
	state.players[0]["roads_left"] = 0
	var play0: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_road_work())
	_assert(not bool(play0.get("ok", false)), "Road Work with no road pieces must fail")
	_assert(str(play0.get("error", "")) == "No road can be placed.", "Road Work failure message should match the contract")
	_assert(state.players[0]["dev_cards"].count(GameTypes.DevCardType.ROAD_WORK) == 1, "Failed Road Work must not consume the card")
	_assert(not bool(state.players[0]["played_dev_this_turn"]), "Failed Road Work must not mark a card as played")

	# no legal edge: strip the player's board presence, restore pieces
	state.players[0]["roads_left"] = 15
	for v in range(state.vertex_owner.size()):
		if state.vertex_owner[v] == 0:
			state.vertex_owner[v] = -1
			state.vertex_building[v] = GameTypes.BuildingType.NONE
	for e in range(state.edge_owner.size()):
		if state.edge_owner[e] == 0:
			state.edge_owner[e] = -1
	var chk_edge: Dictionary = RulesEngine.can_play_dev_card(state, 0, GameTypes.DevCardType.ROAD_WORK)
	_assert(not bool(chk_edge["ok"]) and str(chk_edge["reason"]) == "No road can be placed.", "can_play_dev_card should block Road Work without a legal edge")
	var play_noedge: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_road_work())
	_assert(not bool(play_noedge.get("ok", false)), "Road Work without a legal edge must fail")
	_assert(state.players[0]["dev_cards"].count(GameTypes.DevCardType.ROAD_WORK) == 1, "Failed Road Work (no edge) must not consume the card")

	# bought this turn: not playable
	state.players[0]["dev_cards"].clear()
	state.players[0]["new_dev_cards"].append(GameTypes.DevCardType.ROAD_WORK)
	var chk_bought: Dictionary = RulesEngine.can_play_dev_card(state, 0, GameTypes.DevCardType.ROAD_WORK)
	_assert(not bool(chk_bought["ok"]) and str(chk_bought["reason"]) == "Bought this turn \u2014 playable next turn", "A card bought this turn is not playable yet")
	var play_bought: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_road_work())
	_assert(not bool(play_bought.get("ok", false)), "Playing a card bought this turn must fail")
	_pass_section("10. Road Work Real Test (play + free roads + skip; fails keep the card; bought-this-turn blocked; one card per turn)")

func _test_full_bot_match_2p_and_3p() -> void:
	for n in [2, 3]:
		var session := LocalSession.new()
		var seats: Array[SeatConfig] = []
		for i in range(n):
			var sc := SeatConfig.new()
			sc.seat_id = i
			sc.seat_type = SeatConfig.SeatType.AI_MEDIUM
			sc.display_name = "Bot %d-%d" % [n, i]
			seats.append(sc)
		session.start_match(2026 + n, seats, true)
		var steps := 0
		var invalid_actions := 0
		while session.state.phase != GameTypes.TurnPhase.GAME_OVER and steps < 10000:
			var res: Dictionary = session.step_ai()
			if not bool(res.get("ok", false)):
				invalid_actions += 1
				printerr("Bot invalid action in %d-player match at step %d: %s" % [n, steps, str(res)])
				break
			steps += 1
		_assert(invalid_actions == 0, "%d-player bot match should have 0 invalid fallback results" % n)
		_assert(session.ai_rejected_count == 0, "%d-player bot match should have 0 rejected bot actions" % n)
		_assert(session.state.phase == GameTypes.TurnPhase.GAME_OVER, "%d-player bot match should reach GAME_OVER (turn %d, steps %d)" % [n, session.state.turn_number, steps])
		var w: int = session.state.winner
		_assert(w >= 0 and w < n, "%d-player bot match winner should be a valid seat, got %d" % [n, w])
		_assert(session.state.resource_totals_ok(), "%d-player bot match must keep every resource conserved at match end" % n)
	_pass_section("11. Two- and Three-Player Full Bot Match Tests (both reach GAME_OVER with 0 invalid actions)")

func _start_ui_tests() -> void:
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_trade_card_sizes_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_sidebar_no_vscroll_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_counter_count_badges_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_subpanel_close_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_rev_anim_timing_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_subpanel_geometry_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_handbar_close_clicks_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_panel_extras_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Coral"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ember"),
	], _test_hotseat_trade_ui_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Coral"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_hotseat_privacy_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_dev_card_chips_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_bounty_panel_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_space_after_mouse_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_trade_tray_close_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Coral"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_game_over_banner_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_roll_fx_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_discard_picker_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_steal_chooser_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_steal_toasts_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_steal_toasts_hotseat_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_offer_strip_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_tray_close_controls_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_costs_popover_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_game_over_splash_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_discard_layout_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_stale_discard_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_splash_winner_order_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_card_face_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_bank_stacks_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_port_badges_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_action_anim_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_toast_tween_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_port_geom_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_blocker_phases_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_steal_hold_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_steal_hold_reduce_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_steal_hold_newgame_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Ivory"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Dune"),
	], _test_steal_flight_hotseat_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_steal_supersede_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_steal_flyer_cancel_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_steal_hold_deadline_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_bank_pile_counts_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_card_click_trade_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_trade_close_cross_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_card_redraw_setters_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_flights_production_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_flights_build_trade_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_flight_layer_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_tray_bar_fit_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_counter_offer_card_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_dice_roll_show_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_badge_bounds_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_stepper_labels_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_token_layout_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_board_styles_ui_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_style_defaults_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_sfx_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_HARD, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ivory"),
	], _test_scoreboard_columns_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_action_card_help_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_small_buttons_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_port_tags_fit_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Amber"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_side_trade_panel_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_pacing_focus_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_flight_targets_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
	], _test_blocker_piece_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
	], _test_ghibli_emblems_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_trade_respond_close_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_counter_edit_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_offer_cap_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_decline_dead_end_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_badge_geometry_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_chip_hover_banner_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_collapsed_log_height_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_cursor_shapes_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_action_flights_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ivory"),
	], _test_row_size_and_scroll_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_board_frame_removed_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ivory"),
	], _test_layout_rect_lock_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ivory"),
	], _test_steal_flight_real_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_dead_offer_autowithdraw_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_pending_offer_action_cancel_first_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_fresh_trade_after_no_takers_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_clear_button_states_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_watch_other_trades_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Crimson"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_scoreboard_focus_overlay_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Crimson"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_discard_prompt_strip_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_live_trade_pacing_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Crimson"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	], _test_scoreboard_row_gap_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_toast_layout_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_blocker_rehex_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_fps_cap_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_log_cap_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_review_mode_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_saved_replays_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_steal_onboard_body)

	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_live_revision_ui_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_count_badge_remove_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_ui_style_setting_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_board_style_rebake_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_style_switcher_button_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_style_layout_lock_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_style_leftover_scan_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_style_contrast_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_toast_tint_remap_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_award_glyph_highlight_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_log_stays_placed_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	], _test_badge_over_art_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_fine_line_chrome_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_island_top_bar_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_audit_contrast_batch_a_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_art_batch_b_body)
	_queue_ui_test([
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	], _test_controls_batch_c_body)

func _test_live_revision_ui_body(ui: Node) -> void:
	var s = ui.session
	ui.auto_ai = false
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(31337, seats, true, 0)
	s = ui.session
	s.state.phase = GameTypes.TurnPhase.TURN_MAIN
	s.state.current_player = 1
	s.state.open_trades_this_turn = 0
	for pid in range(4):
		for r in GameTypes.ALL_RESOURCES:
			s.state.players[pid]["hand"][r] = 5
	s.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	await _ui_settle(2)
	_assert(s.get_acting_player_id() == 2, "Bots get the first chance to answer (new rule)")
	s.submit_action(2, GameAction.respond_open_trade("decline"))
	s.submit_action(3, GameAction.respond_open_trade("decline"))
	await _ui_settle(2)
	_assert(s.get_acting_player_id() == 0, "The human answers last (new rule)")
	ui._set_tray_panel_visible(true)
	await _ui_settle(2)
	_assert(bool(ui._trade_respond_view.visible), "The respond view is shown to the human")
	var declined := 0
	for lbl in ui._watch_rows_col.find_children("*", "Label", true, false):
		if str((lbl as Label).text) == "Declined":
			declined += 1
	_assert(declined == 2, "The panel shows both bot answers while the human decides, got %d" % declined)
	_assert(ui._sb_focus_card != null and ui._sb_focus_card == ui._scoreboard_row_parts[1]["card"], "The focus ring marks the turn owner while others answer")
	_ui_real_click(ui._ot_decline_btn)
	await _ui_settle(2)
	_assert(bool(ui._trade_respond_view.visible), "Answered controls stay available for the human to revise")
	_assert(s.get_acting_player_id() == 2, "Bot review passes run before the proposer")
	s.submit_action(2, GameAction.respond_open_trade("accept"))  # a bot revision
	await _ui_settle(2)
	var accepted := false
	for lbl2 in ui._watch_rows_col.find_children("*", "Label", true, false):
		if str((lbl2 as Label).text).contains("Accepted"):
			accepted = true
	_assert(accepted, "The revised accept shows in the answer rail")
	var saw_revise := false
	for ln in ui._log_lines:
		if str(ln).contains("revises: accepts"):
			saw_revise = true
	_assert(saw_revise, "The log carries the revision wording")
	while s.is_ai_to_act():
		s.step_ai()
	s.state.phase = GameTypes.TurnPhase.TURN_MAIN
	s.state.current_player = 0
	s.state.open_trades_this_turn = 0
	ui._refresh_ui()
	_assert(ui._sb_focus_card != null and ui._sb_focus_card == ui._scoreboard_row_parts[0]["card"], "The focus ring follows the turn owner back to the human")
	_pass_section("118. Live Revision UI Test (bot-first answers, live panel, revision rail, focus ring)")
func _test_hotseat_trade_ui_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Coral"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ember"),
	]
	var reached := false
	var used_seed := 0
	for candidate_seed in [424242, 777, 1234, 555, 9090]:
		ui.session.start_match(candidate_seed, seats, true, 0)
		var steps := 0
		while steps < 6000:
			steps += 1
			var st: GameState = ui.session.state
			if st.phase == GameTypes.TurnPhase.GAME_OVER:
				break
			if ui.session.is_ai_to_act():
				ui.session.step_ai()
				continue
			var acting: int = ui.session.get_acting_player_id()
			if (
				st.phase == GameTypes.TurnPhase.TURN_MAIN
				and acting == 1
				and st.open_trade.is_empty()
				and GameTypes.hand_total(st.players[1]["hand"]) >= 1
			):
				reached = true
				used_seed = candidate_seed
				break
			var act: Dictionary = BotController.choose_action(st, acting, 2)
			ui.session.submit_action(acting, act)
		if reached:
			break
	_assert(reached, "Hot-seat match should reach seat 1 TURN_MAIN holding at least one card")
	if not reached:
		ui.free()
		return
	var st: GameState = ui.session.state
	_assert(ui.session.get_acting_player_id() == 1, "Seat 1 (the second human) should be the acting player")
	_assert(bool(ui._hand_hidden()), "Hot-seat hand must be hidden before the device-pass confirmation")
	_assert(bool(ui._device_pass_cover.visible), "Device-pass cover should be visible for the new viewer")
	_assert(str(ui._device_pass_btn.text).contains("Coral"), "Cover button should name the incoming viewer")
	ui._device_pass_btn.pressed.emit()
	_assert(not bool(ui._hand_hidden()), "Pressing the cover button should reveal the acting human's hand")
	for r in GameTypes.ALL_RESOURCES:
		var face: CardFace = ui._res_card_refs[r]
		_assert(not bool(face.hidden_card) and int(face.count) == int(st.players[1]["hand"].get(r, 0)), "Hand bar should show seat 1's count for resource %d" % r)
	_assert(bool(ui._hand_view_name.visible) and str(ui._hand_view_name.text) == "Coral", "Hand bar view label should show the viewed seat's name")
	_assert(str(ui._status_banner_label.text).begins_with("Coral"), "Banner should start with the viewed seat's name")
	var give_res := -1
	var get_res := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(st.players[1]["hand"].get(r, 0)) >= 1:
			give_res = r
			break
	for r in GameTypes.ALL_RESOURCES:
		if r != give_res:
			get_res = r
			break
	var res_open: Dictionary = ui.session.submit_action(1, GameAction.open_trade({give_res: 1}, {get_res: 1}))
	_assert(bool(res_open.get("ok", false)), "Seat 1 should be able to open an offer")
	while ui.session.is_ai_to_act():
		ui.session.step_ai()  # new rule: the bots answer before the humans
	var res_decline: Dictionary = ui.session.submit_action(0, GameAction.respond_open_trade("decline"))
	_assert(bool(res_decline.get("ok", false)), "Seat 0 should be able to decline seat 1's offer")
	while not ui.session.state.open_trade.is_empty() and ui.session.is_ai_to_act():
		ui.session.step_ai()
	_assert(int(ui.session.state.open_trade.get("from", -1)) == 1, "The offer should still belong to seat 1")
	_assert(ui.session.get_acting_player_id() == 1, "Control should return to seat 1 once everyone has answered")
	_assert(bool(ui._hand_hidden()), "Seat 1 must confirm the device again after the bot turns")
	ui._device_pass_btn.pressed.emit()
	_assert(bool(ui._trade_tray.is_visible_in_tree()), "Tray should have auto-opened for seat 1 without the test opening it")
	_assert(str(ui._trade_title_lbl.text).begins_with("Your offer:"), "Seat 1 should see their own offer in the panel title")
	ui._close_trade_tray_by_user()
	_assert(ui.session.state.open_trade.is_empty(), "Closing your own offer withdraws the open trade")
	_assert(not bool(ui._trade_tray.visible), "The tray closes with the withdrawal")
	_pass_section("12. Hot-seat Trade UI Test (seed %d: seat 1 offer, answers, withdraw via UI)" % used_seed)

func _test_hotseat_privacy_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Coral"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	var hidden_ok := false
	var reveal_ok := false
	var bot_turn_ok := false
	var back_ok := false
	for attempt in range(3):
		ui.session.start_match(202500 + attempt * 101, seats, true, 0)
		# human acting, nobody confirmed yet
		if not bool(ui._hand_hidden()):
			continue
		if not bool(ui._device_pass_cover.visible):
			continue
		if str(ui._hand_view_name.text) != "Hand hidden":
			continue
		if not _ui_hand_labels_hidden(ui):
			continue
		hidden_ok = true
		# confirm the device, the acting human's own counts appear
		ui._device_pass_btn.pressed.emit()
		var acting: int = ui.session.get_acting_player_id()
		if bool(ui._hand_hidden()):
			continue
		var all_match := true
		for r in GameTypes.ALL_RESOURCES:
			var face: CardFace = ui._res_card_refs[r]
			if bool(face.hidden_card) or int(face.count) != int(ui.session.state.players[acting]["hand"].get(r, 0)):
				all_match = false
		reveal_ok = all_match
		# advance until the bot is acting: everything hides again
		var reached_bot := _ui_drive_until(ui, func(st: GameState) -> bool:
			return ui.session.is_ai_to_act() and st.phase != GameTypes.TurnPhase.GAME_OVER
		)
		if not reached_bot:
			continue
		if not bool(ui._hand_hidden()) or not _ui_hand_labels_hidden(ui):
			continue
		if bool(ui._device_pass_cover.visible) == false or bool(ui._trade_tray.visible):
			continue
		if bool(ui._device_pass_btn.visible):
			continue
		if not str(ui._device_pass_label.text).contains("hands hidden"):
			continue
		# a human counts > 0 must never leak into a label during the bot's turn
		var leak := false
		for p_id in range(2):
			for r in GameTypes.ALL_RESOURCES:
				var cnt := int(ui.session.state.players[p_id]["hand"].get(r, 0))
				if cnt > 0:
					var face: CardFace = ui._res_card_refs[r]
					if not bool(face.hidden_card) and int(face.count) == cnt:
						leak = true
		if leak:
			continue
		bot_turn_ok = true
		# when play returns to a human, the cover is up again until confirmed
		var reached_human := _ui_drive_until(ui, func(st: GameState) -> bool:
			return not ui.session.is_ai_to_act() and st.phase != GameTypes.TurnPhase.GAME_OVER
		)
		if not reached_human:
			continue
		if not bool(ui._hand_hidden()) or not bool(ui._device_pass_cover.visible):
			continue
		if not bool(ui._device_pass_btn.visible):
			continue
		ui._device_pass_btn.pressed.emit()
		var acting2: int = ui.session.get_acting_player_id()
		var ok2 := true
		for r in GameTypes.ALL_RESOURCES:
			var face2: CardFace = ui._res_card_refs[r]
			if bool(face2.hidden_card) or int(face2.count) != int(ui.session.state.players[acting2]["hand"].get(r, 0)):
				ok2 = false
		back_ok = ok2
		break
	_assert(hidden_ok, "2-human game: hand hidden while unconfirmed (cover up, 'Hand hidden', no counts)")
	_assert(reveal_ok, "After the device-pass button, the acting human sees their own counts")
	_assert(bot_turn_ok, "While a bot acts, the hand is hidden again and no human count appears")
	_assert(back_ok, "On return to a human, cover shows again and the button reveals the right counts")
	# FIX 1: bots answering a human's own offer must NOT re-hide that human's hand
	var fix1_ok := false
	var four: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Ember"),
		SeatConfig.new(3, SeatConfig.SeatType.HUMAN, "Coral"),
	]
	for attempt in range(6):
		ui.session.start_match(202900 + attempt * 137, four, true, 0)
		var human_main := _ui_drive_until(ui, func(st: GameState) -> bool:
			return not ui.session.is_ai_to_act() and ui.session.get_acting_player_id() == 0 and st.phase == GameTypes.TurnPhase.TURN_MAIN and GameTypes.hand_total(st.players[0]["hand"]) >= 1 and not st.open_trade.is_empty() == true or (not ui.session.is_ai_to_act() and ui.session.get_acting_player_id() == 0 and st.phase == GameTypes.TurnPhase.TURN_MAIN and GameTypes.hand_total(st.players[0]["hand"]) >= 1)
		)
		if not human_main:
			continue
		ui._device_pass_btn.pressed.emit()
		if bool(ui._hand_hidden()):
			continue
		var give_r := -1
		var get_r := -1
		for r in GameTypes.ALL_RESOURCES:
			if int(ui.session.state.players[0]["hand"].get(r, 0)) >= 1 and give_r == -1:
				give_r = r
		for r in GameTypes.ALL_RESOURCES:
			if r != give_r:
				for p_id in range(1, 4):
					if int(ui.session.state.players[p_id]["hand"].get(r, 0)) >= 1 and get_r == -1:
						get_r = r
		if give_r == -1:
			continue
		if get_r == -1:
			get_r = (give_r + 1) % GameTypes.ALL_RESOURCES.size()
		ui.session.submit_action(0, GameAction.open_trade({give_r: 1}, {get_r: 1}))
		if ui.session.state.open_trade.is_empty() or int(ui.session.state.open_trade.get("from", -1)) != 0:
			continue
		# bot seat 1 answers -> acting becomes bot seat 2: A's reveal must survive
		ui.session.step_ai()
		var ot1: Dictionary = ui.session.state.open_trade
		if ot1.is_empty() or int(ot1.get("from", -1)) != 0:
			continue
		if ui.session.get_acting_player_id() != 2 or bool(ui._hand_hidden()) or int(ui._revealed_pid) != 0:
			continue
		# bot seat 2 answers -> acting becomes human seat 3: cover up for B
		ui.session.step_ai()
		var ot2: Dictionary = ui.session.state.open_trade
		if ot2.is_empty() or int(ot2.get("from", -1)) != 0:
			continue
		if ui.session.get_acting_player_id() != 3 or not bool(ui._hand_hidden()) or not bool(ui._device_pass_cover.visible):
			continue
		ui._device_pass_btn.pressed.emit()
		if bool(ui._hand_hidden()) or int(ui._revealed_pid) != 3:
			continue
		fix1_ok = true
		break
	_assert(fix1_ok, "Reveal survives bot answers to the poster's own offer; cover re-appears for the next human responder")
	# FIX 2: Space on the focused cover button reveals instead of rolling; the next Space rolls
	var fix2_seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Coral"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Ember"),
	]
	ui.session.start_match(203333, fix2_seats, true, 0)
	var roll_phase := _ui_drive_until(ui, func(st: GameState) -> bool:
		return st.phase == GameTypes.TurnPhase.TURN_ROLL and not ui.session.is_ai_to_act() and ui.session.get_acting_player_id() == 0
	)
	_assert(roll_phase, "Should reach seat 0's roll phase")
	_assert(bool(ui._hand_hidden()) and bool(ui._device_pass_cover.visible), "Cover must be up at the roll phase start")
	await ui.get_tree().process_frame
	ui._device_pass_btn.grab_focus()
	var sp_on := InputEventKey.new()
	sp_on.keycode = KEY_SPACE
	sp_on.pressed = true
	root.push_input(sp_on)
	var sp_off := InputEventKey.new()
	sp_off.keycode = KEY_SPACE
	sp_off.pressed = false
	root.push_input(sp_off)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(not bool(ui._device_pass_cover.visible), "Space on the focused cover button must reveal the hand")
	_assert(ui.session.state.phase == GameTypes.TurnPhase.TURN_ROLL, "The revealing Space must not also roll the dice")
	var sp2_on := InputEventKey.new()
	sp2_on.keycode = KEY_SPACE
	sp2_on.pressed = true
	root.push_input(sp2_on)
	var sp2_off := InputEventKey.new()
	sp2_off.keycode = KEY_SPACE
	sp2_off.pressed = false
	root.push_input(sp2_off)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(ui.session.state.phase != GameTypes.TurnPhase.TURN_ROLL, "The second Space must roll the dice")
	# 1-human game: nothing is ever covered
	var solo: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(31337, solo, true, 0)
	_assert(not bool(ui._hand_hidden()), "Single-human game never hides the hand")
	_assert(not bool(ui._device_pass_cover.visible), "Single-human game shows no device-pass cover")
	_ui_drive_until(ui, func(st: GameState) -> bool:
		return ui.session.is_ai_to_act()
	)
	_assert(not bool(ui._hand_hidden()), "Single-human hand stays visible during the bot's turn")
	_assert(not bool(ui._device_pass_cover.visible), "Single-human cover stays hidden during the bot's turn")
	_pass_section("19. Hot-seat Privacy Test (cover hides hands between humans; single human unaffected)")

func _test_victory_hidden_charter() -> void:
	var state := GameState.create_new_game(901, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	for v in range(9):
		state.vertex_owner[v] = 0
		state.vertex_building[v] = GameTypes.BuildingType.SETTLEMENT
	_assert(state.get_victory_points(0, false) == 9, "Nine settlements should be 9 public VP")
	# hidden Charter makes it 10, but only counted on the holder's own turn
	state.players[0]["new_dev_cards"].append(GameTypes.DevCardType.CHARTER_POINT)
	_assert(state.get_victory_points(0, false) == 9, "Charter VP must stay hidden in public VP")
	_assert(state.get_victory_points(0, true) == 10, "Hidden total should count the Charter")
	state.current_player = 1
	var other_turn: Dictionary = RulesEngine.apply_action(state, 1, GameAction.end_turn())
	_assert(bool(other_turn.get("ok", false)), "Another player's end_turn should succeed")
	_assert(state.phase != GameTypes.TurnPhase.GAME_OVER, "Victory must not trigger on another player's turn")
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	var own_end: Dictionary = RulesEngine.apply_action(state, 0, GameAction.end_turn())
	_assert(bool(own_end.get("ok", false)), "Own end_turn should succeed")
	_assert(state.phase == GameTypes.TurnPhase.GAME_OVER and state.winner == 0, "Reaching 10 with hidden Charter on your own turn wins")
	_pass_section("13. Victory & Hidden Charter Test (10th hidden VP wins only on the holder's own turn)")

func _test_city_upgrade() -> void:
	var state := GameState.create_new_game(778, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	var verts: Array[int] = RulesEngine.get_valid_settlement_vertices(state, 0, true)
	state.vertex_owner[verts[0]] = 0
	state.vertex_building[verts[0]] = GameTypes.BuildingType.SETTLEMENT
	var cities_before: int = int(state.players[0]["cities_left"])
	var settle_before: int = int(state.players[0]["settlements_left"])
	# cost check: one Iron short must fail
	state.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 2
	state.players[0]["hand"][GameTypes.ResourceType.IRON] = 2
	var bad: Dictionary = RulesEngine.apply_action(state, 0, GameAction.upgrade_city(verts[0]))
	_assert(not bool(bad.get("ok", false)), "City upgrade without 3 Iron must fail")
	state.players[0]["hand"][GameTypes.ResourceType.IRON] = 3
	var up: Dictionary = RulesEngine.apply_action(state, 0, GameAction.upgrade_city(verts[0]))
	_assert(bool(up.get("ok", false)), "City upgrade with 2 Grain + 3 Iron should succeed")
	_assert(state.vertex_building[verts[0]] == GameTypes.BuildingType.CITY, "Vertex should now be a City")
	_assert(int(state.players[0]["cities_left"]) == cities_before - 1, "City stock should drop by 1")
	_assert(int(state.players[0]["settlements_left"]) == settle_before + 1, "Upgrading returns the settlement piece")
	_assert(int(state.players[0]["hand"][GameTypes.ResourceType.GRAIN]) == 0 and int(state.players[0]["hand"][GameTypes.ResourceType.IRON]) == 0, "City cost 2 Grain + 3 Iron must be deducted")
	_assert(state.get_victory_points(0, false) == 2, "A City is worth 2 public VP")
	_pass_section("14. City Upgrade Test (cost, piece counts, VP)")

func _test_blocker_steal() -> void:
	var state := GameState.create_new_game(779, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	state.current_player = 0
	var topo := HexMath.get_topology()
	var t := -1
	for cand in range(19):
		if cand == state.blocker_tile:
			continue
		if GameTypes.terrain_to_resource(state.tile_terrains[cand]) >= 0 and topo.tile_vertices[cand].size() >= 2:
			t = cand
			break
	_assert(t != -1, "There should be a resource tile with at least 2 vertices")
	var vs: Array = topo.tile_vertices[t]
	state.vertex_owner[vs[0]] = 1
	state.vertex_building[vs[0]] = GameTypes.BuildingType.SETTLEMENT
	state.vertex_owner[vs[1]] = 2
	state.vertex_building[vs[1]] = GameTypes.BuildingType.SETTLEMENT
	state.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2
	# player 2 has no cards; player 0 (roller) starts empty
	var mv: Dictionary = RulesEngine.apply_action(state, 0, GameAction.move_blocker(t, -1))
	_assert(bool(mv.get("ok", false)), "Blocker move should succeed")
	_assert(state.blocker_tile == t, "Blocker should sit on the chosen tile")
	_assert(GameTypes.hand_total(state.players[1]["hand"]) == 1, "The victim should lose exactly one card")
	_assert(GameTypes.hand_total(state.players[0]["hand"]) == 1, "The roller should gain exactly one card")
	_assert(GameTypes.hand_total(state.players[2]["hand"]) == 0, "A player with no cards is never robbed")
	_assert(state.phase == GameTypes.TurnPhase.TURN_MAIN, "After moving the Blocker the main turn begins")
	_pass_section("15. Blocker Steal Test (exactly one card, never from an empty hand)")

func _test_discard_validation() -> void:
	var state := GameState.create_new_game(780, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_DISCARD
	state.pending_discards[0] = 3
	state.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 5
	state.players[0]["hand"][GameTypes.ResourceType.CLAY] = 1
	var wrong: Dictionary = RulesEngine.apply_action(state, 0, GameAction.discard_resources({GameTypes.ResourceType.TIMBER: 2}))
	_assert(not bool(wrong.get("ok", false)), "Discarding fewer than required must be rejected")
	_assert(GameTypes.hand_total(state.players[0]["hand"]) == 6, "Rejected discard must not change the hand")
	var exact: Dictionary = RulesEngine.apply_action(state, 0, GameAction.discard_resources({
		GameTypes.ResourceType.TIMBER: 2,
		GameTypes.ResourceType.CLAY: 1,
	}))
	_assert(bool(exact.get("ok", false)), "Discarding the exact count must be accepted")
	_assert(GameTypes.hand_total(state.players[0]["hand"]) == 3, "Exact discard should remove exactly the required cards")
	_assert(state.pending_discards.is_empty() and state.phase == GameTypes.TurnPhase.TURN_MOVE_BLOCKER, "After all discards the blocker phase begins")
	_pass_section("16. Discard Validation Test (wrong count rejected, exact count accepted)")

func _test_trade_response_guards() -> void:
	var state := GameState.create_new_game(781, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	state.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 1
	state.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 1
	var open_res: Dictionary = RulesEngine.apply_action(state, 0, GameAction.open_trade(
		{GameTypes.ResourceType.TIMBER: 1},
		{GameTypes.ResourceType.GRAIN: 1}
	))
	_assert(bool(open_res.get("ok", false)), "Opening the offer should succeed")
	var acc: Dictionary = RulesEngine.apply_action(state, 1, GameAction.respond_open_trade("accept"))
	_assert(bool(acc.get("ok", false)), "Player 1 accept should succeed")
	var acc_again: Dictionary = RulesEngine.apply_action(state, 1, GameAction.respond_open_trade("decline"))
	_assert(bool(acc_again.get("ok", false)), "A second response replaces the first (revision)")
	var rev_events: Array = acc_again.get("events", [])
	_assert(not rev_events.is_empty() and str(rev_events[0]) == "Azure revises: declines.", "Revision event wording, got '%s'" % (str(rev_events[0]) if not rev_events.is_empty() else ""))
	var rev_dict: Dictionary = state.open_trade.get("revisions", {})
	_assert(int(rev_dict.get(1, 0)) == 1, "The revision counter should record one change")
	var bad_counter: Dictionary = RulesEngine.apply_action(state, 2, GameAction.respond_open_trade(
		"counter",
		{GameTypes.ResourceType.TIMBER: 1},
		{GameTypes.ResourceType.GRAIN: 1}
	))
	_assert(not bool(bad_counter.get("ok", false)), "A counter the responder cannot pay must be rejected")
	var dec: Dictionary = RulesEngine.apply_action(state, 2, GameAction.respond_open_trade("decline"))
	_assert(bool(dec.get("ok", false)), "Player 2 decline should succeed after a rejected counter")
	_pass_section("17. Trade Response Guards Test (double response and unpayable counters rejected)")

func _test_revisable_trade_responses() -> void:
	var R: Dictionary = {
		"TIMBER": GameTypes.ResourceType.TIMBER,
		"GRAIN": GameTypes.ResourceType.GRAIN,
		"CLAY": GameTypes.ResourceType.CLAY,
	}
	# --- engine: revision limit, wording, proposer guard, review record --------
	var state := GameState.create_new_game(831, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	state.players[0]["hand"][R["TIMBER"]] = 2
	state.players[1]["hand"][R["GRAIN"]] = 9
	state.players[3]["hand"][R["GRAIN"]] = 3
	var ores: Dictionary = RulesEngine.apply_action(state, 0, GameAction.open_trade(
		{R["TIMBER"]: 1}, {R["GRAIN"]: 1}
	))
	_assert(bool(ores.get("ok", false)), "Revise test offer opens")
	var d1: Dictionary = RulesEngine.apply_action(state, 1, GameAction.respond_open_trade("decline"))
	_assert(bool(d1.get("ok", false)), "First response accepted")
	var d1e: Array = d1.get("events", [])
	_assert(not d1e.is_empty() and not str(d1e[0]).contains("revises"), "First response must not use the revise wording")
	for k in range(3):
		var act := GameAction.respond_open_trade("accept")
		var rep: Dictionary = RulesEngine.apply_action(state, 1, act)
		_assert(bool(rep.get("ok", false)), "Revision %d should be accepted" % (k + 1))
		var rv_ev: Array = rep.get("events", [])
		_assert(not rv_ev.is_empty() and str(rv_ev[0]).contains("revises:"), "Revision %d uses the revises wording" % (k + 1))
	var over: Dictionary = RulesEngine.apply_action(state, 1, GameAction.respond_open_trade("accept"))
	_assert(not bool(over.get("ok", false)), "A fourth change must be rejected")
	_assert(str(over.get("error", "")) == "You have used all 3 changes for this offer.", "Revision limit message, got '%s'" % str(over.get("error", "")))
	var rev_n: Dictionary = state.open_trade.get("revisions", {})
	_assert(int(rev_n.get(1, 0)) == 3, "Revision counter reaches exactly 3")
	var self_resp: Dictionary = RulesEngine.apply_action(state, 0, GameAction.respond_open_trade("accept"))
	_assert(not bool(self_resp.get("ok", false)), "The proposer cannot answer their own offer")
	var early_review: Dictionary = RulesEngine.apply_action(state, 2, GameAction.review_open_trade())
	_assert(not bool(early_review.get("ok", false)), "A non-responder cannot review")
	var p2decl: Dictionary = RulesEngine.apply_action(state, 2, GameAction.respond_open_trade("decline"))
	_assert(bool(p2decl.get("ok", false)), "Player 2 declines")
	var p2rev: Dictionary = RulesEngine.apply_action(state, 2, GameAction.review_open_trade())
	_assert(bool(p2rev.get("ok", false)), "An answerer may review")
	var total_ticks: int = RulesEngine._trade_resp_total(state.open_trade)
	_assert(int((state.open_trade.get("reviews", {}) as Dictionary).get(2, -1)) == total_ticks, "The review records the answer tick total")
	# Finalize honours the LATEST (revised) terms: player 3 accepts, player 1 declined.
	var p3acc: Dictionary = RulesEngine.apply_action(state, 3, GameAction.respond_open_trade("accept"))
	_assert(bool(p3acc.get("ok", false)), "Player 3 accepts")
	var timber_before := int(state.players[0]["hand"][R["TIMBER"]])
	var grain_before := int(state.players[1]["hand"][R["GRAIN"]])
	var fin: Dictionary = RulesEngine.apply_action(state, 0, GameAction.finalize_open_trade(3))
	_assert(bool(fin.get("ok", false)), "Finalize with the accepting player 3")
	_assert(int(state.players[0]["hand"][R["TIMBER"]]) == timber_before - 1, "Proposer pays the offer (revised-state finalize)")
	_assert(int(state.players[1]["hand"][R["GRAIN"]]) == grain_before, "The revised-then-declined player 1 is not traded with")
	_pass_section("116. Revisable Responses Engine Test (limit, wording, guards, review record, final terms)")

func _test_revisable_session_and_bots() -> void:
	var R2: Dictionary = {
		"TIMBER": GameTypes.ResourceType.TIMBER,
		"GRAIN": GameTypes.ResourceType.GRAIN,
	}
	# --- session ordering: bots answer, human last, reviews, then proposer -----
	var session := LocalSession.new()
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Hertha"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Riven"),
	]
	session.start_match(9090, seats, true, 0)
	session.state.phase = GameTypes.TurnPhase.TURN_MAIN
	session.state.current_player = 1
	session.state.open_trades_this_turn = 0
	for pid in range(1, 4):
		for r in GameTypes.ALL_RESOURCES:
			session.state.players[pid]["hand"][r] = 4
	var o1: Dictionary = session.submit_action(1, GameAction.open_trade({R2["GRAIN"]: 1}, {R2["TIMBER"]: 1}))
	_assert(bool(o1.get("ok", false)), "Bot offer posts in the session")
	_assert(session.get_acting_player_id() == 2, "The first unanswered bot seat acts first")
	session.submit_action(2, GameAction.respond_open_trade("decline"))
	_assert(session.get_acting_player_id() == 3, "The next bot seat answers before the human")
	session.submit_action(3, GameAction.respond_open_trade("decline"))
	_assert(session.get_acting_player_id() == 0, "The human answers after all bots")
	_assert(not session.is_ai_to_act(), "The human turn is interactive")
	session.submit_action(0, GameAction.respond_open_trade("decline"))
	_assert(session.is_ai_to_act(), "Bot review passes run before the proposer")
	_assert(session.get_acting_player_id() == 2, "Review passes walk seat order")
	session.step_ai()
	_assert(session.get_acting_player_id() == 3, "Second review seat")
	session.step_ai()
	_assert(session.get_acting_player_id() == 1, "The proposer is on deck after reviews")
	# --- bot revision behaviour (proposer-favouring rules) ----------------------
	var ot_setup := {
		"from": 1,
		"offer": {R2["GRAIN"]: 1},
		"request": {R2["TIMBER"]: 3},
		"responses": {
			2: {"status": "decline", "offer": {}, "request": {}},
			3: {"status": "counter", "offer": {R2["GRAIN"]: 5}, "request": {R2["TIMBER"]: 1}},
		},
		"revisions": {},
		"resp_ticks": {2: 1, 3: 1},
		"reviews": {},
	}
	# A declined bot matches a counter it would itself take.
	var bs := GameState.create_new_game(1234, 4, true)
	bs.phase = GameTypes.TurnPhase.TURN_MAIN
	bs.players[1]["hand"][R2["GRAIN"]] = 9
	bs.players[2]["hand"][R2["TIMBER"]] = 4
	bs.players[2]["hand"][R2["GRAIN"]] = 0
	bs.open_trade = ot_setup.duplicate(true)
	var mact: Dictionary = BotController.choose_action(bs, 2, 2)
	_assert(str(mact.get("type", "")) == "respond_open_trade", "A declined bot matches a counter it would take")
	_assert(str(mact.get("status", "")) == "counter", "The revision mirrors the counter")
	_assert(int((mact.get("offer", {}) as Dictionary).get(R2["GRAIN"], 0)) == 5, "The revision copies the counter terms")
	var mapp: Dictionary = RulesEngine.apply_action(bs, 2, mact)
	_assert(bool(mapp.get("ok", false)), "The bot revision applies")
	_assert(int((bs.open_trade.get("revisions", {}) as Dictionary).get(2, 0)) == 1, "Exactly one revision")
	var mact2: Dictionary = BotController.choose_action(bs, 2, 2)
	_assert(str(mact2.get("type", "")) == "review_open_trade", "After revising once the bot settles for review")
	var bs2 := GameState.create_new_game(1234, 4, true)
	bs2.phase = GameTypes.TurnPhase.TURN_MAIN
	bs2.players[2]["hand"][R2["TIMBER"]] = 4
	bs2.open_trade = ot_setup.duplicate(true)
	var eact: Dictionary = BotController.choose_action(bs2, 2, 1)
	_assert(str(eact.get("type", "")) == "review_open_trade", "An easy bot never revises")
	# An accepted bot stays with its accept even when a peer counter is better
	# for the responder.
	var ot_keep := {
		"from": 1,
		"offer": {R2["GRAIN"]: 1},
		"request": {R2["TIMBER"]: 2},
		"responses": {
			2: {"status": "accept", "offer": {R2["GRAIN"]: 1}, "request": {R2["TIMBER"]: 2}},
			3: {"status": "counter", "offer": {R2["GRAIN"]: 5}, "request": {R2["TIMBER"]: 1}},
		},
		"revisions": {},
		"resp_ticks": {2: 1, 3: 1},
		"reviews": {},
	}
	var bs_keep := GameState.create_new_game(1234, 4, true)
	bs_keep.phase = GameTypes.TurnPhase.TURN_MAIN
	bs_keep.players[2]["hand"][R2["TIMBER"]] = 4
	bs_keep.open_trade = ot_keep.duplicate(true)
	var kact: Dictionary = BotController.choose_action(bs_keep, 2, 2)
	_assert(str(kact.get("type", "")) == "review_open_trade", "An accepted bot keeps its accept")
	# An accepted bot only leaves its accept when it can no longer pay.
	var bs_broke := GameState.create_new_game(1234, 4, true)
	bs_broke.phase = GameTypes.TurnPhase.TURN_MAIN
	bs_broke.players[2]["hand"][R2["TIMBER"]] = 1
	bs_broke.open_trade = ot_keep.duplicate(true)
	var bact: Dictionary = BotController.choose_action(bs_broke, 2, 3)
	_assert(str(bact.get("type", "")) == "respond_open_trade", "An acceptor that cannot pay revises")
	_assert(str(bact.get("status", "")) == "decline", "It steps back to decline, never a new counter")
	# A countered bot undercuts only for the proposer: it copies a peer counter
	# that asks the proposer for more and that it would itself take.
	var ot_under := {
		"from": 1,
		"offer": {R2["GRAIN"]: 1},
		"request": {R2["TIMBER"]: 3},
		"responses": {
			2: {"status": "counter", "offer": {R2["GRAIN"]: 5}, "request": {R2["TIMBER"]: 1}},
			3: {"status": "counter", "offer": {R2["GRAIN"]: 5}, "request": {R2["TIMBER"]: 3}},
		},
		"revisions": {},
		"resp_ticks": {2: 1, 3: 1},
		"reviews": {},
	}
	var bs_under := GameState.create_new_game(1234, 4, true)
	bs_under.phase = GameTypes.TurnPhase.TURN_MAIN
	bs_under.players[2]["hand"][R2["TIMBER"]] = 4
	bs_under.open_trade = ot_under.duplicate(true)
	var uact: Dictionary = BotController.choose_action(bs_under, 2, 3)
	_assert(str(uact.get("type", "")) == "respond_open_trade", "A countered bot undercuts a peer counter that beats it for the proposer")
	_assert(str(uact.get("status", "")) == "counter", "The undercut stays a counter")
	_assert(int((uact.get("request", {}) as Dictionary).get(R2["TIMBER"], 0)) == 3, "The undercut asks the proposer for more")
	# A counter better for the bot itself but NOT better for the proposer never
	# triggers a revision.
	var ot_same := {
		"from": 1,
		"offer": {R2["GRAIN"]: 1},
		"request": {R2["TIMBER"]: 3},
		"responses": {
			2: {"status": "counter", "offer": {R2["GRAIN"]: 5}, "request": {R2["TIMBER"]: 1}},
			3: {"status": "counter", "offer": {R2["GRAIN"]: 6}, "request": {R2["TIMBER"]: 1}},
		},
		"revisions": {},
		"resp_ticks": {2: 1, 3: 1},
		"reviews": {},
	}
	var bs_same := GameState.create_new_game(1234, 4, true)
	bs_same.phase = GameTypes.TurnPhase.TURN_MAIN
	bs_same.players[2]["hand"][R2["TIMBER"]] = 4
	bs_same.open_trade = ot_same.duplicate(true)
	var sact: Dictionary = BotController.choose_action(bs_same, 2, 3)
	_assert(str(sact.get("type", "")) == "review_open_trade", "A counter better for itself but not for the proposer is not copied")
	# --- property: no revision ever makes terms worse for the proposer ---------
	# 200 seeded synthetic review states: randomised hands and peer answers,
	# the reviewed bot in one of three prior-answer modes. Every revision must
	# apply in the engine and must never make the deal worse for the proposer.
	var prop_viol := 0
	var prop_revs := 0
	for seed_p in range(200):
		var rng := RandomNumberGenerator.new()
		rng.seed = 90000 + seed_p
		var psv := GameState.create_new_game(90000 + seed_p, 4, true)
		psv.phase = GameTypes.TurnPhase.TURN_MAIN
		for pid in range(4):
			for r in GameTypes.ALL_RESOURCES:
				psv.players[pid]["hand"][r] = rng.randi_range(0, 6)
		psv.players[2]["hand"][R2["TIMBER"]] = rng.randi_range(1, 6)
		psv.players[3]["hand"][R2["TIMBER"]] = rng.randi_range(1, 6)
		var kg: int = 3 + rng.randi_range(0, 3)
		var peer_ask: int = 1 + (seed_p % 3)
		var prop_responses := {}
		match seed_p % 3:
			0:
				prop_responses = {
					2: {"status": "decline", "offer": {}, "request": {}},
					3: {"status": "counter", "offer": {R2["GRAIN"]: kg}, "request": {R2["TIMBER"]: 1}},
				}
			1:
				prop_responses = {
					2: {"status": "counter", "offer": {R2["GRAIN"]: 5}, "request": {R2["TIMBER"]: 1}},
					3: {"status": "counter", "offer": {R2["GRAIN"]: kg}, "request": {R2["TIMBER"]: peer_ask}},
				}
			_:
				prop_responses = {
					2: {"status": "accept", "offer": {R2["GRAIN"]: 1}, "request": {R2["TIMBER"]: 2}},
					3: {"status": "counter", "offer": {R2["GRAIN"]: kg}, "request": {R2["TIMBER"]: 1}},
				}
		psv.open_trade = {
			"from": 1,
			"offer": {R2["GRAIN"]: 1},
			"request": {R2["TIMBER"]: 2},
			"responses": prop_responses,
			"revisions": {},
			"resp_ticks": {2: 1, 3: 1},
			"reviews": {},
		}
		var prop_diff := 2 if seed_p % 2 == 0 else 3
		var old_r: Dictionary = (psv.open_trade.get("responses", {}) as Dictionary)[2].duplicate(true)
		var act: Dictionary = BotController._choose_open_trade_review(psv, 2, prop_diff)
		if str(act.get("type", "")) == "review_open_trade":
			continue
		var res: Dictionary = RulesEngine.apply_action(psv, 2, act)
		if not bool(res.get("ok", false)):
			prop_viol += 1
			continue
		prop_revs += 1
		var new_r: Dictionary = (psv.open_trade.get("responses", {}) as Dictionary)[2]
		var old_st := str(old_r.get("status", ""))
		var new_st := str(new_r.get("status", ""))
		var hand_p: Dictionary = psv.players[2]["hand"]
		match old_st:
			"accept":
				if new_st != "accept" and BotController._hand_has(hand_p, old_r.get("request", {})):
					prop_viol += 1
			"decline":
				if new_st != "decline" and not BotController._hand_has(hand_p, new_r.get("request", {})):
					prop_viol += 1
			"counter":
				if new_st == "decline":
					if BotController._hand_has(hand_p, old_r.get("request", {})):
						prop_viol += 1
				elif new_st == "counter" or new_st == "accept":
					if BotController._terms_gain_for_proposer(new_r) < BotController._terms_gain_for_proposer(old_r):
						prop_viol += 1
			_:
				prop_viol += 1
	_assert(prop_revs > 0, "The property sweep observes at least one revision, got %d" % prop_revs)
	_assert(prop_viol == 0, "No bot revision makes terms worse for the proposer (200 seeds, %d of %d violate)" % [prop_viol, prop_revs])
	# --- termination bound: every injected offer closes quickly ----------------
	var closed_all := true
	for seed_i in range(200):
		var ms := LocalSession.new()
		var mseats: Array[SeatConfig] = []
		for i in range(4):
			var sc := SeatConfig.new(i, SeatConfig.SeatType.AI_MEDIUM, "B %d" % i)
			mseats.append(sc)
		ms.start_match(40000 + seed_i, mseats, true, 0)
		ms.state.phase = GameTypes.TurnPhase.TURN_MAIN
		ms.state.current_player = 0
		ms.state.open_trades_this_turn = 0
		for pid in range(4):
			for r in GameTypes.ALL_RESOURCES:
				ms.state.players[pid]["hand"][r] = 5
		var rinj: Dictionary = ms.submit_action(0, GameAction.open_trade(
			{GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}
		))
		if not bool(rinj.get("ok", false)):
			continue
		var steps := 0
		while not ms.state.open_trade.is_empty() and steps < 60:
			if not ms.is_ai_to_act():
				break
			ms.step_ai()
			steps += 1
		if not ms.state.open_trade.is_empty():
			closed_all = false
			break
	_assert(closed_all, "Every injected offer closes within the revision bounds (200 seeds)")
	# --- replay exactness across revisions -------------------------------------
	# Drive a real turn with pure submit_action calls (no state pokes) so every
	# action is recorded, including a revision and a review.
	var found_revision_match := false
	for seed_m in [90210, 777, 31, 4242, 555]:
		var ms2 := LocalSession.new()
		var mseats2: Array[SeatConfig] = []
		for i2 in range(4):
			mseats2.append(SeatConfig.new(i2, SeatConfig.SeatType.HUMAN, "S %d" % i2))
		ms2.start_match(seed_m, mseats2, true, 0)
		var turn_guard := 0
		var give_res := -1
		var want_res := -1
		while turn_guard < 400 and give_res < 0:
			turn_guard += 1
			var cur2 := ms2.get_acting_player_id()
			var st2: GameState = ms2.state
			if st2.phase == GameTypes.TurnPhase.GAME_OVER:
				break
			if st2.phase == GameTypes.TurnPhase.TURN_MAIN and cur2 == 0:
				for rA in GameTypes.ALL_RESOURCES:
					if int(st2.players[0]["hand"].get(rA, 0)) < 1:
						continue
					for rB in GameTypes.ALL_RESOURCES:
						if int(rA) == int(rB):
							continue
						if int(st2.players[3]["hand"].get(rB, 0)) >= 1 and int(st2.players[0]["hand"].get(rB, 0)) >= 1:
							give_res = int(rA)
							want_res = int(rB)
							break
					if give_res >= 0:
						break
				if give_res < 0:
					ms2.submit_action(0, GameAction.end_turn())
				continue
			var ffa := BotController.choose_action(st2, cur2, 2)
			var ffr := ms2.submit_action(cur2, ffa)
			if not bool(ffr.get("ok", false)):
				break
		if give_res < 0:
			continue
		var o2: Dictionary = ms2.submit_action(0, GameAction.open_trade({give_res: 1}, {want_res: 1}))
		if not bool(o2.get("ok", false)):
			continue
		ms2.submit_action(1, GameAction.respond_open_trade("accept"))
		var rev: Dictionary = ms2.submit_action(1, GameAction.respond_open_trade("decline"))
		_assert(bool(rev.get("ok", false)), "Session revision is recorded")
		var rev_seen := false
		for ev2 in rev.get("events", []):
			if str(ev2).contains("revises:"):
				rev_seen = true
		_assert(rev_seen, "Recorded session action emits the revise wording")
		ms2.submit_action(2, GameAction.respond_open_trade("decline"))
		ms2.submit_action(2, GameAction.review_open_trade())
		var acc3: Dictionary = ms2.submit_action(3, GameAction.respond_open_trade("accept"))
		if not bool(acc3.get("ok", false)):
			ms2.submit_action(0, GameAction.cancel_open_trade())
			continue
		ms2.submit_action(0, GameAction.finalize_open_trade(3))
		var live: GameState = ms2.state
		var exact: GameState = ms2.replay.state_at(ms2.replay.step_count())
		_assert(_replay_state_diff(exact, live) == "", "Replay snapshot matches the live state after revisions")
		var json_back: MatchReplay = MatchReplay.from_dict(JSON.parse_string(JSON.stringify(ms2.replay.to_dict())) as Dictionary)
		_assert(_replay_state_diff(json_back.state_at(json_back.step_count()), live) == "", "The JSON round trip replays revisions exactly")
		found_revision_match = true
		break
	_assert(found_revision_match, "A submit-driven session with revisions replays exactly")
	_pass_section("117. Revisable Session & Bots Test (bot-first order, medium revision, easy abstains, termination, replay)")


func _test_step_guard_owner_only() -> void:
	# Three full offers in one bot turn cost ~21 session steps (3 answers + 3
	# reviews + the owner's close each). Only the owner's own actions may count
	# toward the runaway guard: at step 21 the owner still finalizes the third
	# offer's deal and afterwards builds, instead of a forced decline/end turn.
	var s := LocalSession.new()
	var seats: Array[SeatConfig] = []
	for i in range(4):
		seats.append(SeatConfig.new(i, SeatConfig.SeatType.AI_HARD, "W %d" % i))
	s.start_match(31777, seats, true, 0)
	var setup_guard := 0
	while s.state.phase != GameTypes.TurnPhase.TURN_MAIN and setup_guard < 64 and s.is_ai_to_act():
		setup_guard += 1
		s.step_ai()
	_assert(s.state.phase == GameTypes.TurnPhase.TURN_MAIN, "Setup completes into the main phase")
	s.state.current_player = 0
	s.state.open_trades_this_turn = 0
	var st: GameState = s.state
	for pid in range(4):
		for r in GameTypes.ALL_RESOURCES:
			st.players[pid]["hand"][r] = 5
		if pid > 0:
			st.players[pid]["hand"][GameTypes.ResourceType.IRON] = 0
	var turn_start: int = s.state.turn_number
	var steps := 0
	var traded := false
	var cycle_ok := true
	for k in range(3):
		var give := {GameTypes.ResourceType.GRAIN: 1}
		var want := {GameTypes.ResourceType.TIMBER: 1}
		if k == 2:
			give = {GameTypes.ResourceType.IRON: 2}
			want = {GameTypes.ResourceType.GRAIN: 1}
		var o: Dictionary = s.submit_action(0, GameAction.open_trade(give, want))
		if not bool(o.get("ok", false)):
			cycle_ok = false
			break
		var inner_guard := 0
		while s.is_ai_to_act() and s.get_acting_player_id() != 0 and inner_guard < 40:
			inner_guard += 1
			steps += 1
			s.step_ai()
		if s.is_ai_to_act() and s.get_acting_player_id() == 0:
			steps += 1
			var ro: Dictionary = s.step_ai()
			for ev in ro.get("events", []):
				if str(ev).contains("traded"):
					traded = true
		if not s.state.open_trade.is_empty():
			cycle_ok = false
			break
	_assert(cycle_ok, "Three full offers each closed inside one turn")
	_assert(steps >= 21, "The turn really cost %d session steps (> the old 20-step guard)" % steps)
	_assert(traded, "The owner finalized the third offer's deal at step 21 (guard did not force a cancel)")
	_assert(s.state.turn_number == turn_start, "The turn was not cut short by the guard")
	var edges: Array[int] = RulesEngine.get_valid_road_edges(s.state, 0, -1)
	_assert(not edges.is_empty(), "The owner has a legal road to build after the three offers")
	var rb: Dictionary = s.submit_action(0, GameAction.place_road(edges[0]))
	_assert(bool(rb.get("ok", false)), "The owner still builds after 21 steps in the turn")
	_pass_section("119. Step Guard Owner-Only Test (3 full offers + reviews + build are not cut short)")

func _test_difficulty3_stronger() -> void:
	# The kept Hard feature "plan_lookahead" (default on) replaces Normal's
	# fixed city-first priority with a 1-ply plan of the main build decision.
	var state := GameState.create_new_game(2, 4, true)
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	# Low-production (2 pips) settlement at vertex 46; own roads 61 + 57 step to
	# open vertex 44, which sits on 9 pips of production.
	state.vertex_owner[46] = 0
	state.vertex_building[46] = GameTypes.BuildingType.SETTLEMENT
	state.edge_owner[61] = 0
	state.edge_owner[57] = 0
	state.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 3
	state.players[0]["hand"][GameTypes.ResourceType.IRON] = 3
	state.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 1
	state.players[0]["hand"][GameTypes.ResourceType.CLAY] = 1
	state.players[0]["hand"][GameTypes.ResourceType.FLEECE] = 1
	var city_verts: Array[int] = RulesEngine.get_valid_city_vertices(state, 0)
	var settle_verts: Array[int] = RulesEngine.get_valid_settlement_vertices(state, 0, false)
	_assert(city_verts.has(46), "Vertex 46 should be upgradable to a City")
	_assert(settle_verts.has(44), "Vertex 44 should be a legal settlement spot")

	var a2: Dictionary = BotController.choose_action(state, 0, 2)
	var a3: Dictionary = BotController.choose_action(state, 0, 3)
	_assert(str(a2.get("type", "")) == "upgrade_city" and int(a2.get("vertex_id", -1)) == 46, "Normal upgrades the city first (got %s)" % [str(a2)])
	_assert(str(a3.get("type", "")) == "place_settlement" and int(a3.get("vertex_id", -1)) == 44, "Hard's lookahead plans the richer settlement instead (got %s)" % [str(a3)])

	# The difference comes from the feature switch itself.
	BotController.hard_features["plan_lookahead"] = false
	var a3_off: Dictionary = BotController.choose_action(state, 0, 3)
	BotController.hard_features["plan_lookahead"] = true
	_assert(str(a3_off.get("type", "")) == "upgrade_city" and int(a3_off.get("vertex_id", -1)) == 46, "With plan_lookahead off, Hard must play exactly like Normal")

	var legal3: Dictionary = RulesEngine.apply_action(state, 0, a3)
	_assert(bool(legal3.get("ok", false)), "Hard's planned settlement must be a legal action")
	_pass_section("18. Difficulty 3 Stronger Test (plan_lookahead: Hard picks the richer settlement where Normal upgrades first)")

func _test_dev_card_chips_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4711, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["new_dev_cards"].append(GameTypes.DevCardType.GUARD)
	ui._refresh_ui()
	var guard_chip: CardFace = ui._action_chips[GameTypes.DevCardType.GUARD]
	_assert(bool(guard_chip.disabled), "A Guard bought this turn (new_dev_cards only) must show a disabled chip")
	_assert(int(guard_chip.count) == 1, "The Guard card should show count 1")
	_assert(str(guard_chip.tooltip_text).contains("Bought this turn"), "The disabled chip should explain the reason, got: %s" % str(guard_chip.tooltip_text))
	st.players[0]["new_dev_cards"].clear()
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.GUARD)
	ui._refresh_ui()
	_assert(not bool(guard_chip.disabled), "A Guard held in dev_cards should enable the chip")
	_assert(str(guard_chip.tooltip_text).contains("new this turn") or str(guard_chip.tooltip_text).contains("Play Guard"), "Playable Guard tooltip explains, got: %s" % str(guard_chip.tooltip_text))
	_assert(str(guard_chip.tooltip_text).contains("Play Guard"), "The enabled chip tooltip should say Play Guard, got: %s" % str(guard_chip.tooltip_text))
	st.players[0]["dev_cards"].clear()
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.CHARTER_POINT)
	ui._refresh_ui()
	var charter_chip: CardFace = ui._action_chips[GameTypes.DevCardType.CHARTER_POINT]
	_assert(bool(charter_chip.disabled), "A Charter chip must never be clickable")
	_pass_section("20. Action Card Chips Test (bought-this-turn disabled with reason; owned enabled; Charter inert)")

func _find_button_by_text(node: Node, txt: String) -> Button:
	for c in node.get_children():
		if c is Button and str((c as Button).text) == txt:
			return c as Button
		var r := _find_button_by_text(c, txt)
		if r != null:
			return r
	return null

func _test_bounty_panel_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4712, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.HARVEST_BOUNTY)
	ui._on_play_bounty_pressed()
	_assert(bool(ui._subpanel_container.visible) and bool(ui._bounty_box.visible), "Bounty panel should open for the acting human")
	# end the turn: the panel must hide on the next refresh
	ui._submit_human_action(GameAction.end_turn())
	_assert(not bool(ui._bounty_box.visible) or not bool(ui._subpanel_container.visible), "Bounty panel must hide once the turn has passed")
	_assert(int(ui._subpanel_owner_pid) == -1, "Subpanel ownership should be cleared after the turn passes")
	# force the submit while a bot acts: nothing may change
	var hand_before: int = GameTypes.hand_total(ui.session.state.players[0]["hand"])
	var played_before: bool = bool(ui.session.state.players[0]["played_dev_this_turn"])
	var cards_before: int = ui.session.state.players[0]["dev_cards"].size()
	var claim_btn := _find_button_by_text(ui, "Claim 2 Resources")
	_assert(claim_btn != null, "Claim 2 Resources button should exist")
	if claim_btn != null:
		claim_btn.pressed.emit()
	_assert(GameTypes.hand_total(ui.session.state.players[0]["hand"]) == hand_before, "Submitting Bounty while a bot acts must not change the hand")
	_assert(bool(ui.session.state.players[0]["played_dev_this_turn"]) == played_before, "Submitting Bounty while a bot acts must not mark a card played")
	_assert(ui.session.state.players[0]["dev_cards"].size() == cards_before, "Submitting Bounty while a bot acts must not consume the card")
	_pass_section("21. Bounty Panel Ownership Test (hides when the turn passes; submits ignored for other players)")

func _test_space_after_mouse_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4713, seats, true, 0)
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and not ui._end_turn_btn.disabled
	)
	_assert(reached, "Solo match should reach a human TURN_MAIN with End Turn enabled")
	if not reached:
		return
	var btn: Button = ui._end_turn_btn
	_assert(btn.size.x > 0.0, "End Turn button should have a real size before the mouse click")
	# headless windows are 64x64 with canvas_items stretch: convert the
	# button's canvas centre into screen space so the click lands on it
	_ui_queue.push_front(func() -> void:
		var center := root.get_screen_transform() * (btn.get_global_transform() * (btn.size * 0.5))
		var press_ev := InputEventMouseButton.new()
		press_ev.button_index = MOUSE_BUTTON_LEFT
		press_ev.pressed = true
		press_ev.position = center
		press_ev.global_position = center
		root.push_input(press_ev)
		var release_ev := InputEventMouseButton.new()
		release_ev.button_index = MOUSE_BUTTON_LEFT
		release_ev.pressed = false
		release_ev.position = center
		release_ev.global_position = center
		root.push_input(release_ev)
		_assert(ui.session.state.current_player == 1 or ui.session.state.turn_number > 1, "The mouse click should have ended the human's turn")
		_assert(not bool(btn.has_focus()), "A mouse click must not leave keyboard focus on End Turn")
		var back := _ui_drive_until(ui, func(st: GameState) -> bool:
			return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_ROLL
		)
		_assert(back, "Play should return to the human's roll phase")
		if not back:
			return
		var held_player: int = ui.session.state.current_player
		var space1 := InputEventKey.new()
		space1.keycode = KEY_SPACE
		space1.pressed = true
		root.push_input(space1)
		var space1_up := InputEventKey.new()
		space1_up.keycode = KEY_SPACE
		space1_up.pressed = false
		root.push_input(space1_up)
		_assert(ui.session.state.phase == GameTypes.TurnPhase.TURN_MAIN, "Space #1 should roll into the main phase")
		_assert(ui.session.state.current_player == held_player, "Space #1 must not change the current player")
		var space2 := InputEventKey.new()
		space2.keycode = KEY_SPACE
		space2.pressed = true
		root.push_input(space2)
		var space2_up := InputEventKey.new()
		space2_up.keycode = KEY_SPACE
		space2_up.pressed = false
		root.push_input(space2_up)
		_assert(ui.session.state.phase == GameTypes.TurnPhase.TURN_MAIN and ui.session.state.current_player == held_player, "Space #2 must never end the turn")
		_pass_section("22. Space vs Mouse Focus Test (mouse End Turn click keeps no focus; Space never ends the turn)")
	)

func _test_trade_tray_close_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4714, seats, true, 0)
	# --- scenario 1: tray auto-opened for a bot offer closes when resolved ---
	var bot_main := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty() and GameTypes.hand_total(st.players[0]["hand"]) >= 1
	)
	if not bot_main:
		_assert(false, "Should reach a human main phase with cards")
		return
	# close any stale tray the way a user would, end the human turn, then
	# force an offer from the bot
	if bool(ui._trade_tray.visible):
		ui._toggle_trade_tray()
	_assert(not bool(ui._trade_tray.visible), "User closing should hide the tray")
	# --- scenario 0: an idle human-opened tray toggles normally ---
	ui._toggle_trade_tray()
	_assert(bool(ui._trade_tray.visible), "Human-opened tray is visible")
	_assert(not bool(ui._trade_opened_auto), "Human-opened tray must not be marked automatic")
	ui._toggle_trade_tray()
	_assert(not bool(ui._trade_tray.visible), "Idle toggle must close the tray without touching the engine")
	_assert(ui.session.state.open_trade.is_empty(), "Idle toggling must not touch the engine")
	ui._submit_human_action(GameAction.end_turn())
	var give_res := -1
	var get_res := -1
	var bot_main2 := _ui_drive_until(ui, func(st: GameState) -> bool:
		if not ui.session.is_ai_to_act() or st.phase != GameTypes.TurnPhase.TURN_MAIN or GameTypes.hand_total(st.players[1]["hand"]) < 1:
			return false
		if not st.open_trade.is_empty():
			return false
		var g := -1
		var w := -1
		for r in GameTypes.ALL_RESOURCES:
			if int(st.players[1]["hand"].get(r, 0)) >= 1 and g == -1:
				g = r
			elif int(st.players[0]["hand"].get(r, 0)) >= 1 and w == -1 and r != g:
				w = r
		return g != -1 and w != -1
	)
	if bot_main2:
		for r in GameTypes.ALL_RESOURCES:
			if int(ui.session.state.players[1]["hand"].get(r, 0)) >= 1 and give_res == -1:
				give_res = r
			elif int(ui.session.state.players[0]["hand"].get(r, 0)) >= 1 and get_res == -1 and r != give_res:
				get_res = r
	if give_res == -1 or get_res == -1:
		_assert(false, "Could not find tradeable resources for the forced offer")
		return
	var opened: Dictionary = ui.session.submit_action(1, GameAction.open_trade({give_res: 1}, {get_res: 1}))
	_assert(bool(opened.get("ok", false)), "Bot offer should open")
	while ui.session.is_ai_to_act() and not ui.session.state.open_trade.is_empty():
		ui.session.step_ai()
	_assert(not ui.session.state.open_trade.is_empty(), "Offer should still be open while the human answers")
	_assert(bool(ui._trade_tray.visible), "Tray should auto-open for the incoming offer")
	_assert(bool(ui._trade_opened_auto), "Auto-open should be tracked as automatic")
	ui._ot_accept_btn.pressed.emit()
	var guard := 0
	while not ui.session.state.open_trade.is_empty() and guard < 200:
		guard += 1
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
		else:
			break
	_assert(ui.session.state.open_trade.is_empty(), "Bot should finalize the accepted trade")
	_assert(not bool(ui._trade_tray.visible), "Auto-opened tray must close when the answered offer resolves")
	# --- scenario 2: a tray the human opened themselves stays open ---
	var bot_main3 := _ui_drive_until(ui, func(st: GameState) -> bool:
		if not ui.session.is_ai_to_act() or st.phase != GameTypes.TurnPhase.TURN_MAIN or GameTypes.hand_total(st.players[1]["hand"]) < 1:
			return false
		if not st.open_trade.is_empty():
			return false
		var g := -1
		var w := -1
		for r in GameTypes.ALL_RESOURCES:
			if int(st.players[1]["hand"].get(r, 0)) >= 1 and g == -1:
				g = r
			elif int(st.players[0]["hand"].get(r, 0)) >= 1 and w == -1 and r != g:
				w = r
		return g != -1 and w != -1
	)
	_assert(bot_main3, "Second bot main phase should be reachable")
	var give2 := -1
	var get2 := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(ui.session.state.players[1]["hand"].get(r, 0)) >= 1 and give2 == -1:
			give2 = r
		elif int(ui.session.state.players[0]["hand"].get(r, 0)) >= 1 and get2 == -1 and r != give2:
			get2 = r
	var opened2: Dictionary = ui.session.submit_action(1, GameAction.open_trade({give2: 1}, {get2: 1}))
	_assert(bool(opened2.get("ok", false)), "Second bot offer should open")
	while ui.session.is_ai_to_act() and not ui.session.state.open_trade.is_empty():
		ui.session.step_ai()
	_assert(bool(ui._trade_tray.visible), "Incoming offer reopens the responder's panel")
	_assert(bool(ui._trade_opened_auto), "Reopen for an incoming offer counts as automatic")
	ui._ot_accept_btn.pressed.emit()
	var guard2 := 0
	while not ui.session.state.open_trade.is_empty() and guard2 < 200:
		guard2 += 1
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
		else:
			break
	_assert(ui.session.state.open_trade.is_empty(), "Second offer should resolve")
	_assert(not bool(ui._trade_tray.visible), "The tray must close once the human is no longer part of the offer (bot-to-bot resolution)")
	_pass_section("23. Trade Tray Auto-Close Test (auto-opened closes on resolve; tray closes when the human is out of the loop)")

func _test_game_over_banner_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Coral"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4715, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.GAME_OVER
	st.winner = 1
	ui._board_view.clear_highlights()
	ui._refresh_ui()
	var expected := "%s wins!" % GameTypes.PLAYER_NAMES[1]
	_assert(str(ui._status_banner_label.text) == expected, "Game-over banner must be exactly '%s', got '%s'" % [expected, str(ui._status_banner_label.text)])
	_assert(not str(ui._status_banner_label.text).contains("—"), "Game-over banner must not carry the viewer prefix")
	_assert(not bool(ui._device_pass_cover.visible), "Game over must remove the device-pass cover")
	_assert(_ui_hand_labels_hidden(ui), "Game over must show no hand counts")
	_pass_section("24. Game-over Banner Test (no viewer prefix, no cover, no hand)")

func _test_roll_fx_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4716, seats, true, 0)
	var st: GameState = ui.session.state
	st.last_dice = Vector2i(3, 3)
	var fx0: int = int(ui._roll_fx_count)
	var evs1: Array[String] = ["Azure rolled 3 + 3 = 6."]
	ui._on_state_updated(st, evs1)
	var fx1: int = int(ui._roll_fx_count)
	_assert(fx1 == fx0 + 1, "First 3+3 roll should trigger the dice animation")
	st.last_dice = Vector2i(3, 3)
	var evs2: Array[String] = ["Azure rolled 3 + 3 = 6."]
	ui._on_state_updated(st, evs2)
	var fx2: int = int(ui._roll_fx_count)
	_assert(fx2 == fx1 + 1, "A second identical 3+3 roll must also trigger the animation")
	_pass_section("25. Roll Animation Test (two identical rolls both animate)")


func _test_toast_tween_body(ui: Node) -> void:
	var steps: Array = []
	for i in range(10):
		steps.append(func() -> void:
			ui._show_toast("spam toast %d" % i, Color(0.55, 0.18, 0.14), 0.6)
		)
	steps.append(func() -> void:
		var mid: int = ui._toast_layer.get_child_count()
		_assert(mid == 3, "Toast cap keeps exactly 3 panels during the spam, got %d" % mid)
	)
	for i in range(120):
		steps.append(func() -> void:
			pass
		)
	steps.append(func() -> void:
		var n: int = ui._toast_layer.get_child_count()
		_assert(n <= 3, "At most 3 toast panels may exist, got %d" % n)
		var invalid := 0
		for c in ui._toast_layer.get_children():
			if not is_instance_valid(c):
				invalid += 1
		_assert(invalid == 0, "No invalid toast panels left after the tweens finish, got %d" % invalid)
		_assert(ui._toast_labels.size() <= 3, "Toast label bookkeeping stays capped, got %d" % ui._toast_labels.size())
		_pass_section("47. Toast Tween Lifetime Test (10 toasts over consecutive frames, cap 3, no dangling targets)")
	)
	for j in range(steps.size() - 1, -1, -1):
		_ui_queue.push_front(steps[j])

func _check_port_badges_clear(bv: BoardView, label: String) -> void:
	_assert(bv.get_port_count() > 0, "Ports exist %s" % label)
	_assert(bv.get_port_badge_data().size() == bv.get_port_count(), "Every port gets badge data %s" % label)
	var polys := bv.get_land_polys()
	_assert(polys.size() > 0, "Land polygons are cached %s" % label)
	var view := Rect2(Vector2.ZERO, bv.size).grow(-2.0)
	for bd in bv.get_port_badge_data():
		var c: Vector2 = bd["center"]
		var r: float = bd["r"]
		var tag: Rect2 = bd["tag_rect"]
		var boat: Rect2 = bd["boat_rect"]
		var badge_rect := Rect2(c - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
		_assert(view.encloses(badge_rect), "Badge circle is inside the board view %s (c=%s r=%.1f)" % [label, str(c), r])
		_assert(view.encloses(tag), "Badge tag is inside the board view %s (%s)" % [label, str(tag)])
		_assert(not tag.grow(1.0).intersects(boat), "Tag does not touch its ship %s" % label)
		var d_boat: float = c.distance_to(Vector2(clampf(c.x, boat.position.x, boat.end.x), clampf(c.y, boat.position.y, boat.end.y)))
		_assert(d_boat >= r + 1.0, "Badge circle is clear of its ship %s (gap %.1f)" % [label, d_boat])
		for poly in polys:
			_assert(bv.point_poly_dist(c, poly) >= r + 1.0, "Badge circle is clear of land %s (gap %.1f)" % [label, bv.point_poly_dist(c, poly)])
			var corner_min := INF
			for corner in [tag.position, Vector2(tag.end.x, tag.position.y), tag.end, Vector2(tag.position.x, tag.end.y)]:
				corner_min = minf(corner_min, bv.point_poly_dist(corner, poly))
			_assert(corner_min >= 0.5, "Tag is clear of land %s (gap %.1f)" % [label, corner_min])

func _test_port_geom_body(ui: Node) -> void:
	_check_port_badges_clear(ui._board_view, "at the default 1280x800 window, board ~940x628")
	var bv2 := BoardView.new()
	ui.get_tree().root.add_child(bv2)
	bv2.state = ui.session.state
	var steps: Array = []
	steps.append(func() -> void:
		bv2.size = Vector2(930, 650)
	)
	steps.append(func() -> void:
		pass
	)
	steps.append(func() -> void:
		pass
	)
	steps.append(func() -> void:
		_assert(bv2.size == Vector2(930, 650), "Standalone board keeps 930x650, got %s" % str(bv2.size))
		_check_port_badges_clear(bv2, "at a 930x650 board")
		bv2.size = Vector2(900, 900)
	)
	steps.append(func() -> void:
		pass
	)
	steps.append(func() -> void:
		pass
	)
	steps.append(func() -> void:
		_check_port_badges_clear(bv2, "at a 900x900 board")
		_assert(bv2.get_port_badge_data().size() == 9, "All nine ports get badges on the 900x900 board")
		bv2.free()
		_pass_section("48. Port Badge Geometry Test (sea-side badges clear of hexes, ships and the view rect)")
	)
	for j in range(steps.size() - 1, -1, -1):
		_ui_queue.push_front(steps[j])


func _test_blocker_phases_body(ui: Node) -> void:
	var bv: BoardView = ui._board_view
	var st: GameState = ui.session.state
	bv.reduce_motion = false
	bv.anim_scale = 1.0
	bv._blocker_t = 1.0
	var from_tile: int = (st.blocker_tile + 1) % 19
	_assert(bv.blocker_anim_duration() > 0.0, "Blocker anim has a positive duration when motion is on")
	bv.animate_blocker(from_tile)
	_assert(bv.blocker_anim_phase() == "lift", "Phase starts as lift, got %s" % bv.blocker_anim_phase())
	bv._process(0.15)
	_assert(bv.blocker_anim_phase() == "lift", "Still lifting at t=0.17, got %s" % bv.blocker_anim_phase())
	bv._process(0.2)
	_assert(bv.blocker_anim_phase() == "shift", "Shifting at t=0.39, got %s" % bv.blocker_anim_phase())
	bv._process(0.5)
	_assert(bv.blocker_anim_phase() == "place", "Placing at t=0.94, got %s" % bv.blocker_anim_phase())
	bv._process(0.2)
	_assert(bv.blocker_anim_phase() == "", "Animation reports no phase once finished, got %s" % bv.blocker_anim_phase())
	bv.reduce_motion = true
	bv.animate_blocker(from_tile)
	_assert(bv.blocker_anim_duration() == 0.0, "Reduce motion reports zero duration")
	_assert(bv.blocker_anim_phase() == "", "Reduce motion never animates the Blocker")
	bv.reduce_motion = false
	_pass_section("49. Blocker Lift-Shift-Place Test (phases advance lift-shift-place-empty, reduce motion off)")

func _apply_fake_steal(ui: Node, victim_pid: int, thief_pid: int, res: int) -> void:
	var st: GameState = ui.session.state
	var vhand: Dictionary = st.players[victim_pid]["hand"]
	var thand: Dictionary = st.players[thief_pid]["hand"]
	vhand[res] = int(vhand.get(res, 0)) + 2
	vhand[res] = int(vhand[res]) - 1
	thand[res] = int(thand.get(res, 0)) + 1
	st.last_steal = {"serial": 654321, "thief": thief_pid, "victim": victim_pid, "res": res}
	ui._last_steal_serial = 654320

func _test_steal_hold_body(ui: Node) -> void:
	var st: GameState = ui.session.state
	st.current_player = 0
	var res: int = GameTypes.ResourceType.TIMBER
	_apply_fake_steal(ui, 0, 1, res)
	var pre_victim: int = GameTypes.hand_total(st.players[0]["hand"]) + 1
	var pre_thief: int = GameTypes.hand_total(st.players[1]["hand"]) - 1
	st.current_player = 1
	var evs: Array[String] = ["%s moved the Blocker to tile %d." % [str(st.players[1].get("name", "B")), (st.blocker_tile + 3) % 19]]
	ui._prev_blocker_tile = (st.blocker_tile + 7) % 19
	ui._animate_from_events(evs, st)
	_assert(bool(ui._blocker_anim_this_update), "Blocker move event marks the animation as started this update")
	ui._announce_steal(st)
	_assert(ui._steal_timer != null, "Card flight waits for the Blocker animation")
	_assert(ui._displayed_hand_count(1) == pre_thief, "Thief shows the pre-steal count during the flight, got %d want %d" % [ui._displayed_hand_count(1), pre_thief])
	_assert(ui._displayed_hand_count(0) == pre_victim, "Victim shows the pre-steal count until the card departs, got %d want %d" % [ui._displayed_hand_count(0), pre_victim])
	ui._finish_steal_anim()
	_assert(ui._hand_count_hold.is_empty(), "Finishing the steal animation clears the holds")
	_assert(ui._displayed_hand_count(0) == GameTypes.hand_total(st.players[0]["hand"]), "Victim shows the real total after finishing")
	_assert(ui._displayed_hand_count(1) == GameTypes.hand_total(st.players[1]["hand"]), "Thief shows the real total after finishing")
	_pass_section("50. Steal Count Hold Test (displayed counts move only when the card departs and lands)")

func _test_steal_hold_reduce_body(ui: Node) -> void:
	ui._reduce_motion = true
	ui._board_view.reduce_motion = true
	var st: GameState = ui.session.state
	var res: int = GameTypes.ResourceType.CLAY
	_apply_fake_steal(ui, 0, 1, res)
	ui._announce_steal(st)
	_assert(ui._hand_count_hold.is_empty(), "Reduce motion sets no display holds")
	_assert(ui._displayed_hand_count(0) == GameTypes.hand_total(st.players[0]["hand"]), "Victim shows the real total immediately with reduce motion")
	_assert(ui._displayed_hand_count(1) == GameTypes.hand_total(st.players[1]["hand"]), "Thief shows the real total immediately with reduce motion")
	ui._reduce_motion = false
	ui._board_view.reduce_motion = false
	_pass_section("51. Steal Hold Reduce-Motion Test (counts snap immediately)")

func _test_steal_hold_newgame_body(ui: Node) -> void:
	var st: GameState = ui.session.state
	st.current_player = 1
	var res: int = GameTypes.ResourceType.GRAIN
	_apply_fake_steal(ui, 0, 1, res)
	var evs: Array[String] = ["%s moved the Blocker to tile %d." % [str(st.players[1].get("name", "B")), (st.blocker_tile + 2) % 19]]
	ui._prev_blocker_tile = (st.blocker_tile + 5) % 19
	ui._animate_from_events(evs, st)
	ui._announce_steal(st)
	_assert(not ui._hand_count_hold.is_empty(), "Holds are set while the steal flight is pending")
	ui._start_match_from_lobby_settings()
	_assert(ui._hand_count_hold.is_empty(), "A new game clears the steal display holds")
	_assert(ui._steal_pending_anim.is_empty(), "A new game cancels the pending steal flight")
	_pass_section("52. Steal Hold New Game Test (starting a match clears holds and pending flight)")

func _test_steal_flight_hotseat_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Ivory"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Dune"),
	]
	ui.session.start_match(777001, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	var reached := _ui_drive_until(ui, func(s2: GameState) -> bool:
		return s2.phase >= GameTypes.TurnPhase.TURN_ROLL and s2.phase != GameTypes.TurnPhase.TURN_DISCARD and s2.phase != GameTypes.TurnPhase.GAME_OVER and s2.pending_discards.is_empty() and s2.open_trade.is_empty()
	, 400)
	_assert(bool(reached), "Match drives into normal turns")
	if not reached:
		_pass_section("53. Steal Flight Privacy Test (hot-seat hidden hand flies a card back)")
		return
	st = ui.session.state
	st.current_player = 2
	var res: int = GameTypes.ResourceType.FLEECE
	_apply_fake_steal(ui, 0, 1, res)
	_assert(bool(ui._hand_hidden()), "Hot-seat hides the viewer's hand while the bot acts")
	ui._last_fly_kind = ""
	ui._announce_steal(st)
	_assert(ui._last_fly_kind == "back", "Hot-seat flight shows a card back, got %s" % ui._last_fly_kind)
	ui._finish_steal_anim()
	_pass_section("53. Steal Flight Privacy Test (hot-seat hidden hand flies a card back)")

func _start_fake_steal_a(ui: Node, res: int, serial: int) -> void:
	var st: GameState = ui.session.state
	var vhand: Dictionary = st.players[0]["hand"]
	var thand: Dictionary = st.players[1]["hand"]
	vhand[res] = int(vhand.get(res, 0)) + 2
	vhand[res] = int(vhand[res]) - 1
	thand[res] = int(thand.get(res, 0)) + 1
	st.last_steal = {"serial": serial, "thief": 1, "victim": 0, "res": res}
	ui._last_steal_serial = serial - 1

func _test_steal_supersede_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(777002, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	_start_fake_steal_a(ui, GameTypes.ResourceType.TIMBER, 654321)
	ui._blocker_anim_this_update = false
	ui._announce_steal(st)
	var serial_a: int = ui._steal_anim_serial
	_assert(serial_a == 654321, "Steal A owns the current animation serial")
	_assert(is_instance_valid(ui._steal_flyer), "Steal A put a card in the air")
	_start_fake_steal_a(ui, GameTypes.ResourceType.CLAY, 654322)
	ui._blocker_anim_this_update = true
	ui._announce_steal(st)
	ui._blocker_anim_this_update = false
	var serial_b: int = ui._steal_anim_serial
	_assert(serial_b == 654322, "Steal B took over the animation serial")
	_assert(int(ui._hand_count_hold.get(1, 0)) == -1, "B thief hold is set")
	_assert(int(ui._hand_count_hold.get(0, 0)) == 1, "B victim hold is set")
	_assert(int(ui._res_hold.get(GameTypes.ResourceType.CLAY, 0)) == 1, "B hand-card hold is set")
	_assert(ui._steal_hold_deadline_ms > 0, "B armed the holds deadline")
	ui._on_steal_card_landed(1, serial_a)
	_assert(ui._steal_anim_serial == serial_b, "A's late landing cannot reset B's serial, got %d" % ui._steal_anim_serial)
	_assert(int(ui._hand_count_hold.get(1, 0)) == -1, "A's late landing kept B's thief hold")
	_assert(int(ui._hand_count_hold.get(0, 0)) == 1, "A's late landing kept B's victim hold")
	_assert(int(ui._res_hold.get(GameTypes.ResourceType.CLAY, 0)) == 1, "A's late landing kept B's hand-card hold")
	ui._on_steal_delay_done(serial_a)
	_assert(not ui._steal_pending_anim.is_empty(), "A's stale delay callback cannot consume B's pending flight")
	ui._on_steal_delay_done(serial_b)
	_assert(ui._steal_pending_anim.is_empty(), "B's delay departs the pending flight")
	_assert(int(ui._hand_count_hold.get(1, 0)) == -1, "Only the thief hold remains after B departs")
	_assert(not ui._hand_count_hold.has(0), "B's victim hold cleared when the card departed")
	_assert(ui._res_hold.is_empty(), "B's hand-card hold cleared when the card departed")
	ui._on_steal_card_landed(1, serial_b)
	_assert(ui._hand_count_hold.is_empty(), "B's landing clears all holds")
	_assert(ui._res_hold.is_empty(), "B's landing clears the hand-card holds")
	_assert(ui._displayed_hand_count(0) == GameTypes.hand_total(st.players[0]["hand"]), "Victim shows the real total after B lands")
	_assert(ui._displayed_hand_count(1) == GameTypes.hand_total(st.players[1]["hand"]), "Thief shows the real total after B lands")
	_assert(ui._steal_anim_serial == -1, "Finished animation releases the serial")
	ui._finish_steal_anim()
	_pass_section("54. Superseded Steal Flight Test (a late landing or stale timer cannot break the newer steal)")

func _test_steal_flyer_cancel_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(777003, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	_start_fake_steal_a(ui, GameTypes.ResourceType.GRAIN, 654331)
	ui._blocker_anim_this_update = false
	ui._announce_steal(st)
	var flyer: CardFace = ui._steal_flyer
	_assert(is_instance_valid(flyer), "A flyer is in the air before finishing")
	ui._finish_steal_anim()
	_assert(is_instance_valid(flyer) and flyer.is_queued_for_deletion(), "Finishing a steal queues the in-flight card for deletion")
	_assert(ui._hand_count_hold.is_empty(), "Finishing clears the holds")
	_assert(ui._res_hold.is_empty(), "Finishing clears the hand-card holds")
	_assert(ui._steal_flyer == null, "The flyer reference is dropped on finish")
	_pass_section("55. Steal Flyer Cancel Test (finish removes the superseded card instead of letting it land)")

func _test_steal_hold_deadline_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(777004, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	_start_fake_steal_a(ui, GameTypes.ResourceType.IRON, 654341)
	ui._blocker_anim_this_update = false
	ui._announce_steal(st)
	ui._hand_count_hold[1] = int(ui._hand_count_hold.get(1, 0)) - 1
	ui._steal_hold_deadline_ms = Time.get_ticks_msec() - 1
	ui._on_ai_timer_tick()
	_assert(ui._hand_count_hold.is_empty(), "The deadline tick clears holds that outlived their animation")
	_assert(ui._res_hold.is_empty(), "The deadline tick clears the hand-card holds too")
	_assert(ui._displayed_hand_count(1) == GameTypes.hand_total(st.players[1]["hand"]), "Displayed counts snap back to the real totals after the deadline")
	_pass_section("56. Steal Hold Deadline Test (a stuck animation cannot keep holds past its tick)")

func _numeric_label_count(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is Label:
			var t := (c as Label).text.strip_edges()
			if t.is_valid_int() or t == "empty":
				n += 1
		n += _numeric_label_count(c)
	return n


func _click_card(ui: Node, ctrl: Control) -> void:
	var root := ui.get_tree().root
	var center := root.get_screen_transform() * (ctrl.get_global_transform() * (ctrl.size * 0.5))
	var press_ev := InputEventMouseButton.new()
	press_ev.button_index = MOUSE_BUTTON_LEFT
	press_ev.pressed = true
	press_ev.position = center
	press_ev.global_position = center
	root.push_input(press_ev)
	var release_ev := InputEventMouseButton.new()
	release_ev.button_index = MOUSE_BUTTON_LEFT
	release_ev.pressed = false
	release_ev.position = center
	release_ev.global_position = center
	root.push_input(release_ev)

func _test_bank_pile_counts_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(778000, seats, true, 0)
	ui._refresh_ui()
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	var ok := true
	for r in GameTypes.ALL_RESOURCES:
		var bf: CardFace = ui._bank_faces[r]
		if int(bf.pile_count) != int(st.bank.get(r, 0)):
			ok = false
	_assert(ok, "Every bank pile shows the real card count as pile edges")
	_assert(int(ui._bank_deck_face.pile_count) == st.dev_deck.size(), "The deck pile mirrors the deck size")
	st.bank[GameTypes.ResourceType.FLEECE] = int(st.bank[GameTypes.ResourceType.FLEECE]) - 1
	var fleece_cnt := int(st.bank[GameTypes.ResourceType.FLEECE])
	ui._refresh_ui()
	var wface: CardFace = ui._bank_faces[GameTypes.ResourceType.FLEECE]
	_assert(int(wface.pile_count) == fleece_cnt, "Taking one card removes one edge line")
	_assert(wface.tooltip_text.contains(str(fleece_cnt)), "The hover tooltip keeps the exact number")
	_assert(ui._bank_deck_face.tooltip_text.begins_with("Action Cards left: ") and ui._bank_deck_face.tooltip_text.contains(str(st.dev_deck.size())), "The deck tooltip shows the exact deck count")
	var row_ok := true
	for r in GameTypes.ALL_RESOURCES:
		var bf2: CardFace = ui._bank_faces[r]
		if _numeric_label_count(bf2.get_parent().get_parent()) != 0:
			row_ok = false
	_assert(row_ok, "No plain number label is left in the bank row")
	_pass_section("57. Bank Pile Edges Test (one edge per card, exact count on hover, no numbers)")

func _test_card_click_trade_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(778001, seats, true, 0)
	var grain := GameTypes.ResourceType.GRAIN
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.players[0]["hand"] = {grain: 2}
	ui._trade_tray.visible = false
	ui._reset_trade_counts()
	ui._refresh_ui()
	_ui_queue.push_front(func() -> void:
		var face: CardFace = ui._res_card_refs[grain]
		_assert(face.size.x > 0.0, "The grain hand card has a real size before clicking")
		_assert(face.tooltip_text == "Click to offer in a trade", "A tradeable card invites the click: %s" % face.tooltip_text)
		_click_card(ui, face)
		_assert(bool(ui._trade_tray.visible), "Clicking a hand card opens the trade tray")
		_assert(int(ui._trade_give_counts.get(grain, 0)) == 1, "The clicked card goes onto the give side")
		_click_card(ui, face)
		_assert(int(ui._trade_give_counts.get(grain, 0)) == 2, "A second click offers a second grain")
		_click_card(ui, face)
		_assert(int(ui._trade_give_counts.get(grain, 0)) == 2, "The give side never exceeds the hand")
		ui._close_trade_tray_by_user()
		ui._refresh_ui()
		_assert(not bool(ui._trade_tray.visible), "Closing the tray works")
		st.phase = GameTypes.TurnPhase.TURN_ROLL
		ui._refresh_ui()
		_assert(face.tooltip_text == "Roll first", "Before rolling the tooltip says why: %s" % face.tooltip_text)
		_click_card(ui, face)
		_assert(not bool(ui._trade_tray.visible), "A click before rolling does not open the tray")
		st.phase = GameTypes.TurnPhase.TURN_DISCARD
		st.pending_discards[0] = 2
		ui._refresh_ui()
		_ui_queue.push_front(func() -> void:
			_click_card(ui, face)
			_assert(int(ui._discard_pick.get(grain, 0)) == 1, "In discard mode a click still picks a discard")
			_assert(not bool(ui._trade_tray.visible), "Discard mode clicks never open the trade tray")
			_pass_section("58. Card Click Trade Test (clicking a hand card opens the tray and offers it)")
		)
	)


func _test_trade_close_cross_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(778002, seats, true, 0)
	await ui.get_tree().process_frame
	ui._refresh_ui()
	_assert(ui._trade_close_btn.text == "✕", "The close button is just a cross, got %s" % ui._trade_close_btn.text)
	_assert(ui._trade_close_btn.tooltip_text.contains("Esc"), "The close tooltip still explains Esc")
	_assert(ui._trade_close_btn.custom_minimum_size == Vector2(22, 22), "The close button is a small square")
	_pass_section("59. Trade Close Cross Test (cross-only close button keeps its tooltip)")
func _test_card_redraw_setters_body(ui: Node) -> void:
	var f := CardFace.new()
	ui.add_child(f)
	await ui.get_tree().process_frame
	var n0: int = f.redraw_requests
	f.count = 3
	_assert(f.redraw_requests == n0 + 1, "A changed count asks for a redraw")
	f.count = 3
	_assert(f.redraw_requests == n0 + 1, "Re-setting the same count does not redraw")
	f.badge = 2
	f.badge = 2
	f.selected = true
	f.selected = true
	f.disabled = true
	f.disabled = true
	f.hidden_card = true
	f.hidden_card = true
	f.kind = "back"
	f.kind = "back"
	f.resource = 4
	f.resource = 4
	f.action = 1
	f.action = 1
	f.stack_depth = 2
	f.stack_depth = 2
	f.pile_low_tint = true
	f.pile_low_tint = true
	f.pile_count = 3
	f.pile_count = 3
	_assert(f.redraw_requests == n0 + 11, "Every visual property redraws once on change only, got %d new" % (f.redraw_requests - n0))
	f.count = 0
	_assert(int(f.count) == 0, "Count still stores through the setter")
	f.free()
	_pass_section("60. CardFace Redraw Setters Test (count and friends repaint when they change)")


func _flight_has(list: Array, from_id: int, to_id: int, res: int, n: int) -> bool:
	for tr in list:
		if int(tr["from"]) == from_id and int(tr["to"]) == to_id and int(tr["res"]) == res and int(tr["n"]) == n:
			return true
	return false


func _flight_touches(list: Array, pid: int) -> bool:
	for tr in list:
		if int(tr["from"]) == pid or int(tr["to"]) == pid:
			return true
	return false

func _test_flights_production_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779001, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	_assert(ui._last_flights.is_empty(), "The first update of a new match records no flights")
	var p0h: Dictionary = st.players[0]["hand"]
	var p1h: Dictionary = st.players[1]["hand"]
	p1h[GameTypes.ResourceType.GRAIN] = int(p1h.get(GameTypes.ResourceType.GRAIN, 0)) + 2
	st.bank[GameTypes.ResourceType.GRAIN] = int(st.bank[GameTypes.ResourceType.GRAIN]) - 2
	ui._on_state_updated(st, NO_EVENTS)
	_assert(_flight_has(ui._last_flights, -1, 1, GameTypes.ResourceType.GRAIN, 2), "Production: two Grain fly from the bank to player 1")
	p0h[GameTypes.ResourceType.TIMBER] = int(p0h.get(GameTypes.ResourceType.TIMBER, 0)) - 4
	st.bank[GameTypes.ResourceType.TIMBER] = int(st.bank.get(GameTypes.ResourceType.TIMBER, 0)) + 4
	p0h[GameTypes.ResourceType.GRAIN] = int(p0h.get(GameTypes.ResourceType.GRAIN, 0)) + 1
	st.bank[GameTypes.ResourceType.GRAIN] = int(st.bank.get(GameTypes.ResourceType.GRAIN, 0)) - 1
	ui._on_state_updated(st, NO_EVENTS)
	_assert(_flight_has(ui._last_flights, 0, -1, GameTypes.ResourceType.TIMBER, 4), "Bank trade: four Timber fly to the bank")
	_assert(_flight_has(ui._last_flights, -1, 0, GameTypes.ResourceType.GRAIN, 1), "Bank trade: one Grain flies back to the player")
	p0h[GameTypes.ResourceType.FLEECE] = int(p0h.get(GameTypes.ResourceType.FLEECE, 0)) + 1
	st.bank[GameTypes.ResourceType.FLEECE] = int(st.bank.get(GameTypes.ResourceType.FLEECE, 0)) - 1
	ui._on_state_updated(st, NO_EVENTS)
	p0h[GameTypes.ResourceType.FLEECE] = int(p0h[GameTypes.ResourceType.FLEECE]) - 1
	p1h[GameTypes.ResourceType.FLEECE] = int(p1h.get(GameTypes.ResourceType.FLEECE, 0)) + 1
	st.last_steal = {"serial": 777001, "thief": 1, "victim": 0, "res": GameTypes.ResourceType.FLEECE}
	ui._on_state_updated(st, NO_EVENTS)
	_assert(not _flight_has(ui._last_flights, 0, 1, GameTypes.ResourceType.FLEECE, 1), "A steal never lands in the general flight list")
	_pass_section("61. General Flights Test (production, bank trade and the steal exclusion)")

func _test_flights_build_trade_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779002, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	var p0h: Dictionary = st.players[0]["hand"]
	var p1h: Dictionary = st.players[1]["hand"]
	for r in [GameTypes.ResourceType.TIMBER, GameTypes.ResourceType.CLAY, GameTypes.ResourceType.GRAIN]:
		p0h[r] = int(p0h.get(r, 0)) + 2
		st.bank[r] = int(st.bank.get(r, 0)) - 2
	p1h[GameTypes.ResourceType.FLEECE] = int(p1h.get(GameTypes.ResourceType.FLEECE, 0)) + 1
	st.bank[GameTypes.ResourceType.FLEECE] = int(st.bank.get(GameTypes.ResourceType.FLEECE, 0)) - 1
	ui._on_state_updated(st, NO_EVENTS)
	p0h[GameTypes.ResourceType.TIMBER] = int(p0h[GameTypes.ResourceType.TIMBER]) - 1
	p0h[GameTypes.ResourceType.CLAY] = int(p0h[GameTypes.ResourceType.CLAY]) - 1
	st.bank[GameTypes.ResourceType.TIMBER] = int(st.bank.get(GameTypes.ResourceType.TIMBER, 0)) + 1
	st.bank[GameTypes.ResourceType.CLAY] = int(st.bank.get(GameTypes.ResourceType.CLAY, 0)) + 1
	ui._on_state_updated(st, NO_EVENTS)
	_assert(_flight_has(ui._last_flights, 0, -1, GameTypes.ResourceType.TIMBER, 1), "A road build flies one Timber to the bank")
	_assert(_flight_has(ui._last_flights, 0, -1, GameTypes.ResourceType.CLAY, 1), "A road build flies one Clay to the bank")
	p0h[GameTypes.ResourceType.GRAIN] = int(p0h[GameTypes.ResourceType.GRAIN]) - 1
	p1h[GameTypes.ResourceType.GRAIN] = int(p1h.get(GameTypes.ResourceType.GRAIN, 0)) + 1
	p1h[GameTypes.ResourceType.FLEECE] = int(p1h[GameTypes.ResourceType.FLEECE]) - 1
	p0h[GameTypes.ResourceType.FLEECE] = int(p0h.get(GameTypes.ResourceType.FLEECE, 0)) + 1
	ui._on_state_updated(st, NO_EVENTS)
	_assert(_flight_has(ui._last_flights, 0, 1, GameTypes.ResourceType.GRAIN, 1), "A player trade flies the given Grain A to B")
	_assert(_flight_has(ui._last_flights, 1, 0, GameTypes.ResourceType.FLEECE, 1), "A player trade flies the returned Fleece B to A")
	var bank_free := true
	for tr in ui._last_flights:
		if int(tr["from"]) == -1 or int(tr["to"]) == -1:
			bank_free = false
	_assert(bank_free, "A player trade involves no bank flight")
	_pass_section("62. Build and Player Trade Flights Test (player to bank builds, A to B trades)")

func _test_flight_layer_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779003, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	_assert(ui._flight_layer != null and is_instance_valid(ui._flight_layer), "The flight layer exists")
	ui._reduce_motion = true
	var p1h: Dictionary = st.players[1]["hand"]
	p1h[GameTypes.ResourceType.GRAIN] = int(p1h.get(GameTypes.ResourceType.GRAIN, 0)) + 2
	st.bank[GameTypes.ResourceType.GRAIN] = int(st.bank.get(GameTypes.ResourceType.GRAIN, 0)) - 2
	ui._on_state_updated(st, NO_EVENTS)
	_assert(not ui._last_flights.is_empty(), "Reduce motion still records the transfers")
	_assert(_flight_has(ui._last_flights, -1, 1, GameTypes.ResourceType.GRAIN, 2), "Reduce motion keeps the transfer data")
	_assert(int(ui._flight_layer.get_child_count()) == 0, "Reduce motion spawns no flyers")
	ui._reduce_motion = false
	var p0h: Dictionary = st.players[0]["hand"]
	p0h[GameTypes.ResourceType.CLAY] = int(p0h.get(GameTypes.ResourceType.CLAY, 0)) + 1
	st.bank[GameTypes.ResourceType.CLAY] = int(st.bank.get(GameTypes.ResourceType.CLAY, 0)) - 1
	ui._on_state_updated(st, NO_EVENTS)
	var flyer_seen := false
	for _i in range(30):
		await ui.get_tree().process_frame
		if int(ui._flight_layer.get_child_count()) >= 1:
			flyer_seen = true
			break
	_assert(flyer_seen, "A bank flight to the viewer puts a flyer on the layer")
	ui._start_match_from_lobby_settings()
	await ui.get_tree().process_frame
	_assert(int(ui._flight_layer.get_child_count()) == 0, "A new game clears every flyer")
	_assert(ui._last_flights.is_empty(), "A new game resets the recorded flights")
	_pass_section("63. Flight Layer Test (reduce motion records only; new game frees flyers)")

func _test_tray_bar_fit_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	root.size = Vector2i(1280, 800)
	ui.session.start_match(779004, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	var bar_closed := float(ui._hand_bar_panel.get_global_rect().end.y)
	_assert(bar_closed <= 800.5, "The hand bar fits a 1280x800 window with the tray closed, got bottom %.1f" % bar_closed)
	var dmin: Vector2 = ui._dice_widget.custom_minimum_size
	_assert(dmin.x >= 180.0, "The dice widget grew wider, got %s" % str(dmin))
	_assert(dmin.y >= 70.0, "The dice widget grew taller, got %s" % str(dmin))
	var bar_r: Rect2 = ui._hand_bar_panel.get_global_rect()
	var dice_r: Rect2 = ui._dice_widget.get_global_rect()
	_assert(bar_r.has_point(dice_r.position) and bar_r.has_point(dice_r.end), "The dice widget stays inside the bar: %s vs %s" % [str(dice_r), str(bar_r)])
	var win_r := Rect2(Vector2.ZERO, Vector2(root.size))
	_assert(win_r.grow(0.5).encloses(dice_r), "The dice widget is inside the window with the tray closed: %s" % str(dice_r))
	for r in GameTypes.ALL_RESOURCES:
		var fr: Rect2 = ui._res_card_refs[r].get_global_rect()
		_assert(bar_r.grow(0.5).encloses(fr), "Hand face %d fits inside the bar (tray closed): %s vs %s" % [r, str(fr), str(bar_r)])
		_assert(win_r.grow(0.5).encloses(fr), "Hand face %d fits inside the window (tray closed): %s" % [r, str(fr)])
	ui._toggle_trade_tray()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(bool(ui._trade_tray.visible), "The trade tray is open in propose mode")
	var bar_end := float(ui._hand_bar_panel.get_global_rect().end.y)
	_assert(bar_end <= 800.5, "The hand bar stays inside a 1280x800 window with the tray open, got bottom %.1f" % bar_end)
	var bar_r2: Rect2 = ui._hand_bar_panel.get_global_rect()
	_assert(win_r.grow(0.5).encloses(bar_r2), "The whole hand bar is inside the window with the tray open: %s" % str(bar_r2))
	for r in GameTypes.ALL_RESOURCES:
		var fr2: Rect2 = ui._res_card_refs[r].get_global_rect()
		_assert(bar_r2.grow(0.5).encloses(fr2), "Hand face %d fits inside the bar (tray open): %s vs %s" % [r, str(fr2), str(bar_r2)])
		_assert(win_r.grow(0.5).encloses(fr2), "Hand face %d fits inside the window (tray open): %s" % [r, str(fr2)])
	var dice_r2: Rect2 = ui._dice_widget.get_global_rect()
	_assert(bar_r2.grow(0.5).encloses(dice_r2) and win_r.grow(0.5).encloses(dice_r2), "The dice widget fits inside bar and window (tray open): %s" % str(dice_r2))
	# counters: both buttons of every counter card must be fully visible without scrolling
	var st2: GameState = ui.session.state
	st2.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 2
	st2.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	st2.players[2]["hand"][GameTypes.ResourceType.GRAIN] = 3
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	ui.session.submit_action(1, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.IRON: 2}, {GameTypes.ResourceType.GRAIN: 1}))
	ui.session.submit_action(2, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.IRON: 2}, {GameTypes.ResourceType.GRAIN: 1}))
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(ui._counter_cards_shown, "Counter cards should mark the tray")
	var tray_r: Rect2 = ui._trade_tray.get_global_rect()
	var scroll_r: Rect2 = ui._trade_scroll.get_global_rect()
	var accept_btn := _find_button_by_text(ui._trade_partner_stack, "Accept")
	_assert(accept_btn != null, "Counter cards carry an Accept counter button")
	for b in [accept_btn, _find_button_by_text(ui._trade_partner_stack, "Decline")]:
		var br: Rect2 = b.get_global_rect()
		_assert(tray_r.grow(0.5).encloses(br), "Button '%s' inside the tray rect: %s vs %s" % [b.text, str(br), str(tray_r)])
		_assert(scroll_r.grow(0.5).encloses(br), "Button '%s' inside the tray scroll area: %s vs %s" % [b.text, str(br), str(scroll_r)])
		var bar_r3: Rect2 = ui._hand_bar_panel.get_global_rect()
		_assert(bar_r3.end.y <= 800.5, "The bar still fits with counter cards open, got %.1f" % bar_r3.end.y)
		for r3 in GameTypes.ALL_RESOURCES:
			var fr3: Rect2 = ui._res_card_refs[r3].get_global_rect()
			_assert(win_r.grow(0.5).encloses(fr3) and bar_r3.grow(0.5).encloses(fr3), "Hand face %d fits with counter cards open: %s" % [r3, str(fr3)])
	root.size = Vector2i(64, 64)
	_pass_section("64. Tray Bar Fit Test (the bottom bar stays in the window with the tray open)")
func _test_counter_offer_card_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779065, seats, true, 0)
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 1
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2
	ui._refresh_ui()
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	ui.session.submit_action(1, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.IRON: 2}, {GameTypes.ResourceType.GRAIN: 1}))
	await ui.get_tree().process_frame
	_assert(ui._trade_partner_stack.get_child_count() == 1, "One partner card expected")
	var dcard: Node = ui._trade_partner_stack.get_child(0)
	_assert(_find_label_containing(dcard, "COUNTER-OFFER"), "Counter card should carry the COUNTER-OFFER pill")
	_assert(_find_label_containing(dcard, "You give"), "Counter card should show the 'You give' row")
	_assert(_find_label_containing(dcard, "You get"), "Counter card should show the 'You get' row")
	var accept_btn := _find_button_by_text(dcard, "Accept")
	_assert(accept_btn != null, "Counter card should offer an Accept counter button")
	_assert(_find_button_by_text(dcard, "Trade") == null, "Counter card must not show the plain Trade button")
	_assert(bool(accept_btn.disabled), "Accept counter should be disabled while the offer cannot be paid")
	_assert(str(accept_btn.tooltip_text).begins_with("You don't have"), "Disabled accept tooltip mismatch: '%s'" % str(accept_btn.tooltip_text))
	_assert(_toast_texts(ui).contains("Dune counters: gives 1 Grain, wants 2 Iron"), "Counter should toast once, got '%s'" % _toast_texts(ui))
	var tcount: int = _toast_texts(ui).count("Dune counters: gives 1 Grain, wants 2 Iron")
	ui._refresh_ui()
	ui._refresh_ui()
	_assert(_toast_texts(ui).count("Dune counters: gives 1 Grain, wants 2 Iron") == tcount, "One toast per counter only")
	var dline := _find_button_by_text(dcard, "Decline")
	_assert(dline != null, "Counter card should offer a Decline button")
	var g0: int = int(st.players[0]["hand"].get(GameTypes.ResourceType.GRAIN, 0))
	st.players[0]["hand"][GameTypes.ResourceType.IRON] = 3
	while ui.session.is_ai_to_act():
		ui.session.step_ai()  # the responder's review pass runs before the proposer
	ui._refresh_ui()
	await ui.get_tree().process_frame
	accept_btn = _find_button_by_text(ui._trade_partner_stack, "Accept")
	_assert(accept_btn != null and not bool(accept_btn.disabled), "Accept counter should enable once the offer can be paid")
	accept_btn.pressed.emit()
	await ui.get_tree().process_frame
	_assert(st.open_trade.is_empty(), "Accepting a counter should resolve the offer")
	_assert(int(st.players[0]["hand"].get(GameTypes.ResourceType.IRON, 0)) == 1, "Accepted counter must pay the iron")
	_assert(int(st.players[0]["hand"].get(GameTypes.ResourceType.GRAIN, 0)) == g0 + 1, "Accepted counter must deliver the grain")
	# second offer: decline keeps the offer open and hides the buttons
	ui.session.state.open_trades_this_turn = 0
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.FLEECE: 1}))
	ui.session.submit_action(1, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.IRON: 2}, {GameTypes.ResourceType.GRAIN: 1}))
	await ui.get_tree().process_frame
	var dcard2: Node = ui._trade_partner_stack.get_child(0)
	var dline2 := _find_button_by_text(dcard2, "Decline")
	_assert(dline2 != null, "Second counter card should offer Decline")
	dline2.pressed.emit()
	await ui.get_tree().process_frame
	_assert(not st.open_trade.is_empty(), "Declining a counter is UI-only; the offer stays open")
	_assert(_find_button_by_text(ui._trade_partner_stack, "Accept") == null, "Declined counter should drop the accept button")
	_assert(_find_label_containing(ui._trade_partner_stack, "✗ Counter declined"), "Declined counter should show its status")
	_assert(bool(ui._trade_no_takers_lbl.visible), "All counters declined should surface the no-takers line")
	ui.session.submit_action(0, GameAction.cancel_open_trade())
	_assert(not bool(ui._trade_no_takers_lbl.visible), "No-takers line clears when the offer closes")
	ui.session.state.open_trades_this_turn = 0
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.IRON: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	_assert(not ui.session.state.open_trade.is_empty(), "The fresh offer must be open")
	_assert(ui._declined_counters.is_empty(), "A new offer must clear declined counters")
	_assert(_find_button_by_text(ui._trade_partner_stack, "Accept") == null, "Fresh offer has no counter buttons")
	var st2: GameState = ui.session.state
	st2.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	ui.session.submit_action(1, GameAction.respond_open_trade("accept"))
	await ui.get_tree().process_frame
	_assert(_find_label_containing(ui._trade_partner_stack, "✓ Accepts"), "Accepting bot still shows ✓ Accepts")
	_assert(_find_button_by_text(ui._trade_partner_stack, "Trade") != null, "Accepting bot still shows the Trade button")
	_pass_section("65. Counter-Offer Card Test (pill, give/get rows, accept/decline, no-takers)")

func _test_dice_roll_show_body(ui: Node) -> void:
	# a real click must interrupt the previous player's show and roll at once
	var seats2: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779099, seats2, true, 0)
	var stx: GameState = ui.session.state
	stx.current_player = 1
	stx.phase = GameTypes.TurnPhase.TURN_ROLL
	ui._start_dice_show(4, 5, 1.5)
	_assert(bool(ui._dice_show_active), "A bot roll show is running")
	_assert(int(ui._dice_show_seat) == 1, "The show remembers the bot's seat, got %d" % int(ui._dice_show_seat))
	stx.current_player = 0
	stx.phase = GameTypes.TurnPhase.TURN_ROLL
	ui._refresh_ui()
	var shows_before: int = int(ui._dice_show_count)
	var click_c: Vector2 = root.get_screen_transform() * (ui._dice_widget.get_global_transform() * (ui._dice_widget.size * 0.5))
	var mp := InputEventMouseButton.new()
	mp.button_index = MOUSE_BUTTON_LEFT
	mp.pressed = true
	mp.position = click_c
	mp.global_position = click_c
	root.push_input(mp)
	var mr := InputEventMouseButton.new()
	mr.button_index = MOUSE_BUTTON_LEFT
	mr.pressed = false
	mr.position = click_c
	mr.global_position = click_c
	root.push_input(mr)
	_assert(stx.phase != GameTypes.TurnPhase.TURN_ROLL, "A click during the previous show still rolls, phase stayed '%s'" % str(stx.phase))
	_assert(int(ui._dice_show_count) == shows_before + 1, "The click interrupted and restarted the show, got %d vs %d" % [int(ui._dice_show_count), shows_before + 1])
	_assert(bool(ui._dice_show_active), "The new show is running after the click roll")
	_assert(ui._flight_layer.get_child_count() == 1, "Exactly one show node after a click interrupt, got %d" % ui._flight_layer.get_child_count())
	ui._finish_dice_show()
	# the same via a real Space key event
	stx.phase = GameTypes.TurnPhase.TURN_ROLL
	ui._refresh_ui()
	ui._start_dice_show(2, 2, 1.5)
	var shows_b2: int = int(ui._dice_show_count)
	var sp := InputEventKey.new()
	sp.keycode = KEY_SPACE
	sp.pressed = true
	root.push_input(sp)
	var sp_up := InputEventKey.new()
	sp_up.keycode = KEY_SPACE
	sp_up.pressed = false
	root.push_input(sp_up)
	_assert(stx.phase != GameTypes.TurnPhase.TURN_ROLL, "Space during the previous show still rolls, phase stayed '%s'" % str(stx.phase))
	_assert(int(ui._dice_show_count) == shows_b2 + 1, "Space restarted the show, got %d vs %d" % [int(ui._dice_show_count), shows_b2 + 1])
	_assert(ui._flight_layer.get_child_count() == 1, "Exactly one show node after a Space interrupt, got %d" % ui._flight_layer.get_child_count())
	ui._finish_dice_show()
	# a turn change during the hold cuts straight into a short return
	stx.current_player = 1
	stx.phase = GameTypes.TurnPhase.TURN_ROLL
	ui._start_dice_show(3, 3, 1.5)
	ui._advance_dice_show(1.30)
	_assert(str(ui._dice_show_phase) == "hold", "Show is holding before the turn change, got '%s'" % str(ui._dice_show_phase))
	stx.current_player = 0
	var noev: Array[String] = []
	ui._on_state_updated(stx, noev)
	ui._advance_dice_show(0.01)
	_assert(str(ui._dice_show_phase) == "return", "The turn change cuts the hold into return, got '%s'" % str(ui._dice_show_phase))
	ui._advance_dice_show(0.3)
	_assert(not bool(ui._dice_show_active), "The cut show ends 0.25 s into the return")
	_assert(ui._flight_layer.get_child_count() == 0, "The cut show leaves no node behind")
	var shows0 := int(ui._dice_show_count)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779066, seats, true, 0)
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	ui._refresh_ui()
	await ui.get_tree().process_frame
	st.last_dice = Vector2i(3, 4)
	var evs: Array[String] = ["Azure rolled 3 and 4."]
	ui._on_state_updated(st, evs)
	_assert(bool(ui._dice_show_active), "A roll triggers the dice show")
	_assert(int(ui._dice_show_count) == shows0 + 1, "First show counted, got %d vs %d" % [int(ui._dice_show_count), shows0 + 1])
	_assert(str(ui._dice_show_phase) == "throw", "Show starts in throw, got '%s'" % str(ui._dice_show_phase))
	_assert(ui._dice_show_node != null and ui._dice_show_node.get_parent() == ui._flight_layer, "Travelling dice live on the flight layer")
	_assert(ui._flight_layer.get_child_count() == 1, "Exactly one moving dice node, got %d" % ui._flight_layer.get_child_count())
	_assert(not bool(ui._dice_widget.total_visible), "The total pill hides during the show")
	_assert(not bool(ui._dice_total_visible), "The bar reports no total during the show")
	_assert(str(ui._dice_widget.pill_text()) != "7", "The pill does not show the total while hidden, got '%s'" % str(ui._dice_widget.pill_text()))
	ui._advance_dice_show(0.3)
	_assert(str(ui._dice_show_phase) == "throw", "0.30 s is still the throw arc, got '%s'" % str(ui._dice_show_phase))
	ui._advance_dice_show(0.2)
	_assert(str(ui._dice_show_phase) == "bounce", "0.50 s lands into the bounce, got '%s'" % str(ui._dice_show_phase))
	ui._advance_dice_show(0.5)
	_assert(str(ui._dice_show_phase) == "settle", "1.00 s eases upright in settle, got '%s'" % str(ui._dice_show_phase))
	ui._advance_dice_show(0.15)
	_assert(str(ui._dice_show_phase) == "hold", "1.15 s holds the pair large, got '%s'" % str(ui._dice_show_phase))
	_assert(not bool(ui._dice_widget.total_visible), "The total stays hidden during the hold")
	_assert(not bool(ui._dice_total_visible), "The bar reports no total during the hold")
	_assert(str(ui._dice_widget.pill_text()) != "7", "The hold pill is not the total, got '%s'" % str(ui._dice_widget.pill_text()))
	_assert(int(ui._dice_widget.d1) + int(ui._dice_widget.d2) != 7, "The bar dice do not show the rolled values during the hold")
	ui._advance_dice_show(1.5)
	_assert(str(ui._dice_show_phase) == "return", "After the hold the dice fly home, got '%s'" % str(ui._dice_show_phase))
	_assert(not bool(ui._dice_widget.total_visible), "The total stays hidden during the return")
	_assert(str(ui._dice_widget.pill_text()) != "7", "The return pill is not the total, got '%s'" % str(ui._dice_widget.pill_text()))
	_assert(int(ui._dice_widget.d1) + int(ui._dice_widget.d2) != 7, "The bar dice do not show the rolled values during the return")
	ui._advance_dice_show(0.45)
	_assert(not bool(ui._dice_show_active), "The show ends itself after the return")
	_assert(bool(ui._dice_widget.total_visible), "The pill pops in when the dice land back in the bar")
	_assert(bool(ui._dice_total_visible), "The bar reports a visible total after the return")
	_assert(str(ui._dice_widget.pill_text()) == "7", "The pill shows the rolled total 7, got '%s'" % str(ui._dice_widget.pill_text()))
	_assert(int(ui._dice_widget.d1) == 3 and int(ui._dice_widget.d2) == 4, "The bar dice show the rolled 3 and 4, got %d/%d" % [int(ui._dice_widget.d1), int(ui._dice_widget.d2)])
	_assert(float(ui._dice_widget.pill_pop_t) >= 0.0, "The pill starts its pop on landing")
	_assert(str(ui._dice_show_phase) == "", "A finished show clears its phase")
	_assert(ui._flight_layer.get_child_count() == 0, "A self-finished show frees its dice node, got %d" % ui._flight_layer.get_child_count())
	_assert(bool(ui._dice_widget.total_visible), "The bar keeps the total after a self-finished show")
	_assert(not bool(ui._dice_show_active), "finish_dice_show deactivates the show")
	_assert(str(ui._dice_show_phase) == "", "finish_dice_show clears the phase")
	_assert(ui._flight_layer.get_child_count() == 0, "finish_dice_show leaves no dice node on the flight layer")
	_assert(ui._dice_widget.modulate.a > 0.9, "Bar dice become visible again")
	_assert(bool(ui._dice_widget.total_visible), "finish_dice_show restores the total pill")
	st.last_dice = Vector2i(5, 6)
	ui._start_dice_roll_fx(st)
	st.last_dice = Vector2i(6, 6)
	ui._start_dice_roll_fx(st)
	_assert(int(ui._dice_show_count) == shows0 + 3, "A new roll restarts the show (3 more starts), got %d vs %d" % [int(ui._dice_show_count), shows0 + 3])
	_assert(ui._flight_layer.get_child_count() == 1, "Never more than one moving dice node, got %d" % ui._flight_layer.get_child_count())
	ui._reset_flight_state()
	_assert(not bool(ui._dice_show_active), "New game/lobby reset ends the show")
	_assert(ui._flight_layer.get_child_count() == 0, "Reset frees the travelling dice")
	ui._reduce_motion = true
	ui._start_dice_roll_fx(st)
	_assert(int(ui._dice_show_count) == shows0 + 3, "Reduce motion skips the show entirely")
	_assert(not bool(ui._dice_show_active), "Reduce motion keeps the show inactive")
	_assert(int(ui._dice_widget.d1) == 6 and int(ui._dice_widget.d2) == 6, "Bar dice show the latest value immediately, got %d/%d" % [int(ui._dice_widget.d1), int(ui._dice_widget.d2)])
	_assert(bool(ui._dice_widget.total_visible) and bool(ui._dice_total_visible), "Reduce motion keeps the total visible")
	_assert(str(ui._dice_widget.pill_text()) == "12", "Reduce motion shows the real total at once, got '%s'" % str(ui._dice_widget.pill_text()))
	ui._reduce_motion = false
	_pass_section("66. Dice Roll Show Test (phases, finish, preempt, reduce motion, roll-during-show)")

func _test_badge_bounds_body(ui: Node) -> void:
	var f := CardFace.new()
	f.size = Vector2(62, 68)
	f.kind = "resource"
	f.resource = GameTypes.ResourceType.GRAIN
	_assert(f.badge_bounds().is_empty(), "A plain card has no badges")
	f.count = 12
	var bounds: Array = f.badge_bounds()
	_assert(bounds.size() == 1, "Count badge should report one bound, got %d" % bounds.size())
	var host := Rect2(Vector2.ZERO, f.size)
	var bc0: Rect2 = bounds[0]
	_assert(host.grow(-1.9).encloses(bc0), "A wide card keeps its badge fully inside the control with 2px margin, got %s vs %s" % [str(bc0), str(host)])
	f._hover = true
	_assert(host.grow(-1.9).encloses(f.badge_bounds()[0] as Rect2), "Hover lift keeps the badge inside")
	f._hover = false
	f.selected = true
	_assert(host.grow(-1.9).encloses(f.badge_bounds()[0] as Rect2), "Selected lift keeps the badge inside")
	f.selected = false
	var small := CardFace.new()
	small.size = Vector2(36, 34)
	small.kind = "resource"
	small.resource = GameTypes.ResourceType.CLAY
	small.show_name = false
	small.count = 3
	var shost := Rect2(Vector2.ZERO, small.size)
	var sb: Rect2 = small.count_badge_rect()
	_assert(shost.grow(-1.9).encloses(sb), "A trade-size badge circle stays inside its control with 2px margin, got %s vs %s" % [str(sb), str(shost)])
	_assert(shost.encloses(small.badge_bounds()[0] as Rect2), "Small badge bounds (arc allowance) stay inside the control")
	var scr := small._card_rect()
	var sec := sb.get_center()
	var rr := sb.size.x * 0.5
	_assert(absf(sec.x - minf(scr.end.x, 36.0 - rr - 2.0)) < 0.01 and absf(sec.y - maxf(scr.position.y, rr + 2.0)) < 0.01, "Small badge hugs the card corner but clamps inside the control, got %s" % str(sec))
	small._hover = true
	_assert(shost.grow(-1.9).encloses(small.count_badge_rect()), "Small badge inside on hover lift")
	small._hover = false
	small.selected = true
	_assert(shost.grow(-1.9).encloses(small.count_badge_rect()), "Small badge inside on selected lift")
	small.selected = false
	small.free()
	f.badge = 3
	bounds = f.badge_bounds()
	_assert(bounds.size() == 2, "Count and discard badges report two bounds, got %d" % bounds.size())
	var db := bounds[1] as Rect2
	_assert(host.encloses(db), "Discard badge stays inside the control, got %s vs %s" % [str(db), str(host)])
	f.count_badge = false
	f.count = 0
	f.badge = 4
	bounds = f.badge_bounds()
	_assert(bounds.size() == 1, "Discard badge alone reports one bound")
	_assert(host.encloses(bounds[0] as Rect2), "Discard badge stays inside the control")
	f.free()
	_pass_section("67. CardFace Badge Bounds Test (count and discard badges never clipped)")

func _test_stepper_labels_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779068, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 3
	ui._refresh_ui()
	_assert(not ui.has_method("_build_trade_stepper"), "The stepper builder is gone")
	_assert(not ui.has_method("_update_trade_stepper_labels"), "The stepper label refresh is gone")
	var abbrev_found := false
	for c2 in ui._trade_tray.find_children("*", "Label", true, false):
		if (c2 as Label).text == "GRA":
			abbrev_found = true
	_assert(not abbrev_found, "No TIM/CLA abbreviation labels remain in the tray")
	ui._on_resource_card_pressed(GameTypes.ResourceType.GRAIN)
	ui._on_resource_card_pressed(GameTypes.ResourceType.GRAIN)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(bool(ui._trade_tray.visible), "Clicking a hand card opens the tray")
	var give_chips: Array = ui._trade_give_box.get_children()
	var grain_chip: CardFace = null
	for c3 in give_chips:
		if c3 is CardFace and bool((c3 as CardFace).visible) and int((c3 as CardFace).resource) == GameTypes.ResourceType.GRAIN:
			grain_chip = c3 as CardFace
	_assert(grain_chip != null, "A chip for Grain shows in the give row")
	_assert(int(grain_chip.count) == 2, "The give chip carries the count 2, got %d" % int(grain_chip.count))
	st.players[0]["hand"][GameTypes.ResourceType.CLAY] = 2
	var clay_face: CardFace = ui._trade_get_faces[GameTypes.ResourceType.CLAY]
	_assert(bool(clay_face.vivid), "The get faces are shown at normal brightness, not dimmed")
	clay_face.pressed.emit()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var sel_clay: CardFace = ui._trade_get_faces[GameTypes.ResourceType.CLAY]
	_assert(bool(sel_clay.selected), "The chosen get card shows the selected state")
	_assert(int(sel_clay.count) == 1, "The chosen get card shows count 1")
	_assert(bool(sel_clay.count_badge), "A single chosen card wears its x1 badge")
	_assert(int(sel_clay.custom_minimum_size.x) >= 36, "The get card faces are at least 36 px wide")
	sel_clay.pressed.emit()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var more_clay: CardFace = ui._trade_get_faces[GameTypes.ResourceType.CLAY]
	_assert(int(more_clay.count) == 2, "Clicking a chosen card adds one more")
	_assert(bool(more_clay.count_badge), "Two of a kind wear the count badge")
	more_clay.right_pressed.emit()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var back_clay: CardFace = ui._trade_get_faces[GameTypes.ResourceType.CLAY]
	_assert(int(back_clay.count) == 1, "Right-click takes one back")
	_assert(bool(back_clay.count_badge), "Back to one card, the x1 badge stays on")
	back_clay.right_pressed.emit()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var zero_clay: CardFace = ui._trade_get_faces[GameTypes.ResourceType.CLAY]
	_assert(not bool(zero_clay.selected) and int(zero_clay.count) == 0, "Taking the last one clears the selection")
	var fresh_chip: CardFace = null
	for c4 in ui._trade_give_box.get_children():
		if c4 is CardFace and int((c4 as CardFace).resource) == GameTypes.ResourceType.GRAIN:
			fresh_chip = c4 as CardFace
	_assert(fresh_chip != null, "A fresh grain chip exists after the rebuild")
	fresh_chip.count_pressed.emit()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(int(ui._trade_give_counts.get(GameTypes.ResourceType.GRAIN, 0)) == 1, "Tapping the give chip's count takes one card back")
	ui._close_trade_tray_by_user()
	_pass_section("68. Trade Card Rows Test (chips add and take back, no steppers, no abbreviations)")

func _test_small_buttons_body(ui: Node) -> void:
	var seats78: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779078, seats78, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(ui._end_turn_btn.icon != null, "The End Turn button carries an icon")
	_assert(str(ui._end_turn_btn.text) == "End Turn", "The End Turn button keeps its text")
	_assert(str(ui._log_toggle_btn.text) == "", "The log toggle shows no text")
	_assert(ui._log_toggle_btn.icon != null, "The log toggle carries a chevron icon")
	_assert(str(ui._log_toggle_btn.tooltip_text) == "Show the full log", "Collapsed tooltip says Show the full log")
	_assert(ui._log_toggle_btn.custom_minimum_size == Vector2(28, 28), "The log toggle is a 28 px square")
	var icon_before: Texture2D = ui._log_toggle_btn.icon
	ui._log_toggle_btn.button_pressed = true
	ui._log_toggle_btn.toggled.emit(true)
	await ui.get_tree().process_frame
	_assert(ui._log_toggle_btn.icon != null and ui._log_toggle_btn.icon != icon_before, "Expanded state swaps to the other chevron")
	_assert(str(ui._log_toggle_btn.tooltip_text) == "Hide the log", "Expanded tooltip says Hide the log")
	ui._log_toggle_btn.button_pressed = false
	ui._log_toggle_btn.toggled.emit(false)
	await ui.get_tree().process_frame
	_assert(ui._log_toggle_btn.icon == icon_before, "Collapsing restores the down chevron")
	_pass_section("78. Small Buttons Test (End Turn icon, chevron log toggle)")

func _test_action_card_help_body(ui: Node) -> void:
	var scr: GDScript = load(UI_SCRIPT_PATH)
	var help_map: Dictionary = scr.get_script_constant_map().get("DEV_CARD_HELP", {})
	var types: Array[int] = [
		GameTypes.DevCardType.GUARD,
		GameTypes.DevCardType.ROAD_WORK,
		GameTypes.DevCardType.HARVEST_BOUNTY,
		GameTypes.DevCardType.TRADE_DECREE,
		GameTypes.DevCardType.CHARTER_POINT,
	]
	_assert(help_map.size() == 5, "DEV_CARD_HELP covers all five Action Cards")
	for t_id in types:
		_assert(str(help_map.get(t_id, "")).length() > 10, "Help sentence for %d is non-empty" % t_id)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779077, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["dev_cards"] = types.duplicate()
	ui._refresh_ui()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	for t_id in types:
		var chip: CardFace = ui._action_chips.get(t_id, null)
		_assert(chip != null, "Chip exists for card %d" % t_id)
		_assert(str(chip.tooltip_text).contains(str(help_map[t_id])), "Chip tooltip for %d contains its rule" % t_id)
	st.phase = GameTypes.TurnPhase.TURN_ROLL
	ui._refresh_ui()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var road_chip: CardFace = ui._action_chips[GameTypes.DevCardType.ROAD_WORK]
	_assert(
		str(road_chip.tooltip_text).contains("main turn") or str(road_chip.tooltip_text).contains("Only a Guard"),
		"The chip tooltip adds the current reason when the card cannot be played"
	)
	_assert(str(road_chip.tooltip_text).contains(str(help_map[GameTypes.DevCardType.ROAD_WORK])), "The rule stays in the tooltip with the reason")
	_pass_section("77. Action Card Help Test (one sentence per card, chip tooltips, reasons)")

func _test_scoreboard_columns_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_HARD, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ivory"),
	]
	ui.session.start_match(779076, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["dev_cards"] = [GameTypes.DevCardType.CHARTER_POINT, GameTypes.DevCardType.CHARTER_POINT]
	st.players[1]["played_dev"][GameTypes.DevCardType.GUARD] = 2
	st.players[1]["played_dev"][GameTypes.DevCardType.ROAD_WORK] = 1
	st.players[1]["played_guards"] = 2
	st.largest_guard_holder = 1
	st.players[2]["played_dev"][GameTypes.DevCardType.TRADE_DECREE] = 1
	st.players[2]["longest_route_length"] = 5
	st.longest_route_holder = 2
	ui._refresh_ui()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var col_xs: Array = []
	for pid in range(4):
		var card: Control = ui._scoreboard_row_panels[pid]
		var row: HBoxContainer = card.get_child(0)
		_assert(row.get_child_count() >= 6, "Row %d has the six fixed columns, got %d" % [pid, row.get_child_count()])
		var xs: Array[int] = []
		for i in range(5):
			xs.append(int(round((row.get_child(i) as Control).get_global_position().x)))
		col_xs.append(xs)
		var rr := row.get_global_rect()
		for c in row.get_children():
			var cr: Rect2 = (c as Control).get_global_rect()
			_assert(cr.position.x >= rr.position.x - 1.0 and cr.end.x <= rr.end.x + 1.0,
				"Row %d child %d stays inside the row at 1280x800: %s vs %s" % [pid, c.get_index(), str(cr), str(rr)])
	for i in range(5):
		for pid in range(1, 4):
			_assert(absi(int(col_xs[pid][i]) - int(col_xs[0][i])) <= 1,
				"Column %d aligns across rows: seat 0 at %d, seat %d at %d" % [i, int(col_xs[0][i]), pid, int(col_xs[pid][i])])
	var badge_wrap0: Control = (ui._scoreboard_row_panels[0] as Control).get_child(0).get_child(0)
	var badge0: Label = badge_wrap0.get_child(0)
	_assert(str(badge0.text).contains("(+2)"), "The viewer badge shows hidden points: %s" % str(badge0.text))
	_assert(str(badge0.tooltip_text).contains("hidden (Charter cards)"), "The viewer badge tooltip explains the hidden points")
	for pid in range(1, 4):
		var badge: Label = (ui._scoreboard_row_panels[pid] as Control).get_child(0).get_child(0).get_child(0)
		_assert(not str(badge.text).contains("(+"), "Seat %d shows no hidden points: %s" % [pid, str(badge.text)])
		_assert(str(badge.text) == str(int(st.get_victory_points(pid, false))), "Seat %d badge shows public VP only" % pid)
	_assert(int(badge_wrap0.custom_minimum_size.x) >= 34, "The VP badge cell keeps a 34 px minimum width")
	var pc1: HBoxContainer = ui._scoreboard_played[1]
	_assert(pc1.get_child_count() == 3, "Seat 1 shows Guard and Road Work glyphs plus the Guard pill, got %d" % pc1.get_child_count())
	_assert(str((pc1.get_child(2).get_child(0) as Label).text) == "Guard +2", "The Guard award pill trails the glyphs")
	_assert(str(pc1.get_child(0).tooltip_text) == "Guards played: 2", "Guard glyph tooltip states the count")
	_assert(pc1.get_child(0) is PanelContainer, "The Guard glyph is highlighted for the Guard +2 holder")
	_assert(str(pc1.get_child(1).tooltip_text) == "Road Work played: 1", "Road Work glyph tooltip states the count")
	var pc2: HBoxContainer = ui._scoreboard_played[2]
	_assert(pc2.get_child_count() == 3, "Seat 2 shows Decree and route glyphs plus the Route pill, got %d" % pc2.get_child_count())
	var route_tip := ""
	for c in pc2.get_children():
		if str(c.tooltip_text).contains("Longest route"):
			route_tip = str(c.tooltip_text)
	_assert(route_tip == "Longest route: 5 roads", "The route glyph tooltip states the length")
	_assert(pc2.get_children()[1] is PanelContainer, "The route glyph is highlighted for the Route +2 holder")
	var pc3: HBoxContainer = ui._scoreboard_played[3]
	_assert(pc3.get_child_count() == 0, "A fresh player shows no played glyphs")
	_pass_section("76. Scoreboard Columns Test (fixed columns, VP badge, played icons, no overflow)")

func _test_token_layout_body(ui: Node) -> void:
	var bv := BoardView.new()
	_assert(str(bv.hex_style) == "rich", "Rich landscape is the default hex style")
	_assert(str(bv.token_style) == "classic", "Classic token style is the default")
	var nums: Array[int] = [2, 3, 4, 5, 6, 8, 9, 10, 11, 12]
	var radii: Array[float] = [40.0, 60.0, 90.0]
	for style in BoardView.TOKEN_STYLES:
		for num in nums:
			for hr in radii:
				var tl: Dictionary = bv.token_layout(num, hr, style)
				var disc_r := float(tl["disc_r"])
				var pip_r := float(tl["pip_r"])
				for p in (tl["pips"] as Array):
					var pp: Vector2 = p
					_assert(pp.length() + pip_r <= disc_r * 0.88 + 0.06, "Pip of %d overflows the %s disc at R=%s: %.2f + %.2f > %.2f" % [num, style, str(hr), pp.length(), pip_r, disc_r * 0.88])
	var d6: float = (bv.token_layout(6, 60.0, "odds") as Dictionary)["disc_r"]
	var d5: float = (bv.token_layout(5, 60.0, "odds") as Dictionary)["disc_r"]
	var d4: float = (bv.token_layout(4, 60.0, "odds") as Dictionary)["disc_r"]
	var d3: float = (bv.token_layout(3, 60.0, "odds") as Dictionary)["disc_r"]
	var d2: float = (bv.token_layout(2, 60.0, "odds") as Dictionary)["disc_r"]
	_assert(d6 > d5 and d5 > d4 and d4 > d3 and d3 > d2, "Odds discs must grow with the pip count: %s %s %s %s %s" % [str(d2), str(d3), str(d4), str(d5), str(d6)])
	bv.hex_style = "nonsense"
	_assert(str(bv.hex_style) == "rich", "An unknown hex style falls back to rich")
	var want: Array[String] = ["rich", "classic"]
	var got: Array[String] = []
	for s in BoardView.HEX_STYLES:
		got.append(str(s))
	_assert(got == want, "HEX_STYLES is exactly rich and classic, got %s" % str(got))
	bv.free()
	_pass_section("69. Token Layout Test (pip padding in every style, odds scaling)")

func _test_board_styles_ui_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779070, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(str(ui._board_view.hex_style) == "rich", "The board starts with rich hexes")
	_assert(str(ui._board_view.token_style) == "classic", "The board starts with classic tokens")
	for hs in BoardView.HEX_STYLES:
		ui._board_view.hex_style = hs
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		_assert(str(ui._board_view.hex_style) == str(hs), "Hex style '%s' reads back after redraws" % str(hs))
	for ts in BoardView.TOKEN_STYLES:
		ui._board_view.token_style = ts
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		_assert(str(ui._board_view.token_style) == str(ts), "Token style '%s' reads back after redraws" % str(ts))
	ui._hex_style = "classic"
	ui._token_style = "bold"
	ui._save_settings()
	ui._hex_style = "rich"
	ui._token_style = "classic"
	ui._load_settings()
	_assert(str(ui._hex_style) == "classic", "hex_style must persist through save/load")
	_assert(str(ui._token_style) == "bold", "token_style must persist through save/load")
	ui._apply_settings()
	_assert(str(ui._board_view.hex_style) == "classic", "Applied settings reach the board view")
	_assert(str(ui._board_view.token_style) == "bold", "Applied token settings reach the board view")
	_assert(ui._settings_hex_opt.get_selected_id() == BoardView.HEX_STYLES.find("classic"), "The hex dropdown reflects the loaded style")
	_assert(ui._settings_token_opt.get_selected_id() == BoardView.TOKEN_STYLES.find("bold"), "The token dropdown reflects the loaded style")
	ui._hex_style = "rich"
	ui._token_style = "classic"
	ui._save_settings()
	_pass_section("70. Board Style Settings Test (styles apply live, persist, dropdowns sync)")

static func _pt_in_hex(p: Vector2, poly: PackedVector2Array, tol: float) -> bool:
	var sgn := 0
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var c := (b - a).cross(p - a)
		if c > tol:
			if sgn < 0:
				return false
			sgn = 1
		elif c < -tol:
			if sgn > 0:
				return false
			sgn = -1
	return true

func _test_style_defaults_body(ui: Node) -> void:
	var fresh := BoardView.new()
	_assert(str(fresh.hex_style) == "rich", "A fresh board view defaults to rich")
	fresh.hex_style = "nonsense"
	_assert(str(fresh.hex_style) == "rich", "The board setter rejects unknown styles to rich")
	fresh.free()
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779071, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	for hs in BoardView.HEX_STYLES:
		ui._board_view.hex_style = hs
		ui._board_view.notification(Control.NOTIFICATION_DRAW)
		_assert(str(ui._board_view.hex_style) == str(hs), "Style %s draws and reads back" % str(hs))
	ui._board_view.hex_style = "rich"
	var hexp: PackedVector2Array = ui._board_view._hex_poly(Vector2(120, 90), 40.0)
	var big := PackedVector2Array([Vector2(80, 50), Vector2(160, 50), Vector2(160, 130), Vector2(80, 130)])
	var parts: Array = ui._board_view._clip_shape(big, hexp)
	_assert(parts.size() >= 1, "Clipping a rect bigger than the hex returns polygons")
	var clipped_inside := true
	var total_pts := 0
	for part in parts:
		for p in (part as PackedVector2Array):
			total_pts += 1
			if not _pt_in_hex(p, hexp, 0.5):
				clipped_inside = false
	_assert(total_pts >= 3, "The clipped polygons carry points")
	_assert(clipped_inside, "Every clipped point stays inside the hex (tol 0.5)")
	var cfg := ConfigFile.new()
	var sp: String = load(UI_SCRIPT_PATH).settings_path
	cfg.load(sp)
	cfg.set_value("settings", "tile_layout", "chip_low")
	cfg.set_value("settings", "tile_gap", 0.04)
	cfg.set_value("settings", "board_fill", 1.15)
	cfg.set_value("settings", "hex_style", "classic")
	cfg.set_value("settings", "token_style", "odds")
	cfg.save(sp)
	ui._load_settings()
	_assert(str(ui._hex_style) == "classic", "An old settings file still loads hex_style")
	_assert(str(ui._token_style) == "odds", "An old settings file still loads token_style")
	_assert(ui.get("_tile_layout") == null, "tile_layout is gone from the UI")
	_assert(ui.get("_tile_gap") == null, "tile_gap is gone from the UI")
	_assert(ui.get("_board_fill") == null, "board_fill is gone from the UI")
	_assert(ui._board_view.get("tile_layout") == null, "tile_layout is gone from the board view")
	_assert(ui._board_view.get("tile_gap") == null, "tile_gap is gone from the board view")
	_assert(ui._board_view.get("board_fill") == null, "board_fill is gone from the board view")
	ui._apply_settings()
	ui._board_view.notification(Control.NOTIFICATION_DRAW)
	_assert(str(ui._board_view.hex_style) == "classic", "The loaded hex style applies to the board")
	_assert(str(ui._board_view.token_style) == "odds", "The loaded token style applies to the board")
	_assert(ui._settings_hex_opt.get_selected_id() == BoardView.HEX_STYLES.find("classic"), "The hex dropdown syncs from an old settings file")
	cfg.load(sp)
	cfg.set_value("settings", "hex_style", "scenes")
	cfg.save(sp)
	ui._load_settings()
	_assert(str(ui._hex_style) == "rich", "An unknown saved hex style loads as rich")
	ui._hex_style = "rich"
	ui._token_style = "classic"
	ui._save_settings()
	ui._apply_settings()
	_pass_section("71. Board Style Defaults Test (rich default, unknown fallback, clipping, old keys ignored)")

func _test_start_player_rotation() -> void:
	var seen := {}
	for s in range(40):
		var st := GameState.create_new_game(3000 + s, 4, true)
		_assert(st.start_player >= 0 and st.start_player < 4, "Start player %d is inside 4 seats" % st.start_player)
		_assert(st.current_player == st.start_player, "Seat %d is the first to act" % st.start_player)
		seen[st.start_player] = true
	for p in range(4):
		_assert(seen.has(p), "Seat %d starts at least once over 40 seeds" % p)
	var a := GameState.create_new_game(4242, 4, true)
	var b := GameState.create_new_game(4242, 4, true)
	_assert(a.start_player == b.start_player, "The same seed keeps the same start player")
	var base_terr := {
		1: [2, 0, 4, 1, 2, 0, 0, 3, 4, 1, 1, 3, 2, 5, 2, 3, 4, 0, 3],
		7: [0, 2, 0, 4, 1, 2, 3, 4, 3, 5, 0, 2, 2, 4, 1, 1, 3, 0, 3],
		777: [3, 1, 4, 1, 4, 2, 0, 0, 3, 2, 0, 4, 3, 1, 3, 2, 0, 2, 5],
	}
	var base_num := {
		1: [10, 6, 11, 4, 11, 2, 3, 9, 5, 10, 8, 9, 8, 0, 12, 3, 5, 6, 4],
		7: [11, 6, 4, 3, 5, 10, 12, 10, 5, 0, 9, 8, 11, 2, 9, 3, 8, 4, 6],
		777: [11, 6, 10, 10, 5, 11, 3, 2, 6, 12, 9, 8, 4, 9, 3, 5, 8, 4, 0],
	}
	for seed_val in [1, 7, 777]:
		var st2 := GameState.create_new_game(seed_val, 4, true)
		_assert(st2.tile_terrains == base_terr[seed_val], "Seed %d keeps the old terrain ring" % seed_val)
		_assert(st2.tile_numbers == base_num[seed_val], "Seed %d keeps the old number ring" % seed_val)
	var st3 := GameState.create_new_game(42, 4, true)
	var sp := st3.start_player
	for step_idx in range(8):
		var p := (sp + step_idx) % 4 if step_idx < 4 else (sp + (7 - step_idx)) % 4
		_assert(st3.current_player == p, "Snake step %d belongs to seat %d" % [step_idx, p])
		var vs: Array[int] = RulesEngine.get_valid_settlement_vertices(st3, p, true)
		var rs := RulesEngine.apply_action(st3, p, GameAction.place_settlement(vs[0]))
		_assert(bool(rs.get("ok", false)), "Snake step %d settlement ok" % step_idx)
		var es: Array[int] = RulesEngine.get_valid_road_edges(st3, p, vs[0])
		var rr := RulesEngine.apply_action(st3, p, GameAction.place_road(es[0]))
		_assert(bool(rr.get("ok", false)), "Snake step %d road ok" % step_idx)
	_assert(st3.phase == GameTypes.TurnPhase.TURN_ROLL and st3.current_player == sp and st3.turn_number == 1, "The first TURN_ROLL belongs to the start player")
	_pass_section("72. Start Player Rotation Test (random seat opens, seed-stable, old boards intact, snake from start)")

func _test_pacing_focus_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779073, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var guard := 0
	while ui.session.state.phase < GameTypes.TurnPhase.TURN_ROLL and guard < 64:
		guard += 1
		var s0: GameState = ui.session.state
		var pid := s0.current_player
		var vs: Array[int] = RulesEngine.get_valid_settlement_vertices(s0, pid, true)
		var rs: Dictionary = ui.session.submit_action(pid, GameAction.place_settlement(vs[0]))
		_assert(bool(rs.get("ok", false)), "Pacing setup settlement for seat %d ok" % pid)
		var s1: GameState = ui.session.state
		var es: Array[int] = RulesEngine.get_valid_road_edges(s1, pid, vs[0])
		var rr: Dictionary = ui.session.submit_action(pid, GameAction.place_road(es[0]))
		_assert(bool(rr.get("ok", false)), "Pacing setup road for seat %d ok" % pid)
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	_assert(st.phase == GameTypes.TurnPhase.TURN_ROLL and st.current_player == 0, "Pacing test reaches the viewer's roll phase")
	_assert(ui._turn_focus_pid == 0, "The focus starts on the viewer")
	_assert(int(ui._bot_turn_started_ms) == 0, "No bot clock while the viewer is up")
	var b0 := int(ui._turn_banner_count)
	ui.session.submit_action(0, GameAction.roll_dice())
	ui.session.submit_action(0, GameAction.end_turn())
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(int(ui._turn_banner_count) == b0 + 1, "One new banner per turn change")
	_assert(ui._turn_focus_pid == 1, "The focus moved to the bot")
	_assert(int(ui._bot_turn_started_ms) > 0, "The bot turn clock started")
	load(UI_SCRIPT_PATH).turn_min_seconds_override = 2.0
	ui.auto_ai = true
	var started := int(ui._bot_turn_started_ms)
	_assert(ui._bot_must_wait(started + 500), "A bot may not end its turn 500 ms in")
	_assert(not ui._bot_must_wait(started + 2600), "A bot may end its turn after 2.6 s")
	st.open_trade = {"from": 1, "type": 0}
	_assert(not ui._bot_must_wait(started + 500), "No wait while an open trade waits for answers")
	st.open_trade.clear()
	st.pending_discards[0] = 1
	_assert(not ui._bot_must_wait(started + 500), "No wait while discards are pending")
	st.pending_discards.clear()
	var keep_phase: int = st.phase
	st.phase = GameTypes.TurnPhase.SETUP_ROAD_1
	_assert(not ui._bot_must_wait(started + 500), "No wait during setup phases")
	st.phase = keep_phase
	load(UI_SCRIPT_PATH).turn_min_seconds_override = 0.0
	_assert(not ui._bot_must_wait(started + 500), "The suite override switches the wait off")
	ui.auto_ai = false
	ui.session.submit_action(1, GameAction.roll_dice())
	ui.session.submit_action(1, GameAction.end_turn())
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(int(ui._turn_banner_count) == b0 + 2, "The banner appears again when the turn returns")
	_assert(ui._turn_focus_pid == 0, "The focus returns to the viewer")
	_pass_section("73. Pacing & Focus Test (banner per turn change, focus pid, bot turn minimum)")

func _test_flight_targets_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(779074, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var guard := 0
	while ui.session.state.phase < GameTypes.TurnPhase.TURN_ROLL and guard < 96:
		guard += 1
		var s0: GameState = ui.session.state
		var pid := s0.current_player
		var vs: Array[int] = RulesEngine.get_valid_settlement_vertices(s0, pid, true)
		ui.session.submit_action(pid, GameAction.place_settlement(vs[0]))
		var s1: GameState = ui.session.state
		var es: Array[int] = RulesEngine.get_valid_road_edges(s1, pid, vs[0])
		ui.session.submit_action(pid, GameAction.place_road(es[0]))
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	_assert(st.phase == GameTypes.TurnPhase.TURN_ROLL and st.current_player == 0, "Flight target test reaches the viewer's roll phase")
	var grain := GameTypes.ResourceType.GRAIN
	for pid2 in [0, 1, 2]:
		var h: Dictionary = st.players[pid2]["hand"]
		h[grain] = int(h.get(grain, 0)) + 1
		st.bank[grain] = int(st.bank.get(grain, 0)) - 1
	ui._on_state_updated(st, NO_EVENTS)
	var ready := false
	var landed_ok := false
	var ends_by_to := {}
	for _i in range(60):
		await ui.get_tree().process_frame
		if int(ui._last_flight_targets.size()) < 3:
			continue
		ready = true
		ends_by_to = {}
		landed_ok = true
		for ent in ui._last_flight_targets:
			var to_pid := int(ent["to"])
			var end: Vector2 = ent["end"]
			ends_by_to[to_pid] = end
			if to_pid == 0:
				var face: CardFace = ui._res_card_refs.get(int(ent["res"]), null)
				if face == null or not is_instance_valid(face) or not face.get_global_rect().has_point(end):
					landed_ok = false
			else:
				var mh: Variant = ui._scoreboard_mini_hands.get(to_pid, null)
				if not (mh is Control) or not is_instance_valid(mh) or not (mh as Control).get_global_rect().has_point(end):
					landed_ok = false
		if landed_ok:
			break
	_assert(ready, "Three bank cards spawn with resolved targets")
	_assert(landed_ok, "Every flight ends inside its own recipient node")
	_assert(ends_by_to.size() == 3, "All three recipients get their own target")
	_assert(ends_by_to[0] != ends_by_to[1] and ends_by_to[0] != ends_by_to[2] and ends_by_to[1] != ends_by_to[2], "No two recipients share an end point")
	var mh0: Control = ui._scoreboard_mini_hands[0]
	var mh1: Control = ui._scoreboard_mini_hands[1]
	var mh2: Control = ui._scoreboard_mini_hands[2]
	var r0 := mh0.get_global_rect()
	var r1 := mh1.get_global_rect()
	var r2 := mh2.get_global_rect()
	_assert(r0.size.x > 0.0 and r1.size.x > 0.0 and r2.size.x > 0.0, "The mini hand rows have real sizes")
	_assert(r0 != r1 and r0 != r2 and r1 != r2, "The three rows occupy distinct rects")
	_pass_section("74. Flight Targets Test (bank cards fly to the right scoreboard rows)")

func _test_sfx_body(ui: Node) -> void:
	var sfx: Node = ui.get_node_or_null("Sfx")
	_assert(sfx != null, "UI should own an Sfx child")
	if sfx == null:
		return
	var names: Array = sfx.clip_names()
	for want in ["roll", "build", "trade", "turn", "seven", "win", "click"]:
		_assert(want in names, "Sfx should have a '%s' clip" % want)
	var clips_ok := true
	for nm in names:
		var w: AudioStreamWAV = sfx._clips[nm]
		if w.data.size() <= 0 or sfx.clip_length(str(nm)) >= 1.2:
			clips_ok = false
	_assert(clips_ok, "Every clip must have data and be shorter than 1.2 s")
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4717, seats, true, 0)
	var st: GameState = ui.session.state
	st.last_dice = Vector2i(4, 3)
	var r0: int = int(Sfx.play_count.get("roll", 0)) + int(Sfx.play_count.get("seven", 0))
	var ev_roll: Array[String] = ["Dune rolled 4 + 3 = 7."]
	ui._on_state_updated(st, ev_roll)
	var r1: int = int(Sfx.play_count.get("roll", 0)) + int(Sfx.play_count.get("seven", 0))
	_assert(r1 == r0 + 1, "A 7 roll must play exactly one roll/seven clip, got %d" % (r1 - r0))
	_assert(int(Sfx.play_count.get("seven", 0)) >= 1, "Sum 7 should prefer the 'seven' clip")
	var b0: int = int(Sfx.play_count.get("build", 0))
	var ev_build: Array[String] = ["Azure built a road on edge 5."]
	ui._on_state_updated(st, ev_build)
	var b1: int = int(Sfx.play_count.get("build", 0))
	_assert(b1 == b0 + 1, "A road build should play exactly one build clip, got %d" % (b1 - b0))
	ui._settings_mute_check.button_pressed = true
	_assert(AudioServer.is_bus_mute(0), "Mute setting must mute the Master bus")
	ui._settings_mute_check.button_pressed = false
	_assert(not AudioServer.is_bus_mute(0), "Unmute must un-mute the Master bus")
	_pass_section("26. Sound Test (clips generated, roll/build counts, mute applies)")

func _test_bank_conservation_match() -> void:
	var session := LocalSession.new()
	var seats: Array[SeatConfig] = []
	for i in range(4):
		var sc := SeatConfig.new()
		sc.seat_id = i
		sc.seat_type = SeatConfig.SeatType.AI_MEDIUM
		sc.display_name = "Bank Bot %d" % i
		seats.append(sc)
	session.start_match(31001, seats, true, 0)
	for r in GameTypes.ALL_RESOURCES:
		_assert(int(session.state.bank.get(r, 0)) == 19, "Bank must start with 19 %s" % GameTypes.resource_name(r))
	_assert(session.state.resource_totals_ok(), "Fresh match must satisfy the resource invariant")
	var steps := 0
	var checks := 0
	var ok_everywhere := true
	while session.state.phase != GameTypes.TurnPhase.GAME_OVER and steps < 10000:
		var res: Dictionary = session.step_ai()
		if not bool(res.get("ok", false)):
			break
		steps += 1
		if steps % 10 == 0:
			checks += 1
			if not session.state.resource_totals_ok():
				ok_everywhere = false
				break
	_assert(session.state.phase == GameTypes.TurnPhase.GAME_OVER, "Bank conservation match should finish")
	_assert(ok_everywhere, "Bank + hands = 19 must hold at every check during the match")
	_assert(checks >= 10, "Conservation should have been checked many times, got %d" % checks)
	_assert(session.state.resource_totals_ok(), "Conservation must hold at match end")
	_pass_section("27. Bank Conservation Test (19 per resource, checked mid-match and at end)")

func _test_bank_production_rule() -> void:
	var gs := GameState.create_new_game(4242, 4, true)
	var t_id := -1
	for t in range(19):
		if t != gs.blocker_tile and GameTypes.terrain_to_resource(gs.tile_terrains[t]) >= 0:
			t_id = t
			break
	_assert(t_id != -1, "Need one producing tile for the production test")
	var res := GameTypes.terrain_to_resource(gs.tile_terrains[t_id])
	var topo := HexMath.get_topology()
	var verts: Array = topo.tile_vertices[t_id]
	gs.blocker_tile = (t_id + 3) % 19
	for t in range(19):
		gs.tile_numbers[t] = 99
	gs.tile_numbers[t_id] = 5
	gs.vertex_owner[verts[0]] = 0
	gs.vertex_building[verts[0]] = GameTypes.BuildingType.SETTLEMENT
	gs.vertex_owner[verts[1]] = 1
	gs.vertex_building[verts[1]] = GameTypes.BuildingType.SETTLEMENT
	gs.bank[res] = 1
	var evs: Array[String] = []
	RulesEngine.apply_production(gs, 5, evs)
	_assert(int(gs.players[0]["hand"].get(res, 0)) == 0 and int(gs.players[1]["hand"].get(res, 0)) == 0, "Short bank with two claimants must give nobody the resource")
	_assert(int(gs.bank[res]) == 1, "Nobody-received production must not touch the bank")
	var out_of := false
	for ev in evs:
		if str(ev).contains("The bank is out of"):
			out_of = true
	_assert(out_of, "Short bank with two claimants must log 'The bank is out of <res>.'")
	# single claimant gets what is left
	gs.vertex_owner[verts[1]] = -1
	gs.vertex_building[verts[1]] = GameTypes.BuildingType.NONE
	gs.vertex_building[verts[0]] = GameTypes.BuildingType.CITY
	var evs2: Array[String] = []
	RulesEngine.apply_production(gs, 5, evs2)
	_assert(int(gs.players[0]["hand"].get(res, 0)) == 1, "Single claimant should receive the one resource left in the bank")
	_assert(int(gs.bank[res]) == 0, "Leftover payout must drain the bank to 0")
	# normal production drains the bank exactly by the owed amount
	gs.players[0]["hand"][res] = 0
	gs.bank[res] = 19
	var evs3: Array[String] = []
	RulesEngine.apply_production(gs, 5, evs3)
	_assert(int(gs.players[0]["hand"].get(res, 0)) == 2 and int(gs.bank[res]) == 17, "Full bank pays city 2 and leaves bank 17")
	_assert(gs.resource_totals_ok(), "Production must conserve the total supply")
	_pass_section("28. Bank-Empty Production Test (short bank: nobody / single claimant gets the rest)")

func _test_bank_maritime_empty() -> void:
	var gs := GameState.create_new_game(4343, 4, true)
	var p: Dictionary = gs.players[0]
	p["hand"][GameTypes.ResourceType.TIMBER] = 4
	gs.bank[GameTypes.ResourceType.TIMBER] = 15
	gs.bank[GameTypes.ResourceType.CLAY] = 0
	gs.players[3]["hand"][GameTypes.ResourceType.CLAY] = 19
	gs.current_player = 0
	gs.phase = GameTypes.TurnPhase.TURN_MAIN
	_assert(gs.resource_totals_ok(), "Crafted maritime state must start consistent")
	var events1: Array[String] = []
	var res := RulesEngine.apply_action(gs, 0, GameAction.maritime_trade(GameTypes.ResourceType.TIMBER, GameTypes.ResourceType.CLAY))
	_assert(not bool(res.get("ok", false)), "Maritime trade must fail when the wanted bank pile is empty")
	_assert(str(res.get("error", "")).contains("The bank has no"), "Maritime fail should say 'The bank has no <res>.', got '%s'" % str(res.get("error", "")))
	_assert(int(p["hand"].get(GameTypes.ResourceType.TIMBER, 0)) == 4, "Failed maritime trade must not take resources")
	gs.bank[GameTypes.ResourceType.CLAY] = 5
	gs.players[3]["hand"][GameTypes.ResourceType.CLAY] = 14
	var events2: Array[String] = []
	var res2 := RulesEngine.apply_action(gs, 0, GameAction.maritime_trade(GameTypes.ResourceType.TIMBER, GameTypes.ResourceType.CLAY))
	_assert(bool(res2.get("ok", false)), "Maritime trade should succeed when the bank has the resource")
	_assert(int(p["hand"].get(GameTypes.ResourceType.TIMBER, 0)) == 0 and int(p["hand"].get(GameTypes.ResourceType.CLAY, 0)) == 1, "Maritime trade swaps 4 Timber for 1 Clay")
	_assert(int(gs.bank.get(GameTypes.ResourceType.TIMBER, 0)) == 19, "Given resources must go into the bank")
	_assert(gs.resource_totals_ok(), "Maritime trade must conserve the total supply")
	_pass_section("29. Maritime Empty Bank Test (refused on empty pile, pays the bank on success)")

func _test_steal_victim_choice() -> void:
	var gs := GameState.create_new_game(4444, 4, true)
	var topo := HexMath.get_topology()
	var t_id := -1
	for t in range(19):
		if topo.tile_vertices[t].size() >= 3:
			t_id = t
			break
	var verts: Array = topo.tile_vertices[t_id]
	gs.blocker_tile = (t_id + 2) % 19
	var start_blocker: int = gs.blocker_tile
	gs.players[0]["hand"] = GameTypes.empty_hand()
	gs.players[1]["hand"] = GameTypes.empty_hand()
	gs.players[2]["hand"] = GameTypes.empty_hand()
	gs.current_player = 0
	# 0 victims: nobody else on the tile -> move succeeds, no steal
	gs.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	var ev0: Array[String] = []
	var r0 := RulesEngine.apply_action(gs, 0, GameAction.move_blocker(t_id, -1))
	_assert(bool(r0.get("ok", false)), "Blocker move with 0 victims should succeed")
	_assert(gs.blocker_tile == t_id, "Blocker should have moved with 0 victims")
	_assert(gs.last_steal.is_empty(), "0 victims means no last_steal record")
	# 1 victim: steals even with a bogus target
	gs.blocker_tile = start_blocker
	gs.vertex_owner[verts[0]] = 1
	gs.vertex_building[verts[0]] = GameTypes.BuildingType.SETTLEMENT
	gs.players[1]["hand"][GameTypes.ResourceType.FLEECE] = 2
	_assert(RulesEngine.get_steal_victims(gs, 0, t_id) == [1], "get_steal_victims should list exactly the one victim")
	gs.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	var ev1: Array[String] = []
	var r1 := RulesEngine.apply_action(gs, 0, GameAction.move_blocker(t_id, 99))
	_assert(bool(r1.get("ok", false)), "Single victim must be stolen from whatever target_player says")
	_assert(int(gs.last_steal.get("thief", -1)) == 0 and int(gs.last_steal.get("victim", -1)) == 1, "last_steal must record thief and victim")
	_assert(int(gs.last_steal.get("serial", 0)) == 1, "First steal has serial 1")
	_assert(int(gs.last_steal.get("res", -1)) == GameTypes.ResourceType.FLEECE, "Stolen resource must be recorded")
	_assert(int(gs.players[1]["hand"].get(GameTypes.ResourceType.FLEECE, 0)) == 1, "Victim lost exactly one card")
	# 2 victims: needs a valid target
	gs.blocker_tile = start_blocker
	gs.vertex_owner[verts[1]] = 2
	gs.vertex_building[verts[1]] = GameTypes.BuildingType.SETTLEMENT
	gs.players[2]["hand"][GameTypes.ResourceType.CLAY] = 1
	var victims := RulesEngine.get_steal_victims(gs, 0, t_id)
	_assert(victims.has(1) and victims.has(2), "Both owners with cards must be listed as victims")
	var hand1_before: int = GameTypes.hand_total(gs.players[1]["hand"])
	var hand2_before: int = GameTypes.hand_total(gs.players[2]["hand"])
	gs.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	var ev2: Array[String] = []
	var r2 := RulesEngine.apply_action(gs, 0, GameAction.move_blocker(t_id, -1))
	_assert(not bool(r2.get("ok", false)), "2 victims without a valid target must fail")
	_assert(str(r2.get("error", "")) == "Choose who to steal from.", "Fail reason should be 'Choose who to steal from.', got '%s'" % str(r2.get("error", "")))
	_assert(gs.blocker_tile == start_blocker, "Failed steal must leave the blocker in place")
	_assert(GameTypes.hand_total(gs.players[1]["hand"]) == hand1_before and GameTypes.hand_total(gs.players[2]["hand"]) == hand2_before, "Failed steal must not move any cards")
	_assert(int(gs.last_steal.get("serial", 0)) == 1, "Failed steal must not bump the serial")
	# Guard card kept when the choice fails
	gs.players[0]["dev_cards"] = [GameTypes.DevCardType.GUARD]
	gs.current_player = 0
	gs.phase = GameTypes.TurnPhase.TURN_MAIN
	gs.open_trade.clear()
	var ev3: Array[String] = []
	var r3 := RulesEngine.apply_action(gs, 0, GameAction.play_guard(t_id, -1))
	_assert(not bool(r3.get("ok", false)), "play_guard must fail without a valid victim choice")
	_assert(gs.players[0]["dev_cards"].has(GameTypes.DevCardType.GUARD), "Failed guard play keeps the card")
	_assert(gs.blocker_tile == start_blocker, "Failed guard play leaves the blocker in place")
	# valid target: steals from the chosen victim only
	var ev4: Array[String] = []
	var r4 := RulesEngine.apply_action(gs, 0, GameAction.play_guard(t_id, 2))
	_assert(bool(r4.get("ok", false)), "play_guard with a valid victim target should succeed")
	_assert(not gs.players[0]["dev_cards"].has(GameTypes.DevCardType.GUARD), "Successful guard play consumes the card")
	_assert(int(gs.last_steal.get("victim", -1)) == 2 and int(gs.last_steal.get("serial", 0)) == 2, "Chosen victim is robbed and serial increments")
	_assert(int(gs.last_steal.get("res", -1)) == GameTypes.ResourceType.CLAY, "Victim 2's only card (Clay) must be the recorded steal")
	_assert(int(gs.players[1]["hand"].get(GameTypes.ResourceType.FLEECE, 0)) == 1, "The non-chosen victim keeps all cards")
	_pass_section("30. Steal Victim Choice Test (0/1/2 victims, fail keeps card, last_steal recorded)")

func _test_played_dev_core() -> void:
	var state := GameState.create_new_game(556, 4, true)
	state.start_player = 0
	state.current_player = 0
	var spots: Array[int] = RulesEngine.get_valid_settlement_vertices(state, 0, true)
	var sr: Dictionary = RulesEngine.apply_action(state, 0, GameAction.place_settlement(spots[0]))
	_assert(bool(sr.get("ok", false)), "Setup settlement placed")
	var edges: Array[int] = RulesEngine.get_valid_road_edges(state, 0, spots[0])
	var rr: Dictionary = RulesEngine.apply_action(state, 0, GameAction.place_road(edges[0]))
	_assert(bool(rr.get("ok", false)), "Setup road placed")
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.current_player = 0
	var p0: Dictionary = state.players[0]
	p0["dev_cards"] = [
		GameTypes.DevCardType.GUARD,
		GameTypes.DevCardType.ROAD_WORK,
		GameTypes.DevCardType.HARVEST_BOUNTY,
		GameTypes.DevCardType.TRADE_DECREE,
		GameTypes.DevCardType.CHARTER_POINT,
	]
	var fresh: Dictionary = p0.get("played_dev", {})
	_assert(fresh.is_empty(), "A fresh player has no played_dev entries")
	var r_guard: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_guard((state.blocker_tile + 1) % 19, -1))
	_assert(bool(r_guard.get("ok", false)), "Guard plays on a fresh main phase")
	_assert(int(p0["played_dev"].get(GameTypes.DevCardType.GUARD, 0)) == 1, "played_dev GUARD increments to 1")
	_assert(int(p0["played_guards"]) == 1, "played_guards still increments")
	p0["played_dev_this_turn"] = false
	var r_road: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_road_work())
	_assert(bool(r_road.get("ok", false)), "Road Work plays")
	_assert(int(p0["played_dev"].get(GameTypes.DevCardType.ROAD_WORK, 0)) == 1, "played_dev ROAD_WORK increments")
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	state.road_work_remaining = 0
	p0["played_dev_this_turn"] = false
	var r_bounty: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_harvest_bounty(GameTypes.ResourceType.GRAIN, GameTypes.ResourceType.IRON))
	_assert(bool(r_bounty.get("ok", false)), "Harvest Bounty plays")
	_assert(int(p0["played_dev"].get(GameTypes.DevCardType.HARVEST_BOUNTY, 0)) == 1, "played_dev HARVEST_BOUNTY increments")
	p0["played_dev_this_turn"] = false
	var r_decree: Dictionary = RulesEngine.apply_action(state, 0, GameAction.play_trade_decree(GameTypes.ResourceType.FLEECE))
	_assert(bool(r_decree.get("ok", false)), "Trade Decree plays")
	_assert(int(p0["played_dev"].get(GameTypes.DevCardType.TRADE_DECREE, 0)) == 1, "played_dev TRADE_DECREE increments")
	_assert(int(p0["dev_cards"].count(GameTypes.DevCardType.CHARTER_POINT)) == 1, "The Charter was never played")
	_assert(not p0["played_dev"].has(GameTypes.DevCardType.CHARTER_POINT), "Charter never appears in played_dev")
	var copy := state.clone()
	var copy_pd: Dictionary = copy.players[0]["played_dev"]
	_assert(int(copy_pd.get(GameTypes.DevCardType.GUARD, 0)) == 1, "clone copies played_dev")
	copy_pd[GameTypes.DevCardType.GUARD] = 99
	_assert(int(p0["played_dev"].get(GameTypes.DevCardType.GUARD, 0)) == 1, "clone copies played_dev independently")
	_pass_section("75. Played Dev Cards Core Test (each type counted, Charter never, clone-safe)")

func _test_token_number_legibility() -> void:
	var bv := BoardView.new()
	var styles: Array[String] = ["classic", "bold", "odds"]
	for style in styles:
		var rr := 18
		while rr <= 90:
			for num in [2, 6, 8, 12]:
				var tl: Dictionary = bv.token_layout(num, float(rr), style)
				_assert(int(tl["num_font"]) >= 11, "num_font stays >= 11 at r=%d style=%s num=%d (got %d)" % [
					rr, style, num, int(tl["num_font"])
				])
				var tf: Font = ThemeDB.fallback_font
				var num_w := tf.get_string_size(str(num), HORIZONTAL_ALIGNMENT_CENTER, -1, int(tl["num_font"])).x
				_assert(float(tl["disc_r"]) * 2.0 >= num_w - 0.5, "The chip grows wide enough for the number at r=%d style=%s (chip %.1f vs text %.1f)" % [
					rr, style, float(tl["disc_r"]) * 2.0, num_w
				])
			rr += 6
	bv.free()
	_pass_section("80. Token Number Legibility Test (min 11 px number, growing chip)")

func _assert_panel_buttons_inside(ui: Node, label: String) -> void:
	var win := ui.get_viewport().get_visible_rect()
	var side: Rect2 = ui._right_panel.get_global_rect()
	var tray: Rect2 = ui._trade_tray.get_global_rect()
	_assert(side.grow(1.0).encloses(tray.grow(0.5)), "%s: the trade panel sits inside the sidebar" % label)
	var checked := 0
	for b in ui._trade_tray.find_children("*", "Button", true, false):
		var btn := b as Button
		if not btn.visible or not btn.is_visible_in_tree():
			continue
		var gr := btn.get_global_rect()
		if gr.size.x <= 0.0 or gr.size.y <= 0.0:
			continue
		checked += 1
		_assert(side.grow(1.0).encloses(gr), "%s: button '%s' stays inside the sidebar" % [label, btn.text])
		_assert(win.encloses(gr.grow(-0.5)), "%s: button '%s' stays inside the window" % [label, btn.text])
	_assert(checked >= 3, "%s: the panel shows its buttons (%d found)" % [label, checked])

func _test_side_trade_panel_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Amber"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(779081, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["hand"][GameTypes.ResourceType.CLAY] = 4
	st.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 4
	ui._device_pass_btn.pressed.emit()
	ui._refresh_ui()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(not bool(ui._hand_hidden()), "The hot-seat device pass reveals seat 0")
	for win_sz in [Vector2i(1280, 800), Vector2i(1600, 1000)]:
		root.size = win_sz
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		var before: Vector2 = ui._board_view.size
		_assert(before.x > 100.0 and before.y > 100.0, "The board has a real size at %s" % str(win_sz))
		ui._set_tray_panel_visible(true)
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		_assert(ui._board_view.size == before, "The board keeps its exact size with the panel open at %s" % str(win_sz))
		ui._set_tray_panel_visible(false)
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		_assert(ui._board_view.size == before, "The board keeps its exact size after closing at %s" % str(win_sz))
	root.size = Vector2i(1280, 800)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	# (a) proposer mode: own open offer with 1 accept and 2 counters
	var responses := {
		1: {"status": "accept"},
		2: {"status": "counter", "offer": {GameTypes.ResourceType.GRAIN: 2}, "request": {GameTypes.ResourceType.CLAY: 2}},
		3: {"status": "counter", "offer": {GameTypes.ResourceType.TIMBER: 1}, "request": {GameTypes.ResourceType.GRAIN: 1}},
	}
	st.open_trade = {
		"from": 0,
		"offer": {GameTypes.ResourceType.CLAY: 1},
		"request": {GameTypes.ResourceType.GRAIN: 1},
		"responses": responses,
		"revisions": {},
		"resp_ticks": {1: 1, 2: 1, 3: 1},
		"reviews": {1: 3, 2: 3, 3: 3},
	}
	ui._trade_reopen_token = ""
	ui._log_toggle_btn.button_pressed = true
	ui._log_toggle_btn.toggled.emit(true)
	await ui.get_tree().process_frame
	ui._refresh_ui()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(bool(ui._trade_tray.visible), "The panel auto-opens for the viewed proposer")
	_assert(not bool(ui._log_toggle_btn.button_pressed), "The event log collapses while the trade panel is open")
	_assert(ui._trade_partner_stack.get_child_count() == 3, "One stacked partner row per opponent")
	_assert(str(ui._trade_title_lbl.text).begins_with("Your offer:"), "The header names the viewer's own offer")
	_assert(
		ui._trade_content.get_combined_minimum_size().x <= ui._trade_scroll.size.x + 1.0,
		"No horizontal scrolling inside the panel"
	)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var win_p := ui.get_viewport().get_visible_rect()
	_assert(ui._trade_tray.size.y <= 290.0, "The compact panel fits 290 px (got %.0f)" % ui._trade_tray.size.y)
	_assert(win_p.encloses(ui._trade_tray.get_global_rect().grow(-0.5)), "The panel is fully inside the window")
	var side_scroll2: ScrollContainer = null
	for c2 in ui._right_panel.get_children():
		if c2 is ScrollContainer:
			side_scroll2 = c2
	_assert(side_scroll2 != null and int(side_scroll2.scroll_vertical) == 0, "No sidebar scrolling while trading")
	var rows_seen := 0
	for rc in ui._scoreboard_box.get_children():
		rows_seen += 1
		_assert(win_p.encloses((rc as Control).get_global_rect().grow(-0.5)), "Scoreboard row %d stays visible in the window" % rows_seen)
	_assert(rows_seen == 4, "All four scoreboard rows exist, got %d" % rows_seen)
	_assert(win_p.encloses(ui._bank_faces[GameTypes.ResourceType.TIMBER].get_global_rect().grow(-0.5)), "The bank piles stay visible in the window")
	_assert_panel_buttons_inside(ui, "propose")
	ui._close_trade_tray_by_user()
	_assert(not bool(ui._log_toggle_btn.button_pressed), "The log popup stays closed after the panel closes")
	# (b) respond mode: seat 2 offers, the viewer (0) must answer
	st.current_player = 0
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.open_trade = {
		"from": 2,
		"offer": {GameTypes.ResourceType.TIMBER: 1},
		"request": {GameTypes.ResourceType.CLAY: 1},
		"responses": {
			1: {"status": "decline", "offer": {}, "request": {}},
			3: {"status": "decline", "offer": {}, "request": {}},
		},
		"revisions": {},
		"resp_ticks": {1: 1, 3: 1},
		"reviews": {1: 2, 3: 2},
	}
	ui._trade_reopen_token = ""
	ui._trade_counter_mode = false
	ui._refresh_ui()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(bool(ui._trade_tray.visible), "The panel auto-opens for the responder")
	_assert(bool(ui._trade_respond_view.visible), "Respond mode shows the offer rows")
	_assert(str(ui._trade_title_lbl.text).begins_with("Dune"), "The header names the offering player")
	_assert_panel_buttons_inside(ui, "respond")
	# (c) counter-edit mode
	ui._trade_counter_mode = true
	ui._refresh_ui()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(bool(ui._trade_rows_col.visible), "The counter editor reuses the two card rows")
	_assert(bool(ui._trade_counter_row.visible), "The counter row shows Send/Back")
	_assert_panel_buttons_inside(ui, "counter")
	ui._trade_counter_mode = false
	st.open_trade = {}
	ui._refresh_ui()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(not bool(ui._trade_tray.visible), "The panel closes when the offer is gone")
	_pass_section("81. Side Trade Panel Test (sidebar panel, board size, button fit)")

func _test_port_tags_fit_body(ui: Node) -> void:
	var sizes: Array[Vector2i] = [
		Vector2i(880, 650),
		Vector2i(880, 560),
		Vector2i(1200, 900),
		Vector2i(600, 600),
		Vector2i(883, 2235),
		Vector2i(836, 400),
		Vector2i(600, 380),
		Vector2i(2000, 1500),
		Vector2i(1998, 1500),
	]
	var idx := 0
	for sz in sizes:
		for names in [false, true]:
			idx += 1
			var st := GameState.create_new_game(9100 + idx, 3, true)
			var bv := BoardView.new()
			ui.add_child(bv)
			bv.custom_minimum_size = Vector2.ZERO
			bv.reduce_motion = true
			bv.show_port_names = bool(names)
			bv.state = st
			bv.size = Vector2(sz)
			bv.queue_redraw()
			await ui.get_tree().process_frame
			await ui.get_tree().process_frame
			var tags: Array[Rect2] = bv.port_tag_rects()
			var badges: Array[Rect2] = bv.port_badge_rects()
			_assert(not badges.is_empty() and tags.size() == badges.size(), "Ports draw tags at %s names=%s" % [str(sz), str(names)])
			var vfont := ThemeDB.fallback_font
			var pill_tall := true
			for bd in bv.get_port_badge_data():
				var tfs := int(bd.get("tag_fs", 0))
				var trect: Rect2 = bd["tag_rect"]
				if tfs > 0:
					var need: float = vfont.get_ascent(tfs) + absf(vfont.get_descent(tfs)) + 2.0
					if trect.size.y < need:
						pill_tall = false
			_assert(pill_tall, "Ratio tag pills are tall enough for the font glyphs at %s" % str(sz))
			var tag_clashes := 0
			for i in range(tags.size()):
				for j in range(i + 1, tags.size()):
					if tags[i].intersects(tags[j]):
						tag_clashes += 1
			_assert(tag_clashes == 0, "Ratio tags never overlap each other at %s (clashes=%d)" % [str(sz), tag_clashes])
			var margin := Rect2(Vector2.ZERO, Vector2(sz)).grow(-8.0)
			var inside := true
			for r in tags:
				if not margin.encloses(r.grow(0.5)):
					inside = false
			for r in badges:
				if not margin.encloses(r.grow(0.5)):
					inside = false
			_assert(inside, "Tags and badges stay inside the 8 px margin at %s names=%s" % [str(sz), str(names)])
			var overlap := false
			for i in range(tags.size()):
				for j in range(i + 1, tags.size()):
					if tags[i].intersects(tags[j]):
						overlap = true
			_assert(not overlap, "Ratio tags never overlap each other at %s" % str(sz))
			var clash := false
			for i in range(tags.size()):
				for j in range(badges.size()):
					if i != j and tags[i].intersects(badges[j]):
						clash = true
			_assert(not clash, "A ratio tag only touches its own badge at %s" % str(sz))
			var badge_clash := false
			for i in range(badges.size()):
				for j in range(i + 1, badges.size()):
					var ci: Vector2 = badges[i].position + badges[i].size * 0.5
					var cj: Vector2 = badges[j].position + badges[j].size * 0.5
					var ri: float = badges[i].size.x * 0.5
					var rj: float = badges[j].size.x * 0.5
					if ci.distance_to(cj) < ri + rj - 0.5:
						badge_clash = true
			_assert(not badge_clash, "Port badges never overlap each other at %s" % str(sz))
			if bool(names):
				var pills_ok := true
				for lr in bv._harbour_label_rects:
					if not margin.encloses(lr.grow(0.5)):
						pills_ok = false
				_assert(pills_ok, "Harbour name pills stay inside the margin at %s" % str(sz))
			ui.remove_child(bv)
			bv.free()
	_pass_section("79. Port Tag Fit Test (badges and tags inside the view)")

func _test_standings() -> void:
	var gs := GameState.create_new_game(4545, 4, true)
	gs.vertex_owner[3] = 0
	gs.vertex_building[3] = GameTypes.BuildingType.SETTLEMENT
	gs.vertex_owner[9] = 0
	gs.vertex_building[9] = GameTypes.BuildingType.SETTLEMENT
	gs.players[0]["dev_cards"] = [GameTypes.DevCardType.CHARTER_POINT]
	gs.longest_route_holder = 0
	gs.vertex_owner[14] = 1
	gs.vertex_building[14] = GameTypes.BuildingType.CITY
	gs.vertex_owner[20] = 1
	gs.vertex_building[20] = GameTypes.BuildingType.SETTLEMENT
	gs.vertex_owner[25] = 2
	gs.vertex_building[25] = GameTypes.BuildingType.SETTLEMENT
	gs.vertex_owner[30] = 3
	gs.vertex_building[30] = GameTypes.BuildingType.SETTLEMENT
	gs.largest_guard_holder = 3
	var rows: Array = gs.get_standings()
	_assert(rows.size() == 4, "Standings should list every player")
	var order: Array[int] = []
	for row in rows:
		order.append(int(row["pid"]))
	_assert(order == [0, 1, 3, 2], "Standings order should be 0,1,3,2, got %s" % str(order))
	var by_pid: Dictionary = {}
	for row in rows:
		by_pid[int(row["pid"])] = row
	_assert(int(by_pid[0]["vp"]) == 5, "Player 0: 2 settlements + hidden charter + longest route = 5 VP, got %d" % int(by_pid[0]["vp"]))
	_assert(int(by_pid[0]["charters"]) == 1, "Player 0 shows the hidden Charter count")
	_assert(bool(by_pid[0]["longest_route"]), "Player 0 flagged for longest route")
	_assert(int(by_pid[1]["vp"]) == 3 and int(by_pid[1]["cities"]) == 1 and int(by_pid[1]["settlements"]) == 1, "Player 1: 1 city + 1 settlement = 3 VP")
	_assert(int(by_pid[3]["vp"]) == 3 and bool(by_pid[3]["largest_guard"]), "Player 3: settlement + largest guard = 3 VP")
	_assert(int(by_pid[2]["vp"]) == 1, "Player 2 has 1 VP")
	_assert(str(by_pid[2]["name"]) == GameTypes.PLAYER_NAMES[2], "Standings carry player names")
	# tie: equal everything -> lower pid first
	var gs2 := GameState.create_new_game(4546, 2, true)
	gs2.vertex_owner[2] = 0
	gs2.vertex_building[2] = GameTypes.BuildingType.SETTLEMENT
	gs2.vertex_owner[8] = 1
	gs2.vertex_building[8] = GameTypes.BuildingType.SETTLEMENT
	var rows2: Array = gs2.get_standings()
	_assert(int(rows2[0]["pid"]) == 0 and int(rows2[1]["pid"]) == 1, "Full ties break by lower pid")
	_pass_section("31. Standings Test (hidden Charter counted, city tie-break, pid tie-break)")

func _ui_click_job(node: Control, after: Callable) -> void:
	_ui_queue.push_front(func() -> void:
		if node == null or not is_instance_valid(node):
			_assert(false, "Click target should still be valid")
			return
		if node.size.x <= 0.0:
			_assert(false, "Click target should have a real size")
			return
		var center: Vector2 = root.get_screen_transform() * (node.get_global_transform() * (node.size * 0.5))
		var press_ev := InputEventMouseButton.new()
		press_ev.button_index = MOUSE_BUTTON_LEFT
		press_ev.pressed = true
		press_ev.position = center
		press_ev.global_position = center
		root.push_input(press_ev)
		var release_ev := InputEventMouseButton.new()
		release_ev.button_index = MOUSE_BUTTON_LEFT
		release_ev.pressed = false
		release_ev.position = center
		release_ev.global_position = center
		root.push_input(release_ev)
		after.call()
	)

func _ui_click_job_at(node: Control, local_point: Vector2, after: Callable) -> void:
	_ui_queue.push_front(func() -> void:
		if not is_instance_valid(node) or node.size.x <= 0.0:
			_assert(false, "CardFace missing for badge click")
			return
		var center: Vector2 = root.get_screen_transform() * (node.get_global_transform() * local_point)
		var pe := InputEventMouseButton.new()
		pe.button_index = MOUSE_BUTTON_LEFT
		pe.pressed = true
		pe.position = center
		pe.global_position = center
		root.push_input(pe)
		var re := InputEventMouseButton.new()
		re.button_index = MOUSE_BUTTON_LEFT
		re.pressed = false
		re.position = center
		re.global_position = center
		root.push_input(re)
		after.call()
	)

func _ui_key_job(key: int, shift: bool, after: Callable) -> void:
	_ui_queue.push_front(func() -> void:
		var kd := InputEventKey.new()
		kd.keycode = key
		kd.shift_pressed = shift
		kd.pressed = true
		root.push_input(kd)
		var ku := InputEventKey.new()
		ku.keycode = key
		ku.shift_pressed = shift
		ku.pressed = false
		root.push_input(ku)
		after.call()
	)

func _test_discard_picker_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52001, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_DISCARD
	st.current_player = 0
	st.pending_discards = {0: 4}
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 3
	st.players[0]["hand"][GameTypes.ResourceType.CLAY] = 3
	st.players[0]["hand"][GameTypes.ResourceType.FLEECE] = 2
	ui._refresh_ui()
	_assert(bool(ui._discard_mode_box.visible), "Discard mode should switch the hand bar")
	_assert(str(ui._discard_heading.text).contains("Discard 4 cards") and str(ui._discard_heading.text).contains("picked 0 of 4"), "Heading should announce 4 discards with picked 0 of 4, got '%s'" % str(ui._discard_heading.text))
	_assert(bool(ui._discard_confirm_btn.disabled), "Discard must stay disabled until 4 cards are picked")
	var refs: Dictionary = ui._res_card_refs
	var timber_card: CardFace = refs[GameTypes.ResourceType.TIMBER]
	var clay_card: CardFace = refs[GameTypes.ResourceType.CLAY]
	_ui_click_job(timber_card, func() -> void:
		_ui_click_job(timber_card, func() -> void:
			_ui_click_job(clay_card, func() -> void:
				_assert(str(ui._discard_heading.text).contains("picked 3 of 4"), "Three real picks should show 'picked 3 of 4', got '%s'" % str(ui._discard_heading.text))
				_assert(int(timber_card.count) == 3, "Cards keep normal counts in discard mode, got 'x%d'" % int(timber_card.count))
				_assert(int(timber_card.badge) == 2, "Timber badge should show 2, got %d" % int(timber_card.badge))
				_assert(bool(ui._discard_confirm_btn.disabled), "3 of 4 picked must still disable Discard")
				_assert(not bool(ui._trade_tray.visible), "Discard clicks must not open the trade tray")
				_ui_click_job_at(clay_card, clay_card.badge_center_local(), func() -> void:
					_assert(str(ui._discard_heading.text).contains("picked 2 of 4"), "Badge tap should take one back, got '%s'" % str(ui._discard_heading.text))
					_assert(int(clay_card.badge) == 0, "Badge clears when the last pick is taken back, got %d" % int(clay_card.badge))
					_ui_key_job(KEY_2, false, func() -> void:
						_ui_key_job(KEY_4, false, func() -> void:
							_ui_key_job(KEY_4, true, func() -> void:
								_assert(str(ui._discard_heading.text).contains("picked 3 of 4"), "Keys 1-5 add and Shift removes, got '%s'" % str(ui._discard_heading.text))
								ui._discard_auto_btn.pressed.emit()
								_assert(str(ui._discard_heading.text).contains("picked 4 of 4"), "'Pick for me' should fill 4, got '%s'" % str(ui._discard_heading.text))
								_assert(not bool(ui._discard_confirm_btn.disabled), "Discard must be enabled at 4 of 4")
								_assert(ui.session.state.phase == GameTypes.TurnPhase.TURN_DISCARD, "'Pick for me' must not submit by itself")
								var picked: Dictionary = ui._discard_pick.duplicate()
								var before: Dictionary = ui.session.state.players[0]["hand"].duplicate()
								_ui_key_job(KEY_ENTER, false, func() -> void:
									_assert(ui.session.state.phase != GameTypes.TurnPhase.TURN_DISCARD, "Enter must confirm the discard")
									_assert(not bool(ui._discard_mode_box.visible), "Discard mode ends after confirming")
									var exact := true
									for r in GameTypes.ALL_RESOURCES:
										if int(ui.session.state.players[0]["hand"].get(r, 0)) != int(before.get(r, 0)) - int(picked.get(r, 0)):
											exact = false
									_assert(exact, "Hand must shrink by exactly the picked cards")
									_assert(int(ui._discard_picked_total()) == 0, "Picks reset after confirming")
									_pass_section("32. Discard Picker Test (hand-bar picker, real clicks/keys, Pick for me, exact submit)")
								)
							)
						)
					)
				)
			)
		)
	)

func _test_steal_chooser_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(52002, seats, true, 0)
	var st: GameState = ui.session.state
	var topo := HexMath.get_topology()
	var tile_a: int = 5
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	st.current_player = 0
	st.blocker_tile = 9
	st.vertex_owner[topo.tile_vertices[tile_a][0]] = 1
	st.vertex_owner[topo.tile_vertices[tile_a][1]] = 2
	st.players[1]["hand"] = GameTypes.empty_hand()
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2
	st.players[2]["hand"] = GameTypes.empty_hand()
	st.players[2]["hand"][GameTypes.ResourceType.IRON] = 3
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 1
	ui._refresh_ui()
	await _ui_settle(2)
	_assert(ui._board_view.interaction_mode == BoardView.InteractionMode.PICK_BLOCKER_TILE, "Should be picking a blocker tile")
	ui._on_board_tile_clicked(tile_a)
	await _ui_settle(2)
	_assert(bool(ui._board_view.steal_targets_showing()), "Two victims should be marked on the board")
	_assert(ui._board_view.get_steal_target_count() == 2, "Both victims should get a mark, got %d" % ui._board_view.get_steal_target_count())
	var t0: Dictionary = ui._board_view._steal_targets[0]
	var t1: Dictionary = ui._board_view._steal_targets[1]
	_assert(str(t0.get("label", "")).contains("Dune · 2 cards"), "First mark should read 'Dune · 2 cards', got '%s'" % str(t0.get("label", "")))
	_assert(str(t1.get("label", "")).contains("Pike · 3 cards"), "Second mark should read 'Pike · 3 cards', got '%s'" % str(t1.get("label", "")))
	_assert((t0.get("color", Color.BLACK) as Color) == GameTypes.PLAYER_COLORS[1], "Each mark carries the victim's colour")
	_assert(int(t0.get("key", -1)) == 1 and int(t1.get("key", -1)) == 2, "Marks are numbered for the keys")
	_assert(str(ui._status_banner_label.text).begins_with("Click a marked player"), "Banner should say how to pick a victim")
	_ui_send_key(KEY_ESCAPE)
	await _ui_settle(2)
	_assert(not bool(ui._board_view.steal_targets_showing()), "Esc must clear the marks")
	_assert(ui._board_view.interaction_mode == BoardView.InteractionMode.PICK_BLOCKER_TILE, "Esc must keep tile picking active")
	ui._on_board_tile_clicked(tile_a)
	await _ui_settle(2)
	_assert(bool(ui._board_view.steal_targets_showing()), "Clicking the tile again should re-mark the victims")
	var victims: Array[int] = ui._steal_victims.duplicate()
	var thief_before: int = GameTypes.hand_total(ui.session.state.players[0]["hand"])
	var victim_before: int = GameTypes.hand_total(ui.session.state.players[victims[1]]["hand"])
	_ui_send_key(KEY_2)
	await _ui_settle(3)
	_assert(not bool(ui._board_view.steal_targets_showing()), "Key 2 must clear the marks")
	_assert(ui.session.state.blocker_tile == 5, "Key 2 should have moved the blocker to the picked tile")
	_assert(ui.session.state.phase == GameTypes.TurnPhase.TURN_MAIN, "Blocker move should end in TURN_MAIN")
	_assert(GameTypes.hand_total(ui.session.state.players[victims[1]]["hand"]) == victim_before - 1, "The chosen victim must lose the card")
	_assert(GameTypes.hand_total(ui.session.state.players[0]["hand"]) == thief_before + 1, "The thief must gain the card")
	_assert(int(ui.session.state.last_steal.get("victim", -1)) == victims[1], "last_steal must record the chosen victim")
	# exactly one victim: submit straight away, no marks
	ui.session.state.vertex_owner[HexMath.get_topology().tile_vertices[5][1]] = -1
	ui.session.state.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	ui.session.state.current_player = 0
	ui.session.state.blocker_tile = 9
	ui._refresh_ui()
	await _ui_settle(2)
	var solo_before: int = GameTypes.hand_total(ui.session.state.players[1]["hand"])
	ui._on_board_tile_clicked(5)
	await _ui_settle(3)
	_assert(not bool(ui._board_view.steal_targets_showing()), "One victim must draw no marks")
	_assert(ui.session.state.blocker_tile == 5, "Single-victim move should submit immediately")
	_assert(GameTypes.hand_total(ui.session.state.players[1]["hand"]) == solo_before - 1, "The single victim must be stolen from")
	# zero victims: move without a steal
	ui.session.state.vertex_owner[HexMath.get_topology().tile_vertices[5][0]] = -1
	var serial_before: int = int(ui.session.state.last_steal.get("serial", 0))
	var total_before: int = GameTypes.hand_total(ui.session.state.players[0]["hand"])
	ui.session.state.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	ui.session.state.current_player = 0
	ui.session.state.blocker_tile = 9
	ui._refresh_ui()
	await _ui_settle(2)
	ui._on_board_tile_clicked(6)
	await _ui_settle(3)
	_assert(ui.session.state.blocker_tile == 6, "Zero-victim move should submit immediately")
	_assert(int(ui.session.state.last_steal.get("serial", 0)) == serial_before, "Zero-victim move must not steal")
	_assert(GameTypes.hand_total(ui.session.state.players[0]["hand"]) == total_before, "Zero-victim move must not change hands")
	_pass_section("33. Steal Marks Test (2+ victims marked on board, 1/0 auto, keys, Esc keeps picking)")

func _toast_texts(ui: Node) -> String:
	var out := ""
	for l in ui._toast_labels:
		if is_instance_valid(l):
			out += "|" + str(l.text)
	return out

func _test_steal_toasts_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52003, seats, true, 0)
	var st: GameState = ui.session.state
	var topo := HexMath.get_topology()
	var toasts_before := 0
	for l in ui._toast_labels:
		if is_instance_valid(l):
			toasts_before += 1
	ui._show_toast("hello toast", Color.RED)
	_assert(ui._toast_labels.size() == toasts_before + 1, "Generic toast should be tracked")
	var hello_seen := false
	for l in ui._toast_labels:
		if is_instance_valid(l) and str(l.text) == "hello toast":
			hello_seen = true
	_assert(hello_seen, "Generic toast text should match")
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	st.current_player = 0
	st.blocker_tile = 9
	st.vertex_owner[topo.tile_vertices[5][0]] = 1
	st.players[1]["hand"] = GameTypes.empty_hand()
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2
	st.players[0]["hand"] = GameTypes.empty_hand()
	ui._refresh_ui()
	ui._on_board_tile_clicked(5)
	_assert(_toast_texts(ui).contains("You stole 1 Grain from Dune."), "Thief toast should name the resource in a solo game, got '%s'" % _toast_texts(ui))
	# bot steals from the human: private wording with the resource
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	st.current_player = 1
	st.blocker_tile = 5
	st.vertex_owner[topo.tile_vertices[6][0]] = 0
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.FLEECE] = 1
	ui.session.submit_action(1, GameAction.move_blocker(6, 0))
	_assert(_toast_texts(ui).contains("Dune stole 1 Fleece from you!"), "Victim toast should name the stolen resource for a solo viewer, got '%s'" % _toast_texts(ui))
	_pass_section("34. Steal Toasts Test (generic toast api, thief/victim wording)")

func _test_steal_toasts_hotseat_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(52004, seats, true, 0)
	var st: GameState = ui.session.state
	var topo := HexMath.get_topology()
	# bot steals from an AI: public wording only
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	st.current_player = 2
	st.blocker_tile = 9
	st.vertex_owner[topo.tile_vertices[5][0]] = 1
	st.players[1]["hand"] = GameTypes.empty_hand()
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2
	ui.session.submit_action(2, GameAction.move_blocker(5, 1))
	_assert(_toast_texts(ui).contains("Pike stole a card from Dune."), "Bystander steal should use public wording, got '%s'" % _toast_texts(ui))
	# AI steals from the viewer while hands are hidden (bot still acting turn): no resource name
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	st.current_player = 2
	st.blocker_tile = 5
	st.vertex_owner[topo.tile_vertices[6][0]] = 0
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.FLEECE] = 1
	ui._refresh_ui()
	_assert(bool(ui._hand_hidden()), "Hands should be hidden while the AI acts in hot-seat")
	ui.session.submit_action(2, GameAction.move_blocker(6, 0))
	_assert(_toast_texts(ui).contains("Pike stole a card from you!"), "Hidden-hand victim toast must not name the resource, got '%s'" % _toast_texts(ui))
	_pass_section("35. Steal Toasts Hot-seat Test (public wording, no resource leak while hidden)")

func _strip_chip_texts(ui: Node) -> String:
	var out := ""
	for c in ui._offer_strip_chips.get_children():
		if c is PanelContainer:
			for l in c.get_children():
				if l is Label:
					out += "|" + str((l as Label).text)
	return out

func _color_close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a) < 0.004

func _first_label_text(node: Node) -> String:
	for c in node.get_children():
		if c is Label:
			return str((c as Label).text)
		var sub := _first_label_text(c)
		if sub != "":
			return sub
	return ""

func _find_swatch_of(node: Node, col: Color) -> bool:
	for c in node.get_children():
		if c is ColorRect and _color_close((c as ColorRect).color, col):
			return true
		if c is Panel:
			var sb := (c as Control).get_theme_stylebox("panel")
			if sb is StyleBoxFlat and _color_close((sb as StyleBoxFlat).bg_color, col):
				return true
		if _find_swatch_of(c, col):
			return true
	return false

func _tray_has_mini_icon(node: Node, res_name: String) -> bool:
	for c in node.get_children():
		if c is CardFace and str((c as CardFace).tooltip_text).begins_with(res_name + " \u00d7"):
			return true
		if _tray_has_mini_icon(c, res_name):
			return true
	return false

func _collect_label_texts(node: Node) -> String:
	var out := ""
	for c in node.get_children():
		if c is Label:
			out += "|" + str((c as Label).text)
		out += _collect_label_texts(c)
	return out

func _find_label_containing(node: Node, needle: String) -> bool:
	for c in node.get_children():
		if c is Label and str((c as Label).text).contains(needle):
			return true
		if _find_label_containing(c, needle):
			return true
	return false

func _test_offer_strip_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(52005, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 2
	st.players[0]["hand"][GameTypes.ResourceType.IRON] = 2
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	ui._refresh_ui()
	_assert(bool(ui._offer_strip.visible), "The strip row stays reserved")
	_assert(not bool(ui._offer_strip_label.visible), "No open offer should mean an empty strip")
	# counter wording then withdraw
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	_assert(bool(ui._offer_strip.visible), "An open offer should show the strip")
	_assert(str(ui._offer_strip_label.text) == "Azure offers 1 Timber for 1 Grain", "Strip headline mismatch: '%s'" % str(ui._offer_strip_label.text))
	_assert(_strip_chip_texts(ui).contains("Dune: waiting") and _strip_chip_texts(ui).contains("Pike: waiting"), "Both responders should show waiting, got '%s'" % _strip_chip_texts(ui))
	ui.session.submit_action(1, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.IRON: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	_assert(_strip_chip_texts(ui).contains("Dune counters: gives 1 Grain, wants 1 Iron"), "Counter chip must use the unified wording: '%s'" % _strip_chip_texts(ui))
	ui._refresh_ui()
	_assert(_find_label_containing(ui._trade_tray, "COUNTER-OFFER"), "Partner card should carry the COUNTER-OFFER pill")
	_assert(_find_label_containing(ui._trade_tray, "You give"), "Counter card should show the 'You give' row")
	_assert(_find_button_by_text(ui._trade_tray, "Accept") != null, "Counter card should offer an Accept counter button")
	ui.session.submit_action(0, GameAction.cancel_open_trade())
	_assert(not bool(ui._offer_strip_label.visible), "Withdrawing must empty the strip")
	_assert(_toast_texts(ui).contains("Azure withdrew the offer."), "Withdraw should toast, got '%s'" % _toast_texts(ui))
	# accepted offer: chips, finalize, outcome toast
	ui.session.state.open_trades_this_turn = 0
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	ui.session.submit_action(1, GameAction.respond_open_trade("accept"))
	ui.session.submit_action(2, GameAction.respond_open_trade("decline"))
	_assert(_strip_chip_texts(ui).contains("Dune: ✓ accepts") and _strip_chip_texts(ui).contains("Pike: ✗ declines"), "Accept/decline chips mismatch: '%s'" % _strip_chip_texts(ui))
	var t0: int = int(ui.session.state.players[0]["hand"].get(GameTypes.ResourceType.TIMBER, 0))
	var g0: int = int(ui.session.state.players[0]["hand"].get(GameTypes.ResourceType.GRAIN, 0))
	ui.session.submit_action(0, GameAction.finalize_open_trade(1))
	_assert(not bool(ui._offer_strip_label.visible), "Resolving the offer must empty the strip")
	_assert(int(ui.session.state.players[0]["hand"].get(GameTypes.ResourceType.TIMBER, 0)) == t0 - 1 and int(ui.session.state.players[0]["hand"].get(GameTypes.ResourceType.GRAIN, 0)) == g0 + 1, "Finalized trade must swap the resources")
	_assert(_toast_texts(ui).contains("Azure traded 1 Timber to Dune for 1 Grain"), "Trade outcome toast must match the log line, got '%s'" % _toast_texts(ui))
	# bot-to-bot offer is visible to the human viewer
	ui.session.state.phase = GameTypes.TurnPhase.TURN_MAIN
	ui.session.state.current_player = 1
	ui.session.state.open_trades_this_turn = 0
	ui.session.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	_assert(bool(ui._offer_strip.visible), "Bot-to-bot offers should show the strip")
	_assert(str(ui._offer_strip_label.text).begins_with("Dune offers 1 Grain for 1 Timber"), "Bot offer headline mismatch: '%s'" % str(ui._offer_strip_label.text))
	_pass_section("36. Offer Strip Test (headline, chips, counter wording, outcome toasts)")

func _test_tray_close_controls_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(52006, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 4
	st.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 4
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 4
	st.players[2]["hand"][GameTypes.ResourceType.TIMBER] = 4
	st.players[2]["hand"][GameTypes.ResourceType.GRAIN] = 4
	ui._refresh_ui()
	ui._toggle_trade_tray()
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	_assert(bool(ui._trade_tray.visible), "The proposer's tray should stay open after proposing")
	_assert(ui._trade_close_btn != null and not bool(ui._trade_close_btn.disabled), "The tray must always have an enabled Close button")
	ui._trade_close_btn.pressed.emit()
	_assert(not bool(ui._trade_tray.visible), "Close must hide the tray")
	_assert(not bool(ui.session.state.open_trade.is_empty()), "Closing must NOT withdraw the offer")
	ui.session.submit_action(1, GameAction.respond_open_trade("decline"))
	ui._refresh_ui()
	_assert(not bool(ui._trade_tray.visible), "A dismissed waiting tray must not pop back while an AI still has to answer")
	ui.session.submit_action(2, GameAction.respond_open_trade("accept"))
	while ui.session.is_ai_to_act():
		ui.session.step_ai()  # bot review pass, then the proposer is on deck
	_assert(bool(ui._trade_tray.visible), "Once every answer is in, the proposer must be brought back to the tray")
	ui.session.submit_action(0, GameAction.finalize_open_trade(2))
	_assert(ui.session.state.open_trade.is_empty(), "The offer should have resolved")
	_assert(not bool(ui._trade_tray.visible), "My own resolved offer must auto-close the tray")
	# out of the loop: I decline a bot offer, then bots negotiate
	ui.session.state.phase = GameTypes.TurnPhase.TURN_MAIN
	ui.session.state.current_player = 1
	ui.session.state.open_trades_this_turn = 0
	ui.session.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	while ui.session.is_ai_to_act():
		ui.session.step_ai()  # new rule: bots answer first, then the human is asked
	_assert(bool(ui._trade_tray.visible), "The responder's tray should auto-open")
	ui._ot_decline_btn.pressed.emit()
	_assert(bool(ui._trade_tray.visible), "After answering, the tray stays available to the viewer")
	_assert(bool(ui._trade_watch_col.visible), "The watch column must be visible while bots negotiate")
	_assert(bool(ui._trade_respond_view.visible), "Answered controls stay available for revision (new rule)")
	_assert(str(ui._trade_title_lbl.text).begins_with("Dune offers"), "Watch title names the offer, got '%s'" % str(ui._trade_title_lbl.text))
	_assert(_find_label_containing(ui._trade_tray, "Declined"), "Watch rows show the viewer's own decline")
	_assert(bool(ui._offer_strip.visible), "The strip still covers the bot-to-bot offer")
	ui.session.submit_action(1, GameAction.cancel_open_trade())
	# Let the 1 s "No deal" result band lapse as it would in a real game.
	ui._ot_result_until_ms = 0
	ui._trade_watch_pacing()
	_assert(not bool(ui._trade_tray.visible), "The responder's tray closes once the offer and its result are gone")
	# board background click closes a manually opened tray
	ui.session.state.phase = GameTypes.TurnPhase.TURN_MAIN
	ui.session.state.current_player = 0
	ui.session.state.open_trades_this_turn = 0
	ui._refresh_ui()
	ui._toggle_trade_tray()
	_assert(bool(ui._trade_tray.visible), "T shortcut opens the tray")
	ui._on_board_background_clicked()
	_assert(not bool(ui._trade_tray.visible), "A board background click closes the tray")
	_pass_section("37. Trade Tray Close Test (always-on Close button, no withdraw, auto-close rules, board click)")

func _test_costs_popover_body(ui: Node) -> void:
	_assert(not ui.has_method("_on_build_road_pressed"), "The BUILD side rows must be gone")
	_assert(not ui.has_method("_refresh_build_rows"), "The build side column refresh must be gone")
	_assert(ui._help_costs_btn != null and str(ui._help_costs_btn.text) == "?", "The top bar needs a '?' costs button")
	ui._open_costs_popup()
	await ui.get_tree().process_frame
	_assert(bool(ui._costs_popup.visible), "The '?' button opens the costs popover")
	_assert(not (ui._costs_popup is Popup), "Costs popover must be an inline panel, not an OS popup window")
	var cp_style = ui._costs_popup.get_theme_stylebox("panel")
	_assert(cp_style is StyleBoxFlat, "Costs popover needs the paper panel style")
	_assert((cp_style as StyleBoxFlat).bg_color.v > 0.6, "Costs popover background must be light paper")
	_assert(_find_label_containing(ui._costs_popup, "Road"), "Costs popover lists Road")
	_assert(_find_label_containing(ui._costs_popup, "Settlement"), "Costs popover lists Settlement")
	_assert(_find_label_containing(ui._costs_popup, "City (upgrade)"), "Costs popover lists City")
	_assert(_find_label_containing(ui._costs_popup, "Action Card"), "Costs popover lists the Action Card cost")
	_assert(_find_label_containing(ui._costs_popup, "Click a glowing spot on the board to build."), "Costs popover explains board building")
	var city_cost: Dictionary = ui._build_cost_for("city")
	_assert(int(city_cost.get(GameTypes.ResourceType.GRAIN, 0)) == 2 and int(city_cost.get(GameTypes.ResourceType.IRON, 0)) == 3, "City cost must be 2 Grain + 3 Iron")
	ui._fill_build_bubble("settlement")
	var cells := 0
	for c in ui._build_bubble_cost_box.get_children():
		cells += 1
	_assert(cells == 4, "The build bubble should still show 4 cost cells for a settlement, got %d" % cells)
	for c in ui._costs_popup.get_children():
		for b in c.get_children():
			if b is Button and str((b as Button).text) == "Full help (F1)":
				(b as Button).pressed.emit()
	await ui.get_tree().process_frame
	_assert(not bool(ui._costs_popup.visible), "Full help closes the popover")
	_assert(bool(ui._help_overlay.visible), "Full help opens the help overlay")
	ui._help_overlay.visible = false
	_pass_section("38. Costs Popover Test (? button, costs popup, bubble still priced, no BUILD column)")

func _test_game_over_splash_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52007, seats, true, 0)
	var st: GameState = ui.session.state
	_assert(not bool(ui._splash_overlay.visible), "No splash while playing")
	st.vertex_owner[0] = 0
	st.vertex_building[0] = GameTypes.BuildingType.SETTLEMENT
	st.vertex_owner[1] = 1
	st.vertex_building[1] = GameTypes.BuildingType.CITY
	st.vertex_owner[2] = 1
	st.vertex_building[2] = GameTypes.BuildingType.CITY
	st.longest_route_holder = 1
	st.players[1]["dev_cards"] = [GameTypes.DevCardType.CHARTER_POINT]
	st.turn_number = 12
	st.winner = 1
	st.phase = GameTypes.TurnPhase.GAME_OVER
	var evs: Array[String] = []
	ui._on_state_updated(st, evs)
	await ui.get_tree().process_frame
	_assert(bool(ui._splash_overlay.visible), "Game over must show the splash")
	_assert(bool(ui._splash_shown), "Splash flag set")
	_assert(str(ui._splash_title.text) == "Dune wins!", "Title should announce the winner, got '%s'" % str(ui._splash_title.text))
	_assert(str(ui._splash_turns.text) == "Played 12 turns", "Turn count line, got '%s'" % str(ui._splash_turns.text))
	_assert(_find_label_containing(ui._splash_rows, "Dune (AI)"), "Standings name the AI as AI")
	_assert(_find_label_containing(ui._splash_rows, "Azure (Human)"), "Standings name the human as Human")
	_assert(_find_label_containing(ui._splash_rows, "Longest Route"), "Route bonus shown as words")
	_assert(_find_label_containing(ui._splash_rows, "1 Charter point"), "Charter shown as words")
	_assert(_find_label_containing(ui._splash_rows, "0 settlements · 2 cities"), "Buildings shown as words, rows: %s" % _splash_row_texts(ui))
	_assert(ui._splash_title.get_theme_color("font_color") == Palette.HEADING, "Winner title must use the dark heading colour")
	_assert(_color_close(ui._splash_banner.color, GameTypes.PLAYER_COLORS[1].darkened(0.15)), "Banner carries the winner colour")
	_assert(bool(ui._any_overlay_visible()), "Splash counts as an overlay")
	_assert(ui._splash_quit_btn != null and bool(ui._splash_quit_btn.visible), "The results splash has a visible Quit button")
	_assert(str(ui._splash_quit_btn.text) == "Quit", "The fourth splash button reads Quit, got '%s'" % str(ui._splash_quit_btn.text))
	_assert(ui._splash_quit_btn.get_parent() == ui._splash_lobby_btn.get_parent(), "Quit sits in the splash button row")
	_assert(ui._splash_quit_btn.get_index() == ui._splash_lobby_btn.get_parent().get_child_count() - 1, "Quit is the last button in the row")
	ui._splash_view_board_btn.pressed.emit()
	_assert(not bool(ui._splash_overlay.visible), "View Board hides the splash")
	_assert(bool(ui._results_btn.visible), "A Results button appears to bring it back")
	ui._results_btn.pressed.emit()
	_assert(bool(ui._splash_overlay.visible), "Results reopens the splash")
	ui._splash_lobby_btn.pressed.emit()
	_assert(bool(ui._lobby_overlay.visible), "Back to Lobby opens the lobby")
	_assert(not bool(ui._splash_overlay.visible), "Lobby hides the splash")
	ui._splash_new_game_btn.pressed.emit()
	_assert(not bool(ui._splash_overlay.visible), "New Game hides the splash")
	_assert(ui.session.state.phase != GameTypes.TurnPhase.GAME_OVER, "New Game starts a fresh match")
	_assert(not bool(ui._splash_shown), "Splash flags reset on a new match")
	_pass_section("39. Game Over Splash Test (winner, standings detail, view board / results / lobby / new game)")

func _splash_row_texts(ui: Node) -> String:
	var out := ""
	for hbox in ui._splash_rows.get_children():
		for c in hbox.get_children():
			if c is Label:
				out += "[" + str((c as Label).text) + "]"
		out += "|"
	return out

func _test_discard_layout_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52008, seats, true, 0)
	root.size = Vector2i(1280, 800)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	ui._refresh_ui()
	_assert(ui._hand_bar_panel.get_combined_minimum_size().x <= 1280.0, "Bottom bar fits 1280 in normal mode too, got %.1f" % ui._hand_bar_panel.get_combined_minimum_size().x)
	st.phase = GameTypes.TurnPhase.TURN_DISCARD
	st.current_player = 0
	st.pending_discards = {0: 4}
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 3
	st.players[0]["hand"][GameTypes.ResourceType.CLAY] = 2
	st.players[0]["hand"][GameTypes.ResourceType.FLEECE] = 1
	st.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 1
	st.players[0]["hand"][GameTypes.ResourceType.IRON] = 1
	ui._refresh_ui()
	await ui.get_tree().process_frame
	_assert(ui._hand_bar_panel.get_combined_minimum_size().x <= 1280.0, "Bottom bar must not force the UI wider than 1280, got %.1f" % ui._hand_bar_panel.get_combined_minimum_size().x)
	var sb: Control = ui._scoreboard_box
	var sb_rect := sb.get_global_rect()
	var vp := Rect2(Vector2.ZERO, Vector2(1280, 800))
	_assert(sb_rect.end.x <= vp.end.x + 0.5 and sb_rect.end.y <= vp.end.y + 0.5 and sb_rect.position.x >= -0.5, "Scoreboard must stay inside the window, got %s" % str(sb_rect))
	_assert(bool(ui._end_turn_btn.visible) and bool(ui._end_turn_btn.disabled), "End Turn stays put but disabled while discarding")
	_assert(bool(ui._buy_card_btn.visible) and bool(ui._buy_card_btn.disabled), "Buy card stays put but disabled while discarding")
	_assert(bool(ui._dice_widget.visible) and not bool(ui._dice_widget.get("_roll_enabled")), "Dice stay put but inert while discarding")
	for ctype in ui._action_chips.keys():
		_assert(bool(ui._action_chips[ctype].visible), "Action card chips stay put while discarding")
	ui._discard_pick_one(GameTypes.ResourceType.TIMBER)
	ui._discard_pick_one(GameTypes.ResourceType.TIMBER)
	var tface: CardFace = ui._res_card_refs[GameTypes.ResourceType.TIMBER]
	_assert(int(tface.count) == 3, "Cards keep their normal counts, got 'x%d'" % int(tface.count))
	_assert(int(tface.badge) == 2, "Badge shows the pick count, got %d" % int(tface.badge))
	var stray_badge := false
	for r in GameTypes.ALL_RESOURCES:
		var f: CardFace = ui._res_card_refs[r]
		if int(f.badge) > 0 and int(ui._discard_pick.get(r, 0)) <= 0:
			stray_badge = true
	_assert(not stray_badge, "Only picked cards may carry a badge")
	root.size = Vector2i(64, 64)
	await ui.get_tree().process_frame
	_pass_section("40. Discard Layout Test (1280-wide bottom bar, hidden extras, badge counts)")

func _test_stale_discard_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52009, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_DISCARD
	st.current_player = 0
	st.pending_discards = {0: 4}
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 3
	st.players[0]["hand"][GameTypes.ResourceType.CLAY] = 2
	ui._refresh_ui()
	ui._discard_pick_one(GameTypes.ResourceType.TIMBER)
	ui._discard_pick_one(GameTypes.ResourceType.TIMBER)
	_assert(int(ui._discard_pick.get(GameTypes.ResourceType.TIMBER, 0)) == 2, "Picked before leaving discard mode")
	st.pending_discards.clear()
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	ui._refresh_ui()
	var any_badge := false
	for r in GameTypes.ALL_RESOURCES:
		if int(ui._res_card_refs[r].badge) > 0:
			any_badge = true
	_assert(not any_badge, "No '−' badge may remain after the discard requirement ends")
	_assert(int(ui._discard_picked_total()) == 0, "Picks must clear when the requirement ends")
	_assert(bool(ui._end_turn_btn.visible), "The bottom bar returns to normal")
	_assert(int(ui._res_card_refs[GameTypes.ResourceType.TIMBER].count) == 3, "Counts back to normal")
	_pass_section("41. Stale Discard Display Test (badges and picks clear on refresh)")

func _test_splash_winner_order_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52010, seats, true, 0)
	var st: GameState = ui.session.state
	# VP tie: Azure 2 settlements (2 VP), Dune 1 city (2 VP) — Dune leads get_standings()
	st.vertex_owner[0] = 0
	st.vertex_building[0] = GameTypes.BuildingType.SETTLEMENT
	st.vertex_owner[1] = 0
	st.vertex_building[1] = GameTypes.BuildingType.SETTLEMENT
	st.vertex_owner[2] = 1
	st.vertex_building[2] = GameTypes.BuildingType.CITY
	st.winner = 0
	st.phase = GameTypes.TurnPhase.GAME_OVER
	var evs: Array[String] = []
	ui._on_state_updated(st, evs)
	await ui.get_tree().process_frame
	_assert(str(ui._splash_title.text) == "Azure wins!", "Title must follow state.winner, got '%s'" % str(ui._splash_title.text))
	_assert(_color_close(ui._splash_banner.color, GameTypes.PLAYER_COLORS[0].darkened(0.15)), "Banner follows state.winner")
	var first_row := str(ui._splash_rows.get_child(0).get_child(2).text)
	_assert(first_row.begins_with("Azure"), "Winner row must come first even on a tie, got '%s'" % first_row)
	_pass_section("42. Splash Winner Order Test (state.winner leads on a tie)")

func _test_card_face_body(ui: Node) -> void:
	var made: Array = []
	for r in GameTypes.ALL_RESOURCES:
		var f := CardFace.new()
		f.kind = "resource"
		f.resource = r
		f.count = 5
		f.size = Vector2(64, 90)
		ui.add_child(f)
		made.append(f)
		var f0 := CardFace.new()
		f0.kind = "resource"
		f0.resource = r
		f0.count = 0
		f0.size = Vector2(64, 90)
		ui.add_child(f0)
		made.append(f0)
	for a in range(5):
		var fa := CardFace.new()
		fa.kind = "action"
		fa.action = a
		fa.count = 5
		fa.size = Vector2(64, 90)
		ui.add_child(fa)
		made.append(fa)
	var fb := CardFace.new()
	fb.kind = "back"
	fb.size = Vector2(64, 90)
	ui.add_child(fb)
	made.append(fb)
	var fhidden := CardFace.new()
	fhidden.kind = "resource"
	fhidden.resource = GameTypes.ResourceType.IRON
	fhidden.hidden_card = true
	fhidden.count = 3
	fhidden.size = Vector2(64, 90)
	ui.add_child(fhidden)
	made.append(fhidden)
	await ui.get_tree().process_frame
	for f in made:
		f.queue_redraw()
	await ui.get_tree().process_frame
	for f in made:
		_assert(f.size.x > 0 and f.size.y >= f.size.x, "CardFace keeps the portrait ratio, got %s" % str(f.size))
		_assert(f.get_combined_minimum_size().x > 0, "CardFace has a minimum size")
	var hits := 0
	for face in ui._res_card_refs.values():
		if face is CardFace and (face as CardFace).kind == "resource":
			hits += 1
	_assert(hits == GameTypes.ALL_RESOURCES.size(), "Hand bar holds 5 resource CardFaces, got %d" % hits)
	var st: GameState = ui.session.state
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 4
	ui._refresh_ui()
	_assert(int(ui._res_card_refs[GameTypes.ResourceType.GRAIN].count) == 4, "CardFace count follows the hand")
	_assert(int(ui._res_card_refs[GameTypes.ResourceType.TIMBER].count) == 0, "Empty resources show count 0")
	var chips_ok := true
	for ctype in ui._action_chips.keys():
		var chip: CardFace = ui._action_chips[ctype]
		if chip.kind != "action":
			chips_ok = false
	_assert(chips_ok, "Action chips are CardFaces")
	_pass_section("43. Card Face Test (resource/action/back variants draw, counts follow the hand)")

func _test_bank_stacks_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52011, seats, true, 0)
	ui._refresh_ui()
	var st: GameState = ui.session.state
	var ok := true
	for r in GameTypes.ALL_RESOURCES:
		var bf: CardFace = ui._bank_faces[r]
		if int(bf.count) != int(st.bank.get(r, 0)) or int(bf.pile_count) != int(st.bank.get(r, 0)):
			ok = false
	_assert(ok, "Bank piles mirror state.bank in count and edges")
	_assert(ui._bank_deck_face != null and int(ui._bank_deck_face.pile_count) == st.dev_deck.size(), "The deck stack mirrors state.dev_deck")
	st.bank[GameTypes.ResourceType.TIMBER] = 3
	st.bank[GameTypes.ResourceType.IRON] = 0
	ui._refresh_ui()
	var tface: CardFace = ui._bank_faces[GameTypes.ResourceType.TIMBER]
	var iface: CardFace = ui._bank_faces[GameTypes.ResourceType.IRON]
	_assert(int(tface.pile_count) == 3 and bool(tface.pile_low_tint), "Low piles tint their edges red")
	_assert(int(iface.pile_count) == 0 and bool(iface.pile_low_tint) and not bool(iface.count_badge), "Empty piles are a faint slot with no number")
	_assert(tface.tooltip_text.contains("3") and iface.tooltip_text.contains("0"), "The exact number stays on hover")
	st.bank[GameTypes.ResourceType.GRAIN] = 19
	ui._refresh_ui()
	var grain_ok := true
	for r in GameTypes.ALL_RESOURCES:
		var bf2: CardFace = ui._bank_faces[r]
		if int(bf2.stack_depth) != 0 or int(bf2.mouse_filter) != int(Control.MOUSE_FILTER_PASS) or int(bf2.focus_mode) != int(Control.FOCUS_NONE):
			grain_ok = false
	_assert(grain_ok, "Bank piles drop the old stack layers and stay pass-through, unfocusable cards")
	_assert(int(ui._bank_faces[GameTypes.ResourceType.GRAIN].pile_count) == 19, "A full pile draws every edge")
	_assert(_numeric_label_count(ui._bank_deck_face.get_parent().get_parent()) == 0, "The bank row holds no number labels")
	_assert(bool(ui._bank_faces.values()[0] is CardFace), "Bank stacks are CardFaces")
	_pass_section("44. Bank Stacks Test (real pile edges, red low-stock cue, counts on hover)")

func _test_port_badges_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52012, seats, true, 0)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var bv = ui._board_view
	_assert(not bool(bv.show_port_names), "Port names are hidden by default")
	_assert(bv.get_port_count() > 0, "Ports exist on the board")
	var any_name := false
	for i in range(bv.get_port_count()):
		if bool(bv.port_name_visible_for(i)):
			any_name = true
	_assert(not any_name, "No port name pill is drawn without the setting or hover")
	bv.show_port_names = true
	for i in range(bv.get_port_count()):
		_assert(bool(bv.port_name_visible_for(i)), "The setting shows every port name")
	bv.show_port_names = false
	bv._hovered_port = 0
	_assert(bool(bv.port_name_visible_for(0)), "Hovering a port shows its name")
	_assert(not bool(bv.port_name_visible_for(1)), "Hovering shows only the hovered port's name")
	bv._hovered_port = -1
	_assert(bv._port_badge_rects.size() == bv.get_port_count(), "Every port gets a badge rect")
	ui._settings_portnames_check.set_pressed_no_signal(true)
	ui._settings_portnames_check.toggled.emit(true)
	_assert(bool(bv.show_port_names), "The Settings toggle drives the board")
	ui._settings_portnames_check.toggled.emit(false)
	_pass_section("45. Port Badges Test (no name pills without setting or hover, toggle works)")

func _test_action_anim_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52013, seats, true, 0)
	var st: GameState = ui.session.state
	var toasts_before: int = ui._toast_layer.get_child_count()
	var anims_before: int = int(ui._board_view.anim_count)
	var evs1: Array[String] = ["Dune built a settlement at vertex 7."]
	ui._animate_from_events(evs1, st)
	await ui.get_tree().process_frame
	_assert(int(ui._board_view.anim_count) > anims_before, "Bot build raises the board animation counter")
	_assert(ui._board_view._build_anims.size() >= 1, "Build pop-in animation is queued")
	_assert(ui._toast_layer.get_child_count() > toasts_before, "Bot build raises a toast")
	var toasts_now: int = ui._toast_layer.get_child_count()
	var evs2: Array[String] = ["Azure built a settlement at vertex 8."]
	ui._animate_from_events(evs2, st)
	_assert(ui._toast_layer.get_child_count() == toasts_now, "Human actions do not add toasts")
	ui._prev_blocker_tile = 3
	var evs3: Array[String] = ["Dune moved the Blocker to tile 9."]
	ui._animate_from_events(evs3, st)
	_assert(int(ui._board_view._blocker_from_tile) == 3, "Blocker slide starts from the previous tile")
	ui._reduce_motion = true
	ui._board_view.reduce_motion = true
	var evs4: Array[String] = ["Dune built a road on edge 4."]
	ui._animate_from_events(evs4, st)
	await ui.get_tree().process_frame
	var has_static := false
	for a in ui._board_view._build_anims:
		if bool(a.get("static", false)):
			has_static = true
	_assert(has_static, "Reduce motion swaps pops for static highlight rings")
	var many: Array[String] = []
	for i in range(5):
		many.append("Dune bought an Action Card.")
	ui._animate_from_events(many, st)
	await ui.get_tree().process_frame
	_assert(ui._toast_layer.get_child_count() <= 3, "At most 3 toasts stack, got %d" % ui._toast_layer.get_child_count())
	ui._reduce_motion = false
	ui._start_steal_anim(0, 1, GameTypes.ResourceType.TIMBER, st)
	_assert(ui._last_fly_kind != "", "Steal flight starts once motion is back on")
	_assert(ui._hand_count_hold.has(1), "Thief gets a display hold while the card is in flight")
	ui._finish_steal_anim()
	ui._reduce_motion = false
	ui._board_view.reduce_motion = false
	_pass_section("46. Action Feedback Test (bot toasts, build anims, blocker slide, reduce motion)")

func _test_blocker_piece_body(ui: Node) -> void:
	var idx := 0
	var seen: Array[float] = []
	for sz in [Vector2i(520, 460), Vector2i(760, 670), Vector2i(1150, 990)]:
		idx += 1
		var st := GameState.create_new_game(4242 + idx, 3, true)
		var bv := BoardView.new()
		ui.add_child(bv)
		bv.custom_minimum_size = Vector2.ZERO
		bv.reduce_motion = true
		bv.state = st
		bv.size = Vector2(sz)
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		bv.queue_redraw()
		await ui.get_tree().process_frame
		await ui.get_tree().process_frame
		var r: float = bv._get_hex_radius()
		seen.append(r)
		_assert(st.blocker_tile >= 0, "Blocker sits on the board at %s" % str(sz))
		_assert(bv.blocker_anim_phase() == "", "No blocker animation while static at %s" % str(sz))
		bv.queue_free()
	_assert(seen.size() == 3 and seen[0] < seen[1] and seen[1] < seen[2], "Hex radii climbed: %s" % str(seen))
	_assert(seen[2] >= 60.0, "The large board gives a big blocker canvas (r=%.0f)" % seen[2])
	_pass_section("82. Blocker Piece Test (hooded highwayman at every hex size)")

func _test_ghibli_emblems_body(ui: Node) -> void:
	var specs: Array = [
		["resource", GameTypes.ResourceType.TIMBER],
		["resource", GameTypes.ResourceType.FLEECE],
		["resource", GameTypes.ResourceType.IRON],
		["action", GameTypes.DevCardType.GUARD],
	]
	var drawn := 0
	for wid in [18, 26, 44, 62]:
		for spec in specs:
			var f := CardFace.new()
			f.kind = str(spec[0])
			if str(spec[0]) == "resource":
				f.resource = int(spec[1])
			else:
				f.action = int(spec[1])
			f.emblem_only = true
			f.custom_minimum_size = Vector2(wid, wid * 7.0 / 5.0)
			ui.add_child(f)
			await ui.get_tree().process_frame
			await ui.get_tree().process_frame
			drawn += 1
			f.queue_free()
	_assert(drawn == 16, "Drew 16 Ghibli emblem faces, got %d" % drawn)
	_pass_section("83. Ghibli Emblem Test (Timber, Fleece, Iron, Guard at four sizes)")

func _test_trade_respond_close_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(4811, seats, true, 0)
	var offered := _ui_force_bot_offer(ui)
	_assert(offered, "Bot offer should be pending while the human answers")
	if not offered:
		return
	await _ui_settle(2)
	var st: GameState = ui.session.state
	_assert(bool(ui._ot_awaits_view()), "The open offer must await the viewer's answer")
	_assert(bool(ui._trade_tray.visible), "Respond panel should be open for the responder")
	_assert(bool(ui._trade_respond_mode), "Panel should be in respond mode")
	_assert(bool(ui._human_can_progress()), "Responder always has at least one legal action")
	_assert(ui._trade_close_btn.tooltip_text == "Decline and close (Esc)", "Close tooltip must name the decline")
	_assert(bool(ui._offer_strip_respond_btn.visible), "Offer strip must show a Respond button while an answer is pending")
	# a background close attempt must never strand a pending responder
	ui._on_board_background_clicked()
	_assert(bool(ui._trade_tray.visible), "Board click must not close the panel while an answer is pending")
	ui._set_tray_panel_visible(false)
	ui._refresh_ui()
	_assert(bool(ui._trade_tray.visible), "Pending responder's panel must reopen automatically")
	await _ui_settle(1)
	_ui_real_click(ui._trade_close_btn)
	st = ui.session.state
	var responses: Dictionary = st.open_trade.get("responses", {})
	_assert(responses.has(0), "Closing the panel in respond mode must submit a decline")
	if responses.has(0):
		_assert(str((responses[0] as Dictionary).get("status", "")) == "decline", "Close must decline, not accept")
	_assert(not bool(ui._trade_tray.visible), "Panel closes after the decline is submitted")
	_assert(not bool(ui._offer_strip_respond_btn.visible), "Respond button hides once the viewer has answered")
	_assert(bool(ui._human_can_progress()), "No dead end after declining: bots resolve the offer")
	var guard := 0
	while not ui.session.state.open_trade.is_empty() and guard < 400:
		guard += 1
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
		else:
			break
	_assert(ui.session.state.open_trade.is_empty(), "Offer should resolve after all bots answer")
	_pass_section("84. Respond Dead-End Test (close/Esc decline for responder; strip Respond; real click)")

func _test_counter_edit_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(4812, seats, true, 0)
	var offered := _ui_force_bot_offer(ui)
	_assert(offered, "Bot offer should be pending for the counter test")
	if not offered:
		return
	await _ui_settle(2)
	var st: GameState = ui.session.state
	_assert(bool(ui._ot_counter_btn.visible) and not bool(ui._ot_counter_btn.disabled), "Counter button must be live")
	_ui_real_click(ui._ot_counter_btn)
	await _ui_settle(2)
	st = ui.session.state
	_assert(bool(ui._trade_counter_mode), "Counter mode should engage")
	_assert(bool(ui._trade_rows_col.visible), "Counter must show editable rows")
	var ot: Dictionary = st.open_trade
	var get_res := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(ot.get("request", {}).get(r, 0)) > 0:
			get_res = r
	_assert(get_res != -1, "Forced offer should request a resource")
	_assert(int(ui._trade_give_counts.get(get_res, 0)) == 1, "Counter give row must be pre-filled with their request")
	# edit the get side with a real click on a face that is not pre-filled
	var pick_get := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(ui._trade_get_counts.get(r, 0)) == 0 and int(ui._trade_give_counts.get(r, 0)) == 0:
			pick_get = r
			break
	_assert(pick_get != -1, "There should be an empty get slot")
	_ui_real_click(ui._trade_get_faces[pick_get])
	_assert(int(ui._trade_give_counts.get(get_res, 0)) == 1, "Counter give row stays pre-filled")
	_assert(int(ui._trade_get_counts.get(pick_get, 0)) == 1, "A real click must edit the get row")
	# edit the give side: click a hand card that still has headroom
	var hand: Dictionary = st.players[0].hand
	var pick_hand := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(hand.get(r, 0)) > int(ui._trade_give_counts.get(r, 0)):
			pick_hand = r
			break
	if pick_hand != -1:
		var before := int(ui._trade_give_counts.get(pick_hand, 0))
		_ui_real_click(ui._res_card_refs[pick_hand])
		_assert(int(ui._trade_give_counts.get(pick_hand, 0)) == before + 1, "A hand click must add to the counter give row")
	# and a give chip click must take one back
	var chip: CardFace = null
	for c in ui._trade_give_box.get_children():
		if c is CardFace and bool((c as CardFace).visible) and int((c as CardFace).count) > 0:
			chip = c as CardFace
	await _ui_settle(1)
	if chip != null:
		var res_chip := chip.resource
		var before2 := int(ui._trade_give_counts.get(res_chip, 0))
		_p31_press(chip, chip.count_hit_rect().get_center())
		_assert(int(ui._trade_give_counts.get(res_chip, 0)) == before2 - 1, "Tapping a give chip's count must take one back")
	await _ui_settle(1)
	_assert(not bool(ui._ot_send_btn.disabled), "Send counter must be enabled with both sides set")
	_ui_real_click(ui._ot_send_btn)
	st = ui.session.state
	var responses: Dictionary = st.open_trade.get("responses", {})
	_assert(responses.has(0) and str((responses[0] as Dictionary).get("status", "")) == "counter", "Send must post a counter with the edited terms")
	_assert(bool(ui._human_can_progress()), "No dead end after countering")
	var guard := 0
	while not ui.session.state.open_trade.is_empty() and guard < 400:
		guard += 1
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
		else:
			break
	_pass_section("85. Counter Editing Test (prefilled mirrored rows; real clicks edit give and get; counter posted)")

func _test_offer_cap_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4813, seats, true, 0)
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty() and GameTypes.hand_total(st.players[0]["hand"]) >= 1
	)
	_assert(reached, "Human main phase with cards should be reachable")
	if not reached:
		return
	if bool(ui._trade_tray.visible):
		ui._toggle_trade_tray()
	ui.session.state.open_trades_this_turn = 3
	ui._refresh_ui()
	_assert(bool(ui._trade_ask_btn.disabled), "Ask Players must be disabled at the offer cap")
	_assert(ui._trade_ask_btn.tooltip_text == "No player offers left this turn (3 of 3). Bank and port trades still work.", "Cap tooltip must carry the exact sentence")
	_assert(bool(ui._trade_offers_lbl.visible) and ui._trade_offers_lbl.text == "No player offers left this turn (3 of 3). Bank and port trades still work.", "Cap sentence must also show as a muted line")
	var held := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(ui.session.state.players[0]["hand"].get(r, 0)) >= 1:
			held = r
			break
	_assert(held != -1, "Human should hold a card")
	_ui_real_click(ui._res_card_refs[held])
	await _ui_settle(2)
	_assert(bool(ui._trade_tray.visible), "Cards must still open the panel at the cap")
	_assert(int(ui._trade_give_counts.get(held, 0)) == 1, "Hand click must still draft at the cap")
	var other := -1
	for r in GameTypes.ALL_RESOURCES:
		if r != held:
			other = r
			break
	_ui_real_click(ui._trade_get_faces[other])
	_assert(int(ui._trade_get_counts.get(other, 0)) == 1, "Bank/port side must stay editable at the cap")
	_assert(bool(ui._trade_ask_btn.disabled), "Ask Players stays disabled at the cap")
	ui.session.state.open_trades_this_turn = 0
	ui._refresh_ui()
	_assert(not bool(ui._trade_ask_btn.disabled), "Headroom restores Ask Players")
	_pass_section("86. Offer Cap Test (only posting buttons lock at 3/3; panel, cards and bank stay live)")

func _test_decline_dead_end_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(4814, seats, true, 0)
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty() and GameTypes.hand_total(st.players[0]["hand"]) >= 1
	)
	_assert(reached, "Human main phase with cards should be reachable")
	if not reached:
		return
	var give_res := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(ui.session.state.players[0]["hand"].get(r, 0)) >= 1:
			give_res = r
	var get_res := (give_res + 1) % GameTypes.ALL_RESOURCES.size()
	var opened: Dictionary = ui.session.submit_action(0, GameAction.open_trade({give_res: 1}, {get_res: 1}))
	_assert(bool(opened.get("ok", false)), "Human offer should open")
	if not bool(opened.get("ok", false)):
		return
	for pid in [1, 2]:
		ui.session.submit_action(pid, GameAction.respond_open_trade("decline"))
	while ui.session.is_ai_to_act():
		ui.session.step_ai()  # bot review pass before the proposer acts
	ui._refresh_ui()
	_assert(bool(ui._trade_tray.visible), "Proposer keeps the panel when everyone declined")
	_assert(not bool(ui.session.state.open_trade.is_empty()), "Offer stays open until the proposer withdraws it")
	_assert(bool(ui._human_can_progress()), "All-declined state must not be a dead end")
	await _ui_settle(1)
	_assert(not bool(ui._end_turn_btn.disabled), "End Turn must be live for the proposer")
	_ui_real_click(ui._end_turn_btn)
	_assert(ui.session.state.open_trade.is_empty(), "End Turn must withdraw the offer in one click")
	_assert(ui.session.state.current_player != 0, "End Turn must pass the turn")
	_pass_section("87. Decline Dead-End Test (all declines leave withdraw + one-click End Turn)")

func _test_badge_geometry_body(ui: Node) -> void:
	for w in [26.0, 34.0, 62.0, 120.0]:
		var face := CardFace.new()
		face.size = Vector2(w, w / CardFace.RATIO)
		face.count = 3
		face.count_badge = true
		var r: float = face.count_badge_rect().size.x * 0.5
		var bc: Vector2 = face.count_badge_rect().get_center()
		var cr0: Rect2 = face._card_rect()
		var host := Rect2(Vector2.ZERO, face.size)
		if w < 50.0:
			_assert(r <= w * 0.20 + 0.01, "Trade-row badge diameter must stay under 40%% of card width (w=%f, r=%f)" % [w, r])
			_assert(host.grow(-1.9).encloses(face.count_badge_rect()), "Trade-row badge stays inside its control (w=%f, got %s)" % [w, str(face.count_badge_rect())])
			_assert(absf(bc.x - minf(cr0.end.x, w - r - 2.0)) < 0.01, "Trade-row badge hugs the corner but clamps inside (w=%f)" % w)
		else:
			_assert(r <= w * 0.28 + 0.01 and r >= minf(8.0, w * 0.28) - 0.01, "Wide-card badge radius rule (w=%f, r=%f)" % [w, r])
			_assert(host.grow(-1.9).encloses(face.count_badge_rect()), "Wide-card badge stays fully inside the control (w=%f, got %s)" % [w, str(face.count_badge_rect())])
			_assert(absf(bc.x - (cr0.end.x - r - 2.0)) < 0.01 and absf(bc.y - (cr0.position.y + r + 2.0)) < 0.01, "Wide-card badge sits inside the card corner (w=%f)" % w)
		face.free()
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4815, seats, true, 0)
	await _ui_settle(2)
	var st: GameState = ui.session.state
	var res_ids: Array = GameTypes.ALL_RESOURCES
	st.open_trade = {
		"from": 1,
		"offer": {int(res_ids[0]): 2, int(res_ids[1]): 1},
		"request": {int(res_ids[2]): 1},
		"responses": {},
	}
	ui._refresh_ui()
	await _ui_settle(2)
	_assert(bool(ui._trade_tray.visible) and bool(ui._trade_respond_mode), "Respond panel should show the injected offer")
	var got_badge := false
	var got_single := false
	for c in ui._trade_ro_get_box.get_children():
		if not (c is CardFace):
			continue
		var f := c as CardFace
		if not bool(f.visible):
			continue
		if f.count > 1:
			got_badge = true
			_assert(bool(f.count_badge), "Faces with a real count keep their badge")
			var rr: float = f.count_badge_rect().size.x * 0.5
			_assert(rr <= f.size.x * 0.20 + 0.01, "Respond-row badge fits under 40% of the icon width")
		else:
			got_single = true
			_assert(bool(f.count_badge), "A 1x read-only icon wears its badge")
	_assert(got_badge and got_single, "Respond row should contain both a 2x and a 1x icon")
	st.open_trade = {}
	ui._refresh_ui()
	_pass_section("88. Trade Badge Geometry Test (tiered: small clamped-corner <=40pct, wide inset-in-card, no badge on 1x)")

func _test_chip_hover_banner_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4816, seats, true, 0)
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase should be reachable")
	if not reached:
		return
	var st: GameState = ui.session.state
	if not st.players[0]["dev_cards"].has(GameTypes.DevCardType.GUARD):
		st.players[0]["dev_cards"].append(GameTypes.DevCardType.GUARD)
	for r in [GameTypes.ResourceType.FLEECE, GameTypes.ResourceType.GRAIN, GameTypes.ResourceType.IRON]:
		st.players[0]["hand"][r] = int(st.players[0]["hand"].get(r, 0)) + 1
	ui._refresh_ui()
	await _ui_settle(2)
	var help := str(load(UI_SCRIPT_PATH).DEV_CARD_HELP.get(GameTypes.DevCardType.GUARD, ""))
	_assert(help.length() > 10, "DEV_CARD_HELP must carry a real sentence")
	var chip: CardFace = ui._action_chips[GameTypes.DevCardType.GUARD]
	_assert(chip.tooltip_text.contains(help), "Guard chip tooltip must contain the help sentence, got: %s" % chip.tooltip_text)
	_assert(ui._buy_card_btn.tooltip_text.contains("1 Fleece + 1 Grain + 1 Iron"), "Buy tooltip must state the cost")
	_assert(ui._buy_card_btn.tooltip_text.contains("deck left:"), "Buy tooltip must reveal the remaining deck")
	var base_banner: String = ui._status_banner_label.text
	var chip_pos := chip.get_global_transform() * (chip.size * 0.5)
	var m := InputEventMouseMotion.new()
	m.position = chip_pos
	m.global_position = chip_pos
	m.relative = Vector2(1, 1)
	Input.parse_input_event(m)
	await _ui_settle(1)
	if ui.get_viewport().has_method("gui_get_hovered_control"):
		var hov := ui.get_viewport().gui_get_hovered_control()
		_assert(hov == chip, "Real mouse motion must put the Guard chip under the cursor")
	_assert(ui._status_banner_label.text.contains("Guard"), "Hovering the chip must swap the banner to the card sentence, got: %s" % ui._status_banner_label.text)
	var away := InputEventMouseMotion.new()
	away.position = Vector2(2, 2)
	away.global_position = Vector2(2, 2)
	away.relative = Vector2(-1, -1)
	Input.parse_input_event(away)
	await _ui_settle(1)
	_assert(not ui._status_banner_label.text.contains(help), "Leaving the chip must restore the normal instruction banner")
	_assert(ui._status_banner_label.text.length() > 0, "Banner must stay populated after hover")
	_pass_section("89. Card Help Hover Test (real hover: chip tooltip + instruction banner swap and restore)")

func _test_collapsed_log_height_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4817, seats, true, 0)
	await _ui_settle(3)
	_assert(not bool(ui._log_toggle_btn.button_pressed), "Log starts collapsed")
	var h0: float = ui._log_panel.custom_minimum_size.y
	var log_size0: float = ui._log_panel.size.y
	_assert(ui._log_panel.custom_minimum_size.y >= 56.0, "Collapsed log must fit ~4 rows without the trade panel")
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main should be reachable")
	if not reached:
		return
	ui._set_tray_panel_visible(true)
	await _ui_settle(2)
	_assert(bool(ui._trade_tray.visible), "Trade panel should be open for the height test")
	_assert(absf(ui._log_panel.custom_minimum_size.y - h0) < 0.5, "The log slot keeps its height while the trade panel opens")
	_assert(absf(ui._log_panel.size.y - log_size0) < 0.5, "The log panel's rect must not move when the trade panel opens")
	ui._set_tray_panel_visible(false)
	await _ui_settle(2)
	_assert(absf(ui._log_panel.custom_minimum_size.y - h0) < 0.5, "Log slot height unchanged after closing the panel")
	_pass_section("90. Log Slot Constant Test (log height never changes with the trade panel)")

func _test_cursor_shapes_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4818, seats, true, 0)
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main should be reachable")
	if not reached:
		return
	await _ui_settle(2)
	var held := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(ui.session.state.players[0]["hand"].get(r, 0)) >= 1:
			held = r
	_assert(held != -1, "Human should hold a card")
	_assert(int(ui._res_card_refs[held].mouse_default_cursor_shape) == Control.CURSOR_POINTING_HAND, "Own turn + tradeable card shows the pointing hand")
	var empty := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(ui.session.state.players[0]["hand"].get(r, 0)) <= 0:
			empty = r
	if empty != -1:
		_assert(int(ui._res_card_refs[empty].mouse_default_cursor_shape) == Control.CURSOR_FORBIDDEN, "Unplayable card on own turn shows the forbidden cursor")
	_assert(int(ui._action_chips[GameTypes.DevCardType.CHARTER_POINT].mouse_default_cursor_shape) == Control.CURSOR_FORBIDDEN, "Charter is never playable on your turn")
	_assert(int(ui._dice_widget.mouse_default_cursor_shape) == Control.CURSOR_ARROW, "Dice show plain arrow outside roll phase")
	ui._submit_human_action(GameAction.end_turn())
	await _ui_settle(2)
	_assert(int(ui._res_card_refs[held].mouse_default_cursor_shape) == Control.CURSOR_ARROW, "During bot turns hand cards show plain arrow")
	_assert(int(ui._action_chips[GameTypes.DevCardType.CHARTER_POINT].mouse_default_cursor_shape) == Control.CURSOR_ARROW, "During bot turns chips show plain arrow")
	_pass_section("91. Cursor Shape Test (pointing/forbidden/arrow for cards, chips and dice)")

func _flyer_kinds(ui: Node) -> Array[String]:
	var out: Array[String] = []
	for c in ui._flight_layer.get_children():
		if c is CardFace:
			var f := c as CardFace
			if f.kind == "action":
				out.append("action:%d" % f.action)
			elif f.kind == "back":
				out.append("back")
	return out

func _test_action_flights_body(ui: Node) -> void:
	_use_real_frame_rate()
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4819, seats, true, 0)
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main should be reachable")
	if not reached:
		return
	var st: GameState = ui.session.state
	for r in [GameTypes.ResourceType.FLEECE, GameTypes.ResourceType.GRAIN, GameTypes.ResourceType.IRON]:
		st.players[0]["hand"][r] = int(st.players[0]["hand"].get(r, 0)) + 1
	st.dev_deck[st.dev_deck.size() - 1] = GameTypes.DevCardType.GUARD
	ui._refresh_ui()
	await _ui_settle(2)
	var flights_before := (ui._last_flights as Array).size()
	_ui_real_click(ui._buy_card_btn)
	var recs: Array = ui._last_flights
	var found_buy := false
	for e in recs:
		if int(e.get("from", -9)) == -1 and int(e.get("to", -9)) == 0 and str(e.get("kind", "")) == "action":
			found_buy = true
	_assert(found_buy, "Buying an Action Card must record a {from:-1,to:0,kind:action} flight")
	await _ui_settle(2)
	_assert(_flyer_kinds(ui).has("action:%d" % GameTypes.DevCardType.GUARD), "The buyer sees their new card fly face-up to the chip, got %s" % str(_flyer_kinds(ui)))
	await _ui_settle(5)
	st = ui.session.state
	st.players[1]["dev_cards"].append(GameTypes.DevCardType.CHARTER_POINT)
	ui._compute_dev_flights(st)
	var found_bot := false
	for e in ui._last_flights:
		if int(e.get("from", -9)) == -1 and int(e.get("to", -9)) == 1 and str(e.get("kind", "")) == "action":
			found_bot = true
	_assert(found_bot, "A bot purchase must record a flight to that seat too")
	await _ui_settle(2)
	_assert(_flyer_kinds(ui).has("back"), "A bot's purchase flies face-down to a hot-seat viewer, got %s" % str(_flyer_kinds(ui)))
	await _ui_settle(5)
	st = ui.session.state
	if (st.players[0]["dev_cards"] as Array).has(GameTypes.DevCardType.GUARD):
		st.players[0]["dev_cards"].erase(GameTypes.DevCardType.GUARD)
	elif (st.players[0]["new_dev_cards"] as Array).has(GameTypes.DevCardType.GUARD):
		st.players[0]["new_dev_cards"].erase(GameTypes.DevCardType.GUARD)
	ui._compute_dev_flights(st)
	var found_play := false
	for e in ui._last_flights:
		if int(e.get("from", -9)) == 0 and int(e.get("to", -9)) == -1 and str(e.get("kind", "")) == "action":
			found_play = true
	_assert(found_play, "Playing a card must record an outgoing action flight")
	await _ui_settle(2)
	_assert(_flyer_kinds(ui).has("action:%d" % GameTypes.DevCardType.GUARD), "A played card flies face-up toward the board, got %s" % str(_flyer_kinds(ui)))
	await _ui_settle(5)
	_pass_section("92. Action Card Flight Test (buy face-up to owner / face-down to others, play to board)")

func _test_row_size_and_scroll_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ivory"),
	]
	ui.session.start_match(4242, seats, true, 0)
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase should be reachable for the size test")
	if not reached:
		return
	var st: GameState = ui.session.state
	st.players[0]["hand"][GameTypes.ResourceType.GRAIN] = 3
	ui._reset_trade_counts()
	ui._adjust_trade_count(true, GameTypes.ResourceType.GRAIN, 3)
	ui._adjust_trade_count(false, GameTypes.ResourceType.CLAY, 1)
	var bank_min_base: float = (ui._bank_faces.values()[0] as CardFace).custom_minimum_size.y
	ui._set_tray_panel_visible(true)
	await _ui_settle(3)
	_assert(bool(ui._trade_tray.visible), "Propose panel should be open")
	var grain_chip: CardFace = null
	for c in ui._trade_give_box.get_children():
		if c is CardFace and bool((c as CardFace).visible):
			grain_chip = c as CardFace
			break
	_assert(grain_chip != null, "The give row should show a chip")
	if grain_chip == null:
		return
	_assert(grain_chip.custom_minimum_size.x >= 36.0 and grain_chip.size.x >= 36.0, "Chosen give chips are at least 36 px wide at 1280x800, got %s" % str(grain_chip.size))
	_assert(bool(grain_chip.count_badge), "Three of a kind wear the badge")
	_assert(int(grain_chip.count) == 3, "The chip carries the chosen count")
	var clay_face: CardFace = ui._trade_get_faces[GameTypes.ResourceType.CLAY]
	_assert(clay_face.custom_minimum_size.x >= 36.0, "Get faces are at least 36 px wide")
	_assert(bool(clay_face.count_badge), "A single chosen get card wears its x1 badge")
	var badge_bb: Array = grain_chip.badge_bounds()
	_assert(badge_bb.size() == 1, "The 3x chip reports its badge bound")
	var emb: Rect2 = grain_chip.emblem_bounds()
	var overlapped := emb.intersection(grain_chip.count_badge_rect())
	var covered := (overlapped.size.x * overlapped.size.y) / maxf(emb.size.x * emb.size.y, 1.0)
	_assert(covered <= 0.30, "The badge leaves at least 70%% of the emblem uncovered, got %.1f%% covered" % (covered * 100.0))
	clay_face.pressed.emit()
	await _ui_settle(1)
	_assert(int(ui._trade_get_counts.get(GameTypes.ResourceType.CLAY, 0)) == 2, "A click on the get row adds one")
	ui._trade_get_faces[GameTypes.ResourceType.CLAY].right_pressed.emit()
	await _ui_settle(1)
	_assert(int(ui._trade_get_counts.get(GameTypes.ResourceType.CLAY, 0)) == 1, "Right-click on the get row takes one back")
	await _ui_settle(2)
	var side_scroll: ScrollContainer = null
	for c in ui._right_panel.get_children():
		if c is ScrollContainer:
			side_scroll = c
	_assert(side_scroll != null and int(side_scroll.scroll_vertical) == 0, "Sidebar offset stays 0 with the propose panel open")
	st = ui.session.state
	st.open_trade = {
		"from": 1,
		"offer": {GameTypes.ResourceType.CLAY: 1},
		"request": {GameTypes.ResourceType.GRAIN: 2},
		"responses": {
			2: {"status": "decline", "offer": {}, "request": {}},
			3: {"status": "decline", "offer": {}, "request": {}},
		},
		"revisions": {},
		"resp_ticks": {2: 1, 3: 1},
		"reviews": {2: 2, 3: 2},
	}
	ui._trade_reopen_token = ""
	ui._trade_counter_mode = false
	ui._set_tray_panel_visible(true)
	ui._refresh_ui()
	await _ui_settle(2)
	_assert(bool(ui._trade_respond_view.visible), "Respond panel should show the injected offer")
	var side_scroll3: ScrollContainer = null
	for c3 in ui._right_panel.get_children():
		if c3 is ScrollContainer:
			side_scroll3 = c3
	_assert(side_scroll3 != null and int(side_scroll3.scroll_vertical) == 0, "Sidebar offset stays 0 in respond mode")
	ui._trade_counter_mode = true
	ui._refresh_ui()
	await _ui_settle(2)
	_assert(bool(ui._trade_rows_col.visible), "Counter editor shows the editable rows")
	var side_scroll4: ScrollContainer = null
	for c4 in ui._right_panel.get_children():
		if c4 is ScrollContainer:
			side_scroll4 = c4
	_assert(side_scroll4 != null and int(side_scroll4.scroll_vertical) == 0, "Sidebar offset stays 0 in counter-edit")
	var bank_min: float = (ui._bank_faces.values()[0] as CardFace).custom_minimum_size.y
	_assert(absf(bank_min - bank_min_base) < 0.1, "Bank piles keep a constant reserved height while a trade panel is open, got %f vs %f" % [bank_min, bank_min_base])
	ui._trade_counter_mode = false
	st.open_trade = {}
	ui._set_tray_panel_visible(false)
	await _ui_settle(1)
	load(UI_SCRIPT_PATH).DEV_WINDOW_WIDTH_OVERRIDE = 2000.0
	ui._apply_trade_chip_sizes()
	await _ui_settle(2)
	var wood_face: CardFace = ui._trade_get_faces[GameTypes.ResourceType.TIMBER]
	_assert(wood_face.custom_minimum_size.x >= 44.0, "Chips stay at least 44 px on a 2000 px wide window, got %s" % str(wood_face.custom_minimum_size))
	var pool_face: CardFace = (ui._ro_pools.values()[0] as Array)[0]
	_assert(pool_face.custom_minimum_size.x >= 44.0, "Read-only pool faces keep the minimum at any window size")
	load(UI_SCRIPT_PATH).DEV_WINDOW_WIDTH_OVERRIDE = 0.0
	ui._apply_trade_chip_sizes()
	await _ui_settle(1)
	_assert(wood_face.custom_minimum_size.x >= 44.0, "Chips stay at least 44 px at 1280 wide, got %s" % str(wood_face.custom_minimum_size))
	_pass_section("93. Trade Row Size & Sidebar Scroll Test (44 px cards, badge coverage, click-adds, scroll stays 0)")

func _test_board_frame_removed_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(5150, seats, true, 0)
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not ui.session.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main should be reachable for the frame test")
	if not reached:
		return
	_assert(not ui.has_method("_set_board_turn_frame"), "The board turn frame must be gone for good")
	_assert(ui.get("_turn_frame") == null, "No _turn_frame member may remain")
	_assert(ui.get("_turn_frame_style") == null, "No _turn_frame_style member may remain")
	for c in ui._board_view.get_children():
		if c is Panel:
			var sb := (c as Panel).get_theme_stylebox("panel") as StyleBoxFlat
			_assert(sb == null or (sb.border_width_left == 0 and sb.border_width_top == 0 and sb.border_width_right == 0 and sb.border_width_bottom == 0), "No board child may draw a border frame")
	await _ui_settle(3)
	var size_a: Vector2 = ui._board_view.size
	_assert(size_a.x > 100.0 and size_a.y > 100.0, "The board has a real size before the turn change")
	var cur: int = int(ui.session.state.current_player)
	_ui_real_click(ui._end_turn_btn)
	await _ui_settle(2)
	_assert(ui.session.state.current_player != cur, "End Turn must pass the turn")
	await _ui_settle(12)
	_assert(ui._board_view.size == size_a, "The board keeps the same size across a turn change, got %s vs %s" % [str(ui._board_view.size), str(size_a)])
	for w in [62.0, 80.0]:
		var face := CardFace.new()
		face.size = Vector2(w, w / CardFace.RATIO)
		face.kind = "resource"
		face.resource = GameTypes.ResourceType.CLAY
		face.count = 3
		var host := Rect2(Vector2.ZERO, face.size)
		for mode in range(3):
			face._hover = mode == 1
			face.selected = mode == 2
			var bb: Array = face.badge_bounds()
			_assert(bb.size() >= 1, "Hand-size card wears its count badge (w=%f)" % w)
			_assert(host.grow(-1.9).encloses(bb[0] as Rect2), "Hand-card badge (w=%f, mode %d) stays fully inside the control with 2px margin, got %s vs %s" % [w, mode, str(bb[0]), str(host)])
		face.free()
	var st2: GameState = ui.session.state
	st2.players[cur]["hand"][GameTypes.ResourceType.CLAY] = 3
	ui._refresh_ui()
	await _ui_settle(2)
	var clay: CardFace = ui._res_card_refs[GameTypes.ResourceType.CLAY]
	_assert(clay.size.x >= 50.0, "The hand bar cards are wide, got %s" % str(clay.size))
	var clay_host := Rect2(Vector2.ZERO, clay.size)
	var clay_bb: Array = clay.badge_bounds()
	_assert(clay_bb.size() >= 1, "Three Clay in hand show the x3 badge")
	_assert(clay_host.grow(-1.9).encloses(clay_bb[0] as Rect2), "The real hand-card badge stays inside the control, got %s vs %s" % [str(clay_bb[0]), str(clay_host)])
	st2.players[cur]["hand"][GameTypes.ResourceType.CLAY] = 0
	ui._refresh_ui()
	await _ui_settle(1)
	_pass_section("94. Board Frame Removal & Hand Badge Containment Test (no border ever, size stable, badges inside)")


func _layout_tracked_frames(ui: Node) -> Array:
	var out: Array = []
	out.append(["top_bar", ui._menu_btn.get_parent().get_parent()])
	out.append(["banner", ui._status_banner_label])
	out.append(["turn_counter", ui._phase_label])
	out.append(["menu_btn", ui._menu_btn])
	out.append(["help_btn", ui._help_costs_btn])
	out.append(["board", ui._board_view])
	out.append(["split", ui._center_split])
	out.append(["sidebar", ui._right_panel])
	var col: Node = ui._scoreboard_box.get_parent()
	for i in range(col.get_child_count()):
		out.append(["side_%d" % i, col.get_child(i)])
	for pid in ui._scoreboard_row_panels.keys():
		var panel: Control = ui._scoreboard_row_panels[pid]
		if panel == null or not is_instance_valid(panel):
			continue
		out.append(["sb_row_%d" % pid, panel])
		var row: HBoxContainer = panel.get_child(0)
		for i in range(row.get_child_count()):
			out.append(["sb_%d_%d" % [pid, i], row.get_child(i)])
	for r in GameTypes.ALL_RESOURCES:
		out.append(["bank_%d" % r, ui._bank_faces.get(r, null)])
	out.append(["bank_deck", ui._bank_deck_face])
	out.append(["trade_slot", ui._trade_slot])
	out.append(["trade_tray", ui._trade_tray])
	out.append(["log_toggle", ui._log_toggle_btn])
	out.append(["log_box", ui._log_panel])
	out.append(["strip", ui._offer_strip])
	out.append(["hand_bar", ui._hand_bar_panel])
	for r in GameTypes.ALL_RESOURCES:
		out.append(["hand_%d" % r, ui._res_card_refs.get(r, null)])
	for c in ui._action_chips.keys():
		out.append(["chip_%d" % c, ui._action_chips.get(c, null)])
	out.append(["buy_card", ui._buy_card_btn])
	out.append(["dice", ui._dice_widget])
	out.append(["end_turn", ui._end_turn_btn])
	out.append(["hand_overlay", ui._hand_overlay])
	return out

func _layout_probe_step(ui: Node, tick: int) -> void:
	var st: GameState = ui.session.state
	if st == null or st.phase == GameTypes.TurnPhase.GAME_OVER:
		return
	var ot: Dictionary = st.open_trade
	if not ot.is_empty():
		var from_p := int(ot.get("from", -1))
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
			return
		if int(ui.session.get_acting_player_id()) == 0:
			ui._set_tray_panel_visible(true)
			if from_p == 0:
				ui.session.submit_action(0, GameAction.cancel_open_trade())
			elif not (ot.get("responses", {}) as Dictionary).has(0):
				ui.session.submit_action(0, GameAction.respond_open_trade("decline" if tick % 3 != 0 else "accept"))
			return
		return
	if ui.session.is_ai_to_act():
		ui.session.step_ai()
		return
	var acting: int = int(ui.session.get_acting_player_id())
	if acting == 0 and st.phase == GameTypes.TurnPhase.TURN_MAIN and tick % 9 == 0:
		ui._set_tray_panel_visible(true)
		if st.open_trades_this_turn < 3:
			ui._reset_trade_counts()
			var gave := false
			for r in GameTypes.ALL_RESOURCES:
				var have := int(st.players[0]["hand"].get(r, 0))
				if not gave:
					if have >= 1:
						ui._adjust_trade_count(true, r, 1)
						gave = true
				elif int(ui._trade_get_counts.get(r, 0)) == 0:
					ui._adjust_trade_count(false, r, 1)
					break
			if gave:
				ui._on_ask_players_pressed()
				return
	if tick % 17 == 0:
		ui._set_tray_panel_visible(false)
	var act: Dictionary = BotController.choose_action(st, acting, 2)
	ui.session.submit_action(acting, act)

func _test_layout_rect_lock_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ivory"),
	]
	ui._splash_shown = false
	if ui._splash_overlay != null:
		ui._splash_overlay.visible = false
	ui.auto_ai = false
	ui.turn_min_seconds_override = 0.0
	var counter := {"n": 0}
	var hook := func(_s: GameState, _e: Array) -> void: counter["n"] += 1
	ui.session.state_updated.connect(hook)
	var started := false
	for seed in [90210, 777, 31, 4242]:
		ui.session.start_match(seed, seats, true, 0)
		started = true
		break
	if not started:
		return
	await _ui_settle(6)
	var tracked := _layout_tracked_frames(ui)
	var baseline: Dictionary = {}
	var fail_msg := ""
	var tick := 0
	var guard := 0
	var last_sig := ""
	var stuck := 0
	var tree := ui.get_tree()
	while guard < 3500:
		guard += 1
		await _ui_settle(1)
		for entry in tracked:
			var node: Variant = entry[1]
			if node == null or not is_instance_valid(node):
				continue
			var ctrl := node as Control
			if ctrl == null or not ctrl.visible:
				continue
			if ctrl.scale != Vector2.ONE:
				continue
			var gr := ctrl.get_global_rect()
			var nm: String = entry[0]
			if not baseline.has(nm):
				baseline[nm] = gr
				continue
			var b: Rect2 = baseline[nm]
			if (
				absf(gr.position.x - b.position.x) > 0.5
				or absf(gr.position.y - b.position.y) > 0.5
				or absf(gr.size.x - b.size.x) > 0.5
				or absf(gr.size.y - b.size.y) > 0.5
			):
				fail_msg = "%s moved: first %s now %s" % [nm, str(b), str(gr)]
				break
		if fail_msg != "":
			break
		if counter["n"] == 40:
			ui._set_log_open(true)
		elif counter["n"] == 44:
			ui._set_log_open(false)
		if tick % 2 == 0:
			_layout_probe_step(ui, tick)
			var st: GameState = ui.session.state
			var sig := "%d:%d:%s" % [st.turn_number, st.phase, str(st.current_player)]
			stuck = stuck + 1 if sig == last_sig else 0
			last_sig = sig
			if stuck > 120:
				break
		tick += 1
		if counter["n"] >= 150:
			break
	ui.session.state_updated.disconnect(hook)
	await _ui_settle(1)
	await _ui_settle(1)
	var stc: GameState = ui.session.state
	if stc != null:
		var any_positive := false
		for p_id in range(stc.num_players):
			var res_stack: MiniHandStack = ui._scoreboard_mini_hands.get(p_id, null)
			var act_stack: MiniHandStack = ui._scoreboard_mini_acts.get(p_id, null)
			if res_stack == null or act_stack == null:
				continue
			var exp_res: int = int(ui._displayed_hand_count(p_id))
			_assert(res_stack.res_fan.drawn_count == exp_res, "Seat %d row shows %d resource cards, expected %d" % [p_id, res_stack.res_fan.drawn_count, exp_res])
			var p_d: Dictionary = stc.players[p_id]
			var exp_act: int = p_d.get("dev_cards", []).size() + p_d.get("new_dev_cards", []).size()
			_assert(act_stack.act_fan.drawn_count == exp_act, "Seat %d row shows %d action cards, expected %d" % [p_id, act_stack.act_fan.drawn_count, exp_act])
			if exp_res > 0 or exp_act > 0:
				any_positive = true
		_assert(any_positive, "At least one seat shows a positive card count")
	_assert(baseline.size() >= 40, "Layout lock sampled enough frames, got %d nodes" % baseline.size())
	_assert(counter["n"] >= 120, "Layout lock covered 120 state updates, got %d" % counter["n"])
	_assert(fail_msg == "", "Static frame moved during the match: %s" % fail_msg)
	_pass_section("95. Layout Rect Lock Test (static frames never move across 120+ state updates)")

func _test_steal_flight_real_body(ui: Node) -> void:
	ui.auto_ai = false
	ui.turn_min_seconds_override = 0.0
	ui._reduce_motion = false
	if ui._board_view != null:
		ui._board_view.reduce_motion = false
	var s = ui.session
	var win := ui.get_viewport().get_visible_rect()
	var found := false
	var match_no := 0
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Ivory"),
	]
	while not found and match_no < 8:
		match_no += 1
		s.start_match(4242 + match_no * 13, seats, true, 0)
		await _ui_settle(2)
		var prev_serial: int = int(s.state.last_steal.get("serial", 0))
		var steps := 0
		while not found and steps < 1200:
			steps += 1
			var st: GameState = s.state
			if st.phase == GameTypes.TurnPhase.GAME_OVER:
				break
			var acting := int(s.get_acting_player_id())
			if s.is_ai_to_act():
				s.step_ai()
			elif not st.open_trade.is_empty():
				var frm: int = int(st.open_trade.get("from", -1))
				s.submit_action(acting, GameAction.respond_open_trade("decline") if frm != acting else GameAction.cancel_open_trade())
			elif st.phase == GameTypes.TurnPhase.TURN_MOVE_BLOCKER and acting == 0:
				var picked := false
				for tid in range(19):
					if tid == st.blocker_tile:
						continue
					if RulesEngine.get_steal_victims(st, 0, tid).size() >= 1:
						s.submit_action(0, GameAction.move_blocker(tid, RulesEngine.get_steal_victims(st, 0, tid)[0]))
						picked = true
						break
				if not picked:
					s.submit_action(0, BotController.choose_action(st, 0, 2))
			else:
				s.submit_action(acting, BotController.choose_action(st, acting, 2))
			await _ui_settle(1)
			var st2: GameState = s.state
			var serial: int = int(st2.last_steal.get("serial", 0))
			if serial > prev_serial:
				prev_serial = serial
				var th: int = int(st2.last_steal.get("thief", -1))
				var vi: int = int(st2.last_steal.get("victim", -1))
				if th >= 0 and vi >= 0 and th != vi and (th == 0 or vi == 0):
					found = true
	if not found:
		_assert(false, "A real viewer-involving steal should occur while driving matches")
		return
	await _ui_settle(2)
	var layer: Control = ui._flight_layer
	# Wait for the Blocker delay to elapse and the flyer to appear in the flight layer.
	var flyer_seen := false
	var start_pos := Vector2.INF
	var end_pos := Vector2.INF
	for _i in range(160):
		await _ui_settle(1)
		var fly: Variant = ui._steal_flyer
		if fly != null and is_instance_valid(fly) and (fly as Node).get_parent() == layer:
			if not flyer_seen:
				flyer_seen = true
				start_pos = (fly as Control).get_global_rect().get_center()
			end_pos = (fly as Control).get_global_rect().get_center()
		elif flyer_seen:
			break
	_assert(flyer_seen, "A flyer node appears in the flight layer after the Blocker animation")
	if not flyer_seen:
		return
	var dist: float = start_pos.distance_to(end_pos)
	_assert(dist > 40.0, "The flyer travels more than 40 px (start %s end %s, got %.1f)" % [str(start_pos), str(end_pos), dist])
	_assert(start_pos.x >= 0.0 and start_pos.y >= 0.0 and start_pos.x <= win.size.x and start_pos.y <= win.size.y, "Flyer start inside window: %s" % str(start_pos))
	_assert(end_pos.x >= 0.0 and end_pos.y >= 0.0 and end_pos.x <= win.size.x and end_pos.y <= win.size.y, "Flyer end inside window: %s" % str(end_pos))
	# Let the flyer land and confirm holds are cleared.
	var cleared := false
	for _j in range(120):
		await _ui_settle(1)
		if ui._hand_count_hold.is_empty() and ui._res_hold.is_empty():
			cleared = true
			break
	_assert(cleared, "Card holds are empty once the steal animation finishes")
	_pass_section("96. Real Steal Flight Test (session-driven steal flies a card >40px in the flight layer, holds cleared)")

# --- Round 7B helpers ---------------------------------------------------------

func _ui_drive_to_human_main(ui: Node, max_steps: int = 6000) -> bool:
	for _step in range(max_steps):
		var st: GameState = ui.session.state
		if st.phase == GameTypes.TurnPhase.GAME_OVER:
			return false
		if (
			st.phase == GameTypes.TurnPhase.TURN_MAIN
			and ui.session.get_acting_player_id() == 0
			and st.open_trade.is_empty()
		):
			return true
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
			continue
		var acting: int = ui.session.get_acting_player_id()
		ui.session.submit_action(acting, BotController.choose_action(st, acting, 2))
	return false

func _ui_post_human_offer(ui: Node) -> Dictionary:
	var st: GameState = ui.session.state
	var give_res := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(st.players[0].hand.get(r, 0)) >= 1:
			give_res = r
			break
	if give_res == -1:
		return {}
	var want_res := (give_res + 1) % GameTypes.ALL_RESOURCES.size()
	ui._reset_trade_counts()
	_ui_real_click(ui._res_card_refs[give_res])
	if not bool(ui._trade_tray.visible) or int(ui._trade_give_counts.get(give_res, 0)) != 1:
		return {}
	await _ui_settle(2)
	ui._adjust_trade_count(false, want_res, 1)
	ui._refresh_ui()
	if ui._trade_ask_btn.disabled:
		return {}
	await _ui_settle(1)
	_ui_real_click(ui._trade_ask_btn)
	if ui.session.state.open_trade.is_empty():
		return {}
	return {"give": give_res, "want": want_res}

func _ui_all_bots_decline(ui: Node) -> void:
	# New rule: every AI answers once, in seat order, before the human; after
	# that the acting id cycles through bot review passes, so answer each AI
	# seat directly instead of following the acting id.
	var st: GameState = ui.session.state
	var ot: Dictionary = st.open_trade
	if ot.is_empty():
		return
	var from_p := int(ot.get("from", -1))
	for p_id in range(st.num_players):
		if p_id == from_p:
			continue
		if p_id >= ui.session.seats.size() or not ui.session.seats[p_id].is_ai():
			continue
		ui.session.submit_action(p_id, GameAction.respond_open_trade("decline"))

func _ui_wait_dead_offer_withdrawn(ui: Node, max_ms: int = 3000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not ui.session.state.open_trade.is_empty() and Time.get_ticks_msec() - t0 < max_ms:
		await _ui_settle(1)
	return ui.session.state.open_trade.is_empty()

func _ui_click_point(p: Vector2) -> void:
	var sp: Vector2 = root.get_screen_transform() * p
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = sp
		e.global_position = sp
		root.push_input(e)

func _ui_collect_hits(node: Node, pt: Vector2, out: Array[Node]) -> void:
	for c in node.get_children():
		if c is Control:
			var cc := c as Control
			if cc.is_visible_in_tree() and cc.get_global_rect().has_point(pt):
				out.append(c)
				_ui_collect_hits(c, pt, out)

func _ui_side_total(counts: Dictionary) -> int:
	var total := 0
	for r in GameTypes.ALL_RESOURCES:
		total += int(counts.get(r, 0))
	return total

func _ui_play_guard_real_click(ui: Node) -> void:
	var chip: CardFace = ui._action_chips.get(GameTypes.DevCardType.GUARD, null)
	_ui_real_click(chip)

func _ui_click_guard_tile(ui: Node) -> bool:
	var st: GameState = ui.session.state
	var tid := -1
	for t_id in range(st.tile_terrains.size()):
		if t_id == st.blocker_tile:
			continue
		if RulesEngine.get_steal_victims(st, 0, t_id).size() < 2:
			tid = t_id
			break
	if tid == -1:
		return false
	var p: Vector2 = ui._board_view.global_position + ui._board_view.get_spot_screen_position("tile", tid)
	_ui_click_point(p)
	return true

# --- 97: dead offer auto-withdraw, editor keeps draft, Guard plays ------------

func _test_dead_offer_autowithdraw_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(5201, seats, true, 0)
	var reached := _ui_drive_to_human_main(ui)
	_assert(reached, "Human should reach a main turn")
	if not reached:
		return
	var st: GameState = ui.session.state
	st.players[0].dev_cards.append(GameTypes.DevCardType.GUARD)
	ui._refresh_ui()
	var posted: Dictionary = await _ui_post_human_offer(ui)
	_assert(not posted.is_empty(), "Human offer should be posted")
	if posted.is_empty():
		return
	await _ui_settle(2)
	_ui_all_bots_decline(ui)
	await _ui_settle(2)
	st = ui.session.state
	_assert(not st.open_trade.is_empty(), "Offer is still open right after the last decline")
	_assert(bool(ui._trade_no_takers_lbl.visible), "Panel shows No takers once everybody declined")
	var chip: CardFace = ui._action_chips.get(GameTypes.DevCardType.GUARD, null)
	_assert(chip != null and not bool(chip.disabled), "Guard chip must be enabled while the dead offer is shown")
	var withdrawn := await _ui_wait_dead_offer_withdrawn(ui)
	_assert(withdrawn, "A fully-declined offer withdraws itself within 3 s")
	if not withdrawn:
		return
	_assert(bool(ui._trade_tray.visible), "Trade panel returns to the editor after the auto-withdraw")
	_assert(int(ui._trade_give_counts.get(int(posted["give"]), 0)) == 1, "Editor keeps the give draft")
	_assert(int(ui._trade_get_counts.get(int(posted["want"]), 0)) == 1, "Editor keeps the get draft")
	var chip2: CardFace = ui._action_chips.get(GameTypes.DevCardType.GUARD, null)
	_assert(chip2 != null and not bool(chip2.disabled), "Guard chip is enabled after the auto-withdraw")
	_ui_play_guard_real_click(ui)
	await _ui_settle(1)
	_assert(bool(ui._pending_guard_card), "Real click on the Guard chip engages tile picking")
	_assert(_ui_click_guard_tile(ui), "A low-victim tile exists to play Guard on")
	await _ui_settle(2)
	st = ui.session.state
	_assert((st.players[0].dev_cards as Array).count(GameTypes.DevCardType.GUARD) == 0, "Guard was played by the real clicks")
	_assert(st.open_trade.is_empty(), "No offer is left open after playing Guard")
	_assert(bool(ui._human_can_progress()), "Human can keep acting after the guard")
	_pass_section("97. Dead Offer Auto-Withdraw Test (no takers auto-cancels, draft kept, real Guard click plays)")

# --- 98: action while offer still awaits responses withdraws it first ---------

func _test_pending_offer_action_cancel_first_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(5202, seats, true, 0)
	var reached := _ui_drive_to_human_main(ui)
	_assert(reached, "Human should reach a main turn")
	if not reached:
		return
	var st: GameState = ui.session.state
	st.players[0].dev_cards.append(GameTypes.DevCardType.GUARD)
	ui._refresh_ui()
	var posted: Dictionary = await _ui_post_human_offer(ui)
	_assert(not posted.is_empty(), "Human offer should be posted")
	if posted.is_empty():
		return
	await _ui_settle(2)
	st = ui.session.state
	_assert(not st.open_trade.is_empty(), "Offer still awaits responses (auto_ai off)")
	_assert(ui.session.get_acting_player_id() != 0, "A responder is the acting player while answers are pending")
	var chip: CardFace = ui._action_chips.get(GameTypes.DevCardType.GUARD, null)
	_assert(chip != null and not bool(chip.disabled), "Guard chip is enabled even while responses are pending")
	_ui_play_guard_real_click(ui)
	await _ui_settle(1)
	_assert(bool(ui._pending_guard_card), "Guard picking engaged with the offer still pending")
	_assert(not st.open_trade.is_empty(), "Picking alone does not withdraw the offer")
	_assert(_ui_click_guard_tile(ui), "A tile is available for the Guard")
	await _ui_settle(2)
	st = ui.session.state
	_assert(st.open_trade.is_empty(), "Playing the Guard withdrew the still-unsolicited offer first")
	_assert((st.players[0].dev_cards as Array).count(GameTypes.DevCardType.GUARD) == 0, "Guard was played")
	_pass_section("98. Pending-Offer Cancel-First Test (real Guard click during pending answers withdraws and plays)")

# --- 99: hand-card click starts a fresh trade after No takers -----------------

func _test_fresh_trade_after_no_takers_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(5203, seats, true, 0)
	var reached := _ui_drive_to_human_main(ui)
	_assert(reached, "Human should reach a main turn")
	if not reached:
		return
	var st: GameState = ui.session.state
	var posted: Dictionary = await _ui_post_human_offer(ui)
	_assert(not posted.is_empty(), "First human offer should be posted")
	if posted.is_empty():
		return
	await _ui_settle(2)
	_ui_all_bots_decline(ui)
	await _ui_settle(2)
	st = ui.session.state
	_assert(not st.open_trade.is_empty() and bool(ui._trade_no_takers_lbl.visible), "First offer sits at No takers")
	var card_res := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(st.players[0].hand.get(r, 0)) >= 1 and int(r) != int(posted["give"]):
			card_res = int(r)
			break
	_assert(card_res != -1, "Human holds a card other than the offered one")
	if card_res == -1:
		return
	_ui_real_click(ui._res_card_refs[card_res])
	await _ui_settle(2)
	st = ui.session.state
	_assert(st.open_trade.is_empty(), "Clicking a hand card withdraws the dead offer immediately")
	_assert(int(ui._trade_give_counts.get(card_res, 0)) == 1, "Clicked card becomes the give (1)")
	_assert(_ui_side_total(ui._trade_give_counts) == 1, "Give side holds only the clicked card")
	_assert(_ui_side_total(ui._trade_get_counts) == 0, "Get side starts empty")
	# Second round: let the auto-withdraw fire first, then a card click must
	# still start from scratch despite the retained draft.
	var posted2: Dictionary = await _ui_post_human_offer(ui)
	_assert(not posted2.is_empty(), "Second human offer should be posted")
	if posted2.is_empty():
		return
	await _ui_settle(2)
	_ui_all_bots_decline(ui)
	await _ui_settle(2)
	var withdrawn := await _ui_wait_dead_offer_withdrawn(ui)
	_assert(withdrawn, "Second dead offer auto-withdrew")
	if not withdrawn:
		return
	_assert(_ui_side_total(ui._trade_give_counts) > 0, "Auto-withdraw kept the draft")
	_ui_real_click(ui._res_card_refs[card_res])
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(card_res, 0)) == 1, "Card click after auto-withdraw is a fresh give")
	_assert(_ui_side_total(ui._trade_give_counts) == 1, "Retained draft was cleared by the fresh click")
	_assert(_ui_side_total(ui._trade_get_counts) == 0, "Fresh trade starts with an empty get side")
	_pass_section("99. Fresh Trade After No Takers Test (hand-card click restarts the offer, before and after auto-withdraw)")

# --- 100: Clear button enabled only while editing -----------------------------

func _test_clear_button_states_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Crimson"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Azure"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(5204, seats, true, 0)
	var reached := _ui_drive_to_human_main(ui)
	_assert(reached, "Human should reach a main turn")
	if not reached:
		return
	ui._set_tray_panel_visible(true)
	ui._refresh_ui()
	_assert(bool(ui._trade_clear_btn.disabled), "Clear is disabled with both sides empty")
	var st: GameState = ui.session.state
	var hand_res := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(st.players[0].hand.get(r, 0)) >= 1:
			hand_res = int(r)
			break
	ui._adjust_trade_count(true, hand_res, 1)
	ui._adjust_trade_count(false, (hand_res + 2) % GameTypes.ALL_RESOURCES.size(), 1)
	ui._refresh_ui()
	_assert(not bool(ui._trade_clear_btn.disabled), "Clear is enabled while drafting")
	var posted: Dictionary = await _ui_post_human_offer(ui)
	_assert(not posted.is_empty(), "Offer should be posted")
	await _ui_settle(2)
	_assert(bool(ui._trade_clear_btn.disabled), "Clear is disabled while the own offer awaits answers")
	_ui_all_bots_decline(ui)
	await _ui_settle(2)
	_assert(not ui.session.state.open_trade.is_empty(), "Offer sits at No takers")
	_assert(bool(ui._trade_clear_btn.disabled), "Clear is disabled in the No takers state")
	var withdrawn := await _ui_wait_dead_offer_withdrawn(ui)
	_assert(withdrawn, "Offer auto-withdrew")
	await _ui_settle(1)
	_assert(not bool(ui._trade_clear_btn.disabled), "Clear is enabled again in the editor after the withdraw")
	# responding to someone else's offer
	ui._reset_trade_counts()
	var offered := _ui_force_bot_offer(ui)
	_assert(offered, "Bot offer should be pending")
	if offered:
		await _ui_settle(2)
		_assert(bool(ui._trade_respond_mode), "Panel is in respond mode")
		_assert(bool(ui._trade_clear_btn.disabled), "Clear is disabled while responding to another player")
	_pass_section("100. Clear Button Enable-State Test (disabled unless actively drafting, incl. No takers and respond)")

# --- 101: watching other players' offers, answers and outcomes ----------------

func _test_watch_other_trades_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(5205, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 1
	st.open_trades_this_turn = 0
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	st.players[2]["hand"][GameTypes.ResourceType.GRAIN] = 3
	st.players[2]["hand"][GameTypes.ResourceType.IRON] = 3
	ui._refresh_ui()
	ui.session.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	while ui.session.is_ai_to_act():
		ui.session.step_ai()  # new rule: the bots answer before the human
	await _ui_settle(2)
	st = ui.session.state
	_assert(bool(ui._trade_tray.visible) and bool(ui._trade_respond_mode), "Responder tray auto-opens for the human")
	# counter terms appear on the strip and in the watch rows
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 2
	_ui_real_click(ui._ot_decline_btn)
	await _ui_settle(2)
	_assert(not ui.session.state.open_trade.is_empty(), "Bot offer stays open after the human decline")
	ui.session.submit_action(2, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.IRON: 1}))
	while ui.session.is_ai_to_act() and ui.session.get_acting_player_id() != 1:
		ui.session.step_ai()  # run Pike's stale review only; the test finalizes as the proposer
	await _ui_settle(2)
	st = ui.session.state
	_assert(ui.session.get_acting_player_id() == 1, "The proposer acts after all answers are in")
	_assert(bool(ui._trade_tray.visible), "The watching tray stays available to the viewer")
	_assert(bool(ui._trade_watch_col.visible), "Watch column is visible while bots finish")
	_assert(str(ui._trade_title_lbl.text) == "Dune offers 1 Grain for 1 Timber", "Watch header shows A's terms, got '%s'" % str(ui._trade_title_lbl.text))
	_assert(_find_label_containing(ui._trade_tray, "Declined"), "Watch rows carry the viewer's decline")
	var tray_texts := _collect_label_texts(ui._trade_tray)
	_assert(tray_texts.contains("1\u00d7"), "Watch rows show the counter card counts, got '%s'" % tray_texts)
	_assert(_tray_has_mini_icon(ui._trade_tray, "Grain") and _tray_has_mini_icon(ui._trade_tray, "Iron"), "Counter row shows the counter terms as icons")
	_assert(_strip_chip_texts(ui).contains("Pike counters: gives 1 Iron, wants 1 Grain"), "Strip names counter terms from Pike's side, got '%s'" % _strip_chip_texts(ui))
	# unified counter wording in the log line too
	_assert(ui._event_log.get_parsed_text().contains("Pike revises: counters: gives 1 Iron, wants 1 Grain."), "Log must use the revision wording, got '%s'" % ui._event_log.get_parsed_text())
	# the proposer accepts the counter: toast + log must name both players and resources
	var seen_events: Array[String] = []
	var hook := func(_state: GameState, evs: Array[String]) -> void:
		for e in evs:
			seen_events.append(str(e))
	ui.session.state_updated.connect(hook)
	ui.session.submit_action(1, GameAction.finalize_open_trade(2))
	ui.session.state_updated.disconnect(hook)
	await _ui_settle(2)
	st = ui.session.state
	_assert(st.open_trade.is_empty(), "Counter accepted and the offer finalized")
	var found_line := ""
	for ev in seen_events:
		if ev.contains("traded") and ev.contains("Dune") and ev.contains("Pike"):
			found_line = ev
	_assert(found_line != "", "The log must carry a bot-to-bot trade line naming both players")
	_assert(found_line.contains("1 Grain") and found_line.contains("1 Iron"), "The trade line names both resources, got '%s'" % found_line)
	_assert(_toast_texts(ui).contains(found_line.trim_suffix(".")), "Toast must agree with the log, got '%s' vs '%s'" % [_toast_texts(ui), found_line])
	_assert(ui._event_log.get_parsed_text().contains(found_line), "Event log shows the raw trade line, got '%s'" % ui._event_log.get_parsed_text())
	_pass_section("101. Watch Other Trades Test (decline+counter rows, strip counter terms, bot-trade toast matches log)")

# --- 102: scoreboard focus ring overlay ---------------------------------------

func _test_scoreboard_focus_overlay_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Crimson"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(6102, seats, true, 0)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_ROLL
	var orig_current: int = st.current_player
	ui._refresh_ui()
	var overlay: Control = ui._sb_focus_overlay
	_assert(overlay != null, "Scoreboard focus overlay exists")
	if overlay == null:
		return
	var rows_host: Node = ui._center_split.get_parent()
	for k in range(st.num_players):
		var p_id: int = (st.start_player + k) % st.num_players
		st.current_player = p_id
		ui._refresh_ui()
		ui._update_scoreboard_focus_overlay()
		var parts: Dictionary = ui._scoreboard_row_parts[k]
		var card: Control = parts.get("card")
		_assert(card != null and card.visible, "Row %d exists for the focused player" % k)
		if card == null:
			continue
		_assert(overlay.visible, "Focus overlay is visible for focused row %d" % k)
		var ovr: Rect2 = overlay.get_global_rect()
		var cr: Rect2 = card.get_global_rect()
		_assert(ovr.encloses(cr.grow(0.5)), "Overlay rect %s contains row %d rect %s" % [str(ovr), k, str(cr)])
		_assert(
			overlay.get_parent() == ui and overlay.get_index() > rows_host.get_index(),
			"Focus overlay draws after every row (later sibling of the rows subtree), row %d" % k
		)
		_assert(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Focus overlay ignores the mouse")
	st.current_player = orig_current
	ui._refresh_ui()
	_pass_section("102. Scoreboard Focus Overlay Test (ring above all rows, contains the focused row, for every seat)")

# --- 103: discard prompt and board-selection cancel live in the offer strip ---

func _test_discard_prompt_strip_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Crimson"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(7303, seats, true, 0)
	var st: GameState = ui.session.state
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 8
	st.phase = GameTypes.TurnPhase.TURN_DISCARD
	st.pending_discards[0] = 4
	st.current_player = 0
	ui._refresh_ui()
	_assert(ui._discard_mode_box.visible and ui._discard_heading.visible, "The discard prompt shows during TURN_DISCARD")
	var hrect: Rect2 = ui._discard_heading.get_global_rect()
	var strip: Rect2 = ui._offer_strip.get_global_rect()
	_assert(strip.encloses(hrect.grow(-1.0)), "The prompt lies inside the strip, got %s vs %s" % [str(hrect), str(strip)])
	for r in ui._res_card_refs.keys():
		var face: Control = ui._res_card_refs[r]
		if face.visible:
			_assert(not hrect.intersects(face.get_global_rect()), "The prompt must not cover the hand card %s" % str(r))
	_assert(ui._discard_auto_btn.visible and ui._discard_confirm_btn.visible, "Discard actions show in the strip")
	await _ui_settle(2)
	_ui_real_click(ui._discard_auto_btn)
	await _ui_settle(2)
	_assert(ui._discard_heading.text.contains("picked 4 of 4"), "Pick for me fills the prompt, got '%s'" % ui._discard_heading.text)
	_ui_real_click(ui._discard_confirm_btn)
	await _ui_settle(2)
	_assert(int(ui.session.state.pending_discards.get(0, 0)) == 0, "The discard completes")
	ui._refresh_ui()
	_assert(not ui._discard_mode_box.visible and ui._offer_strip_spacer.visible, "The strip returns to trade content after the discard, got box=%s spacer=%s" % [str(ui._discard_mode_box.visible), str(ui._offer_strip_spacer.visible)])
	ui.session.state.phase = GameTypes.TurnPhase.TURN_MAIN
	ui.session.state.current_player = 0
	ui._refresh_ui()
	ui._on_play_guard_pressed()
	_assert(ui._cancel_pick_btn.visible, "The cancel button shows during a guard tile pick")
	var crect: Rect2 = ui._cancel_pick_btn.get_global_rect()
	_assert(ui._offer_strip.get_global_rect().encloses(crect.grow(-1.0)), "The cancel button lies inside the strip, got %s" % str(crect))
	for r in ui._res_card_refs.keys():
		var face: Control = ui._res_card_refs[r]
		if face.visible:
			_assert(not crect.intersects(face.get_global_rect()), "The cancel button must not cover the hand card %s" % str(r))
	ui._cancel_current_pick()
	_pass_section("103. Discard And Cancel In Strip Test (prompt and cancel never cover the hand cards)")

# --- 104: bot trade answers arrive one at a time when pacing is on ------------

func _watch_row_status(col: Control) -> Dictionary:
	var out := {}
	for row in col.get_children():
		# p29r: rows are wrapped in a transparent PanelContainer background.
		if row.get_child_count() == 1 and row.get_child(0) is HBoxContainer:
			row = row.get_child(0)
		var texts: Array[String] = []
		for c in row.get_children():
			if c is Label:
				texts.append((c as Label).text)
		if texts.is_empty():
			continue
		out[texts[0]] = " ".join(texts.slice(1))
	return out

func _test_live_trade_pacing_body(ui: Node) -> void:
	_use_real_frame_rate()
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.trade_pace_override = 0.4
	ui.session.start_match(9404, seats, true, 0)
	var s = ui.session
	var st: GameState = s.state
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	st.players[2]["hand"][GameTypes.ResourceType.TIMBER] = 2
	st.players[3]["hand"][GameTypes.ResourceType.TIMBER] = 2
	var guard := 0
	while guard < 200:
		guard += 1
		if st.phase == GameTypes.TurnPhase.TURN_MAIN and s.get_acting_player_id() == 1 and st.open_trade.is_empty() and st.turn_number >= 2:
			break
		if s.is_ai_to_act():
			s.step_ai()
		else:
			s.submit_action(s.get_acting_player_id(), BotController.choose_action(st, s.get_acting_player_id(), 2))
		await _ui_settle(1)
	_assert(s.get_acting_player_id() == 1 and st.turn_number >= 2, "Reached bot Dune's main phase")
	s.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	st = s.state
	_assert(not st.open_trade.is_empty(), "Dune's offer is open")
	await _ui_settle(2)
	# The lead-up trades leave their "No deal" / "Trade made" result up for 1 to 1.5 s
	# of real time, and the bots hold their answers until it is gone. Let it run out
	# here, or the watch below sees that old result end and stops before any answer.
	var stale_guard := 0
	while bool(ui._ot_result_active) and Time.get_ticks_msec() < int(ui._ot_result_until_ms) and stale_guard < 600:
		stale_guard += 1
		await _ui_settle(1)
	# New rule: the bots answer first; the human answers when the wave reaches
	# them, still inside the observed window, so every answer is a visible step.
	ui.auto_ai = true
	var prev := _watch_row_status(ui._watch_rows_col)
	var frames_changed: Array[int] = []
	var frame := 0
	var saw_result := false
	var result_seen_before_idle := false
	var human_answered := false
	var guard2 := 0
	while guard2 < 420:
		guard2 += 1
		frame += 1
		var otx: Dictionary = s.state.open_trade
		if (
			not human_answered and not otx.is_empty()
			and s.get_acting_player_id() == 0
			and not (otx.get("responses", {}) as Dictionary).has(0)
			and bool(ui._ot_decline_btn.visible) and not bool(ui._ot_decline_btn.disabled)
		):
			_ui_real_click(ui._ot_decline_btn)
			human_answered = true
		await _ui_settle(1)
		if ui._ot_result_active:
			result_seen_before_idle = true
			saw_result = true
		if not bool(ui._ot_result_active) and saw_result:
			break
		var now_st := _watch_row_status(ui._watch_rows_col)
		for n in now_st.keys():
			if str(prev.get(n, "")) != str(now_st[n]) and str(now_st[n]) != "":
				frames_changed.append(frame)
		prev = now_st
	_assert(saw_result, "A trade result (Trade made / No deal) is shown before idle")
	_assert(result_seen_before_idle, "The result state was observable")
	var distinct := {}
	for f in frames_changed:
		distinct[f] = true
	_assert(frames_changed.size() >= 2 and distinct.size() >= 2, "Bot answers must land on different frames, got %s" % str(frames_changed))
	ui.auto_ai = false
	ui.trade_pace_override = -1.0
	_pass_section("104. Live Trade Pacing Test (answers stagger across frames, result held before idle)")

# --- 105: scoreboard rows keep a 4 px vertical gap ----------------------------

func _test_scoreboard_row_gap_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Crimson"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Amber"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(10505, seats, true, 0)
	ui._refresh_ui()
	await _ui_settle(3)
	for k in range(3):
		var a: Control = (ui._scoreboard_row_parts[k] as Dictionary).get("card")
		var b: Control = (ui._scoreboard_row_parts[k + 1] as Dictionary).get("card")
		var gap: float = b.get_global_position().y - (a.get_global_position().y + a.get_global_rect().size.y)
		_assert(absf(gap - 4.0) <= 0.5, "Rows %d and %d must have a 4 px gap, got %.2f" % [k, k + 1, gap])
	_assert(ui._log_panel.custom_minimum_size.y >= 90.0, "The log keeps room for 4 full rows, min=%s" % str(ui._log_panel.custom_minimum_size.y))
	var win: Vector2 = ui.get_viewport().get_visible_rect().size
	_assert(ui._log_panel.get_global_rect().end.y <= win.y + 0.5, "The log bottom stays on screen, got %s vs %s" % [str(ui._log_panel.get_global_rect().end.y), str(win.y)])
	_pass_section("105. Scoreboard Row Gap Test (4 px between rows, log keeps 4 rows on screen)")

# --- 106: toasts stay inside the board, stack, and show a trade once -----------

func _visible_labels_containing(node: Node, needle: String) -> int:
	var n := 0
	for c in node.get_children():
		if c is Label and (c as Label).is_visible_in_tree() and str((c as Label).text).contains(needle):
			n += 1
		n += _visible_labels_containing(c, needle)
	return n

func _test_toast_layout_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(11606, seats, true, 0)
	var s = ui.session
	var st: GameState = s.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 1
	st.open_trades_this_turn = 0
	ui._refresh_ui()
	await _ui_settle(3)
	var long_text := "Ivory counters: gives 1 Clay, wants 1 Timber + 1 Grain + 1 Fleece + 1 Stone right now please"
	_assert(long_text.length() >= 70, "toast test line has 70+ chars, got %d" % long_text.length())
	ui._show_toast(long_text, Palette.ACCENT_GOLD.darkened(0.2), 9.0)
	ui._show_toast("Dune built a road", Color(0.2, 0.4, 0.2), 9.0)
	await _ui_settle(4)
	var rects: Array[Rect2] = []
	for c in ui._toast_layer.get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			rects.append((c as Control).get_global_rect())
	_assert(rects.size() >= 2, "Both shown toasts are on screen, got %d" % rects.size())
	var brect: Rect2 = ui._board_view.get_global_rect()
	var sb: Rect2 = ui._scoreboard_box.get_global_rect()
	for r in rects:
		_assert(r.position.x >= brect.position.x + 8.0 - 0.5, "toast left edge stays 8 px inside the board, got %.1f vs %.1f" % [r.position.x, brect.position.x + 8.0])
		_assert(r.end.x <= brect.end.x - 8.0 + 0.5, "toast right edge stays 8 px inside the board, got %.1f vs %.1f" % [r.end.x, brect.end.x - 8.0])
		_assert(r.position.y >= brect.position.y - 0.5 and r.end.y <= brect.end.y + 0.5, "toast stays vertically inside the board")
		_assert(not r.intersects(sb), "toast never covers the scoreboard rect")
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			_assert(not rects[i].intersects(rects[j]), "toast rects never overlap each other")
	# a completed bot-to-bot trade must appear exactly once above the board
	st = s.state
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	st.players[1]["hand"][GameTypes.ResourceType.IRON] = 3
	st.players[2]["hand"][GameTypes.ResourceType.TIMBER] = 3
	s.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	await _ui_settle(2)
	s.submit_action(0, GameAction.respond_open_trade("decline"))
	await _ui_settle(2)
	s.submit_action(2, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.GRAIN: 1, GameTypes.ResourceType.IRON: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	await _ui_settle(2)
	s.submit_action(3, GameAction.respond_open_trade("accept"))
	await _ui_settle(2)
	s.submit_action(1, GameAction.finalize_open_trade(2))
	await _ui_settle(3)
	_assert(s.state.open_trade.is_empty(), "Counter accepted and the bot trade finalized")
	var toast_traded := 0
	for c in ui._toast_layer.get_children():
		if c is Control and (c as Control).is_visible_in_tree() and _visible_labels_containing(c, "traded") > 0:
			toast_traded += 1
	_assert(toast_traded == 1, "Exactly one toast carries the completed trade, got %d" % toast_traded)
	var board_traded := _visible_labels_containing(ui._board_view, "traded")
	_assert(board_traded == 0, "No board overlay repeats the trade text, got %d" % board_traded)
	var all_rects: Array[Rect2] = []
	for c2 in ui._toast_layer.get_children():
		if c2 is Control and (c2 as Control).is_visible_in_tree():
			all_rects.append((c2 as Control).get_global_rect())
	for r2 in all_rects:
		_assert(r2.position.x >= brect.position.x + 8.0 - 0.5 and r2.end.x <= brect.end.x - 8.0 + 0.5, "trade toast also stays inside the board")
		_assert(not r2.intersects(sb), "trade toast never covers the scoreboard rect")
	_pass_section("106. Toast Layout Test (8 px board margins, no overlap, trade shown once)")

# --- 107: trade panel resource cards are big in every view --------------------

func _tray_card_checks(ui: Node, tag: String) -> void:
	var tray: Rect2 = ui._trade_tray.get_global_rect()
	var big_boxes: Array = [
		ui._trade_give_box, ui._trade_get_box, ui._trade_ro_get_box,
		ui._trade_ro_give_box, ui._watch_terms_get_box, ui._watch_terms_give_box,
	]
	var rects: Array[Rect2] = []
	var seen := 0
	for node in ui._trade_tray.find_children("*", "CardFace", true, false):
		var f := node as CardFace
		if f == null or not f.is_visible_in_tree():
			continue
		seen += 1
		var big: bool = big_boxes.has(f.get_parent())
		var mw := 44.0 if big else 28.0
		var mh := 58.0 if big else 36.0
		_assert(f.size.x >= mw - 0.5 and f.size.y >= mh - 0.5, "%s: tray card is %s, need >= %sx%s" % [tag, str(f.size), str(mw), str(mh)])
		var r: Rect2 = f.get_global_rect()
		var dbg := ""
		var anc: Node = f
		for _i in 5:
			anc = anc.get_parent()
			if anc == null:
				break
			var ac := anc as Control
			dbg += " << " + String(anc.name) + " " + str(ac.position) + "+" + str(ac.size)
		_assert(tray.grow(1.0).encloses(r), "%s: tray card stays inside the panel (%s in %s)%s" % [tag, str(r), str(tray), dbg])
		for o in rects:
			_assert(not (o as Rect2).intersects(r), "%s: tray cards never overlap" % tag)
		rects.append(r)
	_assert(seen > 0, "%s: some tray cards are visible" % tag)
	_assert(not ui._trade_scroll.get_v_scroll_bar().visible, "%s: no vertical scrollbar in the trade panel" % tag)

func _test_trade_card_sizes_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(12807, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the card size test")
	if not reached:
		return
	var st: GameState = s.state
	for r in GameTypes.ALL_RESOURCES:
		st.players[0]["hand"][r] = 3
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	st.players[1]["hand"][GameTypes.ResourceType.TIMBER] = 3
	st.players[2]["hand"][GameTypes.ResourceType.TIMBER] = 3
	ui._set_tray_panel_visible(true)
	await _ui_settle(3)
	_assert(bool(ui._trade_tray.visible), "The trade panel opens")
	# Worst case editor: 5 give kinds + 5 get kinds.
	for r in GameTypes.ALL_RESOURCES:
		ui._trade_give_counts[r] = 1
		ui._trade_get_counts[r] = 1
	ui._refresh_ui()
	await _ui_settle(3)
	_tray_card_checks(ui, "editor 5+5")
	ui._reset_trade_counts()
	ui._adjust_trade_count(true, GameTypes.ResourceType.TIMBER, 1)
	ui._adjust_trade_count(true, GameTypes.ResourceType.CLAY, 1)
	ui._adjust_trade_count(false, GameTypes.ResourceType.GRAIN, 1)
	await _ui_settle(2)
	_tray_card_checks(ui, "editor side-by-side")
	var gf: CardFace = ui._trade_get_faces[GameTypes.ResourceType.GRAIN]
	_ui_real_click(gf)
	await _ui_settle(2)
	_assert(int(ui._trade_get_counts.get(GameTypes.ResourceType.GRAIN, 0)) == 2, "Clicking a get card still adds one")
	var gp: CardFace = ui._give_chip_pool[0]
	_ui_real_click(gp)
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(GameTypes.ResourceType.TIMBER, 0)) == 2, "Clicking a give card's body now adds one more (p31 badge rule)")
	# A bot offer arrives: respond view.
	ui._reset_trade_counts()
	ui._set_tray_panel_visible(false)
	await _ui_settle(1)
	s.submit_action(0, GameAction.end_turn())
	var guard := 0
	st = s.state
	while guard < 200:
		guard += 1
		if s.get_acting_player_id() == 1 and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty():
			break
		if s.is_ai_to_act():
			s.step_ai()
		else:
			s.submit_action(s.get_acting_player_id(), BotController.choose_action(st, s.get_acting_player_id(), 2))
		await _ui_settle(1)
	s.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1, GameTypes.ResourceType.CLAY: 1, GameTypes.ResourceType.FLEECE: 1}))
	_ui_all_bots_decline(ui)  # new rule: every bot answers once before the human
	await _ui_settle(3)
	_assert(bool(ui._trade_respond_view.visible), "The respond view is shown")
	_tray_card_checks(ui, "respond")
	var cb: Button = ui._ot_counter_btn
	_ui_real_click(cb)
	await _ui_settle(3)
	_assert(bool(ui._trade_rows_col.visible), "The counter editor shows the draft rows")
	_tray_card_checks(ui, "counter editor")
	_ui_real_click(ui._ot_back_btn)
	await _ui_settle(2)
	_ui_real_click(ui._ot_decline_btn)
	await _ui_settle(3)
	_assert(not ui.session.state.open_trade.is_empty(), "The offer stays open after the decline")
	_tray_card_checks(ui, "watch")
	# A bot counter brings the mini icons into the answer rail.
	s.submit_action(2, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	await _ui_settle(3)
	_tray_card_checks(ui, "watch with counter")
	var minis := 0
	for node in ui._watch_rows_col.find_children("*", "CardFace", true, false):
		var f := node as CardFace
		if f != null and f.is_visible_in_tree():
			minis += 1
			_assert(f.size.x >= 28.0 - 0.5 and f.size.y >= 36.0 - 0.5, "Counter mini icons are at least 28x36, got %s" % str(f.size))
	_assert(minis >= 2, "The counter row shows mini icons, got %d" % minis)
	st = s.state
	if not st.open_trade.is_empty():
		s.submit_action(int(st.open_trade.get("from", -1)), GameAction.cancel_open_trade())
	await _ui_settle(2)
	ui._set_tray_panel_visible(false)
	root.size = Vector2i(64, 64)
	_pass_section("107. Trade Card Size Test (44x58 cards in every view, 5+5 fits, minis 28x36)")

# --- 120: sidebar must not scroll at 1280x800 while a trade is on -------------

func _sidebar_fit_check(ui: Node, tag: String) -> void:
	var sc: ScrollContainer = null
	for scv in ui._right_panel.find_children("*", "ScrollContainer", true, false):
		var cand := scv as ScrollContainer
		if cand == null or not cand.is_visible_in_tree():
			continue
		for k in cand.get_children():
			if k == ui._sidebar_box:
				sc = cand
			elif k is Control and (k as Control).is_ancestor_of(ui._sidebar_box):
				sc = cand
	_assert(sc != null, "%s: the sidebar scroll container is found" % tag)
	if sc == null:
		return
	var content_min: float = ui._sidebar_box.get_combined_minimum_size().y
	_assert(content_min <= sc.size.y + 0.5, "%s: sidebar content %s fits the %s viewport" % [tag, str(content_min), str(sc.size.y)])
	_assert(not sc.get_v_scroll_bar().visible, "%s: the sidebar shows no vertical scrollbar" % tag)

func _test_sidebar_no_vscroll_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(12909, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the sidebar fit test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	for r in GameTypes.ALL_RESOURCES:
		st.players[0]["hand"][r] = 3
		st.players[1]["hand"][r] = 3
		st.players[2]["hand"][r] = 3
	s.submit_action(0, GameAction.end_turn())
	var guard := 0
	while guard < 200:
		guard += 1
		st = s.state
		if s.get_acting_player_id() == 1 and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty():
			break
		if s.is_ai_to_act():
			s.step_ai()
		else:
			s.submit_action(s.get_acting_player_id(), BotController.choose_action(st, s.get_acting_player_id(), 2))
		await _ui_settle(1)
	# Respond view: a bot offer with every bot already declined.
	s.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	_ui_all_bots_decline(ui)
	await _ui_settle(3)
	_assert(bool(ui._trade_respond_view.visible), "The respond view is up for the sidebar fit test")
	_sidebar_fit_check(ui, "respond")
	# Revise view: the human answers, then Pike really revises his answer.
	s.submit_action(0, GameAction.respond_open_trade("decline"))
	await _ui_settle(3)
	s.submit_action(2, GameAction.respond_open_trade("accept"))
	await _ui_settle(3)
	_sidebar_fit_check(ui, "revise")
	# Own-offer view with a live counter from Pike.
	st = s.state
	if not st.open_trade.is_empty():
		s.submit_action(int(st.open_trade.get("from", -1)), GameAction.cancel_open_trade())
	await _ui_settle(2)
	guard = 0
	while guard < 200:
		guard += 1
		st = s.state
		if s.get_acting_player_id() == 0 and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty():
			break
		if s.is_ai_to_act():
			s.step_ai()
		else:
			s.submit_action(s.get_acting_player_id(), BotController.choose_action(st, s.get_acting_player_id(), 2))
		await _ui_settle(1)
	s.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	s.submit_action(1, GameAction.respond_open_trade("decline"))
	s.submit_action(2, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.CLAY: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	await _ui_settle(3)
	_sidebar_fit_check(ui, "own offer with counter")
	root.size = Vector2i(64, 64)
	_pass_section("120. Sidebar No-Scrollbar Test (respond, revise and own-offer views fit 1280x800)")

func _mini_face_counts(node: Node) -> Dictionary:
	# Document-order walk mapping every resource mini card to the bold "Nx"
	# label printed immediately before it.
	var out := {}
	var stack: Array = [node]
	var last: Label = null
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for i in range(n.get_child_count() - 1, -1, -1):
			stack.append(n.get_child(i))
		if n is Label:
			var txt := str((n as Label).text)
			if txt.ends_with("\u00d7") and txt.left(txt.length() - 1).is_valid_int():
				last = n as Label
		elif n is CardFace:
			var f := n as CardFace
			if f.kind == "resource" and f.resource >= 0:
				var cnt := -1
				if last != null:
					cnt = int(str(last.text).left(str(last.text).length() - 1))
				out[int(f.resource)] = {"count": cnt, "label": last}
			last = null
	return out

func _assert_count_labels(counts: Dictionary, tag: String, clip: Rect2) -> void:
	var want := {
		GameTypes.ResourceType.GRAIN: 2,
		GameTypes.ResourceType.TIMBER: 3,
		GameTypes.ResourceType.CLAY: 1,
	}
	for res in want.keys():
		var e: Dictionary = counts.get(int(res), {})
		_assert(int(e.get("count", -1)) == int(want[res]), "%s: the %s mini card shows %dx, got %s" % [tag, GameTypes.resource_name(int(res)), int(want[res]), str(e.get("count", -1))])
		var lbl: Label = e.get("label")
		_assert(lbl != null, "%s: the %s count has a text label" % [tag, GameTypes.resource_name(int(res))])
		if lbl != null:
			_assert(int(lbl.get_theme_font_size("font_size")) >= 12, "%s: the %s count label uses font size >= 12, got %d" % [tag, GameTypes.resource_name(int(res)), int(lbl.get_theme_font_size("font_size"))])
			_assert(lbl.has_theme_font_override("font"), "%s: the %s count label is bold (font override set)" % [tag, GameTypes.resource_name(int(res))])
			_assert(clip.grow(1.0).encloses(lbl.get_global_rect()), "%s: the %s count label sits inside the visible trade panel" % [tag, GameTypes.resource_name(int(res))])

func _test_counter_count_badges_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(13901, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the counter count badge test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	for r in GameTypes.ALL_RESOURCES:
		st.players[0]["hand"][r] = 4
		st.players[1]["hand"][r] = 4
		st.players[2]["hand"][r] = 4
	# (a) The human proposes and Pike counters: the counter-offer card the
	# proposer reads must carry the counts on the mini cards themselves.
	s.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	s.submit_action(1, GameAction.respond_open_trade("decline"))
	s.submit_action(2, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.GRAIN: 2}, {GameTypes.ResourceType.TIMBER: 3, GameTypes.ResourceType.CLAY: 1}))
	await _ui_settle(3)
	var st64: GameState = s.state
	_assert(not st64.open_trade.is_empty(), "Pike's counter is live for the proposer")
	# The tray may be collapsed while a bot technically holds the turn;
	# hand the turn to the proposer and rebuild so the counter card is
	# built the way the proposer will read it.
	st64.current_player = 0
	ui._set_tray_panel_visible(true)
	ui._refresh_ui()
	await _ui_settle(2)
	# The partner stack re-swaps its children whenever a response tick
	# advances the rebuild key; retry a few frames until the settled set
	# is the one we can read.
	var prop_counts: Dictionary = {}
	for _try in range(4):
		prop_counts = _mini_face_counts(ui._trade_partner_stack)
		if prop_counts.size() == 3:
			break
		await _ui_settle(1)
	_assert(prop_counts.size() == 3, "The proposer's counter card shows three mini cards, got %d" % prop_counts.size())
	_assert_count_labels(prop_counts, "proposer counter card", ui._trade_scroll.get_global_rect())
	var fit_rect: Rect2 = ui._trade_scroll.get_global_rect()
	_assert(not ui._trade_scroll.get_v_scroll_bar().visible, "proposer counter view must not scroll (%s)" % str(fit_rect))
	_assert(not ui._trade_scroll.get_h_scroll_bar().visible, "proposer counter view shows no horizontal scrollbar (%s)" % str(fit_rect))
	var acc_btn := _ui_find_button(ui._trade_partner_stack, "Accept")
	var dec_btn := _ui_find_button(ui._trade_partner_stack, "Decline")
	_assert(acc_btn != null and dec_btn != null, "counter card keeps Accept and Decline buttons")
	if acc_btn != null:
		_assert(fit_rect.encloses(acc_btn.get_global_rect()), "Accept stays inside the visible trade panel (rect %s in %s)" % [str(acc_btn.get_global_rect()), str(fit_rect)])
	if dec_btn != null:
		_assert(fit_rect.encloses(dec_btn.get_global_rect()), "Decline stays inside the visible trade panel (rect %s in %s)" % [str(dec_btn.get_global_rect()), str(fit_rect)])
	# (b) A watching responder sees the same counter in an answer row with
	# the same counts on the mini cards.
	s.submit_action(0, GameAction.cancel_open_trade())
	await _ui_settle(2)
	st = s.state
	st.current_player = 1
	s.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	# The viewer answers first (decline): the responder widgets stay put on
	# the left, so the answer rows get the narrower rail — the counter row
	# must still fit without scrolling.
	s.submit_action(0, GameAction.respond_open_trade("decline"))
	s.submit_action(2, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.GRAIN: 2}, {GameTypes.ResourceType.TIMBER: 3, GameTypes.ResourceType.CLAY: 1}))
	await _ui_settle(3)
	_assert(not s.state.open_trade.is_empty(), "The watched trade is still open")
	var watch_counts: Dictionary = {}
	for _try in range(4):
		watch_counts = _mini_face_counts(ui._watch_rows_col)
		if watch_counts.size() == 3:
			break
		await _ui_settle(1)
	_assert(watch_counts.size() == 3, "The watch answer row shows three mini cards, got %d" % watch_counts.size())
	_assert_count_labels(watch_counts, "watch answer row", ui._trade_scroll.get_global_rect())
	var wrect: Rect2 = ui._trade_scroll.get_global_rect()
	_assert(not ui._trade_scroll.get_v_scroll_bar().visible, "watcher counter view must not scroll (%s)" % str(wrect))
	_assert(not ui._trade_scroll.get_h_scroll_bar().visible, "watcher counter view shows no horizontal scrollbar (%s)" % str(wrect))
	var n_rows := 0
	for rnode in ui._watch_rows_col.get_children():
		var rc := rnode as Control
		if rc == null or not rc.visible:
			continue
		n_rows += 1
		_assert(wrect.encloses(rc.get_global_rect()), "watcher row %s stays inside the visible trade panel (%s in %s)" % [String(rc.name), str(rc.get_global_rect()), str(wrect)])
	_assert(n_rows == 3, "watcher view lists all three responder rows, got %d" % n_rows)
	root.size = Vector2i(64, 64)
	_pass_section("121. Counter Card Count Badges Test (proposer card and watch row carry xN on the mini cards)")

func _assert_popup_geometry(ui: Node, tag: String, box: Control, title_name: String) -> void:
	var cont: Rect2 = ui._subpanel_container.get_global_rect()
	_assert(cont.size.y > 60.0, "%s: the popup has a real height, got %s" % [tag, str(cont)])
	var win := Rect2(Vector2.ZERO, Vector2(root.size))
	_assert(cont.position.x >= 4.0 and cont.position.y >= 4.0, "%s: popup keeps a 4 px margin from the window top-left, got %s" % [tag, str(cont)])
	_assert(cont.end.x <= win.end.x - 4.0 and cont.end.y <= win.end.y - 4.0, "%s: popup keeps a 4 px margin from the window bottom-right, got %s in %s" % [tag, str(cont), str(win)])
	for c in ui._subpanel_container.find_children("*", "Control", true, false):
		var cc := c as Control
		if cc != null and cc.visible and cc.is_visible_in_tree() and cc.get_global_rect().size.x > 0.0:
			_assert(cont.grow(1.0).encloses(cc.get_global_rect()), "%s: %s stays inside the panel frame, got %s in %s" % [tag, String(cc.name), str(cc.get_global_rect()), str(cont)])
	var close_btn := ui._subpanel_container.find_child("SubpanelClose", true, false) as Button
	_assert(close_btn != null, "%s: popup has an x button" % tag)
	var cr := close_btn.get_global_rect()
	_assert(cr.size.x >= 18.0 and cr.size.y >= 18.0, "%s: the x button is clickable, got %s" % [tag, str(cr)])
	var title := box.find_child(title_name, true, false) as Label
	if title != null:
		_assert(not cr.intersects(title.get_global_rect()), "%s: the x does not overlap the title, %s vs %s" % [tag, str(cr), str(title.get_global_rect())])
	for opt_v in [ui._bounty_res1_opt, ui._bounty_res2_opt, ui._decree_res_opt]:
		var opt := opt_v as OptionButton
		if opt != null and opt.is_visible_in_tree():
			_assert(not cr.intersects(opt.get_global_rect()), "%s: the x does not overlap a dropdown, %s vs %s" % [tag, str(cr), str(opt.get_global_rect())])
	var br: Rect2 = ui._hand_bar_panel.get_global_rect()
	_assert(cont.end.y <= br.position.y - 3.0, "%s: the popup sits above the hand bar, got %s vs bar y %.1f" % [tag, str(cont), br.position.y])
	for ctype_v in ui._popup_chip_by_type.keys():
		var chip: CardFace = ui._popup_chip_by_type[ctype_v]
		if chip != null and is_instance_valid(chip) and chip.is_visible_in_tree():
			_assert(not cont.intersects(chip.get_global_rect()), "%s: the popup does not cover action card %s, got %s vs %s" % [tag, str(ctype_v), str(cont), str(chip.get_global_rect())])

func _test_handbar_close_clicks_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(14704, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the hand bar close test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.HARVEST_BOUNTY)
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.TRADE_DECREE)
	ui._refresh_ui()
	await _ui_settle(2)
	var bchip := _ui_find_action_chip(ui, GameTypes.DevCardType.HARVEST_BOUNTY)
	var dchip := _ui_find_action_chip(ui, GameTypes.DevCardType.TRADE_DECREE)
	_assert(bchip != null and dchip != null, "Both popup action cards are visible")
	if bchip == null or dchip == null:
		root.size = Vector2i(64, 64)
		return
	# 1) The same action card toggles the popup closed.
	_ui_press_with_motion(bchip.get_global_rect().get_center())
	await _ui_settle(1)
	_assert(bool(ui._subpanel_container.visible) and bool(ui._bounty_box.visible), "The Bounty popup opened")
	_ui_press_with_motion(bchip.get_global_rect().get_center())
	await _ui_settle(1)
	_assert(not bool(ui._subpanel_container.visible), "Clicking the Bounty card again closes the popup")
	# 2) A different popup card swaps in one click.
	_ui_press_with_motion(bchip.get_global_rect().get_center())
	await _ui_settle(1)
	var snap := _ui_state_snapshot(s)
	var draft0: Dictionary = ui._trade_give_counts.duplicate()
	_ui_press_with_motion(dchip.get_global_rect().get_center())
	await _ui_settle(1)
	_assert(bool(ui._subpanel_container.visible) and bool(ui._decree_box.visible) and not bool(ui._bounty_box.visible), "Clicking Decree while Bounty is open swaps in one click")
	_ui_press_key(KEY_ESCAPE)
	await _ui_settle(1)
	# 3) Empty hand-bar space closes the popup and does nothing else.
	_ui_press_with_motion(bchip.get_global_rect().get_center())
	await _ui_settle(1)
	var bar: Rect2 = ui._hand_bar_panel.get_global_rect()
	_ui_press_with_motion(Vector2(bar.position.x + bar.size.x * 0.5, bar.position.y + bar.size.y * 0.5))
	await _ui_settle(1)
	_assert(not bool(ui._subpanel_container.visible), "A click on empty hand-bar space closes the popup")
	_assert(_ui_state_snapshot(s) == snap, "The empty-space close changed no game state")
	# 4) End Turn closes the popup without ending the turn.
	_ui_press_with_motion(bchip.get_global_rect().get_center())
	await _ui_settle(1)
	_ui_press_with_motion(ui._end_turn_btn.get_global_rect().get_center())
	await _ui_settle(2)
	_assert(not bool(ui._subpanel_container.visible), "A click on End Turn closes the popup")
	_assert(int(s.state.current_player) == 0, "The closing End Turn click did not end the turn, actor %d" % int(s.state.current_player))
	_assert(_ui_state_snapshot(s) == snap, "The End Turn closing click changed no game state")
	# 5) A hand resource card closes the popup without starting a trade draft.
	_ui_press_with_motion(bchip.get_global_rect().get_center())
	await _ui_settle(1)
	var res_face: CardFace = null
	for c in ui._hand_bar_panel.find_children("*", "CardFace", true, false):
		var f := c as CardFace
		if f != null and f.kind == "resource" and f.is_visible_in_tree():
			res_face = f
			break
	_assert(res_face != null, "A resource card is visible in the hand bar")
	if res_face != null:
		_ui_press_with_motion(res_face.get_global_rect().get_center())
		await _ui_settle(1)
		_assert(not bool(ui._subpanel_container.visible), "A click on a resource card closes the popup")
		_assert(ui._trade_give_counts == draft0, "The closing resource-card click did not change the trade draft")
		_assert(_ui_state_snapshot(s) == snap, "The resource-card closing click changed no game state")
	root.size = Vector2i(64, 64)
	_pass_section("124. Hand-Bar Close Clicks Test (same card toggles, other card swaps, empty space / End Turn / resource card only close)")

func _test_subpanel_geometry_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(14703, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the popup geometry test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.HARVEST_BOUNTY)
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.TRADE_DECREE)
	ui._refresh_ui()
	await _ui_settle(2)
	var bchip := _ui_find_action_chip(ui, GameTypes.DevCardType.HARVEST_BOUNTY)
	var dchip := _ui_find_action_chip(ui, GameTypes.DevCardType.TRADE_DECREE)
	_assert(bchip != null and dchip != null, "Both popup action cards are visible")
	if bchip == null or dchip == null:
		root.size = Vector2i(64, 64)
		return
	# Bounty.
	_ui_press_with_motion(bchip.get_global_rect().get_center())
	await _ui_settle(2)
	_assert(bool(ui._subpanel_container.visible) and bool(ui._bounty_box.visible), "Bounty popup opened at 1280x800")
	_assert_popup_geometry(ui, "bounty@1280", ui._bounty_box, "BountyTitle")
	# Decree swap in one click (bounty still open).
	_ui_press_with_motion(dchip.get_global_rect().get_center())
	await _ui_settle(2)
	_assert(bool(ui._subpanel_container.visible) and bool(ui._decree_box.visible) and not bool(ui._bounty_box.visible), "One click swaps Bounty for Decree in one click")
	_assert_popup_geometry(ui, "decree@1280", ui._decree_box, "DecreeTitle")
	_ui_press_key(KEY_ESCAPE)
	await _ui_settle(1)
	_assert(not bool(ui._subpanel_container.visible), "The popup is closed at the end")
	root.size = Vector2i(64, 64)
	_pass_section("125. Sub-Panel Geometry Test (popup wraps its content, stays in the window, never covers action cards)")

func _test_rev_anim_timing_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var badge_script: GDScript = load("res://scripts/main_ui.gd")
	var wraps_run := func(rate: float) -> int:
		ui._rev_pulse_wraps.clear()
		var host := PanelContainer.new()
		ui.add_child(host)
		ui._rev_pulse_pending_pid = 1
		ui._pulse_row_bg(host, Color(0.8, 0.3, 0.2))
		var steps := 0
		while ui._rev_pulse_wraps.size() > 0 and steps < 400:
			ui._tick_rev_pulse(rate)
			steps += 1
		host.free()
		return steps
	var steps60: int = wraps_run.call(1.0 / 60.0)
	_assert(steps60 >= 53 and steps60 <= 55, "The pulse lasts 0.9 s at 60 fps (+/- one frame), got %d steps" % steps60)
	var steps30: int = wraps_run.call(1.0 / 30.0)
	_assert(steps30 >= 26 and steps30 <= 28, "The pulse lasts 0.9 s at 30 fps (+/- one frame), got %d steps" % steps30)
	ui._rev_pulse_wraps.clear()
	var spin_run := func(rate: float) -> int:
		var badge: Control = badge_script.RevBadge.new()
		ui.add_child(badge)
		badge.anim_start_ms = 555
		var steps := 0
		badge._process(rate)
		steps += 1
		while float(badge.spin_left) > 0.0 and steps < 400:
			badge._process(rate)
			steps += 1
		badge.free()
		return steps
	var spin60: int = spin_run.call(1.0 / 60.0)
	_assert(spin60 >= 53 and spin60 <= 55, "The badge spin lasts 0.9 s at 60 fps (+/- one frame), got %d steps" % spin60)
	var spin30: int = spin_run.call(1.0 / 30.0)
	_assert(spin30 >= 26 and spin30 <= 28, "The badge spin lasts 0.9 s at 30 fps (+/- one frame), got %d steps" % spin30)
	root.size = Vector2i(64, 64)
	_pass_section("123. Revision Anim Timing Test (pulse and spin last 0.9 s of played time at 60 and 30 fps)")

func _ui_press_with_motion(at: Vector2) -> void:
	var center := root.get_screen_transform() * at
	var mv := InputEventMouseMotion.new()
	mv.position = center
	mv.global_position = center
	root.push_input(mv)
	var pe := InputEventMouseButton.new()
	pe.button_index = MOUSE_BUTTON_LEFT
	pe.pressed = true
	pe.position = center
	pe.global_position = center
	root.push_input(pe)
	var re := InputEventMouseButton.new()
	re.button_index = MOUSE_BUTTON_LEFT
	re.pressed = false
	re.position = center
	re.global_position = center
	root.push_input(re)

func _ui_press_key(keycode: int) -> void:
	var k_on := InputEventKey.new()
	k_on.keycode = keycode
	k_on.pressed = true
	root.push_input(k_on)
	var k_off := InputEventKey.new()
	k_off.keycode = keycode
	k_off.pressed = false
	root.push_input(k_off)

func _ui_find_action_chip(ui: Node, ctype: int) -> CardFace:
	for c in ui.find_children("*", "CardFace", true, false):
		var f := c as CardFace
		if f != null and f.kind == "action" and f.action == ctype and f.is_visible_in_tree():
			return f
	return null

func _ui_find_button(node: Node, txt: String) -> Button:
	for c in node.find_children("*", "Button", true, false):
		var b := c as Button
		if b != null and str(b.text) == txt and b.is_visible_in_tree():
			return b
	return null

func _ui_state_snapshot(s) -> String:
	var st = s.state
	var parts: Array[String] = [str(st.turn_number), str(st.current_player), str(st.phase), str(st.open_trade.is_empty())]
	for p_v in st.players:
		var p: Dictionary = p_v
		var keys: Array = p.keys()
		keys.sort()
		for k in keys:
			parts.append("%s.%s=%s" % [str(p.get("name", "?")), str(k), var_to_str(p[k])])
	return "|".join(parts)

func _test_subpanel_close_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(14702, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the sub-panel close test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.HARVEST_BOUNTY)
	ui._refresh_ui()
	await _ui_settle(2)
	var chip := _ui_find_action_chip(ui, GameTypes.DevCardType.HARVEST_BOUNTY)
	_assert(chip != null, "The Bounty card chip is visible in the action row")
	if chip == null:
		root.size = Vector2i(64, 64)
		return
	# Open by clicking the Bounty card with real input events.
	_ui_press_with_motion(chip.get_global_rect().get_center())
	await _ui_settle(1)
	_assert(bool(ui._subpanel_container.visible) and bool(ui._bounty_box.visible), "Clicking the Bounty card opens the sub-panel")
	# A press on the board closes it, swallows the click, and changes nothing.
	var snap := _ui_state_snapshot(s)
	var board_at: Vector2 = ui._board_view.get_global_rect().get_center()
	_ui_press_with_motion(board_at)
	await _ui_settle(2)
	_assert(not bool(ui._subpanel_container.visible), "A board press closes the Bounty sub-panel")
	_assert(_ui_state_snapshot(s) == snap, "The closing board press changed no game state")
	_assert(int(st.players[0]["dev_cards"].count(GameTypes.DevCardType.HARVEST_BOUNTY)) == 1, "The Bounty card stays in hand after an outside close")
	# A click inside the panel (its resource dropdown) must NOT close it.
	_ui_press_with_motion(chip.get_global_rect().get_center())
	await _ui_settle(1)
	_assert(bool(ui._subpanel_container.visible), "The Bounty sub-panel reopened")
	_ui_press_with_motion(ui._bounty_res1_opt.get_global_rect().get_center())
	await _ui_settle(1)
	_assert(bool(ui._subpanel_container.visible) and bool(ui._bounty_box.visible), "A click inside the sub-panel keeps it open")
	var bounty_pop := ui._bounty_res1_opt.get_popup() as Popup
	if bounty_pop != null and bounty_pop.visible:
		bounty_pop.hide()
	await _ui_settle(1)
	# Esc closes it.
	_ui_press_key(KEY_ESCAPE)
	await _ui_settle(1)
	_assert(not bool(ui._subpanel_container.visible), "Esc closes the Bounty sub-panel")
	# The corner x button closes it.
	_ui_press_with_motion(chip.get_global_rect().get_center())
	await _ui_settle(1)
	var close_btn := ui._subpanel_container.find_child("SubpanelClose", true, false) as Button
	_assert(close_btn != null, "The sub-panel has an x close button")
	if close_btn != null:
		_ui_press_with_motion(close_btn.get_global_rect().get_center())
		await _ui_settle(1)
		_assert(not bool(ui._subpanel_container.visible), "The x button closes the sub-panel")
	# Play it for real: pick two resources, press the button, gain them.
	var before := 0
	for r in GameTypes.ALL_RESOURCES:
		before += int(st.players[0]["hand"].get(r, 0))
	_ui_press_with_motion(chip.get_global_rect().get_center())
	await _ui_settle(1)
	ui._bounty_res1_opt.select(GameTypes.ResourceType.GRAIN)
	ui._bounty_res2_opt.select(GameTypes.ResourceType.TIMBER)
	var claim := _ui_find_button(ui._bounty_box, "Claim 2 Resources")
	_assert(claim != null, "The Claim button is present in the Bounty sub-panel")
	if claim != null:
		_ui_press_with_motion(claim.get_global_rect().get_center())
		await _ui_settle(2)
		var after := 0
		for r in GameTypes.ALL_RESOURCES:
			after += int(st.players[0]["hand"].get(r, 0))
		_assert(after == before + 2, "Playing Bounty gained exactly 2 resources, before %d after %d" % [before, after])
		_assert(not bool(ui._subpanel_container.visible), "Playing Bounty hides the sub-panel")
	# Decree: same open / outside-click / Esc behaviour. Playing the
	# Bounty used the human's action, so drive back to their main phase.
	var guard := 0
	while guard < 200:
		guard += 1
		st = s.state
		if s.get_acting_player_id() == 0 and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty():
			break
		if s.is_ai_to_act():
			s.step_ai()
		else:
			s.submit_action(s.get_acting_player_id(), BotController.choose_action(st, s.get_acting_player_id(), 2))
		await _ui_settle(1)
	_assert(guard < 200, "The human is back in their main phase for the Decree part")
	# Playing the Bounty is one card per turn by design; clear the flag the
	# way a fresh turn would, then hand over the Decree card.
	st.players[0]["played_dev_this_turn"] = false
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.TRADE_DECREE)
	ui._refresh_ui()
	await _ui_settle(2)
	var dchip := _ui_find_action_chip(ui, GameTypes.DevCardType.TRADE_DECREE)
	_assert(dchip != null, "The Decree card chip is visible in the action row")
	if dchip == null:
		root.size = Vector2i(64, 64)
		return
	_ui_press_with_motion(dchip.get_global_rect().get_center())
	await _ui_settle(1)
	_assert(bool(ui._subpanel_container.visible) and bool(ui._decree_box.visible), "Clicking the Decree card opens its sub-panel")
	var snap2 := _ui_state_snapshot(s)
	_ui_press_with_motion(board_at)
	await _ui_settle(2)
	_assert(not bool(ui._subpanel_container.visible), "A board press closes the Decree sub-panel")
	_assert(_ui_state_snapshot(s) == snap2, "The closing Decree board press changed no game state")
	_assert(int(st.players[0]["dev_cards"].count(GameTypes.DevCardType.TRADE_DECREE)) == 1, "The Decree card stays in hand after an outside close")
	_ui_press_with_motion(dchip.get_global_rect().get_center())
	await _ui_settle(1)
	_assert(bool(ui._subpanel_container.visible), "The Decree sub-panel reopened")
	_ui_press_key(KEY_ESCAPE)
	await _ui_settle(1)
	_assert(not bool(ui._subpanel_container.visible), "Esc closes the Decree sub-panel")
	root.size = Vector2i(64, 64)
	_pass_section("122. Sub-Panel Close Test (Bounty/Decree close on outside click, Esc and x; inside clicks keep them open; closing never plays)")

func _ui_click_global(at: Vector2) -> void:
	var center := root.get_screen_transform() * at
	var pe := InputEventMouseButton.new()
	pe.button_index = MOUSE_BUTTON_LEFT
	pe.pressed = true
	pe.position = center
	pe.global_position = center
	root.push_input(pe)
	var re := InputEventMouseButton.new()
	re.button_index = MOUSE_BUTTON_LEFT
	re.pressed = false
	re.position = center
	re.global_position = center
	root.push_input(re)

func _tray_status_inside(ui: Node, tag: String) -> void:
	var tray: Rect2 = ui._trade_tray.get_global_rect()
	var seen := 0
	for l in ui._trade_right_col.find_children("*", "Label", true, false):
		var lbl := l as Label
		if lbl == null or not lbl.is_visible_in_tree():
			continue
		seen += 1
		var r: Rect2 = lbl.get_global_rect()
		_assert(r.end.x <= tray.end.x - 8.0 + 1.0, "%s: status text '%s' stays 8 px clear of the panel edge (%.1f vs %.1f)" % [tag, lbl.text, r.end.x, tray.end.x - 8.0])
	_assert(seen > 0, "%s: the rail shows status labels" % tag)

func _tray_band_cards(ui: Node, tag: String) -> int:
	var n := 0
	for box in [ui._watch_terms_get_box, ui._watch_terms_give_box]:
		for c in (box as Control).get_children():
			var f := c as CardFace
			if f != null and f.is_visible_in_tree():
				n += 1
				_assert(f.size.x >= 44.0 - 0.5 and f.size.y >= 58.0 - 0.5, "%s: band card is %s, need >= 44x58" % [tag, str(f.size)])
	return n

func _test_panel_extras_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await ui.get_tree().process_frame
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(12809, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the panel extras test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	var held := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(st.players[0]["hand"].get(r, 0)) >= 1:
			held = r
			break
	_ui_real_click(ui._res_card_refs[held])
	await _ui_settle(3)
	_assert(bool(ui._trade_tray.visible), "The panel opens on a real hand click")
	_assert(ui._trade_clear_btn.is_visible_in_tree(), "Clear is visible in the editor after a hand click")
	_assert(ui._trade_tray.get_global_rect().grow(1.0).encloses(ui._trade_clear_btn.get_global_rect()), "Clear sits inside the panel")
	var want := -1
	for r in GameTypes.ALL_RESOURCES:
		if r != held:
			want = r
			break
	_ui_real_click(ui._trade_get_faces[want])
	await _ui_settle(2)
	_assert(not bool(ui._trade_ask_btn.disabled), "Ask players enables with both sides drafted")
	_ui_real_click(ui._trade_ask_btn)
	await _ui_settle(3)
	st = s.state
	_assert(not st.open_trade.is_empty() and int(st.open_trade.get("from", -1)) == 0, "The human offer is open")
	_assert(bool(ui._trade_watch_col.visible), "The own offer view shows the terms band host")
	_assert(_tray_band_cards(ui, "own offer") >= 2, "The own offer view shows the offer cards")
	_tray_status_inside(ui, "own offer")
	s.submit_action(0, GameAction.cancel_open_trade())
	await _ui_settle(2)
	# A completed bot-to-bot trade renders the result band.
	st = s.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 1
	st.open_trades_this_turn = 0
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2
	st.players[1]["hand"][GameTypes.ResourceType.TIMBER] = 2
	st.players[2]["hand"][GameTypes.ResourceType.GRAIN] = 2
	st.players[2]["hand"][GameTypes.ResourceType.TIMBER] = 2
	st.players[3]["hand"][GameTypes.ResourceType.GRAIN] = 2
	ui.trade_pace_override = 0.5
	var opened: Dictionary = s.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	_assert(bool(opened.get("ok", false)), "Bot 1 opens the trade, got %s" % str(opened.get("error", "")))
	await _ui_settle(2)
	await _ui_settle(2)
	if s.get_acting_player_id() != 1:
		_tray_status_inside(ui, "watch")
	s.submit_action(s.get_acting_player_id(), GameAction.respond_open_trade("accept" if s.get_acting_player_id() == 2 else "decline"))
	await _ui_settle(2)
	if not s.state.open_trade.is_empty() and s.get_acting_player_id() != 1:
		s.submit_action(s.get_acting_player_id(), GameAction.respond_open_trade("accept" if s.get_acting_player_id() == 2 else "decline"))
		await _ui_settle(2)
	if not s.state.open_trade.is_empty() and s.get_acting_player_id() == 0:
		_tray_status_inside(ui, "respond")
		s.submit_action(0, GameAction.respond_open_trade("decline"))
		await _ui_settle(2)
	var resp_guard := 0
	while not s.state.open_trade.is_empty() and resp_guard < 8:
		var ap: int = s.get_acting_player_id()
		if ap == 1:
			break
		s.submit_action(ap, GameAction.respond_open_trade("accept" if ap == 2 else "decline"))
		resp_guard += 1
	await _ui_settle(2)
	var fin: Dictionary = s.submit_action(1, GameAction.finalize_open_trade(2))
	_assert(bool(fin.get("ok", false)), "Bot 1 finalizes with the accepting bot, got %s" % str(fin.get("error", "")))
	await _ui_settle(4)
	_assert(bool(ui._ot_result_active), "The result view is active after the bot trade")
	_assert(ui._trade_title_lbl.text.contains("traded with"), "The result header names the traders, got %s" % ui._trade_title_lbl.text)
	_assert(_tray_band_cards(ui, "result") >= 2, "The result view shows the traded cards")
	_tray_status_inside(ui, "result")
	ui.trade_pace_override = -1.0
	ui._ot_result_active = false
	ui._refresh_ui()
	await _ui_settle(2)
	# Clear comes back in the editor after a result has been shown.
	var reached2 := _ui_drive_until(ui, func(st2: GameState) -> bool:
		return not s.is_ai_to_act() and st2.phase == GameTypes.TurnPhase.TURN_MAIN and st2.open_trade.is_empty()
	)
	if reached2:
		var held2 := -1
		for r in GameTypes.ALL_RESOURCES:
			if int(s.state.players[0]["hand"].get(r, 0)) >= 1:
				held2 = r
				break
		ui._set_tray_panel_visible(false)
		await _ui_settle(1)
		_ui_real_click(ui._res_card_refs[held2])
		await _ui_settle(3)
		_assert(ui._trade_clear_btn.is_visible_in_tree(), "Clear survives the result view: visible again in the editor")
	root.size = Vector2i(64, 64)
	_pass_section("108. Panel Extras Test (Clear visible in the editor, 8 px rail padding, cards in own/result views)")

func _test_blocker_rehex_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await ui.get_tree().process_frame
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(12810, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the re-hex test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	var topo := HexMath.get_topology()
	var tiles: Array[int] = []
	for t in range(19):
		if t != st.blocker_tile and topo.tile_vertices[t].size() >= 2:
			tiles.append(t)
	_assert(tiles.size() >= 3, "The map offers three tiles away from the Blocker")
	var tile_a: int = tiles[0]
	var tile_b: int = tiles[1]
	var tile_c: int = tiles[2]
	for r in GameTypes.ALL_RESOURCES:
		st.players[1]["hand"][r] = maxi(int(st.players[1]["hand"].get(r, 0)), 1)
		st.players[2]["hand"][r] = maxi(int(st.players[2]["hand"].get(r, 0)), 1)
		st.players[3]["hand"][r] = maxi(int(st.players[3]["hand"].get(r, 0)), 1)
	st.vertex_owner[topo.tile_vertices[tile_a][0]] = 1
	st.vertex_owner[topo.tile_vertices[tile_a][1]] = 2
	st.vertex_owner[topo.tile_vertices[tile_b][0]] = 2
	st.vertex_owner[topo.tile_vertices[tile_b][1]] = 3
	st.vertex_owner[topo.tile_vertices[tile_c][0]] = 1
	st.vertex_owner[topo.tile_vertices[tile_c][1]] = 3
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	ui._refresh_ui()
	await _ui_settle(3)
	_assert(int(ui._board_view.interaction_mode) == int(BoardView.InteractionMode.PICK_BLOCKER_TILE), "Blocker tiles are highlighted")
	var blocker_before: int = st.blocker_tile
	var human_before := GameTypes.hand_total(st.players[0]["hand"])
	_ui_click_global(ui._board_view.global_position + ui._board_view.get_spot_screen_position("tile", tile_a))
	await _ui_settle(2)
	_assert(bool(ui._board_view.steal_targets_showing()), "Clicking tile A marks the victims on the board")
	_assert(st.blocker_tile == blocker_before, "The Blocker does not move while the victim is not chosen")
	var names_a := ""
	for t in ui._board_view._steal_targets:
		names_a += str((t as Dictionary).get("label", ""))
	_assert(names_a.contains(str(st.players[1]["name"])) and names_a.contains(str(st.players[2]["name"])), "Tile A marks its two victims")
	_assert(ui._blocker_ghost != null and bool(ui._blocker_ghost.visible), "The pending hex is marked with a ghost")
	_ui_click_global(ui._board_view.global_position + ui._board_view.get_spot_screen_position("tile", tile_b))
	await _ui_settle(2)
	_assert(bool(ui._board_view.steal_targets_showing()), "Clicking tile B switches the marks instead of locking")
	_assert(st.blocker_tile == blocker_before, "The Blocker still has not moved after switching hexes")
	var names_b := ""
	for t in ui._board_view._steal_targets:
		names_b += str((t as Dictionary).get("label", ""))
	_assert(names_b.contains(str(st.players[2]["name"])) and names_b.contains(str(st.players[3]["name"])), "Tile B marks its own victims")
	_ui_click_global(ui._board_view.global_position + ui._board_view.get_spot_screen_position("tile", tile_b))
	await _ui_settle(2)
	_assert(bool(ui._board_view.steal_targets_showing()), "Clicking the pending hex again keeps the marks")
	_ui_click_global(ui._board_view.global_position + ui._board_view.get_steal_target_ring_rect(0).get_center())
	await _ui_settle(3)
	st = s.state
	_assert(not bool(ui._board_view.steal_targets_showing()), "Choosing a victim clears the marks")
	_assert(st.blocker_tile == tile_b, "The Blocker lands on the switched-to tile B, got %d" % st.blocker_tile)
	_assert(GameTypes.hand_total(st.players[0]["hand"]) == human_before + 1, "The chosen victim's card reaches the human")
	# Guard path: same re-hex behaviour.
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.players[0]["played_dev_this_turn"] = false
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.GUARD)
	ui._on_play_guard_pressed()
	await _ui_settle(2)
	_assert(bool(ui._pending_guard_card), "Guard mode is active")
	_ui_click_global(ui._board_view.global_position + ui._board_view.get_spot_screen_position("tile", tile_a))
	await _ui_settle(2)
	_assert(bool(ui._board_view.steal_targets_showing()), "Guard: tile A marks the victims on the board")
	_ui_click_global(ui._board_view.global_position + ui._board_view.get_spot_screen_position("tile", tile_c))
	await _ui_settle(2)
	_assert(bool(ui._board_view.steal_targets_showing()), "Guard: clicking tile C switches the marks")
	var names_c := ""
	for t in ui._board_view._steal_targets:
		names_c += str((t as Dictionary).get("label", ""))
	_assert(names_c.contains(str(st.players[1]["name"])) and names_c.contains(str(st.players[3]["name"])), "Guard: tile C marks its own victims")
	var guards_before := int(st.players[0]["played_guards"])
	_ui_click_global(ui._board_view.global_position + ui._board_view.get_steal_target_ring_rect(0).get_center())
	await _ui_settle(3)
	st = s.state
	_assert(st.blocker_tile == tile_c, "Guard: the Blocker moves to the switched-to tile C")
	_assert(int(st.players[0]["played_guards"]) == guards_before + 1, "Guard: the Guard card is played")
	root.size = Vector2i(64, 64)
	_pass_section("109. Blocker Re-hex Test (victim selection stays open, other hexes stay clickable)")

func _test_fps_cap_body(ui: Node) -> void:
	var before := Engine.max_fps
	ui._update_fps_cap(10.0)
	ui._update_fps_cap(10.0)
	_assert(Engine.max_fps == before, "The headless UI leaves Engine.max_fps at %d, got %d" % [before, Engine.max_fps])
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(2301, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN
	)
	_assert(reached, "The human turn is reachable for the fps cap test")
	if not reached:
		return
	var quiet := false
	var quiet_t0 := Time.get_ticks_msec()
	_settle_hold += 1
	while Time.get_ticks_msec() - quiet_t0 < 20000:
		await process_frame
		if (
			ui._toast_layer != null and ui._toast_layer.get_children().is_empty()
			and ui._flight_layer != null and ui._flight_layer.get_children().is_empty()
			and not bool(ui._dice_show_active)
		):
			break
	# Loop tweens leaked by earlier test sections (nodes freed without
	# auto_kill keep running in the shared SceneTree) would keep the tween
	# signal true forever; they are stale, so drop them before the quiet check.
	for _tw in get_processed_tweens():
		(_tw as Tween).kill()
	while Time.get_ticks_msec() - quiet_t0 < 25000:
		await process_frame
		if not bool(ui._game_is_active()):
			quiet = true
			break
	_settle_hold -= 1
	if not quiet:
		var running := 0
		for tw in get_processed_tweens():
			if tw.is_running():
				running += 1
		print("[fpscap] human=%s dice=%s steal=%s hold=%s splash=%s flight=%s toast=%s busy=%s running_tw=%d" % [
			str(ui._is_human_acting()), str(ui._dice_show_active), str(ui._steal_anim_active()),
			str(ui._trade_hold_active()), str(ui._splash_overlay != null and ui._splash_overlay.visible),
			str(ui._flight_layer != null and not ui._flight_layer.get_children().is_empty()),
			str(ui._toast_layer != null and not ui._toast_layer.get_children().is_empty()),
			str(ui._board_view.is_busy()), running,
		])
	_assert(quiet, "An idle moment is reachable on the human's turn")
	_assert(int(ui._wanted_fps()) == 60, "Before idling, the wanted cap is 60")
	ui._fps_idle_timer = 1.0
	_assert(int(ui._wanted_fps()) == 60, "1 s of idle still wants 60")
	ui._fps_idle_timer = 2.0
	_assert(int(ui._wanted_fps()) == 30, "2 s of idle wants 30")
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(320, 240)
	mm.global_position = Vector2(320, 240)
	root.push_input(mm)
	_assert(float(ui._fps_idle_timer) <= 0.001, "A real mouse-motion event resets the idle timer, got %f" % float(ui._fps_idle_timer))
	_assert(int(ui._wanted_fps()) == 60, "Right after an input event the wanted cap is 60")
	ui._fps_idle_timer = 2.0
	ui._dice_show_active = true
	_assert(int(ui._wanted_fps()) == 60, "While the dice show runs the wanted cap is 60")
	ui._dice_show_active = false
	_pass_section("110. Adaptive FPS Cap Test (decision function, idle timer, headless untouched)")

func _test_log_cap_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await process_frame
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(2401, seats, true, 0)
	for i in range(1, 1001):
		ui._append_log("Log line %04d [b]mark[/b]" % i)
		_assert(ui._log_lines.size() <= 450, "The stored log never exceeds 450 (at line %d it is %d)" % [i, ui._log_lines.size()])
	var final_n := int(ui._log_lines.size())
	_assert(final_n >= 400 and final_n <= 450, "After 1000 appends the log holds %d lines, want 400..450" % final_n)
	var parsed: String = ui._event_log.get_parsed_text()
	_assert(parsed.contains("Log line 1000"), "The newest line is in the log")
	_assert(not parsed.contains("Log line 0001"), "The first line was trimmed away")
	_assert(not parsed.contains("[b]"), "BBCode tags render and never show raw")
	_assert(str(ui._log_lines[ui._log_lines.size() - 1]).contains("[b]"), "The stored source keeps the original BBCode")
	var first_num := 1000 - final_n + 1
	var ok_order := true
	for idx in range(final_n):
		var want := "Log line %04d" % (first_num + idx)
		if not str(ui._log_lines[idx]).contains(want):
			ok_order = false
	_assert(ok_order, "The kept lines are the newest %d in order" % final_n)
	ui._open_log_popup()
	_assert(bool(ui._log_popup.visible), "The log popup opens")
	_settle_hold += 1
	await process_frame
	_settle_hold -= 1
	_assert(float(ui._log_popup.size.x) >= 300.0 and float(ui._log_popup.size.y) >= 300.0, "The opened popup is laid out over the right panel, got %s" % str(ui._log_popup.size))
	_assert(ui._log_popup_text.get_parsed_text() == ui._event_log.get_parsed_text(), "The open popup shows the same capped content as the main log")
	for i in range(1001, 1075):
		ui._append_log("Log line %04d pop" % i)
	_assert(ui._log_popup_text.get_parsed_text() == ui._event_log.get_parsed_text(), "After a trim the popup mirrors the main log")
	ui._close_log_popup()
	_assert(not bool(ui._log_popup.visible), "Closing hides the popup")
	root.size = Vector2i(64, 64)
	ui._seed_input.text = "2402"
	ui._start_match_from_lobby_settings()
	_assert(not str(ui._event_log.get_parsed_text()).contains("Log line 1000"), "A new match clears the capped log content")
	_assert(int(ui._log_lines.size()) < 100, "A new match restarts the stored lines small, got %d" % int(ui._log_lines.size()))
	_pass_section("111. Event Log Cap Test (400 lines kept, 450 trim point, popup mirrors, new match clears)")

func _replay_deep_eq(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return "%s dict size %d vs %d" % [path, da.size(), db.size()]
		for k in da.keys():
			if not db.has(k):
				return "%s missing key %s" % [path, str(k)]
			var r := _replay_deep_eq(da[k], db[k], path + "." + str(k))
			if r != "":
				return r
		return ""
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return "%s arr size %d vs %d" % [path, aa.size(), ab.size()]
		for i in range(aa.size()):
			var r2 := _replay_deep_eq(aa[i], ab[i], path + "[%d]" % i)
			if r2 != "":
				return r2
		return ""
	if typeof(a) == TYPE_DICTIONARY or typeof(b) == TYPE_DICTIONARY or typeof(a) == TYPE_ARRAY or typeof(b) == TYPE_ARRAY:
		return "%s type mismatch %d vs %d" % [path, typeof(a), typeof(b)]
	if a != b:
		return "%s %s vs %s" % [path, str(a), str(b)]
	return ""

func _replay_state_diff(a: GameState, b: GameState) -> String:
	var fields: Array[String] = ["seed_val", "num_players", "phase", "current_player", "start_player", "turn_number", "winner", "setup_anchor_vertex", "tile_terrains", "tile_numbers", "blocker_tile", "vertex_ports", "vertex_owner", "vertex_building", "edge_owner", "players", "dev_deck", "bank", "last_steal", "pending_discards", "open_trade", "open_trades_this_turn", "road_work_remaining", "longest_route_holder", "largest_guard_holder"]
	for f in fields:
		var r := _replay_deep_eq(a.get(f), b.get(f), f)
		if r != "":
			return r
	if a.last_dice != b.last_dice:
		return "last_dice %s vs %s" % [str(a.last_dice), str(b.last_dice)]
	if a.rng.state != b.rng.state:
		return "rng.state %d vs %d" % [a.rng.state, b.rng.state]
	return ""

func _replay_fingerprint(st: GameState) -> String:
	var parts: Array[String] = [str(st.turn_number), str(st.phase), str(st.current_player), str(st.rng.state)]
	for p in range(st.num_players):
		parts.append(str(st.get_victory_points(p, true)))
	return "|".join(parts)

func _replay_run_match(seedv: int, n_p: int, p_balanced: bool, forced: int) -> LocalSession:
	var s := LocalSession.new()
	var seats: Array[SeatConfig] = []
	for i in range(n_p):
		seats.append(SeatConfig.new(i, SeatConfig.SeatType.AI_MEDIUM, ""))
	s.start_match(seedv, seats, p_balanced, forced)
	var guard_steps := 0
	while s.state.phase != GameTypes.TurnPhase.GAME_OVER and guard_steps < 5000:
		if not s.is_ai_to_act():
			break
		s.step_ai()
		guard_steps += 1
	return s

func _test_replay_engine() -> void:
	var configs: Array[Array] = [
		[11, 4, true, -1],
		[777, 3, true, -1],
		[2301, 4, false, -1],
		[2301, 4, true, 2],
	]
	var main: LocalSession = null
	for cfg in configs:
		var s := _replay_run_match(int(cfg[0]), int(cfg[1]), bool(cfg[2]), int(cfg[3]))
		_assert(s.state.phase == GameTypes.TurnPhase.GAME_OVER, "Replay seed %d players %d: match reaches GAME_OVER" % [int(cfg[0]), int(cfg[1])])
		var n := s.replay.step_count()
		_assert(n > 100, "Match recorded %d entries, want a real match" % n)
		var d := _replay_state_diff(s.replay.state_at(n), s.state)
		_assert(d == "", "Replay of seed %d players %d balanced %s forced %d reproduces the final state, first difference: %s" % [int(cfg[0]), int(cfg[1]), str(bool(cfg[2])), int(cfg[3]), d])
		var j: Variant = JSON.parse_string(JSON.stringify(s.replay.to_dict()))
		var r2: MatchReplay = MatchReplay.from_dict(j as Dictionary)
		_assert(r2 != null, "from_dict rebuilds the match")
		if r2 != null:
			var d2 := _replay_state_diff(r2.state_at(r2.step_count()), s.state)
			_assert(d2 == "", "JSON round trip replays to the same final state, first difference: %s" % d2)
		if int(cfg[0]) == 11 and int(cfg[1]) == 4 and int(cfg[3]) == -1:
			main = s
	_assert(main != null, "The seed-11 reference match is available")
	if main == null:
		return
	var n_main := main.replay.step_count()
	var rng_sel := RandomNumberGenerator.new()
	rng_sel.seed = 9182
	var pick: Array[int] = []
	for _i in range(30):
		pick.append(rng_sel.randi_range(0, n_main))
	var asc_fp: Array[String] = []
	for k in pick:
		var scratch: MatchReplay = MatchReplay.from_dict(main.replay.to_dict())
		var d3 := _replay_state_diff(main.replay.state_at(k), scratch.state_at(k))
		_assert(d3 == "", "Random access step %d equals replay-from-scratch, first difference: %s" % [k, d3])
		asc_fp.append(_replay_fingerprint(main.replay.state_at(k)))
	var same_down := true
	for i in range(pick.size() - 1, -1, -1):
		var kk: int = pick[i]
		if _replay_fingerprint(main.replay.state_at(kk)) != asc_fp[i]:
			same_down = false
		var scratch2: MatchReplay = MatchReplay.from_dict(main.replay.to_dict())
		var d4 := _replay_state_diff(main.replay.state_at(kk), scratch2.state_at(kk))
		_assert(d4 == "", "Decreasing-order access step %d still exact, first difference: %s" % [kk, d4])
	_assert(same_down, "state_at in decreasing order matches the increasing-order results (no snapshot mutation leaks)")
	var live := LocalSession.new()
	var lseats: Array[SeatConfig] = []
	for i in range(4):
		lseats.append(SeatConfig.new(i, SeatConfig.SeatType.AI_MEDIUM, ""))
	live.start_match(11, lseats, true, -1)
	var live_checks := 0
	var live_guard := 0
	while live.state.phase != GameTypes.TurnPhase.GAME_OVER and live_guard < 5000:
		if not live.is_ai_to_act():
			break
		live.step_ai()
		live_guard += 1
		var cnt := live.replay.step_count()
		if cnt > 0 and cnt % 40 == 0 and live_checks < cnt:
			live_checks = cnt
			var dl := _replay_state_diff(live.replay.state_at(cnt), live.state)
			_assert(dl == "", "Mid-match replay equals the live state at entry %d, first difference: %s" % [cnt, dl])
	_assert(live_checks >= 5, "Mid-match replay was compared at several checkpoints, got %d" % live_checks)
	var human := LocalSession.new()
	var hseats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_MEDIUM, "Riven"),
	]
	human.start_match(555, hseats, true, 0)
	if int(human.state.phase) == int(GameTypes.TurnPhase.SETUP_SETTLEMENT_1) and int(human.state.current_player) == 0:
		var verts: Array[int] = RulesEngine.get_valid_settlement_vertices(human.state, 0, true)
		var before := human.replay.step_count()
		var ok_res := human.submit_action(0, GameAction.place_settlement(verts[0]))
		_assert(bool(ok_res.get("ok", false)), "The human setup placement is accepted")
		_assert(human.replay.step_count() == before + 1, "The accepted human action is recorded")
		var last_entry: Dictionary = human.replay.entries[human.replay.step_count() - 1]
		_assert(int(last_entry.get("p", -1)) == 0 and str((last_entry.get("a", {}) as Dictionary).get("type", "")) == "place_settlement", "The recorded entry carries the player and action")
		var rej_res := human.submit_action(0, GameAction.place_settlement(verts[0]))
		_assert(not bool(rej_res.get("ok", false)), "A rejected action is rejected")
		_assert(human.replay.step_count() == before + 1, "A rejected action is not recorded")
	var path := "user://p25_replay_test.json"
	var err := main.replay.save_to_file(path)
	_assert(err == OK, "save_to_file succeeds, got %d" % err)
	var loaded: MatchReplay = MatchReplay.load_from_file(path)
	_assert(loaded != null, "load_from_file returns a replay")
	if loaded != null:
		var d5 := _replay_state_diff(loaded.state_at(loaded.step_count()), main.state)
		_assert(d5 == "", "The saved file replays to the final state, first difference: %s" % d5)
	_assert(MatchReplay.load_from_file("user://p25_missing_replay_file.json") == null, "Loading a missing file returns null")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_assert(not FileAccess.file_exists(path), "The test save file is deleted")
	var t0 := Time.get_ticks_usec()
	var rng_perf := RandomNumberGenerator.new()
	rng_perf.seed = 4242
	for _i in range(200):
		main.replay.state_at(rng_perf.randi_range(0, n_main))
	var avg_ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 200.0
	print("[replay] entries=%d, json=%d bytes, state_at avg=%.2f ms" % [n_main, JSON.stringify(main.replay.to_dict()).length(), avg_ms])
	_assert(avg_ms < 20.0, "state_at averages %.2f ms over 200 random calls, want < 20 ms" % avg_ms)
	_pass_section("112. Match Replay Test (exact replay, snapshots, JSON and file round trips)")

func _ui_send_key(keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	root.push_input(ev)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.pressed = false
	root.push_input(up)

func _ui_review_btn(ui: Node, text: String) -> Button:
	for c in ui._review_bar.get_children():
		if c is Button and str((c as Button).text) == text:
			return c as Button
	return null

func _test_review_mode_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.AI_EASY, "A"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "B"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "C"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_HARD, "D"),
	]
	ui.session.start_match(71, seats, true, -1)
	var steps := 0
	while ui.session.state.phase != GameTypes.TurnPhase.GAME_OVER and steps < 5000:
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
			steps += 1
			if steps % 40 == 0:
				await _ui_settle(1)
		else:
			break
	await _ui_settle(3)
	_assert(ui.session.state.phase == GameTypes.TurnPhase.GAME_OVER, "Review test match reached GAME_OVER (steps %d)" % steps)
	_assert(bool(ui._splash_overlay.visible), "Splash shown after the bot match")
	var review_btn: Button = ui._splash_review_btn
	_assert(review_btn != null and bool(review_btn.visible), "The splash has a visible Review match button")
	_assert(str(review_btn.text) == "Review match", "The review button text, got '%s'" % str(review_btn.text))
	var real_session: LocalSession = ui.session
	var live_before: GameState = real_session.state.clone()
	var entries_before := real_session.replay.step_count()
	var flights_before: int = ui._flight_layer.get_child_count()
	var toasts_before: int = ui._toast_layer.get_child_count()
	var roll_fx_before: int = int(ui._roll_fx_count)
	_ui_real_click(review_btn)
	await _ui_settle(2)
	_assert(not bool(ui._splash_overlay.visible), "Review click hides the splash")
	_assert(bool(ui._review_active), "Review mode is active")
	_assert(bool(ui._review_bar.visible), "The review bar is visible")
	_assert(int(ui._review_slider.max_value) == entries_before, "Slider max equals step count, got %d want %d" % [int(ui._review_slider.max_value), entries_before])
	_assert(int(ui._review_slider.tick_count) == 0, "Slider draws custom turn marks, not the per-step comb")
	_assert(int(ui._review_slider_ticks.marks.size()) > 1, "Turn marks are placed on the slider")
	_assert(not bool(ui.session.is_ai_to_act()), "No bot can act in review")
	_assert(not bool(ui._is_human_acting()), "No human can act in review")
	var mid: int = int(floor(float(entries_before) / 2.0))
	for step in [0, 1, mini(37, entries_before), mid, entries_before]:
		ui._review_slider.value = float(step)
		await _ui_settle(1)
		var want: GameState = real_session.replay.state_at(step)
		var d := _replay_state_diff(ui.session.state, want)
		_assert(d == "", "Slider step %d renders the replay state, first difference: %s" % [step, d])
		_assert(str(ui._review_step_lbl.text).begins_with("Step %d / %d" % [step, entries_before]), "Step label at %d, got '%s'" % [step, str(ui._review_step_lbl.text)])
		if step > 0:
			var parts: Array[String] = []
			for ev in real_session.replay.events_at(step):
				parts.append(ui._log_display_text(str(ev)))
			var want_cap := " \u00b7 ".join(parts) if not parts.is_empty() else "\u2014"
			if parts.is_empty():
				# p29r item 6: a review step has no events; the caption names the
				# seat that is content with its answer instead of showing an em dash.
				var ent: Dictionary = real_session.replay.entries[step - 1]
				if str((ent.get("a", {}) as Dictionary).get("type", "")) == "review_open_trade":
					var stp: GameState = real_session.replay.state_at(step)
					want_cap = "%s keeps their answer." % str(stp.players[int(ent.get("p", -1))].get("name", "?"))
			_assert(str(ui._review_caption.text) == want_cap, "Caption at step %d shows the events, got '%s' want '%s'" % [step, str(ui._review_caption.text), want_cap])
	_ui_send_key(KEY_HOME)
	await _ui_settle(1)
	_assert(int(ui._review_step) == 0, "Home jumps to the first step")
	_ui_send_key(KEY_END)
	await _ui_settle(1)
	_assert(int(ui._review_step) == entries_before, "End jumps to the last step")
	_ui_send_key(KEY_END)
	_assert(int(ui._review_step) == entries_before, "End clamps at the last step")
	_ui_real_click(_ui_review_btn(ui, "\u25c0"))
	await _ui_settle(1)
	_assert(int(ui._review_step) == entries_before - 1, "Previous step button moves back one")
	_ui_send_key(KEY_LEFT)
	_assert(int(ui._review_step) == entries_before - 2, "Left arrow moves back one")
	_ui_send_key(KEY_RIGHT)
	_ui_send_key(KEY_RIGHT)
	_assert(int(ui._review_step) == entries_before, "Right arrow moves forward (clamped at max)")
	_ui_send_key(KEY_HOME)
	_ui_send_key(KEY_HOME)
	_assert(int(ui._review_step) == 0, "Home clamps at 0")
	_ui_send_key(KEY_LEFT)
	_assert(int(ui._review_step) == 0, "Left clamps at 0")
	_ui_real_click(_ui_review_btn(ui, "\u25b6"))
	await _ui_settle(1)
	_assert(int(ui._review_step) == 1, "Next step button moves forward one")
	var turn_now: int = real_session.replay.turn_at(1)
	var want_next_turn := real_session.replay.first_step_of_turn(turn_now + 1)
	_ui_real_click(_ui_review_btn(ui, "Turn \u25b6"))
	await _ui_settle(1)
	_assert(want_next_turn < 0 or int(ui._review_step) == want_next_turn, "Next-turn button jumps to the first step of turn %d, got %d want %d" % [turn_now + 1, int(ui._review_step), want_next_turn])
	var after_turn := int(ui._review_step)
	_ui_real_click(_ui_review_btn(ui, "\u25c0 Turn"))
	await _ui_settle(1)
	_assert(int(ui._review_step) < after_turn, "Prev-turn button moves to an earlier turn")
	_ui_real_click(_ui_review_btn(ui, "\u23ed"))
	await _ui_settle(1)
	_assert(int(ui._review_step) == entries_before, "Last button clamps at the end")
	_ui_real_click(_ui_review_btn(ui, "\u23ee"))
	await _ui_settle(1)
	_assert(int(ui._review_step) == 0, "First button jumps to 0")
	ui._review_speed = 4
	_ui_send_key(KEY_SPACE)
	await _ui_settle(1)
	_assert(bool(ui._review_playing), "Space starts playback")
	ui._review_play_acc = 0.2
	await _ui_settle(2)
	_assert(int(ui._review_step) >= 1, "Playback advanced the step")
	_ui_send_key(KEY_SPACE)
	await _ui_settle(1)
	_assert(not bool(ui._review_playing), "Space pauses playback")
	var played_to := int(ui._review_step)
	for step2 in [3, 60, entries_before - 5]:
		if step2 <= 0 or step2 >= entries_before:
			continue
		ui._review_slider.value = float(step2)
		await _ui_settle(1)
	_assert(bool(ui._review_active), "Review is still active after navigation")
	_assert(ui._flight_layer.get_child_count() <= flights_before, "No card flight nodes were created during review")
	_assert(ui._toast_layer.get_child_count() <= toasts_before, "No toast nodes were created during review")
	_assert(int(ui._roll_fx_count) == roll_fx_before, "No dice roll fx during review")
	_assert(not bool(ui._dice_show_active), "The dice show stays off in review")
	_assert(ui.session.replay.step_count() == entries_before, "The replay entry count is unchanged")
	_assert(_replay_state_diff(live_before, real_session.state) == "", "The live match state is untouched during review")
	ui._review_slider.value = float(mini(60, entries_before))
	await _ui_settle(1)
	var slot_k := -1
	for k in ui._sb_row_slot_pid.keys():
		if int(ui._sb_row_slot_pid[k]) == 1:
			slot_k = int(k)
	_assert(slot_k >= 0, "Player 1 has a scoreboard row")
	var row_card: Control = (ui._scoreboard_row_parts[slot_k] as Dictionary)["card"]
	_ui_real_click(row_card)
	await _ui_settle(1)
	_assert(int(ui._view_pid()) == 1, "Clicking a scoreboard row switches the reviewed hand view")
	_assert(str(ui._hand_view_name.text).contains("Viewing:"), "The strip says who is being viewed, got '%s'" % str(ui._hand_view_name.text))
	var view_state: GameState = ui.session.state
	for r in GameTypes.ALL_RESOURCES:
		var face: CardFace = ui._res_card_refs[r]
		var want_cnt := int((view_state.players[1].get("hand", {}) as Dictionary).get(r, 0))
		_assert(int(face.count) == want_cnt, "Hand strip shows player 1 resource %d as %d, want %d" % [r, int(face.count), want_cnt])
	var exit_btn: Button = _ui_review_btn(ui, "Exit review")
	_ui_real_click(exit_btn)
	await _ui_settle(2)
	_assert(bool(ui._splash_overlay.visible), "Exit review returns to the splash")
	_assert(ui.session == real_session, "Exit review restores the real session")
	_assert(not bool(ui._review_active), "Review mode is off")
	_assert(not bool(ui._review_bar.visible), "The review bar is gone")
	_assert(str(ui._splash_title.text) != "", "The splash still shows the result")
	_assert(_replay_state_diff(live_before, ui.session.state) == "", "The live match state is byte-for-byte unchanged after exiting")
	_assert(ui.session.replay.step_count() == entries_before, "The replay entry count is unchanged after exiting")
	_ui_send_key(KEY_ESCAPE)
	await _ui_settle(1)
	_assert(bool(ui._splash_overlay.visible), "Escape outside review does not crash or exit the splash")
	ui._splash_new_game_btn.pressed.emit()
	await _ui_settle(3)
	_assert(ui.session.state.phase != GameTypes.TurnPhase.GAME_OVER, "A new match starts from the splash")
	_assert(not bool(ui._review_active), "Review stays off after starting a new match")
	var ok_prompt := false
	for _i in range(30):
		if bool(ui._is_human_acting()) and ui.session.state.phase == GameTypes.TurnPhase.SETUP_SETTLEMENT_1:
			ok_prompt = true
			break
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
		await _ui_settle(1)
	_assert(ok_prompt, "The first human setup prompt is reachable after review")
	_pass_section("113. Replay Review Mode Test (splash entry, slider, buttons, keys, hands, inertness, exit)")

func _ui_replay_rows(ui: Node) -> Array:
	return ui._replays_list_box.get_children()

func _ui_replay_row(ui: Node, needle: String) -> HBoxContainer:
	for c in ui._replays_list_box.get_children():
		for ch in (c as Node).get_children():
			if ch is Label and str((ch as Label).text).contains(needle):
				return c as HBoxContainer
	return null

func _ui_row_btn(row: HBoxContainer, text: String) -> Button:
	for c in row.get_children():
		if c is Button and str((c as Button).text) == text:
			return c as Button
	return null

func _ui_replay_files_named() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("user://replays")
	if dir != null:
		for f in dir.get_files():
			if str(f).ends_with(".json"):
				out.append(str(f))
	return out

func _test_saved_replays_body(ui: Node) -> void:
	var dir0 := DirAccess.open("user://replays")
	if dir0 != null:
		for f in dir0.get_files():
			if str(f).contains("_seed27"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://replays/" + str(f)))
	await _ui_settle(1)
	var created: Array[String] = []
	var base_files := _ui_replay_files_named()
	ui._show_lobby()
	await _ui_settle(2)
	if base_files.is_empty():
		var rb0: Button = null
		for c in ui._lobby_overlay.find_children("*", "Button", true, false):
			if str((c as Button).text) == "Saved replays":
				rb0 = c as Button
		_ui_real_click(rb0)
		await _ui_settle(4)
		var texts := ""
		for c in ui._replays_list_box.get_children():
			if c is Label:
				texts += str((c as Label).text)
			else:
				for ch in (c as Node).get_children():
					if ch is Label:
						texts += str((ch as Label).text)
		_assert(texts.contains("No saved replays yet"), "Empty list text visible, got '%s'" % texts)
		ui._replays_overlay.visible = false
	_assert(bool(ui._lobby_overlay.visible), "Lobby visible before saving")
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.AI_EASY, "A"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "B"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "C"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_HARD, "D"),
	]
	ui.session.start_match(2701, seats, true, -1)
	var steps := 0
	while ui.session.state.phase != GameTypes.TurnPhase.GAME_OVER and steps < 5000:
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
			steps += 1
			if steps % 40 == 0:
				await _ui_settle(1)
		else:
			break
	await _ui_settle(3)
	_assert(bool(ui._splash_overlay.visible), "Match 1 ended and shows the splash")
	var lobby_btn: Button = null
	for c in ui._lobby_overlay.find_children("*", "Button", true, false):
		if str((c as Button).text) == "Saved replays":
			lobby_btn = c as Button
	_assert(lobby_btn != null, "The lobby has a Saved replays button")
	_ui_real_click(ui._splash_save_btn)
	await _ui_settle(2)
	var path1 := str(ui._replay_saved_path)
	_assert(path1.begins_with("user://replays/") and path1.contains("_seed2701.json"), "Save wrote %s" % path1)
	created.append(path1)
	_assert(str(ui._splash_save_btn.text) == "Saved \u2713" and bool(ui._splash_save_btn.disabled), "Save button shows Saved and disables, got '%s'" % str(ui._splash_save_btn.text))
	_assert(FileAccess.file_exists(path1), "The saved file exists")
	var n2701 := 0
	for f in _ui_replay_files_named():
		if str(f).contains("_seed2701."):
			n2701 += 1
	_assert(n2701 == 1, "Exactly one file for match 1, got %d" % n2701)
	var loaded1: MatchReplay = MatchReplay.load_from_file(path1)
	_assert(loaded1 != null, "The saved file loads")
	if loaded1 != null:
		var d := _replay_state_diff(loaded1.state_at(loaded1.step_count()), ui.session.state)
		_assert(d == "", "The saved replay replays to the live final state: %s" % d)
	_ui_real_click(ui._splash_save_btn)
	await _ui_settle(2)
	n2701 = 0
	for f in _ui_replay_files_named():
		if str(f).contains("_seed2701."):
			n2701 += 1
	_assert(n2701 == 1, "The disabled second click created no second file, got %d" % n2701)
	ui._splash_lobby_btn.pressed.emit()
	await _ui_settle(2)
	_assert(bool(ui._lobby_overlay.visible), "Back to Lobby shows the lobby")
	var corrupt_path := "user://replays/19990101-000000_seed2700.json"
	var cf := FileAccess.open(corrupt_path, FileAccess.WRITE)
	cf.store_string("not json")
	cf.close()
	created.append(corrupt_path)
	_ui_real_click(lobby_btn)
	await _ui_settle(4)
	_assert(bool(ui._replays_overlay.visible), "The saved replays list opened")
	_assert(_ui_replay_rows(ui).size() == 2, "The list shows the save plus the corrupt file, got %d rows" % _ui_replay_rows(ui).size())
	var bad_row := _ui_replay_row(ui, "Unreadable file")
	_assert(bad_row != null, "The corrupt file is listed as Unreadable")
	if bad_row != null:
		_assert(bool(_ui_row_btn(bad_row, "Review").disabled), "Review is disabled for the corrupt file")
		_assert(not bool(_ui_row_btn(bad_row, "Delete").disabled), "Delete stays enabled for the corrupt file")
	ui._replays_overlay.visible = false
	ui._seed_input.text = "2702"
	ui._splash_new_game_btn.pressed.emit()
	await _ui_settle(2)
	steps = 0
	while ui.session.state.phase != GameTypes.TurnPhase.GAME_OVER and steps < 5000:
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
			steps += 1
		else:
			ui.session.submit_action(ui.session.get_acting_player_id(), BotController.choose_action(ui.session.state, ui.session.get_acting_player_id(), 2))
		if steps % 40 == 0:
			await _ui_settle(1)
	await _ui_settle(3)
	_assert(bool(ui._splash_overlay.visible), "Match 2 shows the splash")
	_ui_real_click(ui._splash_save_btn)
	await _ui_settle(2)
	var path2 := str(ui._replay_saved_path)
	_assert(path2.contains("_seed2702.json"), "Match 2 saved to %s" % path2)
	created.append(path2)
	ui._splash_lobby_btn.pressed.emit()
	await _ui_settle(2)
	_ui_real_click(lobby_btn)
	await _ui_settle(4)
	var rows := _ui_replay_rows(ui)
	_assert(rows.size() == 3, "The list shows 3 rows, got %d" % rows.size())
	var first_txt := ""
	for ch in (rows[0] as Node).get_children():
		if ch is Label:
			first_txt = str((ch as Label).text)
	_assert(first_txt.contains("seed 2702"), "Newest first: the 2702 file is on top, got '%s'" % first_txt)
	var both_win := true
	var seen := 0
	for r in rows:
		var t := ""
		for ch in (r as Node).get_children():
			if ch is Label:
				t = str((ch as Label).text)
		if t.contains("seed 2701") or t.contains("seed 2702"):
			seen += 1
			if not t.contains(" wins "):
				both_win = false
	_assert(seen == 2 and both_win, "Both marker rows show a winner name")
	var row2701 := _ui_replay_row(ui, "seed 2701")
	var rev2701 := _ui_row_btn(row2701, "Review")
	_ui_real_click(rev2701)
	await _ui_settle(3)
	_assert(not bool(ui._lobby_overlay.visible), "Reviewing from the list hides the lobby")
	_assert(bool(ui._review_active), "Review is active for the saved replay")
	_assert(not bool(ui._review_save_btn.visible), "Save for later is hidden when opened from the list")
	var want_steps := MatchReplay.load_from_file(path1).step_count()
	_assert(int(ui._review_slider.max_value) == want_steps, "Slider max equals the saved replay's steps, got %d want %d" % [int(ui._review_slider.max_value), want_steps])
	var nm0 := str(ui.session.state.players[ui.session.state.current_player].get("name", ""))
	_assert(str(ui._status_banner_label.text) == "Reviewing match \u2014 %s's turn" % nm0, "Banner at step 0, got '%s'" % str(ui._status_banner_label.text))
	ui._review_slider.value = float(int(want_steps / 2))
	await _ui_settle(1)
	var nm1 := str(ui.session.state.players[ui.session.state.current_player].get("name", ""))
	_assert(str(ui._status_banner_label.text) == "Reviewing match \u2014 %s's turn" % nm1, "Banner at the middle step, got '%s'" % str(ui._status_banner_label.text))
	_ui_send_key(KEY_ESCAPE)
	await _ui_settle(3)
	_assert(bool(ui._lobby_overlay.visible), "Esc from list-review returns to the lobby")
	_assert(not bool(ui._review_active), "Review is off after Esc")
	var start_btn: Button = null
	for c in ui._lobby_overlay.find_children("*", "Button", true, false):
		if str((c as Button).text) == "Start":
			start_btn = c as Button
	_ui_real_click(start_btn)
	await _ui_settle(2)
	var ok_prompt := false
	for _i in range(30):
		if bool(ui._is_human_acting()) and ui.session.state.phase == GameTypes.TurnPhase.SETUP_SETTLEMENT_1:
			ok_prompt = true
			break
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
		await _ui_settle(1)
	_assert(ok_prompt, "A normal match can still be started from the lobby after review")
	ui._open_replays_list()
	await _ui_settle(4)
	var del_row := _ui_replay_row(ui, "seed 2701")
	var del_btn := _ui_row_btn(del_row, "Delete")
	_ui_real_click(del_btn)
	await _ui_settle(2)
	_assert(str(del_btn.text) == "Really delete?", "Delete first asks for confirmation, got '%s'" % str(del_btn.text))
	_ui_real_click(del_btn)
	await _ui_settle(4)
	_assert(not FileAccess.file_exists(path1), "The deleted file is gone")
	_assert(_ui_replay_row(ui, "seed 2701") == null, "The deleted row is removed from the list")
	_assert(_ui_replay_rows(ui).size() == 2, "Two rows remain, got %d" % _ui_replay_rows(ui).size())
	ui._replays_overlay.visible = false
	for pth in created:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pth))
	await _ui_settle(1)
	for pth in created:
		_assert(not FileAccess.file_exists(pth), "Test file %s cleaned up" % pth)
	_pass_section("114. Saved Replays Test (save for later, lobby list, review from file, delete with confirm)")

func _test_steal_onboard_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await ui.get_tree().process_frame
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(12811, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the on-board steal test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	var topo := HexMath.get_topology()
	for pid in [1, 2, 3]:
		for r in GameTypes.ALL_RESOURCES:
			st.players[pid]["hand"][r] = 3
	var tiles: Array[int] = []
	for t in range(19):
		if t != st.blocker_tile and topo.tile_vertices[t].size() == 6:
			tiles.append(t)
	var picked: Array[int] = []
	for t in tiles:
		var clash := false
		for p in picked:
			for v in topo.tile_vertices[t]:
				if topo.tile_vertices[p].has(v):
					clash = true
					break
			if clash:
				break
		if not clash:
			picked.append(t)
		if picked.size() == 3:
			break
	_assert(picked.size() == 3, "The map offers three vertex-disjoint tiles")
	var tile_a: int = picked[0]
	var tile_b: int = picked[1]
	var tile_c: int = picked[2]
	var blocker_orig: int = st.blocker_tile
	# Tile A: Dune owns one vertex; Pike owns a settlement AND a city vertex.
	st.vertex_owner[topo.tile_vertices[tile_a][0]] = 1
	st.vertex_building[topo.tile_vertices[tile_a][0]] = GameTypes.BuildingType.SETTLEMENT
	st.vertex_owner[topo.tile_vertices[tile_a][1]] = 2
	st.vertex_building[topo.tile_vertices[tile_a][1]] = GameTypes.BuildingType.SETTLEMENT
	st.vertex_owner[topo.tile_vertices[tile_a][2]] = 2
	st.vertex_building[topo.tile_vertices[tile_a][2]] = GameTypes.BuildingType.CITY
	# Tile B: a single victim (Riven).
	st.vertex_owner[topo.tile_vertices[tile_b][0]] = 3
	st.vertex_building[topo.tile_vertices[tile_b][0]] = GameTypes.BuildingType.SETTLEMENT
	# Tile C: three victims.
	st.vertex_owner[topo.tile_vertices[tile_c][0]] = 1
	st.vertex_owner[topo.tile_vertices[tile_c][1]] = 2
	st.vertex_owner[topo.tile_vertices[tile_c][2]] = 3
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	ui._refresh_ui()
	await _ui_settle(3)
	var city_vertex: int = int(topo.tile_vertices[tile_a][2])
	var board_pos: Vector2 = ui._board_view.global_position
	# Two victims -> two on-board marks, Pike marked on its city vertex.
	_ui_click_global(board_pos + ui._board_view.get_spot_screen_position("tile", tile_a))
	await _ui_settle(2)
	_assert(ui._board_view.get_steal_target_count() == 2, "Two victims draw exactly two on-board marks, got %d" % ui._board_view.get_steal_target_count())
	var pike_idx := -1
	for i in range(ui._board_view.get_steal_target_count()):
		if int((ui._board_view._steal_targets[i] as Dictionary).get("pid", -1)) == 2:
			pike_idx = i
	_assert(pike_idx >= 0, "Pike is offered as a steal target")
	if pike_idx >= 0:
		var ring: Rect2 = ui._board_view.get_steal_target_ring_rect(pike_idx)
		var city_spot: Vector2 = ui._board_view.get_spot_screen_position("vertex", city_vertex)
		_assert(ring.get_center().distance_to(city_spot) < 1.0, "The two-building player is marked on the City, not the settlement")
		_assert(ring.size.x >= 44.0 and ring.size.y >= 44.0, "The ring hit area is at least 44x44, got %s" % str(ring.size))
		# Tag rects are inside the board and never overlap each other or a ring.
		var board_rect := Rect2(Vector2.ZERO, ui._board_view.size)
		for i in range(ui._board_view.get_steal_target_count()):
			var tag: Rect2 = ui._board_view.get_steal_target_tag_rect(i)
			_assert(board_rect.encloses(tag), "Target %d tag lies inside the board" % i)
			for j in range(i + 1, ui._board_view.get_steal_target_count()):
				_assert(not tag.intersects(ui._board_view.get_steal_target_tag_rect(j)), "Tags %d and %d do not overlap" % [i, j])
	_assert(not ui.has_method("_build_steal_chooser") and not ui.has_method("_open_steal_chooser") and not ui.has_method("_position_steal_chooser"), "The old chooser panel code is gone")
	var chooser_props := 0
	for prop in ui.get_property_list():
		if str(prop.name).contains("steal_chooser"):
			chooser_props += 1
	_assert(chooser_props == 0, "No chooser panel properties remain on the main UI")
	# Esc clears the marks and keeps the picker open.
	var blocker_before: int = st.blocker_tile
	_ui_send_key(KEY_ESCAPE)
	await _ui_settle(2)
	_assert(not bool(ui._board_view.steal_targets_showing()), "Esc clears the on-board marks")
	_assert(st.blocker_tile == blocker_before, "Esc does not move the Blocker")
	_assert(int(ui._board_view.interaction_mode) == int(BoardView.InteractionMode.PICK_BLOCKER_TILE), "After Esc the Blocker can still be placed")
	# Re-mark, then click Pike's NAME TAG to steal from Pike.
	_ui_click_global(board_pos + ui._board_view.get_spot_screen_position("tile", tile_a))
	await _ui_settle(2)
	pike_idx = -1
	for i in range(ui._board_view.get_steal_target_count()):
		if int((ui._board_view._steal_targets[i] as Dictionary).get("pid", -1)) == 2:
			pike_idx = i
	var human_cards_before := GameTypes.hand_total(st.players[0]["hand"])
	_ui_click_global(board_pos + ui._board_view.get_steal_target_tag_rect(pike_idx).get_center())
	await _ui_settle(3)
	st = s.state
	_assert(st.blocker_tile == tile_a, "Clicking the name tag moves the Blocker to the pending hex")
	_assert(int(st.last_steal.get("victim", -1)) == 2, "Clicking Pike's tag steals from Pike, got %d" % int(st.last_steal.get("victim", -1)))
	_assert(GameTypes.hand_total(st.players[0]["hand"]) == human_cards_before + 1, "The stolen card reaches the human")
	# Three victims: retarget from tile C to tile A, then key 2 steals the second victim.
	st.blocker_tile = blocker_orig
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	ui._refresh_ui()
	await _ui_settle(2)
	_ui_click_global(board_pos + ui._board_view.get_spot_screen_position("tile", tile_c))
	await _ui_settle(2)
	_assert(ui._board_view.get_steal_target_count() == 3, "Tile C marks all three victims")
	_ui_click_global(board_pos + ui._board_view.get_spot_screen_position("tile", tile_a))
	await _ui_settle(2)
	_assert(ui._board_view.get_steal_target_count() == 2, "Retargeting to tile A leaves two marks")
	_ui_send_key(KEY_2)
	await _ui_settle(3)
	st = s.state
	_assert(st.blocker_tile == tile_a, "Key 2 moves the Blocker onto the retargeted hex")
	_assert(int(st.last_steal.get("victim", -1)) == 2, "Key 2 steals from the second victim (Pike), got %d" % int(st.last_steal.get("victim", -1)))
	# Single victim: no marks, the steal happens on the hex click itself.
	st.blocker_tile = blocker_orig
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	ui._refresh_ui()
	await _ui_settle(2)
	_ui_click_global(board_pos + ui._board_view.get_spot_screen_position("tile", tile_b))
	await _ui_settle(3)
	st = s.state
	_assert(not bool(ui._board_view.steal_targets_showing()), "A single victim needs no on-board marks")
	_assert(st.blocker_tile == tile_b, "The single-victim hex click moves the Blocker directly")
	_assert(int(st.last_steal.get("victim", -1)) == 3, "The single victim is robbed directly")
	root.size = Vector2i(64, 64)
	_pass_section("115. On-board Steal Marks Test (rings and tags replace the chooser panel)")

func _p31_press(ctrl: Control, local: Vector2, right := false, touch := false) -> void:
	var p := root.get_screen_transform() * (ctrl.get_global_transform() * local)
	if touch:
		var ts := InputEventScreenTouch.new()
		ts.index = 0
		ts.position = p
		ts.pressed = true
		root.push_input(ts)
		var tr := InputEventScreenTouch.new()
		tr.index = 0
		tr.position = p
		tr.pressed = false
		root.push_input(tr)
		return
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	root.push_input(mv)
	var btn := MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	var pe := InputEventMouseButton.new()
	pe.button_index = btn
	pe.pressed = true
	pe.position = p
	pe.global_position = p
	root.push_input(pe)
	var re := InputEventMouseButton.new()
	re.button_index = btn
	re.pressed = false
	re.position = p
	re.global_position = p
	root.push_input(re)

func _p31_move(ctrl: Control, local: Vector2) -> void:
	var pt := root.get_screen_transform() * (ctrl.get_global_transform() * local)
	var mv := InputEventMouseMotion.new()
	mv.position = pt
	mv.global_position = pt
	root.push_input(mv)

func _p31_move_abs(layout_at: Vector2) -> void:
	var pt := root.get_screen_transform() * layout_at
	var mv := InputEventMouseMotion.new()
	mv.position = pt
	mv.global_position = pt
	root.push_input(mv)

func _p31_give_chip(ui: Node, res: int) -> CardFace:
	for c in ui._give_chip_pool:
		if c.visible and int(c.resource) == res:
			return c
	return null

func _p31_collect_faces(node: Node, out: Array[CardFace]) -> void:
	for child in node.get_children():
		if child is CardFace:
			out.append(child as CardFace)
		_p31_collect_faces(child, out)

func _p31_editor_chain(ui: Node, tag: String) -> void:
	var GRAIN: int = GameTypes.ResourceType.GRAIN
	for r in GameTypes.ALL_RESOURCES:
		ui.session.state.players[0]["hand"][r] = 2
	ui._reset_trade_counts()
	ui._refresh_ui()
	await _ui_settle(2)
	# Give side: the hand card adds one, the card body adds more, the
	# count badge removes one (at 1 the chip leaves the side).
	_ui_real_click(ui._res_card_refs[GRAIN])
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(GRAIN, 0)) == 1, "%s: the hand card still adds one" % tag)
	var chip := _p31_give_chip(ui, GRAIN)
	_assert(chip != null and chip.count_clickable, "%s: the visible give chip is badge-clickable" % tag)
	if chip == null:
		return
	_ui_real_click(chip)
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(GRAIN, 0)) == 2, "%s: give body press adds one" % tag)
	var chipb := _p31_give_chip(ui, GRAIN)
	if chipb == null:
		_assert(false, "%s: the give chip is still visible after the body press" % tag)
		return
	_ui_real_click(chipb)
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(GRAIN, 0)) == 2, "%s: give body press stops at the hand's count" % tag)
	_p31_press(chipb, chipb.count_hit_rect().get_center())
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(GRAIN, 0)) == 1, "%s: give badge press removes one" % tag)
	await _ui_settle(1)
	var chip2 := _p31_give_chip(ui, GRAIN)
	if chip2 == null:
		_assert(false, "%s: the give chip is still visible before the last badge press" % tag)
		return
	_p31_press(chip2, chip2.count_hit_rect().get_center())
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(GRAIN, 0)) == 0, "%s: the second give badge press takes the card off the side" % tag)
	# Get side: body adds, badge removes to 0 and body adds again.
	var gf: CardFace = ui._trade_get_faces[GRAIN]
	_assert(gf.count_clickable, "%s: the get face is badge-clickable" % tag)
	_p31_press(gf, gf.size * 0.5)
	await _ui_settle(2)
	_p31_press(gf, gf.size * 0.5)
	await _ui_settle(2)
	_assert(int(ui._trade_get_counts.get(GRAIN, 0)) == 2, "%s: two get body presses ask for two" % tag)
	_p31_press(gf, gf.count_hit_rect().get_center())
	await _ui_settle(2)
	_assert(int(ui._trade_get_counts.get(GRAIN, 0)) == 1, "%s: get badge press removes one" % tag)
	_p31_press(gf, gf.count_hit_rect().get_center())
	await _ui_settle(2)
	_assert(int(ui._trade_get_counts.get(GRAIN, 0)) == 0, "%s: the second get badge press clears it" % tag)
	_p31_press(gf, gf.size * 0.5)
	await _ui_settle(2)
	_assert(int(ui._trade_get_counts.get(GRAIN, 0)) == 1, "%s: a get body press after 0 asks for one" % tag)
	# Right click removes one on BOTH sides.
	var chip3 := _p31_give_chip(ui, GRAIN)
	if chip3 == null:
		_ui_real_click(ui._res_card_refs[GRAIN])
		await _ui_settle(2)
		chip3 = _p31_give_chip(ui, GRAIN)
	_p31_press(chip3, chip3.size * 0.5, true)
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(GRAIN, 0)) == 0, "%s: right-click removes one on the give side" % tag)
	var gf2: CardFace = ui._trade_get_faces[GRAIN]
	_p31_press(gf2, gf2.size * 0.5, true)
	await _ui_settle(2)
	_assert(int(ui._trade_get_counts.get(GRAIN, 0)) == 0, "%s: right-click removes one on the get side" % tag)
	# A touch press on the badge removes one (then wait past the touch-echo guard).
	var gf3: CardFace = ui._trade_get_faces[GRAIN]
	_p31_press(gf3, gf3.size * 0.5)
	await _ui_settle(2)
	_p31_press(gf3, gf3.count_hit_rect().get_center(), false, true)
	await _ui_settle(30)
	_assert(int(ui._trade_get_counts.get(GRAIN, 0)) == 0, "%s: a touch press on the badge removes one" % tag)

func _test_count_badge_remove_body(ui: Node) -> void:
	_use_real_frame_rate()
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(31501, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the badge remove test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	for r in GameTypes.ALL_RESOURCES:
		st.players[0]["hand"][r] = 2
	ui._set_tray_panel_visible(true)
	await _ui_settle(3)
	_assert(bool(ui._trade_rows_col.visible), "The human's offer draft editor is open")
	await _p31_editor_chain(ui, "own draft")
	# The badge hit area: at least 24x24, inside the card, no more than a
	# quarter of its area, and it must contain the drawn badge circle.
	for res in GameTypes.ALL_RESOURCES:
		var gf: CardFace = ui._trade_get_faces[res]
		var hit := gf.count_hit_rect()
		_assert(hit.size.x >= 24.0 and hit.size.y >= 24.0, "badge hit area is at least 24x24 (%s)" % str(hit.size))
		_assert(hit.position.x >= -0.01 and hit.position.y >= -0.01 and hit.end.x <= gf.size.x + 0.05 and hit.end.y <= gf.size.y + 0.05, "badge hit area stays inside the card (%s in %s)" % [str(hit), str(gf.size)])
		_assert(hit.get_area() <= gf.size.x * gf.size.y * 0.25 + 0.5, "badge hit area covers no more than the card's quarter (%.0f of %.0f)" % [hit.get_area(), gf.size.x * gf.size.y * 0.25])
		_assert(hit.encloses(gf.count_badge_rect().grow(-0.5)), "badge hit area contains the drawn badge circle")
	# A real mouse-exited motion must clear the red "minus" hover state.
	var hgf: CardFace = ui._trade_get_faces[GameTypes.ResourceType.GRAIN]
	if int(ui._trade_get_counts.get(GameTypes.ResourceType.GRAIN, 0)) <= 0:
		_p31_press(hgf, hgf.size * 0.5)
		await _ui_settle(2)
	_p31_move(hgf, hgf.count_hit_rect().get_center())
	await _ui_settle(1)
	_assert(bool(hgf._hover_count), "motion onto the badge sets the minus hover")
	_p31_move_abs(Vector2(300, 250))
	await _ui_settle(2)
	_assert(not bool(hgf._hover_count), "a motion far outside the card clears the minus hover")
	# (a) A bot offers, Pike counters, Riven declines: the human answering
	# sees the counter in a watcher row; those cards are read-only.
	var TIMBER: int = GameTypes.ResourceType.TIMBER
	var GRAIN: int = GameTypes.ResourceType.GRAIN
	ui._reset_trade_counts()
	for r in GameTypes.ALL_RESOURCES:
		st.players[2]["hand"][r] = 4
	s.submit_action(0, GameAction.end_turn())
	st = s.state
	var guard2 := 0
	while guard2 < 200:
		guard2 += 1
		if s.get_acting_player_id() == 1 and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty():
			break
		if s.is_ai_to_act():
			s.step_ai()
		else:
			s.submit_action(s.get_acting_player_id(), BotController.choose_action(st, s.get_acting_player_id(), 2))
		await _ui_settle(1)
	st.current_player = 1
	s.submit_action(1, GameAction.open_trade({GRAIN: 1}, {TIMBER: 1}))
	for r in GameTypes.ALL_RESOURCES:
		st.players[2]["hand"][r] = 4
	s.submit_action(2, GameAction.respond_open_trade("counter", {GRAIN: 2}, {TIMBER: 3, GameTypes.ResourceType.CLAY: 1}))
	s.submit_action(3, GameAction.respond_open_trade("decline"))
	ui._set_tray_panel_visible(true)
	ui._refresh_ui()
	await _ui_settle(3)
	_assert(bool(ui._trade_respond_view.visible), "The respond view is shown")
	var ro_faces: Array[CardFace] = []
	_p31_collect_faces(ui._trade_respond_view, ro_faces)
	_p31_collect_faces(ui._watch_rows_col, ro_faces)
	var seen_badge := false
	for f in ro_faces:
		_assert(not f.count_clickable, "read-only cards in the respond view are not badge-clickable")
		if f.visible and f.count > 0:
			seen_badge = true
	_assert(seen_badge, "the watcher counter row shows mini cards with counts")
	var give_before: Dictionary = ui._trade_give_counts.duplicate()
	var get_before: Dictionary = ui._trade_get_counts.duplicate()
	for f in ro_faces:
		if f.visible and f.count > 0:
			_p31_press(f, f.count_hit_rect().get_center())
			await _ui_settle(2)
	_assert(ui._trade_give_counts == give_before and ui._trade_get_counts == get_before, "pressing a read-only badge changes no draft counts")
	# Hand and bank cards keep their old behaviour: no badge rule, flag off.
	var hc: CardFace = ui._res_card_refs[GRAIN]
	_assert(not hc.count_clickable, "hand cards are not badge-clickable")
	var bf: CardFace = ui._bank_faces[GRAIN]
	_assert(not bf.count_clickable, "bank cards are not badge-clickable")
	var give_pre := int(ui._trade_give_counts.get(GRAIN, 0))
	_p31_press(bf, bf.count_badge_rect().get_center())
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(GRAIN, 0)) == give_pre, "a bank card press changes no draft count")
	# (b) The counter editor: the human presses Counter and edits.
	_ui_real_click(ui._ot_counter_btn)
	await _ui_settle(3)
	_assert(bool(ui._trade_rows_col.visible), "The counter editor shows the draft rows")
	await _p31_editor_chain(ui, "counter editor")
	if ui._ot_decline_btn.visible and not ui._ot_decline_btn.disabled:
		_ui_real_click(ui._ot_decline_btn)
		await _ui_settle(2)
	root.size = Vector2i(64, 64)
	_pass_section("126. Count Badge Remove Test (tap the count to remove one in every trade editor)")

func _test_palette_styles() -> void:
	var script: GDScript = load("res://scripts/palette.gd")
	var paper: Dictionary = Palette.STYLES["paper"]
	var dark: Dictionary = Palette.STYLES["dark"]
	var paper_keys: Array = paper.keys()
	paper_keys.sort()
	var dark_keys: Array = dark.keys()
	dark_keys.sort()
	_assert(Palette.current_style == "paper", "the palette starts on the paper style")
	_assert(
		Palette.STYLE_IDS.size() == 2 and Palette.STYLE_IDS[0] == "paper" and Palette.STYLE_IDS[1] == "dark",
		"STYLE_IDS lists the paper and dark styles"
	)
	_assert(
		Palette.style_label("paper") == "Paper" and Palette.style_label("dark") == "Dark",
		"STYLE_LABELS names both styles"
	)
	var option_key_sets: Array = []
	for option_id in Palette.STYLE_IDS:
		_assert(Palette.STYLE_OPTIONS.has(option_id), "STYLE_OPTIONS has an entry for the %s style" % option_id)
		var opt_keys: Array = (Palette.STYLE_OPTIONS[option_id] as Dictionary).keys()
		opt_keys.sort()
		option_key_sets.append(opt_keys)
	var same_option_keys := true
	for opt_set in option_key_sets:
		if opt_set != option_key_sets[0]:
			same_option_keys = false
	_assert(same_option_keys, "every STYLE_OPTIONS entry has exactly the same keys")
	for icon_id in Palette.STYLE_IDS:
		_assert((Palette.STYLE_OPTIONS[icon_id] as Dictionary).has("icon"), "STYLE_OPTIONS gives the %s style a switcher icon" % icon_id)
	_assert(String(Palette.style_option("icon", "sun")) == "sun", "paper names the sun icon")
	_assert(Palette.style_option("custom_check_icons", false) == true, "style_option reads the paper style")
	_assert(Palette.style_option("unknown_option_name", "fb") == "fb", "style_option falls back for an unknown name")
	Palette.apply_style("dark")
	_assert(Palette.style_option("custom_check_icons", false) == true, "style_option reads the dark style")
	_assert(float(Palette.style_option("toast_text_min_contrast", 0.0)) == 4.5, "dark asks for 4.5:1 toast text")
	_assert(String(Palette.style_option("icon", "sun")) == "moon", "dark names the moon icon")
	Palette.apply_style("paper")
	_assert(float(Palette.style_option("toast_text_min_contrast", 0.0)) == 4.5, "paper asks for 4.5:1 toast text too")
	_assert(paper.size() == 112, "the paper style covers every colour variable (%d keys)" % paper.size())
	_assert(paper_keys == dark_keys, "the paper and dark styles cover exactly the same keys")
	var originals := {
		"TEXT": Color(0.29, 0.22, 0.17),
		"PANEL_BG": Color(0.97, 0.93, 0.83),
		"SEA": Color(0.52, 0.75, 0.80),
		"HEADING": Color(0.20, 0.42, 0.40),
		"TOAST_BG": Color(0.20, 0.42, 0.40, 0.92),
		"FOREST": Color(0.36, 0.55, 0.36),
		"NUMBER_TOKEN_BG": Color(0.96, 0.92, 0.82),
		"INK_SOFT": Color(0.29, 0.22, 0.17, 0.45),
	}
	for original_key in originals:
		var ok := String(original_key)
		_assert((script.get(ok) as Color).to_rgba32() == (originals[original_key] as Color).to_rgba32(), "paper keeps the original %s colour" % ok)
	for paper_key in paper_keys:
		var pk := String(paper_key)
		_assert(script.get(pk) == paper[pk], "the live paper colour %s matches STYLES" % pk)
	var readable_overrides := {
		"TOAST_PILL_BG": "PANEL_BG_ALT",
		"CHIP_PILL_BG": "PAPER",
		"DICE_PILL_BG": "PAPER_DARK",
		"CHECK_UNCHECKED_BG": "PAPER",
		"CHECK_BORDER": "PANEL_BORDER",
		"HELP_HEADING": "PANEL_BORDER",
		"LOG_ERROR_TEXT": "PANEL_BORDER",
	}
	for readable_key in readable_overrides:
		var rk := String(readable_key)
		_assert(
			(rk == "HELP_HEADING" or rk == "LOG_ERROR_TEXT") or (script.get(rk) as Color).to_rgba32() == (script.get(readable_overrides[rk]) as Color).to_rgba32(),
			"%s keeps today's paper pixels (nudge of %s)" % [rk, String(readable_overrides[rk])]
		)
	_assert(
		_contrast_ratio(Palette.TEXT, Palette.PANEL_BG) >= 7.0,
		"paper text on panel clears 7:1 (%.2f)" % _contrast_ratio(Palette.TEXT, Palette.PANEL_BG)
	)
	_assert(
		_contrast_ratio(Palette.TEXT_MUTED, Palette.PANEL_BG) >= 4.5,
		"paper muted text on panel clears 4.5:1 (%.2f)" % _contrast_ratio(Palette.TEXT_MUTED, Palette.PANEL_BG)
	)
	_assert(
		_contrast_ratio(Palette.TEXT_MUTED, Palette.PANEL_BG_ALT) >= 4.5,
		"paper muted text on the alt panel clears 4.5:1 (%.2f)" % _contrast_ratio(Palette.TEXT_MUTED, Palette.PANEL_BG_ALT)
	)
	_assert(
		_contrast_ratio(Palette.BUTTON_TEXT, Palette.BUTTON_BG) >= 7.0,
		"paper button text clears 7:1 (%.2f)" % _contrast_ratio(Palette.BUTTON_TEXT, Palette.BUTTON_BG)
	)
	_assert(
		_contrast_ratio(Palette.HEADING, Palette.PANEL_BG) >= 4.5,
		"paper heading on panel clears 4.5:1 (%.2f)" % _contrast_ratio(Palette.HEADING, Palette.PANEL_BG)
	)
	_assert(
		_contrast_ratio(Palette.NUMBER_TOKEN_TEXT, Palette.NUMBER_TOKEN_BG) >= 7.0,
		"paper token number clears 7:1 (%.2f)" % _contrast_ratio(Palette.NUMBER_TOKEN_TEXT, Palette.NUMBER_TOKEN_BG)
	)
	_assert(
		_contrast_ratio(Palette.TOAST_TEXT, Palette.TOAST_BG) >= 4.5,
		"paper toast text clears 4.5:1 (%.2f)" % _contrast_ratio(Palette.TOAST_TEXT, Palette.TOAST_BG)
	)
	Palette.apply_style("dark")
	_assert(Palette.current_style == "dark", "apply_style switches to the dark style")
	_assert(Palette.TEXT == Color(0.90, 0.89, 0.85), "dark text reads through a direct Palette access")
	_assert(Palette.PANEL_BG == Color(0.15, 0.16, 0.19), "dark panel reads through a direct Palette access")
	for dark_key in dark_keys:
		var dk := String(dark_key)
		_assert(script.get(dk) == dark[dk], "the live dark colour %s matches STYLES" % dk)
	for tint in ["TOAST_STEAL_BAD", "TOAST_STEAL_GOOD", "TOAST_NEUTRAL", "TOAST_WARN_BG", "TOAST_TRADE_BG", "TOAST_COUNTER_BG", "TOAST_BG"]:
		var tk := String(tint)
		_assert(
			_contrast_ratio(dark[tk], dark["TOAST_PILL_BG"]) >= 7.0,
			"dark toast tint %s on the toast pill clears 7:1 (%.2f)" % [tk, _contrast_ratio(dark[tk], dark["TOAST_PILL_BG"])]
		)
	_assert(
		_contrast_ratio(dark["INK"], dark["CHIP_PILL_BG"]) >= 7.0,
		"dark chip text clears 7:1 on the port chip (%.2f)" % _contrast_ratio(dark["INK"], dark["CHIP_PILL_BG"])
	)
	_assert(
		_contrast_ratio(dark["NUMBER_TOKEN_TEXT"], dark["DICE_PILL_BG"]) >= 7.0,
		"dark dice total clears 7:1 on the dice pill (%.2f)" % _contrast_ratio(dark["NUMBER_TOKEN_TEXT"], dark["DICE_PILL_BG"])
	)
	_assert(
		_contrast_ratio(dark["CHECK_BORDER"], dark["PANEL_BG"]) >= 3.0,
		"dark checkbox border clears 3:1 on the settings panel (%.2f)" % _contrast_ratio(dark["CHECK_BORDER"], dark["PANEL_BG"])
	)
	_assert(
		_contrast_ratio(dark["CHECK_BORDER"], dark["PANEL_BG_ALT"]) >= 3.0,
		"dark checkbox border clears 3:1 on the alt panel (%.2f)" % _contrast_ratio(dark["CHECK_BORDER"], dark["PANEL_BG_ALT"])
	)
	_assert(
		_contrast_ratio(dark["HELP_HEADING"], dark["PANEL_BG"]) >= 4.5,
		"dark help heading clears 4.5:1 on the help panel (%.2f)" % _contrast_ratio(dark["HELP_HEADING"], dark["PANEL_BG"])
	)
	_assert(
		_contrast_ratio(dark["LOG_ERROR_TEXT"], dark["PANEL_BG"]) >= 4.5,
		"dark log error text clears 4.5:1 on the log panel (%.2f)" % _contrast_ratio(dark["LOG_ERROR_TEXT"], dark["PANEL_BG"])
	)
	_assert(
		_contrast_ratio(dark["BUTTON_TEXT_ON_GREEN"], dark["ACCENT_GREEN"]) >= 4.5,
		"dark End Turn text clears 4.5:1 on the green (%.2f)" % _contrast_ratio(dark["BUTTON_TEXT_ON_GREEN"], dark["ACCENT_GREEN"])
	)
	_assert(
		_contrast_ratio(paper["TEXT"], paper["AWARD_HIGHLIGHT_BG"]) >= 7.0,
		"paper award count clears 7:1 on the highlight box (%.2f)" % _contrast_ratio(paper["TEXT"], paper["AWARD_HIGHLIGHT_BG"])
	)
	_assert(
		_contrast_ratio(paper["ACCENT_GOLD"], paper["AWARD_HIGHLIGHT_BG"]) >= 1.5,
		"paper gold border still shows on the highlight box (%.2f)" % _contrast_ratio(paper["ACCENT_GOLD"], paper["AWARD_HIGHLIGHT_BG"])
	)
	_assert(
		_contrast_ratio(dark["TEXT"], dark["AWARD_HIGHLIGHT_BG"]) >= 7.0,
		"dark award count clears 7:1 on the highlight box (%.2f)" % _contrast_ratio(dark["TEXT"], dark["AWARD_HIGHLIGHT_BG"])
	)
	_assert(
		_contrast_ratio(dark["ACCENT_GOLD"], dark["AWARD_HIGHLIGHT_BG"]) >= 1.5,
		"dark gold border still shows on the highlight box (%.2f)" % _contrast_ratio(dark["ACCENT_GOLD"], dark["AWARD_HIGHLIGHT_BG"])
	)
	_assert(Palette.terrain(GameTypes.TerrainType.FOREST) == dark["FOREST"], "terrain() follows the dark style")
	_assert(
		Palette.terrain_shade(GameTypes.TerrainType.FOREST) == dark["FOREST_SHADE"],
		"terrain_shade() follows the dark style"
	)
	_assert(
		Palette.terrain_light(GameTypes.TerrainType.FOREST) == dark["FOREST_LIGHT"],
		"terrain_light() follows the dark style"
	)
	var resource_keys := {
		GameTypes.ResourceType.TIMBER: "RES_TIMBER",
		GameTypes.ResourceType.CLAY: "RES_CLAY",
		GameTypes.ResourceType.FLEECE: "RES_FLEECE",
		GameTypes.ResourceType.GRAIN: "RES_GRAIN",
		GameTypes.ResourceType.IRON: "RES_IRON",
	}
	for resource_type in resource_keys:
		var rk := String(resource_keys[resource_type])
		_assert(Palette.resource(int(resource_type)) == dark[rk], "resource() follows the dark style for %s" % rk)
	_assert(
		_contrast_ratio(Palette.TEXT, Palette.PANEL_BG) >= 7.0,
		"dark text on panel clears 7:1 (%.2f)" % _contrast_ratio(Palette.TEXT, Palette.PANEL_BG)
	)
	_assert(
		_contrast_ratio(Palette.TEXT_MUTED, Palette.PANEL_BG) >= 4.5,
		"dark muted text on panel clears 4.5:1 (%.2f)" % _contrast_ratio(Palette.TEXT_MUTED, Palette.PANEL_BG)
	)
	_assert(
		_contrast_ratio(Palette.TEXT_MUTED, Palette.PANEL_BG_ALT) >= 4.5,
		"dark muted text on the alt panel clears 4.5:1 (%.2f)" % _contrast_ratio(Palette.TEXT_MUTED, Palette.PANEL_BG_ALT)
	)
	_assert(
		_contrast_ratio(Palette.BUTTON_TEXT, Palette.BUTTON_BG) >= 7.0,
		"dark button text clears 7:1 (%.2f)" % _contrast_ratio(Palette.BUTTON_TEXT, Palette.BUTTON_BG)
	)
	_assert(
		_contrast_ratio(Palette.HEADING, Palette.PANEL_BG) >= 4.5,
		"dark heading on panel clears 4.5:1 (%.2f)" % _contrast_ratio(Palette.HEADING, Palette.PANEL_BG)
	)
	_assert(
		_contrast_ratio(Palette.NUMBER_TOKEN_TEXT, Palette.NUMBER_TOKEN_BG) >= 7.0,
		"dark token number clears 7:1 (%.2f)" % _contrast_ratio(Palette.NUMBER_TOKEN_TEXT, Palette.NUMBER_TOKEN_BG)
	)
	_assert(
		_contrast_ratio(Palette.TOAST_TEXT, Palette.TOAST_BG) >= 4.5,
		"dark toast text clears 4.5:1 (%.2f)" % _contrast_ratio(Palette.TOAST_TEXT, Palette.TOAST_BG)
	)
	Palette.apply_style("no-such-style")
	_assert(Palette.current_style == "paper", "an unknown style falls back to paper")
	_assert(
		(Palette.TEXT as Color).to_rgba32() == Color(0.29, 0.22, 0.17).to_rgba32(),
		"the fallback restores the paper text colour"
	)
	for fallback_key in paper_keys:
		var fk := String(fallback_key)
		_assert(script.get(fk) == paper[fk], "the fallback restores the live colour %s" % fk)
	_assert(Palette.next_style("paper") == "dark", "next_style cycles paper to dark")
	_assert(Palette.next_style("dark") == "paper", "next_style cycles dark to paper")
	Palette.apply_style("paper")
	_assert(Palette.current_style == "paper", "the palette is left on the paper style for every later test")
	_traceable_style_checks(script, paper_keys)
	_pass_section("127. Palette Style Test (data styles, by-name apply, fallback, contrast)")

func _traceable_style_checks(script: GDScript, colour_keys: Array) -> void:
	var paper_originals := {
		"SKY_TOP": Color(0.80, 0.90, 0.92),
		"SEA": Color(0.52, 0.75, 0.80),
		"SEA_DEEP": Color(0.38, 0.63, 0.72),
		"SEA_FOAM": Color(0.93, 0.97, 0.95, 0.85),
		"CLOUD": Color(1.0, 0.99, 0.95, 0.55),
		"INK": Color(0.29, 0.22, 0.17),
		"INK_SOFT": Color(0.29, 0.22, 0.17, 0.45),
		"PAPER": Color(0.97, 0.93, 0.83),
		"PAPER_DARK": Color(0.91, 0.85, 0.72),
		"PAPER_SHADOW": Color(0.25, 0.18, 0.12, 0.22),
		"FOREST": Color(0.36, 0.55, 0.36),
		"FOREST_SHADE": Color(0.27, 0.44, 0.29),
		"FOREST_LIGHT": Color(0.48, 0.66, 0.45),
		"PASTURE": Color(0.66, 0.80, 0.47),
		"PASTURE_SHADE": Color(0.54, 0.70, 0.38),
		"PASTURE_LIGHT": Color(0.78, 0.88, 0.60),
		"FIELD": Color(0.94, 0.81, 0.45),
		"FIELD_SHADE": Color(0.83, 0.68, 0.35),
		"FIELD_LIGHT": Color(0.98, 0.90, 0.63),
		"CLAY": Color(0.82, 0.53, 0.39),
		"CLAY_SHADE": Color(0.70, 0.42, 0.30),
		"CLAY_LIGHT": Color(0.90, 0.66, 0.52),
		"MOUNTAIN": Color(0.58, 0.62, 0.69),
		"MOUNTAIN_SHADE": Color(0.46, 0.50, 0.58),
		"MOUNTAIN_LIGHT": Color(0.70, 0.74, 0.80),
		"BARREN": Color(0.89, 0.81, 0.64),
		"BARREN_SHADE": Color(0.79, 0.70, 0.53),
		"BARREN_LIGHT": Color(0.95, 0.90, 0.76),
		"RES_TIMBER": Color(0.45, 0.58, 0.32),
		"RES_CLAY": Color(0.80, 0.48, 0.35),
		"RES_FLEECE": Color(0.95, 0.91, 0.82),
		"RES_GRAIN": Color(0.93, 0.75, 0.35),
		"RES_IRON": Color(0.55, 0.60, 0.66),
		"PANEL_BG": Color(0.97, 0.93, 0.83),
		"PANEL_BG_ALT": Color(0.94, 0.89, 0.77),
		"PANEL_BORDER": Color(0.55, 0.42, 0.30),
		"TEXT": Color(0.29, 0.22, 0.17),
		"TEXT_MUTED": Color(0.45, 0.38, 0.30),
		"TEXT_ON_DARK": Color(0.97, 0.93, 0.83),
		"HEADING": Color(0.20, 0.42, 0.40),
		"ACCENT_GOLD": Color(0.90, 0.68, 0.26),
		"ACCENT_RED": Color(0.80, 0.37, 0.31),
		"ACCENT_GREEN": Color(0.42, 0.66, 0.40),
		"BUTTON_BG": Color(0.90, 0.83, 0.68),
		"BUTTON_BG_HOVER": Color(0.86, 0.78, 0.60),
		"BUTTON_BG_PRESSED": Color(0.83, 0.75, 0.60),
		"BUTTON_BG_DISABLED": Color(0.9400, 0.9050, 0.8150),
		"BUTTON_TEXT": Color(0.29, 0.22, 0.17),
		"TOAST_BG": Color(0.20, 0.42, 0.40, 0.92),
		"TOAST_TEXT": Color(0.97, 0.93, 0.83),
		"HIGHLIGHT": Color(0.98, 0.84, 0.45, 0.55),
		"HIGHLIGHT_INVALID": Color(0.80, 0.37, 0.31, 0.55),
		"NUMBER_TOKEN_BG": Color(0.96, 0.92, 0.82),
		"NUMBER_TOKEN_TEXT": Color(0.29, 0.22, 0.17),
		"NUMBER_TOKEN_HOT": Color(0.6200, 0.1500, 0.1000),
		"BLOCKER": Color(0.32, 0.27, 0.23),
		"DOCK_WOOD": Color(0.60, 0.45, 0.30),
		"DICE_FACE": Color(0.97, 0.94, 0.86),
		"DICE_PIP": Color(0.29, 0.22, 0.17),
	}
	var dark_originals := {
		"SKY_TOP": Color(0.10, 0.14, 0.20),
		"SEA": Color(0.13, 0.24, 0.32),
		"SEA_DEEP": Color(0.09, 0.18, 0.26),
		"SEA_FOAM": Color(0.70, 0.82, 0.86, 0.45),
		"CLOUD": Color(0.75, 0.80, 0.90, 0.18),
		"INK": Color(0.12, 0.10, 0.09),
		"INK_SOFT": Color(0.12, 0.10, 0.09, 0.45),
		"PAPER": Color(0.17, 0.18, 0.21),
		"PAPER_DARK": Color(0.23, 0.24, 0.28),
		"PAPER_SHADOW": Color(0.00, 0.00, 0.00, 0.40),
		"FOREST": Color(0.27, 0.41, 0.27),
		"FOREST_SHADE": Color(0.20, 0.33, 0.21),
		"FOREST_LIGHT": Color(0.36, 0.49, 0.33),
		"PASTURE": Color(0.49, 0.59, 0.35),
		"PASTURE_SHADE": Color(0.40, 0.52, 0.28),
		"PASTURE_LIGHT": Color(0.58, 0.65, 0.44),
		"FIELD": Color(0.70, 0.60, 0.33),
		"FIELD_SHADE": Color(0.61, 0.50, 0.26),
		"FIELD_LIGHT": Color(0.73, 0.67, 0.47),
		"CLAY": Color(0.61, 0.39, 0.29),
		"CLAY_SHADE": Color(0.52, 0.31, 0.22),
		"CLAY_LIGHT": Color(0.67, 0.49, 0.38),
		"MOUNTAIN": Color(0.43, 0.46, 0.51),
		"MOUNTAIN_SHADE": Color(0.34, 0.37, 0.43),
		"MOUNTAIN_LIGHT": Color(0.52, 0.55, 0.59),
		"BARREN": Color(0.66, 0.60, 0.47),
		"BARREN_SHADE": Color(0.58, 0.52, 0.39),
		"BARREN_LIGHT": Color(0.70, 0.67, 0.56),
		"RES_TIMBER": Color(0.45, 0.58, 0.32),
		"RES_CLAY": Color(0.80, 0.48, 0.35),
		"RES_FLEECE": Color(0.88, 0.85, 0.77),
		"RES_GRAIN": Color(0.93, 0.75, 0.35),
		"RES_IRON": Color(0.55, 0.60, 0.66),
		"PANEL_BG": Color(0.15, 0.16, 0.19),
		"PANEL_BG_ALT": Color(0.19, 0.20, 0.24),
		"PANEL_BORDER": Color(0.4700, 0.4900, 0.5700),
		"TEXT": Color(0.90, 0.89, 0.85),
		"TEXT_MUTED": Color(0.66, 0.66, 0.67),
		"TEXT_ON_DARK": Color(0.95, 0.93, 0.86),
		"HEADING": Color(0.45, 0.78, 0.74),
		"ACCENT_GOLD": Color(0.92, 0.72, 0.32),
		"ACCENT_RED": Color(0.90, 0.48, 0.42),
		"ACCENT_GREEN": Color(0.50, 0.76, 0.48),
		"BUTTON_BG": Color(0.25, 0.27, 0.32),
		"BUTTON_BG_HOVER": Color(0.31, 0.33, 0.39),
		"BUTTON_BG_PRESSED": Color(0.20, 0.21, 0.26),
		"BUTTON_BG_DISABLED": Color(0.19, 0.20, 0.23),
		"BUTTON_TEXT": Color(0.92, 0.91, 0.87),
		"TOAST_BG": Color(0.10, 0.26, 0.26, 0.95),
		"TOAST_TEXT": Color(0.95, 0.93, 0.86),
		"HIGHLIGHT": Color(0.98, 0.84, 0.45, 0.55),
		"HIGHLIGHT_INVALID": Color(0.80, 0.37, 0.31, 0.55),
		"NUMBER_TOKEN_BG": Color(0.86, 0.82, 0.72),
		"NUMBER_TOKEN_TEXT": Color(0.16, 0.12, 0.10),
		"NUMBER_TOKEN_HOT": Color(0.5500, 0.1200, 0.0900),
		"BLOCKER": Color(0.32, 0.27, 0.23),
		"DOCK_WOOD": Color(0.48, 0.36, 0.24),
		"DICE_FACE": Color(0.90, 0.87, 0.80),
		"DICE_PIP": Color(0.16, 0.12, 0.10),
	}
	for paper_original_key in paper_originals:
		var pok := String(paper_original_key)
		_assert(
			(script.get(pok) as Color).to_rgba32() == (paper_originals[paper_original_key] as Color).to_rgba32(),
			"the paper nudge left %s on the same 8-bit colour as the original constant" % pok
		)
	for dark_original_key in dark_originals:
		var dok := String(dark_original_key)
		_assert(
			(Palette.STYLES["dark"][dok] as Color).to_rgba32() == (dark_originals[dark_original_key] as Color).to_rgba32(),
			"the dark nudge left %s on the same 8-bit colour as the style brief" % dok
		)
	for style_id in Palette.STYLE_IDS:
		var seen_rgb := {}
		var doubled := ""
		for own_key in colour_keys:
			var own := String(own_key)
			var own_rgb := Palette.rgb_key(Palette.STYLES[style_id][own])
			if seen_rgb.has(own_rgb):
				doubled += "%s=%s/%s " % [own_rgb, String(seen_rgb[own_rgb]), own]
			else:
				seen_rgb[own_rgb] = own
		_assert(doubled == "", "style %s gives every colour its own rgb key (%s)" % [style_id, doubled])
	for from_id in Palette.STYLE_IDS:
		for to_id in Palette.STYLE_IDS:
			if from_id == to_id:
				continue
			var groups := {}
			for group_key in colour_keys:
				var gk := String(group_key)
				var grp_rgb := Palette.rgb_key(Palette.STYLES[from_id][gk])
				if not groups.has(grp_rgb):
					groups[grp_rgb] = []
				groups[grp_rgb].append(gk)
			var ambiguous := ""
			for rgb_group in groups:
				var members: Array = groups[rgb_group]
				if members.size() < 2:
					continue
				var shared := Palette.rgb_key(Palette.STYLES[to_id][members[0]])
				for member in members:
					if Palette.rgb_key(Palette.STYLES[to_id][member]) != shared:
						ambiguous += "%s " % String(member)
			_assert(ambiguous == "", "style %s -> %s needs no alpha guessing (%s)" % [from_id, to_id, ambiguous])
	var to_dark := Palette.remap_table("paper", "dark")
	var to_paper := Palette.remap_table("dark", "paper")
	_assert(Palette.remap(Palette.STYLES["paper"]["TEXT"], to_dark) == Palette.STYLES["dark"]["TEXT"], "remap turns paper TEXT into dark TEXT")
	var ink_paper: Color = Palette.STYLES["paper"]["INK"]
	var ink_dark: Color = Palette.STYLES["dark"]["INK"]
	var faded_ink := Color(ink_paper.r, ink_paper.g, ink_paper.b, 0.62)
	var faded_result := Palette.remap(faded_ink, to_dark)
	_assert(
		faded_result.a == faded_ink.a and Color(faded_result.r, faded_result.g, faded_result.b, 1.0) == Color(ink_dark.r, ink_dark.g, ink_dark.b, 1.0),
		"remap keeps a hand-set alpha and takes the dark rgb"
	)
	var outside := Color(0.123, 0.456, 0.789)
	_assert(Palette.remap(outside, to_dark) == outside, "a colour outside the palette is returned unchanged")
	var round_trip := ""
	for rt_key in colour_keys:
		var rk := String(rt_key)
		var start: Color = Palette.STYLES["paper"][rk]
		var back := Palette.remap(Palette.remap(start, to_dark), to_paper)
		if back != start:
			round_trip += rk + " "
	_assert(round_trip == "", "paper -> dark -> paper returns every colour unchanged (%s)" % round_trip)
	var banned: Array[Color] = [Color(1, 1, 1), Color(0, 0, 0), Color(0, 0, 0, 0)]
	for player_color in GameTypes.PLAYER_COLORS:
		banned.append(player_color)
	var clashes := ""
	for clash_style in Palette.STYLE_IDS:
		for clash_key in colour_keys:
			var clash_rgb := Palette.rgb_key(Palette.STYLES[clash_style][clash_key])
			for banned_color in banned:
				if clash_rgb == Palette.rgb_key(banned_color):
					clashes += "%s/%s " % [clash_style, String(clash_key)]
	_assert(clashes == "", "no palette colour shares an rgb key with black, white or a player colour (%s)" % clashes)


func _wcag_channel(value: float) -> float:
	if value <= 0.03928:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)

func _wcag_luminance(color: Color) -> float:
	return 0.2126 * _wcag_channel(color.r) + 0.7152 * _wcag_channel(color.g) + 0.0722 * _wcag_channel(color.b)

func _contrast_ratio(a: Color, b: Color) -> float:
	var lum_a := _wcag_luminance(a)
	var lum_b := _wcag_luminance(b)
	return (maxf(lum_a, lum_b) + 0.05) / (minf(lum_a, lum_b) + 0.05)

func _test_palette_restyle_tree() -> void:
	var root := Control.new()
	root.name = "RestyleTree"
	var panel := PanelContainer.new()
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Palette.PANEL_BG
	panel_box.border_color = Palette.PANEL_BORDER
	panel.add_theme_stylebox_override("panel", panel_box)
	root.add_child(panel)
	var label := Label.new()
	label.add_theme_color_override("font_color", Color(Palette.TEXT))
	panel.add_child(label)
	var button := Button.new()
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Palette.BUTTON_BG
	var hover_box := StyleBoxFlat.new()
	hover_box.bg_color = Palette.BUTTON_BG_HOVER
	button.add_theme_stylebox_override("normal", normal_box)
	button.add_theme_stylebox_override("hover", hover_box)
	panel.add_child(button)
	var shared_box := StyleBoxFlat.new()
	shared_box.bg_color = Palette.PANEL_BG_ALT
	var first_label := Label.new()
	first_label.add_theme_stylebox_override("normal", shared_box)
	var second_label := Label.new()
	second_label.add_theme_stylebox_override("normal", shared_box)
	panel.add_child(first_label)
	panel.add_child(second_label)
	var rect := ColorRect.new()
	rect.color = Color(Palette.INK, 0.62)
	panel.add_child(rect)
	var player_label := Label.new()
	player_label.add_theme_color_override("font_color", GameTypes.PLAYER_COLORS[1])
	panel.add_child(player_label)
	var option := OptionButton.new()
	option.add_item("one")
	panel.add_child(option)
	var popup: PopupMenu = null
	var popup_box := StyleBoxFlat.new()
	popup_box.bg_color = Palette.PANEL_BG
	for internal_child in option.get_children(true):
		if internal_child is PopupMenu:
			popup = internal_child as PopupMenu
	_assert(popup != null, "an OptionButton carries an internal popup to walk into")
	if popup != null:
		popup.add_theme_stylebox_override("panel", popup_box)
	var to_dark: Dictionary = Palette.remap_table("paper", "dark")
	Palette.apply_style("dark")
	Palette.restyle_tree(root, to_dark)
	var dark: Dictionary = Palette.STYLES["dark"]
	_assert(panel_box.bg_color == dark["PANEL_BG"], "the walker restyles a panel stylebox background")
	_assert(panel_box.border_color == dark["PANEL_BORDER"], "the walker restyles a panel stylebox border")
	_assert(label.get_theme_color("font_color") == dark["TEXT"], "the walker restyles a font colour override")
	_assert(normal_box.bg_color == dark["BUTTON_BG"], "the walker restyles a button normal stylebox")
	_assert(hover_box.bg_color == dark["BUTTON_BG_HOVER"], "the walker restyles a button hover stylebox")
	_assert(shared_box.bg_color == dark["PANEL_BG_ALT"], "the walker restyles a stylebox two labels share")
	_assert(
		shared_box == first_label.get_theme_stylebox("normal") and shared_box == second_label.get_theme_stylebox("normal"),
		"the two labels still share the one stylebox after the walk"
	)
	var dark_ink: Color = dark["INK"]
	_assert(
		rect.color == Color(dark_ink.r, dark_ink.g, dark_ink.b, 0.62),
		"a ColorRect keeps its own alpha and takes the dark rgb"
	)
	_assert(player_label.get_theme_color("font_color") == GameTypes.PLAYER_COLORS[1], "a player colour is left alone")
	if popup != null:
		_assert(popup_box.bg_color == dark["PANEL_BG"], "the walker reaches the internal popup of an OptionButton")
	var step_a := Color(0.101, 0.102, 0.103)
	var step_b := Color(0.201, 0.202, 0.203)
	var step_c := Color(0.301, 0.302, 0.303)
	var chain_box := StyleBoxFlat.new()
	chain_box.bg_color = step_a
	var chain_label := Label.new()
	chain_label.add_theme_stylebox_override("normal", chain_box)
	var chain_label_two := Label.new()
	chain_label_two.add_theme_stylebox_override("normal", chain_box)
	panel.add_child(chain_label)
	panel.add_child(chain_label_two)
	var chain := {
		Palette.rgb_key(step_a): [[1.0, step_b]],
		Palette.rgb_key(step_b): [[1.0, step_c]],
	}
	Palette.restyle_tree(root, chain)
	_assert(chain_box.bg_color == step_b, "a shared stylebox is remapped once per walk, not twice")
	var to_paper: Dictionary = Palette.remap_table("dark", "paper")
	Palette.apply_style("paper")
	Palette.restyle_tree(root, to_paper)
	var paper: Dictionary = Palette.STYLES["paper"]
	_assert(panel_box.bg_color == paper["PANEL_BG"], "switching back restores the paper panel stylebox")
	_assert(label.get_theme_color("font_color") == paper["TEXT"], "switching back restores the paper font colour")
	_assert(normal_box.bg_color == paper["BUTTON_BG"], "switching back restores the paper button stylebox")
	_assert(shared_box.bg_color == paper["PANEL_BG_ALT"], "switching back restores the shared paper stylebox")
	if popup != null:
		_assert(popup_box.bg_color == paper["PANEL_BG"], "switching back restores the internal popup stylebox")
	root.free()
	Palette.apply_style("paper")
	_assert(Palette.current_style == "paper", "reached the end of the restyle walk test on the paper style")
	_pass_section("128. Palette Restyle Tree Test (theme overrides, shared styleboxes, internal children, round trip)")

func _test_ui_style_setting_body(ui: Node) -> void:
	ui.auto_ai = false
	if ui._splash_overlay != null:
		ui._splash_overlay.visible = false
	ui._splash_shown = false
	await _ui_settle(3)
	var paper: Dictionary = Palette.STYLES["paper"]
	var dark: Dictionary = Palette.STYLES["dark"]
	_assert(Palette.current_style == "paper", "the live style test starts on paper")
	_assert(String(ui._ui_style) == "paper", "a UI without a saved style is paper")
	var state_before: GameState = ui.session.state
	var turn_before := int(state_before.turn_number)
	var hand_before: Dictionary = (state_before.players[0].get("hand", {}) as Dictionary).duplicate(true)
	var header_box := ui._header_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(header_box != null and header_box.bg_color == paper["PANEL_BG"], "the header panel is built in the paper panel colour")
	var title_label: Label = null
	for head_label in ui._header_panel.find_children("*", "Label", true, false):
		if (head_label as Label).text == "Founders: Barter & Block":
			title_label = head_label as Label
			break
	_assert(title_label != null, "the title label sits in the header")
	_assert(title_label.get_theme_color("font_color") == paper["HEADING"], "the title is built in the paper heading colour")
	var plain_btn: Button = null
	for btn_node in ui.find_children("*", "Button", true, false):
		var btn_box := (btn_node as Button).get_theme_stylebox("normal") as StyleBoxFlat
		if btn_box != null and btn_box.bg_color == paper["BUTTON_BG"]:
			plain_btn = btn_node as Button
			break
	_assert(plain_btn != null, "a plain styled button is built into the UI")
	var normal_box := plain_btn.get_theme_stylebox("normal") as StyleBoxFlat
	ui.set_ui_style("dark")
	_assert(Palette.current_style == "dark", "set_ui_style switches the live palette")
	_assert(String(ui._ui_style) == "dark", "the UI records the chosen style id")
	_assert(header_box.bg_color == dark["PANEL_BG"], "the open header panel goes dark")
	_assert(title_label.get_theme_color("font_color") == dark["HEADING"], "the title label goes dark")
	_assert(normal_box.bg_color == dark["BUTTON_BG"], "the button normal stylebox goes dark")
	var cfg := ConfigFile.new()
	_assert(cfg.load(TEST_SETTINGS_PATH) == OK, "a style switch writes the settings file")
	_assert(str(cfg.get_value("settings", "ui_style", "")) == "dark", "the settings file stores the dark style")
	var state_after: GameState = ui.session.state
	_assert(state_after == state_before, "a style switch does not restart the match")
	_assert(int(state_after.turn_number) == turn_before, "a style switch leaves the turn number alone")
	_assert(str(state_after.players[0].get("hand", {})) == str(hand_before), "a style switch leaves the hand alone")
	var packed := ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	var second: Node = packed.instantiate()
	second.auto_ai = false
	root.add_child(second)
	await _ui_settle(3)
	_assert(String(second._ui_style) == "dark", "a fresh UI reads the dark style from the settings file")
	var second_header := second._header_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_assert(second_header != null and second_header.bg_color == dark["PANEL_BG"], "a fresh UI is built in the saved dark style")
	second.free()
	ui.set_ui_style("paper")
	_assert(Palette.current_style == "paper", "the style switches back to paper")
	_assert(header_box.bg_color == paper["PANEL_BG"], "the header panel is paper again")
	_assert(title_label.get_theme_color("font_color") == paper["HEADING"], "the title label is paper again")
	_assert(normal_box.bg_color == paper["BUTTON_BG"], "the button stylebox is paper again")
	var cfg2 := ConfigFile.new()
	_assert(
		cfg2.load(TEST_SETTINGS_PATH) == OK and str(cfg2.get_value("settings", "ui_style", "")) == "paper",
		"the settings file says paper again"
	)
	Palette.apply_style("paper")
	_assert(Palette.current_style == "paper", "reached the end of the live style switch test on paper")
	_pass_section("129. Live Style Switch Test (set_ui_style restyles the open UI, persists, keeps the match)")

func _test_board_style_rebake_body(ui: Node) -> void:
	ui.auto_ai = false
	if ui._splash_overlay != null:
		ui._splash_overlay.visible = false
	ui._splash_shown = false
	await _ui_settle(4)
	var board: BoardView = ui._board_view
	_assert(board != null, "the UI owns a board view")
	var before := int(board.static_bake_requests)
	ui.set_ui_style("dark")
	ui.set_ui_style("dark")
	_assert(int(board.static_bake_requests) == before, "asking for the style already on requests no rebake")
	await _ui_settle(3)
	var after_dark := int(board.static_bake_requests)
	_assert(after_dark >= before + 1, "the dark switch requests a static rebake (+%d)" % (after_dark - before))
	_assert(String(board._static_style_sig).contains("dark"), "the stored static signature names dark, got %s" % str(board._static_style_sig))
	ui.set_ui_style("paper")
	await _ui_settle(3)
	var after_paper := int(board.static_bake_requests)
	_assert(after_paper >= after_dark + 1, "the paper switch requests a static rebake again (+%d)" % (after_paper - after_dark))
	_assert(String(board._static_style_sig).contains("paper"), "the stored static signature names paper again, got %s" % str(board._static_style_sig))
	_assert(not String(board._static_style_sig).contains("dark"), "the stored signature left the dark style behind")
	_assert(Palette.current_style == "paper", "reached the end of the board rebake test on paper")
	_pass_section("130. Board Rebake Test (static sea and land layers follow the colour style)")

func _test_style_switcher_button_body(ui: Node) -> void:
	ui.auto_ai = false
	if ui._splash_overlay != null:
		ui._splash_overlay.visible = false
	ui._splash_shown = false
	await _ui_settle(3)
	var cfg := ConfigFile.new()
	var paper: Dictionary = Palette.STYLES["paper"]
	var dark: Dictionary = Palette.STYLES["dark"]
	_assert(ui._style_btn != null, "the title bar carries a colour style switcher")
	_assert(String(ui._style_btn.text) == "", "the switcher shows no text, got %s" % str(ui._style_btn.text))
	_assert(Vector2(ui._style_btn.custom_minimum_size) == Vector2(44, 34), "the switcher keeps a fixed 44x34 box (p36 pill height 40 with 3 px above and below)")
	var icon_paper: Texture2D = ui._style_btn.icon
	_assert(icon_paper != null, "the paper switcher carries an icon")
	_assert(String(ui._style_btn.tooltip_text) == "Switch to Dark style", "the tooltip announces the next style, got %s" % str(ui._style_btn.tooltip_text))
	_assert(ui._style_btn.get_child_count() == 0, "the switcher button carries no popup child")
	for option_id in Palette.STYLE_IDS:
		_assert(String((Palette.STYLE_OPTIONS[option_id] as Dictionary).get("icon", "")) != "", "style %s names a switcher icon" % option_id)
	var rect_paper: Rect2 = ui._style_btn.get_global_rect()
	var tex_paper: Texture2D = ui._style_btn.icon
	_ui_real_click(ui._style_btn)
	await _ui_settle(3)
	_assert(Palette.current_style == "dark", "one real click switches to dark")
	_assert(cfg.load(TEST_SETTINGS_PATH) == OK and str(cfg.get_value("settings", "ui_style", "")) == "dark", "the settings file records the switched style")
	_assert(String(ui._style_btn.text) == "", "the dark switcher still shows no text")
	_assert(String(ui._style_btn.tooltip_text) == "Switch to Paper style", "the tooltip follows the switch, got %s" % str(ui._style_btn.tooltip_text))
	var icon_dark: Texture2D = ui._style_btn.icon
	_assert(icon_dark != null, "the dark switcher carries an icon")
	_assert(icon_dark != tex_paper, "the icon texture object changes with the style")
	_assert(ui._style_btn.get_global_rect() == rect_paper, "the switcher rect is identical in both styles")
	_assert(Vector2(ui._style_btn.size) == Vector2(44, 34), "the switcher is exactly 44x34 in dark, got %s" % str(ui._style_btn.size))
	_ui_real_click(ui._style_btn)
	await _ui_settle(3)
	_assert(Palette.current_style == "paper", "a second real click switches back to paper")
	_assert(String(ui._style_btn.tooltip_text) == "Switch to Dark style", "the tooltip is back to announcing Dark")
	_assert(ui._style_btn.icon != icon_dark, "the paper icon is rebuilt again")
	_assert(ui._style_btn.get_global_rect() == rect_paper, "the switcher rect never moved")
	var img: Image = (ui._style_btn.icon as Texture2D).get_image()
	var paper_text: Color = paper["BUTTON_TEXT"]
	var white := true
	for py in range(img.get_height()):
		for px in range(img.get_width()):
			var col := img.get_pixel(px, py)
			if col.a > 0.9 and (absf(col.r - 1.0) > 0.01 or absf(col.g - 1.0) > 0.01 or absf(col.b - 1.0) > 0.01):
				white = false
	_assert(white, "the icon texture stays white for the engine to tint")
	_assert(ui._style_btn.get_theme_color("icon_normal_color") == paper_text, "the icon takes the current BUTTON_TEXT colour")
	Palette.apply_style("paper")
	_assert(Palette.current_style == "paper", "reached the end of the switcher test on paper")
	_pass_section("131. Title Bar Style Toggle Test (one real click per style, sun/moon icon, fixed 44x40 rect)")

func _style_tree_snapshot(ui: Node) -> Dictionary:
	var out := {}
	_style_collect(ui, "root", out)
	return out

func _style_collect(node: Node, prefix: String, out: Dictionary) -> void:
	if node is Control:
		var ctrl := node as Control
		out[prefix] = [ctrl.visible, ctrl.global_position, ctrl.size, ctrl.custom_minimum_size, ctrl.get_combined_minimum_size()]
	var seen := {}
	var kids := node.get_children(true)
	for i in range(kids.size()):
		var kid := kids[i]
		var cls := kid.get_class()
		var used := int(seen.get(cls, 0))
		seen[cls] = used + 1
		_style_collect(kid, "%s/%s[%d]" % [prefix, cls, used], out)

func _style_snapshot_diff(a: Dictionary, b: Dictionary) -> String:
	var problems := ""
	for key in a:
		if not b.has(key):
			problems += "%s gone " % String(key)
	for key in b:
		if not a.has(key):
			problems += "%s new " % String(key)
	for key in a:
		if not b.has(key):
			continue
		var va: Array = a[key]
		var vb: Array = b[key]
		if bool(va[0]) != bool(vb[0]):
			problems += "%s visible %s->%s " % [String(key), str(va[0]), str(vb[0])]
			continue
		var pa: Vector2 = va[1]
		var pb: Vector2 = vb[1]
		var sa: Vector2 = va[2]
		var sb: Vector2 = vb[2]
		if (
			absf(pa.x - pb.x) > 0.01 or absf(pa.y - pb.y) > 0.01
			or absf(sa.x - sb.x) > 0.01 or absf(sa.y - sb.y) > 0.01
			or (va[3] as Vector2) != (vb[3] as Vector2)
			or (va[4] as Vector2) != (vb[4] as Vector2)
		):
			problems += "%s %s/%s/%s/%s->%s/%s/%s/%s " % [
				String(key), str(pa), str(sa), str(va[3]), str(va[4]), str(pb), str(sb), str(vb[3]), str(vb[4])
			]
	return problems

func _style_wait_quiet(ui: Node) -> bool:
	for attempt in range(600):
		await _ui_settle(1)
		var busy := bool(ui._turn_banner.visible) or bool(ui._dice_show_active)
		busy = busy or not ui._toast_labels.is_empty()
		if ui._flight_layer != null and not ui._flight_layer.get_children().is_empty():
			busy = true
		if ui._board_view != null and ui._board_view.has_method("steal_targets_showing") and bool(ui._board_view.steal_targets_showing()):
			busy = true
		if not busy:
			return true
	return false

func _style_wait_stable(ui: Node, tag: String) -> Dictionary:
	var quiet := await _style_wait_quiet(ui)
	_assert(quiet, "%s: the toasts, flights and banners all settled down" % tag)
	var last := {}
	for attempt in range(40):
		await _ui_settle(2)
		var a := _style_tree_snapshot(ui)
		await _ui_settle(2)
		var b := _style_tree_snapshot(ui)
		if _style_snapshot_diff(a, b) == "":
			return b
		last = b
	_assert(false, "%s: the UI never became still, cannot lock the layout (%s)" % [tag, _style_snapshot_diff(last, _style_tree_snapshot(ui))])
	return last

func _style_poke_theme(node: Node) -> void:
	for child in node.get_children(true):
		if child is Control:
			_style_poke_theme(child)
			var ctrl := child as Control
			if ctrl.has_theme_color_override("font_color"):
				var keep := ctrl.get_theme_color("font_color")
				ctrl.remove_theme_color_override("font_color")
				ctrl.add_theme_color_override("font_color", keep)
			else:
				ctrl.add_theme_color_override("font_color", ctrl.get_theme_color("font_color"))
				ctrl.remove_theme_color_override("font_color")
			ctrl.update_minimum_size()


func _style_warm_up_ui(ui: Node) -> void:
	# Headless boots cache doubled text metrics until the control's theme is poked;
	# a style switch pokes only the controls it recolours, so the tests warm the
	# whole tree before taking a "before" snapshot.
	ui.set_ui_style("dark")
	await _ui_settle(6)
	ui.set_ui_style("paper")
	await _ui_settle(6)
	_style_poke_theme(ui)
	await _ui_settle(2)


func _style_state_lock(ui: Node, tag: String) -> void:
	await _style_warm_up_ui(ui)
	var paper_snap := await _style_wait_stable(ui, "%s paper" % tag)
	_assert(paper_snap.size() > 200, "%s: the paper snapshot covers the whole tree (%d controls)" % [tag, paper_snap.size()])
	ui.set_ui_style("dark")
	await _ui_settle(3)
	var dark_snap := await _style_wait_stable(ui, "%s dark" % tag)
	var dark_problems := _style_snapshot_diff(paper_snap, dark_snap)
	_assert(dark_problems == "", "%s: switching to dark moved nothing (%s)" % [tag, dark_problems])
	_assert(bool(Palette.current_style == "dark"), "%s: the tree really went dark before comparing" % tag)
	ui.set_ui_style("paper")
	await _ui_settle(3)
	var back_snap := await _style_wait_stable(ui, "%s paper again" % tag)
	var back_problems := _style_snapshot_diff(dark_snap, back_snap)
	_assert(back_problems == "", "%s: switching back to paper moved nothing (%s)" % [tag, back_problems])
	Palette.apply_style("paper")
	_assert(Palette.current_style == "paper", "%s: the state lock ends on paper" % tag)

func _test_style_layout_lock_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	ui.auto_ai = false
	if ui._splash_overlay != null:
		ui._splash_overlay.visible = false
	ui._splash_shown = false
	await _ui_settle(4)
	var seats_ok := _ui_drive_until(ui, func(st: GameState) -> bool:
		return st.phase == GameTypes.TurnPhase.TURN_MAIN and not ui.session.is_ai_to_act() and st.open_trade.is_empty()
	)
	_assert(seats_ok, "the layout lock test reached the human's main phase")
	if not seats_ok:
		return
	await _ui_settle(3)
	var banner_font := ThemeDB.fallback_font
	var phrases: Array[String] = [
		"Choose who to steal from, or click another hex \u2014 keys 1-3, Esc picks another tile",
		"Pick a player card to trade \u2014 any action, closing or End Turn withdraws it.",
		"Click a glowing spot to build \u2014 or trade, or end your turn.",
		"Crimson wants to trade \u2014 accept, decline or counter.",
		"Play Guard: Click a highlighted hex tile to move the Blocker.",
		"Road Work: click a glowing edge for a free road.",
	]
	var widest := 0.0
	for phrase in phrases:
		widest = maxf(widest, banner_font.get_string_size(phrase, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var banner_paper: float = ui._status_banner_label.size.x
	ui._step_top_btn.visible = false
	await _ui_settle(3)
	var banner_default: float = ui._status_banner_label.size.x
	_assert(
		widest <= banner_default + 0.5,
		"the longest banner sentence fits with \"Step bot\" hidden, the shipped layout (needs %.1f px, banner %.1f px)" % [widest, banner_default]
	)
	ui._step_top_btn.visible = true
	await _ui_settle(3)
	var banner_step: float = ui._status_banner_label.size.x
	_assert(
		bool(ui._status_banner_label.clip_text) and banner_step < widest,
		"with \"Step bot\" visible the longest banner ellipsises instead of pushing the switcher (banner %.1f px, needs %.1f px)" % [banner_step, widest]
	)
	await _style_state_lock(ui, "main phase")
	ui._set_tray_panel_visible(true)
	await _ui_settle(3)
	_assert(bool(ui._trade_tray.visible), "the trade tray is open for the layout lock")
	var tray_w0 := float(ui._trade_tray.size.x)
	var creep := ""
	for i in range(5):
		ui._refresh_ui()
		await _ui_settle(4)
		if absf(ui._trade_tray.size.x - tray_w0) > 0.01:
			creep += " r%d=%.1f" % [i + 1, float(ui._trade_tray.size.x)]
	_assert(creep == "", "five plain refreshes keep the trade tray the same width (from %.1f px:%s)" % [tray_w0, creep])
	await _style_state_lock(ui, "trade tray open")
	ui._set_tray_panel_visible(false)
	await _ui_settle(2)
	ui._show_lobby()
	await _ui_settle(3)
	_assert(bool(ui._lobby_overlay.visible), "the lobby overlay is open for the layout lock")
	await _style_state_lock(ui, "lobby overlay open")
	ui._close_overlays()
	await _ui_settle(2)
	var banner_back: float = ui._status_banner_label.size.x
	_assert(absf(banner_back - banner_paper) < 0.01, "the banner label is the same width after a style round trip (%.1f vs %.1f)" % [banner_back, banner_paper])
	_assert(
		ui._status_banner_label.size.x <= 1280.0 - 88.0 - 16.0,
		"the banner still yields to the fixed switcher box (banner %.1f px)" % ui._status_banner_label.size.x
	)
	_assert(String(ui._style_btn.text) == "", "the switcher shows no text at the end")
	Palette.apply_style("paper")
	_assert(Palette.current_style == "paper", "reached the end of the style layout lock test on paper")
	_pass_section("132. Style Layout Lock Test (nothing moves across styles: play, tray, lobby)")

func _style_colour_offender_sets() -> Dictionary:
	var paper: Dictionary = Palette.STYLES["paper"]
	var dark: Dictionary = Palette.STYLES["dark"]
	var paper_keys := {}
	var dark_keys := {}
	for k in paper:
		paper_keys[Palette.rgb_key(paper[k])] = String(k)
	for k in dark:
		dark_keys[Palette.rgb_key(dark[k])] = String(k)
	var paper_only := {}
	for rgb in paper_keys:
		if not dark_keys.has(rgb):
			paper_only[rgb] = paper_keys[rgb]
	var dark_only := {}
	for rgb in dark_keys:
		if not paper_keys.has(rgb):
			dark_only[rgb] = dark_keys[rgb]
	return {"paper_only": paper_only, "dark_only": dark_only}


func _style_collect_colours(node: Node) -> Array:
	var out: Array = []
	_style_collect_colours_into(node, "root", out)
	return out


func _style_collect_colours_into(node: Node, prefix: String, out: Array) -> void:
	if node is Control or node is Window:
		for prop in node.get_property_list():
			var pname := String(prop["name"])
			if pname.begins_with("theme_override_colors/"):
				var value: Variant = node.get(pname)
				if value is Color:
					out.append([prefix, pname, value])
			elif pname.begins_with("theme_override_styles/"):
				var box := node.get(pname) as StyleBoxFlat
				if box != null:
					out.append([prefix, pname + "/bg_color", box.bg_color])
					out.append([prefix, pname + "/border_color", box.border_color])
					out.append([prefix, pname + "/shadow_color", box.shadow_color])
	if node is ColorRect:
		out.append([prefix, "color", (node as ColorRect).color])
	elif node is Line2D:
		out.append([prefix, "default_color", (node as Line2D).default_color])
	elif node is RichTextLabel:
		var rx := RegEx.create_from_string("\\[color=#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?\\]")
		for m in rx.search_all((node as RichTextLabel).text):
			out.append([prefix, "bbcode_color", Color.from_string("ff" + m.get_string(1) + (m.get_string(2) if m.get_string(2) != "" else ""), Color(0, 0, 0, 0))])
	var node_script: GDScript = node.get_script() as GDScript
	if node_script != null:
		for prop in node_script.get_script_property_list():
			if int(prop["type"]) != TYPE_COLOR:
				continue
			var stored: Variant = node.get(String(prop["name"]))
			if stored is Color:
				out.append([prefix, String(prop["name"]), stored])
	var seen := {}
	for kid in node.get_children(true):
		var cls := kid.get_class()
		var used := int(seen.get(cls, 0))
		seen[cls] = used + 1
		_style_collect_colours_into(kid, "%s/%s[%d]" % [prefix, cls, used], out)


func _style_scan_leftovers(ui: Node, tag: String, want_paper_only: bool) -> void:
	var sets := _style_colour_offender_sets()
	var wanted: Dictionary = sets["paper_only"] if want_paper_only else sets["dark_only"]
	var scan: Array = _style_collect_colours(ui)
	var offenders := ""
	var seen_keys := 0
	for trip in scan:
		var rgb := Palette.rgb_key(trip[2] as Color)
		if wanted.has(rgb):
			offenders += "%s %s = %s (%s) " % [String(trip[0]), String(trip[1]), str(trip[2]), String(wanted[rgb])]
		if sets["paper_only"].has(rgb) or sets["dark_only"].has(rgb):
			seen_keys += 1
	_assert(seen_keys > 30, "%s: the colour scan saw palette colours (%d hits)" % [tag, seen_keys])
	var kind := "paper colour" if want_paper_only else "dark colour"
	_assert(offenders == "", "%s: no %s is left behind after the switch (%s)" % [tag, kind, offenders])


func _style_scan_dark_and_back(ui: Node, tag: String, on_dark: Callable = Callable()) -> void:
	ui.set_ui_style("dark")
	await _ui_settle(6)
	_style_scan_leftovers(ui, tag, true)
	if on_dark.is_valid():
		await on_dark.call()
	ui.set_ui_style("paper")
	await _ui_settle(6)
	_style_scan_leftovers(ui, tag, false)
	_assert(Palette.current_style == "paper", "%s: the scan ends back on paper" % tag)


func _style_control_colours(node: Node) -> Dictionary:
	var out := {}
	for prop in node.get_property_list():
		var pname := String(prop["name"])
		if pname.begins_with("theme_override_colors/"):
			var value: Variant = node.get(pname)
			if value is Color:
				out[pname] = value
		elif pname.begins_with("theme_override_styles/"):
			var box := node.get(pname) as StyleBoxFlat
			if box != null:
				out[pname] = [box.bg_color, box.border_color, box.shadow_color]
	return out


func _style_state_walk(ui: Node, on_state: Callable) -> void:
	root.size = Vector2i(1280, 800)
	ui.auto_ai = false
	if ui._splash_overlay != null:
		ui._splash_overlay.visible = false
	ui._splash_shown = false
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return st.phase == GameTypes.TurnPhase.TURN_MAIN and not ui.session.is_ai_to_act() and st.open_trade.is_empty()
	)
	_assert(reached, "the style state walk reached the human's main phase")
	if not reached:
		return
	await _ui_settle(3)
	var walk_state: GameState = ui.session.state
	var guard_holder: Dictionary = walk_state.players[0]
	var guard_played: Dictionary = guard_holder.get("played_dev", {})
	guard_played[GameTypes.DevCardType.GUARD] = 3
	guard_holder["played_dev"] = guard_played
	walk_state.largest_guard_holder = 0
	var route_holder: Dictionary = walk_state.players[1]
	route_holder["longest_route_length"] = 5
	walk_state.longest_route_holder = 1
	ui._refresh_ui()
	await _ui_settle(3)
	await on_state.call(ui, "match on the human's turn")
	var hand: Dictionary = ui.session.state.players[0]["hand"]
	var pick_res := -1
	for r in GameTypes.ALL_RESOURCES:
		if int(hand.get(r, 0)) > 0:
			pick_res = r
			break
	_assert(pick_res >= 0, "the human holds a card to offer for the tray state")
	ui._set_tray_panel_visible(true)
	ui._trade_give_counts[pick_res] = 1
	ui._refresh_ui()
	await _ui_settle(3)
	_assert(bool(ui._trade_tray.visible) and int(ui._trade_give_counts.get(pick_res, 0)) == 1, "the tray is open with a card picked")
	await on_state.call(ui, "trade tray open with a card picked")
	ui._trade_give_counts[pick_res] = 0
	ui._set_tray_panel_visible(false)
	await _ui_settle(2)
	ui._show_lobby()
	await _ui_settle(3)
	_assert(bool(ui._lobby_overlay.visible), "the lobby overlay is open")
	await on_state.call(ui, "lobby overlay open")
	ui._close_overlays()
	await _ui_settle(2)
	ui._show_overlay("settings")
	await _ui_settle(3)
	_assert(bool(ui._settings_overlay.visible), "the settings overlay is open")
	await on_state.call(ui, "settings overlay open")
	ui._close_overlays()
	await _ui_settle(2)
	ui._show_overlay("help")
	await _ui_settle(3)
	_assert(bool(ui._help_overlay.visible), "the help overlay is open")
	await on_state.call(ui, "help overlay open")
	ui._close_overlays()
	await _ui_settle(2)
	ui._set_log_open(true)
	await _ui_settle(3)
	_assert(bool(ui._log_popup.visible), "the full event-log popup is open")
	await on_state.call(ui, "full event-log popup open")
	ui._set_log_open(false)
	await _ui_settle(2)
	var steal_seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_EASY, "Pike"),
	]
	ui.session.start_match(52002, steal_seats, true, 0)
	var st: GameState = ui.session.state
	var topo := HexMath.get_topology()
	st.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	st.current_player = 0
	st.blocker_tile = 9
	st.vertex_owner[topo.tile_vertices[5][0]] = 1
	st.vertex_owner[topo.tile_vertices[5][1]] = 2
	st.players[1]["hand"] = GameTypes.empty_hand()
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 2
	st.players[2]["hand"] = GameTypes.empty_hand()
	st.players[2]["hand"][GameTypes.ResourceType.IRON] = 3
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 1
	ui._refresh_ui()
	ui._on_board_tile_clicked(5)
	await _ui_settle(3)
	_assert(bool(ui._board_view.steal_targets_showing()) and int(ui._board_view.get_steal_target_count()) == 2, "the steal victim marks are open")
	await on_state.call(ui, "steal victim marks open")
	ui._cancel_current_pick()
	await _ui_settle(2)
	var discard_seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52001, discard_seats, true, 0)
	st = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_DISCARD
	st.current_player = 0
	st.pending_discards = {0: 4}
	st.players[0]["hand"] = GameTypes.empty_hand()
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 3
	st.players[0]["hand"][GameTypes.ResourceType.CLAY] = 3
	st.players[0]["hand"][GameTypes.ResourceType.FLEECE] = 2
	ui._refresh_ui()
	await _ui_settle(3)
	_assert(bool(ui._discard_mode_box.visible), "the discard prompt is showing")
	await on_state.call(ui, "discard prompt showing")
	st = ui.session.state
	st.vertex_owner[0] = 0
	st.vertex_building[0] = GameTypes.BuildingType.SETTLEMENT
	st.vertex_owner[1] = 1
	st.vertex_building[1] = GameTypes.BuildingType.CITY
	st.vertex_owner[2] = 1
	st.vertex_building[2] = GameTypes.BuildingType.CITY
	st.longest_route_holder = 1
	st.players[1]["dev_cards"] = [GameTypes.DevCardType.CHARTER_POINT]
	st.turn_number = 12
	st.winner = 1
	st.phase = GameTypes.TurnPhase.GAME_OVER
	var evs: Array[String] = []
	ui._on_state_updated(st, evs)
	await _ui_settle(4)
	_assert(bool(ui._splash_overlay.visible), "the end splash is shown")
	await on_state.call(ui, "end splash shown")


func _style_compare_fresh_dark(ui: Node) -> void:
	var packed := ResourceLoader.load("res://scenes/main.tscn") as PackedScene
	var fresh: Node = packed.instantiate()
	fresh.auto_ai = false
	root.add_child(fresh)
	await _ui_settle(3)
	_assert(String(fresh._ui_style) == "dark", "the fresh UI starts on the saved dark style")
	for member in ["_header_panel", "_status_banner_label", "_phase_label", "_menu_btn", "_help_costs_btn", "_style_btn", "_hand_bar_panel", "_right_panel", "_buy_card_btn", "_trade_ask_btn", "_cancel_pick_btn", "_menu_popup"]:
		var live := _style_control_colours(ui.get(member) as Node)
		var built := _style_control_colours(fresh.get(member) as Node)
		var diff := ""
		for key in live:
			if not built.has(key):
				diff += "%s missing %s " % [member, String(key)]
			elif str(live[key]) != str(built[key]):
				diff += "%s %s live=%s fresh=%s " % [member, String(key), str(live[key]), str(built[key])]
		for key in built:
			if not live.has(key):
				diff += "%s extra %s " % [member, String(key)]
		_assert(diff == "", "live dark equals a freshly built dark UI (%s)" % diff)
	fresh.free()


func _style_leftover_visit(ui: Node, tag: String) -> void:
	if tag == "match on the human's turn":
		await _style_scan_dark_and_back(ui, tag, func() -> void:
			await _style_compare_fresh_dark(ui)
		)
	else:
		await _style_scan_dark_and_back(ui, tag)


func _test_style_leftover_scan_body(ui: Node) -> void:
	await _style_state_walk(ui, _style_leftover_visit)
	Palette.apply_style("paper")
	var cfg := ConfigFile.new()
	_assert(
		cfg.load(TEST_SETTINGS_PATH) == OK and str(cfg.get_value("settings", "ui_style", "")) == "paper",
		"the leftover scan test leaves the settings file on paper"
	)
	_assert(Palette.current_style == "paper", "reached the end of the leftover scan test on paper")
	_pass_section("Style Leftover Scan Test (no colour of the other style left behind, nine states, live dark equals a fresh dark UI)")



func _style_is_player_colour(c: Color) -> bool:
	for pc in GameTypes.PLAYER_COLORS:
		if Palette.rgb_key(pc) == Palette.rgb_key(c):
			return true
	return false


func _style_override_stylebox(c: Control, state_name: String) -> StyleBoxFlat:
	var pname := "theme_override_styles/" + state_name
	for prop in c.get_property_list():
		if String(prop["name"]) == pname:
			var value: Variant = c.get(pname)
			if value is StyleBoxFlat:
				return value as StyleBoxFlat
			return null
	return null


func _style_effective_bg(c: Control) -> Color:
	var n: Node = c
	while n != null and n is Control:
		var cur := n as Control
		if not (cur is Button or cur is LineEdit or cur is PanelContainer or cur is Panel or cur is ColorRect):
			for sn in ["panel", "normal"]:
				var own := _style_override_stylebox(cur, sn)
				if own != null and own.bg_color.a >= 0.9:
					return own.bg_color
		if cur is CheckBox:
			var cb := _style_override_stylebox(cur, "normal")
			if cb != null and cb.bg_color.a >= 0.9:
				return cb.bg_color
		elif cur is Button:
			var sn := "normal"
			if (cur as Button).disabled:
				sn = "disabled"
			var box := cur.get_theme_stylebox(sn) as StyleBoxFlat
			if box != null and box.bg_color.a >= 0.9:
				return box.bg_color
		elif cur is LineEdit:
			var lbox := cur.get_theme_stylebox("normal") as StyleBoxFlat
			if lbox != null and lbox.bg_color.a >= 0.9:
				return lbox.bg_color
		elif cur is PanelContainer or cur is Panel:
			var pbox := cur.get_theme_stylebox("panel") as StyleBoxFlat
			if pbox != null and pbox.bg_color.a >= 0.9:
				return pbox.bg_color
		elif cur is ColorRect and (cur as ColorRect).color.a >= 0.9:
			return (cur as ColorRect).color
		n = cur.get_parent()
	return Palette.SEA


func _style_contrast_check(c: Control, path: String, tag: String, paper_mode: bool, problems: Array[String]) -> void:
	var txt := ""
	if c is Label:
		txt = (c as Label).text
	elif c is Button:
		txt = (c as Button).text
	elif c is LineEdit:
		txt = (c as LineEdit).text
	else:
		return
	if txt.strip_edges() == "":
		return
	var disabled := false
	if c is Button:
		disabled = (c as Button).disabled
	elif c is LineEdit:
		disabled = not (c as LineEdit).editable
	var col: Color = c.get_theme_color("font_disabled_color" if disabled else "font_color")
	var bg := _style_effective_bg(c)
	if col.a < 0.999:
		col = bg.lerp(col, col.a)
	var r := _contrast_ratio(col, bg)
	var min_ratio := 3.0 if disabled else 4.5
	if r >= min_ratio:
		return
	if not paper_mode and _style_is_player_colour(bg):
		return
	var generic := RegEx.create_from_string("\\[\\d+\\]").sub(path, "[*]", true)
	var key := "%s :: %s" % [tag, generic]
	problems.append("%s :: %s text %s on %s = %.2f (min %.1f)" % [key, txt, str(col), str(bg), r, min_ratio])


func _style_contrast_walk_node(node: Node, path: String, tag: String, paper_mode: bool, problems: Array[String]) -> void:
	var seen := {}
	for kid in node.get_children():
		var cls := kid.get_class()
		var used := int(seen.get(cls, 0))
		seen[cls] = used + 1
		var kid_path := "%s/%s[%d]" % [path, cls, used]
		if not (kid is Control):
			continue
		var c := kid as Control
		if not c.is_visible_in_tree():
			continue
		_style_contrast_check(c, kid_path, tag, paper_mode, problems)
		_style_contrast_walk_node(c, kid_path, tag, paper_mode, problems)


func _style_contrast_scan(ui: Node, tag: String, paper_mode: bool) -> void:
	var problems: Array[String] = []
	_style_contrast_walk_node(ui, "root", tag, paper_mode, problems)
	var style := "paper" if paper_mode else "dark"
	_assert(problems.is_empty(), "%s: %s text keeps WCAG contrast (%s)" % [tag, style, " || ".join(problems)])


func _style_contrast_visit(ui: Node, tag: String) -> void:
	ui.set_ui_style("dark")
	await _ui_settle(6)
	_style_contrast_scan(ui, tag, false)
	ui.set_ui_style("paper")
	await _ui_settle(6)
	_style_contrast_scan(ui, tag, true)


func _test_style_contrast_body(ui: Node) -> void:
	await _style_state_walk(ui, _style_contrast_visit)
	Palette.apply_style("paper")
	_assert(Palette.current_style == "paper", "reached the end of the contrast scan test on paper")
	_pass_section("133. Style Contrast Scan Test (4.5:1 enabled and 3:1 disabled text on their real background, nine states, both styles)")


func _test_toast_tint_remap_body(ui: Node) -> void:
	ui.set_ui_style("paper")
	await _ui_settle(6)
	ui._show_toast("x", Palette.TOAST_STEAL_BAD, 30.0)
	await _ui_settle(2)
	var label: Label = ui._toast_labels[ui._toast_labels.size() - 1] as Label
	_assert(label != null, "the toast label was created")
	_assert((label.get_meta("toast_tint") as Color) == Palette.TOAST_STEAL_BAD, "the paper toast stores the paper tint in its meta")
	ui.set_ui_style("dark")
	await _ui_settle(6)
	var dark_tint: Color = Palette.STYLES["dark"]["TOAST_STEAL_BAD"]
	_assert((label.get_meta("toast_tint") as Color) == dark_tint, "the switch remaps the stored toast tint to dark")
	var font_col := label.get_theme_color("font_color")
	_assert(
		_contrast_ratio(font_col, Palette.TOAST_PILL_BG) >= 4.5,
		"the dark toast text keeps 4.5:1 on the pill (%.2f)" % _contrast_ratio(font_col, Palette.TOAST_PILL_BG)
	)
	ui.set_ui_style("paper")
	await _ui_settle(6)
	_assert(label.get_theme_color("font_color") == Palette.TOAST_STEAL_BAD, "the paper toast text is the paper tint again")
	_assert(Palette.current_style == "paper", "reached the end of the toast tint remap test on paper")
	_pass_section("134. Toast Tint Remap Test (live toasts recolour through the style table on a switch)")


func _test_award_glyph_highlight_body(ui: Node) -> void:
	var mins := {}
	for style in ["paper", "dark"]:
		ui.set_ui_style(style)
		await _ui_settle(2)
		var glyph := ui._make_played_glyph(GameTypes.DevCardType.GUARD, 3, true, "t") as PanelContainer
		var road := ui._make_road_glyph(5, true) as PanelContainer
		for cell in [glyph, road]:
			var sb := cell.get_theme_stylebox("panel") as StyleBoxFlat
			_assert(sb != null and sb.bg_color == Palette.AWARD_HIGHLIGHT_BG, "%s award glyph box is filled with AWARD_HIGHLIGHT_BG" % style)
			var lbl: Label = null
			for kid in cell.find_children("*", "Label", true, false):
				lbl = kid as Label
				break
			_assert(lbl != null, "%s award glyph carries a count label" % style)
			_assert(lbl.get_theme_color("font_color") == Palette.TEXT, "%s award count uses TEXT" % style)
			_assert(
				_contrast_ratio(Palette.TEXT, Palette.AWARD_HIGHLIGHT_BG) >= 7.0,
				"%s award count clears 7:1 (%.2f)" % [style, _contrast_ratio(Palette.TEXT, Palette.AWARD_HIGHLIGHT_BG)]
			)
		mins[style] = [glyph.get_combined_minimum_size(), road.get_combined_minimum_size()]
		glyph.free()
		road.free()
	ui.set_ui_style("paper")
	await _ui_settle(2)
	_assert(mins["paper"] == mins["dark"], "the highlighted glyphs ask for the same space in both styles")
	_assert(Palette.current_style == "paper", "reached the end of the award glyph highlight test on paper")
	_pass_section("135. Award Glyph Highlight Test (gold box filled from the palette, count in TEXT, 7:1)")

func _p33_log_heading(ui: Node) -> Label:
	for c in ui._sidebar_box.get_children():
		if c is HBoxContainer:
			for gc in c.get_children():
				if gc is Label and str(gc.text).contains("EVENT LOG"):
					return gc as Label
	return null

func _p33_check_pinned(ui: Node, tag: String, h0: Rect2, l0: Rect2, sy0: float, bar0: float, strip0: float, board0: Rect2) -> void:
	var h1 := _p33_log_heading(ui)
	_assert(h1 != null, "%s: the EVENT LOG heading is in the sidebar" % tag)
	if h1 == null:
		return
	_assert(h1.get_global_rect() == h0, "%s: the EVENT LOG heading did not move (%s vs %s)" % [tag, str(h1.get_global_rect()), str(h0)])
	_assert(ui._log_panel.get_global_rect() == l0, "%s: the log panel did not move (%s vs %s)" % [tag, str(ui._log_panel.get_global_rect()), str(l0)])
	_assert(absf(ui._trade_slot.size.y - sy0) < 0.01, "%s: the trade slot kept its height (%.1f vs %.1f)" % [tag, ui._trade_slot.size.y, sy0])
	_assert(absf(ui._header_panel.size.y - bar0) < 0.01, "%s: the title bar kept its height (%.1f vs %.1f)" % [tag, ui._header_panel.size.y, bar0])
	_assert(absf(ui._offer_strip.size.y - strip0) < 0.01, "%s: the offer strip kept its height (%.1f vs %.1f)" % [tag, ui._offer_strip.size.y, strip0])
	_assert(ui._board_view.get_global_rect() == board0, "%s: the board rect did not change (%s vs %s)" % [tag, str(ui._board_view.get_global_rect()), str(board0)])

func _p33_watch_frames(ui: Node, tag: String, l0: Rect2) -> void:
	for i in range(40):
		await _ui_settle(1)
		_assert(ui._log_panel.get_global_rect() == l0, "%s: frame %d kept the log in place" % [tag, i])

func _test_log_stays_placed_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	ui.auto_ai = false
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(31607, seats, true, 0)
	var s = ui.session
	var reached := _ui_drive_until(ui, func(st: GameState) -> bool:
		return not s.is_ai_to_act() and st.phase == GameTypes.TurnPhase.TURN_MAIN and st.open_trade.is_empty()
	)
	_assert(reached, "Human main phase is reachable for the log placement test")
	if not reached:
		root.size = Vector2i(64, 64)
		return
	var st: GameState = s.state
	var TIMBER: int = GameTypes.ResourceType.TIMBER
	var CLAY: int = GameTypes.ResourceType.CLAY
	var IRON: int = GameTypes.ResourceType.IRON
	var GRAIN: int = GameTypes.ResourceType.GRAIN
	ui._close_trade_tray_by_user()
	await _ui_settle(6)
	var heading := _p33_log_heading(ui)
	_assert(heading != null, "The sidebar carries an EVENT LOG heading")
	if heading == null:
		root.size = Vector2i(64, 64)
		return
	var h0: Rect2 = heading.get_global_rect()
	var l0: Rect2 = ui._log_panel.get_global_rect()
	var sy0: float = ui._trade_slot.size.y
	var bar0: float = ui._header_panel.size.y
	var strip0: float = ui._offer_strip.size.y
	var board0: Rect2 = ui._board_view.get_global_rect()
	_assert(absf(bar0 - 52.0) < 0.01, "The title bar is 52 px at 1280x800, got %.1f" % bar0)
	_assert(absf(strip0 - 30.0) < 0.01, "The offer strip is 30 px at 1280x800, got %.1f" % strip0)
	_assert(l0.size.y >= 90.0, "The log keeps room for 4 full rows at 1280x800, got %.1f" % l0.size.y)
	_assert(ui._trade_slot.visible and ui._log_panel.visible, "The slot and the log are on screen before any trade")
	await _p33_check_pinned(ui, "idle", h0, l0, sy0, bar0, strip0, board0)
	# Own draft with two give kinds, by real clicks on two hand cards.
	for r in GameTypes.ALL_RESOURCES:
		st.players[0]["hand"][r] = 4
	ui._reset_trade_counts()
	ui._set_tray_panel_visible(true)
	await _ui_settle(3)
	_ui_real_click(ui._res_card_refs[TIMBER])
	await _ui_settle(2)
	_ui_real_click(ui._res_card_refs[CLAY])
	await _ui_settle(2)
	_assert(int(ui._trade_give_counts.get(TIMBER, 0)) == 1 and int(ui._trade_give_counts.get(CLAY, 0)) == 1, "The draft holds two give kinds")
	await _p33_check_pinned(ui, "own draft (2 give kinds)", h0, l0, sy0, bar0, strip0, board0)
	# Post the offer; Dune declines, Pike counters with three resources,
	# Riven is still waiting.
	ui._trade_get_counts[GRAIN] = 1
	ui._refresh_ui()
	await _ui_settle(2)
	_ui_real_click(ui._ot_send_btn)
	await _ui_settle(6)
	for r in GameTypes.ALL_RESOURCES:
		st.players[2]["hand"][r] = 4
	s.submit_action(1, GameAction.respond_open_trade("decline"))
	s.submit_action(2, GameAction.respond_open_trade("counter", {GRAIN: 2}, {TIMBER: 3, CLAY: 1, IRON: 1}))
	ui._refresh_ui()
	await _ui_settle(8)
	_assert(bool(ui._ot_accept_btn.visible), "The proposer sees the counter with Accept/Decline")
	await _p33_check_pinned(ui, "own offer: decline + 3-resource counter + waiting", h0, l0, sy0, bar0, strip0, board0)
	_ui_real_click(ui._ot_accept_btn)
	await _ui_settle(8)
	var modal_guard := 0
	while bool(ui._ot_result_active) and modal_guard < 100:
		modal_guard += 1
		await _ui_settle(4)
	await _ui_settle(4)
	# Dune makes an offer; both bots answer first and the human is last.
	st.current_player = 1
	st.open_trades_this_turn = 0
	st.players[1]["hand"][GRAIN] = 3
	s.submit_action(1, GameAction.open_trade({GRAIN: 1}, {TIMBER: 1}))
	s.submit_action(2, GameAction.respond_open_trade("decline"))
	s.submit_action(3, GameAction.respond_open_trade("decline"))
	ui._set_tray_panel_visible(true)
	ui._refresh_ui()
	await _ui_settle(8)
	_assert(bool(ui._trade_respond_mode) and bool(ui._ot_decline_btn.visible), "The human is in the response view")
	await _p33_check_pinned(ui, "bot offer awaiting human", h0, l0, sy0, bar0, strip0, board0)
	# Counter editor (real click), watched for single-frame log jumps.
	_ui_real_click(ui._ot_counter_btn)
	await _ui_settle(2)
	_assert(bool(ui._trade_counter_mode), "Counter mode engages")
	await _p33_watch_frames(ui, "open counter editor", l0)
	await _ui_settle(4)
	_assert(bool(ui._ot_back_btn.visible), "The counter editor is open")
	await _p33_check_pinned(ui, "counter editor", h0, l0, sy0, bar0, strip0, board0)
	_ui_real_click(ui._ot_back_btn)
	await _ui_settle(3)
	_ui_real_click(ui._ot_decline_btn)
	await _ui_settle(8)
	await _p33_check_pinned(ui, "after the human declined", h0, l0, sy0, bar0, strip0, board0)
	st.current_player = 1
	s.submit_action(1, GameAction.cancel_open_trade())
	var gone := await _ui_wait_dead_offer_withdrawn(ui, 2000)
	_assert(gone, "The dead Dune offer is withdrawn before Pike's turn")
	while bool(ui._ot_result_active):
		await _ui_settle(4)
	# A bot-to-bot trade the human only watches: the human declines first
	# and the offer stays open while the bots deliberate.
	st.current_player = 2
	st.open_trades_this_turn = 0
	st.players[2]["hand"][GRAIN] = 3
	s.submit_action(2, GameAction.open_trade({GRAIN: 1}, {CLAY: 1}))
	s.submit_action(0, GameAction.respond_open_trade("decline"))
	ui._set_tray_panel_visible(true)
	ui._refresh_ui()
	await _ui_settle(8)
	_assert((st.open_trade.get("responses", {}) as Dictionary).has(0), "The human's decline is registered")
	_assert(not st.open_trade.is_empty(), "The offer stays open while the bots deliberate")
	_assert(bool(ui._trade_watch_col.visible), "The watch column is visible while bots finish")
	await _p33_check_pinned(ui, "watching a bot-to-bot trade", h0, l0, sy0, bar0, strip0, board0)
	s.submit_action(1, GameAction.respond_open_trade("decline"))
	s.submit_action(3, GameAction.respond_open_trade("decline"))
	st.current_player = 2
	s.submit_action(2, GameAction.cancel_open_trade())
	var gone2 := await _ui_wait_dead_offer_withdrawn(ui, 2000)
	_assert(gone2, "The dead Pike offer is withdrawn")
	while bool(ui._ot_result_active):
		await _ui_settle(4)
	# Tray closed with the x button.
	_ui_real_click(ui._res_card_refs[TIMBER])
	await _ui_settle(2)
	_assert(bool(ui._trade_close_btn.visible), "The editor shows the close button")
	_ui_real_click(ui._trade_close_btn)
	await _ui_settle(6)
	await _p33_check_pinned(ui, "tray closed", h0, l0, sy0, bar0, strip0, board0)
	# Same placement in the dark style and back on paper.
	ui.set_ui_style("dark")
	await _p33_watch_frames(ui, "style switch to dark", l0)
	await _ui_settle(4)
	await _p33_check_pinned(ui, "dark style (tray closed)", h0, l0, sy0, bar0, strip0, board0)
	ui._set_tray_panel_visible(true)
	await _ui_settle(3)
	await _p33_check_pinned(ui, "dark style (editor open)", h0, l0, sy0, bar0, strip0, board0)
	ui._close_trade_tray_by_user()
	ui.set_ui_style("paper")
	await _ui_settle(4)
	await _p33_check_pinned(ui, "paper again", h0, l0, sy0, bar0, strip0, board0)
	_assert(Palette.current_style == "paper", "The log placement test ends on paper")
	root.size = Vector2i(64, 64)
	_pass_section("136. Event Log Stays Placed (one slot height per window size, 7 trade states, 40-frame watch, both styles)")

func _test_badge_over_art_body(ui: Node) -> void:
	var TIMBER: int = GameTypes.ResourceType.TIMBER
	var CLAY: int = GameTypes.ResourceType.CLAY
	var sizes: Array[Vector2] = [
		Vector2(30, 42), Vector2(34, 47), Vector2(44, 61.6),
		Vector2(62, 86.8), Vector2(36, 84.4), Vector2(42, 92.8),
	]
	for nm in [false, true]:
		for pile in [-1, 3]:
			for sz in sizes:
				var a := CardFace.new()
				a.size = sz
				a.kind = "resource"
				a.resource = GameTypes.ResourceType.GRAIN
				a.show_name = nm
				a.count_badge = true
				a.pile_count = pile
				var b := CardFace.new()
				b.size = sz
				b.kind = "resource"
				b.resource = GameTypes.ResourceType.GRAIN
				b.show_name = nm
				b.count_badge = true
				b.pile_count = pile
				b.count = 5
				var fa: Rect2 = a._card_rect()
				var fb: Rect2 = b._card_rect()
				_assert(fa == fb, "A card that can wear a badge keeps one face rect at %s with count 0 or 5: %s vs %s" % [str(sz), str(fa), str(fb)])
				var e0: Rect2 = a.emblem_bounds()
				var e5: Rect2 = b.emblem_bounds()
				_assert(e0 == e5, "Art at %s (name=%s) keeps one rect with and without a count: %s vs %s" % [str(sz), str(nm), str(e0), str(e5)])
				_assert(e0.size.x > 4.0 and e0.size.y > 4.0, "Art at %s stays a real area" % str(sz))
				_assert(fa.grow(-2.0).encloses(e0), "Art at %s lies inside the face rect that is drawn, got %s vs %s" % [str(sz), str(e0), str(fa)])
				_assert(e0.position.y - fa.position.y >= 3.0, "Art at %s keeps at least 3px to the face top, got %.1f (%s in %s)" % [str(sz), e0.position.y - fa.position.y, str(e0), str(fa)])
				var badge: Rect2 = b.count_badge_rect()
				_assert(badge.size.x <= sz.x * 0.4 + 0.01, "Badge stays at most 40%% of the %s card" % str(sz))
				_assert(Rect2(Vector2.ZERO, sz).encloses(badge), "Badge at %s is never clipped by the card's own rect, got %s" % [str(sz), str(badge)])
				var over := badge.size.x / 3.0
				var quarter := Rect2(Vector2(sz.x * 0.5 - over, -over), Vector2(sz.x * 0.5 + over, sz.y * 0.5 + over))
				_assert(quarter.encloses(badge), "Badge at %s rides the top-right corner, got %s" % [str(sz), str(badge)])
				a.free()
				b.free()
	for sz in [Vector2(30, 42), Vector2(34, 47), Vector2(36, 84.4), Vector2(44, 61.6)]:
		var c := CardFace.new()
		c.size = sz
		c.kind = "resource"
		c.resource = GameTypes.ResourceType.CLAY
		c.count_badge = true
		c.count_clickable = true
		c.count = 3
		_assert(c.count_hit_rect().encloses(c.count_badge_rect()), "The drawn badge at %s sits inside its clickable hit rect, got %s vs %s" % [str(sz), str(c.count_badge_rect()), str(c.count_hit_rect())])
		c.free()
	var st = ui.session.state
	st.players[0]["hand"][TIMBER] = 0
	st.players[0]["hand"][CLAY] = 3
	ui._refresh_ui()
	await _ui_settle(2)
	var zero_card: CardFace = ui._res_card_refs[TIMBER] as CardFace
	var three_card: CardFace = ui._res_card_refs[CLAY] as CardFace
	var fz: Rect2 = zero_card._card_rect()
	var ft: Rect2 = three_card._card_rect()
	_assert(fz.position.y == ft.position.y and fz.size.y == ft.size.y, "In the live hand row the x0 and x3 cards share one frame top and height, got %s vs %s" % [str(fz), str(ft)])
	_assert(zero_card.emblem_bounds() == three_card.emblem_bounds(), "In the live hand row the x0 and x3 cards draw art at one rect, got %s vs %s" % [str(zero_card.emblem_bounds()), str(three_card.emblem_bounds())])
	var bank_fleece: CardFace = ui._bank_faces[GameTypes.ResourceType.FLEECE] as CardFace
	var bank_f: Rect2 = bank_fleece._card_rect()
	_assert(not bool(bank_fleece.count_badge) and bank_f.position.y < 5.0, "A badgeless bank card keeps its full-height frame, got %s" % str(bank_f))
	_pass_section("137. Count Badge Over Art Test (frame and art one rect for count 0 and 5, badge rides the top-right corner)")

func _p34_lum_ch(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)

func _p34_lum(c: Color) -> float:
	return 0.2126 * _p34_lum_ch(c.r) + 0.7152 * _p34_lum_ch(c.g) + 0.0722 * _p34_lum_ch(c.b)

func _p34_box(c: Control) -> StyleBoxFlat:
	return c.get_theme_stylebox("panel") as StyleBoxFlat

func _p34_border_all(st: StyleBoxFlat) -> bool:
	return st.border_width_left == 1 and st.border_width_right == 1 and st.border_width_top == 1 and st.border_width_bottom == 1

func _p34_any_modal_box(overlay: Node) -> StyleBoxFlat:
	for c in overlay.find_children("*", "PanelContainer", true, false):
		var st := _p34_box(c as Control)
		if st != null and st.border_width_left >= 1 and st.bg_color.a >= 0.9:
			return st
	return null

func _p34r_overlay_check(panel: Control, tag: String, name: String) -> void:
	# Nothing visible may be painted over a raised panel's fill with a colour
	# of its own: every stylebox background in the panel's subtree is either
	# fully transparent or exactly the panel's own fill colour.
	var fill := _p34_box(panel).bg_color
	_assert(fill.a >= 0.9, "%s: the %s paints an opaque fill" % [tag, name])
	var nodes: Array = [panel]
	nodes.append_array(panel.find_children("*", "Control", true, false))
	for n in nodes:
		if not (n is Control) or not is_instance_valid(n):
			continue
		var c := n as Control
		for sb_name in ["panel", "normal", "background", "hover", "pressed", "disabled", "focus"]:
			if not c.has_theme_stylebox_override(sb_name):
				continue
			var st := c.get_theme_stylebox(sb_name) as StyleBoxFlat
			if st == null or st.bg_color.a <= 0.05:
				continue
			_assert(
				st.bg_color == fill,
				"%s: %s paints %s over the %s fill with %s" % [tag, c.name, sb_name, name, st.bg_color.to_html(true)]
			)

func _p34_lock_rects(ui: Node, tag: String, expected: Dictionary) -> void:
	var found := {
		"log_panel": ui._log_panel,
		"trade_slot": ui._trade_slot,
		"trade_frame": ui._trade_frame,
		"trade_tray": ui._trade_tray,
		"right_panel": ui._right_panel,
		"hand_bar": ui._hand_bar_panel,
		"offer_strip": ui._offer_strip,
		"board": ui._board_view,
	}
	var heading: Array = ui._sidebar_box.find_children("*", "Label", true, false)
	for h in heading:
		if (h as Label).text == "EVENT LOG":
			found["log_heading"] = h as Control
			break
	var k := 0
	for row in ui._scoreboard_box.get_children():
		found["sb_row_%d" % k] = row as Control
		k += 1
	for name in expected:
		var c: Control = found.get(name)
		_assert(c != null and is_instance_valid(c), "%s: lock node %s exists" % [tag, String(name)])
		if c == null or not is_instance_valid(c):
			continue
		var got := c.get_global_rect()
		var want: Rect2 = expected[name]
		_assert(
			got.position.distance_to(want.position) < 0.01 and got.size.distance_to(want.size) < 0.01,
			"%s: %s keeps its rect, got %s want %s" % [tag, String(name), str(got), str(want)]
		)

func _p34_chrome_checks(ui: Node, tag: String) -> void:
	var side := _p34_box(ui._right_panel)
	var trade := _p34_box(ui._trade_frame)
	var log := _p34_box(ui._log_panel)
	var tray := _p34_box(ui._trade_tray)
	_assert(side != null and trade != null and log != null and tray != null, "%s: the sidebar boxes carry their styleboxes" % tag)
	if side == null or trade == null or log == null or tray == null:
		return
	# A. fine lines: one pixel on every area box, one frame around trade content.
	_assert(side.border_width_left == 1 and side.border_color == Palette.PANEL_LINE, "%s: the board/sidebar divider is a fine line" % tag)
	_assert(trade.border_width_left == 1 and trade.border_color == Palette.PANEL_LINE, "%s: the trade panel has one 1 px frame" % tag)
	_assert(tray.border_width_left == 0 and tray.border_width_right == 0 and tray.border_width_top == 0 and tray.border_width_bottom == 0, "%s: the tray draws no second frame" % tag)
	_assert(log.border_width_left == 1 and log.border_color == Palette.PANEL_LINE, "%s: the event log box has a 1 px frame" % tag)
	var header := _p34_box(ui._header_panel)
	_assert(header != null and header.border_width_bottom == 0 and header.border_width_top == 0, "%s: the title band is a plain background with no line" % tag)
	var pill := _p34_box(ui._header_pill)
	_assert(pill != null and _p34_border_all(pill) and pill.border_color == Palette.PANEL_LINE, "%s: the title pill is a fine line" % tag)
	var hand := _p34_box(ui._hand_bar_panel)
	_assert(hand != null and hand.border_width_top == 1 and hand.border_color == Palette.PANEL_LINE, "%s: the line above the hand bar is fine" % tag)
	var strip := _p34_box(ui._offer_strip)
	_assert(strip != null and _p34_border_all(strip) and strip.border_color == Palette.PANEL_LINE, "%s: the offer strip has a fine outline" % tag)
	var logpop := _p34_box(ui._log_popup)
	_assert(logpop != null and _p34_border_all(logpop) and logpop.border_color == Palette.PANEL_LINE, "%s: the expanded event log has a fine outline" % tag)
	var costs := _p34_box(ui._costs_popup)
	_assert(costs != null and _p34_border_all(costs) and costs.border_color == Palette.PANEL_LINE, "%s: the costs popup has a fine outline" % tag)
	for modal_name in ["_lobby_overlay", "_settings_overlay", "_help_overlay", "_replays_overlay", "_splash_overlay"]:
		var overlay: Node = ui.get(modal_name)
		var box := _p34_any_modal_box(overlay)
		_assert(box != null and _p34_border_all(box) and box.border_color == Palette.PANEL_LINE, "%s: the %s frame is a fine line" % [tag, String(modal_name)])
	# B. raised trade panel and log box: equal shadows, one step above the sidebar.
	_assert(trade.shadow_size > 0 and trade.shadow_size == log.shadow_size, "%s: trade and log share a drop shadow" % tag)
	_assert(trade.shadow_color == log.shadow_color and trade.shadow_offset == log.shadow_offset, "%s: the two shadows are identical" % tag)
	_assert(trade.bg_color == log.bg_color, "%s: trade and log share the raised fill" % tag)
	_assert(tray.bg_color == log.bg_color, "%s: the tray fill matches the raised fill" % tag)
	# B1 (p34r): the frame is a closed card — 1 px line and radius 8 on all four
	# sides — and it is inset inside the clipping slot so its whole bottom
	# shadow draws instead of being cut off at the slot's lower edge.
	_assert(_p34_border_all(trade), "%s: the trade frame is a 1 px line on all four sides" % tag)
	_assert(
		trade.corner_radius_top_left == 8 and trade.corner_radius_top_right == 8 and trade.corner_radius_bottom_left == 8 and trade.corner_radius_bottom_right == 8,
		"%s: the trade frame rounds all four corners at 8 px" % tag
	)
	var slot_r: Rect2 = ui._trade_slot.get_global_rect()
	var frame_r: Rect2 = ui._trade_frame.get_global_rect()
	_assert(
		frame_r.position.x >= slot_r.position.x - 0.01 and frame_r.position.y >= slot_r.position.y - 0.01 and frame_r.end.x <= slot_r.end.x + 0.01 and frame_r.end.y <= slot_r.end.y + 0.01,
		"%s: the drawn trade frame lies inside the slot's clip rect (%s in %s)" % [tag, str(frame_r), str(slot_r)]
	)
	_assert(
		frame_r.end.y + trade.shadow_offset.y + trade.shadow_size <= slot_r.end.y + 0.01,
		"%s: the trade frame leaves the full shadow reach below it inside the clip rect" % tag
	)
	_assert(frame_r.position.x == slot_r.position.x and frame_r.end.x == slot_r.end.x, "%s: the trade frame keeps the slot's side lines" % tag)
	_assert(frame_r.position.y == slot_r.position.y, "%s: the trade frame keeps the slot's top line" % tag)
	# B2 (p34r): nothing painted over either raised panel's fill with its own colour.
	_p34r_overlay_check(ui._log_panel, tag, "event log box")
	_p34r_overlay_check(ui._trade_frame, tag, "trade frame")
	var side_l := _p34_lum(side.bg_color)
	var fill_l := _p34_lum(trade.bg_color)
	_assert(fill_l - side_l >= 0.03, "%s: the raised fill is visibly above the sidebar (%.3f vs %.3f)" % [tag, fill_l, side_l])
	# C0/C. rows read the paper direction in both styles.
	for row in ui._scoreboard_box.get_children():
		var card_box: Control = null
		for chn in (row as Control).get_children():
			if chn is PanelContainer:
				card_box = chn as Control
				break
		if card_box == null:
			continue
		var rst := _p34_box(card_box)
		if rst == null or rst.bg_color.a < 0.9:
			continue
		_assert(_p34_lum(rst.bg_color) > side_l, "%s: a scoreboard row sits above the sidebar fill" % tag)
		_assert(rst.shadow_size >= 3, "%s: scoreboard rows carry the light shadow" % tag)

func _test_fine_line_chrome_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(77313, seats, true, 0)
	await _ui_settle(6)
	var ok := _ui_drive_until(ui, func(st: GameState) -> bool:
		return st.phase == GameTypes.TurnPhase.TURN_MAIN and not ui.session.is_ai_to_act() and st.open_trade.is_empty() and ui.session.get_acting_player_id() == 0
	)
	_assert(ok, "the fine line chrome test reached the human's main phase")
	var st: GameState = ui.session.state
	for r in GameTypes.ALL_RESOURCES:
		st.players[0]["hand"][r] = 4
		st.players[1]["hand"][r] = 4
		st.players[2]["hand"][r] = 4
	ui._close_trade_tray_by_user()
	ui._refresh_ui()
	root.size = Vector2i(1280, 800)
	await _ui_settle(4)
	_style_poke_theme(ui)
	await _ui_settle(4)
	_style_poke_theme(ui)
	await _ui_settle(6)
	# The locked rects recorded from the pre-restyle build (both styles agree).
	var expected := {
		"log_heading": Rect2(772, 543, 460, 20),
		"log_panel": Rect2(772, 568, 496, 94),
		"trade_slot": Rect2(772, 346, 496, 192),
		"trade_frame": Rect2(772, 346, 496, 183),
		"trade_tray": Rect2(788, 349, 478, 177),
		"right_panel": Rect2(760, 52, 520, 620),
		"hand_bar": Rect2(0, 702, 1280, 98),
		"offer_strip": Rect2(0, 672, 1280, 30),
		"board": Rect2(0, 52, 760, 620),
		"sb_row_0": Rect2(772, 83, 496, 34),
		"sb_row_1": Rect2(772, 121, 496, 34),
		"sb_row_2": Rect2(772, 159, 496, 34),
		"sb_row_3": Rect2(772, 197, 496, 34),
	}
	_p34_lock_rects(ui, "paper", expected)
	_p34_chrome_checks(ui, "paper")
	var counter: PanelContainer = ui._make_counter_partner_card(
		"Dune", GameTypes.PLAYER_COLORS[1 % GameTypes.PLAYER_COLORS.size()], 1,
		{"offer": {GameTypes.ResourceType.TIMBER: 1}, "request": {GameTypes.ResourceType.GRAIN: 1}},
		ui.session.state, false, -1
	)
	_assert(counter != null, "the counter-offer card builds for the frame check")
	if counter != null:
		var cbox := _p34_box(counter)
		_assert(cbox != null and cbox.border_width_left == 2 and cbox.border_color == Palette.ACCENT_GOLD, "the counter-offer frame keeps its 2 px gold line")
		counter.free()
	ui.set_ui_style("dark")
	await _ui_settle(6)
	_p34_lock_rects(ui, "dark", expected)
	_p34_chrome_checks(ui, "dark")
	ui._show_toast("p34 chrome probe", Palette.TOAST_TRADE_BG, 30.0)
	await _ui_settle(2)
	var toast_box: StyleBoxFlat = null
	for c in ui._toast_layer.get_children(true):
		if c is PanelContainer:
			var tst := _p34_box(c as Control)
			if tst != null and tst.bg_color.a >= 0.9:
				toast_box = tst
	_assert(toast_box != null and toast_box.border_width_left == 1, "the toast on the board carries a 1 px tinted frame")
	var dark_shadow: Color = Palette.STYLES["dark"]["SHADOW_RAISED"]
	var raised_dark: Color = Palette.STYLES["dark"]["SURFACE_RAISED"]
	_assert(_p34_lum(raised_dark) - _p34_lum(Palette.STYLES["dark"]["PANEL_BG_ALT"]) >= 0.03, "the dark raised fill sits one step above the sidebar")
	_assert(dark_shadow.a >= 0.5, "the dark raised shadow is stronger than paper's")
	ui.set_ui_style("paper")
	await _ui_settle(4)
	var back_trade := _p34_box(ui._trade_frame)
	var back_log := _p34_box(ui._log_panel)
	var back_tray := _p34_box(ui._trade_tray)
	var paper_fill: Color = Palette.STYLES["paper"]["SURFACE_RAISED"]
	_assert(
		back_trade != null and back_trade.bg_color == paper_fill and back_log.bg_color == paper_fill and back_tray.bg_color == paper_fill,
		"toggling back repainted the trade frame, the tray and the log box with the paper fill"
	)
	_p34r_overlay_check(ui._log_panel, "paper-back", "event log box")
	_p34r_overlay_check(ui._trade_frame, "paper-back", "trade frame")
	_pass_section("138. Fine Line Chrome & Raised Panels Test (1 px area lines, one trade frame, equal raised shadows, row direction and rects locked in both styles)")


func _p36_top_bar_checks(ui: Node, tag: String, expect_band_w: float) -> void:
	var band_r: Rect2 = ui._header_panel.get_global_rect()
	_assert(
		band_r.position == Vector2.ZERO and absf(band_r.size.x - expect_band_w) < 0.01 and band_r.size.y == 52,
		"%s: the band keeps its full height and the canvas width %.1f (%s)" % [tag, expect_band_w, str(band_r)]
	)
	var m := clampf(band_r.size.x * 0.0375, 24.0, 96.0)
	var pill_r: Rect2 = ui._header_pill.get_global_rect()
	_assert(
		pill_r.position.distance_to(Vector2(m, 6.0)) < 0.01 and pill_r.size.distance_to(Vector2(band_r.size.x - 2.0 * m, 40.0)) < 0.01,
		"%s: the pill is 40 px tall, centred at x %.2f (got %s)" % [tag, m, str(pill_r)]
	)
	var ps := _p34_box(ui._header_pill)
	_assert(ps != null, "%s: the pill carries a flat stylebox" % tag)
	if ps == null:
		return
	_assert(
		ps.corner_radius_top_left == 20 and ps.corner_radius_top_right == 20 and ps.corner_radius_bottom_left == 20 and ps.corner_radius_bottom_right == 20,
		"%s: the pill ends are fully rounded (radius = half height)" % tag
	)
	_assert(_p34_border_all(ps) and ps.border_color == Palette.PANEL_LINE, "%s: the pill has a 1 px fine line" % tag)
	_assert(ps.bg_color == Palette.SURFACE_RAISED, "%s: the pill is raised surface" % tag)
	_assert(ps.shadow_color == Palette.SHADOW_RAISED, "%s: the pill shadow uses the raised shadow colour" % tag)
	_assert(ps.shadow_size == 4 and ps.shadow_offset == Vector2(0, 1), "%s: the pill shadow is the reduced island size" % tag)
	_assert(pill_r.end.y + ps.shadow_offset.y + ps.shadow_size <= 52.0 + 0.01, "%s: the pill shadow fits inside the band below the pill" % tag)
	var title: Label = null
	for c in ui._header_pill.find_children("*", "Label", true, false):
		if (c as Label).text == "Founders: Barter & Block":
			title = c as Label
			break
	_assert(title != null, "%s: the title lives inside the pill" % tag)
	var inner := Rect2(pill_r.position + Vector2(14, 3), pill_r.size - Vector2(28, 6))
	var controls: Array = [ui._menu_btn, ui._help_costs_btn, ui._style_btn, ui._status_banner_label, ui._phase_label, title]
	if bool(ui._results_btn.visible):
		controls.append(ui._results_btn)
	if bool(ui._step_top_btn.visible):
		controls.append(ui._step_top_btn)
	for c in controls:
		var r: Rect2 = (c as Control).get_global_rect()
		_assert(
			r.position.x >= inner.position.x - 0.01 and r.end.x <= inner.end.x + 0.01 and r.position.y >= inner.position.y - 0.01 and r.end.y <= inner.end.y + 0.01,
			"%s: %s stays 14/3 px inside the pill (%s in %s)" % [tag, (c as Node).name, str(r), str(inner)]
		)
	_assert((ui._status_banner_label as Control).size.x > 0.0, "%s: the banner still gets real width (%.1f)" % [tag, (ui._status_banner_label as Control).size.x])

func _p36_neighbour_locks(ui: Node) -> void:
	var wanted := {
		"board": Rect2(0, 52, 760, 620),
		"sidebar": Rect2(760, 52, 520, 620),
		"strip": Rect2(0, 672, 1280, 30),
		"hand": Rect2(0, 702, 1280, 98),
	}
	var found := {
		"board": ui._board_view,
		"sidebar": ui._right_panel,
		"strip": ui._offer_strip,
		"hand": ui._hand_bar_panel,
	}
	for name in wanted:
		var r: Rect2 = (found[name] as Control).get_global_rect()
		_assert(r == wanted[name], "%s moved, got %s want %s" % [name, str(r), str(wanted[name])])

func _test_island_top_bar_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	await _ui_settle(2)
	if ui._splash_overlay != null and ui._splash_overlay.visible:
		ui._splash_overlay.visible = false
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Pike"),
		SeatConfig.new(3, SeatConfig.SeatType.AI_EASY, "Riven"),
	]
	ui.session.start_match(77313, seats, true, 0)
	await _ui_settle(6)
	ui._close_trade_tray_by_user()
	ui._refresh_ui()
	await _ui_settle(4)
	_p36_top_bar_checks(ui, "paper", 1280)
	_p36_neighbour_locks(ui)
	# The longest prompt in the game with "Step bot" visible: nothing moves out
	# of the pill, the banner ellipsizes instead of pushing.
	var banner_backup := String(ui._status_banner_label.text)
	var step_backup := bool(ui._step_top_btn.visible)
	ui._step_top_btn.visible = true
	ui._set_banner("Click a marked player to steal from, or click another hex \u2014 keys 1-4, Esc picks another tile")
	await _ui_settle(2)
	_p36_top_bar_checks(ui, "paper longest prompt + step bot", 1280)
	_assert(
		(ui._status_banner_label as Label).text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		"the banner still ellipsizes"
	)
	ui._set_banner(banner_backup)
	ui._step_top_btn.visible = step_backup
	await _ui_settle(2)
	var paper_fill: Color = Palette.STYLES["paper"]["SURFACE_RAISED"]
	var paper_line: Color = Palette.STYLES["paper"]["PANEL_LINE"]
	ui.set_ui_style("dark")
	await _ui_settle(6)
	_p36_top_bar_checks(ui, "dark", 1280)
	ui.set_ui_style("paper")
	await _ui_settle(6)
	var back_ps := _p34_box(ui._header_pill)
	_assert(
		back_ps != null and back_ps.bg_color == paper_fill and back_ps.border_color == paper_line,
		"switching back restores the exact paper pill pixels"
	)
	_p36_top_bar_checks(ui, "paper again", 1280)
	# The project stretches with canvas_items/expand: the layout canvas is
	# max(1280, window_w * 800 / window_h) wide at 800 canvas height, in a real
	# window exactly as in headless. A 1024x640 window therefore lays out on a
	# 1280-wide canvas (its on-screen side margin is then 38.4 px = the clamp
	# formula on the window width, scaled by 0.8); a 1600x900 window lays out
	# on a rounded 1600*800/900 = 1422 canvas. The clamp runs on the canvas
	# width; the real 1024 window is verified by screenshot.
	for size_pair in [[1024, 640, 1280.0], [1600, 900, roundf(1600.0 * 800.0 / 900.0)]]:
		var w: int = int(size_pair[0])
		var h: int = int(size_pair[1])
		root.size = Vector2i(w, h)
		await _ui_settle(6)
		_p36_top_bar_checks(ui, "%dx%d" % [w, h], float(size_pair[2]))
	root.size = Vector2i(1280, 800)
	await _ui_settle(6)
	_p36_top_bar_checks(ui, "back to 1280", 1280)
	# Real clicks: the menu popup still hangs under the menu button, the '?'
	# opens the costs popup and the pill's switcher flips the style both ways.
	_ui_real_click(ui._menu_btn)
	await _ui_settle(3)
	_assert(bool(ui._menu_popup.visible), "the real click opens the menu popup")
	var pop_pos: Vector2 = ui._menu_popup.position
	var pill_r: Rect2 = ui._header_pill.get_global_rect()
	_assert(
		pop_pos.x >= pill_r.position.x and pop_pos.y >= pill_r.end.y - 8.0 and pop_pos.y <= pill_r.end.y + 8.0,
		"the menu popup opens under the menu button just below the pill (%s vs pill %s)" % [str(pop_pos), str(pill_r)]
	)
	ui._menu_popup.hide()
	await _ui_settle(2)
	_ui_real_click(ui._help_costs_btn)
	await _ui_settle(3)
	_assert(bool(ui._costs_popup.visible), "the real click opens the build costs popup")
	ui._close_costs_popup()
	await _ui_settle(2)
	_ui_real_click(ui._style_btn)
	await _ui_settle(4)
	_assert(Palette.current_style == "dark", "the pill click switches to dark")
	_ui_real_click(ui._style_btn)
	await _ui_settle(4)
	_assert(Palette.current_style == "paper", "the pill click switches back to paper")
	_p36_top_bar_checks(ui, "after clicks", 1280)
	_pass_section("140. Floating Island Top Bar Test (plain 52 px band, centred 40 px pill, clamp margins at three widths, longest prompt, real clicks, both styles)")


# --- 141: audit batch A, text and mark contrast in both styles -----------------

func _p37a_toast_check(ui: Node, tab: Dictionary, tag: String) -> void:
	var tints: Array[Color] = []
	for pc in GameTypes.PLAYER_COLORS:
		tints.append(pc)
	for k in ["STATUS_WARN_TEXT", "STATUS_GOLD_SOFT_TEXT", "TOAST_STEAL_GOOD", "TOAST_STEAL_BAD", "TOAST_NEUTRAL", "HEADING"]:
		tints.append(tab[k])
	for tint in tints:
		var out: Color = ui._toast_text_on_pill(tint)
		var r := _contrast_ratio(out, tab["TOAST_PILL_BG"])
		_assert(r >= 4.5, "%s: toast text %s reaches 4.5:1 on the pill (%s = %.2f)" % [tag, str(tint), str(out), r])


func _p37a_badge_check(ui: Node, tag: String) -> void:
	for seat_color in GameTypes.PLAYER_COLORS:
		var pair: Array = ui._vp_badge_colors(seat_color)
		var r := _contrast_ratio(pair[1], pair[0])
		_assert(r >= 4.5, "%s: VP badge text clears 4.5:1 on the %s seat chip (%.2f)" % [tag, str(seat_color), r])
		var drift := absf((pair[0] as Color).r - seat_color.r) + absf((pair[0] as Color).g - seat_color.g) + absf((pair[0] as Color).b - seat_color.b)
		_assert(drift <= 0.15, "%s: the badge tint stays the seat colour (%s vs %s)" % [tag, str(pair[0]), str(seat_color)])


func _p37a_style_checks(ui: Node, style: String) -> void:
	ui.set_ui_style(style)
	var tab: Dictionary = Palette.STYLES[style]
	var tag := style
	_p37a_toast_check(ui, tab, tag)
	for g in ["ACCENT_GREEN", "BUTTON_GREEN_HOVER", "BUTTON_GREEN_PRESSED"]:
		var r := _contrast_ratio(tab["BUTTON_TEXT_ON_GREEN"], tab[g])
		_assert(r >= 4.5, "%s: End Turn text clears 4.5:1 on the green fill %s (%.2f)" % [tag, g, r])
	for bgk in ["SURFACE_RAISED", "ROW_BG", "ROW_BG_ACTIVE", "PANEL_BG_ALT", "PAPER_DARK"]:
		for fgk in ["STATUS_GOOD_TEXT", "STATUS_BAD_TEXT"]:
			var r2 := _contrast_ratio(tab[fgk], tab[bgk])
			_assert(r2 >= 4.5, "%s: status text %s clears 4.5:1 on %s (%.2f)" % [tag, fgk, bgk, r2])
	var hot: Color = tab["NUMBER_TOKEN_HOT"]
	var hot_bg := _contrast_ratio(hot, tab["NUMBER_TOKEN_BG"])
	_assert(hot_bg >= 4.5, "%s: hot token numbers clear 4.5:1 on the token (%.2f)" % [tag, hot_bg])
	_assert(
		_contrast_ratio(hot, tab["NUMBER_TOKEN_TEXT"]) >= 1.3,
		"%s: hot numbers stay apart from the normal ones (%.2f)" % [tag, _contrast_ratio(hot, tab["NUMBER_TOKEN_TEXT"])]
	)
	_assert(hot.r >= hot.g + 0.3 and hot.r >= hot.b + 0.3, "%s: hot numbers stay red (%s)" % [tag, str(hot)])
	var bar: Color = tab["PANEL_BG"]
	var pulse: Color = tab["DICE_PULSE_RING"]
	var ring := _contrast_ratio(bar.lerp(Color(pulse.r, pulse.g, pulse.b, 1.0), 0.85), bar)
	_assert(ring >= 3.0, "%s: the dice pulse ring reaches 3:1 on the hand bar (%.2f)" % [tag, ring])
	var dis: Color = tab["BUTTON_BG_DISABLED"]
	var recede := _contrast_ratio(dis, bar)
	_assert(recede <= 1.35, "%s: disabled fill recedes into the bar (%.2f)" % [tag, recede])
	var muted := _contrast_ratio(tab["TEXT_MUTED"], dis)
	_assert(muted >= 3.0, "%s: disabled labels stay readable (%.2f)" % [tag, muted])
	_assert(
		absf(_wcag_luminance(tab["BUTTON_BG_HOVER"]) - _wcag_luminance(bar))
			> absf(_wcag_luminance(tab["BUTTON_BG"]) - _wcag_luminance(bar)),
		"%s: hover moves away from the bar" % tag
	)
	_assert(
		_contrast_ratio(tab["AWARD_GUARD_PILL_TEXT"], tab["AWARD_GUARD_PILL_BG"]) >= 4.5,
		"%s: Guard pill text clears 4.5:1 on the pill" % tag
	)
	for rowk in ["ROW_BG", "ROW_BG_ACTIVE"]:
		var pill := _contrast_ratio(tab["AWARD_GUARD_PILL_BG"], tab[rowk])
		_assert(pill >= 3.0, "%s: Guard pill shows on the %s row (%.2f)" % [tag, rowk, pill])
		var seat_bg: Color = (tab[rowk] as Color).lerp(tab["PANEL_BORDER"], 0.28)
		var sr := _contrast_ratio(tab["TEXT"], seat_bg)
		_assert(sr >= 4.5, "%s: seat-type text clears 4.5:1 on the pill over %s (%.2f)" % [tag, rowk, sr])
	_p37a_badge_check(ui, tag)
	if style == "dark":
		for b in ["PANEL_BG", "PANEL_BG_ALT"]:
			var br := _contrast_ratio(tab["PANEL_BORDER"], tab[b])
			_assert(br >= 3.0, "%s: outlines reach 3:1 on %s (%.2f)" % [tag, b, br])
	var ghost: StyleBoxFlat = ui._step_top_btn.get_theme_stylebox("disabled") as StyleBoxFlat
	_assert(ghost != null and ghost.bg_color.a < 0.05, "%s: a disabled ghost keeps a transparent fill" % tag)
	var normal_box: StyleBoxFlat = ui._end_turn_btn.get_theme_stylebox("disabled") as StyleBoxFlat
	_assert(normal_box != null and normal_box.bg_color == dis, "%s: a disabled normal button uses the receding fill" % tag)


func _test_audit_contrast_batch_a_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	ui.auto_ai = false
	if ui._splash_overlay != null:
		ui._splash_overlay.visible = false
	ui._splash_shown = false
	await _ui_settle(4)
	var seats_ok := _ui_drive_until(ui, func(st: GameState) -> bool:
		return st.phase == GameTypes.TurnPhase.TURN_MAIN and not ui.session.is_ai_to_act() and st.open_trade.is_empty()
	)
	_assert(seats_ok, "the batch A contrast test reached the human's main phase")
	if not seats_ok:
		return
	await _ui_settle(3)
	_p37a_style_checks(ui, "paper")
	_p37a_style_checks(ui, "dark")
	_p37a_style_checks(ui, "paper")
	ui.set_ui_style("paper")
	await _ui_settle(3)
	_assert(Palette.current_style == "paper", "the batch A contrast test ends on paper")
	_pass_section("141. Audit Contrast Batch A Test (toasts, green End Turn, status text, hot tokens, badges, dice ring, disabled fill, hover, dark outlines, Guard pill, both styles)")

# --- 142: audit batch B, board and card art that must stay light in Dark -------

func _p37b_function_body(source: String, func_name: String) -> String:
	var marker := "func " + func_name
	var at := source.find(marker)
	_assert(at >= 0, "the source holds %s" % func_name)
	var rest := source.substr(at)
	var nxt := rest.find("\nstatic func", 1)
	if nxt < 0:
		nxt = rest.find("\nfunc ", 1)
	if nxt > 0:
		rest = rest.substr(0, nxt)
	return rest


func _p37b_art_style_checks(style: String) -> void:
	var tab: Dictionary = Palette.STYLES[style]
	var tag := style
	var fill_vs_outline := _contrast_ratio(tab["ART_LIGHT"], tab["ART_INK"])
	_assert(fill_vs_outline >= 3.0, "%s: the build spot fill clears 3:1 on its outline (%.2f)" % [tag, fill_vs_outline])
	_assert(
		_contrast_ratio(tab["ART_LIGHT"], tab["ACCENT_GOLD"]) >= 1.5,
		"%s: the light spot fill stays apart from its gold rim (%.2f)" % [tag, _contrast_ratio(tab["ART_LIGHT"], tab["ACCENT_GOLD"])]
	)
	for tkey in tab:
		var tk := String(tkey)
		if not (
			tk.begins_with("FOREST") or tk.begins_with("PASTURE") or tk.begins_with("FIELD")
				or tk.begins_with("CLAY") or tk.begins_with("MOUNTAIN") or tk.begins_with("BARREN") or tk.begins_with("SEA")
		):
			continue
		var surf: Color = tab[tkey]
		if _contrast_ratio(tab["ART_LIGHT"], surf) < 3.0 and _contrast_ratio(tab["ART_INK"], surf) < 3.0:
			_assert(false, "%s: the build spot reads on %s (fill %.2f, outline %.2f)" % [tag, tk, _contrast_ratio(tab["ART_LIGHT"], surf), _contrast_ratio(tab["ART_INK"], surf)])
	for bgk in ["PANEL_BG", "PANEL_BG_ALT", "ROW_BG", "ROW_BG_ACTIVE", "SURFACE_RAISED"]:
		var sr := _contrast_ratio(tab["INK_OUTLINE"], tab[bgk])
		_assert(sr >= 3.0, "%s: seat swatch outlines clear 3:1 on %s (%.2f)" % [tag, bgk, sr])
	var dr := _contrast_ratio(tab["PANEL_BORDER"], tab["DICE_FACE"])
	_assert(dr >= 3.0, "%s: the die outline clears 3:1 on the die face (%.2f)" % [tag, dr])
	var dbr := _contrast_ratio(tab["PANEL_BORDER"], tab["PANEL_BG"])
	_assert(dbr >= 3.0, "%s: the die outline clears 3:1 on the hand bar (%.2f)" % [tag, dbr])
	var chip: Color = tab["EMBLEM_CHIP_BG"]
	if style == "paper":
		_assert(chip.a == 0.0, "paper draws no emblem chip behind the art (alpha %.2f)" % chip.a)
	else:
		for bgk2 in ["PANEL_BG", "PANEL_BG_ALT", "SURFACE_RAISED", "ROW_BG"]:
			var cr2 := _contrast_ratio(chip, tab[bgk2])
			_assert(cr2 >= 3.0, "%s: the emblem chip clears 3:1 on %s (%.2f)" % [tag, bgk2, cr2])
		_assert(
			_contrast_ratio(tab["ART_INK"], chip) >= 3.0,
			"%s: emblem ink clears 3:1 on the chip (%.2f)" % [tag, _contrast_ratio(tab["ART_INK"], chip)]
		)
		_assert(
			_contrast_ratio(tab["INK"], chip) >= 3.0,
			"%s: the fixed emblems' ink clears 3:1 on the chip (%.2f)" % [tag, _contrast_ratio(tab["INK"], chip)]
		)
	var blend: Color = Color(0.97, 0.94, 0.86).lerp(tab["DISABLED_CARD"], 0.55)
	var name_r := _contrast_ratio(tab["INK"], blend)
	_assert(name_r >= 4.5, "%s: a disabled card's name clears 4.5:1 on the dimmed face (%.2f)" % [tag, name_r])
	var art_r := _contrast_ratio(blend.lerp(Color(tab["INK"].r, tab["INK"].g, tab["INK"].b, 1.0), 0.7), blend)
	_assert(art_r >= 3.0, "%s: a disabled card's art clears 3:1 on the dimmed face (%.2f)" % [tag, art_r])
	if style == "paper":
		_assert(
			_contrast_ratio(blend, tab["PANEL_BG"]) >= 1.6,
			"paper: the dimmed card face stands off the bar (%.2f)" % _contrast_ratio(blend, tab["PANEL_BG"])
		)
	else:
		_assert(
			_contrast_ratio(blend, tab["PANEL_BG"]) >= 5.0,
			"dark: the dimmed card face stands off the bar (%.2f)" % _contrast_ratio(blend, tab["PANEL_BG"])
		)


func _test_art_batch_b_body(ui: Node) -> void:
	var paper: Dictionary = Palette.STYLES["paper"]
	var dark: Dictionary = Palette.STYLES["dark"]
	for fixed_key in ["ART_LIGHT", "ART_INK", "DISABLED_CARD"]:
		var fk := String(fixed_key)
		_assert(paper[fk] == dark[fk], "%s is the identical colour in both style tables" % fk)
	_p37b_art_style_checks("paper")
	_p37b_art_style_checks("dark")
	var board_src := FileAccess.get_file_as_string("res://scripts/board_view.gd")
	var paper_rx := RegEx.create_from_string("Palette\\.PAPER\\b")
	_assert(
		paper_rx.search_all(board_src).size() == 0,
		"board art no longer borrows PAPER as white (%d uses left)" % paper_rx.search_all(board_src).size()
	)
	var cf_src := FileAccess.get_file_as_string("res://scripts/card_face.gd")
	var ink_rx := RegEx.create_from_string("Palette\\.INK\\b")
	for pair in [[_p37b_function_body(cf_src, "_emblem_roadwork"), "road work"], [_p37b_function_body(cf_src, "_emblem_decree"), "decree"]]:
		var body_text := String(pair[0])
		_assert(body_text.contains("Palette.ART_LIGHT"), "%s art keeps its light parts light" % String(pair[1]))
		_assert(body_text.contains("Palette.ART_INK"), "%s art keeps its dark parts dark" % String(pair[1]))
		_assert(paper_rx.search_all(body_text).size() == 0, "%s art does not borrow PAPER (%d uses)" % [String(pair[1]), paper_rx.search_all(body_text).size()])
		_assert(ink_rx.search_all(body_text).size() == 0, "%s art does not borrow INK (%d uses)" % [String(pair[1]), ink_rx.search_all(body_text).size()])
	var die_body := _p37b_function_body(FileAccess.get_file_as_string("res://scripts/main_ui.gd"), "_draw_die")
	_assert(die_body.contains("Palette.PANEL_BORDER"), "the die border uses the chrome outline like the pill's")
	_assert(ink_rx.search_all(die_body).size() == 0, "the die border no longer borrows INK (%d uses)" % ink_rx.search_all(die_body).size())
	var ui_src := FileAccess.get_file_as_string("res://scripts/main_ui.gd")
	_assert(ui_src.contains("func _set_seat_swatch_color"), "seat swatches are built with a styled helper")
	var swatch_helper := _p37b_function_body(ui_src, "_set_seat_swatch_color")
	_assert(swatch_helper.contains("INK_OUTLINE"), "every seat swatch carries the style outline")
	_assert(cf_src.contains("EMBLEM_CHIP_BG"), "emblem-only faces can sit on a light chip")
	_assert(cf_src.contains("DISABLED_CARD"), "disabled cards fade to the fixed disabled colour")
	ui.set_ui_style("dark")
	await _ui_settle(2)
	_assert(Palette.EMBLEM_CHIP_BG.a > 0.5, "dark switches the emblem chip on at runtime")
	ui.set_ui_style("paper")
	await _ui_settle(2)
	_assert(Palette.current_style == "paper", "the batch B art test ends on paper")
	_pass_section("142. Audit Art Batch B Test (build spots, board art, card art, emblem chips, die outlines, swatch outlines, disabled cards, both styles)")

# --- 143: audit batch C, controls that were never themed (both styles) ---------

func _p37c_control_checks(ui: Node, style: String) -> void:
	ui.set_ui_style(style)
	await _ui_settle(2)
	var tab: Dictionary = Palette.STYLES[style]
	var tag := style
	var boxes: Array = []
	for c in ui.find_children("*", "CheckBox", true, false):
		if c is CheckBox:
			boxes.append(c)
	_assert(boxes.size() >= 4, "%s: enough checkboxes exist to check every state" % tag)
	var seen_checked := false
	var seen_unchecked := false
	var idx := 0
	for b in boxes:
		var cb := b as CheckBox
		if idx % 2 == 0:
			cb.button_pressed = true
		idx += 1
		if cb.button_pressed:
			seen_checked = true
		else:
			seen_unchecked = true
		_assert(cb.theme == ui._check_theme, "%s: the checkbox uses the shared check theme" % tag)
		for item_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
			var item := StringName(item_name)
			var col: Color = cb.get_theme_color(item)
			_assert(col != Color(1, 1, 1, 1), "%s: %s is themed on the checkbox" % [tag, item_name])
			for bgk in ["PANEL_BG", "PANEL_BG_ALT"]:
				var r := _contrast_ratio(col, tab[bgk])
				_assert(r >= 4.5, "%s: checkbox %s clears 4.5:1 on %s (%.2f)" % [tag, item_name, bgk, r])
	_assert(seen_checked and seen_unchecked, "%s: both checked and unchecked boxes were seen" % tag)
	for icon_name in ["unchecked", "checked", "unchecked_disabled", "checked_disabled"]:
		_assert(ui._check_theme.get_icon(StringName(icon_name), &"CheckBox") != null, "%s: the %s box draws a custom icon" % [tag, icon_name])
	var box_outline_r := _contrast_ratio(tab["CHECK_BORDER"], tab["PANEL_BG"])
	_assert(box_outline_r >= 3.0, "%s: the unchecked box outline clears 3:1 on the dialog (%.2f)" % [tag, box_outline_r])
	var icon_btns := 0
	for c in ui.find_children("*", "Button", true, false):
		var bt := c as Button
		if bt.icon == null:
			continue
		icon_btns += 1
		for pair in [["icon_normal_color", "font_color"], ["icon_hover_color", "font_hover_color"], ["icon_pressed_color", "font_pressed_color"], ["icon_hover_pressed_color", "font_hover_color"], ["icon_focus_color", "font_focus_color"], ["icon_disabled_color", "font_disabled_color"]]:
			_assert(bt.get_theme_color(StringName(str(pair[0]))) == bt.get_theme_color(StringName(str(pair[1]))), "%s: the %s %s follows %s" % [tag, bt.name, pair[0], pair[1]])
		var itex: Image = (bt.icon as ImageTexture).get_image()
		var white := true
		for py in range(itex.get_height()):
			for px in range(itex.get_width()):
				var pc := itex.get_pixel(px, py)
				if pc.a > 0.95 and (absf(pc.r - 1.0) > 0.01 or absf(pc.g - 1.0) > 0.01 or absf(pc.b - 1.0) > 0.01):
					white = false
		_assert(white, "%s: the %s icon texture is a white stencil" % [tag, bt.name])
	_assert(icon_btns >= 3, "%s: the icon buttons exist to check (%d)" % [tag, icon_btns])
	var et_was_disabled: bool = ui._end_turn_btn.disabled
	ui._end_turn_btn.disabled = true
	_assert(ui._end_turn_btn.get_theme_color("icon_disabled_color") == ui._end_turn_btn.get_theme_color("font_disabled_color"), "%s: a bare disabled flip still colours the icon like the text" % tag)
	ui._end_turn_btn.disabled = et_was_disabled
	var opt: OptionButton = ui._num_players_opt
	_assert(opt.has_theme_icon_override(&"arrow"), "%s: the dropdown arrow is the palette-coloured icon" % tag)
	var arrow_r := _contrast_ratio(tab["TEXT"], tab["BUTTON_BG"])
	_assert(arrow_r >= 3.0, "%s: the dropdown arrow clears 3:1 on the fill (%.2f)" % [tag, arrow_r])
	var pop = opt.get_popup()
	_assert(pop.get_theme_icon(&"check", &"PopupMenu") != null, "%s: the open list gets a check icon" % tag)
	_assert(pop.get_theme_icon(&"radio_checked", &"PopupMenu") != null, "%s: the open list gets a filled radio" % tag)
	_assert(pop.get_theme_icon(&"radio_unchecked", &"PopupMenu") != null, "%s: the open list gets an empty radio" % tag)
	var speed_box: StyleBoxFlat = ui._review_speed_opt.get_theme_stylebox("normal") as StyleBoxFlat
	_assert(speed_box != null and speed_box.bg_color == tab["BUTTON_BG"], "%s: the review speed dropdown wears the standard option style" % tag)
	_assert(ui._review_speed_opt.has_theme_icon_override(&"arrow"), "%s: the review speed arrow matches the other dropdowns" % tag)
	var th: Theme = ui._ui_theme
	_assert(ui.theme == th, "%s: the root theme is applied at the UI root" % tag)
	var tip_box: StyleBoxFlat = th.get_stylebox(&"panel", &"TooltipPanel") as StyleBoxFlat
	_assert(tip_box != null and tip_box.bg_color == tab["SURFACE_RAISED"], "%s: the tooltip panel is the raised surface" % tag)
	_assert(tip_box.border_color == tab["PANEL_LINE"], "%s: the tooltip panel keeps the fine line" % tag)
	_assert(th.get_color(&"font_color", &"TooltipLabel") == tab["TEXT"], "%s: tooltip text is themed" % tag)
	var tip_r := _contrast_ratio(tab["TEXT"], tab["SURFACE_RAISED"])
	_assert(tip_r >= 4.5, "%s: tooltip text clears 4.5:1 on the tooltip panel (%.2f)" % [tag, tip_r])
	for bar_name in ["VScrollBar", "HScrollBar"]:
		var bn := StringName(bar_name)
		var track_box: StyleBoxFlat = th.get_stylebox(&"scroll", bn) as StyleBoxFlat
		var grab_box: StyleBoxFlat = th.get_stylebox(&"grabber", bn) as StyleBoxFlat
		_assert(track_box != null and grab_box != null, "%s: %s is themed" % [tag, bar_name])
		_assert(track_box.bg_color == tab["PANEL_BG_ALT"] and grab_box.bg_color == tab["PANEL_BORDER"], "%s: %s colours come from the palette" % [tag, bar_name])
		var bar_r := _contrast_ratio(tab["PANEL_BORDER"], tab["PANEL_BG_ALT"])
		_assert(bar_r >= 3.0, "%s: the %s grabber clears 3:1 on its track (%.2f)" % [tag, bar_name, bar_r])
	var slider_box: StyleBoxFlat = th.get_stylebox(&"slider", &"HSlider") as StyleBoxFlat
	var sfill_box: StyleBoxFlat = th.get_stylebox(&"grabber_area", &"HSlider") as StyleBoxFlat
	var sgrab_box: StyleBoxFlat = th.get_stylebox(&"grabber", &"HSlider") as StyleBoxFlat
	_assert(slider_box != null and sfill_box != null and sgrab_box != null, "%s: the slider is themed" % tag)
	_assert(slider_box.bg_color == tab["PANEL_BG_ALT"] and sfill_box.bg_color == tab["HEADING"] and sgrab_box.bg_color == tab["PANEL_BORDER"], "%s: the slider colours come from the palette" % tag)
	var fill_r := _contrast_ratio(tab["HEADING"], tab["PANEL_BG_ALT"])
	_assert(fill_r >= 3.0, "%s: the slider fill clears 3:1 on the track (%.2f)" % [tag, fill_r])
	for sep_name in ["VSeparator", "HSeparator"]:
		var line_box := th.get_stylebox(&"line", StringName(sep_name)) as StyleBoxLine
		_assert(line_box != null and line_box.color == tab["PANEL_BORDER"], "%s: the %s line is themed" % [tag, sep_name])
	_assert(ui._replays_overlay.color == Color(tab["SCRIM"], 0.62), "%s: the saved-replays backdrop uses the shared scrim" % tag)
	await _ui_settle(1)


func _p37c_steal_prompt_checks(ui: Node, tag: String) -> void:
	var st = ui.session.state
	var topo = HexMath.get_topology()
	var steal_tile := -1
	var victim := -1
	for v in range(st.vertex_owner.size()):
		var own: int = st.vertex_owner[v]
		if own > 0:
			var tiles: Array = topo.vertex_tiles[v]
			if not tiles.is_empty():
				steal_tile = int(tiles[0])
				victim = own
				break
	_assert(steal_tile >= 0, "%s: a victim settlement exists for the steal prompt test" % tag)
	if steal_tile < 0:
		return
	var victims: Array[int] = [victim]
	var no_verts: Array[int] = []
	var no_edges: Array[int] = []
	var tiles: Array[int] = []
	for t_id in range(st.tile_terrains.size()):
		if t_id != st.blocker_tile:
			tiles.append(t_id)
	ui._board_view.set_highlights(BoardView.InteractionMode.PICK_BLOCKER_TILE, no_verts, no_edges, tiles)
	ui._show_steal_targets(steal_tile, victims)
	await _ui_settle(2)
	var banner_before := String(ui._status_banner_label.text)
	_assert(banner_before.contains("Click a marked player"), "%s: the steal chooser prompts first (%s)" % [tag, banner_before])
	var next_style := "dark" if Palette.current_style == "paper" else "paper"
	ui.set_ui_style(next_style)
	await _ui_settle(2)
	_assert(String(ui._status_banner_label.text) == banner_before, "%s: a style switch keeps the steal banner" % tag)
	_assert(int(ui._steal_pending.get("tile_id", -2)) == steal_tile, "%s: a style switch keeps the pending steal tile" % tag)
	_assert((ui._board_view.get("_steal_targets") as Array).size() == 1, "%s: a style switch keeps the steal targets" % tag)
	ui.set_ui_style("paper")
	await _ui_settle(2)
	ui._cancel_steal_chooser()
	ui._update_mandatory_board_highlights(ui.session.state, ui.session.get_acting_player_id(), true)
	await _ui_settle(2)


func _test_controls_batch_c_body(ui: Node) -> void:
	root.size = Vector2i(1280, 800)
	ui.auto_ai = false
	if ui._splash_overlay != null:
		ui._splash_overlay.visible = false
	ui._splash_shown = false
	await _ui_settle(4)
	var seats_ok := _ui_drive_until(ui, func(st: GameState) -> bool:
		return st.turn_number >= 4 and st.phase == GameTypes.TurnPhase.TURN_MAIN and not ui.session.is_ai_to_act() and st.open_trade.is_empty()
	)
	_assert(seats_ok, "the batch C controls test reached the human's main phase")
	if not seats_ok:
		return
	await _ui_settle(3)
	await _p37c_control_checks(ui, "paper")
	await _p37c_control_checks(ui, "dark")
	await _p37c_control_checks(ui, "paper")
	await _p37c_steal_prompt_checks(ui, "live")
	_assert(Palette.current_style == "paper", "the batch C controls test ends on paper")
	_pass_section("143. Audit Controls Batch C Test (checkbox states and icons, button icons, dropdown arrows and marks, review bar, root theme, replays scrim, steal prompt, both styles)")
