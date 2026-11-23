class_name BoardView
extends Control

signal vertex_clicked(vertex_id: int)
signal edge_clicked(edge_id: int)
signal tile_clicked(tile_id: int)
signal steal_target_clicked(player_id: int)
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
var _steal_targets: Array = []
var _steal_hover: int = -1
var _steal_pending_tile: int = -1
var _steal_ring_rects: Array[Rect2] = []
var _steal_tag_rects: Array[Rect2] = []
var _steal_confirm: Array = []
var _confirm_ring_rects: Array[Rect2] = []
var _confirm_tag_rects: Array[Rect2] = []
const CONFIRM_DURATION := 1.2
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
var _fit_r := 0.0
var _fit_size := Vector2.ZERO
var _fit_off_y := 0.0
var _fit_edges: Array = []
var _fit_all_edges: Array = []
var _fit_state_id := -1
var _port_badge_data: Array[Dictionary] = []
var _land_polys_screen: Array[PackedVector2Array] = []
var _hovered_port: int = -1
var show_port_names: bool = false
const HEX_STYLES: Array[String] = ["rich", "classic"]
const TOKEN_STYLES: Array[String] = ["classic", "bold", "odds"]
var hex_style := "rich":
	set(v):
		var clean := v if HEX_STYLES.has(v) else "rich"
		if hex_style == clean:
			return
		hex_style = clean
		queue_redraw()
var token_style := "classic":
	set(v):
		var clean := v if TOKEN_STYLES.has(v) else "classic"
		if token_style == clean:
			return
		token_style = clean
		queue_redraw()
var _harbour_boat_rects: Array[Rect2] = []
var _port_specs: Array[Dictionary] = []
var _layout_dirty := true
var _rest_boat_rects: Array[Rect2] = []
var _port_pill_info: Array[Dictionary] = []
var _water_vp: SubViewport = null
var _land_vp: SubViewport = null
var _water_layer: Control = null
var _land_layer: Control = null
var _static_dirty := true
var _static_state: GameState = null
var _static_style_sig := ""
var _settle_frames := 0
var _arm_pending := false
var _no_render := false
var static_bake_requests: int = 0
var _layer_rect_local := Rect2()
var _static_delta := Vector2(0.5, 0.5)
var _layer_override := Vector2(1, 1)

func _static_signature() -> String:
	return hex_style + "|" + token_style + "|" + Palette.current_style

class BoardStaticLayer extends Control:
	var view: BoardView = null
	var water := false
	func _draw() -> void:
		if view == null or not is_instance_valid(view):
			return
		if water:
			view._render_static_water(self)
		else:
			view._render_static_land(self)

const _CLOUD_DEFS: Array[Vector4] = [
	Vector4(0.08, 0.10, 1.0, 9.0),
	Vector4(0.42, 0.18, 1.25, 6.5),
	Vector4(0.70, 0.06, 0.9, 12.0),
	Vector4(0.28, 0.90, 1.1, 7.5),
	Vector4(0.86, 0.82, 1.2, 5.0),
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(320, 280)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	set_process(true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_no_render = DisplayServer.get_name() == "headless"
	if not _no_render:
		_ensure_static_layers()

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
	if not _steal_confirm.is_empty():
		for i in range(_steal_confirm.size() - 1, -1, -1):
			var ce: Dictionary = _steal_confirm[i]
			ce["age"] = float(ce["age"]) + delta
			if float(ce["age"]) >= CONFIRM_DURATION:
				_steal_confirm.remove_at(i)
		if _steal_confirm.is_empty():
			_confirm_ring_rects.clear()
			_confirm_tag_rects.clear()
		needs_redraw = true
	if not _build_anims.is_empty():
		var had_builds := true
		for i in range(_build_anims.size() - 1, -1, -1):
			var a: Dictionary = _build_anims[i]
			a["age"] = float(a["age"]) + delta
			if float(a["age"]) >= float(a["duration"]):
				_build_anims.remove_at(i)
		if _build_anims.is_empty() and had_builds:
			_static_dirty = true
		needs_redraw = true
	if _blocker_t < 1.0:
		_blocker_t = minf(1.0, _blocker_t + delta / maxf(0.05, 0.9 * anim_scale))
		if _blocker_t >= 1.0:
			_static_dirty = true
		needs_redraw = true
	if _static_state != state or _static_style_sig != _static_signature():
		_static_dirty = true
		if _no_render:
			needs_redraw = true
	if _static_dirty and not _no_render:
		needs_redraw = true
	if not _no_render:
		if _arm_pending:
			_arm_static_layers()
		if _settle_frames > 0:
			_settle_frames -= 1
			needs_redraw = true
		if _arm_pending:
			_arm_pending = false
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

func spawn_trade_toast(text: String, accent_color: Color = Palette.ACCENT_GOLD) -> void:
	_toasts.append({
		"text": text,
		"color": accent_color,
		"age": 0.0,
		"duration": 2.0,
	})
	queue_redraw()

func set_state(new_state: GameState) -> void:
	state = new_state
	_layout_dirty = true
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

func is_busy() -> bool:
	if not _steal_targets.is_empty():
		return true
	if not _steal_confirm.is_empty():
		return true
	if not _popups.is_empty() or not _toasts.is_empty() or not _build_anims.is_empty():
		return true
	if _blocker_t < 1.0:
		return true
	return (
		interaction_mode != InteractionMode.NONE
		and interaction_mode != InteractionMode.BUILD_ANY
		and (not highlighted_vertices.is_empty() or not highlighted_edges.is_empty() or not highlighted_tiles.is_empty())
	)

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
	var sid := state.get_instance_id() if state != null else -1
	if size != _fit_size or sid != _fit_state_id:
		_recompute_fit()
	return _fit_r

# Largest hex radius at which EVERY drawn feature (tiles, piers, boats, harbour
# label pills, trade badges and their ratio tags — worst case one on every
# coastal edge) fits inside the view with an 8 px margin. Also returns the
# vertical offset that balances the leftover margin top and bottom.
func _recompute_fit() -> void:
	_fit_size = size
	_fit_r = 24.0
	_fit_off_y = 0.0
	_fit_state_id = state.get_instance_id() if state != null else -1
	_layout_dirty = true
	var topo := HexMath.get_topology()
	if _fit_all_edges.is_empty():
		for e_id in topo.coastal_edges:
			var ev: Vector2i = topo.edge_vertices[e_id]
			var m: Vector2 = (topo.vertex_positions[ev.x] + topo.vertex_positions[ev.y]) * 0.5
			var tc: Vector2 = topo.tile_centers[topo.edge_tiles[e_id][0]]
			_fit_all_edges.append({"mid": m, "u": (m - tc).normalized(), "vx": ev.x, "vy": ev.y})
	_fit_edges = _fit_all_edges.duplicate()
	if state != null and state.vertex_ports.size() >= topo.vertex_positions.size():
		var real: Array = []
		for e in _fit_all_edges:
			var pa: int = int(state.vertex_ports[int(e["vx"])])
			var pb: int = int(state.vertex_ports[int(e["vy"])])
			if pa != -2 and pa == pb:
				real.append(e)
		_fit_edges = real
	if size.x < 20.0 or size.y < 20.0:
		return
	var r := 74.0
	while r >= 16.0:
		var res: Variant = _fit_ports_at(r)
		if res != null:
			_fit_r = r
			_fit_off_y = float(res)
			return
		r -= 1.0
	_fit_r = 16.0
	_fit_off_y = 0.0

# Simulates the real badge/tag placement (draw_port_labels) for the current
# ports at radius r inside the 8 px margin. Returns the vertical offset that
# balances the leftover space, or null when some port cannot be placed.
func _fit_ports_at(r: float) -> Variant:
	var topo := HexMath.get_topology()
	if topo.vertex_positions.size() == 0:
		return null
	var tiles_min_y := INF
	var tiles_max_y := -INF
	var tiles_max_x := 0.0
	for v in topo.vertex_positions:
		var vp: Vector2 = v
		tiles_min_y = minf(tiles_min_y, vp.y * r)
		tiles_max_y = maxf(tiles_max_y, vp.y * r)
		tiles_max_x = maxf(tiles_max_x, absf(vp.x) * r)
	var k := maxf(r, 43.4)
	var badge_d := maxf(24.0, r * 0.62)
	var r_c := badge_d * 0.5
	var tag_fs := maxf(11.0, badge_d * 0.30)
	var tag_fm := ThemeDB.fallback_font.get_ascent(int(tag_fs)) + absf(ThemeDB.fallback_font.get_descent(int(tag_fs)))
	var tag_h := tag_fm + 5.0
	var tag_w := 34.0
	var min_y := tiles_min_y
	var max_y := tiles_max_y
	var max_x := tiles_max_x + 60.0
	var boat_rects: Array[Rect2] = []
	var edge_data: Array = []
	for e in _fit_edges:
		var mid: Vector2 = (e["mid"] as Vector2) * r
		var u: Vector2 = e["u"]
		var boat_c := mid + u * (r * 0.73)
		var br := Rect2(boat_c + Vector2(-0.28 * k, -0.31 * k), Vector2(0.56 * k, 0.76 * k))
		boat_rects.append(br)
		edge_data.append({"mid": mid, "u": u})
		min_y = minf(min_y, br.position.y - 28.0)
		max_y = maxf(max_y, br.end.y + 28.0)
		max_x = maxf(max_x, maxf(absf(br.position.x), absf(br.end.x)) + 60.0)
	if max_y - min_y > size.y - 18.0 or max_x * 2.0 > size.x - 18.0:
		return null
	var lo := 9.0 - size.y * 0.5 - min_y
	var hi := size.y * 0.5 - 9.0 - max_y
	var off := (lo + hi) * 0.5
	var bound := Rect2(
		Vector2(9.0 - size.x * 0.5, 9.0 - size.y * 0.5 - off),
		Vector2(size.x - 18.0, size.y - 18.0)
	)
	var land_polys: Array[PackedVector2Array] = []
	for t_id in range(topo.tile_coords.size()):
		var poly := PackedVector2Array()
		for v_id in topo.tile_vertices[t_id]:
			poly.append((topo.vertex_positions[v_id] as Vector2) * r)
		land_polys.append(poly)
	var placed: Array[Rect2] = []
	for ed in edge_data:
		var mid2: Vector2 = ed["mid"]
		var u2: Vector2 = ed["u"]
		var tangent2 := Vector2(-u2.y, u2.x)
		var b_idx: int = edge_data.find(ed)
		var boat_sup := _rect_support_along(boat_rects[b_idx], u2) - mid2.dot(u2)
		var tag_gap := r_c + 3.0 + tag_h * 0.5
		var sides: Array[Vector2] = [u2, tangent2, -tangent2]
		var t0 := boat_sup + 6.0 + r_c
		var ok := false
		var ok_badge := Rect2()
		var ok_tag := Rect2()
		for slide in [0.0, 1.0, -1.0, 2.0, -2.0]:
			var t := t0
			var g := 0
			while g < 90 and t < 480.0:
				g += 1
				var c: Vector2 = mid2 + u2 * t + tangent2 * (float(slide) * r_c)
				var badge_rect := Rect2(c - Vector2(r_c, r_c), Vector2(badge_d, badge_d))
				if not bound.encloses(badge_rect):
					break
				for side in sides:
					var tc := c + side * tag_gap
					var tag_rect := Rect2(tc - Vector2(tag_w, tag_h) * 0.5, Vector2(tag_w, tag_h))
					if not bound.encloses(tag_rect):
						continue
					if _badge_zone_clear(c, r_c, tag_rect, land_polys, boat_rects, placed):
						ok = true
						ok_badge = badge_rect
						ok_tag = tag_rect
						break
				if ok:
					break
				t += 3.0
			if ok:
				break
		if not ok:
			return null
		placed.append(ok_badge)
		placed.append(ok_tag)
	return off

func _unit_to_screen(unit_pos: Vector2, hex_radius: float) -> Vector2:
	return (size * 0.5) + Vector2(0.0, _fit_off_y) + unit_pos * hex_radius

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
		return Palette.ART_LIGHT
	return Palette.resource(port_type)

func _resource_color(res: int) -> Color:
	return Palette.resource(res)

func _motif_jitter(tile_id: int, n: int) -> float:
	return float(((tile_id + 3) * (n + 5) * 7 + n * 13) % 17 - 8) / 16.0

func _draw() -> void:
	var hex_radius := _get_hex_radius()
	var board_center := size * 0.5

	var font: Font = ThemeDB.fallback_font
	var font_size: int = int(clampf(hex_radius * 0.30, 11.0, 20.0))
	var small_font_size: int = int(clampf(hex_radius * 0.19, 9.0, 11.0))

	if state == null:
		_harbour_label_rects.clear()
		_port_badge_rects.clear()
		_port_badge_data.clear()
		_harbour_boat_rects.clear()
		_port_specs.clear()
		_port_pill_info.clear()
		_layout_dirty = true
		if _static_state != null or _static_dirty:
			_static_state = null
			_static_style_sig = ""
			_static_dirty = false
			_resize_static_layers()
			_arm_pending = true
		draw_rect(Rect2(Vector2.ZERO, size), Palette.SEA)
		if font != null:
			var msg := "Configure seats in Lobby to start a match"
			var ts := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			_sstr(self, font, board_center - ts * 0.5, msg, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Palette.TEXT)
		return

	var topo := HexMath.get_topology()
	var pulse := 0.5 + 0.5 * sin(_pulse_time)

	var static_rebake := _static_state != state or _static_style_sig != _static_signature()
	if _layout_dirty or static_rebake:
		_solve_port_layout(topo, hex_radius, font)
		_static_dirty = true
	if static_rebake:
		static_bake_requests += 1
	_static_state = state
	_static_style_sig = _static_signature()
	if _no_render:
		_static_dirty = false
		_render_static_water(self)
		_draw_clouds(hex_radius)
		_draw_ports_structure(topo, hex_radius)
		_render_static_land(self)
	else:
		_resize_static_layers()
		_update_static_alignment()
		if _static_dirty:
			_static_dirty = false
			_arm_pending = true
		# Cached sea base (foam + waves), then moving clouds, then jetties/boats,
		# then the cached land layer; everything that changes per frame stays live.
		# Textures map 1:1 to device pixels (no resampling of the cached layers).
		draw_texture_rect(_water_vp.get_texture(), _layer_rect_local, false)
		_draw_clouds(hex_radius)
		_draw_ports_structure(topo, hex_radius)
		draw_texture_rect(_land_vp.get_texture(), _layer_rect_local, false)

	# 5. Highlighted Tile Ring (for PICK_BLOCKER_TILE)
	for t_id in highlighted_tiles:
		if t_id < 0 or t_id >= topo.tile_centers.size():
			continue
		var t_center := _unit_to_screen(topo.tile_centers[t_id], hex_radius)
		var is_hov := (_hovered_tile == t_id)
		var ring_r := hex_radius * (0.48 + 0.05 * pulse)
		var ring_col: Color = Color(Palette.ACCENT_GOLD, 0.95) if is_hov else Color(Palette.HIGHLIGHT, 0.55 + 0.35 * pulse)
		draw_arc(t_center, ring_r, 0.0, TAU, 36, ring_col, 4.0 if is_hov else 3.0, true)

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

	# 12. Harbour paper label pills (badges live in the cached land layer)
	if font != null:
		_draw_port_label_pills(font)

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
		p_box.bg_color = Color(Palette.CHIP_PILL_BG, 0.94 * p_alpha)
		p_box.border_color = Color(Palette.INK_SOFT, Palette.INK_SOFT.a * p_alpha)
		p_box.set_border_width_all(2)
		p_box.set_corner_radius_all(int(p_pill.y * 0.5))
		draw_style_box(p_box, p_rect)
		var p_dot_x := p_rect.position.x + 8.0 + p_dot_d * 0.5
		draw_circle(Vector2(p_dot_x, p_pos.y), p_dot_d * 0.5, p_col)
		draw_arc(Vector2(p_dot_x, p_pos.y), p_dot_d * 0.5, 0.0, TAU, 16, Color(Palette.INK_SOFT, p_alpha), 1.0, true)
		_sstr(
			self,
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
			self,
			font,
			t_center + Vector2(-t_ts.x * 0.5, t_ts.y * 0.32),
			t_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			t_font_size,
			Color(Palette.TOAST_TEXT, t_alpha)
		)

	_draw_steal_targets(topo, hex_radius, font, pulse)

func set_steal_targets(targets: Array, pending_tile: int) -> void:
	_steal_targets = targets.duplicate(true)
	if not targets.is_empty():
		clear_steal_confirmation()
	_steal_pending_tile = pending_tile
	_steal_hover = -1
	_compute_steal_layout()
	queue_redraw()

func steal_targets_showing() -> bool:
	return not _steal_targets.is_empty()

func get_steal_target_count() -> int:
	return _steal_targets.size()

# Post-steal confirmation: the chooser's ring and tag drawn on the robbed
# player's vertex for CONFIRM_DURATION seconds, then fading. Purely visual:
# never clickable, no phase or input effect (the click paths use only
# _steal_targets), and is_busy() stays true while it shows (as for the chooser).
func show_steal_confirmation(vertex_id: int, color: Color, label: String) -> void:
	if vertex_id < 0 or state == null:
		return
	_steal_confirm = [{"vertex": vertex_id, "color": color, "label": label, "age": 0.0}]
	_compute_confirm_layout()
	queue_redraw()

func steal_confirm_showing() -> bool:
	return not _steal_confirm.is_empty()

func get_steal_confirm_ring_rect() -> Rect2:
	return _confirm_ring_rects[0] if not _confirm_ring_rects.is_empty() else Rect2()

func get_steal_confirm_tag_rect() -> Rect2:
	return _confirm_tag_rects[0] if not _confirm_tag_rects.is_empty() else Rect2()

func clear_steal_confirmation() -> void:
	if _steal_confirm.is_empty():
		return
	_steal_confirm = []
	_confirm_ring_rects.clear()
	_confirm_tag_rects.clear()
	queue_redraw()

func _compute_confirm_layout() -> void:
	_confirm_ring_rects.clear()
	_confirm_tag_rects.clear()
	var tile := int(state.blocker_tile) if state != null else -1
	_compute_layout_for(_steal_confirm, tile, _confirm_ring_rects, _confirm_tag_rects)

func _compute_steal_layout() -> void:
	_steal_ring_rects.clear()
	_steal_tag_rects.clear()
	_compute_layout_for(_steal_targets, _steal_pending_tile, _steal_ring_rects, _steal_tag_rects)

func _compute_layout_for(targets: Array, pending_tile: int, ring_rects: Array[Rect2], tag_rects: Array[Rect2]) -> void:
	if targets.is_empty() or state == null:
		return
	var topo := HexMath.get_topology()
	var hex_radius := _get_hex_radius()
	var font: Font = ThemeDB.fallback_font
	var fs := int(clampf(hex_radius * 0.24, 10.0, 15.0))
	var board_center := size * 0.5
	var tile_center: Vector2 = board_center
	if pending_tile >= 0 and pending_tile < topo.tile_centers.size():
		tile_center = _unit_to_screen(topo.tile_centers[pending_tile], hex_radius)
	var occupied: Array[Rect2] = []
	for t in targets:
		var td: Dictionary = t
		var v_id := int(td.get("vertex", -1))
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			ring_rects.append(Rect2())
			tag_rects.append(Rect2())
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		var r := _steal_ring_radius(hex_radius)
		var ring_rect := Rect2(vp - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
		ring_rects.append(ring_rect)
		occupied.append(ring_rect.grow(2.0))
		var label := str(td.get("label", ""))
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs) if font != null else Vector2(60, 14)
		var tag_size := Vector2(ts.x + 16.0, ts.y + 10.0)
		var out := vp - tile_center
		if out.length() < 0.01:
			out = Vector2.UP
		out = out.normalized()
		var perp := Vector2(-out.y, out.x)
		var board_rect := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var placed := false
		var nudges: Array[Vector2] = [
			Vector2.ZERO, perp * (tag_size.y + 10.0), -perp * (tag_size.y + 10.0),
			perp * (tag_size.y + 26.0), -perp * (tag_size.y + 26.0),
			out * (tag_size.x + 20.0), Vector2(0, -(r + tag_size.y + 12.0)),
			perp * (tag_size.y * 2.0 + 30.0), -perp * (tag_size.y * 2.0 + 30.0),
		]
		for mult in [1.0, 1.28]:
			for nud in nudges:
				var center: Vector2 = vp + out * ((r + 6.0) + tag_size.x * 0.5 * mult) + nud
				if mult == 1.28 and nud != Vector2.ZERO:
					continue
				var tag_rect := Rect2(center - tag_size * 0.5, tag_size)
				if not board_rect.encloses(tag_rect):
					continue
				var hits := false
				for o in occupied:
					if tag_rect.intersects(o.grow(2.0)):
						hits = true
						break
				if hits:
					continue
				tag_rects.append(tag_rect)
				occupied.append(tag_rect.grow(2.0))
				placed = true
				break
			if placed:
				break
		if not placed:
			var center2: Vector2 = vp + out * (r + 6.0 + tag_size.x * 0.5)
			var rect2 := Rect2(center2 - tag_size * 0.5, tag_size).intersection(board_rect)
			if rect2.size.x < 10.0 or rect2.size.y < 10.0:
				rect2 = Rect2(center2, tag_size)
			tag_rects.append(rect2)
			occupied.append(rect2)

func get_steal_target_ring_rect(index: int) -> Rect2:
	if index >= 0 and index < _steal_ring_rects.size():
		return _steal_ring_rects[index]
	return Rect2()

func get_steal_target_tag_rect(index: int) -> Rect2:
	if index >= 0 and index < _steal_tag_rects.size():
		return _steal_tag_rects[index]
	return Rect2()

func _steal_ring_radius(hex_radius: float) -> float:
	return maxf(hex_radius * 0.30, 24.0)

func _steal_target_at(pos: Vector2) -> int:
	var hex_radius := _get_hex_radius()
	var r := _steal_ring_radius(hex_radius)
	for i in range(_steal_targets.size()):
		if i < _steal_ring_rects.size() and _steal_ring_rects[i].size.x > 0.0:
			var rc := _steal_ring_rects[i].get_center()
			if rc.distance_to(pos) <= r + 6.0:
				return i
		if i < _steal_tag_rects.size() and _steal_tag_rects[i].has_point(pos):
			return i
	return -1

func _draw_steal_targets(topo: HexMath.BoardTopology, hex_radius: float, font: Font, pulse: float) -> void:
	if _steal_targets.is_empty() and _steal_confirm.is_empty():
		return
	var amp := 0.0 if reduce_motion else pulse
	var fs := int(clampf(hex_radius * 0.24, 10.0, 15.0))
	for i in range(_steal_targets.size()):
		if i >= _steal_ring_rects.size() or _steal_ring_rects[i].size.x <= 0.0:
			continue
		_draw_target_entry(_steal_targets[i], _steal_ring_rects[i], _steal_tag_rects[i] if i < _steal_tag_rects.size() else Rect2(), amp, 1.0, _steal_hover == i, true, font, fs)
	for i in range(_steal_confirm.size()):
		if i >= _confirm_ring_rects.size() or _confirm_ring_rects[i].size.x <= 0.0:
			continue
		var cd: Dictionary = _steal_confirm[i]
		var age: float = float(cd.get("age", 0.0))
		var alpha := 1.0
		var fade_at := CONFIRM_DURATION * 0.7
		if age > fade_at:
			alpha = clampf(1.0 - (age - fade_at) / (CONFIRM_DURATION - fade_at), 0.0, 1.0)
		_draw_target_entry(cd, _confirm_ring_rects[i], _confirm_tag_rects[i] if i < _confirm_tag_rects.size() else Rect2(), amp, alpha, false, false, font, fs)

func _draw_target_entry(td: Dictionary, ring_rect: Rect2, tag_rect: Rect2, amp: float, alpha: float, hov: bool, show_key: bool, font: Font, fs: int) -> void:
	var vp := ring_rect.get_center()
	var r0 := _steal_ring_radius(_get_hex_radius())
	var col: Color = td.get("color", Palette.ACCENT_GOLD)
	if not reduce_motion:
		draw_arc(vp, r0 + 8.0 + amp * 4.0, 0.0, TAU, 40, Color(col.r, col.g, col.b, (0.28 + 0.22 * amp) * alpha), 2.0, true)
	draw_arc(vp, r0 + 3.0 + amp * 2.0, 0.0, TAU, 40, Color(0.05, 0.04, 0.03, 0.9 * alpha), 7.0, true)
	var ring_col: Color = col.lightened(0.35) if hov else col
	draw_arc(vp, r0 + amp * 2.0, 0.0, TAU, 40, Color(ring_col.r, ring_col.g, ring_col.b, alpha), 4.0, true)
	draw_circle(vp, r0 - 3.0, Color(col.r, col.g, col.b, 0.18 * alpha))
	var key := str(int(td.get("key", 0)))
	if show_key and font != null and key != "0":
		var kts := font.get_string_size(key, HORIZONTAL_ALIGNMENT_CENTER, -1, fs + 2)
		draw_circle(vp + Vector2(0, -r0 + 2.0), 9.0, Color(0.08, 0.06, 0.05, 0.92 * alpha))
		_sstr(
			self, font,
			vp + Vector2(0, -r0 + 2.0) + Vector2(-kts.x * 0.5, kts.y * 0.30),
			key, HORIZONTAL_ALIGNMENT_CENTER, -1, fs + 2,
			Color(1, 1, 1, 0.95 * alpha)
		)
	if tag_rect.size.x > 8.0:
		draw_rect(tag_rect, Color(0.07, 0.05, 0.04, (0.94 if not hov else 0.99) * alpha), true)
		var line_col: Color = col.lightened(0.2) if hov else col
		draw_rect(tag_rect, Color(line_col.r, line_col.g, line_col.b, alpha), false, 2.0)
		var label := str(td.get("label", ""))
		var lts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs) if font != null else Vector2.ZERO
		_sstr(
			self, font,
			tag_rect.position + Vector2((tag_rect.size.x - lts.x) * 0.5, (tag_rect.size.y + lts.y * 0.62) * 0.5),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1, alpha)
		)
	# pending hex ghost keeps its own marker (main_ui); nothing else drawn here

func _ensure_static_layers() -> void:
	if _water_vp != null:
		return
	_water_vp = SubViewport.new()
	_water_vp.transparent_bg = false
	_water_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_water_layer = BoardStaticLayer.new()
	_water_layer.water = true
	_water_layer.view = self
	_water_vp.add_child(_water_layer)
	add_child(_water_vp)
	_land_vp = SubViewport.new()
	_land_vp.transparent_bg = true
	_land_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_land_layer = BoardStaticLayer.new()
	_land_layer.view = self
	_land_vp.add_child(_land_layer)
	add_child(_land_vp)
	_static_dirty = true

func _layer_scale() -> float:
	var w := get_window()
	var vpr := get_viewport()
	if w == null or vpr == null:
		return 1.0
	var vis := vpr.get_visible_rect().size
	if vis.x <= 0.5:
		return 1.0
	return float(w.size.x) * w.content_scale_factor / vis.x

func _resize_static_layers() -> void:
	if _water_vp == null or _no_render:
		return
	var f := _layer_scale()
	var want := Vector2i((size * f).ceil())
	want.x = maxi(1, want.x)
	want.y = maxi(1, want.y)
	if _water_vp.size == want and _land_vp.size == want:
		return
	_water_vp.size = want
	_land_vp.size = want
	_layer_override = Vector2(want) / f
	_water_layer.size = size
	_land_layer.size = size
	_water_layer.scale = Vector2(f, f)
	_land_layer.scale = Vector2(f, f)
	_static_dirty = true

# Snap the cached layers' device-pixel grid onto the screen grid: the texture
# rect origin is rounded to whole device pixels and the sub-pixel residual is
# baked into the layer children's position, so cached texels sample 1:1 and
# land exactly where direct drawing would put them.
func _update_static_alignment() -> void:
	if _water_vp == null or _no_render:
		return
	var f := _layer_scale()
	var dev := global_position * f
	var delta := dev - dev.round()
	if delta != _static_delta:
		_static_delta = delta
		_static_dirty = true
		_water_layer.position = delta
		_land_layer.position = delta
	_layer_rect_local = Rect2((dev.round() - global_position * f) / f, _layer_override)
	if OS.get_environment("PERF_DEBUG") == "1":
		print("ALIGN f=", f, " size=", size, " rect=", _layer_rect_local, " delta=", delta)

func _arm_static_layers() -> void:
	if _water_vp == null:
		return
	_water_layer.queue_redraw()
	_land_layer.queue_redraw()
	_water_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_water_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_land_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_land_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_settle_frames = 2

func _render_static_water(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Palette.SEA)
	var hex_radius := _get_hex_radius()
	var board_center := size * 0.5
	ci.draw_circle(board_center, hex_radius * 4.30, Color(Palette.SEA_FOAM, 0.28))
	ci.draw_circle(board_center, hex_radius * 4.62, Color(Palette.SEA_FOAM, 0.17))
	ci.draw_circle(board_center, hex_radius * 4.95, Color(Palette.SEA_FOAM, 0.09))
	for i in range(9):
		var ang := TAU * float(i) / 9.0 + 0.35
		var radius_mult := 4.40 + float(i % 3) * 0.40
		var span := 0.34 + float((i + 1) % 3) * 0.10
		var wave_col := Color(Palette.SEA_DEEP, 0.45) if i % 2 == 0 else Color(Palette.SEA_FOAM, 0.60)
		ci.draw_arc(board_center, hex_radius * radius_mult, ang, ang + span, 12, wave_col, 2.0, true)

# p40: the header band paints nothing, and the UI asks the board to continue
# its painted sea on another canvas (_sea_band, drawn behind the whole UI).
# Translating by the board's global position puts the canvas in the board's
# own coordinate space, so the same circles and arcs are geometric
# continuations of the baked water: no seam at the board's top edge and no
# colour step at the old board/sidebar x edge inside the band. Only the base
# water is drawn - no land, clouds or fit changes; the board's layout rect,
# camera and picking are untouched.
func paint_sea_band(ci: CanvasItem) -> void:
	if _no_render or state == null or size.x <= 0.0 or size.y <= 0.0:
		return
	ci.draw_set_transform(global_position - ci.global_position, 0.0, Vector2.ONE)
	_render_static_water(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _render_static_land(ci: CanvasItem) -> void:
	if state == null:
		return
	var topo := HexMath.get_topology()
	var hex_radius := _get_hex_radius()
	var font: Font = ThemeDB.fallback_font
	var small_font_size: int = int(clampf(hex_radius * 0.19, 9.0, 11.0))

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

		if hex_style == "rich":
			_draw_tile_rich(ci, t_id, terrain, t_center, hex_radius)
		else:
			var paper_pts := PackedVector2Array()
			for c in corners:
				paper_pts.append(t_center + (c - t_center) * 1.035)
			ci.draw_colored_polygon(paper_pts, Palette.ART_LIGHT)
			ci.draw_colored_polygon(corners, base_col)
			_draw_hex_wash(ci, t_center, hex_radius, terrain)
			ci.draw_polyline(border_pts, Palette.INK_SOFT, 2.0, true)

			_draw_tile_motif(ci, t_id, terrain, t_center, hex_radius)

			# Terrain label near bottom of tile
			if font != null:
				var t_lbl := _terrain_label(terrain)
				var lbl_size := font.get_string_size(t_lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, small_font_size)
				_sstr(ci, 
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
			var tok_c := t_center
			var tl := token_layout(num, hex_radius, token_style)
			var token_r: float = float(tl["disc_r"])
			var token_font: int = int(tl["num_font"])
			var num_offset: Vector2 = tl["num_offset"]
			ci.draw_circle(tok_c + Vector2(0, hex_radius * 0.035), token_r, Palette.PAPER_SHADOW)
			ci.draw_circle(tok_c, token_r, Palette.NUMBER_TOKEN_BG)
			ci.draw_arc(tok_c, token_r, 0.0, TAU, 32, Palette.INK, 1.6, true)

			var is_hot := (num == 6 or num == 8)
			var num_col: Color = Palette.NUMBER_TOKEN_HOT if is_hot else Palette.NUMBER_TOKEN_TEXT
			if token_style == "bold" and is_hot:
				ci.draw_arc(tok_c, token_r - 2.0, 0.0, TAU, 40, Palette.NUMBER_TOKEN_HOT, 3.0, true)
			if font != null:
				var num_str := str(num)
				var n_size := font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, token_font)
				var num_pos := tok_c + Vector2(-n_size.x * 0.5, 0.0) + num_offset
				_sstr(ci, 
					font,
					num_pos,
					num_str,
					HORIZONTAL_ALIGNMENT_CENTER,
					-1,
					token_font,
					num_col
				)
				if token_style == "bold":
					_sstr(ci, font, num_pos + Vector2(0.7, 0.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, token_font, num_col)

			var pip_r: float = float(tl["pip_r"])
			var pip_col: Color = Palette.NUMBER_TOKEN_HOT if (is_hot and token_style == "bold") else num_col
			for pip_rel in (tl["pips"] as Array):
				ci.draw_circle(tok_c + (pip_rel as Vector2), pip_r, pip_col)

		# 4. Blocker Icon
		if state.blocker_tile == t_id and _blocker_t >= 1.0:
			var b_offset: Vector2 = Vector2(hex_radius * 0.02, -hex_radius * 0.06) if num > 0 else Vector2.ZERO
			_draw_blocker_icon(ci, t_center + b_offset, hex_radius, small_font_size)

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
			ci.draw_line(a + Vector2(0, hex_radius * 0.04), b + Vector2(0, hex_radius * 0.04), Palette.PAPER_SHADOW, max(8.0, hex_radius * 0.22), true)
			ci.draw_line(a, b, Palette.INK, max(8.0, hex_radius * 0.22), true)
			ci.draw_line(a, b, p_col, max(5.0, hex_radius * 0.14), true)

	# 8. Harbour ownership rings (before pieces so the piece stays visible on top)
	_draw_port_ownership_rings(ci, topo, hex_radius)

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
			_draw_settlement(ci, vp, hex_radius * 0.22, p_col, owner_id % GameTypes.PLAYER_COLORS.size())
		elif b_type == GameTypes.BuildingType.CITY:
			_draw_city(ci, vp, hex_radius * 0.28, p_col, owner_id % GameTypes.PLAYER_COLORS.size())

	# 12a. Harbour badges — on top of everything land-related, over water only
	if font != null:
		_draw_static_port_badges(ci)

func _draw_clouds(hex_radius: float) -> void:
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

func _draw_hex_wash(ci: CanvasItem, center: Vector2, r: float, terrain: int) -> void:
	var w := 0.866 * r
	var light_col := Color(Palette.terrain_light(terrain), 0.55)
	var shade_col := Color(Palette.terrain_shade(terrain), 0.60)
	ci.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-w, -0.5 * r),
		center + Vector2(0.0, -r),
		center + Vector2(w, -0.5 * r),
		center + Vector2(w, -0.12 * r),
		center + Vector2(-w, -0.12 * r),
	]), light_col)
	ci.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-w, 0.16 * r),
		center + Vector2(w, 0.16 * r),
		center + Vector2(w, 0.5 * r),
		center + Vector2(0.0, r),
		center + Vector2(-w, 0.5 * r),
	]), shade_col)

func _draw_tile_motif(ci: CanvasItem, tile_id: int, terrain: int, center: Vector2, r: float, ink_only: bool = false) -> void:
	var dark: Color = Color(Palette.terrain_shade(terrain), 0.95)
	var lite: Color = Color(Palette.terrain_light(terrain), 0.95)
	if ink_only:
		dark = Color(Palette.INK, 0.8)
		lite = Color(Palette.INK, 0.45)
	match terrain:
		GameTypes.TerrainType.FOREST:
			var xs := [-0.50, -0.17, 0.19, 0.50]
			for k in range(4):
				var tx: float = center.x + xs[k] * r * 0.78 + _motif_jitter(tile_id, k) * 0.05 * r
				var ty: float = center.y - 0.42 * r + _motif_jitter(tile_id, k + 4) * 0.05 * r
				_draw_tree(ci, Vector2(tx, ty), r * 0.95, dark, lite)
			_draw_tree(ci, Vector2(center.x - 0.42 * r, center.y + 0.40 * r), r * 0.70, dark, lite)
		GameTypes.TerrainType.PASTURE:
			ci.draw_arc(center + Vector2(-0.30 * r, -0.16 * r), 0.30 * r, PI, TAU, 12, dark, 2.2, true)
			ci.draw_arc(center + Vector2(0.28 * r, -0.22 * r), 0.22 * r, PI, TAU, 12, dark, 2.0, true)
			_draw_sheep(ci, center + Vector2(-0.34 * r, 0.40 * r), r)
			_draw_sheep(ci, center + Vector2(-0.06 * r, 0.44 * r), r * 0.85)
		GameTypes.TerrainType.FIELDS:
			for k in range(5):
				var wx: float = center.x + (-0.48 + 0.24 * float(k)) * r + _motif_jitter(tile_id, k) * 0.04 * r
				var wy: float = center.y - 0.42 * r + _motif_jitter(tile_id, k + 2) * 0.05 * r
				_draw_wheat(ci, Vector2(wx, wy), r, dark)
			for k in range(2):
				var bx: float = center.x + (0.38 + 0.16 * float(k)) * r
				_draw_wheat(ci, Vector2(bx, center.y + 0.40 * r), r * 0.9, dark)
		GameTypes.TerrainType.HILLS:
			ci.draw_arc(center + Vector2(0.0, -0.14 * r), 0.36 * r, PI, TAU, 16, dark, 2.4, true)
			ci.draw_arc(center + Vector2(0.0, -0.14 * r), 0.21 * r, PI, TAU, 12, lite, 2.0, true)
			for k in range(2):
				var bpos := center + Vector2((-0.46 + 0.20 * float(k)) * r, 0.38 * r)
				var brect := Rect2(bpos - Vector2(0.09 * r, 0.045 * r), Vector2(0.18 * r, 0.09 * r))
				ci.draw_rect(brect, dark)
				ci.draw_rect(brect, Color(Palette.INK_SOFT, 0.6), false, 1.0)
		GameTypes.TerrainType.MOUNTAINS:
			var peaks := [-0.32, 0.02, 0.34]
			for k in range(3):
				var px: float = center.x + peaks[k] * r + _motif_jitter(tile_id, k) * 0.04 * r
				var ph: float = (0.24 + float((tile_id + k) % 3) * 0.05) * r
				_draw_peak(ci, Vector2(px, center.y - 0.30 * r), ph, 0.13 * r, dark, lite)
			_draw_peak(ci, Vector2(center.x - 0.40 * r, center.y + 0.42 * r), 0.14 * r, 0.08 * r, dark, lite)
		GameTypes.TerrainType.BARREN:
			ci.draw_arc(center + Vector2(-0.22 * r, -0.24 * r), 0.34 * r, PI, TAU, 12, dark, 2.0, true)
			ci.draw_arc(center + Vector2(0.26 * r, -0.34 * r), 0.24 * r, PI, TAU, 12, lite, 1.8, true)
			var rock_pos := center + Vector2(0.40 * r, 0.40 * r)
			ci.draw_colored_polygon(PackedVector2Array([
				rock_pos + Vector2(-0.07 * r, 0.05 * r),
				rock_pos + Vector2(-0.03 * r, -0.06 * r),
				rock_pos + Vector2(0.05 * r, -0.03 * r),
				rock_pos + Vector2(0.07 * r, 0.05 * r),
			]), dark)
			ci.draw_circle(rock_pos + Vector2(0.11 * r, 0.04 * r), 0.02 * r, Palette.INK_SOFT)

func _draw_tree(ci: CanvasItem, pos: Vector2, r: float, dark: Color, lite: Color) -> void:
	ci.draw_line(pos + Vector2(0, 0.02 * r), pos + Vector2(0, 0.12 * r), Color(Palette.DOCK_WOOD, 0.95), maxf(1.5, r * 0.025), true)
	ci.draw_circle(pos - Vector2(0, 0.05 * r), 0.085 * r, dark)
	ci.draw_circle(pos - Vector2(0.025 * r, 0.075 * r), 0.04 * r, lite)

func _draw_sheep(ci: CanvasItem, pos: Vector2, r: float) -> void:
	ci.draw_circle(pos, 0.055 * r, Palette.ART_LIGHT)
	ci.draw_arc(pos, 0.055 * r, 0.0, TAU, 12, Color(Palette.ART_INK, 0.8), 1.0, true)
	ci.draw_circle(pos + Vector2(0.05 * r, -0.015 * r), 0.024 * r, Palette.ART_INK)

func _draw_wheat(ci: CanvasItem, pos: Vector2, r: float, dark: Color) -> void:
	ci.draw_line(pos + Vector2(0, 0.10 * r), pos - Vector2(0, 0.08 * r), dark, maxf(1.5, r * 0.022), true)
	ci.draw_circle(pos - Vector2(0, 0.10 * r), 0.022 * r, dark)

func _draw_peak(ci: CanvasItem, pos: Vector2, h: float, hw: float, dark: Color, lite: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		pos - Vector2(hw, 0),
		pos + Vector2(0, -h),
		pos + Vector2(hw, 0),
	]), dark)
	ci.draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-hw * 0.32, -h * 0.68),
		pos + Vector2(0, -h),
		pos + Vector2(hw * 0.32, -h * 0.68),
		pos + Vector2(hw * 0.12, -h * 0.60),
		pos - Vector2(hw * 0.10, -h * 0.66),
	]), lite)


func token_layout(num: int, hex_radius: float, style: String) -> Dictionary:
	var pips := GameTypes.pip_count(num)
	var disc_r := hex_radius * 0.30
	var num_font := int(clampf(hex_radius * 0.30, 11.0, 20.0))
	if style == "bold":
		disc_r *= 1.2
		num_font = int(float(num_font) * 1.2)
	elif style == "odds":
		var sc := 1.0
		match pips:
			5:
				sc = 1.25
			4:
				sc = 1.12
			3:
				sc = 1.0
			2:
				sc = 0.9
			1:
				sc = 0.8
		disc_r *= sc
		num_font = int(float(num_font) * sc)
	num_font = maxi(11, num_font)
	var pip_r := maxf(1.8, hex_radius * 0.032)
	var num_str := str(num)
	var font: Font = ThemeDB.fallback_font
	var text_h := float(num_font)
	if font != null:
		text_h = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, num_font).y
	var num_offset := Vector2(0.0, text_h * 0.18)
	# The chip always grows enough to carry the number legibly.
	var text_w := float(num_font)
	if font != null:
		text_w = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_CENTER, -1, num_font).x
	disc_r = maxf(disc_r, maxf(text_w * 0.5 + 2.5, float(num_font) * 0.62))
	var s := hex_radius * 0.095
	var row_y := disc_r * 0.55
	if pips > 1:
		var half := float(pips - 1) * s * 0.5
		var reach := sqrt(half * half + row_y * row_y)
		var limit := disc_r * 0.88 - pip_r - 0.05
		if reach > limit:
			var k := maxf(0.35, limit / reach)
			s *= k
			row_y *= k
	if pips > 0:
		var num_bottom := num_offset.y + text_h * 0.25
		var pip_top := row_y - pip_r
		if pip_top < num_bottom + 1.5:
			num_offset.y -= (num_bottom + 1.5) - pip_top
	var out_pips: Array[Vector2] = []
	if hex_radius >= 26.0:
		for i in range(pips):
			out_pips.append(Vector2(-float(pips - 1) * s * 0.5 + float(i) * s, row_y))
	return {"disc_r": disc_r, "num_font": num_font, "num_offset": num_offset, "pip_r": pip_r, "pips": out_pips}

func _hex_poly(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := deg_to_rad(60.0 * float(i) - 30.0)
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	return pts

func _clip_line_to_poly(a: Vector2, b: Vector2, poly: PackedVector2Array, inside_ref: Vector2) -> PackedVector2Array:
	var p0 := a
	var p1 := b
	var n := poly.size()
	for i in range(n):
		var c0: Vector2 = poly[i]
		var c1: Vector2 = poly[(i + 1) % n]
		var e := c1 - c0
		var nrm := Vector2(e.y, -e.x)
		var ref := nrm.dot(inside_ref - c0)
		var inside_sign := 1.0 if ref > 0.0 else -1.0
		var s0 := nrm.dot(p0 - c0) * inside_sign
		var s1 := nrm.dot(p1 - c0) * inside_sign
		if s0 >= 0.0 and s1 >= 0.0:
			continue
		if s0 < 0.0 and s1 < 0.0:
			return PackedVector2Array()
		var hit := p0.lerp(p1, s0 / (s0 - s1))
		if s0 < 0.0:
			p0 = hit
		else:
			p1 = hit
	if p0.distance_squared_to(p1) < 0.01:
		return PackedVector2Array()
	return PackedVector2Array([p0, p1])

func _tile_rand(tile_id: int, salt: int) -> float:
	var h := int(tile_id) * 73856093 + int(salt) * 19349663
	h = absi(h ^ (h >> 13))
	h = absi(h * 1274126177)
	h = absi(h ^ (h >> 16))
	return float(h % 1000) / 1000.0

func _terrain_resource(terrain: int) -> int:
	match terrain:
		GameTypes.TerrainType.FOREST:
			return GameTypes.ResourceType.TIMBER
		GameTypes.TerrainType.HILLS:
			return GameTypes.ResourceType.CLAY
		GameTypes.TerrainType.PASTURE:
			return GameTypes.ResourceType.FLEECE
		GameTypes.TerrainType.FIELDS:
			return GameTypes.ResourceType.GRAIN
		GameTypes.TerrainType.MOUNTAINS:
			return GameTypes.ResourceType.IRON
		_:
			return -1

func _ellipse_poly(c: Vector2, rx: float, ry: float, segs: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(maxi(14, segs)):
		var a := TAU * float(i) / float(maxi(14, segs))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _clip_shape(shape: PackedVector2Array, poly: PackedVector2Array) -> Array:
	if shape.size() < 3 or poly.size() < 3:
		return []
	var parts: Array = Geometry2D.intersect_polygons(shape, poly)
	var out: Array = []
	for part in parts:
		var pp: PackedVector2Array = part
		if pp.size() >= 3:
			out.append(pp)
	return out

func _draw_poly_clipped(ci: CanvasItem, pts: PackedVector2Array, col: Color, hexp: PackedVector2Array) -> void:
	for p in _clip_shape(pts, hexp):
		ci.draw_colored_polygon(p, col)

func _draw_quad(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, hexp: PackedVector2Array) -> void:
	var d := b - a
	if d.length_squared() < 0.0001:
		return
	var n := Vector2(-d.y, d.x).normalized() * w * 0.5
	_draw_poly_clipped(ci, PackedVector2Array([a - n, b - n, b + n, a + n]), col, hexp)

func _stroke_line(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color, hexp: PackedVector2Array) -> void:
	var seg := _clip_line_to_poly(a, b, hexp, hexp[0] + hexp[3])
	if seg.size() == 2:
		ci.draw_line(seg[0], seg[1], col, w, true)

func _shadow_ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, hexp: PackedVector2Array) -> void:
	_draw_poly_clipped(ci, _ellipse_poly(c, rx, ry), Color(0.0, 0.0, 0.0, 0.18), hexp)

func _conifer(ci: CanvasItem, pos: Vector2, sz: float, green: Color, hexp: PackedVector2Array) -> void:
	_shadow_ellipse(ci, pos + Vector2(sz * 0.35, sz * 0.98), sz * 0.55, sz * 0.16, hexp)
	_draw_poly_clipped(ci, PackedVector2Array([
		pos + Vector2(-sz * 0.09, sz * 0.95), pos + Vector2(sz * 0.09, sz * 0.95),
		pos + Vector2(sz * 0.09, sz * 0.55), pos + Vector2(-sz * 0.09, sz * 0.55),
	]), Color(0.32, 0.21, 0.11), hexp)
	_draw_poly_clipped(ci, PackedVector2Array([
		pos + Vector2(-sz * 0.85, sz * 0.62), pos + Vector2(0, -sz * 0.15), pos + Vector2(sz * 0.85, sz * 0.62),
	]), green, hexp)
	_draw_poly_clipped(ci, PackedVector2Array([
		pos + Vector2(-sz * 0.68, sz * 0.10), pos + Vector2(0, -sz * 0.85), pos + Vector2(sz * 0.68, sz * 0.10),
	]), green.lightened(0.10), hexp)
	_draw_poly_clipped(ci, PackedVector2Array([
		pos + Vector2(-sz * 0.85, sz * 0.62), pos + Vector2(0, -sz * 0.15), pos + Vector2(0, sz * 0.62),
	]), green.lightened(0.16), hexp)
	_draw_poly_clipped(ci, PackedVector2Array([
		pos + Vector2(sz * 0.0, -sz * 0.15), pos + Vector2(sz * 0.85, sz * 0.62), pos + Vector2(0, sz * 0.62),
	]), green.darkened(0.22), hexp)

func _sheep(ci: CanvasItem, pos: Vector2, sz: float, hexp: PackedVector2Array) -> void:
	_shadow_ellipse(ci, pos + Vector2(sz * 0.12, sz * 0.55), sz * 0.62, sz * 0.16, hexp)
	_draw_poly_clipped(ci, PackedVector2Array([
		pos + Vector2(-sz * 0.25, sz * 0.25), pos + Vector2(-sz * 0.12, sz * 0.25),
		pos + Vector2(-sz * 0.12, sz * 0.5), pos + Vector2(-sz * 0.25, sz * 0.5),
	]), Color(0.25, 0.2, 0.16), hexp)
	_draw_poly_clipped(ci, PackedVector2Array([
		pos + Vector2(sz * 0.12, sz * 0.25), pos + Vector2(sz * 0.25, sz * 0.25),
		pos + Vector2(sz * 0.25, sz * 0.5), pos + Vector2(sz * 0.12, sz * 0.5),
	]), Color(0.25, 0.2, 0.16), hexp)
	_draw_poly_clipped(ci, _ellipse_poly(pos, sz * 0.6, sz * 0.4), Color(0.95, 0.93, 0.88), hexp)
	_draw_poly_clipped(ci, _ellipse_poly(pos + Vector2(0, -sz * 0.12), sz * 0.45, sz * 0.22), Color(1, 1, 1, 0.45), hexp)
	_draw_poly_clipped(ci, _ellipse_poly(pos + Vector2(sz * 0.55, -sz * 0.05), sz * 0.24, sz * 0.2), Color(0.3, 0.24, 0.2), hexp)

func _draw_tile_rich(ci: CanvasItem, tile_id: int, terrain: int, center: Vector2, r: float) -> void:
	var hexp := _hex_poly(center, r)
	var base := Color(Palette.terrain(terrain))
	var ac := center.y
	# a. gradient ground: lit warm at top-left, dark cool at bottom-right
	var warm := base.lightened(0.18)
	warm.r = minf(1.0, warm.r + 0.035)
	var cool := base.darkened(0.20)
	cool.b = minf(1.0, cool.b + 0.02)
	var cols := PackedColorArray()
	for c in hexp:
		var t := clampf(0.5 + ((center.x - c.x) + (center.y - c.y)) / (r * 2.1), 0.0, 1.0)
		cols.append(warm.lerp(cool, 1.0 - t))
	ci.draw_polygon(hexp, cols)
	# b. far band: rolling ridge in a pale, desaturated tint
	var far_col := base.lerp(Color(0.82, 0.87, 0.92), 0.42)
	far_col.a = 0.85
	var ridge := PackedVector2Array()
	for i in range(9):
		var fx := center.x + (-1.15 + 2.3 * float(i) / 8.0) * r
		var fy := ac - r * (0.24 + 0.10 * sin(float(i) * 1.9 + float(tile_id)) + 0.04 * _tile_rand(tile_id, i))
		ridge.append(Vector2(fx, fy))
	ridge.append(Vector2(center.x + 1.15 * r, ac + 0.06 * r))
	ridge.append(Vector2(center.x - 1.15 * r, ac + 0.06 * r))
	_draw_poly_clipped(ci, ridge, far_col, hexp)
	# c. middle band: terrain features, lit left / shaded right, each with a soft shadow
	match terrain:
		GameTypes.TerrainType.FOREST:
			var green := base.darkened(0.05)
			var n_back := 3 + int(_tile_rand(tile_id, 1) * 2.0)
			for k in range(n_back):
				var fx := center.x + (-0.62 + 1.24 * float(k) / maxf(1.0, float(n_back - 1))) * r
				_conifer(ci, Vector2(fx, ac - 0.10 * r), r * (0.16 + 0.03 * _tile_rand(tile_id, 10 + k)), green.darkened(0.12), hexp)
			var n_front := 3 + int(_tile_rand(tile_id, 2) * 2.0)
			for k in range(n_front):
				var px := center.x + (-0.72 + 1.44 * float(k) / maxf(1.0, float(n_front - 1))) * r
				_conifer(ci, Vector2(px, ac + 0.26 * r), r * (0.24 + 0.06 * _tile_rand(tile_id, 20 + k)), green, hexp)
		GameTypes.TerrainType.HILLS:
			for tno in range(3):
				var ty := ac + (-0.26 + 0.24 * float(tno)) * r
				var band := PackedVector2Array()
				for i in range(9):
					var fx := center.x + (-1.1 + 2.2 * float(i) / 8.0) * r
					band.append(Vector2(fx, ty - 0.06 * r * sin(float(i) * 2.3 + float(tno))))
				for i in range(9):
					var gx := center.x + (1.1 - 2.2 * float(i) / 8.0) * r
					band.append(Vector2(gx, ty + 0.12 * r - 0.05 * r * sin(float(i) * 1.7 + tno)))
				_draw_poly_clipped(ci, band, base.darkened(0.04 * float(tno)).lerp(Color(0.55, 0.3, 0.18), 0.18 * float(tno)), hexp)
			var kx := center.x - 0.42 * r
			var ky := ac + 0.30 * r
			_shadow_ellipse(ci, Vector2(kx + 0.10 * r, ky + 0.16 * r), 0.30 * r, 0.08 * r, hexp)
			for row in range(3):
				for col in range(2 - (row % 2)):
					var bx := kx + (float(col) * 0.24 - 0.10) * r + (0.06 * r if row % 2 == 1 else 0.0)
					var by := ky - float(row) * 0.13 * r
					var blk := Rect2(Vector2(bx, by), Vector2(0.2 * r, 0.11 * r))
					_draw_poly_clipped(ci, PackedVector2Array([
						blk.position, Vector2(blk.end.x, blk.position.y), blk.end, Vector2(blk.position.x, blk.end.y),
					]), Color(0.66, 0.34, 0.22), hexp)
					_draw_poly_clipped(ci, PackedVector2Array([
						blk.position, Vector2(blk.end.x, blk.position.y),
						Vector2(blk.end.x - 0.04 * r, blk.position.y + 0.03 * r), Vector2(blk.position.x + 0.04 * r, blk.position.y + 0.03 * r),
					]), Color(0.9, 0.6, 0.45), hexp)
		GameTypes.TerrainType.PASTURE:
			_draw_poly_clipped(ci, _ellipse_poly(Vector2(center.x - 0.42 * r, ac + 0.18 * r), 0.62 * r, 0.34 * r), base.lightened(0.05), hexp)
			_draw_poly_clipped(ci, _ellipse_poly(Vector2(center.x + 0.46 * r, ac + 0.10 * r), 0.55 * r, 0.3 * r), base.darkened(0.06), hexp)
			_stroke_line(ci, Vector2(center.x - 0.9 * r, ac + 0.14 * r), Vector2(center.x + 0.05 * r, ac - 0.12 * r), 1.6, Color(1, 1, 0.9, 0.45), hexp)
			for k in range(4):
				var wx := center.x + (-0.55 + 0.36 * float(k)) * r
				_draw_quad(ci, Vector2(wx, ac + 0.02 * r), Vector2(wx, ac - 0.16 * r), 0.03 * r, Color(0.4, 0.3, 0.18), hexp)
			_draw_quad(ci, Vector2(center.x - 0.55 * r, ac - 0.11 * r), Vector2(center.x + 0.53 * r, ac - 0.11 * r), 0.02 * r, Color(0.45, 0.34, 0.2), hexp)
			for k in range(3):
				var sx := center.x + (-0.55 + 0.5 * float(k) + 0.08 * _tile_rand(tile_id, 5 + k)) * r
				_sheep(ci, Vector2(sx, ac + 0.38 * r + 0.04 * r * _tile_rand(tile_id, 9 + k)), r * 0.13, hexp)
		GameTypes.TerrainType.FIELDS:
			var vy := ac - 0.30 * r
			for k in range(6):
				var x0 := center.x + (-0.9 + 0.3 * float(k)) * r
				var x1 := center.x + (-0.9 + 0.3 * float(k + 1)) * r
				var vx0 := center.x + (-0.28 + 0.112 * float(k)) * r
				var vx1 := center.x + (-0.28 + 0.112 * float(k + 1)) * r
				var col := base.lightened(0.10) if k % 2 == 0 else base.darkened(0.08)
				_draw_poly_clipped(ci, PackedVector2Array([
					Vector2(x0, ac + 0.55 * r), Vector2(x1, ac + 0.55 * r),
					Vector2(vx1, vy), Vector2(vx0, vy),
				]), col, hexp)
			_draw_quad(ci, Vector2(center.x - 0.9 * r, vy), Vector2(center.x + 0.9 * r, vy), 0.045 * r, Color(0.2, 0.34, 0.16), hexp)
			for k in range(2):
				var hx := center.x + (-0.35 + 0.7 * float(k)) * r
				var hy := ac + 0.16 * r
				_shadow_ellipse(ci, Vector2(hx + 0.08 * r, hy + 0.2 * r), 0.2 * r, 0.06 * r, hexp)
				_draw_poly_clipped(ci, _ellipse_poly(Vector2(hx, hy), 0.17 * r, 0.13 * r), base.lightened(0.22), hexp)
				_draw_poly_clipped(ci, _ellipse_poly(Vector2(hx - 0.05 * r, hy - 0.04 * r), 0.1 * r, 0.08 * r), Color(1, 0.95, 0.7, 0.5), hexp)
		GameTypes.TerrainType.MOUNTAINS:
			var rock := base.lerp(Color(0.45, 0.48, 0.55), 0.55)
			for k in range(3):
				var pkx := center.x + (-0.5 + 0.5 * float(k) + 0.1 * _tile_rand(tile_id, 3 + k)) * r
				var ph := (0.52 + 0.18 * _tile_rand(tile_id, 13 + k)) * r
				var hw := (0.42 + 0.1 * _tile_rand(tile_id, 23 + k)) * r
				var by0 := ac + 0.34 * r
				var apex := Vector2(pkx, by0 - ph)
				_draw_poly_clipped(ci, PackedVector2Array([Vector2(pkx - hw, by0), apex, Vector2(pkx, by0)]), rock.lightened(0.14), hexp)
				_draw_poly_clipped(ci, PackedVector2Array([apex, Vector2(pkx + hw, by0), Vector2(pkx, by0)]), rock.darkened(0.18), hexp)
				if ph > 0.6 * r:
					_draw_poly_clipped(ci, PackedVector2Array([
						apex + Vector2(-hw * 0.22, ph * 0.22), apex + Vector2(hw * 0.05, ph * 0.1), apex + Vector2(hw * 0.24, ph * 0.24),
					]), Color(0.94, 0.96, 0.98), hexp)
				for s in range(2):
					_stroke_line(ci, apex + Vector2(hw * (0.12 + 0.2 * float(s)), ph * 0.45), apex + Vector2(hw * (0.3 + 0.2 * float(s)), ph * 0.8), 1.0, Color(0, 0, 0, 0.2), hexp)
			var mx := center.x + (0.3 - 0.6 * _tile_rand(tile_id, 33)) * r
			var my := ac + 0.36 * r
			_draw_poly_clipped(ci, _ellipse_poly(Vector2(mx, my), 0.11 * r, 0.09 * r), Color(0.2, 0.16, 0.14), hexp)
			_draw_poly_clipped(ci, _ellipse_poly(Vector2(mx, my - 0.02 * r), 0.075 * r, 0.06 * r), Color(0.06, 0.05, 0.05), hexp)
		GameTypes.TerrainType.BARREN:
			for k in range(3):
				var dy := ac + (-0.12 + 0.22 * float(k)) * r
				var crest := PackedVector2Array()
				for i in range(9):
					var fx := center.x + (-1.1 + 2.2 * float(i) / 8.0) * r
					crest.append(Vector2(fx, dy - 0.1 * r * sin(float(i) * 1.4 + 2.2 * float(k))))
				for i in range(9):
					var gx := center.x + (1.1 - 2.2 * float(i) / 8.0) * r
					crest.append(Vector2(gx, dy + 0.11 * r - 0.08 * r * sin(float(i) * 1.4 + 2.2 * float(k))))
				_draw_poly_clipped(ci, crest, base.lightened(0.12 - 0.07 * float(k)), hexp)
				var slip := PackedVector2Array()
				for i in range(9):
					var hx := center.x + (1.1 - 2.2 * float(i) / 8.0) * r
					slip.append(Vector2(hx, dy + 0.11 * r - 0.08 * r * sin(float(i) * 1.4 + 2.2 * float(k))))
				for i in range(9):
					var gx2 := center.x + (1.1 - 2.2 * float(i) / 8.0) * r
					slip.append(Vector2(gx2, dy + 0.2 * r - 0.08 * r * sin(float(i) * 1.4 + 2.2 * float(k))))
				_draw_poly_clipped(ci, slip, base.darkened(0.14 + 0.03 * float(k)), hexp)
			for k in range(3):
				var rx2 := center.x + (-0.5 + 0.5 * float(k) + 0.1 * _tile_rand(tile_id, 41 + k)) * r
				var ry2 := ac + 0.42 * r
				_shadow_ellipse(ci, Vector2(rx2 + 0.04 * r, ry2 + 0.05 * r), 0.07 * r, 0.022 * r, hexp)
				_draw_poly_clipped(ci, _ellipse_poly(Vector2(rx2, ry2), 0.05 * r, 0.036 * r), Color(0.5, 0.46, 0.4), hexp)
	# d. foreground strip with short strokes for depth
	var fg := PackedVector2Array()
	for i in range(6):
		var a: Vector2 = hexp[i]
		if a.y > center.y + 0.18 * r:
			fg.append(a)
		else:
			fg.append(Vector2(a.x, center.y + maxf(0.3 * r, (a.y - center.y))))
	_draw_poly_clipped(ci, fg, Color(0.06, 0.08, 0.05, 0.30), hexp)
	for k in range(7):
		var tx := center.x + (-0.8 + 0.27 * float(k) + 0.08 * _tile_rand(tile_id, 51 + k)) * r
		var ty0 := center.y + (0.44 + 0.1 * _tile_rand(tile_id, 61 + k)) * r
		_stroke_line(ci, Vector2(tx, ty0), Vector2(tx + (0.05 - 0.1 * _tile_rand(tile_id, 71 + k)) * r, ty0 - 0.08 * r), 1.4, Color(0.1, 0.12, 0.08, 0.55), hexp)
	# e. finish: inner vignette, top-left highlight, dark outline
	for i in range(6):
		var a: Vector2 = hexp[i]
		var b: Vector2 = hexp[(i + 1) % 6]
		var ai := center + (a - center) * 0.88
		var bi := center + (b - center) * 0.88
		ci.draw_polygon(
			PackedVector2Array([a, b, bi, ai]),
			PackedColorArray([Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.22), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)])
		)
	for i in range(6):
		var ha: Vector2 = hexp[i]
		var hb: Vector2 = hexp[(i + 1) % 6]
		var hm := (ha + hb) * 0.5
		if hm.x < center.x and hm.y <= center.y:
			ci.draw_line(ha, hb, Color(1.0, 0.98, 0.9, 0.5), 1.5, true)
	var ring := hexp.duplicate()
	ring.append(hexp[0])
	ci.draw_polyline(ring, Color(Palette.INK, 0.8), 2.0, true)

func _draw_ports_structure(topo: HexMath.BoardTopology, hex_radius: float) -> void:
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
	draw_polyline(hull_outline, Palette.ART_INK, 1.5, true)
	draw_line(pos + Vector2(0, 0.10 * k), pos + Vector2(0, -0.30 * k), Palette.ART_INK, 1.4, true)
	var sail_col: Color = Palette.ART_LIGHT if port_type == GameTypes.PortType.GENERIC_3_TO_1 else Palette.resource(port_type).lightened(0.35)
	var mainsail := PackedVector2Array([
		pos + Vector2(0.02 * k, -0.30 * k),
		pos + Vector2(0.02 * k, 0.08 * k),
		pos + Vector2(0.25 * k, 0.08 * k),
	])
	draw_colored_polygon(mainsail, sail_col)
	var mainsail_outline := mainsail.duplicate()
	mainsail_outline.append(mainsail[0])
	draw_polyline(mainsail_outline, Palette.ART_INK, 1.5, true)
	var jib := PackedVector2Array([
		pos + Vector2(-0.02 * k, -0.17 * k),
		pos + Vector2(-0.02 * k, 0.06 * k),
		pos + Vector2(-0.145 * k, 0.06 * k),
	])
	draw_colored_polygon(jib, sail_col)
	var jib_outline := jib.duplicate()
	jib_outline.append(jib[0])
	draw_polyline(jib_outline, Palette.ART_INK, 1.5, true)
	draw_line(pos + Vector2(-0.15 * k, 0.36 * k), pos + Vector2(0.15 * k, 0.36 * k), Color(Palette.SEA_FOAM, 0.9), 1.6, true)
	draw_line(pos + Vector2(-0.07 * k, 0.42 * k), pos + Vector2(0.07 * k, 0.42 * k), Color(Palette.SEA_FOAM, 0.7), 1.4, true)

func _solve_port_layout(topo: HexMath.BoardTopology, hex_radius: float, font: Font) -> void:
	_layout_dirty = false
	_harbour_label_rects.clear()
	_port_badge_rects.clear()
	_port_badge_data.clear()
	_port_pill_info.clear()
	_rest_boat_rects.clear()
	_land_polys_screen.clear()
	if state == null or state.vertex_ports.size() < topo.vertex_positions.size():
		return
	var specs: Array[Dictionary] = []
	var port_index := 0
	for e_id in topo.coastal_edges:
		var ev: Vector2i = topo.edge_vertices[e_id]
		var p_a: int = state.vertex_ports[ev.x]
		var p_b: int = state.vertex_ports[ev.y]
		if p_a == -2 or p_a != p_b:
			continue
		var v1 := _unit_to_screen(topo.vertex_positions[ev.x], hex_radius)
		var v2 := _unit_to_screen(topo.vertex_positions[ev.y], hex_radius)
		var mid: Vector2 = (v1 + v2) * 0.5
		var t_center := _unit_to_screen(topo.tile_centers[topo.edge_tiles[e_id][0]], hex_radius)
		var outward := (mid - t_center).normalized()
		var tangent := Vector2(-outward.y, outward.x)
		var rest_pos: Vector2 = mid + outward * (hex_radius * 0.73)
		_rest_boat_rects.append(_boat_rect(rest_pos, hex_radius))
		specs.append({
			"boat_index": port_index,
			"boat_pos": rest_pos,
			"tangent": tangent,
			"port_type": p_a,
			"mid": mid,
			"outward": outward,
		})
		port_index += 1
	if specs.is_empty() or size.x < 10.0 or size.y < 10.0:
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
	var bound := Rect2(Vector2.ZERO, size).grow(-9.0)
	var gap := 4.0
	for spec in specs:
		var port_type: int = int(spec["port_type"])
		var boat_pos: Vector2 = spec["boat_pos"]
		var tangent: Vector2 = spec["tangent"]
		var boat_index: int = int(spec["boat_index"])
		var boat_rect: Rect2 = _rest_boat_rects[boat_index]
		var badge_d := maxf(24.0, hex_radius * 0.62)
		var r_c: float = badge_d * 0.5
		var tag_fs := maxi(11, int(badge_d * 0.30))
		var tag_txt := "3:1" if port_type == GameTypes.PortType.GENERIC_3_TO_1 else "2:1"
		var tag_ts := font.get_string_size(tag_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, tag_fs)
		var tag_w: float = tag_ts.x + 8.0
		var tag_fm := font.get_ascent(tag_fs) + absf(font.get_descent(tag_fs))
		var tag_h: float = tag_fm + 5.0
		var mid: Vector2 = spec["mid"]
		var u: Vector2 = spec["outward"]
		var boat_sup: float = _rect_support_along(boat_rect, u) - mid.dot(u)
		var tag_gap: float = r_c + 3.0 + tag_h * 0.5
		var sides: Array[Vector2] = [u, tangent, -tangent]
		var chosen_c := Vector2.INF
		var chosen_tag := Rect2()
		var t0 := boat_sup + 6.0 + r_c
		# March outward; when the sea lane is crowded, slide along the coast
		# tangent so neighbouring ports separate instead of stacking badges.
		for slide in [0.0, 1.0, -1.0, 2.0, -2.0]:
			var t := t0
			var guard_n := 0
			while guard_n < 90 and t < 480.0:
				guard_n += 1
				var c: Vector2 = mid + u * t + tangent * (float(slide) * r_c)
				var badge_rect := Rect2(c - Vector2(r_c, r_c), Vector2(badge_d, badge_d))
				if not bound.encloses(badge_rect):
					break
				for side in sides:
					var tc := c + side * tag_gap
					var tag_rect := Rect2(tc - Vector2(tag_w, tag_h) * 0.5, Vector2(tag_w, tag_h))
					if not bound.encloses(tag_rect):
						continue
					if _badge_zone_clear(c, r_c, tag_rect, land_polys, _rest_boat_rects, placed_badges):
						chosen_c = c
						chosen_tag = tag_rect
						break
				if chosen_c != Vector2.INF:
					break
				t += 3.0
			if chosen_c != Vector2.INF:
				break
		if chosen_c == Vector2.INF:
			for slide2 in [0.0, 1.0, -1.0, 2.0, -2.0, 3.0, -3.0]:
				var t2 := t0
				var guard2 := 0
				while guard2 < 90 and t2 < 480.0:
					guard2 += 1
					var c2: Vector2 = mid + u * t2 + tangent * (float(slide2) * r_c)
					var badge2 := Rect2(c2 - Vector2(r_c, r_c), Vector2(badge_d, badge_d))
					if not bound.encloses(badge2):
						break
					for side2 in sides:
						var tc2 := c2 + side2 * tag_gap
						var tag2 := Rect2(tc2 - Vector2(tag_w, tag_h) * 0.5, Vector2(tag_w, tag_h))
						if not bound.encloses(tag2):
							continue
						var clash := false
						for pr in placed_badges:
							if tag2.grow(2.0).intersects(pr) or _rect_circle_overlap(pr, c2, r_c + 2.0):
								clash = true
								break
						if not clash:
							chosen_c = c2
							chosen_tag = tag2
							break
					if chosen_c != Vector2.INF:
						break
					t2 += 3.0
				if chosen_c != Vector2.INF:
					break
		if chosen_c == Vector2.INF:
			var c3 := mid + u * (boat_sup + 6.0 + r_c)
			c3.x = clampf(c3.x, bound.position.x + r_c, bound.end.x - r_c)
			c3.y = clampf(c3.y, bound.position.y + r_c, bound.end.y - r_c)
			chosen_c = c3
			var best_tag := Rect2()
			var best_clash := 1000
			for side3 in sides:
				var tc3 := c3 + side3 * tag_gap
				var tag3 := _clamp_rect(Rect2(tc3 - Vector2(tag_w, tag_h) * 0.5, Vector2(tag_w, tag_h)), bound)
				var clash3 := 0
				for pr3 in placed_badges:
					if tag3.intersects(pr3):
						clash3 += 1
				if clash3 < best_clash:
					best_clash = clash3
					best_tag = tag3
				if clash3 == 0:
					break
			chosen_tag = best_tag if best_clash < 1000 else _clamp_rect(Rect2((c3 + u * tag_gap) - Vector2(tag_w, tag_h) * 0.5, Vector2(tag_w, tag_h)), bound)
		placed_badges.append(Rect2(chosen_c - Vector2(r_c, r_c), Vector2(badge_d, badge_d)))
		placed_badges.append(chosen_tag)
		_port_badge_rects.append(Rect2(chosen_c - Vector2(r_c, r_c), Vector2(badge_d, badge_d)))
		_port_badge_data.append({
			"center": chosen_c,
			"r": r_c,
			"tag_rect": chosen_tag,
			"boat_rect": boat_rect,
			"tag_fs": tag_fs,
			"tag_txt": tag_txt,
			"badge_d": badge_d,
			"port_type": port_type,
		})
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
		var pill_avoid: Array[Rect2] = []
		pill_avoid.append_array(placed)
		pill_avoid.append_array(placed_badges)
		for c in cands:
			var rect := _clamp_rect(Rect2(c - pill * 0.5, pill), bound)
			if _label_hits(rect, land_polys, _rest_boat_rects, pill_avoid):
				continue
			chosen = rect
			found = true
			break
		if not found:
			chosen = _clamp_rect(Rect2(first - pill * 0.5, pill), bound)
		placed.append(chosen)
		_harbour_label_rects.append(chosen)
		_port_pill_info.append({"rect": chosen, "fs": fs, "port_type": port_type})

func _draw_static_port_badges(ci: CanvasItem) -> void:
	for bd in _port_badge_data:
		_draw_port_badge(ci, bd["center"], bd["badge_d"], bd["port_type"], bd["tag_rect"], bd["tag_txt"], bd["tag_fs"])

func _draw_port_label_pills(font: Font) -> void:
	for i in range(_port_pill_info.size()):
		if _hovered_port == i or show_port_names:
			var info: Dictionary = _port_pill_info[i]
			_draw_port_label_pill(info["rect"], font, info["fs"], info["port_type"])

func _label_hits(rect: Rect2, land_polys: Array[PackedVector2Array], boats: Array[Rect2], placed: Array[Rect2]) -> bool:
	var rect_poly := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	for poly in land_polys:
		if _convex_polygons_intersect(rect_poly, poly):
			return true
	for boat in boats:
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
	box.bg_color = Palette.CHIP_PILL_BG
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
	_sstr(self, 
		font,
		Vector2(text_left, text_cy + text_ts.y * 0.32),
		lbl,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		fs,
		Palette.INK
	)

func _draw_port_ownership_rings(ci: CanvasItem, topo: HexMath.BoardTopology, hex_radius: float) -> void:
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
			ci.draw_arc(vp, ring_r, 0.0, TAU, 32, Color(p_col, 0.95), 2.5, true)
			ci.draw_arc(vp, ring_r + 2.0, 0.0, TAU, 32, Color(Palette.INK_SOFT, 0.9), 1.0, true)

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
			_draw_settlement(self, vp, hex_radius * 0.22, Color(p_col, 0.55), cur_seat)
			draw_arc(vp, 8.0, 0.0, TAU, 24, Color(Palette.ACCENT_GOLD, 1.0), 2.0, true)
		else:
			draw_circle(vp, 7.0, Palette.ART_LIGHT)
			draw_arc(vp, 7.0, 0.0, TAU, 24, Color(Palette.ACCENT_GOLD, ring_alpha), 2.0, true)
			draw_arc(vp, 8.9, 0.0, TAU, 24, Color(Palette.ART_INK, 0.95), 1.6, true)
	for v_id in highlighted_city_vertices:
		if v_id < 0 or v_id >= topo.vertex_positions.size():
			continue
		var vp := _unit_to_screen(topo.vertex_positions[v_id], hex_radius)
		if _hovered_city_vertex == v_id:
			draw_circle(vp, 12.0, Color(Palette.ACCENT_GOLD, 0.40))
			_draw_city(self, vp, hex_radius * 0.28, Color(p_col, 0.55), cur_seat)
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
			_draw_city(self, spot, hex_radius * 0.28, Color(p_col, 0.85), cur_seat)
		else:
			_draw_settlement(self, spot, hex_radius * 0.22, Color(p_col, 0.85), cur_seat)
		var pulse_r := hex_radius * (0.30 + 0.035 * sin(_ambient_time * 3.5))
		draw_arc(spot, pulse_r + 2.6, 0.0, TAU, 32, Color(Palette.ART_INK, 0.95), 1.6, true)
		draw_arc(spot, pulse_r, 0.0, TAU, 32, Palette.ART_LIGHT, 3.6, true)
		draw_arc(spot, pulse_r, 0.0, TAU, 32, Color(Palette.ACCENT_GOLD, 0.95), 2.2, true)

func _draw_city_chevron(vp: Vector2, r: float) -> void:
	var badge_c := vp + Vector2(0.0, -maxf(15.0, r * 0.42))
	draw_arc(badge_c, 9.2, 0.0, TAU, 20, Color(Palette.ART_INK, 0.95), 1.6, true)
	draw_circle(badge_c, 8.0, Palette.ART_LIGHT)
	draw_arc(badge_c, 8.0, 0.0, TAU, 20, Color(Palette.ART_INK, 0.9), 1.4, true)
	var chevron := PackedVector2Array([
		badge_c + Vector2(-3.6, 1.9),
		badge_c + Vector2(0.0, -2.1),
		badge_c + Vector2(3.6, 1.9),
	])
	draw_polyline(chevron, Palette.ACCENT_GOLD, 2.4, true)

func _draw_settlement(ci: CanvasItem, center: Vector2, r: float, col: Color, seat: int) -> void:
	ci.draw_circle(center + Vector2(0, r * 0.35), r * 0.95, Palette.PAPER_SHADOW)
	var poly := PackedVector2Array([
		center + Vector2(0, -r * 1.15),
		center + Vector2(r * 0.95, -r * 0.2),
		center + Vector2(r * 0.8, r * 0.95),
		center + Vector2(-r * 0.8, r * 0.95),
		center + Vector2(-r * 0.95, -r * 0.2),
	])
	ci.draw_colored_polygon(poly, col)
	var outline := poly.duplicate()
	outline.append(poly[0])
	ci.draw_polyline(outline, Palette.INK, 2.2, true)
	_draw_seat_mark(ci, center, r, seat)

func _draw_city(ci: CanvasItem, center: Vector2, r: float, col: Color, seat: int) -> void:
	ci.draw_circle(center + Vector2(0, r * 0.30), r * 1.05, Palette.PAPER_SHADOW)
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
	ci.draw_colored_polygon(poly, col)
	var outline := poly.duplicate()
	outline.append(poly[0])
	ci.draw_polyline(outline, Palette.INK, 2.5, true)
	_draw_seat_mark(ci, center, r, seat)

func _draw_seat_mark(ci: CanvasItem, center: Vector2, r: float, seat: int) -> void:
	match seat:
		1:
			ci.draw_circle(center + Vector2(0, r * 0.25), r * 0.22, Palette.ART_LIGHT)
			ci.draw_arc(center + Vector2(0, r * 0.25), r * 0.22, 0.0, TAU, 12, Palette.ART_INK, 1.1, true)
		2:
			var stripe := Rect2(center + Vector2(-r * 0.62, r * 0.08), Vector2(r * 1.24, r * 0.30))
			ci.draw_rect(stripe, Palette.ART_LIGHT)
			ci.draw_rect(stripe, Palette.ART_INK, false, 1.1)
		3:
			ci.draw_arc(center + Vector2(0, r * 0.20), r * 0.36, 0.0, TAU, 16, Palette.ART_LIGHT, 3.0, true)
			ci.draw_arc(center + Vector2(0, r * 0.20), r * 0.36, 0.0, TAU, 16, Palette.ART_INK, 1.1, true)
		_:
			pass

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	var topo := HexMath.get_topology()
	var hex_radius := _get_hex_radius()

	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		var new_steal := _steal_target_at(pos)
		if new_steal != _steal_hover:
			_steal_hover = new_steal
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
		if not _steal_targets.is_empty():
			var st_i := _steal_target_at(pos)
			if st_i >= 0:
				steal_target_clicked.emit(int((_steal_targets[st_i] as Dictionary).get("pid", -1)))
				accept_event()
				return
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
	if _steal_hover >= 0:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		return
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

func port_tag_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for d in _port_badge_data:
		out.append(d["tag_rect"])
	return out

func port_badge_rects() -> Array[Rect2]:
	return _port_badge_rects.duplicate()


func _draw_port_badge(ci: CanvasItem, center: Vector2, d: float, port_type: int, tag_rect: Rect2, tag_txt: String, tag_fs: int) -> void:
	var r := d * 0.5
	ci.draw_circle(center, r, Palette.CHIP_PILL_BG)
	ci.draw_arc(center, r, 0.0, TAU, 28, Palette.INK_SOFT, 1.8, true)
	var is_generic: bool = port_type == GameTypes.PortType.GENERIC_3_TO_1
	var er := Rect2(center - Vector2(r, r) * 0.70, Vector2(r, r) * 1.40)
	if is_generic:
		CardFace.draw_emblem(ci, "mixed", 0, er)
	else:
		CardFace.draw_emblem(ci, "resource", port_type, er)
	var font := ThemeDB.fallback_font
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.CHIP_PILL_BG
	box.border_color = Palette.INK_SOFT
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	ci.draw_style_box(box, tag_rect)
	var fm := font.get_ascent(tag_fs) + absf(font.get_descent(tag_fs))
	var base_y := tag_rect.position.y + (tag_rect.size.y - fm) * 0.5 + font.get_ascent(tag_fs)
	ci.draw_string(font, Vector2(snappedf(tag_rect.position.x + 4.0, 1.0), snappedf(base_y, 1.0)), tag_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_fs, Palette.INK)

func get_port_count() -> int:
	return _port_specs.size()

func port_name_visible_for(idx: int) -> bool:
	return show_port_names or _hovered_port == idx

func _sstr(ci: CanvasItem, font: Font, pos: Vector2, text: String, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, font_size: int = 16, modulate: Color = Color(1, 1, 1, 1)) -> void:
	ci.draw_string(font, Vector2(snappedf(pos.x, 1.0), snappedf(pos.y, 1.0)), text, alignment, width, font_size, modulate)

func _draw_blocker_icon(ci: CanvasItem, center: Vector2, hex_radius: float, _small_font_size: int) -> void:
	# A hooded highwayman standing 1.25 chip-diameters tall: flared bell cloak,
	# pointed cowl with warm eyes, tan road sack, wooden base.
	var u := hex_radius
	var ink := Palette.INK
	var lw := clampf(u * 0.045, 1.4, 2.6)
	var cloak := Color(0.255, 0.24, 0.36)
	var cloak_lit := Color(0.37, 0.35, 0.5)
	var cloak_dark := Color(0.18, 0.17, 0.28)
	var hood := Color(0.29, 0.275, 0.41)
	var face := Color(0.085, 0.075, 0.13)
	var eye := Color(0.98, 0.83, 0.45)
	var sack := Color(0.78, 0.64, 0.42)
	var strap := Color(0.42, 0.31, 0.2)
	var wood := Color(0.55, 0.42, 0.28)
	var wood_lit := Color(0.66, 0.52, 0.36)
	var rim := Color(0.32, 0.24, 0.15)
	# ground shadow
	ci.draw_colored_polygon(_ellipse_poly(center + Vector2(0, u * 0.305), u * 0.235, u * 0.07, 14), Color(0.05, 0.04, 0.03, 0.12))
	# round wooden base
	ci.draw_colored_polygon(_ellipse_poly(center + Vector2(0, u * 0.255), u * 0.21, u * 0.08, 16), wood)
	ci.draw_colored_polygon(_ellipse_poly(center + Vector2(0, u * 0.24), u * 0.165, u * 0.05, 14), wood_lit)
	var base_rim := _ellipse_poly(center + Vector2(0, u * 0.255), u * 0.21, u * 0.08, 16)
	base_rim.append(base_rim[0])
	ci.draw_polyline(base_rim, rim, lw * 0.8, true)
	# bell cloak: narrow shoulders flaring to a wide hem
	var bell := PackedVector2Array([
		center + Vector2(-0.13 * u, -0.24 * u),
		center + Vector2(-0.185 * u, -0.10 * u),
		center + Vector2(-0.24 * u, 0.06 * u),
		center + Vector2(-0.3 * u, 0.24 * u),
		center + Vector2(0, 0.27 * u),
		center + Vector2(0.3 * u, 0.24 * u),
		center + Vector2(0.24 * u, 0.06 * u),
		center + Vector2(0.185 * u, -0.10 * u),
		center + Vector2(0.13 * u, -0.24 * u),
		center + Vector2(0, -0.26 * u),
	])
	ci.draw_colored_polygon(bell, cloak)
	if u >= 32.0:
		# warm light down the left edge, shade on the right
		var lit := PackedVector2Array([
			center + Vector2(-0.122 * u, -0.225 * u),
			center + Vector2(-0.172 * u, -0.095 * u),
			center + Vector2(-0.226 * u, 0.065 * u),
			center + Vector2(-0.284 * u, 0.235 * u),
			center + Vector2(-0.244 * u, 0.24 * u),
			center + Vector2(-0.19 * u, 0.07 * u),
			center + Vector2(-0.136 * u, -0.09 * u),
			center + Vector2(-0.092 * u, -0.21 * u),
		])
		ci.draw_colored_polygon(lit, cloak_lit)
		var dark := PackedVector2Array([
			center + Vector2(0.122 * u, -0.225 * u),
			center + Vector2(0.172 * u, -0.095 * u),
			center + Vector2(0.226 * u, 0.065 * u),
			center + Vector2(0.284 * u, 0.235 * u),
			center + Vector2(0.244 * u, 0.24 * u),
			center + Vector2(0.19 * u, 0.07 * u),
			center + Vector2(0.136 * u, -0.09 * u),
			center + Vector2(0.092 * u, -0.21 * u),
		])
		ci.draw_colored_polygon(dark, cloak_dark)
	# strap over the shoulder to the sack
	ci.draw_line(center + Vector2(-0.09 * u, -0.21 * u), center + Vector2(0.235 * u, -0.05 * u), strap, maxf(1.4, u * 0.03), true)
	# tan road sack, clearly outside the cloak silhouette
	ci.draw_circle(center + Vector2(0.255 * u, -0.005 * u), u * 0.105, sack)
	ci.draw_circle(center + Vector2(0.255 * u, -0.045 * u), u * 0.035, sack.lightened(0.12))
	ci.draw_circle(center + Vector2(0.255 * u, -0.105 * u), u * 0.028, strap)
	if u >= 28.0:
		var sack_ring := _ellipse_poly(center + Vector2(0.255 * u, -0.005 * u), u * 0.105, u * 0.105, 14)
		sack_ring.append(sack_ring[0])
		ci.draw_polyline(sack_ring, ink.darkened(0.1), lw * 0.7, true)
	# pointed hood with a cowl tip flaring right
	var hood_c := center + Vector2(0, -0.305 * u)
	var tip := PackedVector2Array([
		hood_c + Vector2(0.03 * u, -0.105 * u),
		hood_c + Vector2(0.115 * u, -0.215 * u),
		hood_c + Vector2(0.13 * u, -0.04 * u),
	])
	ci.draw_colored_polygon(tip, hood)
	ci.draw_circle(hood_c, u * 0.135, hood)
	ci.draw_circle(hood_c + Vector2(0, u * 0.005), u * 0.085, face)
	if u < 56.0:
		ci.draw_line(hood_c + Vector2(-0.03 * u, 0), hood_c + Vector2(0.03 * u, 0), Color(eye, 0.9), maxf(1.0, u * 0.022), true)
	else:
		var eye_r: float = maxf(1.1, u * 0.017)
		ci.draw_circle(hood_c + Vector2(-0.034 * u, -0.004 * u), eye_r * 2.0, Color(eye, 0.3))
		ci.draw_circle(hood_c + Vector2(0.034 * u, -0.004 * u), eye_r * 2.0, Color(eye, 0.3))
		ci.draw_circle(hood_c + Vector2(-0.034 * u, -0.004 * u), eye_r, eye)
		ci.draw_circle(hood_c + Vector2(0.034 * u, -0.004 * u), eye_r, eye)
	# ink outlines: cloak, hood, tip
	var bell_line := bell.duplicate()
	bell_line.append(bell[0])
	ci.draw_polyline(bell_line, ink, lw, true)
	var hood_ring := _ellipse_poly(hood_c, u * 0.135, u * 0.135, 14)
	hood_ring.append(hood_ring[0])
	ci.draw_polyline(hood_ring, ink, lw * 0.8, true)
	var tip_line := tip.duplicate()
	tip_line.append(tip[0])
	ci.draw_polyline(tip_line, ink, lw * 0.8, true)

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
			_draw_city(self, vp, hex_radius * 0.22 * k, col, seat)
		else:
			_draw_settlement(self, vp, hex_radius * 0.22 * k, col, seat)
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
	_draw_blocker_icon(self, pos, hex_radius * scale_f, int(round(float(small_font_size) * scale_f)))
