class_name SeatConfig
extends RefCounted

enum SeatType {
	HUMAN = 0,
	AI_EASY = 1,
	AI_MEDIUM = 2,
	AI_HARD = 3,
}

var seat_id: int = 0
var seat_type: int = SeatType.HUMAN
var display_name: String = ""

func _init(p_seat_id: int = 0, p_seat_type: int = SeatType.HUMAN, p_display_name: String = "") -> void:
	seat_id = p_seat_id
	seat_type = p_seat_type
	if p_display_name.is_empty():
		if p_seat_id >= 0 and p_seat_id < GameTypes.PLAYER_NAMES.size():
			display_name = GameTypes.PLAYER_NAMES[p_seat_id]
		else:
			display_name = "Player %d" % (p_seat_id + 1)
	else:
		display_name = p_display_name

func is_ai() -> bool:
	return seat_type != SeatType.HUMAN

func get_difficulty() -> int:
	match seat_type:
		SeatType.AI_EASY:
			return 1
		SeatType.AI_MEDIUM:
			return 2
		SeatType.AI_HARD:
			return 3
		_:
			return 2
