class_name BoardView
extends Control

signal vertex_clicked(vertex_id: int)
signal edge_clicked(edge_id: int)
signal tile_clicked(tile_id: int)
signal build_spot_clicked(kind: String, id: int)
signal background_clicked()

enum InteractionMode {
	NONE = 0,
	PICK_SETTLEMENT = 1,
	PICK_ROAD = 2,
	PICK_CITY = 3,
	PICK_BLOCKER_TILE = 4,
	BUILD_ANY = 5,
}

const TOAST_ACCENT: Color = Palette.ACCENT_GOLD
const _AMBIENT_INTERVAL: float = 1.0 / 12.0

var state: GameState = null
var interaction_mode: int = InteractionMode.NONE
var highlighted_vertices: Array[int] = []
var highlighted_edges: Array[int] = []
var highlighted_tiles: Array[int] = []
var highlighted_city_vertices: Array[int] = []
var reduce_motion: bool = false

var _pulse_time: float = 0.0
var _ambient_time: float = 0.0
var _ambient_accum: float = 0.0
var _hovered_vertex: int = -1
var _hovered_edge: int = -1
var _hovered_tile: int = -1
var _hovered_city_vertex: int = -1

var _popups: Array = []
var _build_anims: Array = []
var anim_scale: float = 1.0
var anim_count: int = 0
var _blocker_from_tile: int = -1
var _blocker_t: float = 1.0
var _toasts: Array = []
var _pending_kind: String = ""
var _pending_id: int = -1
var _harbour_label_rects: Array[Rect2] = []
var _port_badge_rects: Array[Rect2] = []
var _port_badge_data: Array[Dictionary] = []
var _land_polys_screen: Array[PackedVector2Array] = []
var _hovered_port: int = -1
var show_port_names: bool = false
var _harbour_boat_rects: Array[Rect2] = []
var _port_specs: Array[Dictionary] = []

const _CLOUD_DEFS: Array[Vector4] = [
	Vector4(0.08, 0.10, 1.0, 9.0),
	Vector4(0.42, 0.18, 1.25, 6.5),
	Vector4(0.70, 0.06, 0.9, 12.0),
	Vector4(0.28, 0.90, 1.1, 7.5),
	Vector4(0.86, 0.82, 1.2, 5.0),
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(520, 480)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	set_process(true)

func _process(delta: float) -> void:
	var needs_redraw := false
	var classic_highlight := (
		interaction_mode != InteractionMode.NONE
		and interaction_mode != InteractionMode.BUILD_ANY
		and (not highlighted_vertices.is_empty() or not highlighted_edges.is_empty() or not highlighted_tiles.is_empty())
	)
	if classic_highlight:
		_pulse_time += delta * 4.0
		needs_redraw = true
	if not reduce_motion:
		_ambient_time += delta
		_ambient_accum += delta
		if _ambient_accum >= _AMBIENT_INTERVAL:
			_ambient_accum = 0.0
			needs_redraw = true
	if not _popups.is_empty():
		for i in range(_popups.size() - 1, -1, -1):
			var popup: Dictionary = _popups[i]
			popup["age"] = float(popup["age"]) + delta
			if float(popup["age"]) >= float(popup["duration"]):
				_popups.remove_at(i)
		needs_redraw = not _popups.is_empty() or needs_redraw
	if not _toasts.is_empty():
		for i in range(_toasts.size() - 1, -1, -1):
			var toast: Dictionary = _toasts[i]
			toast["age"] = float(toast["age"]) + delta
			if float(toast["age"]) >= float(toast["duration"]):
				_toasts.remove_at(i)
		needs_redraw = not _toasts.is_empty() or needs_redraw
	if not _build_anims.is_empty():
		for i in range(_build_anims.size() - 1, -1, -1):
			var a: Dictionary = _build_anims[i]
			a["age"] = float(a["age"]) + delta
			if float(a["age"]) >= float(a["duration"]):
				_build_anims.remove_at(i)
		needs_redraw = true
	if _blocker_t < 1.0:
		_blocker_t = minf(1.0, _blocker_t + delta / maxf(0.05, 0.9 * anim_scale))
		needs_redraw = true
	if needs_redraw:
		queue_redraw()

func spawn_tile_resource_popup(tile_id: int, res: int, amount: int) -> void:
	if state == null:
		return
	var topo := HexMath.get_topology()
	if tile_id < 0 or tile_id >= topo.tile_centers.size():
		return
	var hex_radius := _get_hex_radius()
	var dx := float((tile_id * 53 + 17) % 25 - 12)
	var stack := -8.0 * float(mini(_popups.size(), 3))
	var screen_pos := _unit_to_screen(topo.tile_centers[tile_id], hex_radius) + Vector2(dx, -hex_radius * 0.55 + stack)
	_popups.append({
		"pos": screen_pos,
		"text": "+%d %s" % [amount, GameTypes.resource_name(res)],
		"color": _resource_color(res),
		"age": 0.0,
		"duration": 1.35,
	})
	queue_redraw()

func spawn_trade_toast(text: String, accent_color: Color = TOAST_ACCENT) -> void:
	_toasts.append({
		"text": text,
		"color": accent_color,
		"age": 0.0,
		"duration": 2.0,
	})
	queue_redraw()

func set_state(new_state: GameState) -> void:
	state = new_state
	queue_redraw()

func set_highlights(
	mode: int,
	verts: Array[int] = [],
	edges: Array[int] = [],
	tiles: Array[int] = []
) -> void:
	interaction_mode = mode
	highlighted_vertices = verts.duplicate()
	highlighted_edges = edges.duplicate()
	highlighted_tiles = tiles.duplicate()
	highlighted_city_vertices.clear()
	_pending_kind = ""
	_pending_id = -1
	queue_redraw()

func clear_highlights() -> void:
	interaction_mode = InteractionMode.NONE
	highlighted_vertices.clear()
	highlighted_edges.clear()
	highlighted_tiles.clear()
	highlighted_city_vertices.clear()
	_pending_kind = ""
	_pending_id = -1
	_hovered_vertex = -1
	_hovered_edge = -1
	_hovered_tile = -1
	_hovered_city_vertex = -1
	_hovered_port = -1
	_update_cursor_shape()
	queue_redraw()

# --- Build-on-board support (BUILD_ANY mode contract) ---

func set_build_hints(settlement_vertices: Array[int], road_edges: Array[int], city_vertices: Array[int]) -> void:
	highlighted_vertices = settlement_vertices.duplicate()
	highlighted_edges = road_edges.duplicate()
	highlighted_city_vertices = city_vertices.duplicate()
	interaction_mode = InteractionMode.BUILD_ANY
	queue_redraw()

func set_pending_build(kind: String, id: int) -> void:
	_pending_kind = kind
	_pending_id = id
	queue_redraw()

func clear_pending_build() -> void:
	_pending_kind = ""
	_pending_id = -1
	queue_redraw()

func get_spot_screen_position(kind: String, id: int) -> Vector2:
	var topo := HexMath.get_topology()
	var hex_radius := _get_hex_radius()
	if kind == "tile":
		if id >= 0 and id < topo.tile_centers.size():
			return _unit_to_screen(topo.tile_centers[id], hex_radius)
		return size * 0.5
	if kind == "road":
		if id >= 0 and id < topo.edge_vertices.size():
			var ev: Vector2i = topo.edge_vertices[id]
			var p1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
			var p2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
			return (p1 + p2) * 0.5
		return size * 0.5
	if id >= 0 and id < topo.vertex_positions.size():
		return _unit_to_screen(topo.vertex_positions[id], hex_radius)
	return size * 0.5

func _get_hex_radius() -> float:
	var half_y: float = size.y * 0.5
	var half_x: float = size.x * 0.5
	# Island reaches ~4.48 units (harbour point + boat + gap + label pill + 12 px margin).
	# Two linear bounds: one where the 26 px boat-minimum dominates, one where it scales with R.
	var ry := minf((half_y - 39.0) / 4.92, (half_y - 49.0) / 4.48)
	# Outward sea-side trade badge: circle + "2:1" tag reach ~5.7 units + 30 px.
	var ry_badge := (half_y - 22.0) / 5.5
	# East/west harbour label pill half-width (~58 px worst case) + 12 px margin.
	var rx := (half_x - 70.0) / 5.06
	return clampf(minf(minf(rx, ry), ry_badge), 24.0, 74.0)

func _unit_to_screen(unit_pos: Vector2, hex_radius: float) -> Vector2:
	return (size * 0.5) + unit_pos * hex_radius

func _pick_radius_vertex(hex_radius: float) -> float:
	return maxf(22.0, hex_radius * 0.45)

func _pick_radius_edge(hex_radius: float) -> float:
	return maxf(22.0, hex_radius * 0.42)

func _terrain_color(terrain: int) -> Color:
	return Palette.terrain(terrain)

func _terrain_label(terrain: int) -> String:
	match terrain:
		GameTypes.TerrainType.FOREST: return "TIMBER"
		GameTypes.TerrainType.HILLS: return "CLAY"
		GameTypes.TerrainType.PASTURE: return "FLEECE"
		GameTypes.TerrainType.FIELDS: return "GRAIN"
		GameTypes.TerrainType.MOUNTAINS: return "IRON"
		GameTypes.TerrainType.BARREN: return "BARREN"
		_: return ""

func _port_label(port_type: int) -> String:
	match port_type:
		GameTypes.PortType.GENERIC_3_TO_1: return "3:1"
		GameTypes.PortType.TIMBER_2_TO_1: return "2:1 Timber"
		GameTypes.PortType.CLAY_2_TO_1: return "2:1 Clay"
		GameTypes.PortType.FLEECE_2_TO_1: return "2:1 Fleece"
		GameTypes.PortType.GRAIN_2_TO_1: return "2:1 Grain"
		GameTypes.PortType.IRON_2_TO_1: return "2:1 Iron"
		_: return ""

func _port_color(port_type: int) -> Color:
	if port_type == GameTypes.PortType.GENERIC_3_TO_1:
		return Palette.PAPER
	return Palette.resource(port_type)

func _resource_color(res: int) -> Color:
	return Palette.resource(res)

func _motif_jitter(tile_id: int, n: int) -> float:
	return float(((tile_id + 3) * (n + 5) * 7 + n * 13) % 17 - 8) / 16.0

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.SEA)
	var hex_radius := _get_hex_radius()
	var board_center := size * 0.5
	_draw_sea_deco(board_center, hex_radius)

	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(clampf(hex_radius * 0.30, 11.0, 20.0))
	var small_font_size: int = int(clampf(hex_radius * 0.19, 9.0, 11.0))

	if state == null:
		_harbour_label_rects.clear()
		_port_badge_rects.clear()
		_port_badge_data.clear()
		_harbour_boat_rects.clear()
		_port_specs.clear()
		if font != null:
			var msg := "Configure seats in Lobby to start a match"
			var ts := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			_sstr(font, board_center - ts * 0.5, msg, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Palette.TEXT)
		return

	var topo := HexMath.get_topology()
	var pulse := 0.5 + 0.5 * sin(_pulse_time)

	# 1. Coastal harbours: parallel plank jetties + sailboats (labels drawn last)
	_draw_ports_structure(topo, hex_radius)

	# 2. 19 Pointy-top Hex Tiles
	for t_id in range(topo.tile_coords.size()):
		var t_center := _unit_to_screen(topo.tile_centers[t_id], hex_radius)
		var terrain: int = state.tile_terrains[t_id] if t_id < state.tile_terrains.size() else GameTypes.TerrainType.BARREN
		var base_col: Color = _terrain_color(terrain)

		var corners := PackedVector2Array()
		var border_pts := PackedVector2Array()
		for v_id in topo.tile_vertices[t_id]:
			var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
			corners.append(vp)
			border_pts.append(vp)
		border_pts.append(corners[0])

		var paper_pts := PackedVector2Array()
		for c in corners:
			paper_pts.append(t_center + (c - t_center) * 1.035)
		draw_colored_polygon(paper_pts, Palette.PAPER)
		draw_colored_polygon(corners, base_col)
		_draw_hex_wash(t_center, hex_radius, terrain)
		draw_polyline(border_pts, Palette.INK_SOFT, 2.0, true)

		_draw_tile_motif(t_id, terrain, t_center, hex_radius)

		# Terrain label near bottom of tile
		if font != null:
			var t_lbl := _terrain_label(terrain)
			var lbl_size := font.get_string_size(t_lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, small_font_size)
			_sstr(
				font,
				t_center + Vector2(-lbl_size.x * 0.5, hex_radius * 0.60),
				t_lbl,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				small_font_size,
				Palette.INK
			)

		# 3. Circular Number Tokens & Pip Dots
		var num: int = state.tile_numbers[t_id] if t_id < state.tile_numbers.size() else 0
		if num > 0:
			var token_r := hex_radius * 0.30
			draw_circle(t_center + Vector2(0, hex_radius * 0.035), token_r, Palette.PAPER_SHADOW)
			draw_circle(t_center, token_r, Palette.NUMBER_TOKEN_BG)
			draw_arc(t_center, token_r, 0.0, TAU, 32, Palette.INK, 1.6, true)

			var is_hot := (num == 6 or num == 8)
			var num_col: Color = Palette.NUMBER_TOKEN_HOT if is_hot else Palette.NUMBER_TOKEN_TEXT
			if font != null:
				var num_str := str(num)
				var n_size := font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
				_sstr(
					font,
					t_center + Vector2(-n_size.x * 0.5, n_size.y * 0.18),
					num_str,
					HORIZONTAL_ALIGNMENT_CENTER,
					-1,
					font_size,
					num_col
				)

			var pips := GameTypes.pip_count(num)
			var pip_spacing := hex_radius * 0.095
			var pip_start_x := -float(pips - 1) * pip_spacing * 0.5
			for p_idx in range(pips):
				var pip_pos := t_center + Vector2(pip_start_x + float(p_idx) * pip_spacing, token_r * 0.55)
				draw_circle(pip_pos, max(1.8, hex_radius * 0.032), num_col)

		# 4. Blocker Icon
		if state.blocker_tile == t_id and _blocker_t >= 1.0:
			var b_offset: Vector2 = Vector2(hex_radius * 0.28, -hex_radius * 0.24) if num > 0 else Vector2.ZERO
			_draw_blocker_icon(t_center + b_offset, hex_radius, small_font_size)

		# 5. Highlighted Tile Ring (for PICK_BLOCKER_TILE)
		if highlighted_tiles.has(t_id):
			var is_hov := (_hovered_tile == t_id)
			var ring_r := hex_radius * (0.48 + 0.05 * pulse)
			var ring_col: Color = Color(Palette.ACCENT_GOLD, 0.95) if is_hov else Color(Palette.HIGHLIGHT, 0.55 + 0.35 * pulse)
			draw_arc(t_center, ring_r, 0.0, TAU, 36, ring_col, 4.0 if is_hov else 3.0, true)

	# 6. Built Roads
	for e_id in range(topo.edge_vertices.size()):
		var owner_id: int = state.edge_owner[e_id] if e_id < state.edge_owner.size() else -1
		if owner_id != -1 and not _edge_pop_active(e_id):
			var ev: Vector2i = topo.edge_vertices[e_id]
			var p1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
			var p2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
			var a := p1.lerp(p2, 0.12)
			var b := p2.lerp(p1, 0.12)
			var p_col: Color = GameTypes.PLAYER_COLORS[owner_id % GameTypes.PLAYER_COLORS.size()]
			draw_line(a + Vector2(0, hex_radius * 0.04), b + Vector2(0, hex_radius * 0.04), Palette.PAPER_SHADOW, max(8.0, hex_radius * 0.22), true)
			draw_line(a, b, Palette.INK, max(8.0, hex_radius * 0.22), true)
			draw_line(a, b, p_col, max(5.0, hex_radius * 0.14), true)

	# 7. Highlighted Edges (classic modes)
	if interaction_mode != InteractionMode.BUILD_ANY:
		for e_id in highlighted_edges:
			if e_id < 0 or e_id >= topo.edge_vertices.size():
				continue
			var ev: Vector2i = topo.edge_vertices[e_id]
			var p1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
			var p2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
			var a := p1.lerp(p2, 0.16)
			var b := p2.lerp(p1, 0.16)
			var is_hov := (_hovered_edge == e_id)
			var glow_col: Color = Color(Palette.ACCENT_GOLD, 0.95) if is_hov else Color(Palette.HIGHLIGHT, 0.55 + 0.35 * pulse)
			draw_line(a, b, Color(Palette.INK_SOFT, 0.85), max(10.0, hex_radius * 0.24), true)
			draw_line(a, b, glow_col, max(6.0, hex_radius * 0.15), true)
			draw_circle((a + b) * 0.5, max(4.0, hex_radius * 0.09), glow_col)

	# 8. Harbour ownership rings (before pieces so the piece stays visible on top)
	_draw_port_ownership_rings(topo, hex_radius)

	# 9. Built Settlements & Cities
	for v_id in range(topo.vertex_positions.size()):
		var owner_id: int = state.vertex_owner[v_id] if v_id < state.vertex_owner.size() else -1
		var b_type: int = state.vertex_building[v_id] if v_id < state.vertex_building.size() else GameTypes.BuildingType.NONE
		if owner_id == -1 or b_type == GameTypes.BuildingType.NONE:
			continue
		if _vertex_pop_active(v_id):
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		var p_col: Color = GameTypes.PLAYER_COLORS[owner_id % GameTypes.PLAYER_COLORS.size()]
		if b_type == GameTypes.BuildingType.SETTLEMENT:
			_draw_settlement(vp, hex_radius * 0.22, p_col, owner_id % GameTypes.PLAYER_COLORS.size())
		elif b_type == GameTypes.BuildingType.CITY:
			_draw_city(vp, hex_radius * 0.28, p_col, owner_id % GameTypes.PLAYER_COLORS.size())

	# 10. Highlighted Vertices (classic modes)
	if interaction_mode != InteractionMode.BUILD_ANY:
		for v_id in highlighted_vertices:
			if v_id < 0 or v_id >= topo.vertex_positions.size():
				continue
			var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
			var is_hov := (_hovered_vertex == v_id)
			var rad: float = hex_radius * (0.22 if is_hov else (0.17 + 0.04 * pulse))
			var h_col: Color = Color(Palette.ACCENT_GOLD, 0.95) if is_hov else Color(Palette.HIGHLIGHT, 0.6 + 0.3 * pulse)
			draw_circle(vp, rad, Color(Palette.INK_SOFT, 0.45))
			draw_arc(vp, rad, 0.0, TAU, 24, h_col, 3.0 if is_hov else 2.2, true)

	# 9.5 Build pop-in animations and the sliding Blocker
	_draw_build_anims(topo, hex_radius)
	_draw_blocker_slide(topo, hex_radius, small_font_size)

	# 11. BUILD_ANY calm hints, hover ghost, pending build
	if interaction_mode == InteractionMode.BUILD_ANY:
		_draw_build_any(topo, hex_radius)

	# 12. Harbour paper labels — on top of everything land-related, over water only
	if font != null:
		_draw_port_labels(topo, hex_radius, font)

	# 13. Floating resource popups
	for popup in _popups:
		var p_age: float = popup["age"]
		var p_dur: float = popup["duration"]
		var p_t: float = clampf(p_age / p_dur, 0.0, 1.0)
		var p_alpha := 1.0
		if p_t > 0.62:
			p_alpha = clampf(1.0 - (p_t - 0.62) / 0.38, 0.0, 1.0)
		var p_pos: Vector2 = popup["pos"] + Vector2(0.0, -42.0 * p_t)
		var p_col: Color = popup["color"]
		if font == null:
			continue
		var p_font_size: int = int(clampf(hex_radius * 0.30, 12.0, 18.0))
		var p_text: String = popup["text"]
		var p_ts := font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_CENTER, -1, p_font_size)
		var p_dot_d: float = max(7.0, p_font_size * 0.55)
		var p_pill := Vector2(p_ts.x + p_dot_d + 28.0, p_ts.y + 10.0)
		var p_rect := Rect2(p_pos - p_pill * 0.5, p_pill)
		var p_box := StyleBoxFlat.new()
		p_box.bg_color = Color(Palette.PAPER, 0.94 * p_alpha)
		p_box.border_color = Color(Palette.INK_SOFT, Palette.INK_SOFT.a * p_alpha)
		p_box.set_border_width_all(2)
		p_box.set_corner_radius_all(int(p_pill.y * 0.5))
		draw_style_box(p_box, p_rect)
		var p_dot_x := p_rect.position.x + 8.0 + p_dot_d * 0.5
		draw_circle(Vector2(p_dot_x, p_pos.y), p_dot_d * 0.5, p_col)
		draw_arc(Vector2(p_dot_x, p_pos.y), p_dot_d * 0.5, 0.0, TAU, 16, Color(Palette.INK_SOFT, p_alpha), 1.0, true)
		_sstr(
			font,
			p_pos + Vector2(-p_ts.x * 0.5 + (p_dot_d + 8.0) * 0.5, p_ts.y * 0.32),
			p_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			p_font_size,
			Color(Palette.INK, p_alpha)
		)

	# 14. Trade toast banners
	for toast in _toasts:
		var t_age: float = toast["age"]
		var t_dur: float = toast["duration"]
		var t_t: float = clampf(t_age / t_dur, 0.0, 1.0)
		var t_alpha := 1.0
		if t_t < 0.12:
			t_alpha = t_t / 0.12
		elif t_t > 0.68:
			t_alpha = clampf(1.0 - (t_t - 0.68) / 0.32, 0.0, 1.0)
		var t_center := Vector2(size.x * 0.5, 44.0) + Vector2(0.0, -12.0 * t_t)
		var t_col: Color = toast["color"]
		if font == null:
			continue
		var t_font_size: int = int(clampf(hex_radius * 0.28, 12.0, 17.0))
		var t_text: String = toast["text"]
		var t_ts := font.get_string_size(t_text, HORIZONTAL_ALIGNMENT_CENTER, -1, t_font_size)
		var t_pill := Vector2(t_ts.x + 34.0, t_ts.y + 14.0)
		var t_rect := Rect2(t_center - t_pill * 0.5, t_pill)
		var t_box := StyleBoxFlat.new()
		t_box.bg_color = Color(Palette.TOAST_BG.r, Palette.TOAST_BG.g, Palette.TOAST_BG.b, Palette.TOAST_BG.a * t_alpha)
		t_box.border_color = Color(t_col.r, t_col.g, t_col.b, 0.95 * t_alpha)
		t_box.set_border_width_all(2)
		t_box.set_corner_radius_all(int(t_pill.y * 0.5))
		draw_style_box(t_box, t_rect)
		_sstr(
			font,
			t_center + Vector2(-t_ts.x * 0.5, t_ts.y * 0.32),
			t_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			t_font_size,
			Color(Palette.TOAST_TEXT, t_alpha)
		)

func _draw_sea_deco(board_center: Vector2, hex_radius: float) -> void:
	draw_circle(board_center, hex_radius * 4.30, Color(Palette.SEA_FOAM, 0.28))
	draw_circle(board_center, hex_radius * 4.62, Color(Palette.SEA_FOAM, 0.17))
	draw_circle(board_center, hex_radius * 4.95, Color(Palette.SEA_FOAM, 0.09))
	for i in range(9):
		var ang := TAU * float(i) / 9.0 + 0.35
		var radius_mult := 4.40 + float(i % 3) * 0.40
		var span := 0.34 + float((i + 1) % 3) * 0.10
		var wave_col := Color(Palette.SEA_DEEP, 0.45) if i % 2 == 0 else Color(Palette.SEA_FOAM, 0.60)
		draw_arc(board_center, hex_radius * radius_mult, ang, ang + span, 12, wave_col, 2.0, true)
	var cloud_span_x := size.x + 260.0
	for c_idx in range(_CLOUD_DEFS.size()):
		var def: Vector4 = _CLOUD_DEFS[c_idx]
		var cx := fmod(def.x * size.x + _ambient_time * def.w, cloud_span_x) - 130.0
		var cy := def.y * size.y
		var cs := def.z * maxf(18.0, hex_radius * 0.42)
		_draw_cloud(Vector2(cx, cy), cs)

func _draw_cloud(center: Vector2, scale_r: float) -> void:
	var cloud_col := Color(Palette.CLOUD.r, Palette.CLOUD.g, Palette.CLOUD.b, 0.38)
	var puffs := [
		Vector3(-0.95, 0.18, 0.62),
		Vector3(0.0, -0.16, 0.85),
		Vector3(0.95, 0.14, 0.58),
		Vector3(0.25, 0.30, 0.66),
	]
	for puff in puffs:
		var p: Vector3 = puff
		draw_circle(center + Vector2(p.x * scale_r, p.y * scale_r), p.z * scale_r, cloud_col)

func _draw_hex_wash(center: Vector2, r: float, terrain: int) -> void:
	var w := 0.866 * r
	var light_col := Color(Palette.terrain_light(terrain), 0.55)
	var shade_col := Color(Palette.terrain_shade(terrain), 0.60)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-w, -0.5 * r),
		center + Vector2(0.0, -r),
		center + Vector2(w, -0.5 * r),
		center + Vector2(w, -0.12 * r),
		center + Vector2(-w, -0.12 * r),
	]), light_col)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-w, 0.16 * r),
		center + Vector2(w, 0.16 * r),
		center + Vector2(w, 0.5 * r),
		center + Vector2(0.0, r),
		center + Vector2(-w, 0.5 * r),
	]), shade_col)

func _draw_tile_motif(tile_id: int, terrain: int, center: Vector2, r: float) -> void:
	var dark: Color = Color(Palette.terrain_shade(terrain), 0.95)
	var lite: Color = Color(Palette.terrain_light(terrain), 0.95)
	match terrain:
		GameTypes.TerrainType.FOREST:
			var xs := [-0.50, -0.17, 0.19, 0.50]
			for k in range(4):
				var tx: float = center.x + xs[k] * r * 0.78 + _motif_jitter(tile_id, k) * 0.05 * r
				var ty: float = center.y - 0.42 * r + _motif_jitter(tile_id, k + 4) * 0.05 * r
				_draw_tree(Vector2(tx, ty), r * 0.95, dark, lite)
			_draw_tree(Vector2(center.x - 0.42 * r, center.y + 0.40 * r), r * 0.70, dark, lite)
		GameTypes.TerrainType.PASTURE:
			draw_arc(center + Vector2(-0.30 * r, -0.16 * r), 0.30 * r, PI, TAU, 12, dark, 2.2, true)
			draw_arc(center + Vector2(0.28 * r, -0.22 * r), 0.22 * r, PI, TAU, 12, dark, 2.0, true)
			_draw_sheep(center + Vector2(-0.34 * r, 0.40 * r), r)
			_draw_sheep(center + Vector2(-0.06 * r, 0.44 * r), r * 0.85)
		GameTypes.TerrainType.FIELDS:
			for k in range(5):
				var wx: float = center.x + (-0.48 + 0.24 * float(k)) * r + _motif_jitter(tile_id, k) * 0.04 * r
				var wy: float = center.y - 0.42 * r + _motif_jitter(tile_id, k + 2) * 0.05 * r
				_draw_wheat(Vector2(wx, wy), r, dark)
			for k in range(2):
				var bx: float = center.x + (0.38 + 0.16 * float(k)) * r
				_draw_wheat(Vector2(bx, center.y + 0.40 * r), r * 0.9, dark)
		GameTypes.TerrainType.HILLS:
			draw_arc(center + Vector2(0.0, -0.14 * r), 0.36 * r, PI, TAU, 16, dark, 2.4, true)
			draw_arc(center + Vector2(0.0, -0.14 * r), 0.21 * r, PI, TAU, 12, lite, 2.0, true)
			for k in range(2):
				var bpos := center + Vector2((-0.46 + 0.20 * float(k)) * r, 0.38 * r)
				var brect := Rect2(bpos - Vector2(0.09 * r, 0.045 * r), Vector2(0.18 * r, 0.09 * r))
				draw_rect(brect, dark)
				draw_rect(brect, Color(Palette.INK_SOFT, 0.6), false, 1.0)
		GameTypes.TerrainType.MOUNTAINS:
			var peaks := [-0.32, 0.02, 0.34]
			for k in range(3):
				var px: float = center.x + peaks[k] * r + _motif_jitter(tile_id, k) * 0.04 * r
				var ph: float = (0.24 + float((tile_id + k) % 3) * 0.05) * r
				_draw_peak(Vector2(px, center.y - 0.30 * r), ph, 0.13 * r, dark, lite)
			_draw_peak(Vector2(center.x - 0.40 * r, center.y + 0.42 * r), 0.14 * r, 0.08 * r, dark, lite)
		GameTypes.TerrainType.BARREN:
			draw_arc(center + Vector2(-0.22 * r, -0.24 * r), 0.34 * r, PI, TAU, 12, dark, 2.0, true)
			draw_arc(center + Vector2(0.26 * r, -0.34 * r), 0.24 * r, PI, TAU, 12, lite, 1.8, true)
			var rock_pos := center + Vector2(0.40 * r, 0.40 * r)
			draw_colored_polygon(PackedVector2Array([
				rock_pos + Vector2(-0.07 * r, 0.05 * r),
				rock_pos + Vector2(-0.03 * r, -0.06 * r),
				rock_pos + Vector2(0.05 * r, -0.03 * r),
				rock_pos + Vector2(0.07 * r, 0.05 * r),
			]), dark)
			draw_circle(rock_pos + Vector2(0.11 * r, 0.04 * r), 0.02 * r, Palette.INK_SOFT)

func _draw_tree(pos: Vector2, r: float, dark: Color, lite: Color) -> void:
	draw_line(pos + Vector2(0, 0.02 * r), pos + Vector2(0, 0.12 * r), Color(Palette.DOCK_WOOD, 0.95), maxf(1.5, r * 0.025), true)
	draw_circle(pos - Vector2(0, 0.05 * r), 0.085 * r, dark)
	draw_circle(pos - Vector2(0.025 * r, 0.075 * r), 0.04 * r, lite)

func _draw_sheep(pos: Vector2, r: float) -> void:
	draw_circle(pos, 0.055 * r, Palette.PAPER)
	draw_arc(pos, 0.055 * r, 0.0, TAU, 12, Color(Palette.INK_SOFT, 0.8), 1.0, true)
	draw_circle(pos + Vector2(0.05 * r, -0.015 * r), 0.024 * r, Palette.INK)

func _draw_wheat(pos: Vector2, r: float, dark: Color) -> void:
	draw_line(pos + Vector2(0, 0.10 * r), pos - Vector2(0, 0.08 * r), dark, maxf(1.5, r * 0.022), true)
	draw_circle(pos - Vector2(0, 0.10 * r), 0.022 * r, dark)

func _draw_peak(pos: Vector2, h: float, hw: float, dark: Color, lite: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		pos - Vector2(hw, 0),
		pos + Vector2(0, -h),
		pos + Vector2(hw, 0),
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-hw * 0.32, -h * 0.68),
		pos + Vector2(0, -h),
		pos + Vector2(hw * 0.32, -h * 0.68),
		pos + Vector2(hw * 0.12, -h * 0.60),
		pos - Vector2(hw * 0.10, -h * 0.66),
	]), lite)

func _draw_ports_structure(topo: HexMath.BoardTopology, hex_radius: float) -> void:
	_harbour_label_rects.clear()
	_port_badge_rects.clear()
	_harbour_boat_rects.clear()
	_port_specs.clear()
	if state.vertex_ports.size() < topo.vertex_positions.size():
		return
	var port_index := 0
	for e_id in topo.coastal_edges:
		var ev: Vector2i = topo.edge_vertices[e_id]
		var p_a: int = state.vertex_ports[ev.x]
		var p_b: int = state.vertex_ports[ev.y]
		if p_a == -2 or p_a != p_b:
			continue
		var v1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
		var v2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
		var mid := (v1 + v2) * 0.5
		var t_id: int = topo.edge_tiles[e_id][0]
		var t_center := _unit_to_screen(topo.tile_centers[t_id], hex_radius)
		var outward := (mid - t_center).normalized()
		var tangent := Vector2(-outward.y, outward.x)

		# Two parallel plank jetties, each running straight outward from its port vertex.
		_draw_pier(v1, outward, hex_radius)
		_draw_pier(v2, outward, hex_radius)

		var bob := 0.0
		if not reduce_motion:
			bob = sin(_ambient_time * 1.8 + float(port_index) * 1.7) * (hex_radius * 0.03)
		var boat_pos: Vector2 = mid + outward * (hex_radius * 0.73) + Vector2(0.0, bob)
		_draw_boat(boat_pos, hex_radius, p_a)
		_harbour_boat_rects.append(_boat_rect(boat_pos, hex_radius))
		_port_specs.append({
			"boat_index": port_index,
			"boat_pos": boat_pos,
			"tangent": tangent,
			"port_type": p_a,
			"mid": mid,
			"outward": outward,
		})
		port_index += 1

func _draw_pier(from: Vector2, outward: Vector2, r: float) -> void:
	var perp := Vector2(-outward.y, outward.x)
	var a := from + outward * (r * 0.04)
	var to := from + outward * (r * 0.45)
	var w := 5.0
	draw_line(a, to, Color(Palette.DOCK_WOOD.darkened(0.35), 0.95), w + 2.0, true)
	draw_line(a, to, Palette.DOCK_WOOD, w, true)
	for k in range(1, 4):
		var pt := a.lerp(to, float(k) / 4.0)
		draw_line(pt - perp * w * 0.75, pt + perp * w * 0.75, Color(Palette.DOCK_WOOD.darkened(0.5), 0.95), 1.4, true)

func _boat_scale(r: float) -> float:
	return maxf(r, 43.4)

func _boat_rect(pos: Vector2, r: float) -> Rect2:
	var k := _boat_scale(r)
	return Rect2(pos + Vector2(-0.28 * k, -0.31 * k), Vector2(0.56 * k, 0.76 * k))

func _draw_boat(pos: Vector2, r: float, port_type: int) -> void:
	var k := _boat_scale(r)
	var hull := PackedVector2Array([
		pos + Vector2(-0.275 * k, 0.10 * k),
		pos + Vector2(0.275 * k, 0.10 * k),
		pos + Vector2(0.185 * k, 0.26 * k),
		pos + Vector2(0.0, 0.31 * k),
		pos + Vector2(-0.185 * k, 0.26 * k),
	])
	draw_colored_polygon(hull, Palette.DOCK_WOOD)
	var hull_outline := hull.duplicate()
	hull_outline.append(hull[0])
	draw_polyline(hull_outline, Palette.INK, 1.5, true)
	draw_line(pos + Vector2(0, 0.10 * k), pos + Vector2(0, -0.30 * k), Palette.INK, 1.4, true)
	var sail_col: Color = Palette.PAPER if port_type == GameTypes.PortType.GENERIC_3_TO_1 else Palette.resource(port_type).lightened(0.35)
	var mainsail := PackedVector2Array([
		pos + Vector2(0.02 * k, -0.30 * k),
		pos + Vector2(0.02 * k, 0.08 * k),
		pos + Vector2(0.25 * k, 0.08 * k),
	])
	draw_colored_polygon(mainsail, sail_col)
	var mainsail_outline := mainsail.duplicate()
	mainsail_outline.append(mainsail[0])
	draw_polyline(mainsail_outline, Palette.INK, 1.5, true)
	var jib := PackedVector2Array([
		pos + Vector2(-0.02 * k, -0.17 * k),
		pos + Vector2(-0.02 * k, 0.06 * k),
		pos + Vector2(-0.145 * k, 0.06 * k),
	])
	draw_colored_polygon(jib, sail_col)
	var jib_outline := jib.duplicate()
	jib_outline.append(jib[0])
	draw_polyline(jib_outline, Palette.INK, 1.5, true)
	draw_line(pos + Vector2(-0.15 * k, 0.36 * k), pos + Vector2(0.15 * k, 0.36 * k), Color(Palette.SEA_FOAM, 0.9), 1.6, true)
	draw_line(pos + Vector2(-0.07 * k, 0.42 * k), pos + Vector2(0.07 * k, 0.42 * k), Color(Palette.SEA_FOAM, 0.7), 1.4, true)

func _draw_port_labels(topo: HexMath.BoardTopology, hex_radius: float, font: Font) -> void:
	_harbour_label_rects.clear()
	_port_badge_rects.clear()
	_port_badge_data.clear()
	if _port_specs.is_empty() or size.x < 10.0 or size.y < 10.0:
		return
	var land_polys: Array[PackedVector2Array] = []
	for t_id in range(topo.tile_coords.size()):
		var poly := PackedVector2Array()
		for v_id in topo.tile_vertices[t_id]:
			poly.append(_unit_to_screen(topo.vertex_positions[v_id], hex_radius))
		land_polys.append(poly)
	_land_polys_screen = land_polys
	var placed: Array[Rect2] = []
	var placed_badges: Array[Rect2] = []
	var bound := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	var gap := 4.0
	for spec in _port_specs:
		var port_type: int = int(spec["port_type"])
		var boat_pos: Vector2 = spec["boat_pos"]
		var tangent: Vector2 = spec["tangent"]
		var boat_index: int = int(spec["boat_index"])
		var boat_rect: Rect2 = _harbour_boat_rects[boat_index]
		var fs := maxi(11, int(clampf(hex_radius * 0.21, 11.0, 14.0)))
		var lbl := _port_label(port_type)
		var text_ts := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var dot_r: float = 0.0 if port_type == GameTypes.PortType.GENERIC_3_TO_1 else maxf(3.0, (float(fs) + 9.0) * 0.22)
		var dot_w: float = dot_r * 2.0 + 8.0
		var pill := Vector2(text_ts.x + dot_w + 16.0, float(fs) + 9.0)
		var below_c: Vector2 = Vector2(boat_pos.x, boat_rect.end.y + gap + pill.y * 0.5)
		var above_c: Vector2 = Vector2(boat_pos.x, boat_rect.position.y - gap - pill.y * 0.5)
		var first := below_c
		if Rect2(below_c - pill * 0.5, pill).end.y > bound.end.y:
			first = above_c
		var second: Vector2 = above_c if first == below_c else below_c
		var cands: Array[Vector2] = [first, second]
		for s in [0.34, 0.68, 1.02]:
			cands.append(Vector2(first.x + s * pill.x, first.y))
			cands.append(Vector2(first.x - s * pill.x, first.y))
			cands.append(Vector2(second.x + s * pill.x, second.y))
			cands.append(Vector2(second.x - s * pill.x, second.y))
		cands.append(first + tangent * pill.x * 0.6)
		cands.append(first - tangent * pill.x * 0.6)
		cands.append(second + tangent * pill.x * 0.6)
		cands.append(second - tangent * pill.x * 0.6)
		var chosen := Rect2()
		var found := false
		for c in cands:
			var rect := _clamp_rect(Rect2(c - pill * 0.5, pill), bound)
			if _label_hits(rect, land_polys, placed):
				continue
			chosen = rect
			found = true
			break
		if not found:
			chosen = _clamp_rect(Rect2(first - pill * 0.5, pill), bound)
		placed.append(chosen)
		_harbour_label_rects.append(chosen)
		var pi: int = _port_specs.find(spec)
		var badge_d := maxf(24.0, hex_radius * 0.62)
		var r_c: float = badge_d * 0.5
		var tag_fs := maxi(11, int(badge_d * 0.30))
		var tag_txt := "3:1" if port_type == GameTypes.PortType.GENERIC_3_TO_1 else "2:1"
		var tag_ts := font.get_string_size(tag_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, tag_fs)
		var tag_w: float = tag_ts.x + 8.0
		var tag_h: float = float(tag_fs) + 5.0
		var mid: Vector2 = spec["mid"]
		var u: Vector2 = spec["outward"]
		var boat_sup: float = _rect_support_along(boat_rect, u) - mid.dot(u)
		var tag_gap: float = r_c + 3.0 + tag_h * 0.5
		var chosen_c := Vector2.INF
		var chosen_tag := Rect2()
		var t := boat_sup + 6.0 + r_c
		while t < 480.0:
			var c := mid + u * t
			var badge_rect := Rect2(c - Vector2(r_c, r_c), Vector2(badge_d, badge_d))
			var tc := c + u * tag_gap
			var tag_rect := Rect2(tc - Vector2(tag_w, tag_h) * 0.5, Vector2(tag_w, tag_h))
			if not bound.encloses(badge_rect) or not bound.encloses(tag_rect):
				break
			if _badge_zone_clear(c, r_c, tag_rect, land_polys, _harbour_boat_rects, placed_badges):
				chosen_c = c
				chosen_tag = tag_rect
				break
			t += 3.0
		if chosen_c == Vector2.INF:
			var last_c := mid + u * (boat_sup + 6.0 + r_c)
			var last_tag := Rect2(last_c + u * tag_gap - Vector2(tag_w, tag_h) * 0.5, Vector2(tag_w, tag_h))
			var tt := boat_sup + 6.0 + r_c
			while tt < 480.0:
				var c2 := mid + u * tt
				var badge_rect2 := Rect2(c2 - Vector2(r_c, r_c), Vector2(badge_d, badge_d))
				var tc2 := c2 + u * tag_gap
				var tag_rect2 := Rect2(tc2 - Vector2(tag_w, tag_h) * 0.5, Vector2(tag_w, tag_h))
				if not bound.encloses(badge_rect2) or not bound.encloses(tag_rect2):
					break
				last_c = c2
				last_tag = tag_rect2
				tt += 3.0
			chosen_c = last_c
			chosen_tag = last_tag
		placed_badges.append(Rect2(chosen_c - Vector2(r_c, r_c), Vector2(badge_d, badge_d)))
		placed_badges.append(chosen_tag)
		_port_badge_rects.append(Rect2(chosen_c - Vector2(r_c, r_c), Vector2(badge_d, badge_d)))
		_port_badge_data.append({
			"center": chosen_c,
			"r": r_c,
			"tag_rect": chosen_tag,
			"boat_rect": boat_rect,
		})
		if _hovered_port == pi or show_port_names:
			_draw_port_label_pill(chosen, font, fs, port_type)
		_draw_port_badge(chosen_c, badge_d, port_type, chosen_tag, tag_txt, tag_fs)

func _label_hits(rect: Rect2, land_polys: Array[PackedVector2Array], placed: Array[Rect2]) -> bool:
	var rect_poly := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	for poly in land_polys:
		if _convex_polygons_intersect(rect_poly, poly):
			return true
	for boat in _harbour_boat_rects:
		if rect.intersects(boat):
			return true
	for other in placed:
		if rect.intersects(other):
			return true
	return false

func _convex_polygons_intersect(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if a.size() < 3 or b.size() < 3:
		return false
	var polys: Array = [a, b]
	for poly in polys:
		var pts: PackedVector2Array = poly
		for i in range(pts.size()):
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[(i + 1) % pts.size()]
			var axis := Vector2(-(p2.y - p1.y), p2.x - p1.x)
			var min_a := INF
			var max_a := -INF
			for pa in a:
				var da: float = axis.dot(pa)
				min_a = minf(min_a, da)
				max_a = maxf(max_a, da)
			var min_b := INF
			var max_b := -INF
			for pb in b:
				var db: float = axis.dot(pb)
				min_b = minf(min_b, db)
				max_b = maxf(max_b, db)
			if max_a < min_b or max_b < min_a:
				return false
	return true

func _clamp_rect(rect: Rect2, bound: Rect2) -> Rect2:
	var pos := rect.position
	pos.x = clampf(pos.x, bound.position.x, maxf(bound.position.x, bound.end.x - rect.size.x))
	pos.y = clampf(pos.y, bound.position.y, maxf(bound.position.y, bound.end.y - rect.size.y))
	return Rect2(pos, rect.size)

func _draw_port_label_pill(rect: Rect2, font: Font, font_size: int, port_type: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.border_color = Palette.INK_SOFT
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(rect.size.y * 0.5))
	draw_style_box(box, rect)
	var fs := maxi(11, font_size)
	var lbl := _port_label(port_type)
	var text_ts := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var dot_r: float = 0.0 if port_type == GameTypes.PortType.GENERIC_3_TO_1 else maxf(3.0, rect.size.y * 0.22)
	var text_cy := rect.position.y + rect.size.y * 0.5
	var dot_cx := rect.position.x + 6.0 + dot_r
	if dot_r > 0.0:
		draw_circle(Vector2(dot_cx, text_cy), dot_r, _port_color(port_type))
		draw_arc(Vector2(dot_cx, text_cy), dot_r, 0.0, TAU, 12, Palette.INK_SOFT, 1.0, true)
	var text_left := rect.position.x + (rect.size.x - text_ts.x) * 0.5 + (dot_r * 2.0 + 4.0) * 0.5
	if port_type == GameTypes.PortType.GENERIC_3_TO_1:
		text_left = rect.position.x + (rect.size.x - text_ts.x) * 0.5
	_sstr(
		font,
		Vector2(text_left, text_cy + text_ts.y * 0.32),
		lbl,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Palette.INK
	)

func _draw_port_ownership_rings(topo: HexMath.BoardTopology, hex_radius: float) -> void:
	if state.vertex_ports.size() < topo.vertex_positions.size():
		return
	for e_id in topo.coastal_edges:
		var ev: Vector2i = topo.edge_vertices[e_id]
		var p_a: int = state.vertex_ports[ev.x]
		var p_b: int = state.vertex_ports[ev.y]
		if p_a == -2 or p_a != p_b:
			continue
		for v_id in [ev.x, ev.y]:
			var owner_id: int = state.vertex_owner[v_id] if v_id < state.vertex_owner.size() else -1
			if owner_id < 0:
				continue
			var b_type: int = state.vertex_building[v_id] if v_id < state.vertex_building.size() else GameTypes.BuildingType.NONE
			var piece_r: float = hex_radius * 0.28 if b_type == GameTypes.BuildingType.CITY else hex_radius * 0.22
			var ring_r: float = piece_r + 5.0
			var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
			var p_col: Color = GameTypes.PLAYER_COLORS[owner_id % GameTypes.PLAYER_COLORS.size()]
			draw_arc(vp, ring_r, 0.0, TAU, 32, Color(p_col, 0.95), 2.5, true)
			draw_arc(vp, ring_r + 2.0, 0.0, TAU, 32, Color(Palette.INK_SOFT, 0.9), 1.0, true)

func _draw_build_any(topo: HexMath.BoardTopology, hex_radius: float) -> void:
	var cur_seat: int = state.current_player % GameTypes.PLAYER_COLORS.size()
	var p_col: Color = GameTypes.PLAYER_COLORS[cur_seat]
	var ring_alpha: float = 0.8 if reduce_motion else (0.6 + 0.4 * (0.5 + 0.5 * sin(_ambient_time * 2.0)))
	for e_id in highlighted_edges:
		if e_id < 0 or e_id >= topo.edge_vertices.size():
			continue
		var ev: Vector2i = topo.edge_vertices[e_id]
		var p1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
		var p2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
		var a := p1.lerp(p2, 0.24)
		var b := p2.lerp(p1, 0.24)
		if _hovered_edge == e_id:
			draw_line(a, b, Color(Palette.ACCENT_GOLD, 0.95), 7.0, true)
			draw_circle(a, 3.5, Color(Palette.ACCENT_GOLD, 0.95))
			draw_circle(b, 3.5, Color(Palette.ACCENT_GOLD, 0.95))
			draw_line(a, b, Color(p_col, 0.55), 5.0, true)
		else:
			draw_line(a, b, Color(Palette.INK_SOFT, 0.9), 7.0, true)
			draw_line(a, b, Color(Palette.ACCENT_GOLD, 0.75), 5.0, true)
			draw_circle(a, 2.5, Color(Palette.ACCENT_GOLD, 0.75))
			draw_circle(b, 2.5, Color(Palette.ACCENT_GOLD, 0.75))
	for v_id in highlighted_vertices:
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		if _hovered_vertex == v_id:
			draw_circle(vp, 11.0, Color(Palette.ACCENT_GOLD, 0.40))
			_draw_settlement(vp, hex_radius * 0.22, Color(p_col, 0.55), cur_seat)
			draw_arc(vp, 8.0, 0.0, TAU, 24, Color(Palette.ACCENT_GOLD, 1.0), 2.0, true)
		else:
			draw_circle(vp, 7.0, Palette.PAPER)
			draw_arc(vp, 7.0, 0.0, TAU, 24, Color(Palette.ACCENT_GOLD, ring_alpha), 2.0, true)
	for v_id in highlighted_city_vertices:
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		if _hovered_city_vertex == v_id:
			draw_circle(vp, 12.0, Color(Palette.ACCENT_GOLD, 0.40))
			_draw_city(vp, hex_radius * 0.28, Color(p_col, 0.55), cur_seat)
			draw_arc(vp, 8.0, 0.0, TAU, 24, Color(Palette.ACCENT_GOLD, 1.0), 2.0, true)
		_draw_city_chevron(vp, hex_radius)
	if _pending_kind != "" and _pending_id >= 0:
		var spot := get_spot_screen_position(_pending_kind, _pending_id)
		if _pending_kind == "road":
			var pev: Vector2i = topo.edge_vertices[_pending_id]
			var pa := _unit_to_screen(topo.vertex_positions[pev.x], hex_radius).lerp(_unit_to_screen(topo.vertex_positions[pev.y], hex_radius), 0.12)
			var pb := _unit_to_screen(topo.vertex_positions[pev.y], hex_radius).lerp(_unit_to_screen(topo.vertex_positions[pev.x], hex_radius), 0.12)
			draw_line(pa, pb, Color(p_col, 0.85), max(5.0, hex_radius * 0.14), true)
		elif _pending_kind == "city":
			_draw_city(spot, hex_radius * 0.28, Color(p_col, 0.85), cur_seat)
		else:
			_draw_settlement(spot, hex_radius * 0.22, Color(p_col, 0.85), cur_seat)
		var pulse_r := hex_radius * (0.30 + 0.035 * sin(_ambient_time * 3.5))
		draw_arc(spot, pulse_r, 0.0, TAU, 32, Palette.PAPER, 3.6, true)
		draw_arc(spot, pulse_r, 0.0, TAU, 32, Color(Palette.ACCENT_GOLD, 0.95), 2.2, true)

func _draw_city_chevron(vp: Vector2, r: float) -> void:
	var badge_c := vp + Vector2(0.0, -maxf(15.0, r * 0.42))
	draw_circle(badge_c, 8.0, Palette.PAPER)
	draw_arc(badge_c, 8.0, 0.0, TAU, 20, Color(Palette.INK_SOFT, 0.9), 1.4, true)
	var chevron := PackedVector2Array([
		badge_c + Vector2(-3.6, 1.9),
		badge_c + Vector2(0.0, -2.1),
		badge_c + Vector2(3.6, 1.9),
	])
	draw_polyline(chevron, Palette.ACCENT_GOLD, 2.4, true)

func _draw_settlement(center: Vector2, r: float, col: Color, seat: int) -> void:
	draw_circle(center + Vector2(0, r * 0.35), r * 0.95, Palette.PAPER_SHADOW)
	var poly := PackedVector2Array([
		center + Vector2(0, -r * 1.15),
		center + Vector2(r * 0.95, -r * 0.2),
		center + Vector2(r * 0.8, r * 0.95),
		center + Vector2(-r * 0.8, r * 0.95),
		center + Vector2(-r * 0.95, -r * 0.2),
	])
	draw_colored_polygon(poly, col)
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Palette.INK, 2.2, true)
	_draw_seat_mark(center, r, seat)

func _draw_city(center: Vector2, r: float, col: Color, seat: int) -> void:
	draw_circle(center + Vector2(0, r * 0.30), r * 1.05, Palette.PAPER_SHADOW)
	var poly := PackedVector2Array([
		center + Vector2(-r * 1.05, r * 0.95),
		center + Vector2(-r * 1.05, -r * 0.25),
		center + Vector2(-r * 0.55, -r * 0.75),
		center + Vector2(-r * 0.05, -r * 0.25),
		center + Vector2(-r * 0.05, -r * 0.95),
		center + Vector2(r * 0.5, -r * 1.25),
		center + Vector2(r * 1.05, -r * 0.95),
		center + Vector2(r * 1.05, r * 0.95),
	])
	draw_colored_polygon(poly, col)
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Palette.INK, 2.5, true)
	_draw_seat_mark(center, r, seat)

func _draw_seat_mark(center: Vector2, r: float, seat: int) -> void:
	match seat:
		1:
			draw_circle(center + Vector2(0, r * 0.25), r * 0.22, Palette.PAPER)
			draw_arc(center + Vector2(0, r * 0.25), r * 0.22, 0.0, TAU, 12, Palette.INK, 1.1, true)
		2:
			var stripe := Rect2(center + Vector2(-r * 0.62, r * 0.08), Vector2(r * 1.24, r * 0.30))
			draw_rect(stripe, Palette.PAPER)
			draw_rect(stripe, Palette.INK, false, 1.1)
		3:
			draw_arc(center + Vector2(0, r * 0.20), r * 0.36, 0.0, TAU, 16, Palette.PAPER, 3.0, true)
			draw_arc(center + Vector2(0, r * 0.20), r * 0.36, 0.0, TAU, 16, Palette.INK, 1.1, true)
		_:
			pass

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	var topo := HexMath.get_topology()
	var hex_radius := _get_hex_radius()

	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		_hovered_vertex = _find_closest_vertex(topo, hex_radius, pos)
		_hovered_edge = _find_closest_edge(topo, hex_radius, pos)
		_hovered_tile = _find_closest_tile(topo, hex_radius, pos)
		_hovered_city_vertex = _find_closest_city_vertex(topo, hex_radius, pos)
		var new_port := -1
		for i in range(_port_badge_rects.size()):
			if _port_badge_rects[i].grow(3.0).has_point(pos):
				new_port = i
				break
		if new_port != _hovered_port:
			_hovered_port = new_port
		_update_cursor_shape()
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		if interaction_mode == InteractionMode.BUILD_ANY:
			if not _handle_build_click(topo, hex_radius, pos):
				background_clicked.emit()
			return
		if not highlighted_vertices.is_empty():
			var v_id := _find_closest_vertex(topo, hex_radius, pos)
			if v_id != -1:
				vertex_clicked.emit(v_id)
				accept_event()
				return
		if not highlighted_edges.is_empty():
			var e_id := _find_closest_edge(topo, hex_radius, pos)
			if e_id != -1:
				edge_clicked.emit(e_id)
				accept_event()
				return
		if not highlighted_tiles.is_empty():
			var t_id := _find_closest_tile(topo, hex_radius, pos)
			if t_id != -1:
				tile_clicked.emit(t_id)
				accept_event()
				return
		background_clicked.emit()

func _update_cursor_shape() -> void:
	var over_spot := (
		interaction_mode == InteractionMode.BUILD_ANY
		and (_hovered_vertex != -1 or _hovered_city_vertex != -1 or _hovered_edge != -1)
	)
	if over_spot:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _handle_build_click(topo: HexMath.BoardTopology, hex_radius: float, pos: Vector2) -> bool:
	var best_v := -1
	var best_kind := ""
	var best_v_d := _pick_radius_vertex(hex_radius)
	for v_id in highlighted_vertices:
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		var d := pos.distance_to(vp)
		if d < best_v_d:
			best_v_d = d
			best_v = v_id
			best_kind = "settlement"
	for v_id in highlighted_city_vertices:
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		var d := pos.distance_to(vp)
		if d < best_v_d:
			best_v_d = d
			best_v = v_id
			best_kind = "city"
	if best_v != -1:
		build_spot_clicked.emit(best_kind, best_v)
		accept_event()
		return true
	var best_e := -1
	var best_e_d := _pick_radius_edge(hex_radius)
	for e_id in highlighted_edges:
		if e_id < 0 or e_id >= topo.edge_vertices.size():
			continue
		var ev: Vector2i = topo.edge_vertices[e_id]
		var p1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
		var p2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
		var closest := Geometry2D.get_closest_point_to_segment(pos, p1, p2)
		var d := pos.distance_to(closest)
		if d < best_e_d:
			best_e_d = d
			best_e = e_id
	if best_e != -1:
		build_spot_clicked.emit("road", best_e)
		accept_event()
		return true
	return false

func _find_closest_vertex(topo: HexMath.BoardTopology, hex_radius: float, pos: Vector2) -> int:
	var best_v := -1
	var best_dist := _pick_radius_vertex(hex_radius)
	for v_id in highlighted_vertices:
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		var d := pos.distance_to(vp)
		if d < best_dist:
			best_dist = d
			best_v = v_id
	return best_v

func _find_closest_edge(topo: HexMath.BoardTopology, hex_radius: float, pos: Vector2) -> int:
	var best_e := -1
	var best_dist := _pick_radius_edge(hex_radius)
	for e_id in highlighted_edges:
		if e_id < 0 or e_id >= topo.edge_vertices.size():
			continue
		var ev: Vector2i = topo.edge_vertices[e_id]
		var p1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
		var p2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
		var closest := Geometry2D.get_closest_point_to_segment(pos, p1, p2)
		var d := pos.distance_to(closest)
		if d < best_dist:
			best_dist = d
			best_e = e_id
	return best_e

func _find_closest_city_vertex(topo: HexMath.BoardTopology, hex_radius: float, pos: Vector2) -> int:
	var best_v := -1
	var best_dist := _pick_radius_vertex(hex_radius)
	for v_id in highlighted_city_vertices:
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		var d := pos.distance_to(vp)
		if d < best_dist:
			best_dist = d
			best_v = v_id
	return best_v

func _find_closest_tile(topo: HexMath.BoardTopology, hex_radius: float, pos: Vector2) -> int:
	var best_t := -1
	var best_dist := hex_radius * 0.85
	for t_id in highlighted_tiles:
		if t_id < 0 or t_id >= topo.tile_centers.size():
			continue
		var tc := _unit_to_screen(topo.tile_centers[t_id], hex_radius)
		var d := pos.distance_to(tc)
		if d < best_dist:
			best_dist = d
			best_t = t_id
	return best_t

func _rect_support_along(rect: Rect2, dir: Vector2) -> float:
	var best := -INF
	for p in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]:
		best = maxf(best, p.dot(dir))
	return best


func _badge_zone_clear(center: Vector2, r: float, tag_rect: Rect2, polys: Array[PackedVector2Array], boats: Array[Rect2], placed: Array[Rect2]) -> bool:
	for pr in placed:
		if tag_rect.grow(2.0).intersects(pr):
			return false
		if _rect_circle_overlap(pr, center, r + 2.0):
			return false
	for br in boats:
		if _rect_circle_overlap(br, center, r + 2.0):
			return false
		if tag_rect.grow(2.0).intersects(br):
			return false
	for poly in polys:
		if point_poly_dist(center, poly) < r + 1.5:
			return false
		for corner in [
			tag_rect.position,
			Vector2(tag_rect.end.x, tag_rect.position.y),
			tag_rect.end,
			Vector2(tag_rect.position.x, tag_rect.end.y),
		]:
			if point_poly_dist(corner, poly) < 1.5:
				return false
	return true


func _rect_circle_overlap(rect: Rect2, c: Vector2, r: float) -> bool:
	var p := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return c.distance_to(p) < r


func point_poly_dist(p: Vector2, poly: PackedVector2Array) -> float:
	var inside := false
	var n := poly.size()
	for i in range(n):
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
	if inside:
		return 0.0
	var best := INF
	for i in range(n):
		var d := _point_seg_dist(p, poly[i], poly[(i + 1) % n])
		if d < best:
			best = d
	return best


func _point_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func get_land_polys() -> Array[PackedVector2Array]:
	return _land_polys_screen


func get_port_badge_data() -> Array[Dictionary]:
	return _port_badge_data


func _draw_port_badge(center: Vector2, d: float, port_type: int, tag_rect: Rect2, tag_txt: String, tag_fs: int) -> void:
	var r := d * 0.5
	draw_circle(center, r, Palette.PAPER)
	draw_arc(center, r, 0.0, TAU, 28, Palette.INK_SOFT, 1.8, true)
	var is_generic: bool = port_type == GameTypes.PortType.GENERIC_3_TO_1
	var er := Rect2(center - Vector2(r, r) * 0.70, Vector2(r, r) * 1.40)
	if is_generic:
		CardFace.draw_emblem(self, "mixed", 0, er)
	else:
		CardFace.draw_emblem(self, "resource", port_type, er)
	var font := ThemeDB.fallback_font
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.border_color = Palette.INK_SOFT
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	draw_style_box(box, tag_rect)
	var ts := font.get_string_size(tag_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, tag_fs)
	draw_string(font, Vector2(snappedf(tag_rect.position.x + 4.0, 1.0), snappedf(tag_rect.position.y + 3.0 + ts.y * 0.8, 1.0)), tag_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_fs, Palette.INK)

func get_port_count() -> int:
	return _port_specs.size()

func port_name_visible_for(idx: int) -> bool:
	return show_port_names or _hovered_port == idx

func _sstr(font: Font, pos: Vector2, text: String, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, font_size: int = 16, modulate: Color = Color(1, 1, 1, 1)) -> void:
	draw_string(font, Vector2(snappedf(pos.x, 1.0), snappedf(pos.y, 1.0)), text, alignment, width, font_size, modulate)

func _draw_blocker_icon(center: Vector2, hex_radius: float, small_font_size: int) -> void:
	var br := hex_radius * 0.26
	var shield := PackedVector2Array([
		center + Vector2(0, -br),
		center + Vector2(br * 0.85, -br * 0.45),
		center + Vector2(br * 0.65, br * 0.45),
		center + Vector2(0, br),
		center + Vector2(-br * 0.65, br * 0.45),
		center + Vector2(-br * 0.85, -br * 0.45),
	])
	draw_colored_polygon(shield, Palette.BLOCKER)
	var shield_outline := shield.duplicate()
	shield_outline.append(shield[0])
	draw_polyline(shield_outline, Palette.INK, 2.2, true)
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var b_txt := "B"
	var bt_size := font.get_string_size(b_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, small_font_size)
	_sstr(font, center + Vector2(-bt_size.x * 0.5, bt_size.y * 0.28), b_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, small_font_size, Palette.PAPER)

func animate_build_vertex(v_id: int, col: Color) -> void:
	if state == null or v_id < 0 or v_id >= HexMath.get_topology().vertex_positions.size():
		return
	for a in _build_anims:
		if int(a.get("vertex", -1)) == v_id and float(a["age"]) < 0.2:
			return
	if reduce_motion:
		_build_anims.append({"kind": "ring", "vertex": v_id, "age": 0.0, "duration": 1.5, "color": col, "static": true})
	else:
		_build_anims.append({"kind": "pop_vertex", "vertex": v_id, "age": 0.0, "duration": 0.6 * anim_scale, "color": col, "static": false, "building": int(state.vertex_building[v_id]), "seat": int(state.vertex_owner[v_id])})
	anim_count += 1

func animate_build_edge(e_id: int, col: Color) -> void:
	if state == null or e_id < 0 or e_id >= HexMath.get_topology().edge_vertices.size():
		return
	for a in _build_anims:
		if int(a.get("edge", -1)) == e_id and float(a["age"]) < 0.2:
			return
	if reduce_motion:
		_build_anims.append({"kind": "ring_edge", "edge": e_id, "age": 0.0, "duration": 1.5, "color": col, "static": true})
	else:
		_build_anims.append({"kind": "pop_edge", "edge": e_id, "age": 0.0, "duration": 0.6 * anim_scale, "color": col, "static": false})
	anim_count += 1

func animate_blocker(from_tile: int) -> void:
	if state == null or reduce_motion or from_tile < 0:
		return
	if from_tile == state.blocker_tile:
		return
	_blocker_from_tile = from_tile
	_blocker_t = 0.0
	anim_count += 1

func blocker_anim_duration() -> float:
	if reduce_motion:
		return 0.0
	return 0.9 * anim_scale

func blocker_anim_phase() -> String:
	if reduce_motion or _blocker_t >= 1.0 or _blocker_from_tile < 0:
		return ""
	if _blocker_t < 0.25:
		return "lift"
	if _blocker_t < 0.80:
		return "shift"
	return "place"

func anim_total() -> int:
	return anim_count

func _vertex_pop_active(v_id: int) -> bool:
	for a in _build_anims:
		if a["kind"] == "pop_vertex" and int(a["vertex"]) == v_id:
			return true
	return false

func _edge_pop_active(e_id: int) -> bool:
	for a in _build_anims:
		if a["kind"] == "pop_edge" and int(a["edge"]) == e_id:
			return true
	return false

func _draw_build_anims(topo: HexMath.BoardTopology, hex_radius: float) -> void:
	for a in _build_anims:
		var t := clampf(float(a["age"]) / float(a["duration"]), 0.0, 1.0)
		var col: Color = a["color"]
		if a["kind"] == "pop_edge" or a["kind"] == "ring_edge":
			var e_id := int(a["edge"])
			if e_id < 0 or e_id >= topo.edge_vertices.size():
				continue
			var ev: Vector2i = topo.edge_vertices[e_id]
			var p1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
			var p2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
			if bool(a.get("static", false)):
				draw_line(p1, p2, Color(col, 1.0 - t), max(8.0, hex_radius * 0.20), true)
				continue
			var pop := 1.0 + 0.45 * sin(PI * t)
			draw_line(p1, p2, col, max(5.0, hex_radius * 0.14) * pop, true)
			draw_arc((p1 + p2) * 0.5, hex_radius * (0.18 + 0.95 * t), 0.0, TAU, 24, Color(col, 1.0 - t), lerpf(5.0, 1.0, t), true)
			continue
		var v_id := int(a["vertex"])
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		if bool(a.get("static", false)):
			draw_arc(vp, hex_radius * 0.30, 0.0, TAU, 28, Color(col, 1.0 - t), 3.0, true)
			continue
		var k := 0.45 + 0.55 * ease(t, 2.0)
		var seat := maxi(0, int(a.get("seat", 0)))
		if int(a.get("building", GameTypes.BuildingType.SETTLEMENT)) == GameTypes.BuildingType.CITY:
			_draw_city(vp, hex_radius * 0.22 * k, col, seat)
		else:
			_draw_settlement(vp, hex_radius * 0.22 * k, col, seat)
		draw_arc(vp, hex_radius * (0.16 + 1.05 * t), 0.0, TAU, 28, Color(col, 1.0 - t), lerpf(6.0, 1.0, t), true)

func _draw_blocker_slide(topo: HexMath.BoardTopology, hex_radius: float, small_font_size: int) -> void:
	if _blocker_t >= 1.0 or _blocker_from_tile < 0:
		return
	if _blocker_from_tile >= topo.tile_centers.size() or state.blocker_tile >= topo.tile_centers.size():
		_blocker_t = 1.0
		return
	var from_c := _unit_to_screen(topo.tile_centers[_blocker_from_tile], hex_radius)
	var to_c := _unit_to_screen(topo.tile_centers[state.blocker_tile], hex_radius)
	var t := _blocker_t
	var lift_h := hex_radius * 0.35
	var pos: Vector2
	var scale_f: float
	var ground: Vector2
	if t < 0.25:
		var lu := t / 0.25
		pos = from_c + Vector2(0, -lift_h * ease(lu, 0.6))
		scale_f = lerpf(1.0, 1.15, lu)
		ground = from_c
	elif t < 0.80:
		var su := (t - 0.25) / 0.55
		var glide := ease(su, 1.6)
		pos = from_c.lerp(to_c, glide) + Vector2(0, -lift_h)
		scale_f = 1.15
		ground = from_c.lerp(to_c, glide)
	else:
		var pu := (t - 0.80) / 0.20
		var drop := ease(pu, 1.0)
		var settle := 0.0
		if pu > 0.75:
			settle = sin((pu - 0.75) / 0.25 * PI) * hex_radius * 0.04
		pos = to_c + Vector2(0, lerpf(-lift_h, 0.0, drop)) + Vector2(0, settle)
		scale_f = lerpf(1.15, 1.0, drop)
		if pu > 0.75:
			scale_f = 1.0 + sin((pu - 0.75) / 0.25 * PI) * 0.05
		ground = to_c
	var lift_frac := clampf((ground.y - pos.y) / maxf(lift_h, 0.001), 0.0, 1.2)
	if lift_frac > 0.02:
		var sh_w := hex_radius * 0.34 * lerpf(1.0, 0.55, minf(lift_frac, 1.0))
		var sh_col := Color(0.05, 0.08, 0.12, lerpf(0.35, 0.10, minf(lift_frac, 1.0)))
		draw_set_transform(ground + Vector2(0, hex_radius * 0.10), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, sh_w, sh_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_blocker_icon(pos, hex_radius * scale_f, int(round(float(small_font_size) * scale_f)))
