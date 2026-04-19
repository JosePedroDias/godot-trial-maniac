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

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3):
	st.set_normal(normal)
	st.add_vertex(v0)
	st.add_vertex(v1)
	st.add_vertex(v2)
	
	st.set_normal(normal)
	st.add_vertex(v0)
	st.add_vertex(v2)
	st.add_vertex(v3)

func _create_curved_road_mesh(inner_radius: float, outer_radius: float, color: Color) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	st.set_material(mat)
	
	var segments = 16
	var h = 0.1 # Half height
	
	for i in range(segments):
		var a0 = (float(i) / segments) * (PI / 2.0)
		var a1 = (float(i + 1) / segments) * (PI / 2.0)
		
		var c0 = cos(a0); var s0 = sin(a0)
		var c1 = cos(a1); var s1 = sin(a1)
		
		# Top verts
		var v_in0 = Vector3(c0 * inner_radius, 0, s0 * inner_radius)
		var v_out0 = Vector3(c0 * outer_radius, 0, s0 * outer_radius)
		var v_in1 = Vector3(c1 * inner_radius, 0, s1 * inner_radius)
		var v_out1 = Vector3(c1 * outer_radius, 0, s1 * outer_radius)
		
		# Bottom verts
		var v_in0_b = v_in0 - Vector3(0, 2*h, 0)
		var v_out0_b = v_out0 - Vector3(0, 2*h, 0)
		var v_in1_b = v_in1 - Vector3(0, 2*h, 0)
		var v_out1_b = v_out1 - Vector3(0, 2*h, 0)

		# Top: CCW from +Y
		_add_quad(st, v_in0, v_out0, v_out1, v_in1, Vector3.UP)
		
		# Bottom: CCW from -Y
		_add_quad(st, v_out0_b, v_out1_b, v_in1_b, v_in0_b, Vector3.DOWN)
		
		# Inner Side: Facing towards origin
		var n_in = -Vector3(cos((a0+a1)/2.0), 0, sin((a0+a1)/2.0))
		_add_quad(st, v_in0, v_in1, v_in1_b, v_in0_b, n_in)
		
		# Outer Side: Facing away from origin
		var n_out = -n_in
		_add_quad(st, v_out0, v_out0_b, v_out1_b, v_out1, n_out)

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
	
	# Global Y offset as requested
	if custom_mesh:
		mesh.position.y = 0.5
	elif rotation.x != 0:
		mesh.position.y = 0.5 + (size.z * sin(deg_to_rad(abs(rotation.x))) / 2.0)
	else:
		mesh.position.y = 0.5
	
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
	col.position = mesh.position
	
	if extra_node:
		root.add_child(extra_node)
		extra_node.owner = root
		# Adjust gate height to match road
		extra_node.position.y = mesh.position.y
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
	
	var tight_mesh = _create_curved_road_mesh(0.0, 4.0, road_color)
	_save_block("RoadCurveTight", 5, road_color, Vector3(4, 0.2, 4), null, Vector3.ZERO, tight_mesh)
	
	var wide_mesh = _create_curved_road_mesh(4.0, 8.0, road_color)
	_save_block("RoadCurveWide", 6, road_color, Vector3(8, 0.2, 8), null, Vector3.ZERO, wide_mesh)
	
	print("Successfully updated block scenes with 0.5Y offset and fixed shading")
	quit()
