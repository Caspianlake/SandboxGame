extends Node3D

@export var t_noise:= FastNoiseLite.new()
@export var t_material:= StandardMaterial3D.new()
@export var chunk_size:= Vector3i(16,16,16)

var sample_size:= Vector3i(2,2,2)

func _ready() -> void:
	for cx in range(-2,3):
		for cz in range(-2,3):
			var sdf_data := PackedFloat32Array()
			sdf_data.resize(sample_size.x*sample_size.y*sample_size.z)
			
			var chunk_offset:= Vector3(cx * chunk_size.x, 0, cz * chunk_size.z)
			var idx = 0
			
			var t = Time.get_ticks_msec()
			
			for x in range(sample_size.x):
				for z in range(sample_size.z):
					var column_height:= remap(clampf(t_noise.get_noise_2d(chunk_offset.x+x,chunk_offset.z+z),-1,1),-1,1,0,chunk_size.y)
					
					for y in range(sample_size.y):
						sdf_data[idx] = y - column_height
						idx += 1
			
			var mesh = SurfaceNets.generate_mesh(sdf_data, sample_size)
			print("Chunk (%d, %d) generated in %d ms" % [cx, cz, Time.get_ticks_msec() - t])
			
			# 4. Display it
			if mesh != null:
				var mi = MeshInstance3D.new()
				mi.mesh = mesh
				mi.set_surface_override_material(0, t_material)
				mi.position = Vector3(cx * chunk_size.x, 0, cz * chunk_size.z)
				add_child(mi)

func _process(_delta: float) -> void:
	pass
