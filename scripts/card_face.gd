class_name CardFace
extends Control

signal pressed()
signal badge_pressed()
signal right_pressed()

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
var emblem_only := false:
	set(v):
		if emblem_only == v:
			return
		emblem_only = v
		queue_redraw()
var show_name := true:
	set(v):
		if show_name == v:
			return
		show_name = v
		_mark_dirty()
var vivid := false:
	set(v):
		if vivid == v:
			return
		vivid = v
		_mark_dirty()
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

func badge_bounds() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var cr := _card_rect()
	if count > 0 and count_badge:
		var rr2 := maxf(9.0, size.x * 0.18)
		var c2 := Vector2(cr.end.x - rr2 - 2.0, cr.position.y + rr2 + 2.0)
		var r2 := rr2 + 1.5
		out.append(Rect2(c2 - Vector2(r2, r2), Vector2(r2 * 2.0, r2 * 2.0)))
	if badge > 0:
		var bc := badge_center_local()
		var rr := _badge_rect().size.x * 0.5 + 1.5
		out.append(Rect2(bc - Vector2(rr, rr), Vector2(rr * 2.0, rr * 2.0)))
	return out

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
	if (count_badge and count > 0) or badge > 0:
		lt += 5.0
	var h := size.y - lt - 3.0
	if pile_count >= 0:
		h = minf(h, (size.x - 6.0) / RATIO)
	return Rect2(Vector2(3.0, lt - lift), Vector2(size.x - 6.0, h))

func _draw() -> void:
	if size.x <= 2.0 or size.y <= 2.0:
		return
	if emblem_only:
		var kind_s := "action" if kind == "action" else "resource"
		var id_v: int = action if kind_s == "action" else resource
		draw_emblem(self, kind_s, id_v, Rect2(Vector2.ZERO, size).grow(-1.0), 1.0)
		return
	var dim := disabled or ((not vivid) and count <= 0 and kind != "back")
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
	var font := ThemeDB.fallback_font
	var want_name := show_name and size.x >= 34.0
	var emblem_rect := Rect2(inner.position + inner.size * Vector2(0.11, 0.10), inner.size * Vector2(0.78, 0.55))
	if not want_name:
		emblem_rect = Rect2(inner.position + inner.size * Vector2(0.09, 0.18), inner.size * Vector2(0.82, 0.64))
	if kind == "resource" and resource >= 0:
		draw_emblem(self, "resource", resource, emblem_rect, a)
		if want_name:
			_draw_name(font, cr, GameTypes.resource_name(resource).to_upper(), Color(Palette.INK, a))
	elif kind == "action":
		draw_emblem(self, "action", action, emblem_rect, a)
		if want_name:
			_draw_name(font, cr, CardFace.action_name(action).to_upper(), Color(Palette.INK, a))
	elif want_name:
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
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed and not disabled:
				right_pressed.emit()
				accept_event()
			return
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
	var k := 1.0
	if kind_str == "resource":
		match id:
			GameTypes.ResourceType.TIMBER:
				k = 1.32
			GameTypes.ResourceType.CLAY:
				k = 1.3
			GameTypes.ResourceType.GRAIN:
				k = 1.15
			GameTypes.ResourceType.IRON:
				k = 1.12
	if not is_equal_approx(k, 1.0):
		ci.draw_set_transform(rect.get_center() * (1.0 - k), 0.0, Vector2(k, k))
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

	if not is_equal_approx(k, 1.0):
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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

static func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, segs: int, col: Color, outline: Color, ow: float) -> void:
	var pts := PackedVector2Array()
	for k in range(segs):
		var a := TAU * float(k) / float(segs)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_poly(ci, pts, col, outline, ow)

static func _emblem_timber(ci: CanvasItem, rect: Rect2) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var ink := Color(0.24, 0.17, 0.12)
	var bark := Color(0.50, 0.37, 0.25)
	var bark_hi := Color(0.64, 0.50, 0.35)
	var cut := Color(0.88, 0.78, 0.59)
	var ring := Color(0.60, 0.46, 0.30)
	var grass := Color(0.42, 0.55, 0.28)
	# meadow strip under the stack
	_ell(ci, Vector2(rect.get_center().x + w * 0.02, rect.end.y - h * 0.055), w * 0.42, h * 0.05, 14, grass, ink.darkened(0.1), 1.0)
	var lr := h * 0.13
	var lw := w * 0.62
	var tops := [rect.end.y - h * 0.15 - lr, rect.end.y - h * 0.15 - lr * 3.0, rect.end.y - h * 0.15 - lr * 4.9]
	var xs := [0.03, -0.04, 0.02]
	for i in range(3):
		var lc: Vector2 = Vector2(rect.get_center().x + w * float(xs[i]), tops[i])
		# right end cap, then the body band, so the caps read round
		_circle(ci, lc + Vector2(lw * 0.5 - lr, 0), lr, bark.darkened(0.14), ink, 1.2)
		var band := Rect2(lc + Vector2(-lw * 0.5 + lr, -lr), Vector2(lw - lr * 2.0, lr * 2.0))
		ci.draw_rect(band, _c(bark))
		_line(ci, band.position + Vector2(0, -0.6), band.end + Vector2(0, -0.6), bark_hi, maxf(1.0, lr * 0.34))
		_line(ci, Vector2(band.position.x, band.end.y + 0.6), Vector2(band.end.x, band.end.y + 0.6), ink, 1.1)
		# cut face with growth rings
		var fc: Vector2 = lc + Vector2(-lw * 0.5 + lr, 0)
		_circle(ci, fc, lr, bark, ink, 1.3)
		_circle(ci, fc, lr * 0.72, cut, ring, 0.9)
		if w >= 24.0:
			ci.draw_arc(fc, lr * 0.46, TAU * 0.1, TAU * 0.9, 12, ring, 0.8, true)
			ci.draw_arc(fc, lr * 0.23, TAU * 0.15, TAU * 0.85, 10, ring, 0.8, true)
		if w >= 30.0:
			_line(ci, lc + Vector2(-lw * 0.06, lr * 0.3), lc + Vector2(lw * 0.2, lr * 0.3), bark.darkened(0.22), 0.8)
	# grass tufts and a leafy sprig
	for g in [-0.30, 0.34]:
		var gx: float = rect.get_center().x + w * float(g)
		var gy: float = rect.end.y - h * 0.09
		_line(ci, Vector2(gx, gy), Vector2(gx - w * 0.035, gy - h * 0.08), grass.darkened(0.15), 1.2)
		_line(ci, Vector2(gx + w * 0.02, gy), Vector2(gx + w * 0.045, gy - h * 0.07), grass.darkened(0.15), 1.2)
	if w >= 30.0:
		var sc := Vector2(rect.get_center().x + w * 0.30, rect.end.y - h * 0.12)
		_line(ci, sc, sc + Vector2(w * 0.015, -h * 0.15), Color(0.32, 0.45, 0.2), 1.2)
		_ell(ci, sc + Vector2(-w * 0.03, -h * 0.09), w * 0.05, h * 0.026, 8, grass.lightened(0.12), Color(0.24, 0.32, 0.15), 0.8)
		_ell(ci, sc + Vector2(w * 0.035, -h * 0.13), w * 0.05, h * 0.026, 8, grass.lightened(0.12), Color(0.24, 0.32, 0.15), 0.8)

static func _emblem_clay(ci: CanvasItem, rect: Rect2) -> void:
	var base := Palette.RES_CLAY
	var dark := base.darkened(0.35)
	var bw := rect.size.x * 0.24
	var bh := rect.size.y * 0.26
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
	var w := rect.size.x
	var h := rect.size.y
	var ink := Color(0.24, 0.17, 0.12)
	var cream := Color(0.91, 0.85, 0.67)
	var cream_lo := Color(0.72, 0.65, 0.47)
	var shade := Color(0.55, 0.62, 0.70)
	var face := Color(0.31, 0.23, 0.17)
	var leg := Color(0.27, 0.20, 0.15)
	var grass := Color(0.42, 0.55, 0.28)
	# meadow strip
	_ell(ci, Vector2(rect.get_center().x, rect.end.y - h * 0.045), w * 0.44, h * 0.05, 14, grass, ink.darkened(0.1), 1.0)
	if w >= 30.0:
		for g in [-0.30, 0.34]:
			var gx: float = rect.get_center().x + w * float(g)
			var gy: float = rect.end.y - h * 0.08
			_line(ci, Vector2(gx, gy), Vector2(gx - w * 0.03, gy - h * 0.06), grass.darkened(0.15), 1.0)
			_line(ci, Vector2(gx + w * 0.02, gy), Vector2(gx + w * 0.04, gy - h * 0.055), grass.darkened(0.15), 1.0)
	var c := rect.get_center() + Vector2(w * 0.05, -h * 0.03)
	var r := minf(w, h) * 0.31
	var foot_y := rect.end.y - h * 0.085
	# four short legs in two pairs
	_line(ci, c + Vector2(-r * 0.42, r * 0.5), Vector2(c.x - r * 0.42, foot_y), leg.darkened(0.12), maxf(1.3, r * 0.14))
	_line(ci, c + Vector2(-r * 0.18, r * 0.55), Vector2(c.x - r * 0.18, foot_y), leg, maxf(1.3, r * 0.15))
	_line(ci, c + Vector2(r * 0.34, r * 0.52), Vector2(c.x + r * 0.34, foot_y), leg.darkened(0.12), maxf(1.3, r * 0.14))
	_line(ci, c + Vector2(r * 0.58, r * 0.47), Vector2(c.x + r * 0.58, foot_y), leg, maxf(1.3, r * 0.15))
	# tiny tail bump
	if w >= 28.0:
		_circle(ci, c + Vector2(r * 1.02, -r * 0.15), r * 0.22, cream_lo, cream_lo, 0.0)
	# soft blue-grey underside under the wool
	_ell(ci, c + Vector2(0, r * 0.6), r * 0.72, r * 0.4, 12, shade, shade.darkened(0.2), 0.7)
	# fluffy cloud outline: six fill-only bumps behind the body
	for k in range(7):
		var a := -PI * (0.95 - 0.30 * float(k))
		var bp := c + Vector2(cos(a), sin(a)) * r * 0.95
		_circle(ci, bp, r * 0.52, cream_lo, cream_lo, 0.0)
	_circle(ci, c, r * 0.94, cream, ink, 1.4)
	# head facing left: dark brown face, ear, single eye dot
	var hc := c + Vector2(-r * 1.3, r * 0.04)
	if w >= 22.0:
		_ell(ci, hc + Vector2(r * 0.18, -r * 0.22), r * 0.19, r * 0.09, 8, face.darkened(0.25), ink, 0.7)
	_ell(ci, hc, r * 0.3, r * 0.42, 12, face, ink, 1.1)
	_circle(ci, hc + Vector2(-r * 0.08, -r * 0.06), maxf(0.9, r * 0.08), Color(0.96, 0.93, 0.86), Color(0.96, 0.93, 0.86), 0.0)
	if w >= 28.0:
		# small tuft of wool on the forehead
		_circle(ci, hc + Vector2(r * 0.02, -r * 0.5), r * 0.16, cream, ink, 0.8)

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
	var w := rect.size.x
	var h := rect.size.y
	var ink := Color(0.24, 0.17, 0.12)
	var base := Color(0.42, 0.48, 0.58)
	var lite := Color(0.60, 0.66, 0.74)
	var shad := Color(0.30, 0.35, 0.44)
	var rust := Color(0.68, 0.40, 0.20)
	var c := rect.get_center() + Vector2(-w * 0.03, h * 0.06)
	if w >= 30.0:
		# miner's pick behind the boulder, steel head bound at the shaft top
		var shaft_a := c + Vector2(-w * 0.40, h * 0.40)
		var shaft_b := c + Vector2(w * 0.26, -h * 0.26)
		_line(ci, shaft_a, shaft_b, Color(0.42, 0.30, 0.18), maxf(1.6, w * 0.06))
		_line(ci, shaft_a, shaft_b, Color(0.58, 0.44, 0.28), maxf(0.8, w * 0.026))
		ci.draw_arc(shaft_b + Vector2(0, w * 0.06), w * 0.16, -PI * 1.05, -PI * 0.45, 14, ink, maxf(1.6, w * 0.06), true)
		ci.draw_arc(shaft_b + Vector2(0, w * 0.06), w * 0.16, -PI * 1.05, -PI * 0.45, 14, lite, maxf(0.8, w * 0.03), true)
	# irregular slate boulder
	var body := PackedVector2Array([
		c + Vector2(-w * 0.38, h * 0.20),
		c + Vector2(-w * 0.44, -h * 0.02),
		c + Vector2(-w * 0.26, -h * 0.28),
		c + Vector2(0.0, -h * 0.36),
		c + Vector2(w * 0.26, -h * 0.24),
		c + Vector2(w * 0.42, h * 0.02),
		c + Vector2(w * 0.30, h * 0.28),
		c + Vector2(-w * 0.12, h * 0.32),
	])
	_poly(ci, body, base, ink, 1.5)
	_poly(ci, PackedVector2Array([
		c + Vector2(-w * 0.42, -h * 0.02),
		c + Vector2(-w * 0.24, -h * 0.26),
		c + Vector2(0.0, -h * 0.34),
		c + Vector2(-w * 0.06, -h * 0.06),
		c + Vector2(-w * 0.30, h * 0.06),
	]), lite, lite.darkened(0.25), 0.8)
	_poly(ci, PackedVector2Array([
		c + Vector2(w * 0.40, h * 0.04),
		c + Vector2(w * 0.28, h * 0.26),
		c + Vector2(-w * 0.10, h * 0.30),
		c + Vector2(-w * 0.02, h * 0.10),
		c + Vector2(w * 0.22, h * 0.0),
	]), shad, shad, 0.0)
	# rust veins
	var vein_w := maxf(1.0, w * 0.035)
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(-w * 0.30, h * 0.06), c + Vector2(-w * 0.10, -h * 0.02),
		c + Vector2(w * 0.06, h * 0.06), c + Vector2(w * 0.22, -h * 0.02),
	]), rust, vein_w, true)
	ci.draw_polyline(PackedVector2Array([
		c + Vector2(-w * 0.14, h * 0.22), c + Vector2(w * 0.0, h * 0.14),
		c + Vector2(w * 0.16, h * 0.18),
	]), rust.darkened(0.12), vein_w * 0.8, true)
	if w >= 40.0:
		ci.draw_polyline(PackedVector2Array([
			c + Vector2(-w * 0.30, -h * 0.16), c + Vector2(-w * 0.20, -h * 0.10),
		]), rust, vein_w * 0.7, true)
	# glint on the lit facet
	_line(ci, c + Vector2(-w * 0.30, -h * 0.24), c + Vector2(-w * 0.16, -h * 0.26), Color(0.95, 0.96, 0.92, 0.9), maxf(0.8, w * 0.02))

static func _emblem_guard(ci: CanvasItem, rect: Rect2) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var ink := Color(0.24, 0.17, 0.12)
	var teal := Color(0.24, 0.48, 0.47)
	var teal_lit := Color(0.40, 0.62, 0.60)
	var teal_dk := Color(0.16, 0.36, 0.36)
	var cream := Color(0.93, 0.88, 0.74)
	var steel := Color(0.70, 0.73, 0.78)
	var cx := rect.get_center().x
	var sw := w * 0.78
	var sh := minf(h * 0.94, sw / 0.8)
	var top := rect.get_center().y - sh * 0.5 - h * 0.01
	# wooden spear shaft crossing behind, bottom-left to top-right
	var tip_a := Vector2(cx - sw * 0.58, rect.end.y - h * 0.03)
	var big := w >= 26.0
	var tip_b := Vector2(cx + sw * 0.44, top - sh * 0.05)
	if big:
		_line(ci, tip_a, tip_b, Color(0.42, 0.30, 0.18), maxf(1.6, w * 0.05))
		_line(ci, tip_a, tip_b, Color(0.58, 0.44, 0.28), maxf(0.8, w * 0.02))
		# steel leaf-shaped tip above the shield's top-right corner
		var dirv := (tip_b - tip_a).normalized()
		var perp := Vector2(-dirv.y, dirv.x)
		var apex := tip_b + dirv * sh * 0.15
		_poly(ci, PackedVector2Array([
			tip_b - perp * w * 0.05,
			apex - perp * w * 0.018,
			apex + perp * w * 0.018,
			tip_b + perp * w * 0.05,
		]), steel, ink, 1.1)
	# soft cast shadow
	_ell(ci, Vector2(cx + w * 0.05, rect.end.y - h * 0.035), sw * 0.46, h * 0.04, 12, Color(0.15, 0.12, 0.1, 0.22), Color(0.15, 0.12, 0.1, 0.22), 0.0)
	# broad heater shield: flat top, rounded upper corners, point at the bottom
	var pts := PackedVector2Array([
		Vector2(cx - sw * 0.5, top + sh * 0.07),
		Vector2(cx - sw * 0.46, top + sh * 0.015),
		Vector2(cx - sw * 0.38, top),
		Vector2(cx + sw * 0.38, top),
		Vector2(cx + sw * 0.46, top + sh * 0.015),
		Vector2(cx + sw * 0.5, top + sh * 0.07),
		Vector2(cx + sw * 0.47, top + sh * 0.36),
		Vector2(cx + sw * 0.34, top + sh * 0.64),
		Vector2(cx + sw * 0.16, top + sh * 0.86),
		Vector2(cx, top + sh),
		Vector2(cx - sw * 0.16, top + sh * 0.86),
		Vector2(cx - sw * 0.34, top + sh * 0.64),
		Vector2(cx - sw * 0.47, top + sh * 0.36),
	])
	_poly(ci, pts, teal, ink, 1.6)
	# lighter highlight band down the left third
	_poly(ci, PackedVector2Array([
		Vector2(cx - sw * 0.44, top + sh * 0.06),
		Vector2(cx - sw * 0.17, top + sh * 0.06),
		Vector2(cx - sw * 0.17, top + sh * 0.64),
		Vector2(cx - sw * 0.30, top + sh * 0.66),
		Vector2(cx - sw * 0.44, top + sh * 0.40),
	]), teal_lit, teal_lit, 0.0)
	# darker right edge
	_poly(ci, PackedVector2Array([
		Vector2(cx + sw * 0.24, top + sh * 0.06),
		Vector2(cx + sw * 0.46, top + sh * 0.06),
		Vector2(cx + sw * 0.44, top + sh * 0.38),
		Vector2(cx + sw * 0.30, top + sh * 0.66),
		Vector2(cx + sw * 0.24, top + sh * 0.52),
	]), teal_dk, teal_dk, 0.0)
	# thin cream border inset along the shield shape
	var pc := Vector2(cx, top + sh * 0.42)
	var ip := PackedVector2Array()
	for p in pts:
		ip.append(pc + (p - pc) * 0.84)
	ip.append(ip[0])
	ci.draw_polyline(ip, cream, maxf(0.9, w * 0.018), true)
	# cream sun crest in the centre
	var cc := Vector2(cx, top + sh * 0.44)
	_circle(ci, cc, w * 0.1, cream, ink, 1.0)
	if w >= 30.0:
		for k in range(8):
			var a2 := TAU * float(k) / 8.0 + 0.2
			_line(ci, cc + Vector2(cos(a2), sin(a2)) * w * 0.13, cc + Vector2(cos(a2), sin(a2)) * w * 0.17, cream, 1.2)

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
