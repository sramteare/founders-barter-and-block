class_name GameAction
extends RefCounted

static func roll_dice() -> Dictionary:
	return {"type": "roll_dice"}

static func place_settlement(vertex_id: int) -> Dictionary:
	return {"type": "place_settlement", "vertex_id": vertex_id}

static func place_road(edge_id: int) -> Dictionary:
	return {"type": "place_road", "edge_id": edge_id}

static func upgrade_city(vertex_id: int) -> Dictionary:
	return {"type": "upgrade_city", "vertex_id": vertex_id}

static func move_blocker(tile_id: int, target_player: int = -1) -> Dictionary:
	return {"type": "move_blocker", "tile_id": tile_id, "target_player": target_player}

static func discard_resources(resources: Dictionary) -> Dictionary:
	return {"type": "discard_resources", "resources": resources.duplicate()}

static func maritime_trade(give_res: int, get_res: int) -> Dictionary:
	return {"type": "maritime_trade", "give_res": give_res, "get_res": get_res}

static func propose_barter(target_player: int, offer: Dictionary, request: Dictionary) -> Dictionary:
	return {
		"type": "propose_barter",
		"target_player": target_player,
		"offer": offer.duplicate(),
		"request": request.duplicate(),
	}

static func respond_barter(accept: bool) -> Dictionary:
	return {"type": "respond_barter", "accept": accept}

static func open_trade(offer: Dictionary, request: Dictionary) -> Dictionary:
	return {
		"type": "open_trade",
		"offer": offer.duplicate(),
		"request": request.duplicate(),
	}

static func respond_open_trade(status: String, offer: Dictionary = {}, request: Dictionary = {}) -> Dictionary:
	return {
		"type": "respond_open_trade",
		"status": status,
		"offer": offer.duplicate(),
		"request": request.duplicate(),
	}

static func finalize_open_trade(partner: int) -> Dictionary:
	return {"type": "finalize_open_trade", "partner": partner}

static func cancel_open_trade() -> Dictionary:
	return {"type": "cancel_open_trade"}

static func buy_dev_card() -> Dictionary:
	return {"type": "buy_dev_card"}

static func play_guard(tile_id: int, target_player: int = -1) -> Dictionary:
	return {"type": "play_guard", "tile_id": tile_id, "target_player": target_player}

static func play_road_work() -> Dictionary:
	return {"type": "play_road_work"}

static func play_harvest_bounty(res1: int, res2: int) -> Dictionary:
	return {"type": "play_harvest_bounty", "res1": res1, "res2": res2}

static func play_trade_decree(res: int) -> Dictionary:
	return {"type": "play_trade_decree", "res": res}

static func end_turn() -> Dictionary:
	return {"type": "end_turn"}
