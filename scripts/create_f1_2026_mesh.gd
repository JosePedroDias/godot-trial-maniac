extends Node3D

func create_mesh() -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var body_color = Color(0.1, 0.1, 0.8) # Blue base
	var carbon_color = Color(0.05, 0.05, 0.05)
	
	# Dimensions (meters)
	var length = 5.0 
	var width = 1.9
	var cockpit_w = 0.6
	var nose_w = 0.3
	
	# Simple procedural F1 Body
	# Nose
	_add_box(st, Vector3(0, 0.2, 2.0), Vector3(nose_w, 0.15, 1.0), body_color)
	# Cockpit / Main Body
	_add_box(st, Vector3(0, 0.3, 0.5), Vector3(width * 0.4, 0.4, 1.5), body_color)
	# Sidepods (2026 Style - narrower)
	_add_box(st, Vector3(0.6, 0.25, 0.0), Vector3(0.5, 0.3, 1.2), body_color)
	_add_box(st, Vector3(-0.6, 0.25, 0.0), Vector3(0.5, 0.3, 1.2), body_color)
	# Front Wing
	_add_box(st, Vector3(0, 0.1, 2.4), Vector3(1.9, 0.05, 0.4), carbon_color)
	# Rear Wing (Active Aero style)
	_add_box(st, Vector3(0, 0.6, -1.8), Vector3(1.4, 0.1, 0.5), carbon_color)
	# Endplates
	_add_box(st, Vector3(0.7, 0.5, -1.8), Vector3(0.05, 0.4, 0.6), carbon_color)
	_add_box(st, Vector3(-0.7, 0.5, -1.8), Vector3(0.05, 0.4, 0.6), carbon_color)
	
	st.generate_normals()
	return st.commit()

func _add_box(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color):
	var hs = size / 2.0
	var verts = [
		Vector3(-hs.x, -hs.y, hs.z), Vector3(hs.x, -hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(-hs.x, hs.y, hs.z),
		Vector3(-hs.x, -hs.y, -hs.z), Vector3(hs.x, -hs.y, -hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z)
	]
	for i in range(verts.size()):
		verts[i] += pos
		
	var indices = [
		0, 1, 2, 0, 2, 3, # Front
		1, 5, 6, 1, 6, 2, # Right
		5, 4, 7, 5, 7, 6, # Back
		4, 0, 3, 4, 3, 7, # Left
		3, 2, 6, 3, 6, 7, # Top
		4, 5, 1, 4, 1, 0  # Bottom
	]
	
	st.set_color(color)
	for i in indices:
		st.add_vertex(verts[i])

func _ready():
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = create_mesh()
	add_child(mesh_instance)
	mesh_instance.owner = self
