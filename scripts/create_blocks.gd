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

func _create_curved_road_mesh(inner_radius: float, outer_radius: float, color: Color) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	st.set_material(mat)
	
	var segments = 16
	var height = 0.2
	
	for i in range(segments + 1):
		var angle = (float(i) / segments) * (PI / 2.0)
		var c = cos(angle)
		var s = sin(angle)
		
		var v_inner = Vector3(c * inner_radius, 0, s * inner_radius)
		var v_outer = Vector3(c * outer_radius, 0, s * outer_radius)
		
		# UVs
		var u = float(i) / segments
		
		st.set_uv(Vector2(u, 0))
		st.add_vertex(v_inner)
		st.set_uv(Vector2(u, 1))
		st.add_vertex(v_outer)
		
		# Bottom face
		st.set_uv(Vector2(u, 0))
		st.add_vertex(v_inner - Vector3(0, height, 0))
		st.set_uv(Vector2(u, 1))
		st.add_vertex(v_outer - Vector3(0, height, 0))

	# Indices for Top face
	for i in range(segments):
		var i0 = i * 4
		var i1 = i0 + 1
		var i2 = (i + 1) * 4
		var i3 = i2 + 1
		
		# Top
		st.add_index(i0)
		st.add_index(i2)
		st.add_index(i1)
		
		st.add_index(i1)
		st.add_index(i2)
		st.add_index(i3)
		
		# Bottom
		st.add_index(i0 + 2)
		st.add_index(i1 + 2)
		st.add_index(i2 + 2)
		
		st.add_index(i1 + 2)
		st.add_index(i3 + 2)
		st.add_index(i2 + 2)
		
		# Inner side
		st.add_index(i0)
		st.add_index(i0 + 2)
		st.add_index(i2)
		
		st.add_index(i2)
		st.add_index(i0 + 2)
		st.add_index(i2 + 2)
		
		# Outer side
		st.add_index(i1)
		st.add_index(i3)
		st.add_index(i1 + 2)
		
		st.add_index(i3)
		st.add_index(i3 + 2)
		st.add_index(i1 + 2)

	st.generate_normals()
	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = st.commit()
	return mesh_node

func _create_gate(color: Color) -> Node3D:
	var gate = Node3D.new()
	gate.name = "Gate"
	var left = _create_mesh(Vector3(0.1, 2, 0.1), color)
	left.position = Vector3(-1.95, 1, 0)
	gate.add_child(left)
	var right = _create_mesh(Vector3(0.1, 2, 0.1), color)
	right.position = Vector3(1.95, 1, 0)
	gate.add_child(right)
	var top = _create_mesh(Vector3(4, 0.1, 0.1), color)
	top.position = Vector3(0, 2, 0)
	gate.add_child(top)
	return gate

func _save_block(name: String, type_idx: int, color: Color, size: Vector3 = Vector3(4, 0.2, 2), extra_node: Node = null, rotation: Vector3 = Vector3.ZERO, custom_mesh: MeshInstance3D = null):
	var root = StaticBody3D.new()
	root.name = name
	root.set_script(load("res://scripts/track_block.gd"))
	root.type = type_idx
	
	var mesh = custom_mesh
	if !mesh:
		mesh = _create_mesh(size, color, (2.0 if type_idx == 3 else 0.0))
	
	root.add_child(mesh)
	mesh.owner = root
	mesh.rotation_degrees = rotation
	
	if rotation.x != 0:
		mesh.position.y = size.z * sin(deg_to_rad(abs(rotation.x))) / 2.0
	
	var col = CollisionShape3D.new()
	if custom_mesh:
		col.shape = custom_mesh.mesh.create_trimesh_shape()
	else:
		var shape = BoxShape3D.new()
		shape.size = size
		col.shape = shape
	
	root.add_child(col)
	col.owner = root
	col.rotation_degrees = rotation
	if rotation.x != 0:
		col.position.y = mesh.position.y
	
	if extra_node:
		root.add_child(extra_node)
		extra_node.owner = root
		for child in extra_node.get_children():
			child.owner = root
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/blocks/" + name + ".tscn")

func _init():
	var dir = DirAccess.open("res://")
	dir.make_dir_recursive("scenes/blocks")
	
	var road_color = Color(0.2, 0.2, 0.2)
	
	_save_block("RoadStraight", 0, road_color)
	_save_block("RoadStart", 1, road_color, Vector3(4, 0.2, 2), _create_gate(Color(0.1, 0.8, 0.1)))
	_save_block("RoadFinish", 2, road_color, Vector3(4, 0.2, 2), _create_gate(Color(0.8, 0.1, 0.1)))
	_save_block("RoadBooster", 3, Color(1, 0.8, 0.1))
	_save_block("RoadRamp", 4, Color(0.3, 0.3, 0.3), Vector3(4, 0.2, 4), null, Vector3(-15, 0, 0))
	
	# Proper Curved Blocks
	var tight_mesh = _create_curved_road_mesh(0.0, 4.0, road_color)
	_save_block("RoadCurveTight", 5, road_color, Vector3(4, 0.2, 4), null, Vector3.ZERO, tight_mesh)
	
	var wide_mesh = _create_curved_road_mesh(4.0, 8.0, road_color)
	_save_block("RoadCurveWide", 6, road_color, Vector3(8, 0.2, 8), null, Vector3.ZERO, wide_mesh)
	
	print("Successfully updated and created proper curved block scenes")
	quit()
