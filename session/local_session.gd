class_name LocalSession
extends RefCounted

signal state_updated(state: GameState, events: Array[String])
signal action_rejected(player_id: int, error: String)

var state: GameState = null
var seats: Array[SeatConfig] = []
var _ai_steps_in_turn: int = 0
var _last_tracked_turn: int = -1
var _last_tracked_player: int = -1

func start_match(seed_val: int, seat_configs: Array[SeatConfig], balanced: bool = true) -> void:
	seats.clear()
	if seat_configs.is_empty():
		seats.append(SeatConfig.new(0, SeatConfig.SeatType.HUMAN, GameTypes.PLAYER_NAMES[0]))
		for i in range(1, 4):
			seats.append(SeatConfig.new(i, SeatConfig.SeatType.AI_MEDIUM, GameTypes.PLAYER_NAMES[i]))
	else:
		for sc in seat_configs:
			seats.append(sc)

	var num_p: int = clampi(seats.size(), 2, 4)
	state = GameState.create_new_game(seed_val, num_p, balanced)
	for i in range(min(seats.size(), state.players.size())):
		if not seats[i].display_name.is_empty():
			state.players[i]["name"] = seats[i].display_name

	_ai_steps_in_turn = 0
	_last_tracked_turn = state.turn_number
	_last_tracked_player = state.current_player

	var init_events: Array[String] = ["Match started with %d seats (Seed: %d)." % [num_p, seed_val]]
	state_updated.emit(state, init_events)

func submit_action(player_id: int, action: Dictionary) -> Dictionary:
	if state == null:
		var err_msg := "Match has not been started."
		action_rejected.emit(player_id, err_msg)
		return {"ok": false, "error": err_msg, "events": [] as Array[String]}

	var result: Dictionary = RulesEngine.apply_action(state, player_id, action)
	if bool(result.get("ok", false)):
		var typed_events: Array[String] = []
		var raw_events = result.get("events", [])
		if raw_events is Array:
			for ev in raw_events:
				typed_events.append(str(ev))
		state_updated.emit(state, typed_events)
	else:
		var err_str: String = str(result.get("error", "Invalid action."))
		action_rejected.emit(player_id, err_str)
	return result

func get_acting_player_id() -> int:
	if state == null:
		return 0
	if state.phase == GameTypes.TurnPhase.TURN_DISCARD and not state.pending_discards.is_empty():
		for p_id in range(state.num_players):
			if state.pending_discards.has(p_id) and int(state.pending_discards[p_id]) > 0:
				return p_id
		for k in state.pending_discards.keys():
			if int(state.pending_discards[k]) > 0:
				return int(k)
	if not state.open_trade.is_empty():
		var proposer: int = int(state.open_trade.get("from", state.current_player))
		var responses: Dictionary = state.open_trade.get("responses", {})
		for p_id in range(state.num_players):
			if p_id == proposer:
				continue
			if not responses.has(p_id):
				return p_id
		return proposer
	if not state.pending_barter.is_empty():
		var target_to: int = int(state.pending_barter.get("to", -1))
		if target_to >= 0 and target_to < state.num_players:
			return target_to
	return state.current_player

func is_ai_to_act() -> bool:
	if state == null or state.phase == GameTypes.TurnPhase.GAME_OVER:
		return false
	var acting_id: int = get_acting_player_id()
	if acting_id < 0 or acting_id >= seats.size():
		return false
	return seats[acting_id].is_ai()

func step_ai() -> Dictionary:
	if not is_ai_to_act():
		return {"ok": false, "error": "Not an AI seat's turn to act.", "events": [] as Array[String]}

	var acting_id: int = get_acting_player_id()
	if state.turn_number != _last_tracked_turn or state.current_player != _last_tracked_player:
		_last_tracked_turn = state.turn_number
		_last_tracked_player = state.current_player
		_ai_steps_in_turn = 0
	_ai_steps_in_turn += 1

	# Safety guard against excessive AI actions within a single turn
	if _ai_steps_in_turn > 20 and state.phase == GameTypes.TurnPhase.TURN_MAIN:
		if not state.open_trade.is_empty():
			if int(state.open_trade.get("from", -1)) == acting_id:
				return submit_action(acting_id, GameAction.cancel_open_trade())
			return submit_action(acting_id, GameAction.respond_open_trade("decline"))
		return submit_action(acting_id, GameAction.end_turn())

	var difficulty: int = seats[acting_id].get_difficulty()
	var action: Dictionary = BotController.choose_action(state, acting_id, difficulty)
	var result: Dictionary = submit_action(acting_id, action)

	if not bool(result.get("ok", false)):
		return _execute_fallback_action(acting_id)

	return result

func set_ai_difficulty(level: int) -> void:
	var clamped: int = clampi(level, 1, 3)
	var target_type: int = SeatConfig.SeatType.AI_MEDIUM
	match clamped:
		1:
			target_type = SeatConfig.SeatType.AI_EASY
		2:
			target_type = SeatConfig.SeatType.AI_MEDIUM
		3:
			target_type = SeatConfig.SeatType.AI_HARD
	for seat in seats:
		if seat.is_ai():
			seat.seat_type = target_type

func get_ai_difficulty() -> int:
	for seat in seats:
		if seat.is_ai():
			return seat.get_difficulty()
	return 2

func _execute_fallback_action(acting_id: int) -> Dictionary:
	if not state.open_trade.is_empty():
		var proposer: int = int(state.open_trade.get("from", -1))
		if acting_id == proposer:
			return submit_action(acting_id, GameAction.cancel_open_trade())
		return submit_action(acting_id, GameAction.respond_open_trade("decline"))

	if not state.pending_barter.is_empty() and int(state.pending_barter.get("to", -1)) == acting_id:
		return submit_action(acting_id, GameAction.respond_barter(false))

	match state.phase:
		GameTypes.TurnPhase.TURN_MAIN:
			return submit_action(acting_id, GameAction.end_turn())
		GameTypes.TurnPhase.TURN_ROAD_WORK:
			state.road_work_remaining = 0
			state.phase = GameTypes.TurnPhase.TURN_MAIN
			return submit_action(acting_id, GameAction.end_turn())
		GameTypes.TurnPhase.TURN_ROLL:
			return submit_action(acting_id, GameAction.roll_dice())
		GameTypes.TurnPhase.TURN_MOVE_BLOCKER:
			var alt_tile: int = (state.blocker_tile + 1) % 19
			return submit_action(acting_id, GameAction.move_blocker(alt_tile, -1))
		_:
			return {"ok": false, "error": "AI fallback could not resolve action.", "events": [] as Array[String]}
