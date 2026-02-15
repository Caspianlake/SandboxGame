class_name MarchingCubes
extends RefCounted

static var MARCHING_CUBES_TABLES = preload("res://Scripts/Terrain/marchingcubes_tables.gd")

## Generates a mesh from SDF data using Marching Cubes algorithm.
## sdf_grid: Flattened 3D array (X Z Y order).
## dims: Grid dimensions (should include padding for seamless chunks).
## iso_level: Surface threshold (default 0.0).
## skip_min_boundary: If true, skips cells at x=0, y=0, z=0 to avoid duplicate faces between chunks.
static func generate_mesh(sdf_grid: PackedFloat32Array, dims: Vector3i, chunk_key: Vector3i, iso_level: float = 0.0, skip_min_boundary: bool = false) -> ArrayMesh:

	var t_start = Time.get_ticks_msec()

	if dims.x < 2 or dims.y < 2 or dims.z < 2:
		SignalBus.meshing_ended.emit.call_deferred(chunk_key)
		return

	var tables = MARCHING_CUBES_TABLES.new()

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()

	var cell_dims = dims - Vector3i(1, 1, 1)

	# Start from 1 if skipping min boundary to avoid duplicate faces between chunks
	var start_x = 1 if skip_min_boundary else 0
	var start_y = 1 if skip_min_boundary else 0
	var start_z = 1 if skip_min_boundary else 0

	var dy = 1
	var dz = dims.y
	var dx = dims.y * dims.z

	# Pass 1: Generate vertices and triangles
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

				var edge_vertices = PackedInt32Array()
				edge_vertices.resize(12)
				edge_vertices.fill(-1)

				var tri_list = tables.triangulations[mask]

				# Generate vertices on edges
				for vertex_index in tri_list:
					if vertex_index == -1:
						continue
					if edge_vertices[vertex_index] != -1:
						continue

					var edge = tables.edges[vertex_index]
					var v0 = corner_values[edge.x]
					var v1 = corner_values[edge.y]
					if (v0 < iso_level) == (v1 < iso_level):
						continue  # Should not happen for valid edges

					var t = (iso_level - v0) / (v1 - v0)
					var p0 = Vector3(tables.points[edge.x])
					var p1 = Vector3(tables.points[edge.y])
					var vertex_pos = p0.lerp(p1, t) + Vector3(x, y, z)

					vertices.append(vertex_pos)

					# Calculate normal
					var normal = _calculate_normal_from_sdf(sdf_grid, dims, vertex_pos)
					normals.append(normal)

					edge_vertices[vertex_index] = vertices.size() - 1

				# Add triangles
				for i in range(0, tri_list.size(), 3):
					if tri_list[i] == -1 or tri_list[i+1] == -1 or tri_list[i+2] == -1:
						break
					indices.append(edge_vertices[tri_list[i]])
					indices.append(edge_vertices[tri_list[i+1]])
					indices.append(edge_vertices[tri_list[i+2]])

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
	print("Marching Cubes meshed in: ", Time.get_ticks_msec() - t_start)
	return

## Calculates the normal using the analytical gradient of trilinear interpolation.
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
	var idx000 = x0 * dx_stride + z0 * dz_stride + y0 * dy_stride
	var c000 = sdf_grid[idx000]
	var c100 = sdf_grid[idx000 + dx_stride]
	var c010 = sdf_grid[idx000 + dy_stride]
	var c110 = sdf_grid[idx000 + dx_stride + dy_stride]
	var c001 = sdf_grid[idx000 + dz_stride]
	var c101 = sdf_grid[idx000 + dx_stride + dz_stride]
	var c011 = sdf_grid[idx000 + dy_stride + dz_stride]
	var c111 = sdf_grid[idx000 + dx_stride + dy_stride + dz_stride]

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
