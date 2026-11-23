class_name ReviewSession
extends LocalSession

# Read-only LocalSession surface for replay review. The game never advances
# through this object: main_ui assigns `state` from MatchReplay.state_at()
# and every mutation path is inert.

func submit_action(player_id: int, _action: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"error": "Review mode — the match is finished.",
		"events": [] as Array[String],
	}

func step_ai() -> Dictionary:
	return {"ok": false, "error": "Review mode — the match is finished.", "events": [] as Array[String]}

func is_ai_to_act() -> bool:
	return false
