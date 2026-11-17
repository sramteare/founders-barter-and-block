class_name BotController
extends RefCounted

static func choose_action(state: GameState, player_id: int, difficulty: int = 2) -> Dictionary:
	# 1. Out-of-turn / interrupt checks: Discard on 7
	if state.phase == GameTypes.TurnPhase.TURN_DISCARD and state.pending_discards.has(player_id):
		var count_needed: int = int(state.pending_discards[player_id])
		if count_needed > 0:
			return GameAction.discard_resources(_choose_discards(state, player_id, count_needed))

	# 2. Out-of-turn / interrupt checks: Open trade responses / proposer decision
	if not state.open_trade.is_empty():
		var open_from: int = int(state.open_trade.get("from", -1))
		if open_from == player_id:
			return _choose_open_trade_proposer_action(state, player_id)
		var open_responses: Dictionary = state.open_trade.get("responses", {})
		if not open_responses.has(player_id):
			return _choose_open_trade_response(state, player_id, difficulty)

	# 3. Out-of-turn / interrupt checks: Pending Barter response
	if not state.pending_barter.is_empty() and int(state.pending_barter.get("to", -1)) == player_id:
		var accept: bool = _should_accept_barter(state, player_id, state.pending_barter)
		return GameAction.respond_barter(accept)

	# 4. Phase-based decisions
	match state.phase:
		GameTypes.TurnPhase.SETUP_SETTLEMENT_1, GameTypes.TurnPhase.SETUP_SETTLEMENT_2:
			var valid_verts: Array[int] = RulesEngine.get_valid_settlement_vertices(state, player_id, true)
			var best_v: int = _choose_best_settlement_vertex(state, player_id, valid_verts, true, difficulty)
			return GameAction.place_settlement(best_v)

		GameTypes.TurnPhase.SETUP_ROAD_1, GameTypes.TurnPhase.SETUP_ROAD_2:
			var anchor: int = _get_setup_anchor(state)
			var valid_edges: Array[int] = RulesEngine.get_valid_road_edges(state, player_id, anchor)
			if valid_edges.is_empty():
				valid_edges = RulesEngine.get_valid_road_edges(state, player_id, -1)
			var best_e: int = _choose_best_road_edge(state, player_id, valid_edges)
			return GameAction.place_road(best_e)

		GameTypes.TurnPhase.TURN_ROLL:
			var p_roll: Dictionary = state.players[player_id]
			var dev_cards_roll: Array = p_roll.get("dev_cards", [])
			var played_dev_roll: bool = bool(p_roll.get("played_dev_this_turn", false))
			if not played_dev_roll and dev_cards_roll.has(GameTypes.DevCardType.GUARD):
				if _tile_touches_player(state, state.blocker_tile, player_id):
					var guard_target: Dictionary = _choose_blocker_target(state, player_id)
					return GameAction.play_guard(int(guard_target["tile_id"]), int(guard_target["target_player"]))
			return GameAction.roll_dice()

		GameTypes.TurnPhase.TURN_MOVE_BLOCKER:
			var target: Dictionary = _choose_blocker_target(state, player_id)
			return GameAction.move_blocker(int(target["tile_id"]), int(target["target_player"]))

		GameTypes.TurnPhase.TURN_ROAD_WORK:
			var p_rw: Dictionary = state.players[player_id]
			if state.road_work_remaining > 0 and int(p_rw.get("roads_left", 0)) > 0:
				var valid_rw_edges: Array[int] = RulesEngine.get_valid_road_edges(state, player_id, -1)
				if not valid_rw_edges.is_empty():
					var best_rw_edge: int = _choose_best_road_edge(state, player_id, valid_rw_edges)
					return GameAction.place_road(best_rw_edge)
			return GameAction.end_turn()

		GameTypes.TurnPhase.TURN_MAIN:
			return _choose_main_turn_action(state, player_id, difficulty)

		_:
			return GameAction.end_turn()

static func _get_setup_anchor(state: GameState) -> int:
	var val = state.get("setup_anchor_vertex")
	if val != null:
		return int(val)
	var val_cap = state.get("setup_Anchor_vertex")
	if val_cap != null:
		return int(val_cap)
	return -1

static func _choose_main_turn_action(state: GameState, player_id: int, difficulty: int) -> Dictionary:
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]
	var dev_cards: Array = p.get("dev_cards", [])
	var played_dev: bool = bool(p.get("played_dev_this_turn", false))

	var city_verts: Array[int] = RulesEngine.get_valid_city_vertices(state, player_id)
	var settle_verts: Array[int] = RulesEngine.get_valid_settlement_vertices(state, player_id, false)
	var road_edges: Array[int] = RulesEngine.get_valid_road_edges(state, player_id, -1)

	var cities_left: int = int(p.get("cities_left", 0))
	var settlements_left: int = int(p.get("settlements_left", 0))
	var roads_left: int = int(p.get("roads_left", 0))

	# 1. Play ROAD_WORK, HARVEST_BOUNTY, TRADE_DECREE, or GUARD if available and not played_dev_this_turn
	if not played_dev and not dev_cards.is_empty():
		if dev_cards.has(GameTypes.DevCardType.ROAD_WORK) and roads_left > 0 and not road_edges.is_empty():
			return GameAction.play_road_work()
		if dev_cards.has(GameTypes.DevCardType.HARVEST_BOUNTY):
			var bounty_pair: Vector2i = _choose_harvest_bounty_resources(state, player_id, city_verts, settle_verts)
			return GameAction.play_harvest_bounty(bounty_pair.x, bounty_pair.y)
		if dev_cards.has(GameTypes.DevCardType.TRADE_DECREE):
			var decree_res: int = _choose_trade_decree_resource(state, player_id)
			if decree_res >= 0:
				return GameAction.play_trade_decree(decree_res)
		if dev_cards.has(GameTypes.DevCardType.GUARD):
			var target: Dictionary = _choose_blocker_target(state, player_id)
			return GameAction.play_guard(int(target["tile_id"]), int(target["target_player"]))

	# 2. Upgrade a city if affordable and get_valid_city_vertices non-empty
	if cities_left > 0 and not city_verts.is_empty() and _can_afford_city(hand):
		var best_city_v: int = _choose_best_city_vertex(state, city_verts)
		return GameAction.upgrade_city(best_city_v)

	# 3. Build a settlement if affordable and get_valid_settlement_vertices non-empty
	if settlements_left > 0 and not settle_verts.is_empty() and _can_afford_settlement(hand):
		var best_settle_v: int = _choose_best_settlement_vertex(state, player_id, settle_verts, false, difficulty)
		return GameAction.place_settlement(best_settle_v)

	# 4. Maritime trade if holding >4 of any resource or enough for port/4:1 trade and missing 1 resource for a build
	var trade_action: Dictionary = _choose_maritime_trade(
		state,
		player_id,
		city_verts,
		settle_verts,
		road_edges
	)
	if not trade_action.is_empty():
		return trade_action

	# 5. Build a road if affordable, roads_left > 0, and leads toward an open buildable vertex or extends route
	if roads_left > 0 and not road_edges.is_empty() and _can_afford_road(hand):
		var wants_road: bool = false
		if settlements_left > 0 and settle_verts.is_empty():
			wants_road = true
		elif _should_build_road(state, player_id, road_edges):
			# Don't spend last Timber/Clay if we already have a settlement vertex open and have Fleece+Grain ready
			var would_delay_settlement: bool = (
				settlements_left > 0
				and not settle_verts.is_empty()
				and int(hand.get(GameTypes.ResourceType.FLEECE, 0)) >= 1
				and int(hand.get(GameTypes.ResourceType.GRAIN, 0)) >= 1
				and (int(hand.get(GameTypes.ResourceType.TIMBER, 0)) < 2 or int(hand.get(GameTypes.ResourceType.CLAY, 0)) < 2)
			)
			if not would_delay_settlement:
				wants_road = true
		if wants_road:
			var best_road_e: int = _choose_best_road_edge(state, player_id, road_edges)
			return GameAction.place_road(best_road_e)

	# 6. Open a table-wide trade if exactly one resource short of a build
	var open_trade_action: Dictionary = _choose_open_trade_action(
		state,
		player_id,
		difficulty,
		city_verts,
		settle_verts,
		road_edges
	)
	if not open_trade_action.is_empty():
		return open_trade_action

	# 7. Buy a dev card if affordable and not state.dev_deck.is_empty()
	if not state.dev_deck.is_empty() and _can_afford_dev_card(hand):
		# Avoid buying dev card if we are 1 resource away from an immediately available City upgrade and have >= 5 cards
		var save_for_city: bool = (
			cities_left > 0
			and not city_verts.is_empty()
			and int(hand.get(GameTypes.ResourceType.GRAIN, 0)) >= 2
			and int(hand.get(GameTypes.ResourceType.IRON, 0)) == 2
		)
		if not save_for_city:
			return GameAction.buy_dev_card()

	# 8. Otherwise end turn
	return GameAction.end_turn()

static func _can_afford_road(hand: Dictionary) -> bool:
	return (
		int(hand.get(GameTypes.ResourceType.TIMBER, 0)) >= 1
		and int(hand.get(GameTypes.ResourceType.CLAY, 0)) >= 1
	)

static func _can_afford_settlement(hand: Dictionary) -> bool:
	return (
		int(hand.get(GameTypes.ResourceType.TIMBER, 0)) >= 1
		and int(hand.get(GameTypes.ResourceType.CLAY, 0)) >= 1
		and int(hand.get(GameTypes.ResourceType.FLEECE, 0)) >= 1
		and int(hand.get(GameTypes.ResourceType.GRAIN, 0)) >= 1
	)

static func _can_afford_city(hand: Dictionary) -> bool:
	return (
		int(hand.get(GameTypes.ResourceType.GRAIN, 0)) >= 2
		and int(hand.get(GameTypes.ResourceType.IRON, 0)) >= 3
	)

static func _can_afford_dev_card(hand: Dictionary) -> bool:
	return (
		int(hand.get(GameTypes.ResourceType.FLEECE, 0)) >= 1
		and int(hand.get(GameTypes.ResourceType.GRAIN, 0)) >= 1
		and int(hand.get(GameTypes.ResourceType.IRON, 0)) >= 1
	)

static func _choose_best_settlement_vertex(
	state: GameState,
	player_id: int,
	valid_verts: Array[int],
	is_setup: bool,
	difficulty: int
) -> int:
	if valid_verts.is_empty():
		return 0
	var topo := HexMath.get_topology()

	# Track resources player already produces for diversity scoring
	var existing_res: Dictionary = {}
	for v in range(state.vertex_owner.size()):
		if state.vertex_owner[v] == player_id:
			for t in topo.vertex_tiles[v]:
				var r: int = GameTypes.terrain_to_resource(state.tile_terrains[t])
				if r >= 0:
					existing_res[r] = true

	var best_v: int = valid_verts[0]
	var best_score: float = -999999.0

	for v in valid_verts:
		var score: float = _score_vertex(state, topo, v, existing_res, is_setup, difficulty)
		if score > best_score:
			best_score = score
			best_v = v

	return best_v

static func _score_vertex(
	state: GameState,
	topo: HexMath.BoardTopology,
	v: int,
	existing_res: Dictionary,
	is_setup: bool,
	difficulty: int
) -> float:
	var pip_sum: float = 0.0
	var local_res: Dictionary = {}
	for t in topo.vertex_tiles[v]:
		var terrain: int = state.tile_terrains[t]
		var res: int = GameTypes.terrain_to_resource(terrain)
		if res >= 0:
			var pips: int = GameTypes.pip_count(state.tile_numbers[t])
			pip_sum += float(pips)
			local_res[res] = int(local_res.get(res, 0)) + pips
			# Slight bonus for critical early-game expansion resources (Timber/Clay/Grain/Iron)
			if is_setup and (res == GameTypes.ResourceType.TIMBER or res == GameTypes.ResourceType.CLAY or res == GameTypes.ResourceType.GRAIN):
				pip_sum += 0.35

	var diversity_bonus: float = float(local_res.size()) * 1.75
	for r in local_res.keys():
		if not existing_res.has(r):
			diversity_bonus += 1.5

	var port_bonus: float = 0.0
	if v >= 0 and v < state.vertex_ports.size():
		var port: int = state.vertex_ports[v]
		if port == GameTypes.PortType.GENERIC_3_TO_1:
			port_bonus = 1.5
		elif port >= 0:
			port_bonus = 1.2
			if local_res.has(port) or existing_res.has(port):
				port_bonus = 2.5

	var total: float = pip_sum + diversity_bonus + port_bonus
	if difficulty <= 1:
		# Easy AI cares mostly about raw pips
		total = pip_sum + float(local_res.size()) * 0.5
	return total

static func _choose_best_city_vertex(state: GameState, city_verts: Array[int]) -> int:
	if city_verts.is_empty():
		return 0
	var topo := HexMath.get_topology()
	var best_v: int = city_verts[0]
	var best_score: float = -1.0
	for v in city_verts:
		var score: float = 0.0
		for t in topo.vertex_tiles[v]:
			var res: int = GameTypes.terrain_to_resource(state.tile_terrains[t])
			if res >= 0:
				var pips: float = float(GameTypes.pip_count(state.tile_numbers[t]))
				if res == GameTypes.ResourceType.GRAIN or res == GameTypes.ResourceType.IRON:
					pips *= 1.2
				score += pips
		if score > best_score:
			best_score = score
			best_v = v
	return best_v

static func _is_vertex_distance_open(state: GameState, topo: HexMath.BoardTopology, v: int) -> bool:
	if state.vertex_owner[v] != -1:
		return false
	for nb in topo.vertex_neighbors[v]:
		if state.vertex_owner[nb] != -1:
			return false
	return true

static func _choose_best_road_edge(state: GameState, player_id: int, valid_edges: Array[int]) -> int:
	if valid_edges.is_empty():
		return 0
	var topo := HexMath.get_topology()
	var empty_existing: Dictionary = {}
	var best_e: int = valid_edges[0]
	var best_score: float = -999999.0

	for e in valid_edges:
		var ev: Vector2i = topo.edge_vertices[e]
		var score: float = 0.0
		for endpoint in [ev.x, ev.y]:
			if _is_vertex_distance_open(state, topo, endpoint):
				score = max(score, _score_vertex(state, topo, endpoint, empty_existing, false, 2) + 8.0)
			for nb_v in topo.vertex_neighbors[endpoint]:
				if _is_vertex_distance_open(state, topo, nb_v):
					score = max(score, _score_vertex(state, topo, nb_v, empty_existing, false, 2) * 0.75 + 3.0)
				for nb2_v in topo.vertex_neighbors[nb_v]:
					if _is_vertex_distance_open(state, topo, nb2_v):
						score = max(score, _score_vertex(state, topo, nb2_v, empty_existing, false, 2) * 0.4)

		# Also evaluate longest route gain if we place this road
		var test_edges: Array[int] = state.edge_owner.duplicate()
		test_edges[e] = player_id
		var new_route: int = HexMath.compute_longest_route(player_id, test_edges, state.vertex_owner)
		var cur_route: int = int(state.players[player_id].get("longest_route_length", 0))
		if new_route > cur_route:
			score += 2.5
			if new_route >= 5 and state.longest_route_holder != player_id:
				score += 6.0

		if score > best_score:
			best_score = score
			best_e = e

	return best_e

static func _should_build_road(state: GameState, player_id: int, valid_edges: Array[int]) -> bool:
	var topo := HexMath.get_topology()
	var p: Dictionary = state.players[player_id]
	var settlements_left: int = int(p.get("settlements_left", 0))

	# Check if any valid road edge reaches or steps toward an open buildable settlement spot
	if settlements_left > 0:
		for e in valid_edges:
			var ev: Vector2i = topo.edge_vertices[e]
			if _is_vertex_distance_open(state, topo, ev.x) or _is_vertex_distance_open(state, topo, ev.y):
				return true
			for endpoint in [ev.x, ev.y]:
				for nb in topo.vertex_neighbors[endpoint]:
					if _is_vertex_distance_open(state, topo, nb):
						return true

	# Or if building a road increases our longest route and helps contest Longest Route
	var cur_route: int = int(p.get("longest_route_length", 0))
	if cur_route >= 3 and state.longest_route_holder != player_id:
		for e in valid_edges:
			var test_edges: Array[int] = state.edge_owner.duplicate()
			test_edges[e] = player_id
			if HexMath.compute_longest_route(player_id, test_edges, state.vertex_owner) > cur_route:
				return true

	# Or if hand has plenty of Timber & Clay (> 2 each)
	var hand: Dictionary = p["hand"]
	if int(hand.get(GameTypes.ResourceType.TIMBER, 0)) >= 3 and int(hand.get(GameTypes.ResourceType.CLAY, 0)) >= 3:
		return true

	return false

static func _choose_maritime_trade(
	state: GameState,
	player_id: int,
	city_verts: Array[int],
	settle_verts: Array[int],
	road_edges: Array[int]
) -> Dictionary:
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]
	var cities_left: int = int(p.get("cities_left", 0))
	var settlements_left: int = int(p.get("settlements_left", 0))
	var roads_left: int = int(p.get("roads_left", 0))

	# Ordered build targets we might be 1 resource short of
	var targets: Array[Dictionary] = []
	if cities_left > 0 and not city_verts.is_empty():
		targets.append({
			GameTypes.ResourceType.GRAIN: 2,
			GameTypes.ResourceType.IRON: 3,
		})
	if settlements_left > 0 and not settle_verts.is_empty():
		targets.append({
			GameTypes.ResourceType.TIMBER: 1,
			GameTypes.ResourceType.CLAY: 1,
			GameTypes.ResourceType.FLEECE: 1,
			GameTypes.ResourceType.GRAIN: 1,
		})
	if settlements_left > 0 and settle_verts.is_empty() and roads_left > 0 and not road_edges.is_empty():
		targets.append({
			GameTypes.ResourceType.TIMBER: 1,
			GameTypes.ResourceType.CLAY: 1,
		})
	if not state.dev_deck.is_empty():
		targets.append({
			GameTypes.ResourceType.FLEECE: 1,
			GameTypes.ResourceType.GRAIN: 1,
			GameTypes.ResourceType.IRON: 1,
		})
	if roads_left > 0 and not road_edges.is_empty():
		targets.append({
			GameTypes.ResourceType.TIMBER: 1,
			GameTypes.ResourceType.CLAY: 1,
		})

	for cost in targets:
		var missing_res: int = -1
		var missing_count: int = 0
		for r in cost.keys():
			var req: int = int(cost[r])
			var have: int = int(hand.get(r, 0))
			if have < req:
				missing_count += (req - have)
				missing_res = int(r)
		if missing_count == 1 and missing_res != -1:
			# Find a resource we have enough surplus of (beyond what `cost` needs) to trade at our port/maritime ratio
			var best_give: int = -1
			var best_surplus: int = -1
			for r in GameTypes.ALL_RESOURCES:
				if r == missing_res:
					continue
				var ratio: int = state.get_trade_ratio(player_id, r)
				var keep: int = int(cost.get(r, 0))
				var avail: int = int(hand.get(r, 0)) - keep
				if avail >= ratio and avail > best_surplus:
					best_surplus = avail
					best_give = r
			if best_give != -1:
				return GameAction.maritime_trade(best_give, missing_res)

	# Also if holding > 4 of any resource and missing a resource with 0 copies in hand, trade down to avoid 7-discard & unlock builds
	var best_overflow_res: int = -1
	var best_overflow_amt: int = 0
	for r in GameTypes.ALL_RESOURCES:
		var amt: int = int(hand.get(r, 0))
		var ratio: int = state.get_trade_ratio(player_id, r)
		if amt > 4 and amt >= ratio and amt > best_overflow_amt:
			best_overflow_amt = amt
			best_overflow_res = r

	if best_overflow_res != -1:
		var scariest_need: int = _choose_most_needed_resource(state, player_id, best_overflow_res)
		if scariest_need != -1 and scariest_need != best_overflow_res:
			return GameAction.maritime_trade(best_overflow_res, scariest_need)

	return {}

static func _choose_most_needed_resource(state: GameState, player_id: int, exclude_res: int = -1) -> int:
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]
	var best_r: int = -1
	var min_count: int = 999999
	for r in GameTypes.ALL_RESOURCES:
		if r == exclude_res:
			continue
		var c: int = int(hand.get(r, 0))
		if c < min_count:
			min_count = c
			best_r = r
	return best_r

static func _choose_harvest_bounty_resources(
	state: GameState,
	player_id: int,
	city_verts: Array[int],
	settle_verts: Array[int]
) -> Vector2i:
	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]

	# Check if 2 resources can complete a City
	if int(p.get("cities_left", 0)) > 0 and not city_verts.is_empty():
		var missing_city: Array[int] = []
		for i in range(max(0, 2 - int(hand.get(GameTypes.ResourceType.GRAIN, 0)))):
			missing_city.append(GameTypes.ResourceType.GRAIN)
		for i in range(max(0, 3 - int(hand.get(GameTypes.ResourceType.IRON, 0)))):
			missing_city.append(GameTypes.ResourceType.IRON)
		if missing_city.size() == 1:
			return Vector2i(missing_city[0], GameTypes.ResourceType.IRON)
		elif missing_city.size() == 2:
			return Vector2i(missing_city[0], missing_city[1])

	# Check if 2 resources can complete a Settlement
	if int(p.get("settlements_left", 0)) > 0 and not settle_verts.is_empty():
		var missing_settle: Array[int] = []
		for r in [
			GameTypes.ResourceType.TIMBER,
			GameTypes.ResourceType.CLAY,
			GameTypes.ResourceType.FLEECE,
			GameTypes.ResourceType.GRAIN
		]:
			if int(hand.get(r, 0)) < 1:
				missing_settle.append(r)
		if missing_settle.size() == 1:
			return Vector2i(missing_settle[0], GameTypes.ResourceType.GRAIN)
		elif missing_settle.size() == 2:
			return Vector2i(missing_settle[0], missing_settle[1])

	# Otherwise pick the two resources we have the least of
	var r1: int = _choose_most_needed_resource(state, player_id, -1)
	var r2: int = _choose_most_needed_resource(state, player_id, r1)
	if r1 < 0:
		r1 = GameTypes.ResourceType.GRAIN
	if r2 < 0:
		r2 = GameTypes.ResourceType.IRON
	return Vector2i(r1, r2)

static func _choose_trade_decree_resource(state: GameState, player_id: int) -> int:
	var best_res: int = GameTypes.ResourceType.GRAIN
	var best_opp_total: int = -1
	for r in GameTypes.ALL_RESOURCES:
		var total: int = 0
		for opp_id in range(state.num_players):
			if opp_id == player_id:
				continue
			total += int(state.players[opp_id]["hand"].get(r, 0))
		if total > best_opp_total:
			best_opp_total = total
			best_res = r
	return best_res

static func _tile_touches_player(state: GameState, tile_id: int, player_id: int) -> bool:
	if tile_id < 0 or tile_id >= 19:
		return false
	var topo := HexMath.get_topology()
	for v in topo.tile_vertices[tile_id]:
		if state.vertex_owner[v] == player_id:
			return true
	return false

static func _choose_blocker_target(state: GameState, player_id: int) -> Dictionary:
	var topo := HexMath.get_topology()
	var best_tile: int = -1
	var best_score: float = -999999.0
	var best_target_opp: int = -1

	for t_id in range(19):
		if t_id == state.blocker_tile:
			continue
		var touches_self: bool = false
		var opp_weight: float = 0.0
		var best_opp_on_tile: int = -1
		var best_opp_score: float = -1.0

		var pips: int = GameTypes.pip_count(state.tile_numbers[t_id])
		for v in topo.tile_vertices[t_id]:
			var owner: int = state.vertex_owner[v]
			if owner == player_id:
				touches_self = true
			elif owner != -1:
				var mult: int = 2 if state.vertex_building[v] == GameTypes.BuildingType.CITY else 1
				var vp: int = state.get_victory_points(owner, false)
				opp_weight += float(pips * mult) + float(vp) * 1.5
				var opp_cards: int = GameTypes.hand_total(state.players[owner]["hand"])
				var victim_score: float = float(vp) * 10.0 + (50.0 if opp_cards > 0 else 0.0) + float(opp_cards)
				if victim_score > best_opp_score:
					best_opp_score = victim_score
					best_opp_on_tile = owner

		var tile_score: float = opp_weight
		if touches_self:
			tile_score -= 1000.0
		if state.tile_terrains[t_id] == GameTypes.TerrainType.BARREN:
			tile_score -= 50.0

		if tile_score > best_score:
			best_score = tile_score
			best_tile = t_id
			best_target_opp = best_opp_on_tile

	if best_tile == -1:
		best_tile = (state.blocker_tile + 1) % 19

	return {
		"tile_id": best_tile,
		"target_player": best_target_opp,
	}

static func _choose_discards(state: GameState, player_id: int, count_needed: int) -> Dictionary:
	var hand: Dictionary = state.players[player_id]["hand"].duplicate()
	var discards: Dictionary = GameTypes.empty_hand()
	var remaining: int = count_needed

	while remaining > 0:
		var best_r: int = -1
		var max_amt: int = 0
		for r in GameTypes.ALL_RESOURCES:
			var amt: int = int(hand.get(r, 0))
			if amt > max_amt:
				max_amt = amt
				best_r = r
		if best_r == -1 or max_amt <= 0:
			break
		discards[best_r] = int(discards.get(best_r, 0)) + 1
		hand[best_r] = max_amt - 1
		remaining -= 1

	return discards

static func _should_accept_barter(state: GameState, player_id: int, barter: Dictionary) -> bool:
	var from_id: int = int(barter.get("from", -1))
	var offer: Dictionary = barter.get("offer", {})
	var request: Dictionary = barter.get("request", {})
	return _should_accept_terms(state, player_id, from_id, offer, request)

static func _should_accept_terms(
	state: GameState,
	player_id: int,
	from_id: int,
	offer: Dictionary,
	request: Dictionary
) -> bool:
	if from_id < 0 or from_id >= state.num_players:
		return false
	# Never help a player at >= 8 VP
	if state.get_victory_points(from_id, false) >= 8:
		return false

	var hand: Dictionary = state.players[player_id]["hand"]

	var offer_total: int = 0
	var request_total: int = 0
	for r in GameTypes.ALL_RESOURCES:
		var req_amt: int = int(request.get(r, 0))
		var off_amt: int = int(offer.get(r, 0))
		if req_amt > int(hand.get(r, 0)):
			return false
		# Do not give away a resource if it drops us to 0 unless we have > 2 of it
		if req_amt > 0 and int(hand.get(r, 0)) - req_amt < 1:
			return false
		offer_total += off_amt
		request_total += req_amt

	if offer_total <= 0 or request_total <= 0 or offer_total < request_total:
		return false

	# Accept if we gain at least one resource that we currently have <= 1 of
	for r in GameTypes.ALL_RESOURCES:
		if int(offer.get(r, 0)) > 0 and int(hand.get(r, 0)) <= 1:
			return true

	return false

static func _hand_has(hand: Dictionary, cost: Dictionary) -> bool:
	for r in cost.keys():
		if int(hand.get(r, 0)) < int(cost[r]):
			return false
	return true

static func _choose_open_trade_response(state: GameState, player_id: int, difficulty: int) -> Dictionary:
	var from_id: int = int(state.open_trade.get("from", -1))
	var offer: Dictionary = state.open_trade.get("offer", {})
	var request: Dictionary = state.open_trade.get("request", {})

	# Never help a player at >= 8 VP
	if state.get_victory_points(from_id, false) >= 8:
		return GameAction.respond_open_trade("decline")

	if _should_accept_terms(state, player_id, from_id, offer, request):
		return GameAction.respond_open_trade("accept")

	if difficulty >= 2:
		var hand: Dictionary = state.players[player_id]["hand"]
		var holds_part: bool = false
		for r in GameTypes.ALL_RESOURCES:
			if int(request.get(r, 0)) > 0 and int(hand.get(r, 0)) >= 1:
				holds_part = true
				break
		var wants_offer: bool = false
		for r in GameTypes.ALL_RESOURCES:
			if int(offer.get(r, 0)) > 0 and int(hand.get(r, 0)) <= 1:
				wants_offer = true
				break
		if holds_part and wants_offer:
			var terms: Dictionary = _choose_counter_terms(state, player_id, from_id, offer, request)
			if not terms.is_empty():
				var counter_offer: Dictionary = terms["offer"]
				var counter_request: Dictionary = terms["request"]
				return GameAction.respond_open_trade("counter", counter_offer, counter_request)

	return GameAction.respond_open_trade("decline")

static func _choose_counter_terms(
	state: GameState,
	player_id: int,
	proposer_id: int,
	offer: Dictionary,
	request: Dictionary
) -> Dictionary:
	var hand: Dictionary = state.players[player_id]["hand"]
	var proposer_hand: Dictionary = state.players[proposer_id]["hand"]
	var counter_offer: Dictionary = offer.duplicate()
	var counter_request: Dictionary = request.duplicate()

	# Option 1: ask for one extra card of a resource we want, keeping the same terms otherwise.
	if _hand_has(hand, counter_request):
		var chosen: Dictionary = {}
		var best_count: int = 999999
		for r in GameTypes.ALL_RESOURCES:
			if int(counter_request.get(r, 0)) > 0:
				continue
			var trial_offer: Dictionary = counter_offer.duplicate()
			trial_offer[r] = int(trial_offer.get(r, 0)) + 1
			if not _hand_has(proposer_hand, trial_offer):
				continue
			var held: int = int(hand.get(r, 0))
			if held < best_count:
				best_count = held
				chosen = {"offer": trial_offer, "request": counter_request.duplicate()}
		if not chosen.is_empty():
			return chosen

	# Option 2: swap a resource we are short on for one we have in surplus.
	for give_res in GameTypes.ALL_RESOURCES:
		if int(counter_request.get(give_res, 0)) <= 0:
			continue
		for take_res in GameTypes.ALL_RESOURCES:
			if take_res == give_res:
				continue
			if int(counter_offer.get(take_res, 0)) > 0:
				continue
			if int(counter_request.get(take_res, 0)) > 0:
				continue
			var surplus: int = int(hand.get(take_res, 0)) - int(counter_request.get(take_res, 0))
			if surplus < 2:
				continue
			var trial_request: Dictionary = counter_request.duplicate()
			trial_request[give_res] = int(trial_request.get(give_res, 0)) - 1
			trial_request[take_res] = int(trial_request.get(take_res, 0)) + 1
			if not _hand_has(hand, trial_request):
				continue
			if not _hand_has(proposer_hand, counter_offer):
				continue
			return {"offer": counter_offer.duplicate(), "request": trial_request}

	return {}

static func _choose_open_trade_proposer_action(state: GameState, player_id: int) -> Dictionary:
	var responses: Dictionary = state.open_trade.get("responses", {})
	var best_accept: int = -1
	var best_accept_vp: int = 999999
	var best_counter: int = -1
	var best_counter_vp: int = 999999

	for key in responses.keys():
		var partner: int = int(key)
		if partner == player_id:
			continue
		var response: Dictionary = responses[key]
		var status: String = str(response.get("status", ""))
		var partner_vp: int = state.get_victory_points(partner, false)
		if status == "accept":
			if partner_vp < best_accept_vp or (partner_vp == best_accept_vp and (best_accept == -1 or partner < best_accept)):
				best_accept_vp = partner_vp
				best_accept = partner
		elif status == "counter":
			var counter_offer: Dictionary = response.get("offer", {})
			var counter_request: Dictionary = response.get("request", {})
			# Proposer gives counter_offer and receives counter_request.
			if _should_accept_terms(state, player_id, partner, counter_request, counter_offer):
				if partner_vp < best_counter_vp or (partner_vp == best_counter_vp and (best_counter == -1 or partner < best_counter)):
					best_counter_vp = partner_vp
					best_counter = partner

	if best_accept != -1:
		return GameAction.finalize_open_trade(best_accept)
	if best_counter != -1:
		return GameAction.finalize_open_trade(best_counter)
	return GameAction.cancel_open_trade()

static func _choose_open_trade_action(
	state: GameState,
	player_id: int,
	difficulty: int,
	city_verts: Array[int],
	settle_verts: Array[int],
	road_edges: Array[int]
) -> Dictionary:
	if difficulty < 2:
		return {}
	if state.open_trades_this_turn != 0:
		return {}
	if not state.pending_barter.is_empty() or not state.open_trade.is_empty():
		return {}

	var p: Dictionary = state.players[player_id]
	var hand: Dictionary = p["hand"]

	var targets: Array[Dictionary] = []
	if int(p.get("cities_left", 0)) > 0 and not city_verts.is_empty():
		targets.append({
			GameTypes.ResourceType.GRAIN: 2,
			GameTypes.ResourceType.IRON: 3,
		})
	if int(p.get("settlements_left", 0)) > 0 and not settle_verts.is_empty():
		targets.append({
			GameTypes.ResourceType.TIMBER: 1,
			GameTypes.ResourceType.CLAY: 1,
			GameTypes.ResourceType.FLEECE: 1,
			GameTypes.ResourceType.GRAIN: 1,
		})
	if int(p.get("roads_left", 0)) > 0 and not road_edges.is_empty():
		targets.append({
			GameTypes.ResourceType.TIMBER: 1,
			GameTypes.ResourceType.CLAY: 1,
		})

	for cost in targets:
		var missing_res: int = -1
		var missing_count: int = 0
		for r in cost.keys():
			var req: int = int(cost[r])
			var have: int = int(hand.get(r, 0))
			if have < req:
				missing_count += (req - have)
				missing_res = int(r)
		if missing_count != 1 or missing_res == -1:
			continue

		var spare_res: int = -1
		var best_surplus: int = 0
		for r in GameTypes.ALL_RESOURCES:
			if r == missing_res:
				continue
			var keep: int = int(cost.get(r, 0))
			var surplus: int = int(hand.get(r, 0)) - keep
			if surplus > best_surplus:
				best_surplus = surplus
				spare_res = r
		if spare_res == -1:
			continue

		return GameAction.open_trade({spare_res: 1}, {missing_res: 1})

	return {}
