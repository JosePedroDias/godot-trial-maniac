extends MeshInstance3D

@export var max_points: int = 1000
@export var trail_width: float = 0.5
@export var lifetime: float = 1.0

var points = [] # Array of {pos, normal, time}
var min_dist: float = 0.1

func _ready():
	mesh = ImmediateMesh.new()
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0, 0, 0.5) # Lower alpha
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = StandardMaterial3D.CULL_BACK # Re-enable standard culling
	mat.no_depth_test = false # Re-enable depth test for proper integration
	material_override = mat
	
	extra_cull_margin = 100.0

func _process(_delta):
	var current_time = Time.get_ticks_msec() / 1000.0
	while points.size() > 0 and current_time - points[0].time > lifetime:
		points.remove_at(0)
	
	_update_mesh()

func add_point(pos: Vector3, normal: Vector3):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if points.size() > 0:
		if pos.distance_to(points[-1].pos) < min_dist:
			return
			
	points.append({
		"pos": pos + normal * 0.05, # 5cm offset
		"normal": normal,
		"time": current_time
	})
	
	if points.size() > max_points:
		points.remove_at(0)

func _update_mesh():
	var imm = mesh as ImmediateMesh
	imm.clear_surfaces()
	
	if points.size() < 2:
		return
		
	imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i + 1]
		
		var dir = (p2.pos - p1.pos).normalized()
		var side1 = dir.cross(p1.normal).normalized() * (trail_width * 0.5)
		var side2 = dir.cross(p2.normal).normalized() * (trail_width * 0.5)
		
		var alpha1 = clamp(1.0 - (current_time - p1.time) / lifetime, 0.0, 1.0)
		var alpha2 = clamp(1.0 - (current_time - p2.time) / lifetime, 0.0, 1.0)
		
		var v1 = p1.pos - side1
		var v2 = p1.pos + side1
		var v3 = p2.pos - side2
		var v4 = p2.pos + side2
		
		# Quad faces (winding for CULL_BACK)
		# Face 1 (Clockwise)
		imm.surface_set_color(Color(0, 0, 0, 0.5 * alpha1))
		imm.surface_add_vertex(v1)
		imm.surface_set_color(Color(0, 0, 0, 0.5 * alpha2))
		imm.surface_add_vertex(v3)
		imm.surface_set_color(Color(0, 0, 0, 0.5 * alpha1))
		imm.surface_add_vertex(v2)
		
		# Face 2 (Clockwise)
		imm.surface_set_color(Color(0, 0, 0, 0.5 * alpha1))
		imm.surface_add_vertex(v2)
		imm.surface_set_color(Color(0, 0, 0, 0.5 * alpha2))
		imm.surface_add_vertex(v3)
		imm.surface_set_color(Color(0, 0, 0, 0.5 * alpha2))
		imm.surface_add_vertex(v4)
		
	imm.surface_end()
