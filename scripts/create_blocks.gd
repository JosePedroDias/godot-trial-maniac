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
	var flat_width = ROAD_WIDTH - radius
	if flat_width < 0: flat_width = 2.0
	
	var half_len = length / 2.0
	var side_sign = 1.0 if is_right else -1.0
	
	# 1. Flat Road Part
	st.set_color(color)
	var f_x_start = -ROAD_WIDTH / 2.0 if is_right else (ROAD_WIDTH / 2.0 - flat_width)
	var f_x_end = f_x_start + flat_width
	
	var v_f0 = Vector3(f_x_start, 0, -half_len)
	var v_f1 = Vector3(f_x_end, 0, -half_len)
	var v_f2 = Vector3(f_x_end, 0, half_len)
	var v_f3 = Vector3(f_x_start, 0, half_len)
	_add_quad(st, v_f0, v_f1, v_f2, v_f3, Vector3.UP)
	_add_quad(st, v_f3 - Vector3(0, ROAD_THICKNESS, 0), v_f2 - Vector3(0, ROAD_THICKNESS, 0), v_f1 - Vector3(0, ROAD_THICKNESS, 0), v_f0 - Vector3(0, ROAD_THICKNESS, 0), Vector3.DOWN)
	
	var flat_outer_x = f_x_start if is_right else f_x_end
	var n_flat_outer = Vector3.LEFT if is_right else Vector3.RIGHT
	_add_quad(st, Vector3(flat_outer_x, 0, half_len), Vector3(flat_outer_x, 0, -half_len), Vector3(flat_outer_x, -ROAD_THICKNESS, -half_len), Vector3(flat_outer_x, -ROAD_THICKNESS, half_len), n_flat_outer)

	# 2. Pipe Arc Part
	var arc_x_center = f_x_end if is_right else f_x_start
	var arc_y_center = radius
	
	for i in range(segments):
		var a0 = (float(i) / segments) * angle_rad
		var a1 = (float(i + 1) / segments) * angle_rad
		
		var s0 = sin(a0); var c0 = cos(a0)
		var s1 = sin(a1); var c1 = cos(a1)
		
		var x0_i = arc_x_center + side_sign * radius * s0
		var y0_i = arc_y_center - radius * c0
		var x1_i = arc_x_center + side_sign * radius * s1
		var y1_i = arc_y_center - radius * c1
		
		var r_out = radius + WALL_THICKNESS
		var x0_o = arc_x_center + side_sign * r_out * s0
		var y0_o = arc_y_center - r_out * c0
		var x1_o = arc_x_center + side_sign * r_out * s1
		var y1_o = arc_y_center - r_out * c1
		
		var v0_i = Vector3(x0_i, y0_i, -half_len); var v1_i = Vector3(x1_i, y1_i, -half_len)
		var v2_i = Vector3(x1_i, y1_i, half_len); var v3_i = Vector3(x0_i, y0_i, half_len)
		
		var v0_o = Vector3(x0_o, y0_o, -half_len); var v1_o = Vector3(x1_o, y1_o, -half_len)
		var v2_o = Vector3(x1_o, y1_o, half_len); var v3_o = Vector3(x0_o, y0_o, half_len)
		
		var n0 = Vector3(side_sign * s0, -c0, 0).normalized()
		var n1 = Vector3(side_sign * s1, -c1, 0).normalized()
		var n_avg = (n0 + n1).normalized()
		
		st.set_color(color)
		if is_right:
			_add_quad(st, v0_i, v1_i, v2_i, v3_i, -n_avg)
			_add_quad(st, v3_o, v2_o, v1_o, v0_o, n_avg)
		else:
			_add_quad(st, v1_i, v0_i, v3_i, v2_i, -n_avg)
			_add_quad(st, v0_o, v1_o, v2_o, v3_o, n_avg)
			
		if i == segments - 1:
			st.set_color(wall_color)
			var n_rim = Vector3(side_sign * sin(angle_rad), -cos(angle_rad), 0).normalized()
			if is_right:
				_add_quad(st, v1_i, v1_o, v2_o, v2_i, -n_rim)
			else:
				_add_quad(st, v1_o, v1_i, v2_i, v2_o, -n_rim)

	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = st.commit()
	return mesh_node

func _create_loop_mesh(radius: float, angle_deg: float, road_width: float, color: Color) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	st.set_material(mat)
	
	var segments = 64
	var angle_rad = deg_to_rad(angle_deg)
	var half_w = road_width / 2.0
	
	for i in range(segments):
		var a0 = (float(i) / segments) * angle_rad
		var a1 = (float(i + 1) / segments) * angle_rad
		
		# In a loop, we are essentially building a cylinder surface
		# We'll orient it so it's a vertical loop (around X axis)
		# z = r * sin(a), y = r - r * cos(a)
		
		var s0 = sin(a0); var c0 = cos(a0)
		var s1 = sin(a1); var c1 = cos(a1)
		
		var r_in = radius
		var r_out = radius + ROAD_THICKNESS
		
		# Inner surface (where car drives)
		var v0 = Vector3(-half_w, r_in - r_in * c0, r_in * s0)
		var v1 = Vector3(half_w, r_in - r_in * c0, r_in * s0)
		var v2 = Vector3(half_w, r_in - r_in * c1, r_in * s1)
		var v3 = Vector3(-half_w, r_in - r_in * c1, r_in * s1)
		
		# Outer surface
		var v0b = Vector3(-half_w, r_out - r_out * c0, r_out * s0)
		var v1b = Vector3(half_w, r_out - r_out * c0, r_out * s0)
		var v2b = Vector3(half_w, r_out - r_out * c1, r_out * s1)
		var v3b = Vector3(-half_w, r_out - r_out * c1, r_out * s1)
		
		var n_avg = Vector3(0, -cos((a0+a1)/2.0), sin((a0+a1)/2.0)).normalized()
		
		# Drive surface (inward facing normal)
		_add_quad(st, v0, v1, v2, v3, -n_avg)
		# Back surface (outward facing normal)
		_add_quad(st, v3b, v2b, v1b, v0b, n_avg)
		
		# Sides
		var n_side_l = Vector3.LEFT
		var n_side_r = Vector3.RIGHT
		_add_quad(st, v0b, v0, v3, v3b, n_side_l)
		_add_quad(st, v1, v1b, v2b, v2, n_side_r)

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

func _save_block(name: String, type_idx: int, color: Color, color2: Color, size: Vector3 = Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_LENGTH), extra_node: Node = null, rotation: Vector3 = Vector3.ZERO, custom_mesh: MeshInstance3D = null, has_walls: bool = true):
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
		
	if !custom_mesh and has_walls:
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
	_save_block("RoadStraightLongNoWalls", 11, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, ROAD_LENGTH * 4.0), null, Vector3.ZERO, null, false)
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

	# Loops
	var loop360_mesh = _create_loop_mesh(24.0, 360.0, ROAD_WIDTH, road_color)
	_save_block("RoadLoop360", 12, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, 24.0 * 2.0), null, Vector3.ZERO, loop360_mesh)
	
	var loop90_mesh = _create_loop_mesh(24.0, 90.0, ROAD_WIDTH, road_color)
	_save_block("RoadLoop90", 13, road_color, side_color, Vector3(ROAD_WIDTH, ROAD_THICKNESS, 24.0), null, Vector3.ZERO, loop90_mesh)

	print("Successfully updated block scenes with loops")
	call_deferred("quit")
