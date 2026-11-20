extends SceneTree

var _passed: int = 0
var _failed: int = 0

const UI_SCRIPT_PATH := "res://scripts/main_ui.gd"
const TEST_SETTINGS_PATH := "user://test_settings.cfg"
const NO_EVENTS: Array[String] = []
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
	_test_bank_conservation_match()
	_test_bank_production_rule()
	_test_bank_maritime_empty()
	_test_steal_victim_choice()
	_test_standings()
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
		var face: CardFace = ui._res_card_refs[r]
		if not bool(face.hidden_card):
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
	var guard_chip: CardFace = ui._action_chips[GameTypes.DevCardType.GUARD]
	_assert(bool(guard_chip.disabled), "A Guard bought this turn (new_dev_cards only) must show a disabled chip")
	_assert(int(guard_chip.count) == 1, "The Guard card should show count 1")
	_assert(str(guard_chip.tooltip_text).contains("Bought this turn"), "The disabled chip should explain the reason, got: %s" % str(guard_chip.tooltip_text))
	st.players[0]["new_dev_cards"].clear()
	st.players[0]["dev_cards"].append(GameTypes.DevCardType.GUARD)
	ui._refresh_ui()
	_assert(not bool(guard_chip.disabled), "A Guard held in dev_cards should enable the chip")
	_assert(str(guard_chip.tooltip_text).contains("new this turn") or str(guard_chip.tooltip_text).contains("Play Guard"), "Playable Guard tooltip explains, got: %s" % str(guard_chip.tooltip_text))
	_assert(str(guard_chip.tooltip_text) == "Play Guard", "The enabled chip tooltip should say Play Guard, got: %s" % str(guard_chip.tooltip_text))
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
	_assert(not bool(ui._trade_tray.visible), "The tray must close once the human is no longer part of the offer (bot-to-bot resolution)")
	_pass_section("23. Trade Tray Auto-Close Test (auto-opened closes on resolve; tray closes when the human is out of the loop)")

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
	ui.session.start_match(777001, seats, true)
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
	ui.session.start_match(777002, seats, true)
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
	ui.session.start_match(777003, seats, true)
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
	ui.session.start_match(777004, seats, true)
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
	ui.session.start_match(778000, seats, true)
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
	ui.session.start_match(778001, seats, true)
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
	ui.session.start_match(778002, seats, true)
	await ui.get_tree().process_frame
	ui._refresh_ui()
	_assert(ui._trade_close_btn.text == "✕", "The close button is just a cross, got %s" % ui._trade_close_btn.text)
	_assert(ui._trade_close_btn.tooltip_text.contains("Esc"), "The close tooltip still explains Esc")
	_assert(ui._trade_close_btn.custom_minimum_size == Vector2(28, 28), "The close button is a small square")
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
	ui.session.start_match(779001, seats, true)
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
	ui.session.start_match(779002, seats, true)
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
	ui.session.start_match(779003, seats, true)
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
	_assert(int(ui._flight_layer.get_child_count()) >= 1, "A bank flight to the viewer puts a flyer on the layer")
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
	ui.session.start_match(779004, seats, true)
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
	var accept_btn := _find_button_by_text(ui._trade_partner_row, "Accept counter")
	_assert(accept_btn != null, "Counter cards carry an Accept counter button")
	for b in [accept_btn, _find_button_by_text(ui._trade_partner_row, "Decline")]:
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
	ui.session.start_match(779065, seats, true)
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
	_assert(ui._trade_partner_row.get_child_count() == 1, "One partner card expected")
	var dcard: Node = ui._trade_partner_row.get_child(0)
	_assert(_find_label_containing(dcard, "COUNTER-OFFER"), "Counter card should carry the COUNTER-OFFER pill")
	_assert(_find_label_containing(dcard, "You give"), "Counter card should show the 'You give' row")
	_assert(_find_label_containing(dcard, "You get"), "Counter card should show the 'You get' row")
	var accept_btn := _find_button_by_text(dcard, "Accept counter")
	_assert(accept_btn != null, "Counter card should offer an Accept counter button")
	_assert(_find_button_by_text(dcard, "Trade") == null, "Counter card must not show the plain Trade button")
	_assert(bool(accept_btn.disabled), "Accept counter should be disabled while the offer cannot be paid")
	_assert(str(accept_btn.tooltip_text).begins_with("You don't have"), "Disabled accept tooltip mismatch: '%s'" % str(accept_btn.tooltip_text))
	_assert(_toast_texts(ui).contains("Dune counters: wants 2 Iron for 1 Grain"), "Counter should toast once, got '%s'" % _toast_texts(ui))
	var tcount: int = _toast_texts(ui).count("Dune counters: wants 2 Iron for 1 Grain")
	ui._refresh_ui()
	ui._refresh_ui()
	_assert(_toast_texts(ui).count("Dune counters: wants 2 Iron for 1 Grain") == tcount, "One toast per counter only")
	var dline := _find_button_by_text(dcard, "Decline")
	_assert(dline != null, "Counter card should offer a Decline button")
	var g0: int = int(st.players[0]["hand"].get(GameTypes.ResourceType.GRAIN, 0))
	st.players[0]["hand"][GameTypes.ResourceType.IRON] = 3
	ui._refresh_ui()
	await ui.get_tree().process_frame
	accept_btn = _find_button_by_text(ui._trade_partner_row, "Accept counter")
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
	var dcard2: Node = ui._trade_partner_row.get_child(0)
	var dline2 := _find_button_by_text(dcard2, "Decline")
	_assert(dline2 != null, "Second counter card should offer Decline")
	dline2.pressed.emit()
	await ui.get_tree().process_frame
	_assert(not st.open_trade.is_empty(), "Declining a counter is UI-only; the offer stays open")
	_assert(_find_button_by_text(ui._trade_partner_row, "Accept counter") == null, "Declined counter should drop the accept button")
	_assert(_find_label_containing(ui._trade_partner_row, "✗ Counter declined"), "Declined counter should show its status")
	_assert(bool(ui._trade_no_takers_lbl.visible), "All counters declined should surface the no-takers line")
	ui.session.submit_action(0, GameAction.cancel_open_trade())
	_assert(not bool(ui._trade_no_takers_lbl.visible), "No-takers line clears when the offer closes")
	ui.session.state.open_trades_this_turn = 0
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.IRON: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	_assert(not ui.session.state.open_trade.is_empty(), "The fresh offer must be open")
	_assert(ui._declined_counters.is_empty(), "A new offer must clear declined counters")
	_assert(_find_button_by_text(ui._trade_partner_row, "Accept counter") == null, "Fresh offer has no counter buttons")
	var st2: GameState = ui.session.state
	st2.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	ui.session.submit_action(1, GameAction.respond_open_trade("accept"))
	await ui.get_tree().process_frame
	_assert(_find_label_containing(ui._trade_partner_row, "✓ Accepts"), "Accepting bot still shows ✓ Accepts")
	_assert(_find_button_by_text(ui._trade_partner_row, "Trade") != null, "Accepting bot still shows the Trade button")
	_pass_section("65. Counter-Offer Card Test (pill, give/get rows, accept/decline, no-takers)")

func _test_dice_roll_show_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(779066, seats, true)
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
	_assert(int(ui._dice_show_count) == 1, "First show counted, got %d" % int(ui._dice_show_count))
	_assert(str(ui._dice_show_phase) == "travel", "Show starts in travel, got '%s'" % str(ui._dice_show_phase))
	_assert(ui._dice_show_node != null and ui._dice_show_node.get_parent() == ui._flight_layer, "Travelling dice live on the flight layer")
	_assert(ui._flight_layer.get_child_count() == 1, "Exactly one moving dice node, got %d" % ui._flight_layer.get_child_count())
	_assert(absf(ui._dice_widget.modulate.a) < 0.05, "Bar dice go ghost during the show")
	await ui.get_tree().create_timer(0.5).timeout
	_assert(str(ui._dice_show_phase) == "tumble", "After travel the dice tumble, got '%s'" % str(ui._dice_show_phase))
	ui._finish_dice_show()
	_assert(not bool(ui._dice_show_active), "finish_dice_show deactivates the show")
	_assert(str(ui._dice_show_phase) == "", "finish_dice_show clears the phase")
	_assert(ui._flight_layer.get_child_count() == 0, "finish_dice_show leaves no dice node on the flight layer")
	_assert(ui._dice_widget.modulate.a > 0.9, "Bar dice become visible again")
	st.last_dice = Vector2i(5, 6)
	ui._start_dice_roll_fx(st)
	st.last_dice = Vector2i(6, 6)
	ui._start_dice_roll_fx(st)
	_assert(int(ui._dice_show_count) == 3, "A new roll restarts the show (3 starts total), got %d" % int(ui._dice_show_count))
	_assert(ui._flight_layer.get_child_count() == 1, "Never more than one moving dice node, got %d" % ui._flight_layer.get_child_count())
	ui._reset_flight_state()
	_assert(not bool(ui._dice_show_active), "New game/lobby reset ends the show")
	_assert(ui._flight_layer.get_child_count() == 0, "Reset frees the travelling dice")
	ui._reduce_motion = true
	ui._start_dice_roll_fx(st)
	_assert(int(ui._dice_show_count) == 3, "Reduce motion skips the show entirely")
	_assert(not bool(ui._dice_show_active), "Reduce motion keeps the show inactive")
	_assert(int(ui._dice_widget.d1) == 6 and int(ui._dice_widget.d2) == 6, "Bar dice show the latest value immediately, got %d/%d" % [int(ui._dice_widget.d1), int(ui._dice_widget.d2)])
	ui._reduce_motion = false
	_pass_section("66. Dice Roll Show Test (bigger dice, travel phase, finish, preempt, reduce motion)")

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
	_assert(host.encloses(bounds[0] as Rect2), "Count badge stays inside the control, got %s vs %s" % [str(bounds[0]), str(host)])
	f.selected = true
	bounds = f.badge_bounds()
	_assert(host.encloses(bounds[0] as Rect2), "Count badge stays inside when selected (lifted), got %s" % str(bounds[0]))
	f.selected = false
	f.badge = 3
	bounds = f.badge_bounds()
	_assert(bounds.size() == 2, "Count and discard badges report two bounds, got %d" % bounds.size())
	for b in bounds:
		_assert(host.encloses(b as Rect2), "Every badge stays inside the control, got %s vs %s" % [str(b), str(host)])
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
	ui.session.start_match(779068, seats, true)
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	ui._refresh_ui()
	ui._toggle_trade_tray()
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame
	_assert(bool(ui._trade_tray.visible), "Trade tray opens for the stepper check")
	var font := ThemeDB.fallback_font
	_assert(font != null, "A fallback font is available to measure labels")
	var two_digits := font.get_string_size("10", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 4.0
	for r in GameTypes.ALL_RESOURCES:
		var cnt: Label = ui._trade_give_gui[r]["count"]
		_assert(cnt.custom_minimum_size.x >= two_digits, "Counter for %d reserves two digits, got %.1f < %.1f" % [r, cnt.custom_minimum_size.x, two_digits])
		var abbr: Label = null
		for c2 in ui._trade_tray.find_children("*", "Label", true, false):
			var lab := c2 as Label
			if lab.text == ui._resource_abbrev(r):
				abbr = lab
				break
		_assert(abbr != null, "Abbreviation label for %d exists" % r)
		_assert(not bool(abbr.clip_text), "Abbreviation label for %d never clips" % r)
		_assert(abbr.custom_minimum_size.x >= font.get_string_size(abbr.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, "Abbreviation label %s is wide enough to show its text" % abbr.text)
	_pass_section("68. Trade Stepper Labels Test (two-digit counts and abbreviations never clipped)")

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
	ui.session.start_match(779070, seats, true)
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
	ui.session.start_match(779071, seats, true)
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

func _test_bank_conservation_match() -> void:
	var session := LocalSession.new()
	var seats: Array[SeatConfig] = []
	for i in range(4):
		var sc := SeatConfig.new()
		sc.seat_id = i
		sc.seat_type = SeatConfig.SeatType.AI_MEDIUM
		sc.display_name = "Bank Bot %d" % i
		seats.append(sc)
	session.start_match(31001, seats, true)
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
	ui.session.start_match(52001, seats, true)
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
	_assert(str(ui._discard_heading.text) == "Discard 4 cards (picked 0 of 4)", "Heading should read 'Discard 4 cards (picked 0 of 4)', got '%s'" % str(ui._discard_heading.text))
	_assert(bool(ui._discard_confirm_btn.disabled), "Discard must stay disabled until 4 cards are picked")
	var refs: Dictionary = ui._res_card_refs
	var timber_card: CardFace = refs[GameTypes.ResourceType.TIMBER]
	var clay_card: CardFace = refs[GameTypes.ResourceType.CLAY]
	_ui_click_job(timber_card, func() -> void:
		_ui_click_job(timber_card, func() -> void:
			_ui_click_job(clay_card, func() -> void:
				_assert(str(ui._discard_heading.text) == "Discard 4 cards (picked 3 of 4)", "Three real picks should show 'picked 3 of 4', got '%s'" % str(ui._discard_heading.text))
				_assert(int(timber_card.count) == 3, "Cards keep normal counts in discard mode, got 'x%d'" % int(timber_card.count))
				_assert(int(timber_card.badge) == 2, "Timber badge should show 2, got %d" % int(timber_card.badge))
				_assert(bool(ui._discard_confirm_btn.disabled), "3 of 4 picked must still disable Discard")
				_assert(not bool(ui._trade_tray.visible), "Discard clicks must not open the trade tray")
				_ui_click_job_at(clay_card, clay_card.badge_center_local(), func() -> void:
					_assert(str(ui._discard_heading.text) == "Discard 4 cards (picked 2 of 4)", "Badge tap should take one back, got '%s'" % str(ui._discard_heading.text))
					_assert(int(clay_card.badge) == 0, "Badge clears when the last pick is taken back, got %d" % int(clay_card.badge))
					_ui_key_job(KEY_2, false, func() -> void:
						_ui_key_job(KEY_4, false, func() -> void:
							_ui_key_job(KEY_4, true, func() -> void:
								_assert(str(ui._discard_heading.text) == "Discard 4 cards (picked 3 of 4)", "Keys 1-5 add and Shift removes, got '%s'" % str(ui._discard_heading.text))
								ui._discard_auto_btn.pressed.emit()
								_assert(str(ui._discard_heading.text) == "Discard 4 cards (picked 4 of 4)", "'Pick for me' should fill 4, got '%s'" % str(ui._discard_heading.text))
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
	ui.session.start_match(52002, seats, true)
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
	_assert(ui._board_view.interaction_mode == BoardView.InteractionMode.PICK_BLOCKER_TILE, "Should be picking a blocker tile")
	ui._on_board_tile_clicked(tile_a)
	_assert(bool(ui._steal_chooser.visible), "Two victims should open the steal chooser")
	_assert(ui._steal_victim_btns.size() == 2, "Chooser should list both victims, got %d" % ui._steal_victim_btns.size())
	if ui._steal_victim_btns.size() == 2:
		var b0lbl := _first_label_text(ui._steal_victim_btns[0])
		_assert(b0lbl.begins_with("1. Dune — 2 cards"), "First victim button should read '1. Dune — 2 cards', got '%s'" % b0lbl)
		var b0sw := _find_swatch_of(ui._steal_victim_btns[0], GameTypes.PLAYER_COLORS[1])
		_assert(b0sw, "Victim button should carry the victim's colour swatch")
		var b0style = ui._steal_victim_btns[0].get_theme_stylebox("normal")
		_assert(b0style != null and b0style.bg_color.v > 0.55, "Victim buttons must use the paper button style, not the dark default")
	_assert(str(ui._status_banner_label.text).begins_with("Choose who to steal from"), "Banner should ask who to steal from")
	_ui_key_job(KEY_ESCAPE, false, func() -> void:
		_assert(not bool(ui._steal_chooser.visible), "Esc must close the steal chooser")
		_assert(ui._board_view.interaction_mode == BoardView.InteractionMode.PICK_BLOCKER_TILE, "Esc must keep tile picking active")
		ui._on_board_tile_clicked(tile_a)
		_assert(bool(ui._steal_chooser.visible), "Clicking the tile again should reopen the chooser")
		var victims: Array[int] = ui._steal_victims.duplicate()
		var thief_before: int = GameTypes.hand_total(ui.session.state.players[0]["hand"])
		var victim_before: int = GameTypes.hand_total(ui.session.state.players[victims[1]]["hand"])
		_ui_key_job(KEY_2, false, func() -> void:
			_assert(not bool(ui._steal_chooser.visible), "Key 2 must close the chooser")
			_assert(ui.session.state.blocker_tile == 5, "Key 2 should have moved the blocker to the picked tile")
			_assert(ui.session.state.phase == GameTypes.TurnPhase.TURN_MAIN, "Blocker move should end in TURN_MAIN")
			_assert(GameTypes.hand_total(ui.session.state.players[victims[1]]["hand"]) == victim_before - 1, "The chosen victim must lose the card")
			_assert(GameTypes.hand_total(ui.session.state.players[0]["hand"]) == thief_before + 1, "The thief must gain the card")
			_assert(int(ui.session.state.last_steal.get("victim", -1)) == victims[1], "last_steal must record the chosen victim")
			# exactly one victim: submit straight away, no chooser
			ui.session.state.vertex_owner[HexMath.get_topology().tile_vertices[5][1]] = -1
			ui.session.state.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
			ui.session.state.current_player = 0
			ui.session.state.blocker_tile = 9
			ui._refresh_ui()
			var solo_before: int = GameTypes.hand_total(ui.session.state.players[1]["hand"])
			ui._on_board_tile_clicked(5)
			_assert(not bool(ui._steal_chooser.visible), "One victim must not open the chooser")
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
			ui._on_board_tile_clicked(6)
			_assert(ui.session.state.blocker_tile == 6, "Zero-victim move should submit immediately")
			_assert(int(ui.session.state.last_steal.get("serial", 0)) == serial_before, "Zero-victim move must not steal")
			_assert(GameTypes.hand_total(ui.session.state.players[0]["hand"]) == total_before, "Zero-victim move must not change hands")
			_pass_section("33. Steal Chooser Test (2+ victims choose, 1/0 auto, keys, Esc keeps picking)")
		)
	)

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
	ui.session.start_match(52003, seats, true)
	var st: GameState = ui.session.state
	var topo := HexMath.get_topology()
	ui._show_toast("hello toast", Color.RED)
	_assert(ui._toast_labels.size() == 1, "Generic toast should be tracked")
	_assert(str(ui._toast_labels[0].text) == "hello toast", "Generic toast text should match")
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
	ui.session.start_match(52004, seats, true)
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
		if _find_swatch_of(c, col):
			return true
	return false

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
	ui.session.start_match(52005, seats, true)
	var st: GameState = ui.session.state
	st.phase = GameTypes.TurnPhase.TURN_MAIN
	st.current_player = 0
	st.players[0]["hand"][GameTypes.ResourceType.TIMBER] = 2
	st.players[0]["hand"][GameTypes.ResourceType.IRON] = 2
	st.players[1]["hand"][GameTypes.ResourceType.GRAIN] = 3
	ui._refresh_ui()
	_assert(not bool(ui._offer_strip.visible), "No open offer should mean a hidden strip")
	# counter wording then withdraw
	ui.session.submit_action(0, GameAction.open_trade({GameTypes.ResourceType.TIMBER: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	_assert(bool(ui._offer_strip.visible), "An open offer should show the strip")
	_assert(str(ui._offer_strip_label.text) == "Azure offers 1 Timber for 1 Grain", "Strip headline mismatch: '%s'" % str(ui._offer_strip_label.text))
	_assert(_strip_chip_texts(ui).contains("Dune: waiting") and _strip_chip_texts(ui).contains("Pike: waiting"), "Both responders should show waiting, got '%s'" % _strip_chip_texts(ui))
	ui.session.submit_action(1, GameAction.respond_open_trade("counter", {GameTypes.ResourceType.IRON: 1}, {GameTypes.ResourceType.GRAIN: 1}))
	_assert(_strip_chip_texts(ui).contains("Dune: ↺ counters"), "Counter chip mismatch: '%s'" % _strip_chip_texts(ui))
	ui._refresh_ui()
	_assert(_find_label_containing(ui._trade_tray, "COUNTER-OFFER"), "Partner card should carry the COUNTER-OFFER pill")
	_assert(_find_label_containing(ui._trade_tray, "You give"), "Counter card should show the 'You give' row")
	_assert(_find_button_by_text(ui._trade_tray, "Accept counter") != null, "Counter card should offer an Accept counter button")
	ui.session.submit_action(0, GameAction.cancel_open_trade())
	_assert(not bool(ui._offer_strip.visible), "Withdrawing must hide the strip")
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
	_assert(not bool(ui._offer_strip.visible), "Resolving the offer must hide the strip")
	_assert(int(ui.session.state.players[0]["hand"].get(GameTypes.ResourceType.TIMBER, 0)) == t0 - 1 and int(ui.session.state.players[0]["hand"].get(GameTypes.ResourceType.GRAIN, 0)) == g0 + 1, "Finalized trade must swap the resources")
	_assert(_toast_texts(ui).contains("Azure traded with Dune."), "Trade outcome should toast, got '%s'" % _toast_texts(ui))
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
	ui.session.start_match(52006, seats, true)
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
	_assert(bool(ui._trade_tray.visible), "Once every answer is in, the proposer must be brought back to the tray")
	ui.session.submit_action(0, GameAction.finalize_open_trade(2))
	_assert(ui.session.state.open_trade.is_empty(), "The offer should have resolved")
	_assert(not bool(ui._trade_tray.visible), "My own resolved offer must auto-close the tray")
	# out of the loop: I decline a bot offer, then bots negotiate
	ui.session.state.phase = GameTypes.TurnPhase.TURN_MAIN
	ui.session.state.current_player = 1
	ui.session.state.open_trades_this_turn = 0
	ui.session.submit_action(1, GameAction.open_trade({GameTypes.ResourceType.GRAIN: 1}, {GameTypes.ResourceType.TIMBER: 1}))
	_assert(bool(ui._trade_tray.visible), "The responder's tray should auto-open")
	ui._ot_decline_btn.pressed.emit()
	_assert(not bool(ui._trade_tray.visible), "The tray must close once the viewer is neither proposer nor responder")
	_assert(bool(ui._offer_strip.visible), "The strip still covers the bot-to-bot offer")
	ui.session.submit_action(1, GameAction.cancel_open_trade())
	# board background click closes a manually opened tray
	ui.session.state.phase = GameTypes.TurnPhase.TURN_MAIN
	ui.session.state.current_player = 0
	ui.session.state.open_trades_this_turn = 0
	ui._refresh_ui()
	ui._toggle_trade_tray()
	_assert(bool(ui._trade_tray.visible), "Trade button should open the tray")
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
	ui.session.start_match(52007, seats, true)
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
	ui.session.start_match(52008, seats, true)
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
	_assert(not bool(ui._trade_btn.visible), "Trade must hide while discarding")
	_assert(not bool(ui._end_turn_btn.visible), "End Turn must hide while discarding")
	_assert(not bool(ui._buy_card_btn.visible), "Buy card must hide while discarding")
	_assert(not bool(ui._dice_widget.visible), "Dice must hide while discarding")
	for ctype in ui._action_chips.keys():
		_assert(not bool(ui._action_chips[ctype].visible), "Action card chips must hide while discarding")
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
	ui.session.start_match(52009, seats, true)
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
	_assert(bool(ui._trade_btn.visible), "The bottom bar returns to normal")
	_assert(int(ui._res_card_refs[GameTypes.ResourceType.TIMBER].count) == 3, "Counts back to normal")
	_pass_section("41. Stale Discard Display Test (badges and picks clear on refresh)")

func _test_splash_winner_order_body(ui: Node) -> void:
	var seats: Array[SeatConfig] = [
		SeatConfig.new(0, SeatConfig.SeatType.HUMAN, "Azure"),
		SeatConfig.new(1, SeatConfig.SeatType.AI_MEDIUM, "Dune"),
	]
	ui.session.start_match(52010, seats, true)
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
	ui.session.start_match(52011, seats, true)
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
	ui.session.start_match(52012, seats, true)
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
	ui.session.start_match(52013, seats, true)
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
