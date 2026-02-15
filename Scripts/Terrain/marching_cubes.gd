class_name MarchingCubes
extends RefCounted

static var MARCHING_CUBES_TABLES = preload("res://Scripts/Terrain/marchingcubes_tables.gd")

## Generates a mesh from SDF data using marching cubes algorithm.
## sdf_grid: Flattened 3D array (X Z Y order).
## dims: Grid dimensions.
## iso_level: Surface threshold (default 0.0).
static func generate_mesh(sdf_grid: PackedFloat32Array, dims: Vector3i, chunk_key: Vector3i, iso_level: float = 0.0) -> ArrayMesh:

	var t_start = Time.get_ticks_msec()

	if dims.x < 2 or dims.y < 2 or dims.z < 2:
		SignalBus.meshing_ended.emit.call_deferred(chunk_key)
		return

	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()

	
	
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
	print("Marching cubes meshed in: ", Time.get_ticks_msec() - t_start)
	return mesh

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
