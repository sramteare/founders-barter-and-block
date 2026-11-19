class_name RulesEngine
extends RefCounted

const MAX_OPEN_TRADES_PER_TURN := 3

static func get_valid_settlement_vertices(state: GameState, player_id: int, is_setup: bool) -> Array[int]:
	var valid: Array[int] = []
	if player_id < 0 or player_id >= state.num_players:
		return valid
	if int(state.players[player_id]["settlements_left"]) <= 0:
		return valid

	var topo := HexMath.get_topology()
	for v in range(54):
		if state.vertex_building[v] != GameTypes.BuildingType.NONE:
			continue
		var neighbor_occupied := false
		for nv in topo.vertex_neighbors[v]:
			if state.vertex_building[nv] != GameTypes.BuildingType.NONE:
				neighbor_occupied = true
				break
		if neighbor_occupied:
			continue

		if not is_setup:
			var touches_road := false
			for e_id in topo.vertex_edges[v]:
				if state.edge_owner[e_id] == player_id:
					touches_road = true
					break
			if not touches_road:
				continue

		valid.append(v)
	return valid

static func get_valid_road_edges(state: GameState, player_id: int, anchor_vertex: int = -1) -> Array[int]:
	var valid: Array[int] = []
	if player_id < 0 or player_id >= state.num_players:
		return valid
	if int(state.players[player_id]["roads_left"]) <= 0:
		return valid

	var effective_anchor := anchor_vertex
	if effective_anchor == -1 and (
		state.phase == GameTypes.TurnPhase.SETUP_ROAD_1
		or state.phase == GameTypes.TurnPhase.SETUP_ROAD_2
	):
		effective_anchor = state.setup_anchor_vertex

	var topo := HexMath.get_topology()
	for e_id in range(72):
		if state.edge_owner[e_id] != -1:
			continue
		var ev: Vector2i = topo.edge_vertices[e_id]
		if effective_anchor != -1:
			if ev.x == effective_anchor or ev.y == effective_anchor:
				valid.append(e_id)
		else:
			if _can_connect_road_at_vertex(state, topo, player_id, ev.x, e_id) or _can_connect_road_at_vertex(state, topo, player_id, ev.y, e_id):
				valid.append(e_id)
	return valid

static func _can_connect_road_at_vertex(
	state: GameState,
	topo: HexMath.BoardTopology,
	player_id: int,
	v_id: int,
	candidate_edge: int
) -> bool:
	var v_owner: int = state.vertex_owner[v_id]
	if v_owner == player_id:
		return true
	if v_owner != -1 and v_owner != player_id:
		return false
	for inc_edge in topo.vertex_edges[v_id]:
		if inc_edge != candidate_edge and state.edge_owner[inc_edge] == player_id:
			return true
	return false

static func get_valid_city_vertices(state: GameState, player_id: int) -> Array[int]:
	var valid: Array[int] = []
	if player_id < 0 or player_id >= state.num_players:
		return valid
	if int(state.players[player_id]["cities_left"]) <= 0:
		return valid
	for v in range(54):
		if state.vertex_owner[v] == player_id and state.vertex_building[v] == GameTypes.BuildingType.SETTLEMENT:
			valid.append(v)
	return valid

static func apply_action(state: GameState, player_id: int, action: Dictionary) -> Dictionary:
	var events: Array[String] = []
	if state.phase == GameTypes.TurnPhase.GAME_OVER:
		return _fail("Game is already over.")
	if player_id < 0 or player_id >= state.num_players:
		return _fail("Invalid player ID.")

	var action_type: String = str(action.get("type", ""))

	# Out-of-turn actions first: discard_resources
	if state.phase == GameTypes.TurnPhase.TURN_DISCARD:
		if action_type != "discard_resources":
			return _fail("Must discard resources first.")
		return _handle_discard(state, player_id, action, events)

	if not state.open_trade.is_empty():
		match action_type:
			"respond_open_trade":
				return _handle_respond_open_trade(state, player_id, action, events)
			"finalize_open_trade":
				return _handle_finalize_open_trade(state, player_id, action, events)
			"cancel_open_trade":
				return _handle_cancel_open_trade(state, player_id, events)
			_:
				return _fail("An open trade offer is awaiting responses.")

	if player_id != state.current_player:
		return _fail("It is not Player %d's turn." % player_id)

	match state.phase:
		GameTypes.TurnPhase.SETUP_SETTLEMENT_1, GameTypes.TurnPhase.SETUP_SETTLEMENT_2:
			if action_type != "place_settlement":
				return _fail("Must place a setup settlement.")
			return _handle_setup_settlement(state, player_id, action, events)

		GameTypes.TurnPhase.SETUP_ROAD_1, GameTypes.TurnPhase.SETUP_ROAD_2:
			if action_type != "place_road":
				return _fail("Must place a setup road.")
			return _handle_setup_road(state, player_id, action, events)

		GameTypes.TurnPhase.TURN_ROLL:
			if action_type == "roll_dice":
				return _handle_roll_dice(state, player_id, events)
			elif action_type == "play_guard":
				return _handle_play_guard(state, player_id, action, events)
			else:
				return _fail("Must roll dice (or play Guard) at start of turn.")

		GameTypes.TurnPhase.TURN_MOVE_BLOCKER:
			if action_type != "move_blocker":
				return _fail("Must move the Blocker.")
			return _handle_move_blocker(state, player_id, action, events)

		GameTypes.TurnPhase.TURN_ROAD_WORK:
			if action_type == "place_road":
				return _handle_road_work_place(state, player_id, action, events)
			elif action_type == "end_turn":
				state.road_work_remaining = 0
				state.phase = GameTypes.TurnPhase.TURN_MAIN
				return _handle_end_turn(state, player_id, events)
			else:
				return _fail("Must place free road(s) for Road Work.")

		GameTypes.TurnPhase.TURN_MAIN:
			match action_type:
				"place_settlement":
					return _handle_main_settlement(state, player_id, action, events)
				"place_road":
					return _handle_main_road(state, player_id, action, events)
				"upgrade_city":
					return _handle_upgrade_city(state, player_id, action, events)
				"maritime_trade":
					return _handle_maritime_trade(state, player_id, action, events)
				"open_trade":
					return _handle_open_trade(state, player_id, action, events)
				"buy_dev_card":
					return _handle_buy_dev_card(state, player_id, events)
				"play_guard":
					return _handle_play_guard(state, player_id, action, events)
				"play_road_work":
					return _handle_play_road_work(state, player_id, events)
				"play_harvest_bounty":
					return _handle_play_harvest_bounty(state, player_id, action, events)
				"play_trade_decree":
					return _handle_play_trade_decree(state, player_id, action, events)
				"end_turn":
					return _handle_end_turn(state, player_id, events)
				_:
					return _fail("Invalid action '%s' during TURN_MAIN." % action_type)

	return _fail("Unhandled game phase.")

static func _handle_setup_settlement(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var v_id: int = int(action.get("vertex_id", -1))
	var valid := get_valid_settlement_vertices(state, player_id, true)
	if not valid.has(v_id):
		return _fail("Invalid vertex %d for setup settlement." % v_id)

	var p: Dictionary = state.players[player_id]
	state.vertex_owner[v_id] = player_id
	state.vertex_building[v_id] = GameTypes.BuildingType.SETTLEMENT
	p["settlements_left"] = int(p["settlements_left"]) - 1
	state.setup_anchor_vertex = v_id
	events.append("%s placed a starting settlement at vertex %d." % [p["name"], v_id])

	if state.phase == GameTypes.TurnPhase.SETUP_SETTLEMENT_2:
		var topo := HexMath.get_topology()
		var gained_names: Array[String] = []
		for t_id in topo.vertex_tiles[v_id]:
			var res := GameTypes.terrain_to_resource(state.tile_terrains[t_id])
			if res >= 0:
				p["hand"][res] = int(p["hand"].get(res, 0)) + 1
				gained_names.append(GameTypes.resource_name(res))
		if not gained_names.is_empty():
			events.append("%s gained starting resources: %s." % [p["name"], ", ".join(gained_names)])
		state.phase = GameTypes.TurnPhase.SETUP_ROAD_2
	else:
		state.phase = GameTypes.TurnPhase.SETUP_ROAD_1

	return _ok(events)

static func _handle_setup_road(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var e_id: int = int(action.get("edge_id", -1))
	var valid := get_valid_road_edges(state, player_id, state.setup_anchor_vertex)
	if not valid.has(e_id):
		return _fail("Invalid edge %d for setup road." % e_id)

	var p: Dictionary = state.players[player_id]
	state.edge_owner[e_id] = player_id
	p["roads_left"] = int(p["roads_left"]) - 1
	state.setup_anchor_vertex = -1
	events.append("%s placed a starting road on edge %d." % [p["name"], e_id])
	_recompute_longest_route(state, events)

	if state.phase == GameTypes.TurnPhase.SETUP_ROAD_1:
		if state.current_player < state.num_players - 1:
			state.current_player += 1
			state.phase = GameTypes.TurnPhase.SETUP_SETTLEMENT_1
		else:
			state.phase = GameTypes.TurnPhase.SETUP_SETTLEMENT_2
	else:
		if state.current_player > 0:
			state.current_player -= 1
			state.phase = GameTypes.TurnPhase.SETUP_SETTLEMENT_2
		else:
			state.current_player = 0
			state.turn_number = 1
			state.phase = GameTypes.TurnPhase.TURN_ROLL
			events.append("Setup complete! %s begins Turn 1." % state.players[0]["name"])

	return _ok(events)

static func _handle_roll_dice(state: GameState, player_id: int, events: Array[String]) -> Dictionary:
	var d1 := state.rng.randi_range(1, 6)
	var d2 := state.rng.randi_range(1, 6)
	var total := d1 + d2
	state.last_dice = Vector2i(d1, d2)
	var p_name: String = state.players[player_id]["name"]
	events.append("%s rolled %d + %d = %d." % [p_name, d1, d2, total])

	if total == 7:
		state.pending_discards.clear()
		for p_idx in range(state.num_players):
			var h_total := GameTypes.hand_total(state.players[p_idx]["hand"])
			if h_total > 7:
				var to_discard: int = h_total / 2
				state.pending_discards[p_idx] = to_discard
				events.append("%s has %d cards and must discard %d." % [state.players[p_idx]["name"], h_total, to_discard])
		if state.pending_discards.is_empty():
			state.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
		else:
			state.phase = GameTypes.TurnPhase.TURN_DISCARD
	else:
		var topo := HexMath.get_topology()
		for t_id in range(19):
			if t_id == state.blocker_tile:
				continue
			if state.tile_numbers[t_id] != total:
				continue
			var res := GameTypes.terrain_to_resource(state.tile_terrains[t_id])
			if res < 0:
				continue
			for v_id in topo.tile_vertices[t_id]:
				var owner_id: int = state.vertex_owner[v_id]
				if owner_id >= 0:
					var b_type: int = state.vertex_building[v_id]
					var amount := 2 if b_type == GameTypes.BuildingType.CITY else 1
					var owner_hand: Dictionary = state.players[owner_id]["hand"]
					owner_hand[res] = int(owner_hand.get(res, 0)) + amount
					events.append("%s produced %d %s." % [state.players[owner_id]["name"], amount, GameTypes.resource_name(res)])
		state.phase = GameTypes.TurnPhase.TURN_MAIN

	return _ok(events)

static func _handle_discard(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	if not state.pending_discards.has(player_id):
		return _fail("Player %d does not need to discard." % player_id)
	var req_count: int = int(state.pending_discards[player_id])
	var res_dict: Dictionary = action.get("resources", {})
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]

	var sum_discard := 0
	for r in GameTypes.ALL_RESOURCES:
		var amt := int(res_dict.get(r, 0))
		if amt < 0:
			return _fail("Cannot discard negative resource count.")
		if amt > int(hand.get(r, 0)):
			return _fail("Not enough %s in hand to discard." % GameTypes.resource_name(r))
		sum_discard += amt

	if sum_discard != req_count:
		return _fail("Must discard exactly %d resources (got %d)." % [req_count, sum_discard])

	for r in GameTypes.ALL_RESOURCES:
		var amt := int(res_dict.get(r, 0))
		if amt > 0:
			hand[r] = int(hand.get(r, 0)) - amt

	state.pending_discards.erase(player_id)
	events.append("%s discarded %d cards." % [p["name"], req_count])

	if state.pending_discards.is_empty():
		state.phase = GameTypes.TurnPhase.TURN_MOVE_BLOCKER
	return _ok(events)

static func _handle_move_blocker(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var res := _execute_blocker_move(state, player_id, action, events)
	if not res["ok"]:
		return res
	state.phase = GameTypes.TurnPhase.TURN_MAIN
	_check_victory(state, events)
	return _ok(events)

static func _execute_blocker_move(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var tile_id: int = int(action.get("tile_id", -1))
	var target_player: int = int(action.get("target_player", -1))
	if tile_id < 0 or tile_id >= 19:
		return _fail("Invalid tile ID for Blocker.")
	if tile_id == state.blocker_tile:
		return _fail("Blocker must be moved to a different tile.")

	state.blocker_tile = tile_id
	var p: Dictionary = state.players[player_id]
	events.append("%s moved the Blocker to tile %d." % [p["name"], tile_id])

	var topo := HexMath.get_topology()
	var valid_victims: Array[int] = []
	for v_id in topo.tile_vertices[tile_id]:
		var v_owner: int = state.vertex_owner[v_id]
		if v_owner >= 0 and v_owner != player_id and not valid_victims.has(v_owner):
			if GameTypes.hand_total(state.players[v_owner]["hand"]) > 0:
				valid_victims.append(v_owner)

	var chosen_victim := -1
	if target_player >= 0 and valid_victims.has(target_player):
		chosen_victim = target_player
	elif not valid_victims.is_empty():
		chosen_victim = valid_victims[0]

	if chosen_victim >= 0:
		var victim_dict: Dictionary = state.players[chosen_victim]
		var victim_hand: Dictionary = victim_dict["hand"]
		var card_pool: Array[int] = []
		for r in GameTypes.ALL_RESOURCES:
			var cnt := int(victim_hand.get(r, 0))
			for _i in range(cnt):
				card_pool.append(r)
		if not card_pool.is_empty():
			var stolen_res: int = card_pool[state.rng.randi_range(0, card_pool.size() - 1)]
			victim_hand[stolen_res] = int(victim_hand[stolen_res]) - 1
			p["hand"][stolen_res] = int(p["hand"].get(stolen_res, 0)) + 1
			events.append("%s stole 1 resource from %s." % [p["name"], victim_dict["name"]])

	return _ok(events)

static func _handle_main_settlement(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var v_id: int = int(action.get("vertex_id", -1))
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]

	if int(p["settlements_left"]) <= 0:
		return _fail("No settlements remaining.")
	if not _has_resources(hand, {
		GameTypes.ResourceType.TIMBER: 1,
		GameTypes.ResourceType.CLAY: 1,
		GameTypes.ResourceType.FLEECE: 1,
		GameTypes.ResourceType.GRAIN: 1,
	}):
		return _fail("Insufficient resources to build a settlement.")

	var valid := get_valid_settlement_vertices(state, player_id, false)
	if not valid.has(v_id):
		return _fail("Invalid vertex %d for settlement." % v_id)

	_deduct_resources(hand, {
		GameTypes.ResourceType.TIMBER: 1,
		GameTypes.ResourceType.CLAY: 1,
		GameTypes.ResourceType.FLEECE: 1,
		GameTypes.ResourceType.GRAIN: 1,
	})
	state.vertex_owner[v_id] = player_id
	state.vertex_building[v_id] = GameTypes.BuildingType.SETTLEMENT
	p["settlements_left"] = int(p["settlements_left"]) - 1
	events.append("%s built a settlement at vertex %d." % [p["name"], v_id])

	# Building a settlement can split an opponent's road
	_recompute_longest_route(state, events)
	_check_victory(state, events)
	return _ok(events)

static func _handle_main_road(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var e_id: int = int(action.get("edge_id", -1))
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]

	if int(p["roads_left"]) <= 0:
		return _fail("No roads remaining.")
	if not _has_resources(hand, {
		GameTypes.ResourceType.TIMBER: 1,
		GameTypes.ResourceType.CLAY: 1,
	}):
		return _fail("Insufficient resources to build a road.")

	var valid := get_valid_road_edges(state, player_id, -1)
	if not valid.has(e_id):
		return _fail("Invalid edge %d for road." % e_id)

	_deduct_resources(hand, {
		GameTypes.ResourceType.TIMBER: 1,
		GameTypes.ResourceType.CLAY: 1,
	})
	state.edge_owner[e_id] = player_id
	p["roads_left"] = int(p["roads_left"]) - 1
	events.append("%s built a road on edge %d." % [p["name"], e_id])

	_recompute_longest_route(state, events)
	_check_victory(state, events)
	return _ok(events)

static func _handle_road_work_place(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var e_id: int = int(action.get("edge_id", -1))
	var p: Dictionary = state.players[player_id]
	var valid := get_valid_road_edges(state, player_id, -1)
	if not valid.has(e_id):
		return _fail("Invalid edge %d for Road Work." % e_id)

	state.edge_owner[e_id] = player_id
	p["roads_left"] = int(p["roads_left"]) - 1
	state.road_work_remaining -= 1
	events.append("%s built a free road on edge %d (Road Work)." % [p["name"], e_id])

	_recompute_longest_route(state, events)
	if state.road_work_remaining <= 0 or get_valid_road_edges(state, player_id, -1).is_empty():
		state.road_work_remaining = 0
		state.phase = GameTypes.TurnPhase.TURN_MAIN

	_check_victory(state, events)
	return _ok(events)

static func _handle_upgrade_city(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var v_id: int = int(action.get("vertex_id", -1))
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]

	if int(p["cities_left"]) <= 0:
		return _fail("No cities remaining.")
	if not _has_resources(hand, {
		GameTypes.ResourceType.GRAIN: 2,
		GameTypes.ResourceType.IRON: 3,
	}):
		return _fail("Insufficient resources to upgrade to a city.")

	var valid := get_valid_city_vertices(state, player_id)
	if not valid.has(v_id):
		return _fail("Invalid vertex %d for city upgrade." % v_id)

	_deduct_resources(hand, {
		GameTypes.ResourceType.GRAIN: 2,
		GameTypes.ResourceType.IRON: 3,
	})
	state.vertex_building[v_id] = GameTypes.BuildingType.CITY
	p["cities_left"] = int(p["cities_left"]) - 1
	p["settlements_left"] = int(p["settlements_left"]) + 1
	events.append("%s upgraded vertex %d to a City." % [p["name"], v_id])

	_check_victory(state, events)
	return _ok(events)

static func _handle_maritime_trade(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var give_res: int = int(action.get("give_res", -1))
	var get_res: int = int(action.get("get_res", -1))
	if not GameTypes.ALL_RESOURCES.has(give_res) or not GameTypes.ALL_RESOURCES.has(get_res):
		return _fail("Invalid resource type for maritime trade.")
	if give_res == get_res:
		return _fail("Cannot trade a resource for itself.")

	var ratio := state.get_trade_ratio(player_id, give_res)
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]
	if int(hand.get(give_res, 0)) < ratio:
		return _fail("Need %d %s for maritime trade." % [ratio, GameTypes.resource_name(give_res)])

	hand[give_res] = int(hand.get(give_res, 0)) - ratio
	hand[get_res] = int(hand.get(get_res, 0)) + 1
	events.append("%s traded %d %s for 1 %s (%d:1)." % [
		p["name"], ratio, GameTypes.resource_name(give_res), GameTypes.resource_name(get_res), ratio
	])
	return _ok(events)

static func _handle_open_trade(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	if player_id != state.current_player:
		return _fail("Only the current player can open a trade.")
	if state.phase != GameTypes.TurnPhase.TURN_MAIN:
		return _fail("Trades can only be opened during the main turn.")
	if not state.open_trade.is_empty():
		return _fail("Another trade is already in progress.")
	if state.open_trades_this_turn >= MAX_OPEN_TRADES_PER_TURN:
		return _fail("You can post at most %d offers per turn." % MAX_OPEN_TRADES_PER_TURN)

	var terms := _build_trade_terms(
		action.get("offer", {}),
		action.get("request", {})
	)
	if not bool(terms["ok"]):
		return _fail(str(terms["error"]))

	var offer: Dictionary = terms["offer"]
	var request: Dictionary = terms["request"]
	var p: Dictionary = state.players[player_id]
	if not _has_resources(p["hand"], offer):
		return _fail("Proposer does not have enough resources to offer.")

	state.open_trade = {
		"from": player_id,
		"offer": offer,
		"request": request,
		"responses": {},
	}
	state.open_trades_this_turn += 1
	events.append("%s offers %s for %s." % [
		p["name"], _format_resources(offer), _format_resources(request)
	])
	return _ok(events)

static func _handle_respond_open_trade(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var from_id: int = int(state.open_trade.get("from", -1))
	if player_id == from_id:
		return _fail("The proposer cannot respond to their own offer.")

	var responses: Dictionary = state.open_trade.get("responses", {})
	if responses.has(player_id):
		return _fail("You have already responded to this offer.")

	var status: String = str(action.get("status", ""))
	var p: Dictionary = state.players[player_id]
	var offer: Dictionary = state.open_trade.get("offer", GameTypes.empty_hand())
	var request: Dictionary = state.open_trade.get("request", GameTypes.empty_hand())

	if status == "accept":
		if not _has_resources(p["hand"], request):
			return _fail("Responder does not have the requested resources.")
		responses[player_id] = {
			"status": "accept",
			"offer": offer.duplicate(),
			"request": request.duplicate(),
		}
		events.append("%s accepts." % p["name"])
		return _ok(events)

	if status == "decline":
		responses[player_id] = {
			"status": "decline",
			"offer": offer.duplicate(),
			"request": request.duplicate(),
		}
		events.append("%s declines." % p["name"])
		return _ok(events)

	if status == "counter":
		var terms := _build_trade_terms(
			action.get("offer", {}),
			action.get("request", {})
		)
		if not bool(terms["ok"]):
			return _fail(str(terms["error"]))
		var counter_offer: Dictionary = terms["offer"]
		var counter_request: Dictionary = terms["request"]
		if not _has_resources(p["hand"], counter_request):
			return _fail("Responder does not have the resources for that counter-offer.")
		responses[player_id] = {
			"status": "counter",
			"offer": counter_offer,
			"request": counter_request,
		}
		events.append("%s counters: gives %s for %s." % [
			p["name"], _format_resources(counter_request), _format_resources(counter_offer)
		])
		return _ok(events)

	return _fail("Invalid trade response status '%s'." % status)

static func _handle_finalize_open_trade(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var from_id: int = int(state.open_trade.get("from", -1))
	if player_id != from_id:
		return _fail("Only the proposer can finalize this trade.")

	var partner: int = int(action.get("partner", -1))
	if partner < 0 or partner >= state.num_players or partner == from_id:
		return _fail("Invalid trade partner.")

	var responses: Dictionary = state.open_trade.get("responses", {})
	if not responses.has(partner):
		return _fail("That player has not responded to the offer.")
	var response: Dictionary = responses[partner]
	var status: String = str(response.get("status", ""))
	if status != "accept" and status != "counter":
		return _fail("That player declined the offer.")

	var offer: Dictionary = response.get("offer", GameTypes.empty_hand())
	var request: Dictionary = response.get("request", GameTypes.empty_hand())
	var p_from: Dictionary = state.players[from_id]
	var p_partner: Dictionary = state.players[partner]

	if not _has_resources(p_from["hand"], offer):
		return _fail("Proposer can no longer pay the agreed resources.")
	if not _has_resources(p_partner["hand"], request):
		return _fail("Partner can no longer pay the agreed resources.")

	for r in GameTypes.ALL_RESOURCES:
		var o_amt: int = int(offer.get(r, 0))
		var req_amt: int = int(request.get(r, 0))
		p_from["hand"][r] = int(p_from["hand"].get(r, 0)) - o_amt + req_amt
		p_partner["hand"][r] = int(p_partner["hand"].get(r, 0)) - req_amt + o_amt

	state.open_trade.clear()
	events.append("%s traded %s to %s for %s." % [
		p_from["name"], _format_resources(offer), p_partner["name"], _format_resources(request)
	])
	return _ok(events)

static func _handle_cancel_open_trade(state: GameState, player_id: int, events: Array[String]) -> Dictionary:
	var from_id: int = int(state.open_trade.get("from", -1))
	if player_id != from_id:
		return _fail("Only the proposer can withdraw the offer.")
	var p: Dictionary = state.players[player_id]
	state.open_trade.clear()
	events.append("%s withdrew the offer." % p["name"])
	return _ok(events)

static func _build_trade_terms(offer_raw: Dictionary, request_raw: Dictionary) -> Dictionary:
	var offer := GameTypes.empty_hand()
	var request := GameTypes.empty_hand()
	var offer_total := 0
	var request_total := 0
	for r in GameTypes.ALL_RESOURCES:
		var o_amt: int = int(offer_raw.get(r, 0))
		var req_amt: int = int(request_raw.get(r, 0))
		if o_amt < 0 or req_amt < 0:
			return {"ok": false, "error": "Trade amounts cannot be negative."}
		offer[r] = o_amt
		request[r] = req_amt
		offer_total += o_amt
		request_total += req_amt

	if offer_total == 0 or request_total == 0:
		return {"ok": false, "error": "Trade must offer and request at least 1 resource."}

	for r in GameTypes.ALL_RESOURCES:
		if int(offer[r]) > 0 and int(request[r]) > 0:
			return {"ok": false, "error": "A resource cannot be on both sides of a trade."}

	return {
		"ok": true,
		"error": "",
		"offer": offer,
		"request": request,
		"offer_total": offer_total,
		"request_total": request_total,
	}

static func _format_resources(res: Dictionary) -> String:
	var parts: Array[String] = []
	for r in GameTypes.ALL_RESOURCES:
		var amt: int = int(res.get(r, 0))
		if amt > 0:
			parts.append("%d %s" % [amt, GameTypes.resource_name(r)])
	if parts.is_empty():
		return "nothing"
	return " + ".join(parts)

static func can_afford(state: GameState, player_id: int, what: String) -> bool:
	if player_id < 0 or player_id >= state.num_players:
		return false
	var cost: Dictionary = {}
	match what:
		"road":
			cost = {
				GameTypes.ResourceType.TIMBER: 1,
				GameTypes.ResourceType.CLAY: 1,
			}
		"settlement":
			cost = {
				GameTypes.ResourceType.TIMBER: 1,
				GameTypes.ResourceType.CLAY: 1,
				GameTypes.ResourceType.FLEECE: 1,
				GameTypes.ResourceType.GRAIN: 1,
			}
		"city":
			cost = {
				GameTypes.ResourceType.GRAIN: 2,
				GameTypes.ResourceType.IRON: 3,
			}
		"dev_card":
			cost = {
				GameTypes.ResourceType.FLEECE: 1,
				GameTypes.ResourceType.GRAIN: 1,
				GameTypes.ResourceType.IRON: 1,
			}
		_:
			return false
	return _has_resources(state.players[player_id]["hand"], cost)

static func _handle_buy_dev_card(state: GameState, player_id: int, events: Array[String]) -> Dictionary:
	if state.dev_deck.is_empty():
		return _fail("No Action Cards remaining in deck.")
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]
	if not _has_resources(hand, {
		GameTypes.ResourceType.FLEECE: 1,
		GameTypes.ResourceType.GRAIN: 1,
		GameTypes.ResourceType.IRON: 1,
	}):
		return _fail("Insufficient resources to buy an Action Card.")

	_deduct_resources(hand, {
		GameTypes.ResourceType.FLEECE: 1,
		GameTypes.ResourceType.GRAIN: 1,
		GameTypes.ResourceType.IRON: 1,
	})
	var card: int = state.dev_deck.pop_back()
	if card == GameTypes.DevCardType.CHARTER_POINT:
		p["dev_cards"].append(card)
	else:
		p["new_dev_cards"].append(card)
	events.append("%s bought an Action Card." % p["name"])

	_check_victory(state, events)
	return _ok(events)

static func can_play_dev_card(state: GameState, player_id: int, card_type: int) -> Dictionary:
	if state.phase == GameTypes.TurnPhase.GAME_OVER:
		return {"ok": false, "reason": "The game is over."}
	if state.phase == GameTypes.TurnPhase.TURN_ROLL:
		if card_type != GameTypes.DevCardType.GUARD:
			return {"ok": false, "reason": "Only a Guard can be played before rolling."}
	elif state.phase != GameTypes.TurnPhase.TURN_MAIN:
		return {"ok": false, "reason": "Action Cards are played during your main turn."}
	if state.current_player != player_id:
		return {"ok": false, "reason": "It is not your turn."}
	if not state.open_trade.is_empty():
		return {"ok": false, "reason": "An open trade offer is awaiting responses."}
	var p: Dictionary = state.players[player_id]
	var dev_cards: Array = p.get("dev_cards", [])
	var new_dev_cards: Array = p.get("new_dev_cards", [])
	if not dev_cards.has(card_type):
		if new_dev_cards.has(card_type):
			return {"ok": false, "reason": "Bought this turn — playable next turn"}
		return {"ok": false, "reason": "You do not have this Action Card."}
	if bool(p.get("played_dev_this_turn", false)):
		return {"ok": false, "reason": "Already played an Action Card this turn."}
	if card_type == GameTypes.DevCardType.ROAD_WORK:
		if int(p.get("roads_left", 0)) <= 0 or get_valid_road_edges(state, player_id, -1).is_empty():
			return {"ok": false, "reason": "No road can be placed."}
	return {"ok": true, "reason": ""}

static func _handle_play_guard(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var check := can_play_dev_card(state, player_id, GameTypes.DevCardType.GUARD)
	if not bool(check["ok"]):
		return _fail(str(check["reason"]))
	var p: Dictionary = state.players[player_id]
	var dev_cards: Array = p["dev_cards"]
	var idx := dev_cards.find(GameTypes.DevCardType.GUARD)

	var move_res := _execute_blocker_move(state, player_id, action, events)
	if not move_res["ok"]:
		return move_res

	dev_cards.remove_at(idx)
	p["played_dev_this_turn"] = true
	p["played_guards"] = int(p["played_guards"]) + 1
	events.append("%s played a Guard (total played: %d)." % [p["name"], int(p["played_guards"])])

	_recompute_largest_guard(state, events)
	_check_victory(state, events)
	return _ok(events)

static func _handle_play_road_work(state: GameState, player_id: int, events: Array[String]) -> Dictionary:
	var check := can_play_dev_card(state, player_id, GameTypes.DevCardType.ROAD_WORK)
	if not bool(check["ok"]):
		return _fail(str(check["reason"]))
	var p: Dictionary = state.players[player_id]
	var dev_cards: Array = p["dev_cards"]
	var idx := dev_cards.find(GameTypes.DevCardType.ROAD_WORK)

	dev_cards.remove_at(idx)
	p["played_dev_this_turn"] = true
	events.append("%s played Road Work!" % p["name"])

	var max_free := mini(2, int(p["roads_left"]))
	if max_free > 0 and not get_valid_road_edges(state, player_id, -1).is_empty():
		state.road_work_remaining = max_free
		state.phase = GameTypes.TurnPhase.TURN_ROAD_WORK
	return _ok(events)

static func _handle_play_harvest_bounty(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var check := can_play_dev_card(state, player_id, GameTypes.DevCardType.HARVEST_BOUNTY)
	if not bool(check["ok"]):
		return _fail(str(check["reason"]))
	var p: Dictionary = state.players[player_id]
	var dev_cards: Array = p["dev_cards"]
	var idx := dev_cards.find(GameTypes.DevCardType.HARVEST_BOUNTY)

	var res1: int = int(action.get("res1", -1))
	var res2: int = int(action.get("res2", -1))
	if not GameTypes.ALL_RESOURCES.has(res1) or not GameTypes.ALL_RESOURCES.has(res2):
		return _fail("Invalid resource selection for Harvest Bounty.")

	dev_cards.remove_at(idx)
	p["played_dev_this_turn"] = true
	p["hand"][res1] = int(p["hand"].get(res1, 0)) + 1
	p["hand"][res2] = int(p["hand"].get(res2, 0)) + 1
	events.append("%s played Harvest Bounty and took %s & %s." % [
		p["name"], GameTypes.resource_name(res1), GameTypes.resource_name(res2)
	])
	return _ok(events)

static func _handle_play_trade_decree(state: GameState, player_id: int, action: Dictionary, events: Array[String]) -> Dictionary:
	var check := can_play_dev_card(state, player_id, GameTypes.DevCardType.TRADE_DECREE)
	if not bool(check["ok"]):
		return _fail(str(check["reason"]))
	var p: Dictionary = state.players[player_id]
	var dev_cards: Array = p["dev_cards"]
	var idx := dev_cards.find(GameTypes.DevCardType.TRADE_DECREE)

	var res: int = int(action.get("res", -1))
	if not GameTypes.ALL_RESOURCES.has(res):
		return _fail("Invalid resource selection for Trade Decree.")

	dev_cards.remove_at(idx)
	p["played_dev_this_turn"] = true

	var total_taken := 0
	for opp_id in range(state.num_players):
		if opp_id == player_id:
			continue
		var opp_hand: Dictionary = state.players[opp_id]["hand"]
		var cnt := int(opp_hand.get(res, 0))
		if cnt > 0:
			opp_hand[res] = 0
			total_taken += cnt
	p["hand"][res] = int(p["hand"].get(res, 0)) + total_taken
	events.append("%s played Trade Decree on %s and collected %d!" % [
		p["name"], GameTypes.resource_name(res), total_taken
	])
	return _ok(events)

static func _handle_end_turn(state: GameState, player_id: int, events: Array[String]) -> Dictionary:
	_check_victory(state, events)
	if state.phase == GameTypes.TurnPhase.GAME_OVER:
		return _ok(events)

	var p: Dictionary = state.players[player_id]
	for card in p["new_dev_cards"]:
		p["dev_cards"].append(card)
	p["new_dev_cards"].clear()
	p["played_dev_this_turn"] = false

	state.open_trade.clear()
	state.open_trades_this_turn = 0
	state.road_work_remaining = 0
	state.current_player = (state.current_player + 1) % state.num_players
	if state.current_player == 0:
		state.turn_number += 1
	state.phase = GameTypes.TurnPhase.TURN_ROLL
	events.append("%s ended turn. Now %s's turn (Turn %d)." % [
		p["name"], state.players[state.current_player]["name"], state.turn_number
	])
	return _ok(events)

static func _recompute_longest_route(state: GameState, events: Array[String]) -> void:
	var max_len := 0
	for p_idx in range(state.num_players):
		var length := HexMath.compute_longest_route(p_idx, state.edge_owner, state.vertex_owner)
		state.players[p_idx]["longest_route_length"] = length
		if length > max_len:
			max_len = length

	var prev_holder := state.longest_route_holder
	if max_len < 5:
		state.longest_route_holder = -1
		return

	if prev_holder != -1 and int(state.players[prev_holder]["longest_route_length"]) == max_len:
		return

	var leaders: Array[int] = []
	for p_idx in range(state.num_players):
		if int(state.players[p_idx]["longest_route_length"]) == max_len:
			leaders.append(p_idx)

	if leaders.size() == 1:
		state.longest_route_holder = leaders[0]
		if state.longest_route_holder != prev_holder:
			events.append("%s claimed Longest Route (length %d)!" % [
				state.players[state.longest_route_holder]["name"], max_len
			])
	else:
		state.longest_route_holder = -1

static func _recompute_largest_guard(state: GameState, events: Array[String]) -> void:
	var prev_holder := state.largest_guard_holder
	var current_max := 2
	if prev_holder != -1:
		current_max = int(state.players[prev_holder]["played_guards"])

	for p_idx in range(state.num_players):
		var guards := int(state.players[p_idx]["played_guards"])
		if guards >= 3 and guards > current_max:
			current_max = guards
			state.largest_guard_holder = p_idx

	if state.largest_guard_holder != prev_holder and state.largest_guard_holder != -1:
		events.append("%s claimed Largest Guard (%d guards)!" % [
			state.players[state.largest_guard_holder]["name"], current_max
		])

static func _check_victory(state: GameState, events: Array[String]) -> void:
	var p_id := state.current_player
	var vp := state.get_victory_points(p_id, true)
	if vp >= 10:
		state.winner = p_id
		state.phase = GameTypes.TurnPhase.GAME_OVER
		state.open_trade.clear()
		events.append("%s wins the game with %d Victory Points!" % [state.players[p_id]["name"], vp])

static func _has_resources(hand: Dictionary, cost: Dictionary) -> bool:
	for r in cost.keys():
		if int(hand.get(r, 0)) < int(cost[r]):
			return false
	return true

static func _deduct_resources(hand: Dictionary, cost: Dictionary) -> void:
	for r in cost.keys():
		hand[r] = int(hand.get(r, 0)) - int(cost[r])

static func _ok(events: Array[String]) -> Dictionary:
	return {"ok": true, "error": "", "events": events}

static func _fail(err: String) -> Dictionary:
	var empty_events: Array[String] = []
	return {"ok": false, "error": err, "events": empty_events}
