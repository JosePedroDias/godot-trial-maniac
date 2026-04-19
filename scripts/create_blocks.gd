extends SceneTree

const ROAD_WIDTH = 8.0
const ROAD_LENGTH = 4.0
const ROAD_THICKNESS = 0.2
const WALL_HEIGHT = 0.25
const WALL_THICKNESS = 0.1

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
	mat.vertex_color_use_as_albedo = true
	st.set_material(mat)
	
	var segments = 16
	var h = ROAD_THICKNESS / 2.0
	var wh = WALL_HEIGHT
	var wt = WALL_THICKNESS
	var wall_color = color2
	
	for i in range(segments):
		var a0 = (float(i) / segments) * (PI / 2.0)
		var a1 = (float(i + 1) / segments) * (PI / 2.0)
		
		var c0 = cos(a0); var s0 = sin(a0)
		var c1 = cos(a1); var s1 = sin(a1)
		
		var r_in = inner_radius
		var r_out = outer_radius
		
		var v_in0 = Vector3(c0 * r_in, 0, s0 * r_in)
		var v_out0 = Vector3(c0 * r_out, 0, s0 * r_out)
		var v_in1 = Vector3(c1 * r_in, 0, s1 * r_in)
		var v_out1 = Vector3(c1 * r_out, 0, s1 * r_out)
		
		var v_in0_b = v_in0 - Vector3(0, ROAD_THICKNESS, 0)
		var v_out0_b = v_out0 - Vector3(0, ROAD_THICKNESS, 0)
		var v_in1_b = v_in1 - Vector3(0, ROAD_THICKNESS, 0)
		var v_out1_b = v_out1 - Vector3(0, ROAD_THICKNESS, 0)

		# 1. Road Faces
		st.set_color(color)
		_add_quad(st, v_in0, v_out0, v_out1, v_in1, Vector3.UP)
		_add_quad(st, v_out0_b, v_in0_b, v_in1_b, v_out1_b, Vector3.DOWN)
		
		# 2. Outer Wall
		var n_out = Vector3(cos((a0+a1)/2.0), 0, sin((a0+a1)/2.0))
		var r_wall_out = r_out + wt
		
		var v_o0 = v_out0
		var v_o1 = v_out1
		var v_o0_w = v_o0 + Vector3(0, wh, 0)
		var v_o1_w = v_o1 + Vector3(0, wh, 0)
		var v_oe0 = Vector3(c0 * r_wall_out, 0, s0 * r_wall_out)
		var v_oe1 = Vector3(c1 * r_wall_out, 0, s1 * r_wall_out)
		var v_oe0_w = v_oe0 + Vector3(0, wh, 0)
		var v_oe1_w = v_oe1 + Vector3(0, wh, 0)
		
		st.set_color(wall_color)
		_add_quad(st, v_o1, v_o0, v_o0_w, v_o1_w, -n_out)
		_add_quad(st, v_oe0, v_oe1, v_oe1_w, v_oe0_w, n_out)
		_add_quad(st, v_o0_w, v_oe0_w, v_oe1_w, v_o1_w, Vector3.UP)
		
		# 3. Inner Wall
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
			_add_quad(st, v_i0, v_i1, v_i1_w, v_i0_w, -n_in)
			_add_quad(st, v_ie1, v_ie0, v_ie0_w, v_ie1_w, n_in)
			_add_quad(st, v_i1_w, v_ie1_w, v_ie0_w, v_i0_w, Vector3.UP)
		else:
			st.set_color(color)
			_add_quad(st, v_in1, v_in0, v_in0 - Vector3(0, ROAD_THICKNESS, 0), v_in1 - Vector3(0, ROAD_THICKNESS, 0), -n_out)

	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = st.commit()
	return mesh_node

func _create_side_pipe_mesh(radius: float, angle_deg: float, length: float, is_right: bool, color: Color, wall_color: Color) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	st.set_material(mat)
	
	var segments = 16
	var angle_rad = deg_to_rad(angle_deg)
	var flat_width = ROAD_WIDTH - radius # Width of the flat part
	if flat_width < 0: flat_width = 2.0 # Fallback
	
	var half_len = length / 2.0
	
	# 1. Flat Road Part
	st.set_color(color)
	var f_x_start = -ROAD_WIDTH / 2.0 if is_right else (ROAD_WIDTH / 2.0 - flat_width)
	var f_x_end = f_x_start + flat_width
	
	var v_f0 = Vector3(f_x_start, 0, -half_len)
	var v_f1 = Vector3(f_x_end, 0, -half_len)
	var v_f2 = Vector3(f_x_end, 0, half_len)
	var v_f3 = Vector3(f_x_start, 0, half_len)
	_add_quad(st, v_f0, v_f1, v_f2, v_f3, Vector3.UP)
	
	# 1b. Flat Underneath
	_add_quad(st, v_f3 - Vector3(0, ROAD_THICKNESS, 0), v_f2 - Vector3(0, ROAD_THICKNESS, 0), v_f1 - Vector3(0, ROAD_THICKNESS, 0), v_f0 - Vector3(0, ROAD_THICKNESS, 0), Vector3.DOWN)
	
	# 1c. Left/Right outer wall for the flat part
	var flat_wall_x = f_x_start if is_right else f_x_end
	var n_wall = Vector3.LEFT if is_right else Vector3.RIGHT
	var v_w0 = Vector3(flat_wall_x, 0, -half_len)
	var v_w1 = Vector3(flat_wall_x, 0, half_len)
	var v_w0_w = v_w0 + Vector3(0, WALL_HEIGHT, 0)
	var v_w1_w = v_w1 + Vector3(0, WALL_HEIGHT, 0)
	var v_we0 = v_w0 + n_wall * WALL_THICKNESS
	var v_we1 = v_w1 + n_wall * WALL_THICKNESS
	var v_we0_w = v_we0 + Vector3(0, WALL_HEIGHT, 0)
	var v_we1_w = v_we1 + Vector3(0, WALL_HEIGHT, 0)
	
	st.set_color(wall_color)
	_add_quad(st, v_w1, v_w0, v_w0_w, v_w1_w, -n_wall)
	_add_quad(st, v_we0, v_we1, v_we1_w, v_we0_w, n_wall)
	_add_quad(st, v_w0_w, v_we0_w, v_we1_w, v_w1_w, Vector3.UP)

	# 2. Pipe Arc Part
	var arc_x_center = f_x_end if is_right else f_x_start
	var arc_y_center = radius
	
	for i in range(segments):
		var a0 = (float(i) / segments) * angle_rad
		var a1 = (float(i + 1) / segments) * angle_rad
		
		# For right: arc goes from alpha=0 (bottom) to alpha=90 (right)
		# x = center + radius * sin(alpha), y = center - radius * cos(alpha)
		# For left: arc goes from alpha=0 (bottom) to alpha=90 (left)
		# x = center - radius * sin(alpha), y = center - radius * cos(alpha)
		
		var s0 = sin(a0); var c0 = cos(a0)
		var s1 = sin(a1); var c1 = cos(a1)
		
		var side_sign = 1.0 if is_right else -1.0
		
		var x0 = arc_x_center + side_sign * radius * s0
		var y0 = arc_y_center - radius * c0
		var x1 = arc_x_center + side_sign * radius * s1
		var y1 = arc_y_center - radius * c1
		
		var v_a0 = Vector3(x0, y0, -half_len)
		var v_a1 = Vector3(x1, y1, -half_len)
		var v_a2 = Vector3(x1, y1, half_len)
		var v_a3 = Vector3(x0, y0, half_len)
		
		var v_a0_b = v_a0 - Vector3(0, ROAD_THICKNESS, 0)
		var v_a1_b = v_a1 - Vector3(0, ROAD_THICKNESS, 0)
		var v_a2_b = v_a2 - Vector3(0, ROAD_THICKNESS, 0)
		var v_a3_b = v_a3 - Vector3(0, ROAD_THICKNESS, 0)
		
		var n0 = Vector3(side_sign * s0, -c0, 0).normalized()
		var n1 = Vector3(side_sign * s1, -c1, 0).normalized()
		var n_avg = (n0 + n1).normalized()
		
		st.set_color(color)
		if is_right:
			_add_quad(st, v_a0, v_a1, v_a2, v_a3, -n_avg)
			_add_quad(st, v_a3_b, v_a2_b, v_a1_b, v_a0_b, n_avg)
		else:
			_add_quad(st, v_a1, v_a0, v_a3, v_a2, -n_avg)
			_add_quad(st, v_a0_b, v_a1_b, v_a2_b, v_a3_b, n_avg)
			
		# Add end wall at the top of the arc
		if i == segments - 1:
			var n_end = Vector3(side_sign * sin(angle_rad), -cos(angle_rad), 0).normalized()
			var v_top0 = v_a1
			var v_top1 = v_a2
			var v_top0_w = v_top0 - n_end * WALL_HEIGHT
			var v_top1_w = v_top1 - n_end * WALL_HEIGHT
			var v_tope0 = v_top0 + Vector3(side_sign * WALL_THICKNESS, 0, 0)
			var v_tope1 = v_top1 + Vector3(side_sign * WALL_THICKNESS, 0, 0)
			var v_tope0_w = v_tope0 - n_end * WALL_HEIGHT
			var v_tope1_w = v_tope1 - n_end * WALL_HEIGHT
			
			st.set_color(wall_color)
			if is_right:
				_add_quad(st, v_top0, v_top1, v_top1_w, v_top0_w, Vector3(-sin(angle_rad), cos(angle_rad), 0))
			else:
				_add_quad(st, v_top1, v_top0, v_top0_w, v_top1_w, Vector3(sin(angle_rad), cos(angle_rad), 0))

	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = st.commit()
	return mesh_node

func _create_gate(color: Color) -> Node3D:
	var gate = Node3D.new()
	gate.name = "Gate"
	var left = _create_mesh(Vector3(0.1, 2, 0.1), color)
	left.position = Vector3(-(ROAD_WIDTH/2.0 - 0.05), 1, 0)
	gate.add_child(left)
	var right = _create_mesh(Vector3(0.1, 2, 0.1), color)
	right.position = Vector3(ROAD_WIDTH/2.0 - 0.05, 1, 0)
	gate.add_child(right)
	var top = _create_mesh(Vector3(ROAD_WIDTH, 0.1, 0.1), color)
	top.position = Vector3(0, 2, 0)
	gate.add_child(top)
	return gate

func _save_block(name: String, type_idx: int, color: Color, color2: Color, size: Vector3 = Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_LENGTH), extra_node: Node = null, rotation: Vector3 = Vector3.ZERO, custom_mesh: MeshInstance3D = null):
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
	
	if custom_mesh:
		mesh.position.y = 0.5
	elif rotation.x != 0:
		mesh.position.y = 0.5 + (size.z * sin(deg_to_rad(abs(rotation.x))) / 2.0)
	else:
		mesh.position.y = 0.5
		
	if !custom_mesh:
		var wall_h = WALL_HEIGHT
		var wall_t = WALL_THICKNESS
		var wall_color = color2
		for i in [-1, 1]:
			var wall = _create_mesh(Vector3(wall_t, wall_h, size.z), wall_color)
			root.add_child(wall)
			wall.owner = root
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
		extra_node.position.y = mesh.position.y
		for child in extra_node.get_children():
			child.owner = root
	
	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/blocks/" + name + ".tscn")
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
	_save_block("RoadStraightLong", 7, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_LENGTH * 4.0))
	_save_block("RoadStart", 1, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_LENGTH), _create_gate(start_color))
	_save_block("RoadFinish", 2, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_LENGTH), _create_gate(finish_color))
	_save_block("RoadBooster", 3, booster_color, side_color)
	_save_block("RoadRamp", 4, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_WIDTH), null, Vector3(-15, 0, 0))
	
	# Curves
	var tight_mesh = _create_curved_road_mesh(2.0, 2.0 + ROAD_WIDTH, road_color, side_color)
	_save_block("RoadCurveTight", 5, road_color, side_color, Vector3(2.0 + ROAD_WIDTH, ROAD_THICKNESS, 2.0 + ROAD_WIDTH), null, Vector3.ZERO, tight_mesh)
	
	var wide_mesh = _create_curved_road_mesh(ROAD_WIDTH + 2.0, ROAD_WIDTH * 2.0 + 2.0, road_color, side_color)
	_save_block("RoadCurveWide", 6, road_color, side_color, Vector3(ROAD_WIDTH * 2.0 + 2.0, ROAD_THICKNESS, ROAD_WIDTH * 2.0 + 2.0), null, Vector3.ZERO, wide_mesh)
	
	var extra_wide_mesh = _create_curved_road_mesh(ROAD_WIDTH * 2.0 + 2.0, ROAD_WIDTH * 3.0 + 2.0, road_color, side_color)
	_save_block("RoadCurveExtraWide", 8, road_color, side_color, Vector3(ROAD_WIDTH * 3.0 + 2.0, ROAD_THICKNESS, ROAD_WIDTH * 3.0 + 2.0), null, Vector3.ZERO, extra_wide_mesh)
	
	# Side Pipes
	var pipe_r_mesh = _create_side_pipe_mesh(6.0, 90.0, 8.0, true, road_color, side_color)
	_save_block("RoadSidePipeRight", 10, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, 8.0), null, Vector3.ZERO, pipe_r_mesh)
	
	var pipe_l_mesh = _create_side_pipe_mesh(6.0, 90.0, 8.0, false, road_color, side_color)
	_save_block("RoadSidePipeLeft", 9, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, 8.0), null, Vector3.ZERO, pipe_l_mesh)

	print("Successfully updated block scenes with side pipes")
	call_deferred("quit")
