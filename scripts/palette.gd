class_name Palette
extends RefCounted

# Backdrop / sea
static var SKY_TOP: Color = Color(0.80, 0.90, 0.92)
static var SEA: Color = Color(0.52, 0.75, 0.80)
static var SEA_DEEP: Color = Color(0.38, 0.63, 0.72)
static var SEA_FOAM: Color = Color(0.93, 0.97, 0.95, 0.85)
static var CLOUD: Color = Color(1.0, 0.99, 0.95, 0.55)

# Ink & paper
static var INK: Color = Color(0.29, 0.22, 0.169)
static var INK_SOFT: Color = Color(0.29, 0.22, 0.168, 0.45)
static var PAPER: Color = Color(0.97, 0.93, 0.831)
static var PAPER_DARK: Color = Color(0.91, 0.85, 0.72)
static var PAPER_SHADOW: Color = Color(0.25, 0.18, 0.12, 0.22)

# Terrain base / shade / light
static var FOREST: Color = Color(0.36, 0.55, 0.36)
static var FOREST_SHADE: Color = Color(0.27, 0.44, 0.29)
static var FOREST_LIGHT: Color = Color(0.48, 0.66, 0.45)

static var PASTURE: Color = Color(0.66, 0.80, 0.47)
static var PASTURE_SHADE: Color = Color(0.54, 0.70, 0.38)
static var PASTURE_LIGHT: Color = Color(0.78, 0.88, 0.60)

static var FIELD: Color = Color(0.94, 0.81, 0.45)
static var FIELD_SHADE: Color = Color(0.83, 0.68, 0.35)
static var FIELD_LIGHT: Color = Color(0.98, 0.90, 0.63)

static var CLAY: Color = Color(0.82, 0.53, 0.39)
static var CLAY_SHADE: Color = Color(0.70, 0.42, 0.30)
static var CLAY_LIGHT: Color = Color(0.90, 0.66, 0.52)

static var MOUNTAIN: Color = Color(0.58, 0.62, 0.69)
static var MOUNTAIN_SHADE: Color = Color(0.46, 0.50, 0.58)
static var MOUNTAIN_LIGHT: Color = Color(0.70, 0.74, 0.80)

static var BARREN: Color = Color(0.89, 0.81, 0.64)
static var BARREN_SHADE: Color = Color(0.79, 0.70, 0.53)
static var BARREN_LIGHT: Color = Color(0.95, 0.90, 0.76)

# Resources
static var RES_TIMBER: Color = Color(0.45, 0.58, 0.32)
static var RES_CLAY: Color = Color(0.80, 0.48, 0.35)
static var RES_FLEECE: Color = Color(0.95, 0.91, 0.82)
static var RES_GRAIN: Color = Color(0.93, 0.75, 0.35)
static var RES_IRON: Color = Color(0.55, 0.60, 0.66)

# UI
static var PANEL_BG: Color = Color(0.97, 0.93, 0.832)
static var PANEL_BG_ALT: Color = Color(0.94, 0.89, 0.77)
static var PANEL_BORDER: Color = Color(0.55, 0.42, 0.30)
static var TEXT: Color = Color(0.29, 0.221, 0.17)
static var TEXT_MUTED: Color = Color(0.45, 0.38, 0.30)
static var TEXT_ON_DARK: Color = Color(0.97, 0.93, 0.833)
static var HEADING: Color = Color(0.20, 0.42, 0.401)
static var ACCENT_GOLD: Color = Color(0.90, 0.68, 0.26)
static var ACCENT_RED: Color = Color(0.80, 0.37, 0.311)
static var ACCENT_GREEN: Color = Color(0.42, 0.66, 0.40)
static var BUTTON_BG: Color = Color(0.90, 0.83, 0.68)
static var BUTTON_BG_HOVER: Color = Color(0.94, 0.88, 0.74)
static var BUTTON_BG_PRESSED: Color = Color(0.83, 0.75, 0.60)
static var BUTTON_BG_DISABLED: Color = Color(0.84, 0.81, 0.74)
static var BUTTON_TEXT: Color = Color(0.29, 0.219, 0.17)
static var TOAST_BG: Color = Color(0.20, 0.42, 0.40, 0.92)
static var TOAST_TEXT: Color = Color(0.97, 0.93, 0.83)
static var HIGHLIGHT: Color = Color(0.98, 0.84, 0.45, 0.55)
static var HIGHLIGHT_INVALID: Color = Color(0.80, 0.37, 0.309, 0.55)

# Named chrome and accent shades used by the UI (paper value = today's look)
static var ACCENT_GOLD_BORDER: Color = Color(0.7650, 0.5780, 0.2210)
static var ACCENT_GOLD_BORDER_SOFT: Color = Color(0.8100, 0.6120, 0.2340)
static var STATUS_GOOD_TEXT: Color = Color(0.3150, 0.4950, 0.3000)
static var STATUS_BAD_TEXT: Color = Color(0.7200, 0.3330, 0.2799)
static var STATUS_WARN_TEXT: Color = Color(0.7650, 0.5780, 0.2200)
static var STATUS_GOLD_SOFT_TEXT: Color = Color(0.7200, 0.5440, 0.2070)
static var STATUS_GOLD_STRONG_TEXT: Color = Color(0.6300, 0.4760, 0.1820)
static var TOAST_TRADE_BG: Color = Color(0.1900, 0.3990, 0.3800)
static var TOAST_COUNTER_BG: Color = Color(0.7200, 0.5440, 0.2080)
static var TOAST_WARN_BG: Color = Color(0.6750, 0.5100, 0.1950)
static var BUTTON_PRIMARY_HOVER: Color = Color(0.9080, 0.7056, 0.3192)
static var BUTTON_PRIMARY_PRESSED: Color = Color(0.8280, 0.6256, 0.2392)
static var BUTTON_DANGER_HOVER: Color = Color(0.8140, 0.4141, 0.3592)
static var BUTTON_DANGER_PRESSED: Color = Color(0.7360, 0.3404, 0.2861)
static var BUTTON_GREEN_HOVER: Color = Color(0.4606, 0.6838, 0.4420)
static var BUTTON_GREEN_PRESSED: Color = Color(0.3906, 0.6138, 0.3720)
static var BUTTON_BORDER_PRESSED: Color = Color(0.4950, 0.3780, 0.2700)
static var SECTION_TAG_TEXT: Color = Color(0.1700, 0.3570, 0.3408)
static var BUTTON_TEXT_ON_GOLD: Color = Color(0.2910, 0.2190, 0.1700)
static var BUTTON_TEXT_ON_RED: Color = Color(0.9700, 0.9300, 0.8340)
static var BUTTON_TEXT_ON_GREEN: Color = Color(0.9700, 0.9305, 0.8330)
static var SCRIM: Color = Color(0.2900, 0.2200, 0.1670)
static var SPLASH_SCRIM: Color = Color(0.1200, 0.0900, 0.0600)
static var TOAST_STEAL_BAD: Color = Color(0.5500, 0.1800, 0.1400)
static var TOAST_STEAL_GOOD: Color = Color(0.1800, 0.4200, 0.2000)
static var TOAST_NEUTRAL: Color = Color(0.4500, 0.3500, 0.2000)
static var BLOCKER_GHOST_BG: Color = Color(0.1500, 0.1200, 0.1000)
static var BADGE_TEXT: Color = Color(0.1300, 0.1100, 0.0900)
static var ROAD_ICON_FILL: Color = Color(0.5800, 0.4400, 0.3000)
static var INK_OUTLINE: Color = Color(0.2910, 0.2200, 0.1690)
static var OPTION_HOVER_TEXT: Color = Color(0.2900, 0.2205, 0.1690)
static var TEXT_CARET: Color = Color(0.2900, 0.2200, 0.1705)
static var TOAST_PILL_BG: Color = Color(0.9404, 0.8904, 0.7704)
static var CHIP_PILL_BG: Color = Color(0.9704, 0.9304, 0.8314)
static var DICE_PILL_BG: Color = Color(0.9104, 0.8504, 0.7204)
static var CHECK_UNCHECKED_BG: Color = Color(0.9700, 0.9304, 0.8314)
static var CHECK_BORDER: Color = Color(0.5504, 0.4204, 0.3004)
static var HELP_HEADING: Color = Color(0.1216, 0.3529, 0.3216)
static var LOG_ERROR_TEXT: Color = Color(0.4784, 0.1647, 0.1255)
static var AWARD_HIGHLIGHT_BG: Color = Color(0.9600, 0.8980, 0.7060)

# Tokens
static var NUMBER_TOKEN_BG: Color = Color(0.96, 0.92, 0.82)
static var NUMBER_TOKEN_TEXT: Color = Color(0.29, 0.218, 0.17)
static var NUMBER_TOKEN_HOT: Color = Color(0.80, 0.37, 0.31)
static var BLOCKER: Color = Color(0.32, 0.27, 0.23)
static var DOCK_WOOD: Color = Color(0.60, 0.45, 0.30)
static var DICE_FACE: Color = Color(0.97, 0.94, 0.86)
static var DICE_PIP: Color = Color(0.29, 0.22, 0.17)

# Colour styles: a new style is one more entry in STYLES plus its id and label.
const STYLE_IDS: Array[String] = ["paper", "dark"]
const STYLE_OPTIONS := {"paper": {"custom_check_icons": false, "toast_text_min_contrast": 0.0, "icon": "sun"}, "dark": {"custom_check_icons": true, "toast_text_min_contrast": 4.5, "icon": "moon"}}
const STYLE_LABELS := {"paper": "Paper", "dark": "Dark"}

const STYLES := {
	"paper": {
		"SKY_TOP": Color(0.80, 0.90, 0.92),
		"SEA": Color(0.52, 0.75, 0.80),
		"SEA_DEEP": Color(0.38, 0.63, 0.72),
		"SEA_FOAM": Color(0.93, 0.97, 0.95, 0.85),
		"CLOUD": Color(1.0, 0.99, 0.95, 0.55),
		"INK": Color(0.29, 0.22, 0.169),
		"INK_SOFT": Color(0.29, 0.22, 0.168, 0.45),
		"PAPER": Color(0.97, 0.93, 0.831),
		"PAPER_DARK": Color(0.91, 0.85, 0.72),
		"PAPER_SHADOW": Color(0.25, 0.18, 0.12, 0.22),
		"FOREST": Color(0.36, 0.55, 0.36),
		"FOREST_SHADE": Color(0.27, 0.44, 0.29),
		"FOREST_LIGHT": Color(0.48, 0.66, 0.45),
		"PASTURE": Color(0.66, 0.80, 0.47),
		"PASTURE_SHADE": Color(0.54, 0.70, 0.38),
		"PASTURE_LIGHT": Color(0.78, 0.88, 0.60),
		"FIELD": Color(0.94, 0.81, 0.45),
		"FIELD_SHADE": Color(0.83, 0.68, 0.35),
		"FIELD_LIGHT": Color(0.98, 0.90, 0.63),
		"CLAY": Color(0.82, 0.53, 0.39),
		"CLAY_SHADE": Color(0.70, 0.42, 0.30),
		"CLAY_LIGHT": Color(0.90, 0.66, 0.52),
		"MOUNTAIN": Color(0.58, 0.62, 0.69),
		"MOUNTAIN_SHADE": Color(0.46, 0.50, 0.58),
		"MOUNTAIN_LIGHT": Color(0.70, 0.74, 0.80),
		"BARREN": Color(0.89, 0.81, 0.64),
		"BARREN_SHADE": Color(0.79, 0.70, 0.53),
		"BARREN_LIGHT": Color(0.95, 0.90, 0.76),
		"RES_TIMBER": Color(0.45, 0.58, 0.32),
		"RES_CLAY": Color(0.80, 0.48, 0.35),
		"RES_FLEECE": Color(0.95, 0.91, 0.82),
		"RES_GRAIN": Color(0.93, 0.75, 0.35),
		"RES_IRON": Color(0.55, 0.60, 0.66),
		"PANEL_BG": Color(0.97, 0.93, 0.832),
		"PANEL_BG_ALT": Color(0.94, 0.89, 0.77),
		"PANEL_BORDER": Color(0.55, 0.42, 0.30),
		"TEXT": Color(0.29, 0.221, 0.17),
		"TEXT_MUTED": Color(0.45, 0.38, 0.30),
		"TEXT_ON_DARK": Color(0.97, 0.93, 0.833),
		"HEADING": Color(0.20, 0.42, 0.401),
		"ACCENT_GOLD": Color(0.90, 0.68, 0.26),
		"ACCENT_RED": Color(0.80, 0.37, 0.311),
		"ACCENT_GREEN": Color(0.42, 0.66, 0.40),
		"BUTTON_BG": Color(0.90, 0.83, 0.68),
		"BUTTON_BG_HOVER": Color(0.94, 0.88, 0.74),
		"BUTTON_BG_PRESSED": Color(0.83, 0.75, 0.60),
		"BUTTON_BG_DISABLED": Color(0.84, 0.81, 0.74),
		"BUTTON_TEXT": Color(0.29, 0.219, 0.17),
		"TOAST_BG": Color(0.20, 0.42, 0.40, 0.92),
		"TOAST_TEXT": Color(0.97, 0.93, 0.83),
		"HIGHLIGHT": Color(0.98, 0.84, 0.45, 0.55),
		"HIGHLIGHT_INVALID": Color(0.80, 0.37, 0.309, 0.55),
		"ACCENT_GOLD_BORDER": Color(0.7650, 0.5780, 0.2210),
		"ACCENT_GOLD_BORDER_SOFT": Color(0.8100, 0.6120, 0.2340),
		"STATUS_GOOD_TEXT": Color(0.3150, 0.4950, 0.3000),
		"STATUS_BAD_TEXT": Color(0.7200, 0.3330, 0.2799),
		"STATUS_WARN_TEXT": Color(0.7650, 0.5780, 0.2200),
		"STATUS_GOLD_SOFT_TEXT": Color(0.7200, 0.5440, 0.2070),
		"STATUS_GOLD_STRONG_TEXT": Color(0.6300, 0.4760, 0.1820),
		"TOAST_TRADE_BG": Color(0.1900, 0.3990, 0.3800),
		"TOAST_COUNTER_BG": Color(0.7200, 0.5440, 0.2080),
		"TOAST_WARN_BG": Color(0.6750, 0.5100, 0.1950),
		"BUTTON_PRIMARY_HOVER": Color(0.9080, 0.7056, 0.3192),
		"BUTTON_PRIMARY_PRESSED": Color(0.8280, 0.6256, 0.2392),
		"BUTTON_DANGER_HOVER": Color(0.8140, 0.4141, 0.3592),
		"BUTTON_DANGER_PRESSED": Color(0.7360, 0.3404, 0.2861),
		"BUTTON_GREEN_HOVER": Color(0.4606, 0.6838, 0.4420),
		"BUTTON_GREEN_PRESSED": Color(0.3906, 0.6138, 0.3720),
		"BUTTON_BORDER_PRESSED": Color(0.4950, 0.3780, 0.2700),
		"SECTION_TAG_TEXT": Color(0.1700, 0.3570, 0.3408),
		"BUTTON_TEXT_ON_GOLD": Color(0.2910, 0.2190, 0.1700),
		"BUTTON_TEXT_ON_RED": Color(0.9700, 0.9300, 0.8340),
		"BUTTON_TEXT_ON_GREEN": Color(0.9700, 0.9305, 0.8330),
		"SCRIM": Color(0.2900, 0.2200, 0.1670),
		"SPLASH_SCRIM": Color(0.1200, 0.0900, 0.0600),
		"TOAST_STEAL_BAD": Color(0.5500, 0.1800, 0.1400),
		"TOAST_STEAL_GOOD": Color(0.1800, 0.4200, 0.2000),
		"TOAST_NEUTRAL": Color(0.4500, 0.3500, 0.2000),
		"BLOCKER_GHOST_BG": Color(0.1500, 0.1200, 0.1000),
		"BADGE_TEXT": Color(0.1300, 0.1100, 0.0900),
		"ROAD_ICON_FILL": Color(0.5800, 0.4400, 0.3000),
		"INK_OUTLINE": Color(0.2910, 0.2200, 0.1690),
		"OPTION_HOVER_TEXT": Color(0.2900, 0.2205, 0.1690),
		"TEXT_CARET": Color(0.2900, 0.2200, 0.1705),
		"TOAST_PILL_BG": Color(0.9404, 0.8904, 0.7704),
		"CHIP_PILL_BG": Color(0.9704, 0.9304, 0.8314),
		"DICE_PILL_BG": Color(0.9104, 0.8504, 0.7204),
		"CHECK_UNCHECKED_BG": Color(0.9700, 0.9304, 0.8314),
		"CHECK_BORDER": Color(0.5504, 0.4204, 0.3004),
		"HELP_HEADING": Color(0.1216, 0.3529, 0.3216),
		"LOG_ERROR_TEXT": Color(0.4784, 0.1647, 0.1255),
		"AWARD_HIGHLIGHT_BG": Color(0.9600, 0.8980, 0.7060),
		"NUMBER_TOKEN_BG": Color(0.96, 0.92, 0.82),
		"NUMBER_TOKEN_TEXT": Color(0.29, 0.218, 0.17),
		"NUMBER_TOKEN_HOT": Color(0.80, 0.37, 0.31),
		"BLOCKER": Color(0.32, 0.27, 0.23),
		"DOCK_WOOD": Color(0.60, 0.45, 0.30),
		"DICE_FACE": Color(0.97, 0.94, 0.86),
		"DICE_PIP": Color(0.29, 0.22, 0.17),
	},
	"dark": {
		"SKY_TOP": Color(0.10, 0.14, 0.20),
		"SEA": Color(0.13, 0.24, 0.32),
		"SEA_DEEP": Color(0.09, 0.18, 0.26),
		"SEA_FOAM": Color(0.70, 0.82, 0.86, 0.45),
		"CLOUD": Color(0.75, 0.80, 0.90, 0.18),
		"INK": Color(0.12, 0.10, 0.091),
		"INK_SOFT": Color(0.12, 0.10, 0.09, 0.45),
		"PAPER": Color(0.17, 0.18, 0.21),
		"PAPER_DARK": Color(0.23, 0.24, 0.28),
		"PAPER_SHADOW": Color(0.0, 0.0, 0.001, 0.40),
		"FOREST": Color(0.27, 0.41, 0.27),
		"FOREST_SHADE": Color(0.20, 0.33, 0.21),
		"FOREST_LIGHT": Color(0.36, 0.49, 0.33),
		"PASTURE": Color(0.49, 0.59, 0.35),
		"PASTURE_SHADE": Color(0.40, 0.52, 0.28),
		"PASTURE_LIGHT": Color(0.58, 0.65, 0.44),
		"FIELD": Color(0.70, 0.60, 0.33),
		"FIELD_SHADE": Color(0.61, 0.50, 0.26),
		"FIELD_LIGHT": Color(0.73, 0.67, 0.47),
		"CLAY": Color(0.61, 0.39, 0.29),
		"CLAY_SHADE": Color(0.52, 0.31, 0.22),
		"CLAY_LIGHT": Color(0.67, 0.49, 0.38),
		"MOUNTAIN": Color(0.43, 0.46, 0.51),
		"MOUNTAIN_SHADE": Color(0.34, 0.37, 0.43),
		"MOUNTAIN_LIGHT": Color(0.52, 0.55, 0.59),
		"BARREN": Color(0.66, 0.60, 0.47),
		"BARREN_SHADE": Color(0.58, 0.52, 0.39),
		"BARREN_LIGHT": Color(0.70, 0.67, 0.56),
		"RES_TIMBER": Color(0.45, 0.58, 0.32),
		"RES_CLAY": Color(0.80, 0.48, 0.35),
		"RES_FLEECE": Color(0.88, 0.85, 0.77),
		"RES_GRAIN": Color(0.93, 0.75, 0.35),
		"RES_IRON": Color(0.55, 0.60, 0.66),
		"PANEL_BG": Color(0.15, 0.16, 0.19),
		"PANEL_BG_ALT": Color(0.19, 0.20, 0.24),
		"PANEL_BORDER": Color(0.42, 0.44, 0.52),
		"TEXT": Color(0.90, 0.89, 0.85),
		"TEXT_MUTED": Color(0.66, 0.66, 0.67),
		"TEXT_ON_DARK": Color(0.95, 0.93, 0.859),
		"HEADING": Color(0.45, 0.78, 0.74),
		"ACCENT_GOLD": Color(0.92, 0.72, 0.32),
		"ACCENT_RED": Color(0.90, 0.48, 0.42),
		"ACCENT_GREEN": Color(0.50, 0.76, 0.48),
		"BUTTON_BG": Color(0.25, 0.27, 0.32),
		"BUTTON_BG_HOVER": Color(0.31, 0.33, 0.39),
		"BUTTON_BG_PRESSED": Color(0.20, 0.21, 0.26),
		"BUTTON_BG_DISABLED": Color(0.19, 0.20, 0.23),
		"BUTTON_TEXT": Color(0.92, 0.91, 0.87),
		"TOAST_BG": Color(0.1000, 0.2600, 0.2600, 0.95),
		"TOAST_TEXT": Color(0.95, 0.93, 0.86),
		"HIGHLIGHT": Color(0.98, 0.84, 0.45, 0.55),
		"HIGHLIGHT_INVALID": Color(0.80, 0.37, 0.31, 0.55),
		"ACCENT_GOLD_BORDER": Color(0.9190, 0.7200, 0.3200),
		"ACCENT_GOLD_BORDER_SOFT": Color(0.7500, 0.5800, 0.2600),
		"STATUS_GOOD_TEXT": Color(0.6200, 0.8600, 0.5800),
		"STATUS_BAD_TEXT": Color(0.9600, 0.6200, 0.5700),
		"STATUS_WARN_TEXT": Color(0.9400, 0.7800, 0.4200),
		"STATUS_GOLD_SOFT_TEXT": Color(0.9500, 0.8000, 0.4600),
		"STATUS_GOLD_STRONG_TEXT": Color(0.9250, 0.7450, 0.3650),
		"TOAST_TRADE_BG": Color(0.0850, 0.2250, 0.2250),
		"TOAST_COUNTER_BG": Color(0.3000, 0.2200, 0.0900),
		"TOAST_WARN_BG": Color(0.2600, 0.1900, 0.0600),
		"BUTTON_PRIMARY_HOVER": Color(0.9600, 0.7900, 0.4200),
		"BUTTON_PRIMARY_PRESSED": Color(0.7800, 0.5800, 0.2200),
		"BUTTON_DANGER_HOVER": Color(0.9500, 0.5800, 0.5200),
		"BUTTON_DANGER_PRESSED": Color(0.8000, 0.4000, 0.3500),
		"BUTTON_GREEN_HOVER": Color(0.5800, 0.8200, 0.5600),
		"BUTTON_GREEN_PRESSED": Color(0.4200, 0.6600, 0.4000),
		"BUTTON_BORDER_PRESSED": Color(0.3000, 0.3200, 0.4000),
		"SECTION_TAG_TEXT": Color(0.5500, 0.8300, 0.8000),
		"BUTTON_TEXT_ON_GOLD": Color(0.1500, 0.1100, 0.0800),
		"BUTTON_TEXT_ON_RED": Color(0.0900, 0.0500, 0.0500),
		"BUTTON_TEXT_ON_GREEN": Color(0.1000, 0.1400, 0.1000),
		"SCRIM": Color(0.0500, 0.0600, 0.0800),
		"SPLASH_SCRIM": Color(0.0300, 0.0300, 0.0500),
		"TOAST_STEAL_BAD": Color(0.3400, 0.1300, 0.1100),
		"TOAST_STEAL_GOOD": Color(0.1100, 0.2600, 0.1400),
		"TOAST_NEUTRAL": Color(0.2500, 0.1900, 0.1000),
		"BLOCKER_GHOST_BG": Color(0.0600, 0.0500, 0.0400),
		"BADGE_TEXT": Color(0.1300, 0.1100, 0.0900),
		"ROAD_ICON_FILL": Color(0.7000, 0.5500, 0.3800),
		"INK_OUTLINE": Color(0.8500, 0.8400, 0.8000),
		"OPTION_HOVER_TEXT": Color(0.9300, 0.9200, 0.8800),
		"TEXT_CARET": Color(0.9000, 0.8900, 0.8550),
		"TOAST_PILL_BG": Color(0.8450, 0.8150, 0.7350),
		"CHIP_PILL_BG": Color(0.7800, 0.7400, 0.6400),
		"DICE_PILL_BG": Color(0.8000, 0.7700, 0.6800),
		"CHECK_UNCHECKED_BG": Color(0.2600, 0.2750, 0.3400),
		"CHECK_BORDER": Color(0.6200, 0.6400, 0.7200),
		"HELP_HEADING": Color(0.5216, 0.8196, 0.7804),
		"LOG_ERROR_TEXT": Color(0.9098, 0.5216, 0.4706),
		"AWARD_HIGHLIGHT_BG": Color(0.3200, 0.2800, 0.1600),
		"NUMBER_TOKEN_BG": Color(0.86, 0.82, 0.72),
		"NUMBER_TOKEN_TEXT": Color(0.16, 0.12, 0.101),
		"NUMBER_TOKEN_HOT": Color(0.72, 0.22, 0.16),
		"BLOCKER": Color(0.32, 0.27, 0.23),
		"DOCK_WOOD": Color(0.48, 0.36, 0.24),
		"DICE_FACE": Color(0.90, 0.87, 0.80),
		"DICE_PIP": Color(0.16, 0.12, 0.10),
	},
}

static var current_style: String = "paper"


static func apply_style(id: String) -> void:
	if not STYLES.has(id):
		id = "paper"
	var base: Dictionary = STYLES["paper"]
	var style: Dictionary = STYLES[id]
	var self_script: GDScript = load("res://scripts/palette.gd")
	for key in base:
		var value: Color = style[key] if style.has(key) else base[key]
		self_script.set(key, value)
	current_style = id


static func style_label(id: String) -> String:
	if STYLE_LABELS.has(id):
		return String(STYLE_LABELS[id])
	return id.capitalize()


static func style_option(name: String, fallback: Variant = null) -> Variant:
	var style: Dictionary = STYLE_OPTIONS[current_style] if STYLE_OPTIONS.has(current_style) else STYLE_OPTIONS["paper"]
	if style.has(name):
		return style[name]
	return fallback


static func next_style(id: String) -> String:
	var index := STYLE_IDS.find(id)
	if index < 0:
		return STYLE_IDS[0]
	return STYLE_IDS[(index + 1) % STYLE_IDS.size()]


static func rgb_key(c: Color) -> String:
	return "%.4f|%.4f|%.4f" % [c.r, c.g, c.b]


static func remap_table(from_id: String, to_id: String) -> Dictionary:
	var base: Dictionary = STYLES["paper"]
	var source: Dictionary = STYLES[from_id] if STYLES.has(from_id) else base
	var target: Dictionary = STYLES[to_id] if STYLES.has(to_id) else base
	var table := {}
	for key in base:
		var old_color: Color = source[key] if source.has(key) else base[key]
		var new_color: Color = target[key] if target.has(key) else base[key]
		var rgb := rgb_key(old_color)
		var pairs: Array = table.get(rgb, [])
		pairs.append([old_color.a, new_color])
		table[rgb] = pairs
	return table


static func remap(c: Color, table: Dictionary) -> Color:
	if not table.has(rgb_key(c)):
		return c
	var pairs: Array = table[rgb_key(c)]
	for pair in pairs:
		if absf(float(pair[0]) - c.a) <= 0.005:
			return pair[1]
	var first: Color = pairs[0][1]
	return Color(first.r, first.g, first.b, c.a)


static func restyle_tree(root: Node, table: Dictionary) -> void:
	_restyle_node(root, table, {})


static func _restyle_node(node: Node, table: Dictionary, visited: Dictionary) -> void:
	if node is Control or node is Window:
		_restyle_theme_overrides(node, table, visited)
	if node is ColorRect:
		(node as ColorRect).color = Palette.remap((node as ColorRect).color, table)
	elif node is Line2D:
		(node as Line2D).default_color = Palette.remap((node as Line2D).default_color, table)
	elif node is Polygon2D:
		(node as Polygon2D).color = Palette.remap((node as Polygon2D).color, table)
	if node is CanvasItem:
		var item := node as CanvasItem
		item.modulate = Palette.remap(item.modulate, table)
		item.self_modulate = Palette.remap(item.self_modulate, table)
		item.queue_redraw()
	var node_script: GDScript = node.get_script() as GDScript
	if node_script != null:
		for prop in node_script.get_script_property_list():
			if int(prop["type"]) != TYPE_COLOR:
				continue
			var pname := String(prop["name"])
			var stored: Variant = node.get(pname)
			if stored is Color:
				node.set(pname, Palette.remap(stored, table))
	for child in node.get_children(true):
		_restyle_node(child, table, visited)


static func _restyle_theme_overrides(node: Node, table: Dictionary, visited: Dictionary) -> void:
	for prop in node.get_property_list():
		var pname := String(prop["name"])
		if pname.begins_with("theme_override_colors/"):
			var value: Variant = node.get(pname)
			if value is Color:
				node.set(pname, Palette.remap(value, table))
		elif pname.begins_with("theme_override_styles/"):
			var style: Variant = node.get(pname)
			if style is StyleBoxFlat:
				_restyle_style_box(style as StyleBoxFlat, table, visited)


static func _restyle_style_box(box: StyleBoxFlat, table: Dictionary, visited: Dictionary) -> void:
	var id := box.get_instance_id()
	if visited.has(id):
		return
	visited[id] = true
	box.bg_color = Palette.remap(box.bg_color, table)
	box.border_color = Palette.remap(box.border_color, table)
	box.shadow_color = Palette.remap(box.shadow_color, table)


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
