extends SceneTree

func _create_mesh(size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mesh_node = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	box.material = mat
	mesh_node.mesh = box
	return mesh_node

func _create_gate(color: Color) -> Node3D:
	var gate = Node3D.new()
	gate.name = "Gate"
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	
	var left = _create_mesh(Vector3(0.1, 2, 0.1), color)
	left.position = Vector3(-0.95, 1, 0)
	gate.add_child(left)
	
	var right = _create_mesh(Vector3(0.1, 2, 0.1), color)
	right.position = Vector3(0.95, 1, 0)
	gate.add_child(right)
	
	var top = _create_mesh(Vector3(2, 0.1, 0.1), color)
	top.position = Vector3(0, 2, 0)
	gate.add_child(top)
	
	return gate

func _save_block(name: String, type_idx: int, color: Color, extra_node: Node = null):
	var root = StaticBody3D.new()
	root.name = name
	root.set_script(load("res://scripts/track_block.gd"))
	root.type = type_idx
	
	var mesh = _create_mesh(Vector3(2, 0.2, 2), color, (2.0 if type_idx == 3 else 0.0))
	root.add_child(mesh)
	mesh.owner = root
	
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(2, 0.2, 2)
	col.shape = shape
	root.add_child(col)
	col.owner = root
	
	if extra_node:
		root.add_child(extra_node)
		extra_node.owner = root
		# Ensure children of extra_node are also owned for packing
		for child in extra_node.get_children():
			child.owner = root
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/blocks/" + name + ".tscn")

func _init():
	var dir = DirAccess.open("res://")
	dir.make_dir_recursive("scenes/blocks")
	
	_save_block("RoadStraight", 0, Color(0.2, 0.2, 0.2))
	_save_block("RoadStart", 1, Color(0.2, 0.2, 0.2), _create_gate(Color(0.1, 0.8, 0.1)))
	_save_block("RoadFinish", 2, Color(0.2, 0.2, 0.2), _create_gate(Color(0.8, 0.1, 0.1)))
	_save_block("RoadBooster", 3, Color(1, 0.8, 0.1))
	
	# Ramp and Curve need special transforms or meshes, but for the palette let's keep them simple
	_save_block("RoadRamp", 4, Color(0.3, 0.3, 0.3))
	_save_block("RoadCurve", 5, Color(0.2, 0.2, 0.2))
	
	print("Successfully created block scenes in res://scenes/blocks/")
	quit()
