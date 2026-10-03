extends Resource
class_name BlockMesher

@export_category("Mesher Settings")
@export var nfb: Array[int] = [] # non full block


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
				var visible := false
				for neighbor in neighbors:
					var neighbor_block = block_data[Vector3i(neighbor + Vector3(x,y,z))]
					if nfb.has(neighbor_block):
						visible = true
				if visible:
					

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	var FinalMesh = ArrayMesh.new()
	if vertices.size() > 0:
		FinalMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return FinalMesh
