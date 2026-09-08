extends MultiMeshInstance3D


func _ready():
	var main_mesh: BoxMesh = BoxMesh.new()
	main_mesh.surface_set_material(0,load("res://Resources/UniversalMaterial.tres"))
	
	# Create the multimesh.
	multimesh = MultiMesh.new()
	# Set the format first.
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# Set the mesh that will be duplicated.
	multimesh.mesh = main_mesh
	
	multimesh.use_colors = true
	
	# Then resize (otherwise, changing the format is not allowed).
	multimesh.instance_count = 2
	# Maybe not all of them should be visible at first.
	multimesh.visible_instance_count = 2

	# Set the transform of the instances.
	for i in multimesh.visible_instance_count:
		multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(i * 1, 0, 0)))
	multimesh.set_instance_color(0,Color8(1,0,0))
	multimesh.set_instance_color(1,Color8(2,0,0))
