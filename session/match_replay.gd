class_name MatchReplay
extends RefCounted

const VERSION := 1
const SNAPSHOT_EVERY := 25

var version := VERSION
var seed_val := 0
var balanced := true
var forced_start_player := -1
var seats: Array = []
var entries: Array = []
var standings: Array = []
var winner := -1

var _initial_turn := 1
var _snapshots: Dictionary = {}

func begin_match(p_seed: int, p_balanced: bool, p_forced_start: int, seat_configs: Array, live: GameState) -> void:
	version = VERSION
	seed_val = p_seed
	balanced = p_balanced
	forced_start_player = p_forced_start
	seats = []
	for sc in seat_configs:
		seats.append({
			"idx": int(sc.seat_id),
			"type": int(sc.seat_type),
			"name": str(sc.display_name),
		})
	entries = []
	standings = []
	winner = -1
	_snapshots = {}
	_initial_turn = int(live.turn_number)
	_snapshots[0] = live.clone()

func record_action(player_id: int, action: Dictionary, events: Array, turn_number: int) -> void:
	entries.append({
		"p": int(player_id),
		"a": action.duplicate(true),
		"ev": events.duplicate(),
		"turn": int(turn_number),
	})

func record_patch(fields: Dictionary) -> void:
	entries.append({"t": "set", "f": fields.duplicate(true)})

func maybe_snapshot(state: GameState) -> void:
	var n := entries.size()
	if n > 0 and n % SNAPSHOT_EVERY == 0 and not _snapshots.has(n):
		_snapshots[n] = state.clone()

func set_final(state: GameState) -> void:
	winner = int(state.winner)
	standings = []
	for row in state.get_standings():
		standings.append(_int_normalise(row))

func step_count() -> int:
	return entries.size()

func state_at(step: int) -> GameState:
	var n: int = clampi(step, 0, entries.size())
	if not _snapshots.has(0):
		_snapshots[0] = _rebuild_initial_state()
	var base := int(floor(float(n) / float(SNAPSHOT_EVERY))) * SNAPSHOT_EVERY
	while base > 0 and not _snapshots.has(base):
		base -= SNAPSHOT_EVERY
	var st: GameState = (_snapshots[base] as GameState).clone()
	for i in range(base, n):
		var e: Dictionary = entries[i]
		if str(e.get("t", "")) == "set":
			for fkey in (e["f"] as Dictionary).keys():
				st.set(str(fkey), e["f"][fkey])
		else:
			RulesEngine.apply_action(st, int(e["p"]), e["a"])
		if (i + 1) % SNAPSHOT_EVERY == 0 and not _snapshots.has(i + 1):
			_snapshots[i + 1] = st.clone()
	return st

func events_at(step: int) -> Array:
	if step <= 0 or step > entries.size():
		return []
	var e: Dictionary = entries[step - 1]
	if str(e.get("t", "")) == "set":
		return []
	return (e.get("ev", []) as Array).duplicate()

func turn_at(step: int) -> int:
	if step <= 0:
		return _initial_turn
	if step > entries.size():
		step = entries.size()
	return int(entries[step - 1].get("turn", _initial_turn))

func first_step_of_turn(turn_number: int) -> int:
	if _initial_turn == turn_number:
		return 0
	for i in range(entries.size()):
		if int(entries[i].get("turn", _initial_turn)) == turn_number:
			return i + 1
	return -1

func _rebuild_initial_state() -> GameState:
	var num_p: int = clampi(seats.size(), 2, 4)
	var gs := GameState.create_new_game(seed_val, num_p, balanced)
	if forced_start_player >= 0:
		gs.start_player = forced_start_player % num_p
		gs.current_player = gs.start_player
	for s in seats:
		var idx := int((s as Dictionary).get("idx", -1))
		var nm := str((s as Dictionary).get("name", ""))
		if idx >= 0 and idx < gs.players.size() and nm != "":
			gs.players[idx]["name"] = nm
	return gs

func to_dict() -> Dictionary:
	return {
		"version": version,
		"seed": seed_val,
		"balanced": balanced,
		"forced_start_player": forced_start_player,
		"initial_turn": _initial_turn,
		"seats": seats.duplicate(true),
		"entries": entries.duplicate(true),
		"standings": standings.duplicate(true),
		"winner": winner,
	}

static func from_dict(d: Dictionary) -> MatchReplay:
	if d.is_empty() or int(d.get("version", 0)) > VERSION or int(d.get("version", 0)) < 1:
		return null
	var r: MatchReplay = (load("res://session/match_replay.gd") as GDScript).new()
	r.version = int(d.get("version", VERSION))
	r.seed_val = int(d.get("seed", 0))
	r.balanced = bool(d.get("balanced", true))
	r.forced_start_player = int(d.get("forced_start_player", -1))
	r._initial_turn = int(d.get("initial_turn", 1))
	r.winner = int(d.get("winner", -1))
	r.seats = []
	for s in (d.get("seats", []) as Array):
		r.seats.append(_int_normalise(s))
	r.entries = []
	for e in (d.get("entries", []) as Array):
		var ed: Dictionary = _int_normalise(e) as Dictionary
		r.entries.append(ed)
	r.standings = []
	for row in (d.get("standings", []) as Array):
		r.standings.append(_int_normalise(row))
	r._snapshots = {}
	return r

func save_to_file(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict()))
	f.flush()
	f.close()
	return OK

static func load_from_file(path: String) -> MatchReplay:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return from_dict(parsed as Dictionary)

static func _int_normalise(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			if is_finite(v) and float(v) == floor(float(v)):
				return int(round(float(v)))
			return v
		TYPE_ARRAY:
			var out: Array = []
			for item in (v as Array):
				out.append(_int_normalise(item))
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			var keys: Array = (v as Dictionary).keys()
			var all_int_keys := not keys.is_empty()
			for k in keys:
				if not (typeof(k) == TYPE_STRING and str(k).is_valid_int()):
					all_int_keys = false
					break
			for k in keys:
				var nk: Variant = int(str(k)) if (all_int_keys and typeof(k) == TYPE_STRING) else k
				d[nk] = _int_normalise((v as Dictionary)[k])
			return d
		_:
			return v
