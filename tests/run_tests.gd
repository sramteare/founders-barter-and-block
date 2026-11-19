extends SceneTree

var _passed: int = 0
var _failed: int = 0

const UI_SCRIPT_PATH := "res://scripts/main_ui.gd"
const TEST_SETTINGS_PATH := "user://test_settings.cfg"
var _ui_queue: Array[Callable] = []
var _pending_ui: Node = null
var _pending_body: Callable = Callable()

func _init() -> void:
	print("=== Founders: Barter & Block - Headless Test Suite ===")
	root.size = Vector2i(1400, 1100)
	var ui_script = load(UI_SCRIPT_PATH)
	ui_script.settings_path = TEST_SETTINGS_PATH
	_test_topology()
	_test_board_generator()
	_test_setup_and_distance_rule()
	_test_longest_route_and_splitting()
	_test_seven_roll_discard_and_blocker()
	_test_maritime_trade_and_action_cards()
	_test_open_trade_flow()
	_test_full_4bot_simulated_match()
	_test_main_scene_load()
	_test_road_work_real()
	_test_full_bot_match_2p_and_3p()
	_test_victory_hidden_charter()
	_test_city_upgrade()
	_test_blocker_steal()
	_test_discard_validation()
	_test_trade_response_guards()
	_test_difficulty3_stronger()
	_start_ui_tests()

func _process(_delta: float) -> bool:
	if not _ui_queue.is_empty():
		var job: Callable = _ui_queue.pop_front()
		job.call()
		if _ui_queue.is_empty():
			_finish_suite()
			return true
		return false
	_finish_suite()
	return true

func _queue_ui_test(seats: Array[SeatConfig], body: Callable) -> void:
	_ui_queue.append(func() -> void:
		var packed := ResourceLoader.load("res://scenes/main.tscn") as PackedScene
		_assert(packed != null, "main.tscn should load for the UI test")
		if packed == null:
			return
		var ui: Node = packed.instantiate()
		ui.auto_ai = false
		root.add_child(ui)
		_pending_ui = ui
		_pending_body = body
	)
	_ui_queue.append(func() -> void:
		var ui: Node = _pending_ui
		_pending_ui = null
		var b: Callable = _pending_body
		_pending_body = Callable()
		if ui == null:
			return
		if not ui.is_node_ready():
			_assert(false, "UI should be ready by the first processed frame")
			_ui_queue.append(func() -> void:
				ui.free()
			)
			return
		b.call(ui)
		_ui_queue.append(func() -> void:
			ui.free()
		)
	)

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
		var count_lbl: Label = ui._res_card_refs[r]["count"]
		if str(count_lbl.text) != "—":
			return false
	return true

func _finish_suite() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	load(UI_SCRIPT_PATH).settings_path = "user://settings.cfg"
	print("======================================================")
	print("Tests Passed: %d | Tests Failed: %d" % [_passed, _failed])
	if _failed > 0:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: ALL TESTS PASSED")
		quit(0)

func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("[FAIL] " + msg)

func _pass_section(title: String) -> void:
	print("[PASS] " + title)

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
	var expected_order: Array[int] = [0, 1, 2, 3, 3, 2, 1, 0]

	for step_idx in range(expected_order.size()):
		var p: int = expected_order[step_idx]
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

	_assert(state.phase == GameTypes.TurnPhase.TURN_ROLL and state.current_player == 0, "After snake draft, should enter TURN_ROLL for player 0")
	_pass_section("3. Setup & Distance Rule Test (snake draft 0,1,2,3,3,2,1,0, distance rule, starting resources)")

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

	_assert(session.get_acting_player_id() == 1, "Acting player should be lowest non-proposer without a response")

	var res_bad_accept: Dictionary = RulesEngine.apply_action(state, 3, GameAction.respond_open_trade("accept"))
	_assert(not bool(res_bad_accept.get("ok", false)), "Accept must fail without the requested resources")
	var responses_after_bad: Dictionary = state.open_trade["responses"]
	_assert(not responses_after_bad.has(3), "Failed accept must not record a response")

	var res_finalize_unanswered: Dictionary = RulesEngine.apply_action(state, 0, GameAction.finalize_open_trade(3))
	_assert(not bool(res_finalize_unanswered.get("ok", false)), "Finalize must fail with a non-responder")

	var res_accept_1: Dictionary = RulesEngine.apply_action(state, 1, GameAction.respond_open_trade("accept"))
	_assert(bool(res_accept_1.get("ok", false)), "Player 1 accept should succeed")
	_assert(session.get_acting_player_id() == 2, "Acting player should advance to player 2 after player 1 responds")
	var res_accept_2: Dictionary = RulesEngine.apply_action(state, 2, GameAction.respond_open_trade("accept"))
	_assert(bool(res_accept_2.get("ok", false)), "Player 2 accept should succeed")
	var res_decline_3: Dictionary = RulesEngine.apply_action(state, 3, GameAction.respond_open_trade("decline"))
	_assert(bool(res_decline_3.get("ok", false)), "Player 3 decline should succeed")
	_assert(session.get_acting_player_id() == 0, "Acting player should return to proposer once all have responded")

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
	diff_session.start_match(321, seats, true)
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
	human_session.start_match(654, human_seats, true)
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

	session.start_match(2026, seats, true)
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
	_pass_section("11. Two- and Three-Player Full Bot Match Tests (both reach GAME_OVER with 0 invalid actions)")

func _start_ui_tests() -> void:
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
	], _test_sfx_body)

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
		ui.session.start_match(candidate_seed, seats, true)
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
		var count_lbl: Label = ui._res_card_refs[r]["count"]
		_assert(count_lbl.text == "x%d" % int(st.players[1]["hand"].get(r, 0)), "Hand bar should show seat 1's count for resource %d" % r)
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
	var res_decline: Dictionary = ui.session.submit_action(0, GameAction.respond_open_trade("decline"))
	_assert(bool(res_decline.get("ok", false)), "Seat 0 should be able to decline seat 1's offer")
	while not ui.session.state.open_trade.is_empty() and ui.session.is_ai_to_act():
		ui.session.step_ai()
	_assert(int(ui.session.state.open_trade.get("from", -1)) == 1, "The offer should still belong to seat 1")
	_assert(ui.session.get_acting_player_id() == 1, "Control should return to seat 1 once everyone has answered")
	_assert(bool(ui._hand_hidden()), "Seat 1 must confirm the device again after the bot turns")
	ui._device_pass_btn.pressed.emit()
	_assert(bool(ui._trade_tray.is_visible_in_tree()), "Tray should have auto-opened for seat 1 without the test opening it")
	_assert(bool(ui._trade_summary_row.visible), "Seat 1 should see their own open-offer summary row")
	_assert(bool(ui._trade_withdraw_btn.visible) and not bool(ui._trade_withdraw_btn.disabled), "Withdraw should be visible and enabled for seat 1")
	_assert(bool(ui._trade_withdraw_btn.is_visible_in_tree()), "Withdraw button should be inside the visible tree")
	ui._trade_withdraw_btn.pressed.emit()
	_assert(ui.session.state.open_trade.is_empty(), "Pressing Withdraw should clear the open trade")
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
		ui.session.start_match(202500 + attempt * 101, seats, true)
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
			var count_lbl: Label = ui._res_card_refs[r]["count"]
			if str(count_lbl.text) != "x%d" % int(ui.session.state.players[acting]["hand"].get(r, 0)):
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
				if int(ui.session.state.players[p_id]["hand"].get(r, 0)) > 0:
					var lbl: Label = ui._res_card_refs[r]["count"]
					if str(lbl.text) == "x%d" % int(ui.session.state.players[p_id]["hand"].get(r, 0)):
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
			var lbl2: Label = ui._res_card_refs[r]["count"]
			if str(lbl2.text) != "x%d" % int(ui.session.state.players[acting2]["hand"].get(r, 0)):
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
		ui.session.start_match(202900 + attempt * 137, four, true)
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
	ui.session.start_match(203333, fix2_seats, true)
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
	ui.session.start_match(31337, solo, true)
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
	var acc_again: Dictionary = RulesEngine.apply_action(state, 1, GameAction.respond_open_trade("accept"))
	_assert(not bool(acc_again.get("ok", false)), "Responding twice to the same offer must be rejected")
	var bad_counter: Dictionary = RulesEngine.apply_action(state, 2, GameAction.respond_open_trade(
		"counter",
		{GameTypes.ResourceType.TIMBER: 1},
		{GameTypes.ResourceType.GRAIN: 1}
	))
	_assert(not bool(bad_counter.get("ok", false)), "A counter the responder cannot pay must be rejected")
	var dec: Dictionary = RulesEngine.apply_action(state, 2, GameAction.respond_open_trade("decline"))
	_assert(bool(dec.get("ok", false)), "Player 2 decline should succeed after a rejected counter")
	_pass_section("17. Trade Response Guards Test (double response and unpayable counters rejected)")

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
	ui.session.start_match(4711, seats, true)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["new_dev_cards"].append(GameTypes.DevCardType.GUARD)
	ui._refresh_ui()
	var guard_chip: Button = ui._action_chips[GameTypes.DevCardType.GUARD]
	_assert(bool(guard_chip.disabled), "A Guard bought this turn (new_dev_cards only) must show a disabled chip")
	_assert(str(guard_chip.text).contains("(new)"), "The chip label should flag the card bought this turn")
	_assert(str(guard_chip.tooltip_text).contains("Bought this turn"), "The disabled chip should explain the reason, got: %s" % str(guard_chip.tooltip_text))
	st.players[0]["new_dev_cards"].clear()
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.GUARD)
	ui._refresh_ui()
	_assert(not bool(guard_chip.disabled), "A Guard held in dev_cards should enable the chip")
	_assert(str(guard_chip.tooltip_text) == "Play Guard", "The enabled chip tooltip should say Play Guard, got: %s" % str(guard_chip.tooltip_text))
	st.players[0]["dev_cards"].clear()
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.CHARTER_POINT)
	ui._refresh_ui()
	var charter_chip: Button = ui._action_chips[GameTypes.DevCardType.CHARTER_POINT]
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
	ui.session.start_match(4712, seats, true)
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
	ui.session.start_match(4713, seats, true)
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
	ui.session.start_match(4714, seats, true)
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
	if bool(ui._trade_tray.visible):
		ui._toggle_trade_tray()
	ui._toggle_trade_tray()
	_assert(bool(ui._trade_tray.visible), "Human-opened tray is visible")
	_assert(not bool(ui._trade_opened_auto), "Human-opened tray must not be marked automatic")
	ui._ot_accept_btn.pressed.emit()
	var guard2 := 0
	while not ui.session.state.open_trade.is_empty() and guard2 < 200:
		guard2 += 1
		if ui.session.is_ai_to_act():
			ui.session.step_ai()
		else:
			break
	_assert(ui.session.state.open_trade.is_empty(), "Second offer should resolve")
	_assert(bool(ui._trade_tray.visible), "A tray the human opened themselves stays open after the offer resolves")
	_pass_section("23. Trade Tray Auto-Close Test (auto-opened closes on resolve; user-opened stays open)")

func _test_game_over_banner_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.HUMAN, "Coral"),
		SeatConfig.new(2, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(4715, seats, true)
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
	ui.session.start_match(4716, seats, true)
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
	ui.session.start_match(4717, seats, true)
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
