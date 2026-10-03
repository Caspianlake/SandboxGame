extends Resource
class_name BlockMesher

@export_category("Mesher Settings")
@export var nfb: Array[int] = []

var flat_shading: bool = true

func generate_mesh(chunk_size: Vector3i, block_size: float, block_data: Dictionary[Vector3i, int]) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	
	var neighbors := PackedVector3Array([
		Vector3(0,0,1),
		Vector3(0,1,0),
		Vector3(1,0,0),
		Vector3(0,0,-1),
		Vector3(0,-1,0),
		Vector3(-1,0,0),
	])
	
	for x in range(0, chunk_size.x):
		for y in range(0,chunk_size.y):
			for z in range(0, chunk_size.z):
				var pos = Vector3(x,y,z)
				
				var current_block = block_data.get(Vector3i(pos), 0)
				if nfb.has(current_block):
					continue
					
				var quad_to: Array[Vector3] = []
				for neighbor in neighbors:
					var neighbor_block = block_data.get(Vector3i(neighbor + pos), 0)
					if nfb.has(neighbor_block):
						quad_to.append(neighbor + pos)
				
				if quad_to.size() > 0:
					for neighbor in quad_to:
						var data: Dictionary = get_quad(neighbor, pos, block_size)
						for vertex in data["vertices"]:
							vertices.append(vertex)
							normals.append(data["normal"])
							colors.append(Color8(current_block, 0, 0))

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	var FinalMesh = ArrayMesh.new()
	if vertices.size() > 0:
		FinalMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return FinalMesh

func get_quad(pos_a: Vector3, pos_b: Vector3, size: float) -> Dictionary:
	var dir: Vector3 = (pos_b - pos_a).normalized()
	var p: Vector3 = pos_a * size
	var h: float = size * 0.5
	var vertices: Array[Vector3] = []

	if dir.is_equal_approx(Vector3.UP):
		vertices = [
			p + Vector3(-h, h,  h), p + Vector3( h, h,  h), p + Vector3( h, h, -h),
			p + Vector3(-h, h,  h), p + Vector3( h, h, -h), p + Vector3(-h, h, -h)
		]
	elif dir.is_equal_approx(Vector3.DOWN):
		vertices = [
			p + Vector3(-h, -h, -h), p + Vector3( h, -h, -h), p + Vector3( h, -h,  h),
			p + Vector3(-h, -h, -h), p + Vector3( h, -h,  h), p + Vector3(-h, -h,  h)
		]
	elif dir.is_equal_approx(Vector3.LEFT):
		vertices = [
			p + Vector3(-h,  h,  h), p + Vector3(-h,  h, -h), p + Vector3(-h, -h, -h),
			p + Vector3(-h,  h,  h), p + Vector3(-h, -h, -h), p + Vector3(-h, -h,  h)
		]
	elif dir.is_equal_approx(Vector3.RIGHT):
		vertices = [
			p + Vector3( h,  h, -h), p + Vector3( h,  h,  h), p + Vector3( h, -h,  h),
			p + Vector3( h,  h, -h), p + Vector3( h, -h,  h), p + Vector3( h, -h, -h)
		]
	elif dir.is_equal_approx(Vector3.FORWARD):
		vertices = [
			p + Vector3(-h,  h, -h), p + Vector3( h,  h, -h), p + Vector3( h, -h, -h),
			p + Vector3(-h,  h, -h), p + Vector3( h, -h, -h), p + Vector3(-h, -h, -h)
		]
	elif dir.is_equal_approx(Vector3.BACK):
		vertices = [
			p + Vector3( h,  h,  h), p + Vector3(-h,  h,  h), p + Vector3(-h, -h,  h),
			p + Vector3( h,  h,  h), p + Vector3(-h, -h,  h), p + Vector3( h, -h,  h)
		]
	else:
		dir = Vector3.BACK
		vertices = [
			p + Vector3( h,  h,  h), p + Vector3(-h,  h,  h), p + Vector3(-h, -h,  h),
			p + Vector3( h,  h,  h), p + Vector3(-h, -h,  h), p + Vector3( h, -h,  h)
		]

	return {
		"vertices": vertices,
		"normal": -dir
	}
