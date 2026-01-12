## Manages terrain generation and rendering using chunks.
extends Node3D

## Noise generator for terrain height.
@export var t_noise:= FastNoiseLite.new()
## Material for terrain meshes.
@export var t_material:= StandardMaterial3D.new()
## Size of each terrain chunk.
@export var chunk_size:= Vector3i(16,256,16)
## Distance in chunks to render around the origin.
@export var render_distance:= 16

## Number of remaining tasks.
var tasks_remaining: int = 0
## Start time for performance measurement.
var t_start: int

## Called when SDF generation ends.
func sdf_gen_ended(data, chunk_key):
	tasks_remaining -= 1
	
	if data:
		ThreadPool.add_task(SurfaceNets.generate_mesh.bind(data,chunk_size+Vector3i(2,2,2),chunk_key))
		tasks_remaining += 1

## Called when meshing ends.
func meshing_ended(data, chunk_key):
	tasks_remaining -= 1

	if data is ArrayMesh:
		var mi = MeshInstance3D.new()
		mi.mesh = data
		mi.set_surface_override_material(0, t_material)
		mi.position = Vector3(chunk_key.x * chunk_size.x, 0, chunk_key.z * chunk_size.z)
		add_child(mi)

	if tasks_remaining == 0:
		print(pow(render_distance*2+1,2)," Chunks completed in: ",Time.get_ticks_msec()-t_start)

## Initializes the terrain generation.
func _ready() -> void:
	
	SignalBus.sdf_gen_ended.connect(sdf_gen_ended)
	SignalBus.meshing_ended.connect(meshing_ended)
	
	t_start = Time.get_ticks_msec()
	
	for cx in range(-render_distance,render_distance+1):
		for cz in range(-render_distance,render_distance+1):
			var chunk_key := Vector3i(cx,0,cz)
			ThreadPool.add_task(TerrainDataGenerator.generate_sdf.bind(t_noise,chunk_size,chunk_key))
			tasks_remaining += 1
