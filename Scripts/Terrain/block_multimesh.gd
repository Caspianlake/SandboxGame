extends Resource
class_name BlockMultimesh

static var flat_shading: bool = true


static func generate_mesh(chunk_data: Dictionary[Vector3i, float], chunk_size: Vector3i, block_size: float, block_data: Dictionary[Vector3i, int], Voxel: BoxMesh, Scenario) -> MultiMesh:
	var instance = RenderingServer.instance_create()
	
	
	
	var NewMesh: MultiMesh = MultiMesh.new()
	NewMesh.transform_format = MultiMesh.TRANSFORM_3D
	NewMesh.mesh = Voxel
	NewMesh.use_colors = true
	NewMesh.instance_count = chunk_size.x * chunk_size.y * chunk_size.z
	
	var ctr: int = 0
	
	for x in range(0, chunk_size.x):
		for y in range(0, chunk_size.y):
			for z in range (0, chunk_size.z):
				
				if y < chunk_data[Vector3i(x,chunk_size.y,z)]:
					NewMesh.set_instance_transform(ctr, Transform3D(Basis(),Vector3(x*block_size,y*block_size,z*block_size)))
					NewMesh.set_instance_color(ctr, Color.from_rgba8(block_data[Vector3i(x,y,z)],0,0))
					ctr += 1
				else:
					ctr += 1
	
	return NewMesh
