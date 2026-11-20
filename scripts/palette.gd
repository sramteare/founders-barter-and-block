class_name Palette
extends RefCounted

# Backdrop / sea
const SKY_TOP: Color = Color(0.80, 0.90, 0.92)
const SEA: Color = Color(0.52, 0.75, 0.80)
const SEA_DEEP: Color = Color(0.38, 0.63, 0.72)
const SEA_FOAM: Color = Color(0.93, 0.97, 0.95, 0.85)
const CLOUD: Color = Color(1.0, 0.99, 0.95, 0.55)

# Ink & paper
const INK: Color = Color(0.29, 0.22, 0.17)
const INK_SOFT: Color = Color(0.29, 0.22, 0.17, 0.45)
const PAPER: Color = Color(0.97, 0.93, 0.83)
const PAPER_DARK: Color = Color(0.91, 0.85, 0.72)
const PAPER_SHADOW: Color = Color(0.25, 0.18, 0.12, 0.22)

# Terrain base / shade / light
const FOREST: Color = Color(0.36, 0.55, 0.36)
const FOREST_SHADE: Color = Color(0.27, 0.44, 0.29)
const FOREST_LIGHT: Color = Color(0.48, 0.66, 0.45)

const PASTURE: Color = Color(0.66, 0.80, 0.47)
const PASTURE_SHADE: Color = Color(0.54, 0.70, 0.38)
const PASTURE_LIGHT: Color = Color(0.78, 0.88, 0.60)

const FIELD: Color = Color(0.94, 0.81, 0.45)
const FIELD_SHADE: Color = Color(0.83, 0.68, 0.35)
const FIELD_LIGHT: Color = Color(0.98, 0.90, 0.63)

const CLAY: Color = Color(0.82, 0.53, 0.39)
const CLAY_SHADE: Color = Color(0.70, 0.42, 0.30)
const CLAY_LIGHT: Color = Color(0.90, 0.66, 0.52)

const MOUNTAIN: Color = Color(0.58, 0.62, 0.69)
const MOUNTAIN_SHADE: Color = Color(0.46, 0.50, 0.58)
const MOUNTAIN_LIGHT: Color = Color(0.70, 0.74, 0.80)

const BARREN: Color = Color(0.89, 0.81, 0.64)
const BARREN_SHADE: Color = Color(0.79, 0.70, 0.53)
const BARREN_LIGHT: Color = Color(0.95, 0.90, 0.76)

# Resources
const RES_TIMBER: Color = Color(0.45, 0.58, 0.32)
const RES_CLAY: Color = Color(0.80, 0.48, 0.35)
const RES_FLEECE: Color = Color(0.95, 0.91, 0.82)
const RES_GRAIN: Color = Color(0.93, 0.75, 0.35)
const RES_IRON: Color = Color(0.55, 0.60, 0.66)

# UI
const PANEL_BG: Color = Color(0.97, 0.93, 0.83)
const PANEL_BG_ALT: Color = Color(0.94, 0.89, 0.77)
const PANEL_BORDER: Color = Color(0.55, 0.42, 0.30)
const TEXT: Color = Color(0.29, 0.22, 0.17)
const TEXT_MUTED: Color = Color(0.45, 0.38, 0.30)
const TEXT_ON_DARK: Color = Color(0.97, 0.93, 0.83)
const HEADING: Color = Color(0.20, 0.42, 0.40)
const ACCENT_GOLD: Color = Color(0.90, 0.68, 0.26)
const ACCENT_RED: Color = Color(0.80, 0.37, 0.31)
const ACCENT_GREEN: Color = Color(0.42, 0.66, 0.40)
const BUTTON_BG: Color = Color(0.90, 0.83, 0.68)
const BUTTON_BG_HOVER: Color = Color(0.94, 0.88, 0.74)
const BUTTON_BG_PRESSED: Color = Color(0.83, 0.75, 0.60)
const BUTTON_BG_DISABLED: Color = Color(0.84, 0.81, 0.74)
const BUTTON_TEXT: Color = Color(0.29, 0.22, 0.17)
const TOAST_BG: Color = Color(0.20, 0.42, 0.40, 0.92)
const TOAST_TEXT: Color = Color(0.97, 0.93, 0.83)
const HIGHLIGHT: Color = Color(0.98, 0.84, 0.45, 0.55)
const HIGHLIGHT_INVALID: Color = Color(0.80, 0.37, 0.31, 0.55)

# Tokens
const NUMBER_TOKEN_BG: Color = Color(0.96, 0.92, 0.82)
const NUMBER_TOKEN_TEXT: Color = Color(0.29, 0.22, 0.17)
const NUMBER_TOKEN_HOT: Color = Color(0.80, 0.37, 0.31)
const BLOCKER: Color = Color(0.32, 0.27, 0.23)
const DOCK_WOOD: Color = Color(0.60, 0.45, 0.30)
const DICE_FACE: Color = Color(0.97, 0.94, 0.86)
const DICE_PIP: Color = Color(0.29, 0.22, 0.17)


static func terrain(t: int) -> Color:
	match t:
		GameTypes.TerrainType.FOREST: return FOREST
		GameTypes.TerrainType.HILLS: return CLAY
		GameTypes.TerrainType.PASTURE: return PASTURE
		GameTypes.TerrainType.FIELDS: return FIELD
		GameTypes.TerrainType.MOUNTAINS: return MOUNTAIN
		GameTypes.TerrainType.BARREN: return BARREN
		_: return BARREN


static func terrain_shade(t: int) -> Color:
	match t:
		GameTypes.TerrainType.FOREST: return FOREST_SHADE
		GameTypes.TerrainType.HILLS: return CLAY_SHADE
		GameTypes.TerrainType.PASTURE: return PASTURE_SHADE
		GameTypes.TerrainType.FIELDS: return FIELD_SHADE
		GameTypes.TerrainType.MOUNTAINS: return MOUNTAIN_SHADE
		GameTypes.TerrainType.BARREN: return BARREN_SHADE
		_: return BARREN_SHADE


static func terrain_light(t: int) -> Color:
	match t:
		GameTypes.TerrainType.FOREST: return FOREST_LIGHT
		GameTypes.TerrainType.HILLS: return CLAY_LIGHT
		GameTypes.TerrainType.PASTURE: return PASTURE_LIGHT
		GameTypes.TerrainType.FIELDS: return FIELD_LIGHT
		GameTypes.TerrainType.MOUNTAINS: return MOUNTAIN_LIGHT
		GameTypes.TerrainType.BARREN: return BARREN_LIGHT
		_: return BARREN_LIGHT


static func resource(r: int) -> Color:
	match r:
		GameTypes.ResourceType.TIMBER: return RES_TIMBER
		GameTypes.ResourceType.CLAY: return RES_CLAY
		GameTypes.ResourceType.FLEECE: return RES_FLEECE
		GameTypes.ResourceType.GRAIN: return RES_GRAIN
		GameTypes.ResourceType.IRON: return RES_IRON
		_: return PAPER
