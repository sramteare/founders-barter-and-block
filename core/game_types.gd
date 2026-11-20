class_name GameTypes
extends RefCounted

enum ResourceType {
	TIMBER = 0,
	CLAY = 1,
	FLEECE = 2,
	GRAIN = 3,
	IRON = 4,
}

const ALL_RESOURCES: Array[int] = [
	ResourceType.TIMBER,
	ResourceType.CLAY,
	ResourceType.FLEECE,
	ResourceType.GRAIN,
	ResourceType.IRON,
]

enum TerrainType {
	FOREST = 0,   # Produces TIMBER
	HILLS = 1,    # Produces CLAY
	PASTURE = 2,  # Produces FLEECE
	FIELDS = 3,   # Produces GRAIN
	MOUNTAINS = 4,# Produces IRON
	BARREN = 5,   # Produces nothing (starts with Blocker)
}

enum PortType {
	GENERIC_3_TO_1 = -1,
	TIMBER_2_TO_1 = 0,
	CLAY_2_TO_1 = 1,
	FLEECE_2_TO_1 = 2,
	GRAIN_2_TO_1 = 3,
	IRON_2_TO_1 = 4,
}

enum BuildingType {
	NONE = 0,
	SETTLEMENT = 1,
	CITY = 2,
}

enum DevCardType {
	GUARD = 0,          # Move Blocker & steal 1 resource (counts toward Largest Guard)
	ROAD_WORK = 1,      # Place up to 2 free roads
	HARVEST_BOUNTY = 2, # Take any 2 resources from the bank
	TRADE_DECREE = 3,   # Name 1 resource; all other players give you all of theirs
	CHARTER_POINT = 4,  # +1 Victory Point
}

enum TurnPhase {
	SETUP_SETTLEMENT_1 = 0,
	SETUP_ROAD_1 = 1,
	SETUP_SETTLEMENT_2 = 2,
	SETUP_ROAD_2 = 3,
	TURN_ROLL = 4,
	TURN_DISCARD = 5,
	TURN_MOVE_BLOCKER = 6,
	TURN_MAIN = 7,
	TURN_ROAD_WORK = 8,
	GAME_OVER = 9,
}

const PLAYER_COLORS: Array[Color] = [
	Color(0.89, 0.29, 0.24), # Red
	Color(0.22, 0.53, 0.87), # Blue
	Color(0.93, 0.62, 0.16), # Orange/Gold
	Color(0.92, 0.92, 0.94), # Ivory/White
]

const PLAYER_NAMES: Array[String] = [
	"Crimson",
	"Azure",
	"Amber",
	"Ivory",
]

static func resource_name(res: int) -> String:
	match res:
		ResourceType.TIMBER: return "Timber"
		ResourceType.CLAY: return "Clay"
		ResourceType.FLEECE: return "Fleece"
		ResourceType.GRAIN: return "Grain"
		ResourceType.IRON: return "Iron"
		_: return "Unknown"

static func terrain_to_resource(terrain: int) -> int:
	match terrain:
		TerrainType.FOREST: return ResourceType.TIMBER
		TerrainType.HILLS: return ResourceType.CLAY
		TerrainType.PASTURE: return ResourceType.FLEECE
		TerrainType.FIELDS: return ResourceType.GRAIN
		TerrainType.MOUNTAINS: return ResourceType.IRON
		_: return -1

static func pip_count(dice_num: int) -> int:
	match dice_num:
		2, 12: return 1
		3, 11: return 2
		4, 10: return 3
		5, 9: return 4
		6, 8: return 5
		_: return 0

static func empty_hand() -> Dictionary:
	return {
		ResourceType.TIMBER: 0,
		ResourceType.CLAY: 0,
		ResourceType.FLEECE: 0,
		ResourceType.GRAIN: 0,
		ResourceType.IRON: 0,
	}

static func hand_total(hand: Dictionary) -> int:
	var total := 0
	for r in ALL_RESOURCES:
		total += int(hand.get(r, 0))
	return total
