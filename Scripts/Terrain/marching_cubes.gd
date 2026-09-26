extends Resource
class_name MarchingCubes

static var flat_shading: bool = true

static func generate_mesh(chunk_data: Dictionary[Vector3i, float], chunk_size: Vector3i, block_size: float, block_data: Dictionary[Vector3i, int]) -> ArrayMesh:
	
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	
	for x in range(0, chunk_size.x):
		for y in range(0,chunk_size.y):
			for z in range(0, chunk_size.z):
				var tri_table: Array = get_triangulation(x,y,z,chunk_data)
				for edge_index in tri_table:
					if edge_index < 0: break
					var point_indices = MCTables.edges[edge_index]
					var p0 = MCTables.points[point_indices.x]
					var p1 = MCTables.points[point_indices.y]
					var pos_a: = Vector3i(x+p0.x, y+p0.y, z+p0.z)
					var pos_b: = Vector3i(x+p1.x, y+p1.y, z+p1.z)
					
					var position: Vector3 = calculate_interpolation(pos_a,pos_b, chunk_data)
					position *= Vector3(block_size,block_size,block_size)
					
					vertices.append(position)
					
					var solid_pos: Vector3i = Vector3i(x,y,z)
					var block_id: int = block_data.get(solid_pos, 0)
					
					colors.append(Color.from_rgba8(block_id,0,0))
					
					if not flat_shading:
						var normal: Vector3 = calculate_normal(pos_a, pos_b, chunk_data)
						normals.append(normal)
					elif vertices.size() % 3 == 0:
						var v0 = vertices[vertices.size() - 3]
						var v1 = vertices[vertices.size() - 2]
						var v2 = vertices[vertices.size() - 1]
						var face_normal = (v2 - v0).cross(v1 - v0).normalized()
						normals.append(face_normal)
						normals.append(face_normal)
						normals.append(face_normal)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	var FinalMesh = ArrayMesh.new()
	if vertices.size() > 0:
		FinalMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return FinalMesh

static func calculate_interpolation(a:Vector3i, b:Vector3i, chunk_data: Dictionary[Vector3i, float]) -> Vector3:
	var val_a: float = chunk_data[Vector3i(a.x,a.y,a.z)]
	var val_b: float = chunk_data[Vector3i(b.x,b.y,b.z)]
	
	var fa := Vector3(a)
	var fb := Vector3(b)
	
	var t: float = (0 - val_a)/(val_b-val_a)
	return fa+t*(fb-fa)

static func calculate_normal(a:Vector3i, b:Vector3i, chunk_data: Dictionary[Vector3i, float]) -> Vector3:
	var grad_a = Vector3(
		chunk_data.get(a + Vector3i(1, 0, 0), 0.0) - chunk_data.get(a - Vector3i(1, 0, 0), 0.0),
		chunk_data.get(a + Vector3i(0, 1, 0), 0.0) - chunk_data.get(a - Vector3i(0, 1, 0), 0.0),
		chunk_data.get(a + Vector3i(0, 0, 1), 0.0) - chunk_data.get(a - Vector3i(0, 0, 1), 0.0)
	)
	var grad_b = Vector3(
		chunk_data.get(b + Vector3i(1, 0, 0), 0.0) - chunk_data.get(b - Vector3i(1, 0, 0), 0.0),
		chunk_data.get(b + Vector3i(0, 1, 0), 0.0) - chunk_data.get(b - Vector3i(0, 1, 0), 0.0),
		chunk_data.get(b + Vector3i(0, 0, 1), 0.0) - chunk_data.get(b - Vector3i(0, 0, 1), 0.0)
	)
	
	var val_a = chunk_data[a]
	var val_b = chunk_data[b]
	
	var t = (0.0 - val_a) / (val_b - val_a) if val_b != val_a else 0.5
	var normal = -grad_a.lerp(grad_b, t)
	
	return normal.normalized() if normal.length_squared() > 0.0 else Vector3.UP

static func get_triangulation(x:int, y:int, z:int,chunk_data: Dictionary[Vector3i, float]) -> Array:
	var idx = 0b00000000
	idx |= int(chunk_data[Vector3i(x,y,z)] >= 0)<<0
	idx |= int(chunk_data[Vector3i(x,y,z+1)] >= 0)<<1
	idx |= int(chunk_data[Vector3i(x+1,y,z+1)] >= 0)<<2
	idx |= int(chunk_data[Vector3i(x+1,y,z)] >= 0)<<3
	idx |= int(chunk_data[Vector3i(x,y+1,z)] >= 0)<<4
	idx |= int(chunk_data[Vector3i(x,y+1,z+1)] >= 0)<<5
	idx |= int(chunk_data[Vector3i(x+1,y+1,z+1)] >= 0)<<6
	idx |= int(chunk_data[Vector3i(x+1,y+1,z)] >= 0)<<7
	return MCTables.triangulations[idx]
