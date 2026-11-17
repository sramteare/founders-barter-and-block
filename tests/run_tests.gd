extends SceneTree

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("=== Founders: Barter & Block - Headless Test Suite ===")
	_test_topology()
	_test_board_generator()
	_test_setup_and_distance_rule()
	_test_longest_route_and_splitting()
	_test_seven_roll_discard_and_blocker()
	_test_maritime_trade_and_action_cards()
	_test_open_trade_flow()
	_test_full_4bot_simulated_match()
	_test_main_scene_load()

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
		_assert(session.is_ai_to_act(), "All 4 seats are AI_MEDIUM so is_ai_to_act() must be true")
		var res: Dictionary = session.step_ai()
		if not res.get("ok", false):
			invalid_actions += 1
			printerr("Bot invalid action at step %d: %s" % [steps, str(res)])
			break
		steps += 1

	_assert(invalid_actions == 0, "Simulated match should have 0 invalid actions")
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
