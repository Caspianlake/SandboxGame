## Surface Nets for Godot 4
## Generates smooth meshes from Signed Distance Field (SDF) data.

class_name SurfaceNets
extends RefCounted

## Edges of a cube, connecting corner indices.
const CUBE_EDGES = [
	[0, 1], [1, 2], [2, 3], [3, 0],  # Bottom
	[4, 5], [5, 6], [6, 7], [7, 4],  # Top
	[0, 4], [1, 5], [2, 6], [3, 7]   # Vertical
]

## Corner positions of a cube.
const CUBE_CORNERS = [
	Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 1), Vector3i(0, 0, 1),
	Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(1, 1, 1), Vector3i(0, 1, 1)
]

## Generates a mesh from SDF data.
## sdf_grid: Flattened 3D array (X Z Y order).
## dims: Grid dimensions (should include padding for seamless chunks).
## iso_level: Surface threshold (default 0.0).
## skip_min_boundary: If true, skips cells at x=0, y=0, z=0 to avoid duplicate faces between chunks.
static func generate_mesh(sdf_grid: PackedFloat32Array, dims: Vector3i, chunk_key: Vector3i, iso_level: float = 0.0, skip_min_boundary: bool = false) -> ArrayMesh:
	
	var t_start = Time.get_ticks_msec()
	
	if dims.x < 2 or dims.y < 2 or dims.z < 2:
		SignalBus.meshing_ended.emit.call_deferred(chunk_key)
		return 

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
	
	# Start from 1 if skipping min boundary to avoid duplicate faces between chunks
	var start_x = 1 if skip_min_boundary else 0
	var start_y = 1 if skip_min_boundary else 0
	var start_z = 1 if skip_min_boundary else 0
	
	# Pass 1: Generate vertices
	for x in range(start_x, cell_dims.x):
		for z in range(start_z, cell_dims.z):
			for y in range(start_y, cell_dims.y):
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
	for x in range(start_x, cell_dims.x):
		for z in range(start_z, cell_dims.z - 1):
			for y in range(start_y, cell_dims.y - 1):
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
	for x in range(start_x, cell_dims.x - 1):
		for z in range(start_z, cell_dims.z - 1):
			for y in range(start_y, cell_dims.y):
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
	for x in range(start_x, cell_dims.x - 1):
		for z in range(start_z, cell_dims.z):
			for y in range(start_y, cell_dims.y - 1):
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
		SignalBus.meshing_ended.emit.call_deferred(chunk_key)
		return

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	SignalBus.meshing_ended.emit.call_deferred(mesh, chunk_key)
	print("Grid meshed in: ",Time.get_ticks_msec()-t_start)
	return

## Calculates the normal using the analytical gradient of trilinear interpolation.
## This computes the exact partial derivatives of the trilinear interpolation formula.
## sdf_grid: The SDF data array.
## dims: Dimensions of the grid.
## pos: Position to calculate normal at.
static func _calculate_normal_from_sdf(sdf_grid: PackedFloat32Array, dims: Vector3i, pos: Vector3) -> Vector3:
	var dy_stride = 1
	var dz_stride = dims.y
	var dx_stride = dims.y * dims.z
	
	# Get the cell containing the position (clamp to valid cell range)
	var x0 = clampi(int(floor(pos.x)), 0, dims.x - 2)
	var y0 = clampi(int(floor(pos.y)), 0, dims.y - 2)
	var z0 = clampi(int(floor(pos.z)), 0, dims.z - 2)
	
	# Fractional position within the cell [0, 1]
	var fx = clampf(pos.x - float(x0), 0.0, 1.0)
	var fy = clampf(pos.y - float(y0), 0.0, 1.0)
	var fz = clampf(pos.z - float(z0), 0.0, 1.0)
	
	# Get the 8 corner values of the cell
	# Corner naming: c[x][y][z] where 0=low, 1=high
	var idx000 = x0 * dx_stride + z0 * dz_stride + y0 * dy_stride
	var c000 = sdf_grid[idx000]
	var c100 = sdf_grid[idx000 + dx_stride]
	var c010 = sdf_grid[idx000 + dy_stride]
	var c110 = sdf_grid[idx000 + dx_stride + dy_stride]
	var c001 = sdf_grid[idx000 + dz_stride]
	var c101 = sdf_grid[idx000 + dx_stride + dz_stride]
	var c011 = sdf_grid[idx000 + dy_stride + dz_stride]
	var c111 = sdf_grid[idx000 + dx_stride + dy_stride + dz_stride]
	
	# Analytical gradient of trilinear interpolation:
	# f(x,y,z) = c000(1-x)(1-y)(1-z) + c100*x(1-y)(1-z) + c010(1-x)*y(1-z) + c110*x*y(1-z)
	#          + c001(1-x)(1-y)*z + c101*x(1-y)*z + c011(1-x)*y*z + c111*x*y*z
	#
	# df/dx = (c100-c000)(1-y)(1-z) + (c110-c010)*y(1-z) + (c101-c001)(1-y)*z + (c111-c011)*y*z
	# df/dy = (c010-c000)(1-x)(1-z) + (c110-c100)*x(1-z) + (c011-c001)(1-x)*z + (c111-c101)*x*z
	# df/dz = (c001-c000)(1-x)(1-y) + (c101-c100)*x(1-y) + (c011-c010)(1-x)*y + (c111-c110)*x*y
	
	var one_minus_fx = 1.0 - fx
	var one_minus_fy = 1.0 - fy
	var one_minus_fz = 1.0 - fz
	
	var grad_x = (c100 - c000) * one_minus_fy * one_minus_fz + \
				 (c110 - c010) * fy * one_minus_fz + \
				 (c101 - c001) * one_minus_fy * fz + \
				 (c111 - c011) * fy * fz
	
	var grad_y = (c010 - c000) * one_minus_fx * one_minus_fz + \
				 (c110 - c100) * fx * one_minus_fz + \
				 (c011 - c001) * one_minus_fx * fz + \
				 (c111 - c101) * fx * fz
	
	var grad_z = (c001 - c000) * one_minus_fx * one_minus_fy + \
				 (c101 - c100) * fx * one_minus_fy + \
				 (c011 - c010) * one_minus_fx * fy + \
				 (c111 - c110) * fx * fy
	
	var gradient = Vector3(grad_x, grad_y, grad_z)
	if gradient.length_squared() > 0.0001:
		return gradient.normalized()
	return Vector3.UP

## Safely gets the vertex index from the cell map.
## x, y, z: Cell coordinates.
## dims: Dimensions of the cell map.
## cell_map: Array of vertex indices.
static func _safe_map_idx(x: int, y: int, z: int, dims: Vector3i, cell_map: PackedInt32Array) -> int:
	if x < 0 or x >= dims.x or y < 0 or y >= dims.y or z < 0 or z >= dims.z:
		return -1
	return cell_map[x * (dims.z * dims.y) + z * dims.y + y]

## Adds a quad to the indices array as two triangles.
## indices: The indices array to append to.
## v1, v2, v3, v4: Vertex indices for the quad.
static func _add_quad(indices: PackedInt32Array, v1: int, v2: int, v3: int, v4: int):
	indices.append(v1)
	indices.append(v2)
	indices.append(v3)
	indices.append(v1)
	indices.append(v3)
	indices.append(v4)
