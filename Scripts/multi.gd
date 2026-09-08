extends Node3D

@export var world_size: int = 32
@export var grid_size: int = 32
@export var new_noise: FastNoiseLite = FastNoiseLite.new()

func _ready():
	var main_mesh: BoxMesh = BoxMesh.new()
	main_mesh.size = Vector3(1,512,1)
	main_mesh.surface_set_material(0,load("res://Resources/UniversalMaterial.tres"))
	
	for cX in range(0,world_size):
		for cZ in range(0,world_size):
			var new_multimesh = MultiMesh.new()
			new_multimesh.transform_format = MultiMesh.TRANSFORM_3D
			new_multimesh.mesh = main_mesh
			new_multimesh.use_colors = true
			new_multimesh.instance_count = grid_size * grid_size
			new_multimesh.visible_instance_count = grid_size * grid_size
			
			var fX = cX * grid_size
			var fZ = cZ * grid_size
			
			for x in range(0,grid_size):
				for z in range(0, grid_size):
					var height = floorf(remap(new_noise.get_noise_2d(fX + x,fZ + z),-1.0,1.0,1.0,512.0))
					new_multimesh.set_instance_transform(x*grid_size + z, Transform3D(Basis(), Vector3(fX + x, height-700, fZ + z)))
			
			var mmi = MultiMeshInstance3D.new()
			mmi.multimesh = new_multimesh
			add_child(mmi)
