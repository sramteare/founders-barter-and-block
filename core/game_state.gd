class_name GameState
extends RefCounted

const TOTAL_RESOURCE_SUPPLY: int = 19

var seed_val: int = 0
var num_players: int = 4
var phase: int = GameTypes.TurnPhase.SETUP_SETTLEMENT_1
var current_player: int = 0
var start_player: int = 0
var turn_number: int = 1
var winner: int = -1

var setup_anchor_vertex: int = -1

var tile_terrains: Array[int] = []
var tile_numbers: Array[int] = []
var blocker_tile: int = 0
var vertex_ports: Array[int] = []

var vertex_owner: Array[int] = []
var vertex_building: Array[int] = []
var edge_owner: Array[int] = []

var players: Array = []
var dev_deck: Array[int] = []
var bank: Dictionary = {}
var last_steal: Dictionary = {}

var pending_discards: Dictionary = {}
var open_trade: Dictionary = {}
var open_trades_this_turn: int = 0
var road_work_remaining: int = 0
var last_dice: Vector2i = Vector2i(0, 0)

var longest_route_holder: int = -1
var largest_guard_holder: int = -1

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

static func create_new_game(seed_val_in: int, num_players_in: int = 4, balanced: bool = true) -> GameState:
	var gs := GameState.new()
	gs.seed_val = seed_val_in
	gs.num_players = clampi(num_players_in, 2, 4)
	gs.phase = GameTypes.TurnPhase.SETUP_SETTLEMENT_1
	gs.current_player = 0
	gs.start_player = 0
	gs.turn_number = 1
	gs.winner = -1
	gs.setup_anchor_vertex = -1

	gs.rng = RandomNumberGenerator.new()
	gs.rng.seed = seed_val_in ^ 0x5A5A5A5A

	var board: Dictionary = BoardGenerator.generate(seed_val_in, balanced)
	gs.tile_terrains = board["tile_terrains"]
	gs.tile_numbers = board["tile_numbers"]
	gs.blocker_tile = board["blocker_tile"]
	gs.vertex_ports = board["vertex_ports"]

	# The start player is drawn from the game RNG AFTER the board was generated,
	# so boards for a given seed never change.
	gs.start_player = gs.rng.randi_range(0, gs.num_players - 1)
	gs.current_player = gs.start_player

	gs.vertex_owner = []
	gs.vertex_owner.resize(54)
	gs.vertex_owner.fill(-1)

	gs.vertex_building = []
	gs.vertex_building.resize(54)
	gs.vertex_building.fill(GameTypes.BuildingType.NONE)

	gs.edge_owner = []
	gs.edge_owner.resize(72)
	gs.edge_owner.fill(-1)

	gs.bank = {}
	for r in GameTypes.ALL_RESOURCES:
		gs.bank[r] = TOTAL_RESOURCE_SUPPLY
	gs.last_steal = {}

	gs.players = []
	for p in range(gs.num_players):
		var dev_cards_arr: Array[int] = []
		var new_dev_cards_arr: Array[int] = []
		gs.players.append({
			"id": p,
			"name": GameTypes.PLAYER_NAMES[p],
			"hand": GameTypes.empty_hand(),
			"dev_cards": dev_cards_arr,
			"new_dev_cards": new_dev_cards_arr,
			"played_guards": 0,
			"played_dev": {},
			"played_dev_this_turn": false,
			"settlements_left": 5,
			"cities_left": 4,
			"roads_left": 15,
			"longest_route_length": 0,
		})

	gs.dev_deck = []
	for _i in range(14):
		gs.dev_deck.append(GameTypes.DevCardType.GUARD)
	for _i in range(2):
		gs.dev_deck.append(GameTypes.DevCardType.ROAD_WORK)
	for _i in range(2):
		gs.dev_deck.append(GameTypes.DevCardType.HARVEST_BOUNTY)
	for _i in range(2):
		gs.dev_deck.append(GameTypes.DevCardType.TRADE_DECREE)
	for _i in range(5):
		gs.dev_deck.append(GameTypes.DevCardType.CHARTER_POINT)

	for i in range(gs.dev_deck.size() - 1, 0, -1):
		var j := gs.rng.randi_range(0, i)
		var tmp: int = gs.dev_deck[i]
		gs.dev_deck[i] = gs.dev_deck[j]
		gs.dev_deck[j] = tmp

	return gs

func get_victory_points(player_id: int, include_hidden: bool = true) -> int:
	if player_id < 0 or player_id >= num_players:
		return 0
	var vp := 0
	for v in range(vertex_owner.size()):
		if vertex_owner[v] == player_id:
			if vertex_building[v] == GameTypes.BuildingType.SETTLEMENT:
				vp += 1
			elif vertex_building[v] == GameTypes.BuildingType.CITY:
				vp += 2

	if longest_route_holder == player_id:
		vp += 2
	if largest_guard_holder == player_id:
		vp += 2

	if include_hidden:
		var p: Dictionary = players[player_id]
		for card in p["dev_cards"]:
			if card == GameTypes.DevCardType.CHARTER_POINT:
				vp += 1
		for card in p["new_dev_cards"]:
			if card == GameTypes.DevCardType.CHARTER_POINT:
				vp += 1
	return vp

func get_trade_ratio(player_id: int, res: int) -> int:
	var best_ratio := 4
	for v in range(vertex_owner.size()):
		if vertex_owner[v] == player_id and vertex_building[v] != GameTypes.BuildingType.NONE:
			var port: int = vertex_ports[v]
			if port == res:
				return 2
			elif port == GameTypes.PortType.GENERIC_3_TO_1 and best_ratio > 3:
				best_ratio = 3
	return best_ratio

func resource_totals_ok() -> bool:
	for r in GameTypes.ALL_RESOURCES:
		var total := int(bank.get(r, 0))
		for p in range(num_players):
			total += int(players[p]["hand"].get(r, 0))
		if total != TOTAL_RESOURCE_SUPPLY:
			return false
	return true

func get_standings() -> Array:
	var rows: Array = []
	for p in range(num_players):
		var pd: Dictionary = players[p]
		var settlements := 0
		var cities := 0
		for v in range(vertex_owner.size()):
			if vertex_owner[v] == p:
				if vertex_building[v] == GameTypes.BuildingType.SETTLEMENT:
					settlements += 1
				elif vertex_building[v] == GameTypes.BuildingType.CITY:
					cities += 1
		var charters := 0
		for c in pd["dev_cards"]:
			if int(c) == GameTypes.DevCardType.CHARTER_POINT:
				charters += 1
		for c in pd["new_dev_cards"]:
			if int(c) == GameTypes.DevCardType.CHARTER_POINT:
				charters += 1
		rows.append({
			"pid": p,
			"name": pd["name"],
			"vp": get_victory_points(p, true),
			"settlements": settlements,
			"cities": cities,
			"longest_route": longest_route_holder == p,
			"largest_guard": largest_guard_holder == p,
			"charters": charters,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["vp"]) != int(b["vp"]):
			return int(a["vp"]) > int(b["vp"])
		if int(a["cities"]) != int(b["cities"]):
			return int(a["cities"]) > int(b["cities"])
		if int(a["settlements"]) != int(b["settlements"]):
			return int(a["settlements"]) > int(b["settlements"])
		return int(a["pid"]) < int(b["pid"])
	)
	return rows

func clone() -> GameState:
	var copy := GameState.new()
	copy.seed_val = seed_val
	copy.num_players = num_players
	copy.phase = phase
	copy.current_player = current_player
	copy.start_player = start_player
	copy.turn_number = turn_number
	copy.winner = winner
	copy.setup_anchor_vertex = setup_anchor_vertex

	copy.tile_terrains = tile_terrains.duplicate()
	copy.tile_numbers = tile_numbers.duplicate()
	copy.blocker_tile = blocker_tile
	copy.vertex_ports = vertex_ports.duplicate()

	copy.vertex_owner = vertex_owner.duplicate()
	copy.vertex_building = vertex_building.duplicate()
	copy.edge_owner = edge_owner.duplicate()

	copy.players = []
	for p in players:
		var dev_copy: Array[int] = []
		dev_copy.assign(p["dev_cards"])
		var new_dev_copy: Array[int] = []
		new_dev_copy.assign(p["new_dev_cards"])
		copy.players.append({
			"id": p["id"],
			"name": p["name"],
			"hand": p["hand"].duplicate(),
			"dev_cards": dev_copy,
			"new_dev_cards": new_dev_copy,
			"played_guards": p["played_guards"],
			"played_dev": (p.get("played_dev", {}) as Dictionary).duplicate(),
			"played_dev_this_turn": p["played_dev_this_turn"],
			"settlements_left": p["settlements_left"],
			"cities_left": p["cities_left"],
			"roads_left": p["roads_left"],
			"longest_route_length": p["longest_route_length"],
		})

	copy.dev_deck = dev_deck.duplicate()
	copy.bank = bank.duplicate()
	copy.last_steal = last_steal.duplicate()
	copy.pending_discards = pending_discards.duplicate()
	copy.open_trade = open_trade.duplicate(true)
	copy.open_trades_this_turn = open_trades_this_turn
	copy.road_work_remaining = road_work_remaining
	copy.last_dice = last_dice
	copy.longest_route_holder = longest_route_holder
	copy.largest_guard_holder = largest_guard_holder

	copy.rng = RandomNumberGenerator.new()
	copy.rng.state = rng.state
	return copy
