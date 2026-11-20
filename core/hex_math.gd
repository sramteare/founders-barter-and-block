class_name HexMath
extends RefCounted

# Standard 19-hex Catan-style island topology (pointy-top axial coordinates q, r)
# Generates exactly:
# - 19 Tiles
# - 54 Vertices (corners where up to 3 hexes meet)
# - 72 Edges (sides connecting adjacent vertices)

class BoardTopology extends RefCounted:
	var tile_coords: Array[Vector2i] = []          # index = tile_id (0..18)
	var tile_centers: Array[Vector2] = []          # unit-radius 2D centers
	var tile_vertices: Array = []                  # tile_id -> Array[int] (6 vertex_ids, clockwise)
	var tile_edges: Array = []                     # tile_id -> Array[int] (6 edge_ids)
	var vertex_positions: Array[Vector2] = []      # index = vertex_id (0..53), unit-radius 2D pos
	var vertex_tiles: Array = []                   # vertex_id -> Array[int] (1..3 adjacent tile_ids)
	var vertex_neighbors: Array = []               # vertex_id -> Array[int] (2..3 adjacent vertex_ids)
	var vertex_edges: Array = []                   # vertex_id -> Array[int] (2..3 incident edge_ids)
	var edge_vertices: Array[Vector2i] = []        # edge_id -> Vector2i(v_a, v_b) with v_a < v_b
	var edge_tiles: Array = []                     # edge_id -> Array[int] (1..2 adjacent tile_ids)
	var coastal_edges: Array[int] = []             # edges touching only 1 tile (30 perimeter edges)

static var _cached_topology: BoardTopology = null

static func get_topology() -> BoardTopology:
	if _cached_topology != null:
		return _cached_topology
	_cached_topology = _build_topology()
	return _cached_topology

static func axial_to_pixel(q: int, r: int, radius: float = 1.0) -> Vector2:
	var x := radius * sqrt(3.0) * (float(q) + float(r) * 0.5)
	var y := radius * 1.5 * float(r)
	return Vector2(x, y)

static func _build_topology() -> BoardTopology:
	var topo := BoardTopology.new()
	# Ring/row order for radius 2 island (19 hexes)
	for r in range(-2, 3):
		var q_min: int = max(-2, -r - 2)
		var q_max: int = min(2, -r + 2)
		for q in range(q_min, q_max + 1):
			topo.tile_coords.append(Vector2i(q, r))
			topo.tile_centers.append(axial_to_pixel(q, r, 1.0))

	var vertex_key_to_id: Dictionary = {}
	var edge_key_to_id: Dictionary = {}

	for t_id in range(topo.tile_coords.size()):
		var center: Vector2 = topo.tile_centers[t_id]
		var corners: Array[int] = []
		for i in range(6):
			var angle_deg := 60.0 * float(i) - 30.0 # Pointy-top hex corners
			var angle_rad := deg_to_rad(angle_deg)
			var pos := center + Vector2(cos(angle_rad), sin(angle_rad))
			var key := "%d_%d" % [int(round(pos.x * 1000.0)), int(round(pos.y * 1000.0))]
			var v_id: int
			if vertex_key_to_id.has(key):
				v_id = vertex_key_to_id[key]
			else:
				v_id = topo.vertex_positions.size()
				vertex_key_to_id[key] = v_id
				topo.vertex_positions.append(pos)
				topo.vertex_tiles.append([])
				topo.vertex_neighbors.append([])
				topo.vertex_edges.append([])
			corners.append(v_id)
			if not topo.vertex_tiles[v_id].has(t_id):
				topo.vertex_tiles[v_id].append(t_id)
		topo.tile_vertices.append(corners)

		var t_edges: Array[int] = []
		for i in range(6):
			var v1: int = corners[i]
			var v2: int = corners[(i + 1) % 6]
			var va: int = min(v1, v2)
			var vb: int = max(v1, v2)
			var e_key := "%d_%d" % [va, vb]
			var e_id: int
			if edge_key_to_id.has(e_key):
				e_id = edge_key_to_id[e_key]
			else:
				e_id = topo.edge_vertices.size()
				edge_key_to_id[e_key] = e_id
				topo.edge_vertices.append(Vector2i(va, vb))
				topo.edge_tiles.append([])
				topo.vertex_neighbors[va].append(vb)
				topo.vertex_neighbors[vb].append(va)
				topo.vertex_edges[va].append(e_id)
				topo.vertex_edges[vb].append(e_id)
			t_edges.append(e_id)
			if not topo.edge_tiles[e_id].has(t_id):
				topo.edge_tiles[e_id].append(t_id)
		topo.tile_edges.append(t_edges)

	# Collect coastal edges ordered clockwise around the island center
	var raw_coastal: Array[int] = []
	for e_id in range(topo.edge_vertices.size()):
		if topo.edge_tiles[e_id].size() == 1:
			raw_coastal.append(e_id)

	raw_coastal.sort_custom(func(a: int, b: int) -> bool:
		var ev_a: Vector2i = topo.edge_vertices[a]
		var ev_b: Vector2i = topo.edge_vertices[b]
		var mid_a: Vector2 = (topo.vertex_positions[ev_a.x] + topo.vertex_positions[ev_a.y]) * 0.5
		var mid_b: Vector2 = (topo.vertex_positions[ev_b.x] + topo.vertex_positions[ev_b.y]) * 0.5
		return atan2(mid_a.y, mid_a.x) < atan2(mid_b.y, mid_b.x)
	)
	topo.coastal_edges = raw_coastal
	return topo

static func are_tiles_adjacent(t1: int, t2: int) -> bool:
	var topo := get_topology()
	var c1: Vector2i = topo.tile_coords[t1]
	var c2: Vector2i = topo.tile_coords[t2]
	var dq: int = c1.x - c2.x
	var dr: int = c1.y - c2.y
	var ds: int = (-c1.x - c1.y) - (-c2.x - c2.y)
	return max(abs(dq), max(abs(dr), abs(ds))) == 1

# Computes the longest continuous simple path of edges owned by `player_id`.
# Respects road-breaking: an opponent building on an intermediate vertex blocks continuity.
static func compute_longest_route(
	player_id: int,
	edge_owner: Array[int],
	vertex_owner: Array[int]
) -> int:
	var topo := get_topology()
	var owned_edges: Array[int] = []
	for e_id in range(edge_owner.size()):
		if edge_owner[e_id] == player_id:
			owned_edges.append(e_id)
	if owned_edges.is_empty():
		return 0

	var best := 0
	var visited_edges: Dictionary = {}
	for e_id in owned_edges:
		var ev: Vector2i = topo.edge_vertices[e_id]
		visited_edges[e_id] = true
		var len_a := 1 + _dfs_route(topo, player_id, ev.x, visited_edges, edge_owner, vertex_owner)
		var len_b := 1 + _dfs_route(topo, player_id, ev.y, visited_edges, edge_owner, vertex_owner)
		visited_edges.erase(e_id)
		best = max(best, max(len_a, len_b))
	return best

static func _dfs_route(
	topo: BoardTopology,
	player_id: int,
	current_vertex: int,
	visited_edges: Dictionary,
	edge_owner: Array[int],
	vertex_owner: Array[int]
) -> int:
	# Opponent settlement/city breaks the route at this vertex
	var v_owner: int = vertex_owner[current_vertex]
	if v_owner != -1 and v_owner != player_id:
		return 0

	var max_sub := 0
	for next_edge in topo.vertex_edges[current_vertex]:
		if edge_owner[next_edge] != player_id or visited_edges.has(next_edge):
			continue
		var ev: Vector2i = topo.edge_vertices[next_edge]
		var next_vertex: int = ev.y if ev.x == current_vertex else ev.x
		visited_edges[next_edge] = true
		var dist := 1 + _dfs_route(topo, player_id, next_vertex, visited_edges, edge_owner, vertex_owner)
		visited_edges.erase(next_edge)
		if dist > max_sub:
			max_sub = dist
	return max_sub
