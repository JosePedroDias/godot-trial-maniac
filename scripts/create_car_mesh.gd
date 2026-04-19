extends SceneTree

func _create_mesh(mesh: Mesh, color: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	# Add some metallic look for racing feel
	mat.metallic = 0.8
	mat.roughness = 0.2
	mi.mesh.material = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scale
	return mi

func _init():
	var car_node = Node3D.new()
	car_node.name = "OpenSeaterMesh"
	
	var body_color = Color(0.1, 0.3, 0.8) # Racing Blue
	var accent_color = Color(0.1, 0.1, 0.1) # Dark/Carbon
	
	# Main Chassis (Central part)
	var main_box = BoxMesh.new()
	main_box.size = Vector3(0.6, 0.3, 1.2)
	car_node.add_child(_create_mesh(main_box, body_color, Vector3(0, 0, -0.2)))
	
	# Nose (Tapered front)
	var nose_box = BoxMesh.new()
	nose_box.size = Vector3(0.4, 0.2, 1.0)
	car_node.add_child(_create_mesh(nose_box, body_color, Vector3(0, -0.05, 0.8)))
	
	# Cockpit Surround
	var cockpit = BoxMesh.new()
	cockpit.size = Vector3(0.5, 0.15, 0.6)
	car_node.add_child(_create_mesh(cockpit, accent_color, Vector3(0, 0.15, -0.1)))
	
	# Front Wing
	var f_wing = BoxMesh.new()
	f_wing.size = Vector3(1.3, 0.05, 0.3)
	car_node.add_child(_create_mesh(f_wing, accent_color, Vector3(0, -0.1, 1.2)))
	
	# Rear Wing Main
	var r_wing = BoxMesh.new()
	r_wing.size = Vector3(1.1, 0.05, 0.4)
	car_node.add_child(_create_mesh(r_wing, body_color, Vector3(0, 0.3, -1.0)))
	
	# Rear Wing Supports
	var r_supp = BoxMesh.new()
	r_supp.size = Vector3(0.05, 0.4, 0.3)
	car_node.add_child(_create_mesh(r_supp, accent_color, Vector3(0.4, 0.1, -1.0)))
	car_node.add_child(_create_mesh(r_supp, accent_color, Vector3(-0.4, 0.1, -1.0)))
	
	# Sidepods
	var sidepod = BoxMesh.new()
	sidepod.size = Vector3(0.3, 0.25, 0.8)
	car_node.add_child(_create_mesh(sidepod, body_color, Vector3(0.4, -0.05, -0.3)))
	car_node.add_child(_create_mesh(sidepod, body_color, Vector3(-0.4, -0.05, -0.3)))

	var packed = PackedScene.new()
	for child in car_node.get_children():
		child.owner = car_node
		
	packed.pack(car_node)
	ResourceSaver.save(packed, "res://assets/open_seater_mesh.tscn")
	
	print("Created open seater mesh at res://assets/open_seater_mesh.tscn")
	
	car_node.free()
	call_deferred("quit")
