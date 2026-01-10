## Surface Nets for Godot 4
## Generates smooth meshes from Signed Distance Field (SDF) data.

class_name SurfaceNets
extends RefCounted

const CUBE_EDGES = [
	[0, 1], [1, 2], [2, 3], [3, 0],  # Bottom
	[4, 5], [5, 6], [6, 7], [7, 4],  # Top
	[0, 4], [1, 5], [2, 6], [3, 7]   # Vertical
]

const CUBE_CORNERS = [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 1), Vector3i(0, 0, 1),
	Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 1)
]

## Generates a mesh from SDF data.
## sdf_grid: Flattened 3D array (X Z Y order).
## dims: Grid dimensions.
## iso_level: Surface threshold (default 0.0).
static func generate_mesh(sdf_grid: PackedFloat32Array, dims: Vector3i, iso_level: float = 0.0) -> ArrayMesh:
	if dims.x < 2 or dims.y < 2 or dims.z < 2:
		return null

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	var cell_dims = dims - Vector3i(1, 1, 1)
	var cell_map = PackedInt32Array()
	cell_map.resize(cell_dims.x * cell_dims.y * cell_dims.z)
	cell_map.fill(-1)
	
	var dy = 1
	var dz = dims.y
	var dx = dims.y * dims.z
	
	# Pass 1: Generate vertices
	for x in range(cell_dims.x):
		for z in range(cell_dims.z):
			for y in range(cell_dims.y):
				var base_idx = x * dx + z * dz + y * dy
				
				var corner_values = [
					sdf_grid[base_idx],
					sdf_grid[base_idx + dx],
					sdf_grid[base_idx + dx + dz],
					sdf_grid[base_idx + dz],
					sdf_grid[base_idx + dy],
					sdf_grid[base_idx + dy + dx],
					sdf_grid[base_idx + dy + dx + dz],
					sdf_grid[base_idx + dy + dz]
				]
				
				var mask = 0
				for i in range(8):
					if corner_values[i] < iso_level:
						mask |= (1 << i)
				
				if mask == 0 or mask == 255:
					continue
				
				var edge_count = 0
				var avg_pos = Vector3.ZERO
				for edge in CUBE_EDGES:
					var v1 = corner_values[edge[0]]
					var v2 = corner_values[edge[1]]
					if (v1 < iso_level) != (v2 < iso_level):
						var t = (iso_level - v1) / (v2 - v1)
						avg_pos += Vector3(CUBE_CORNERS[edge[0]]).lerp(Vector3(CUBE_CORNERS[edge[1]]), t)
						edge_count += 1
				
				if edge_count > 0:
					var vertex_pos = (avg_pos / float(edge_count)) + Vector3(x, y, z)
					vertices.append(vertex_pos)
					
					# Calculate normal from SDF gradient at the vertex position
					var normal = _calculate_normal_from_sdf(sdf_grid, dims, vertex_pos)
					normals.append(normal)
					
					cell_map[x * (cell_dims.z * cell_dims.y) + z * cell_dims.y + y] = vertices.size() - 1

	# Pass 2: Generate faces
	# For each edge that crosses the iso-surface, create a quad connecting the 4 adjacent cells
	
	# X-axis edges: connect cells sharing an edge along X
	for x in range(cell_dims.x):
		for z in range(cell_dims.z - 1):
			for y in range(cell_dims.y - 1):
				# Check if edge along X crosses the surface
				var grid_idx = x * dx + z * dz + y * dy
				var v0 = sdf_grid[grid_idx + dy + dz]  # Corner at (x, y+1, z+1)
				var v1 = sdf_grid[grid_idx + dx + dy + dz]  # Corner at (x+1, y+1, z+1)
				
				if (v0 < iso_level) != (v1 < iso_level):
					# Edge crosses surface - get the 4 cells sharing this edge
					var c1 = _safe_map_idx(x, y, z, cell_dims, cell_map)
					var c2 = _safe_map_idx(x, y + 1, z, cell_dims, cell_map)
					var c3 = _safe_map_idx(x, y + 1, z + 1, cell_dims, cell_map)
					var c4 = _safe_map_idx(x, y, z + 1, cell_dims, cell_map)
					
					if c1 != -1 and c2 != -1 and c3 != -1 and c4 != -1:
						# Godot uses clockwise winding - swap order based on which side is inside
						if v0 < iso_level:
							_add_quad(indices, c4, c3, c2, c1)
						else:
							_add_quad(indices, c1, c2, c3, c4)

	# Y-axis edges: connect cells sharing an edge along Y
	for x in range(cell_dims.x - 1):
		for z in range(cell_dims.z - 1):
			for y in range(cell_dims.y):
				# Check if edge along Y crosses the surface
				var grid_idx = x * dx + z * dz + y * dy
				var v0 = sdf_grid[grid_idx + dx + dz]  # Corner at (x+1, y, z+1)
				var v1 = sdf_grid[grid_idx + dx + dy + dz]  # Corner at (x+1, y+1, z+1)
				
				if (v0 < iso_level) != (v1 < iso_level):
					# Edge crosses surface - get the 4 cells sharing this edge
					var c1 = _safe_map_idx(x, y, z, cell_dims, cell_map)
					var c2 = _safe_map_idx(x, y, z + 1, cell_dims, cell_map)
					var c3 = _safe_map_idx(x + 1, y, z + 1, cell_dims, cell_map)
					var c4 = _safe_map_idx(x + 1, y, z, cell_dims, cell_map)
					
					if c1 != -1 and c2 != -1 and c3 != -1 and c4 != -1:
						# Godot uses clockwise winding - swap order based on which side is inside
						if v0 < iso_level:
							_add_quad(indices, c4, c3, c2, c1)
						else:
							_add_quad(indices, c1, c2, c3, c4)

	# Z-axis edges: connect cells sharing an edge along Z
	for x in range(cell_dims.x - 1):
		for z in range(cell_dims.z):
			for y in range(cell_dims.y - 1):
				# Check if edge along Z crosses the surface
				var grid_idx = x * dx + z * dz + y * dy
				var v0 = sdf_grid[grid_idx + dx + dy]  # Corner at (x+1, y+1, z)
				var v1 = sdf_grid[grid_idx + dx + dy + dz]  # Corner at (x+1, y+1, z+1)
				
				if (v0 < iso_level) != (v1 < iso_level):
					# Edge crosses surface - get the 4 cells sharing this edge
					var c1 = _safe_map_idx(x, y, z, cell_dims, cell_map)
					var c2 = _safe_map_idx(x + 1, y, z, cell_dims, cell_map)
					var c3 = _safe_map_idx(x + 1, y + 1, z, cell_dims, cell_map)
					var c4 = _safe_map_idx(x, y + 1, z, cell_dims, cell_map)
					
					if c1 != -1 and c2 != -1 and c3 != -1 and c4 != -1:
						# Godot uses clockwise winding - swap order based on which side is inside
						if v0 < iso_level:
							_add_quad(indices, c4, c3, c2, c1)
						else:
							_add_quad(indices, c1, c2, c3, c4)

	if vertices.is_empty() or indices.is_empty():
		return null

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Calculates the normal using central differences on the SDF grid.
## The gradient of the SDF points toward increasing values (outside for standard SDF).
static func _calculate_normal_from_sdf(sdf_grid: PackedFloat32Array, dims: Vector3i, pos: Vector3) -> Vector3:
	var dy_stride = 1
	var dz_stride = dims.y
	var dx_stride = dims.y * dims.z
	
	# Sample positions for central differences
	var xi = clampi(int(round(pos.x)), 1, dims.x - 2)
	var yi = clampi(int(round(pos.y)), 1, dims.y - 2)
	var zi = clampi(int(round(pos.z)), 1, dims.z - 2)
	
	var idx = xi * dx_stride + zi * dz_stride + yi * dy_stride
	
	# Central differences for gradient
	var grad_x = sdf_grid[idx + dx_stride] - sdf_grid[idx - dx_stride]
	var grad_y = sdf_grid[idx + dy_stride] - sdf_grid[idx - dy_stride]
	var grad_z = sdf_grid[idx + dz_stride] - sdf_grid[idx - dz_stride]
	
	# The gradient points toward increasing SDF values
	# For standard SDF (negative inside, positive outside), gradient points outward
	var normal = Vector3(grad_x, grad_y, grad_z)
	if normal.length_squared() > 0.0001:
		return normal.normalized()
	return Vector3.UP

static func _safe_map_idx(x: int, y: int, z: int, dims: Vector3i, cell_map: PackedInt32Array) -> int:
	if x < 0 or x >= dims.x or y < 0 or y >= dims.y or z < 0 or z >= dims.z:
		return -1
	return cell_map[x * (dims.z * dims.y) + z * dims.y + y]

static func _add_quad(indices: PackedInt32Array, v1: int, v2: int, v3: int, v4: int):
	indices.append(v1)
	indices.append(v2)
	indices.append(v3)
	indices.append(v1)
	indices.append(v3)
	indices.append(v4)
