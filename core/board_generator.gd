class_name BoardGenerator
extends RefCounted

const PORT_COASTAL_INDICES: Array[int] = [0, 3, 6, 10, 13, 16, 20, 23, 26]

static func generate(seed_val: int, balanced_numbers: bool = true) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var terrains: Array[int] = [
		GameTypes.TerrainType.FOREST, GameTypes.TerrainType.FOREST,
		GameTypes.TerrainType.FOREST, GameTypes.TerrainType.FOREST,
		GameTypes.TerrainType.FIELDS, GameTypes.TerrainType.FIELDS,
		GameTypes.TerrainType.FIELDS, GameTypes.TerrainType.FIELDS,
		GameTypes.TerrainType.PASTURE, GameTypes.TerrainType.PASTURE,
		GameTypes.TerrainType.PASTURE, GameTypes.TerrainType.PASTURE,
		GameTypes.TerrainType.HILLS, GameTypes.TerrainType.HILLS,
		GameTypes.TerrainType.HILLS,
		GameTypes.TerrainType.MOUNTAINS, GameTypes.TerrainType.MOUNTAINS,
		GameTypes.TerrainType.MOUNTAINS,
		GameTypes.TerrainType.BARREN,
	]
	_shuffle_int_array(terrains, rng)

	var blocker_tile := 0
	for i in range(terrains.size()):
		if terrains[i] == GameTypes.TerrainType.BARREN:
			blocker_tile = i
			break

	var base_tokens: Array[int] = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
	var tile_numbers: Array[int] = []
	tile_numbers.resize(19)

	var max_attempts := 1000 if balanced_numbers else 1
	for _attempt in range(max_attempts):
		var tokens: Array[int] = base_tokens.duplicate()
		_shuffle_int_array(tokens, rng)
		var token_idx := 0
		for t_id in range(19):
			if t_id == blocker_tile:
				tile_numbers[t_id] = 0
			else:
				tile_numbers[t_id] = tokens[token_idx]
				token_idx += 1
		if not balanced_numbers or not _has_adjacent_red_numbers(tile_numbers):
			break

	var ports_pool: Array[int] = [
		GameTypes.PortType.GENERIC_3_TO_1,
		GameTypes.PortType.GENERIC_3_TO_1,
		GameTypes.PortType.GENERIC_3_TO_1,
		GameTypes.PortType.GENERIC_3_TO_1,
		GameTypes.PortType.TIMBER_2_TO_1,
		GameTypes.PortType.CLAY_2_TO_1,
		GameTypes.PortType.FLEECE_2_TO_1,
		GameTypes.PortType.GRAIN_2_TO_1,
		GameTypes.PortType.IRON_2_TO_1,
	]
	_shuffle_int_array(ports_pool, rng)

	var topo := HexMath.get_topology()
	var vertex_ports: Array[int] = []
	vertex_ports.resize(54)
	vertex_ports.fill(-2)

	for i in range(PORT_COASTAL_INDICES.size()):
		var coastal_idx: int = PORT_COASTAL_INDICES[i]
		if coastal_idx < topo.coastal_edges.size():
			var edge_id: int = topo.coastal_edges[coastal_idx]
			var ev: Vector2i = topo.edge_vertices[edge_id]
			var port_type: int = ports_pool[i]
			vertex_ports[ev.x] = port_type
			vertex_ports[ev.y] = port_type

	return {
		"tile_terrains": terrains,
		"tile_numbers": tile_numbers,
		"blocker_tile": blocker_tile,
		"vertex_ports": vertex_ports,
	}

static func _shuffle_int_array(arr: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _has_adjacent_red_numbers(tile_numbers: Array[int]) -> bool:
	for t1 in range(tile_numbers.size()):
		var n1: int = tile_numbers[t1]
		if n1 != 6 and n1 != 8:
			continue
		for t2 in range(t1 + 1, tile_numbers.size()):
			var n2: int = tile_numbers[t2]
			if n2 != 6 and n2 != 8:
				continue
			if HexMath.are_tiles_adjacent(t1, t2):
				return true
	return false
