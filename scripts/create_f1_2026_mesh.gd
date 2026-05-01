extends Node3D

func create_mesh() -> Mesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var body_color = Color(0.8, 0.1, 0.1) # Red base
	var carbon_color = Color(0.1, 0.1, 0.1)
	
	# Dimensions (meters)
	var nose_w = 0.3
	var width = 1.9
	
	# Simple procedural F1 Body
	_add_box(st, Vector3(0, 0.2, 2.0), Vector3(nose_w, 0.15, 1.0), body_color)
	_add_box(st, Vector3(0, 0.3, 0.5), Vector3(width * 0.4, 0.4, 1.5), body_color)
	_add_box(st, Vector3(0.6, 0.25, 0.0), Vector3(0.5, 0.3, 1.2), body_color)
	_add_box(st, Vector3(-0.6, 0.25, 0.0), Vector3(0.5, 0.3, 1.2), body_color)
	_add_box(st, Vector3(0, 0.1, 2.4), Vector3(1.9, 0.05, 0.4), carbon_color)
	_add_box(st, Vector3(0, 0.6, -1.8), Vector3(1.4, 0.1, 0.5), carbon_color)
	_add_box(st, Vector3(0.7, 0.5, -1.8), Vector3(0.05, 0.4, 0.6), carbon_color)
	_add_box(st, Vector3(-0.7, 0.5, -1.8), Vector3(0.05, 0.4, 0.6), carbon_color)
	
	st.index()
	var mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.5
	mat.metallic = 0.2
	mesh.surface_set_material(0, mat)
	
	return mesh

func _add_box(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color):
	var hs = size / 2.0
	var v = [
		Vector3(-hs.x, -hs.y, hs.z), Vector3(hs.x, -hs.y, hs.z), Vector3(hs.x, hs.y, hs.z), Vector3(-hs.x, hs.y, hs.z),
		Vector3(-hs.x, -hs.y, -hs.z), Vector3(hs.x, -hs.y, -hs.z), Vector3(hs.x, hs.y, -hs.z), Vector3(-hs.x, hs.y, -hs.z)
	]
	for i in range(v.size()):
		v[i] += pos
	
	# Front (Z+)
	_add_face(st, v[0], v[1], v[2], v[3], Vector3(0, 0, 1), color)
	# Right (X+)
	_add_face(st, v[1], v[5], v[6], v[2], Vector3(1, 0, 0), color)
	# Back (Z-)
	_add_face(st, v[5], v[4], v[7], v[6], Vector3(0, 0, -1), color)
	# Left (X-)
	_add_face(st, v[4], v[0], v[3], v[7], Vector3(-1, 0, 0), color)
	# Top (Y+)
	_add_face(st, v[3], v[2], v[6], v[7], Vector3(0, 1, 0), color)
	# Bottom (Y-)
	_add_face(st, v[4], v[5], v[1], v[0], Vector3(0, -1, 0), color)

func _add_face(st: SurfaceTool, v1, v2, v3, v4, normal, color):
	st.set_normal(normal)
	st.set_color(color)
	# Tri 1 (CW)
	st.add_vertex(v1)
	st.add_vertex(v3)
	st.add_vertex(v2)
	# Tri 2 (CW)
	st.add_vertex(v1)
	st.add_vertex(v4)
	st.add_vertex(v3)

func _ready():
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = create_mesh()
	add_child(mesh_instance)
	mesh_instance.owner = self
