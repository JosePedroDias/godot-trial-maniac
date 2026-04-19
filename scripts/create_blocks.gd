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

func _create_curved_road_mesh(inner_radius: float, outer_radius: float, color: Color, color2: Color) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true # Enable vertex colors
	st.set_material(mat)
	
	var segments = 16
	var h = 0.1 # Half height of road
	var wh = 0.5 # Wall height (above road)
	var wt = 0.1 # Wall thickness
	var wall_color = color2
	
	for i in range(segments):
		var a0 = (float(i) / segments) * (PI / 2.0)
		var a1 = (float(i + 1) / segments) * (PI / 2.0)
		
		var c0 = cos(a0); var s0 = sin(a0)
		var c1 = cos(a1); var s1 = sin(a1)
		
		# Road top surface radii
		var r_in = inner_radius
		var r_out = outer_radius
		
		# Road Verts
		var v_in0 = Vector3(c0 * r_in, 0, s0 * r_in)
		var v_out0 = Vector3(c0 * r_out, 0, s0 * r_out)
		var v_in1 = Vector3(c1 * r_in, 0, s1 * r_in)
		var v_out1 = Vector3(c1 * r_out, 0, s1 * r_out)
		
		# Road Bottom Verts
		var v_in0_b = v_in0 - Vector3(0, 2*h, 0)
		var v_out0_b = v_out0 - Vector3(0, 2*h, 0)
		var v_in1_b = v_in1 - Vector3(0, 2*h, 0)
		var v_out1_b = v_out1 - Vector3(0, 2*h, 0)

		# 1. Road Faces
		st.set_color(color)
		_add_quad(st, v_in0, v_out0, v_out1, v_in1, Vector3.UP)
		_add_quad(st, v_out0_b, v_in0_b, v_in1_b, v_out1_b, Vector3.DOWN)
		
		# 2. Outer Wall
		var n_out = Vector3(cos((a0+a1)/2.0), 0, sin((a0+a1)/2.0))
		var r_wall_out = r_out + wt
		
		# Wall Verts (Outer side)
		var v_o0 = v_out0
		var v_o1 = v_out1
		var v_o0_w = v_o0 + Vector3(0, wh, 0)
		var v_o1_w = v_o1 + Vector3(0, wh, 0)
		var v_oe0 = Vector3(c0 * r_wall_out, 0, s0 * r_wall_out)
		var v_oe1 = Vector3(c1 * r_wall_out, 0, s1 * r_wall_out)
		var v_oe0_w = v_oe0 + Vector3(0, wh, 0)
		var v_oe1_w = v_oe1 + Vector3(0, wh, 0)
		
		st.set_color(wall_color)
		_add_quad(st, v_o1, v_o0, v_o0_w, v_o1_w, -n_out) # Road side face
		_add_quad(st, v_oe0, v_oe1, v_oe1_w, v_oe0_w, n_out) # External face
		_add_quad(st, v_o0_w, v_oe0_w, v_oe1_w, v_o1_w, Vector3.UP) # Top face
		
		# 3. Inner Wall (only if inner_radius > 0.1 to avoid artifacts at center)
		if r_in > 0.1:
			var n_in = -n_out
			var r_wall_in = r_in - wt
			
			var v_i0 = v_in0
			var v_i1 = v_in1
			var v_i0_w = v_i0 + Vector3(0, wh, 0)
			var v_i1_w = v_i1 + Vector3(0, wh, 0)
			var v_ie0 = Vector3(c0 * r_wall_in, 0, s0 * r_wall_in)
			var v_ie1 = Vector3(c1 * r_wall_in, 0, s1 * r_wall_in)
			var v_ie0_w = v_ie0 + Vector3(0, wh, 0)
			var v_ie1_w = v_ie1 + Vector3(0, wh, 0)
			
			st.set_color(wall_color)
			_add_quad(st, v_i0, v_i1, v_i1_w, v_i0_w, -n_in) # Road side face
			_add_quad(st, v_ie1, v_ie0, v_ie0_w, v_ie1_w, n_in) # External face
			_add_quad(st, v_i1_w, v_ie1_w, v_ie0_w, v_i0_w, Vector3.UP) # Top face
		else:
			# If radius is 0, just add a small center post or face
			st.set_color(color)
			_add_quad(st, v_in1, v_in0, v_in0 - Vector3(0, 2*h, 0), v_in1 - Vector3(0, 2*h, 0), -n_out)

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

func _save_block(name: String, type_idx: int, color: Color, color2: Color, size: Vector3 = Vector3(4, 0.2, 2), extra_node: Node = null, rotation: Vector3 = Vector3.ZERO, custom_mesh: MeshInstance3D = null):
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
	
	# Global Y offset
	if custom_mesh:
		mesh.position.y = 0.5
	elif rotation.x != 0:
		mesh.position.y = 0.5 + (size.z * sin(deg_to_rad(abs(rotation.x))) / 2.0)
	else:
		mesh.position.y = 0.5
		
	# Add side walls for non-custom meshes (Straight pieces)
	if !custom_mesh:
		var wall_h = 0.5
		var wall_t = 0.1
		var wall_color = color2
		for i in [-1, 1]:
			var wall = _create_mesh(Vector3(wall_t, wall_h, size.z), wall_color)
			root.add_child(wall)
			wall.owner = root
			# Position relative to road, then rotated
			var local_pos = Vector3(i * (size.x/2.0 + wall_t/2.0), wall_h/2.0 + size.y/2.0, 0)
			wall.position = mesh.position + local_pos.rotated(Vector3.RIGHT, deg_to_rad(rotation.x))
			wall.rotation_degrees = rotation
			
			var wall_col = CollisionShape3D.new()
			var wall_shape = BoxShape3D.new()
			wall_shape.size = Vector3(wall_t, wall_h, size.z)
			wall_col.shape = wall_shape
			root.add_child(wall_col)
			wall_col.owner = root
			wall_col.position = wall.position
			wall_col.rotation_degrees = rotation
	
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
	
	# Cleanup memory to prevent RID leaks
	root.free()

func _init():
	var dir = DirAccess.open("res://")
	dir.make_dir_recursive("scenes/blocks")
	
	var road_color = Color(0.2, 0.2, 0.2)
	var side_color = Color(road_color).lightened(0.2)
	var start_color = Color(0.1, 0.8, 0.1)
	var finish_color = Color(0.8, 0.1, 0.1)
	var booster_color = Color(1, 0.8, 0.1)
	
	_save_block("RoadStraight", 0, road_color, side_color)
	_save_block("RoadStart", 1, road_color, side_color, Vector3(4, 0, 2), _create_gate(start_color))
	_save_block("RoadFinish", 2, road_color, side_color, Vector3(4, 0, 2), _create_gate(finish_color))
	_save_block("RoadBooster", 3, booster_color, side_color)
	_save_block("RoadRamp", 4, road_color, side_color, Vector3(4, 0, 4), null, Vector3(-15, 0, 0))
	
	var tight_mesh = _create_curved_road_mesh(0.0, 4.0, road_color, side_color)
	_save_block("RoadCurveTight", 5, road_color, side_color, Vector3(4, 0, 4), null, Vector3.ZERO, tight_mesh)
	
	var wide_mesh = _create_curved_road_mesh(4.0, 8.0, road_color, side_color)
	_save_block("RoadCurveWide", 6, road_color, side_color, Vector3(8, 0, 8), null, Vector3.ZERO, wide_mesh)
	
	print("Successfully updated block scenes with thickness and fixed shading")
	quit()
