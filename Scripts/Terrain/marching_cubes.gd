class_name MarchingCubes
extends RefCounted

static var MARCHING_CUBES_TABLES = preload("res://Scripts/Terrain/marchingcubes_tables.gd")

## Generates a mesh from SDF data using marching cubes algorithm.
## sdf_grid: Flattened 3D array (X Z Y order).
## dims: Grid dimensions.
## iso_level: Surface threshold (default 0.0).
static func generate_mesh(sdf_grid: PackedFloat32Array, dims: Vector3i, chunk_key: Vector3i, iso_level: float = 0.0) -> ArrayMesh:

	var t_start = Time.get_ticks_msec()

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()

	if dims.x < 2 or dims.y < 2 or dims.z < 2:
		SignalBus.meshing_ended.emit.call_deferred(chunk_key)
		return

	# IMPLEMENT MARCHING CUBES
	var dx_stride = dims.y * dims.z
	var dz_stride = dims.y
	var dy_stride = 1

	for x in range(dims.x - 1):
		for z in range(dims.z - 1):
			for y in range(dims.y - 1):
				# Get corner indices in flattened array (X Z Y order)
				var c000_idx = x * dx_stride + z * dz_stride + y * dy_stride
				var c100_idx = (x + 1) * dx_stride + z * dz_stride + y * dy_stride
				var c010_idx = x * dx_stride + z * dz_stride + (y + 1) * dy_stride
				var c110_idx = (x + 1) * dx_stride + z * dz_stride + (y + 1) * dy_stride
				var c001_idx = x * dx_stride + (z + 1) * dz_stride + y * dy_stride
				var c101_idx = (x + 1) * dx_stride + (z + 1) * dz_stride + y * dy_stride
				var c011_idx = x * dx_stride + (z + 1) * dz_stride + (y + 1) * dy_stride
				var c111_idx = (x + 1) * dx_stride + (z + 1) * dz_stride + (y + 1) * dy_stride

				# Get corner values
				var c000 = sdf_grid[c000_idx]
				var c100 = sdf_grid[c100_idx]
				var c010 = sdf_grid[c010_idx]
				var c110 = sdf_grid[c110_idx]
				var c001 = sdf_grid[c001_idx]
				var c101 = sdf_grid[c101_idx]
				var c011 = sdf_grid[c011_idx]
				var c111 = sdf_grid[c111_idx]

				# Compute cube index
				var cube_index = 0
				if c000 < iso_level: cube_index |= 1
				if c100 < iso_level: cube_index |= 2
				if c110 < iso_level: cube_index |= 4
				if c010 < iso_level: cube_index |= 8
				if c001 < iso_level: cube_index |= 16
				if c101 < iso_level: cube_index |= 32
				if c111 < iso_level: cube_index |= 64
				if c011 < iso_level: cube_index |= 128

				# Get triangulation for this cube
				var triangulation = MARCHING_CUBES_TABLES.triangulations[cube_index]

				# Define corner positions
				var p000 = Vector3(x, y, z)
				var p100 = Vector3(x + 1, y, z)
				var p110 = Vector3(x + 1, y + 1, z)
				var p010 = Vector3(x, y + 1, z)
				var p001 = Vector3(x, y, z + 1)
				var p101 = Vector3(x + 1, y, z + 1)
				var p111 = Vector3(x + 1, y + 1, z + 1)
				var p011 = Vector3(x, y + 1, z + 1)

				var corners = [p000, p100, p110, p010, p001, p101, p111, p011]
				var corner_values = [c000, c100, c110, c010, c001, c101, c111, c011]

				# Process triangles
				var tri_index = 0
				while tri_index < triangulation.size() and triangulation[tri_index] != -1:
					var edge0 = triangulation[tri_index]
					var edge1 = triangulation[tri_index + 1]
					var edge2 = triangulation[tri_index + 2]

					# Interpolate vertices on edges
					var v0 = _interpolate_vertex(corners, corner_values, MARCHING_CUBES_TABLES.edges[edge0], iso_level)
					var v1 = _interpolate_vertex(corners, corner_values, MARCHING_CUBES_TABLES.edges[edge1], iso_level)
					var v2 = _interpolate_vertex(corners, corner_values, MARCHING_CUBES_TABLES.edges[edge2], iso_level)

					# Add vertices
					var vertex_start = vertices.size()
					vertices.append(v0)
					vertices.append(v1)
					vertices.append(v2)

					# Calculate normals
					normals.append(_calculate_normal_from_sdf(sdf_grid, dims, v0))
					normals.append(_calculate_normal_from_sdf(sdf_grid, dims, v1))
					normals.append(_calculate_normal_from_sdf(sdf_grid, dims, v2))

					# Add indices
					indices.append(vertex_start)
					indices.append(vertex_start + 1)
					indices.append(vertex_start + 2)

					tri_index += 3

	if vertices.is_empty() or indices.is_empty():
		SignalBus.meshing_ended.emit.call_deferred(null,chunk_key)
		print("Marching cubes meshed empty in: ", Time.get_ticks_msec() - t_start)
		return

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	SignalBus.meshing_ended.emit.call_deferred(mesh, chunk_key)
	print("Marching cubes meshed in: ", Time.get_ticks_msec() - t_start)
	return mesh

## Interpolates a vertex on an edge based on the iso level.
static func _interpolate_vertex(corners: Array, corner_values: Array, edge: Vector2i, iso_level: float) -> Vector3:
	var p0 = corners[edge.x]
	var p1 = corners[edge.y]
	var v0 = corner_values[edge.x]
	var v1 = corner_values[edge.y]
	if abs(v1 - v0) < 0.00001:
		return p0
	var t = (iso_level - v0) / (v1 - v0)
	return p0 + t * (p1 - p0)

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
