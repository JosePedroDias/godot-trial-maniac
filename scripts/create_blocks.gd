extends SceneTree

const MeshTurtle = preload("res://scripts/mesh_turtle.gd")

const ROAD_WIDTH = 8.0
const ROAD_LENGTH = 4.0
const ROAD_THICKNESS = 0.4 
const WALL_HEIGHT = 0.25
const WALL_THICKNESS = 0.1

func _create_turtle(color: Color = Color(0.2, 0.2, 0.2)) -> MeshTurtle:
	var turtle = MeshTurtle.new()
	# Convention: Road surface at Y=0, walls ABOVE, thickness BELOW.
	var res = MeshTurtle.create_road_profile(ROAD_WIDTH, ROAD_THICKNESS, WALL_HEIGHT, color)
	turtle.set_profile(res.points, res.colors)
	# Start at (0,0,0) facing -Z (Identity)
	return turtle

func _create_straight(length: float, color: Color) -> MeshInstance3D:
	var turtle = _create_turtle(color)
	turtle.move_and_extrude(length)
	
	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = turtle.commit_mesh()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh_node.material_override = mat
	return mesh_node

func _create_curve(radius: float, angle_deg: float, is_left: bool, color: Color) -> MeshInstance3D:
	var turtle = _create_turtle(color)
	var center_radius = radius + ROAD_WIDTH/2.0
	var arc_len = deg_to_rad(abs(angle_deg)) * center_radius
	
	# Turn Left (positive yaw) or Right (negative yaw)
	var yaw = angle_deg if is_left else -angle_deg
	turtle.smooth_step(yaw, 0, 0, arc_len, 32)
	
	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = turtle.commit_mesh()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh_node.material_override = mat
	return mesh_node

func _create_loop(radius: float, angle_deg: float, color: Color) -> MeshInstance3D:
	var turtle = _create_turtle(color)
	var arc_len = deg_to_rad(abs(angle_deg)) * radius
	turtle.smooth_step(0, angle_deg, 0, arc_len, 48)
		
	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = turtle.commit_mesh()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh_node.material_override = mat
	return mesh_node

func _create_gate(color: Color) -> Node3D:
	var gate = Node3D.new()
	gate.name = "Gate"
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	
	var left = MeshInstance3D.new()
	left.mesh = BoxMesh.new(); left.mesh.size = Vector3(0.1, 2, 0.1); left.mesh.material = mat
	left.position = Vector3(-(ROAD_WIDTH/2.0 + 0.15), 1, 0)
	gate.add_child(left)
	
	var right = MeshInstance3D.new()
	right.mesh = BoxMesh.new(); right.mesh.size = Vector3(0.1, 2, 0.1); right.mesh.material = mat
	right.position = Vector3(ROAD_WIDTH/2.0 + 0.15, 1, 0)
	gate.add_child(right)
	
	var top = MeshInstance3D.new()
	top.mesh = BoxMesh.new(); top.mesh.size = Vector3(ROAD_WIDTH + 0.3, 0.1, 0.1); top.mesh.material = mat
	top.position = Vector3(0, 2, 0)
	gate.add_child(top)
	
	var area = Area3D.new()
	area.name = "DetectionArea"
	var col = CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(ROAD_WIDTH, 3.0, 0.5)
	area.add_child(col)
	# Center at Y=1.5 with height 3.0 means it covers Y=[0, 3]
	area.position = Vector3(0, 1.5, 0)
	gate.add_child(area)
	
	return gate

func _save_block(name: String, type_idx: int, mesh_node: MeshInstance3D, extra: Node = null):
	var root = StaticBody3D.new()
	root.name = name
	root.set_script(load("res://scripts/track_block.gd"))
	root.type = type_idx
	
	root.add_child(mesh_node)
	mesh_node.owner = root
	
	var col = CollisionShape3D.new()
	col.shape = mesh_node.mesh.create_trimesh_shape()
	root.add_child(col)
	col.owner = root
	
	if extra:
		root.add_child(extra)
		extra.owner = root
		for child in extra.get_children():
			child.owner = root
			for grandchild in child.get_children():
				grandchild.owner = root

	var packed = PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/blocks/" + name + ".tscn")
	print("Saved block: ", name)
	root.free()

func _create_ramp(length: float, angle_deg: float, color: Color) -> MeshInstance3D:
	var turtle = _create_turtle(color)
	# Start slightly inclined to match previous block connection point?
	# Actually, if we want it to start at Y=0, we just turn and move.
	turtle.turn_up(angle_deg)
	turtle.move_and_extrude(length)
	
	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = turtle.commit_mesh()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh_node.material_override = mat
	return mesh_node

func _create_side_pipe(length: float, color: Color) -> MeshInstance3D:
	var turtle = MeshTurtle.new()
	# A pipe profile: 8 points in a circle
	var p: Array[Vector2] = []
	var c: Array[Color] = []
	var radius = ROAD_WIDTH / 2.0
	for i in range(9):
		var a = float(i) * PI * 2.0 / 8.0
		p.append(Vector2(cos(a) * radius, sin(a) * radius + radius)) # Bottom at Y=0
		c.append(color)
	
	turtle.set_profile(p, c)
	turtle.move_and_extrude(length)
	
	var mesh_node = MeshInstance3D.new()
	mesh_node.mesh = turtle.commit_mesh()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh_node.material_override = mat
	return mesh_node

func _init():
	var road_color = Color(0.2, 0.2, 0.2)
	var booster_color = Color(1.0, 0.7, 0.1)
	var start_color = Color(0.1, 0.8, 0.1)
	var finish_color = Color(0.8, 0.1, 0.1)
	
	_save_block("RoadStraight", 0, _create_straight(ROAD_LENGTH, road_color))
	_save_block("RoadStraightLong", 7, _create_straight(ROAD_LENGTH * 4.0, road_color))
	_save_block("RoadStraightLongNoWalls", 10, _create_straight(ROAD_LENGTH * 4.0, road_color)) # Should technically have no walls, but for now...
	_save_block("RoadBooster", 3, _create_straight(ROAD_LENGTH, booster_color))
	
	_save_block("RoadStart", 1, _create_straight(ROAD_LENGTH, road_color), _create_gate(start_color))
	_save_block("RoadFinish", 2, _create_straight(ROAD_LENGTH, road_color), _create_gate(finish_color))
	
	_save_block("RoadCurveTightRight", 5, _create_curve(2.0, 90, false, road_color))
	_save_block("RoadCurveTightLeft", 5, _create_curve(2.0, 90, true, road_color))
	
	_save_block("RoadCurveWideRight", 6, _create_curve(ROAD_WIDTH + 2.0, 90, false, road_color))
	_save_block("RoadCurveWideLeft", 6, _create_curve(ROAD_WIDTH + 2.0, 90, true, road_color))
	
	_save_block("RoadCurveExtraWideRight", 8, _create_curve(ROAD_WIDTH * 2.0 + 2.0, 90, false, road_color))
	_save_block("RoadCurveExtraWideLeft", 8, _create_curve(ROAD_WIDTH * 2.0 + 2.0, 90, true, road_color))
	
	_save_block("RoadRamp", 4, _create_ramp(ROAD_LENGTH * 2.0, 15, road_color))
	_save_block("RoadSidePipe", 9, _create_side_pipe(ROAD_LENGTH * 2.0, road_color))
	
	_save_block("RoadLoop90", 12, _create_loop(24.0, 90, road_color))
	_save_block("RoadLoop360", 11, _create_loop(24.0, 360, road_color))
	
	print("Block regeneration complete.")
	call_deferred("quit")
