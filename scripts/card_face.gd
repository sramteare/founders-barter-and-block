class_name CardFace
extends Control

signal pressed()
signal badge_pressed()

const RATIO := 5.0 / 7.0
const BADGE_COLOR := Color(0.68, 0.23, 0.16)
const PILE_RESERVE := 48.0

var kind := "resource":
	set(v):
		if kind == v:
			return
		kind = v
		_mark_dirty()
var resource := -1:
	set(v):
		if resource == v:
			return
		resource = v
		_mark_dirty()
var action := -1:
	set(v):
		if action == v:
			return
		action = v
		_mark_dirty()
var count := 0:
	set(v):
		if count == v:
			return
		count = v
		_mark_dirty()
var badge := 0:
	set(v):
		if badge == v:
			return
		badge = v
		_mark_dirty()
var selected := false:
	set(v):
		if selected == v:
			return
		selected = v
		_mark_dirty()
var disabled := false:
	set(v):
		if disabled == v:
			return
		disabled = v
		_mark_dirty()
var hidden_card := false:
	set(v):
		if hidden_card == v:
			return
		hidden_card = v
		_mark_dirty()
var stack_depth := 0:
	set(v):
		if stack_depth == v:
			return
		stack_depth = v
		_mark_dirty()
var focusable := true
var count_badge := true
var pile_low_tint := false:
	set(v):
		if pile_low_tint == v:
			return
		pile_low_tint = v
		_mark_dirty()
var redraw_requests := 0
var pile_count := -1:
	set(v):
		if pile_count == v:
			return
		pile_count = v
		if pile_count >= 0:
			var w := maxf(custom_minimum_size.x, 1.0)
			custom_minimum_size = Vector2(w, w / RATIO + PILE_RESERVE)
		_mark_dirty()

func _mark_dirty() -> void:
	redraw_requests += 1
	queue_redraw()

var _hover := false
var _press_inside := false
static var _ea := 1.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	if custom_minimum_size.x <= 0.0:
		custom_minimum_size = Vector2(64, 64.0 / RATIO)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw()
	)

func badge_center_local() -> Vector2:
	var s := size.x
	var r := s * 0.17
	return Vector2(size.x - r - 4.0, size.y - r - 4.0)

func _badge_rect() -> Rect2:
	var r := size.x * 0.17
	var c := badge_center_local()
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)

func _card_rect() -> Rect2:
	var lift := 6.0 if selected else (3.0 if _hover else 0.0)
	var lt := 3.0 + float(stack_depth) * 1.8
	var h := size.y - lt - 3.0
	if pile_count >= 0:
		h = minf(h, (size.x - 6.0) / RATIO)
	return Rect2(Vector2(3.0, lt - lift), Vector2(size.x - 6.0, h))

func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	var dim := disabled or (count <= 0 and kind != "back")
	var a := 0.55 if dim else 1.0
	var cr := _card_rect()
	if pile_count == 0:
		_draw_pile_slot(cr)
		return
	if selected:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		glow.set_corner_radius_all(10)
		glow.set_border_width_all(3)
		glow.border_color = Color(Palette.ACCENT_GOLD, 0.75)
		draw_style_box(glow, cr.grow(3.0))
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0.15, 0.11, 0.07, 0.20)
	sh.set_corner_radius_all(7)
	draw_style_box(sh, Rect2(cr.position + Vector2(1.6, 2.4), cr.size))
	for i in range(stack_depth, 0, -1):
		var lr := Rect2(cr.position - Vector2(i * 1.8, i * 1.8), cr.size)
		var ls := StyleBoxFlat.new()
		ls.bg_color = Palette.PAPER.darkened(0.10 + float(i) * 0.04)
		ls.border_color = Palette.INK_SOFT
		ls.set_border_width_all(1)
		ls.set_corner_radius_all(6)
		draw_style_box(ls, lr)
	if hidden_card or kind == "back":
		_draw_back(cr)
		_draw_pile_edges(cr)
		_draw_badges(cr)
		return
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.97, 0.94, 0.86, a)
	face.border_color = Palette.INK
	face.set_border_width_all(2)
	face.set_corner_radius_all(7)
	draw_style_box(face, cr)
	var frame_col := Palette.TEXT_MUTED
	if kind == "resource" and resource >= 0:
		frame_col = Palette.resource(resource)
	elif kind == "action":
		frame_col = Palette.ACCENT_GOLD.darkened(0.2)
	var inner := cr.grow(-4.0)
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	fs.border_color = Color(frame_col, 0.7)
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(4)
	draw_style_box(fs, inner)
	var emblem_rect := Rect2(inner.position + inner.size * Vector2(0.16, 0.10), inner.size * Vector2(0.68, 0.55))
	var font := ThemeDB.fallback_font
	if kind == "resource" and resource >= 0:
		draw_emblem(self, "resource", resource, emblem_rect, a)
		_draw_name(font, cr, GameTypes.resource_name(resource).to_upper(), Color(Palette.INK, a))
	elif kind == "action":
		draw_emblem(self, "action", action, emblem_rect, a)
		_draw_name(font, cr, CardFace.action_name(action).to_upper(), Color(Palette.INK, a))
	else:
		_draw_name(font, cr, "CARD", Color(Palette.INK, a))
	_draw_pile_edges(cr)
	_draw_badges(cr)


func _draw_pile_edges(cr: Rect2) -> void:
	if pile_count <= 1:
		return
	var edge_col := Palette.ACCENT_RED.darkened(0.08) if pile_low_tint else Palette.INK_SOFT
	var paper := Color(0.93, 0.90, 0.82, 0.95)
	var last_i := pile_count - 1
	for i in range(1, pile_count):
		var y0 := cr.end.y + float(i - 1) * 2.0
		if i == last_i:
			var sb := StyleBoxFlat.new()
			sb.bg_color = paper
			sb.border_color = edge_col
			sb.set_border_width_all(1)
			sb.border_width_top = 0
			sb.corner_radius_bottom_left = 5
			sb.corner_radius_bottom_right = 5
			draw_style_box(sb, Rect2(Vector2(cr.position.x, y0 - 3.0), Vector2(cr.size.x, 5.0)))
		else:
			draw_rect(Rect2(Vector2(cr.position.x, y0), Vector2(cr.size.x, 2.0)), paper)
			var ly := y0 + 1.5
			draw_line(Vector2(cr.position.x, ly), Vector2(cr.end.x, ly), edge_col, 1.0)


func _draw_pile_slot(cr: Rect2) -> void:
	var col := Color(Palette.ACCENT_RED, 0.8) if pile_low_tint else Color(Palette.INK_SOFT, 0.55)
	var dash := 4.0
	var gap := 6.0
	var x := cr.position.x
	while x < cr.end.x - dash:
		draw_line(Vector2(x, cr.position.y), Vector2(minf(x + dash, cr.end.x), cr.position.y), col, 1.0)
		draw_line(Vector2(x, cr.end.y), Vector2(minf(x + dash, cr.end.x), cr.end.y), col, 1.0)
		x += gap
	var y := cr.position.y
	while y < cr.end.y - dash:
		draw_line(Vector2(cr.position.x, y), Vector2(cr.position.x, minf(y + dash, cr.end.y)), col, 1.0)
		draw_line(Vector2(cr.end.x, y), Vector2(cr.end.x, minf(y + dash, cr.end.y)), col, 1.0)
		y += gap

func _draw_back(cr: Rect2) -> void:
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.36, 0.47, 0.55)
	face.border_color = Palette.INK
	face.set_border_width_all(2)
	face.set_corner_radius_all(7)
	draw_style_box(face, cr)
	var inner := cr.grow(-4.0)
	var cols := 4
	var rows := 6
	for r in range(rows + 1):
		var pts := PackedVector2Array()
		var y0 := inner.position.y + inner.size.y * float(r) / float(rows)
		pts.append(Vector2(inner.position.x, y0))
		pts.append(Vector2(inner.end.x, y0))
		draw_polyline(pts, Color(0.93, 0.90, 0.80, 0.22), 1.0, true)
	for c in range(cols + 1):
		var pts2 := PackedVector2Array()
		var x0 := inner.position.x + inner.size.x * float(c) / float(cols)
		pts2.append(Vector2(x0, inner.position.y))
		pts2.append(Vector2(x0, inner.end.y))
		draw_polyline(pts2, Color(0.93, 0.90, 0.80, 0.22), 1.0, true)
	var cc := inner.get_center()
	var rad := minf(inner.size.x, inner.size.y) * 0.34
	draw_circle(cc, rad, Color(0.97, 0.94, 0.86))
	draw_arc(cc, rad, 0.0, TAU, 24, Palette.ACCENT_GOLD.darkened(0.1), 2.0, true)
	var font := ThemeDB.fallback_font
	var fs := maxi(8, int(rad * 1.2))
	var ts := font.get_string_size("F", HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, Vector2(snappedf(cc.x - ts.x * 0.5, 1.0), snappedf(cc.y + ts.y * 0.32, 1.0)), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.ACCENT_GOLD.darkened(0.35))
	# the count badge still renders on top of a back (deck stacks)

func _draw_badges(cr: Rect2) -> void:
	var font := ThemeDB.fallback_font
	if count > 0 and count_badge:
		var rr2 := maxf(9.0, size.x * 0.18)
		var bx := cr.end.x - rr2 - 2.0
		var by := cr.position.y + rr2 + 2.0
		var col := Color(0.91, 0.70, 0.28)
		draw_circle(Vector2(bx, by), rr2, col)
		draw_arc(Vector2(bx, by), rr2, 0.0, TAU, 20, Palette.INK, 1.5, true)
		var txt2 := "x%d" % count
		var fs2 := maxi(10, int(rr2))
		var ts2 := font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_CENTER, -1, fs2)
		draw_string(font, Vector2(snappedf(bx - ts2.x * 0.5, 1.0), snappedf(by + ts2.y * 0.32, 1.0)), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Palette.INK)
	if badge > 0:
		var br := _badge_rect()
		var bc := br.get_center()
		var rr := br.size.x * 0.5
		draw_circle(bc, rr, BADGE_COLOR)
		draw_arc(bc, rr, 0.0, TAU, 20, Palette.INK, 1.5, true)
		var txt := "−%d" % badge
		var fs := maxi(9, int(rr * 1.05))
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2(snappedf(bc.x - ts.x * 0.5, 1.0), snappedf(bc.y + ts.y * 0.32, 1.0)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.93, 0.88))

func _draw_name(font: Font, cr: Rect2, text: String, col: Color) -> void:
	var fs := clampi(int(cr.size.x * 0.16), 9, 10)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var x := snappedf(cr.get_center().x - ts.x * 0.5, 1.0)
	var y := snappedf(cr.end.y - 6.0, 1.0)
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE) and not disabled:
			pressed.emit()
			accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_inside = Rect2(Vector2.ZERO, size).has_point(mb.position)
		elif _press_inside:
			_press_inside = false
			if disabled:
				return
			if badge > 0 and _badge_rect().grow(3.0).has_point(mb.position):
				badge_pressed.emit()
			else:
				pressed.emit()
			accept_event()

static func action_name(id: int) -> String:
	match id:
		GameTypes.DevCardType.GUARD:
			return "Guard"
		GameTypes.DevCardType.ROAD_WORK:
			return "Road Work"
		GameTypes.DevCardType.HARVEST_BOUNTY:
			return "Bounty"
		GameTypes.DevCardType.TRADE_DECREE:
			return "Decree"
		GameTypes.DevCardType.CHARTER_POINT:
			return "Charter"
	return "Card"

static func draw_emblem(ci: CanvasItem, kind_str: String, id: int, rect: Rect2, alpha: float = 1.0) -> void:
	_ea = alpha
	match kind_str:
		"resource":
			match id:
				GameTypes.ResourceType.TIMBER:
					_emblem_timber(ci, rect)
				GameTypes.ResourceType.CLAY:
					_emblem_clay(ci, rect)
				GameTypes.ResourceType.FLEECE:
					_emblem_fleece(ci, rect)
				GameTypes.ResourceType.GRAIN:
					_emblem_grain(ci, rect)
				GameTypes.ResourceType.IRON:
					_emblem_iron(ci, rect)
		"action":
			match id:
				GameTypes.DevCardType.GUARD:
					_emblem_guard(ci, rect)
				GameTypes.DevCardType.ROAD_WORK:
					_emblem_roadwork(ci, rect)
				GameTypes.DevCardType.HARVEST_BOUNTY:
					_emblem_bounty(ci, rect)
				GameTypes.DevCardType.TRADE_DECREE:
					_emblem_decree(ci, rect)
				GameTypes.DevCardType.CHARTER_POINT:
					_emblem_charter(ci, rect)
		"mixed":
			_emblem_mixed(ci, rect)

	_ea = 1.0

static func _c(col: Color) -> Color:
	return col * Color(1, 1, 1, _ea)

static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, outline: Color, ow: float) -> void:
	ci.draw_colored_polygon(pts, _c(col), PackedVector2Array(), null)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, outline, ow, true)

static func _circle(ci: CanvasItem, c: Vector2, r: float, col: Color, outline: Color, ow: float) -> void:
	ci.draw_circle(c, r, _c(col))
	ci.draw_arc(c, r, 0.0, TAU, 24, outline, ow, true)

static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, true)

static func _emblem_timber(ci: CanvasItem, rect: Rect2) -> void:
	var base := Palette.RES_TIMBER
	var dark := base.darkened(0.35)
	var w := rect.size.x
	var h := rect.size.y
	var log_h := h * 0.30
	for i in range(2):
		var y := rect.position.y + h * (0.14 + float(i) * 0.42)
		var lb := Rect2(rect.position.x + w * 0.06, y, w * 0.88, log_h)
		ci.draw_rect(lb, _c(base))
		ci.draw_rect(lb, dark, false, 1.5)
		var ec := Vector2(lb.position.x, lb.get_center().y)
		_circle(ci, ec, log_h * 0.5, base.lightened(0.35), dark, 1.5)
		ci.draw_arc(ec, log_h * 0.22, 0.0, TAU, 16, dark, 1.0, true)

static func _emblem_clay(ci: CanvasItem, rect: Rect2) -> void:
	var base := Palette.RES_CLAY
	var dark := base.darkened(0.35)
	var bw := rect.size.x * 0.40
	var bh := rect.size.y * 0.22
	var rows := [
		[0.0, 1.0, 2.0],
		[0.5, 1.5],
		[1.0],
	]
	for r in range(rows.size()):
		for slot in rows[r]:
			var bpos := Vector2(rect.position.x + rect.size.x * 0.5 - bw * 1.5 + slot * bw, rect.end.y - bh * float(r + 1) - rect.size.y * 0.04 * float(r))
			var br := Rect2(bpos, Vector2(bw - 2.0, bh))
			ci.draw_rect(br, _c(base.lightened(0.08 * float(r))))
			ci.draw_rect(br, dark, false, 1.5)

static func _emblem_fleece(ci: CanvasItem, rect: Rect2) -> void:
	var base := Palette.RES_FLEECE
	var dark := Color(0.30, 0.24, 0.20)
	var c := rect.get_center() + Vector2(0, rect.size.y * 0.05)
	var r := minf(rect.size.x, rect.size.y) * 0.30
	for k in range(6):
		var a := TAU * float(k) / 6.0
		_circle(ci, c + Vector2(cos(a), sin(a)) * r * 0.85, r * 0.42, base.lightened(0.10), dark.darkened(0.2), 1.0)
	_circle(ci, c, r, base.lightened(0.18), dark, 1.5)
	var fc := c + Vector2(0, -r * 0.75)
	_circle(ci, fc, r * 0.42, dark, dark, 1.0)
	_line(ci, fc + Vector2(-r * 0.5, -r * 0.15), fc + Vector2(-r * 0.78, -r * 0.38), dark, 2.0)
	_line(ci, fc + Vector2(r * 0.5, -r * 0.15), fc + Vector2(r * 0.78, -r * 0.38), dark, 2.0)
	_line(ci, c + Vector2(-r * 0.35, r * 0.9), c + Vector2(-r * 0.35, r * 1.35), dark, 2.0)
	_line(ci, c + Vector2(r * 0.35, r * 0.9), c + Vector2(r * 0.35, r * 1.35), dark, 2.0)

static func _emblem_grain(ci: CanvasItem, rect: Rect2) -> void:
	var base := Palette.RES_GRAIN
	var dark := base.darkened(0.4)
	var cx := rect.get_center().x
	var top := rect.position.y + rect.size.y * 0.08
	var bottom := rect.end.y - rect.size.y * 0.06
	for s in range(-1, 2):
		var lean := float(s) * rect.size.x * 0.16
		var stem_top := Vector2(cx + lean * 0.9, top + absf(float(s)) * rect.size.y * 0.08)
		var stem_bot := Vector2(cx + lean * 0.25, bottom)
		_line(ci, stem_bot, stem_top, dark, 2.0)
		for k in range(4):
			var t := float(k) / 4.0
			var p := stem_top.lerp(stem_bot, t * 0.55)
			_line(ci, p, p + Vector2(-rect.size.x * 0.10, -rect.size.y * 0.10), base, 2.5)
			_line(ci, p, p + Vector2(rect.size.x * 0.10, -rect.size.y * 0.10), base, 2.5)
	var tie := (rect.position + Vector2(cx - rect.size.x * 0.3, bottom - rect.size.y * 0.12))
	_line(ci, Vector2(cx - rect.size.x * 0.28, bottom - rect.size.y * 0.10), Vector2(cx + rect.size.x * 0.28, bottom - rect.size.y * 0.16), Color(0.55, 0.42, 0.25), 2.5)

static func _emblem_iron(ci: CanvasItem, rect: Rect2) -> void:
	var base := Palette.RES_IRON
	var dark := base.darkened(0.4)
	var cx := rect.get_center().x
	var w := rect.size.x
	var y0 := rect.position.y + rect.size.y * 0.22
	var body := PackedVector2Array([
		Vector2(cx - w * 0.42, y0 + rect.size.y * 0.16),
		Vector2(cx - w * 0.20, y0),
		Vector2(cx + w * 0.30, y0),
		Vector2(cx + w * 0.45, y0 + rect.size.y * 0.10),
		Vector2(cx + w * 0.30, y0 + rect.size.y * 0.20),
		Vector2(cx - w * 0.26, y0 + rect.size.y * 0.20),
	])
	_poly(ci, body, base, dark, 1.5)
	var post := Rect2(Vector2(cx - w * 0.12, y0 + rect.size.y * 0.20), Vector2(w * 0.24, rect.size.y * 0.30))
	ci.draw_rect(post, _c(base.darkened(0.12)))
	ci.draw_rect(post, dark, false, 1.5)
	var foot := Rect2(Vector2(cx - w * 0.30, y0 + rect.size.y * 0.50), Vector2(w * 0.60, rect.size.y * 0.14))
	ci.draw_rect(foot, _c(base.darkened(0.2)))
	ci.draw_rect(foot, dark, false, 1.5)

static func _emblem_guard(ci: CanvasItem, rect: Rect2) -> void:
	var steel := Palette.SEA_DEEP
	var dark := Palette.INK
	var cx := rect.get_center().x
	var top := rect.position.y + rect.size.y * 0.10
	var w := rect.size.x * 0.62
	var shield := PackedVector2Array([
		Vector2(cx - w * 0.5, top),
		Vector2(cx + w * 0.5, top),
		Vector2(cx + w * 0.5, top + rect.size.y * 0.38),
		Vector2(cx, top + rect.size.y * 0.78),
		Vector2(cx - w * 0.5, top + rect.size.y * 0.38),
	])
	_poly(ci, shield, steel.lightened(0.15), dark, 1.5)
	_line(ci, Vector2(cx + w * 0.55, top + rect.size.y * 0.75), Vector2(cx + w * 0.25, top - rect.size.y * 0.04), Color(0.55, 0.42, 0.25), 2.5)
	var tip := Vector2(cx + w * 0.25, top - rect.size.y * 0.04)
	_poly(ci, PackedVector2Array([tip, tip + Vector2(-4, 8), tip + Vector2(4, 8)]), Palette.MOUNTAIN_LIGHT.darkened(0.1), dark, 1.0)

static func _emblem_roadwork(ci: CanvasItem, rect: Rect2) -> void:
	var dirt := Palette.CLAY_SHADE
	var dark := Palette.INK
	_line(ci, rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.85), rect.position + Vector2(rect.size.x * 0.55, rect.size.y * 0.35), dirt, 8.0)
	_line(ci, rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.85), rect.position + Vector2(rect.size.x * 0.55, rect.size.y * 0.35), Palette.PAPER, 1.5)
	_line(ci, rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.95), rect.position + Vector2(rect.size.x * 0.95, rect.size.y * 0.55), dirt.darkened(0.1), 8.0)
	_line(ci, rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.95), rect.position + Vector2(rect.size.x * 0.95, rect.size.y * 0.55), Palette.PAPER, 1.5)
	_line(ci, rect.position + Vector2(rect.size.x * 0.55, rect.size.y * 0.35), rect.position + Vector2(rect.size.x * 0.60, rect.size.y * 0.20), dark, 2.0)

static func _emblem_bounty(ci: CanvasItem, rect: Rect2) -> void:
	var wicker := Color(0.72, 0.52, 0.30)
	var dark := Palette.INK
	var cx := rect.get_center().x
	var top := rect.position.y + rect.size.y * 0.30
	var basket := PackedVector2Array([
		Vector2(cx - rect.size.x * 0.34, top),
		Vector2(cx + rect.size.x * 0.34, top),
		Vector2(cx + rect.size.x * 0.22, rect.end.y - rect.size.y * 0.06),
		Vector2(cx - rect.size.x * 0.22, rect.end.y - rect.size.y * 0.06),
	])
	_poly(ci, basket, wicker, dark, 1.5)
	_line(ci, Vector2(cx - rect.size.x * 0.30, top + rect.size.y * 0.16), Vector2(cx + rect.size.x * 0.30, top + rect.size.y * 0.16), dark.darkened(0.2), 1.0)
	for k in range(3):
		var gc := Vector2(cx + (float(k) - 1.0) * rect.size.x * 0.20, top - rect.size.y * 0.10)
		_circle(ci, gc, rect.size.x * 0.09, [Palette.RES_GRAIN, Palette.RES_FLEECE, Palette.RES_TIMBER][k], dark, 1.0)

static func _emblem_decree(ci: CanvasItem, rect: Rect2) -> void:
	var parchment := Palette.PAPER
	var dark := Palette.INK
	var r := Rect2(rect.position + rect.size * Vector2(0.16, 0.16), rect.size * Vector2(0.68, 0.62))
	ci.draw_rect(r, _c(parchment))
	ci.draw_rect(r, dark, false, 1.5)
	for k in range(3):
		var y := r.position.y + r.size.y * (0.25 + 0.25 * float(k))
		_line(ci, Vector2(r.position.x + r.size.x * 0.15, y), Vector2(r.end.x - r.size.x * 0.15, y), Palette.TEXT_MUTED, 1.5)
	_circle(ci, Vector2(r.get_center().x + r.size.x * 0.18, r.end.y + rect.size.y * 0.02), rect.size.x * 0.11, Color(0.65, 0.22, 0.18), dark, 1.0)

static func _emblem_charter(ci: CanvasItem, rect: Rect2) -> void:
	var gold := Palette.ACCENT_GOLD.darkened(0.1)
	var dark := Palette.INK
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.34
	ci.draw_arc(c + Vector2(-r * 0.35, 0), r, -TAU * 0.28, TAU * 0.42, 16, gold, 2.0, true)
	ci.draw_arc(c + Vector2(r * 0.35, 0), r, TAU * 0.58, TAU * 1.28, 16, gold, 2.0, true)
	var star := PackedVector2Array()
	for k in range(10):
		var ang := -PI * 0.5 + TAU * float(k) / 10.0
		var rr := r * 0.55 if k % 2 == 0 else r * 0.24
		star.append(c + Vector2(cos(ang), sin(ang)) * rr)
	_poly(ci, star, Palette.ACCENT_GOLD, dark, 1.2)

static func _emblem_mixed(ci: CanvasItem, rect: Rect2) -> void:
	var dark := Palette.INK
	var c := rect.get_center()
	var r := minf(rect.size.x, rect.size.y) * 0.42
	var cols := [Palette.RES_TIMBER, Palette.RES_CLAY, Palette.RES_FLEECE, Palette.RES_GRAIN]
	for k in range(4):
		var a := TAU * float(k) / 4.0 + PI * 0.25
		_circle(ci, c + Vector2(cos(a), sin(a)) * r * 0.62, r * 0.30, cols[k], dark.darkened(0.1), 1.0)
	ci.draw_string(ThemeDB.fallback_font, Vector2(snappedf(c.x - r * 0.28, 1.0), snappedf(c.y + r * 0.30, 1.0)), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(r * 0.8)), Palette.INK)
