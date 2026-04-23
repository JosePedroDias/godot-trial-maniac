class_name MeshTurtle
extends Turtle

## A Turtle that generates a 3D mesh as it moves.

var _st: SurfaceTool = SurfaceTool.new()
var _vertices: Array[Vector3] = []
var _profile: Array[Vector2] = [] # 2D cross-section points (X, Y)

func _init(initial_transform: Transform3D = Transform3D.IDENTITY) -> void:
	super._init(initial_transform)
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)

## Sets the 2D cross-section to be extruded.
## Points should be in local X-Y plane (road width and height).
func set_profile(points: Array[Vector2]) -> void:
	_profile = points

var _total_dist: float = 0.0
var _skip_connection: bool = false

## Stops connecting the next slice to the previous one (breaks the extrusion).
func stop_extrusion() -> void:
	_skip_connection = true

## Captures the current cross-section vertices in world space.
func _add_slice() -> void:
	var slice_verts: Array[Vector3] = []
	var slice_normals: Array[Vector3] = []
	
	var up = transform.basis.y.normalized()
	
	for i in range(_profile.size()):
		var p = _profile[i]
		var local_p = Vector3(p.x, p.y, 0)
		slice_verts.append(transform * local_p)
		slice_normals.append(up)
	
	# If we have a previous slice, connect it with triangles
	if _vertices.size() >= _profile.size() and not _skip_connection:
		var prev_start = _vertices.size() - _profile.size()
		var curr_start = _vertices.size()
		
		for i in range(_profile.size() - 1):
			var v1 = prev_start + i
			var v2 = prev_start + i + 1
			var v3 = curr_start + i
			var v4 = curr_start + i + 1
			
			# Triangle 1
			_st.add_index(v1); _st.add_index(v3); _st.add_index(v2)
			# Triangle 2
			_st.add_index(v2); _st.add_index(v3); _st.add_index(v4)
			
	_skip_connection = false
	
	for i in range(slice_verts.size()):
		_st.set_normal(slice_normals[i])
		# UV: X is across road (0 to 1), Y is along road distance
		var u = float(i) / (_profile.size() - 1)
		_st.set_uv(Vector2(u, _total_dist * 0.1)) # Scale UV for tiling
		_st.add_vertex(slice_verts[i])
		_vertices.append(slice_verts[i])

## Moves forward and adds a geometry slice.
func move_and_extrude(distance: float) -> void:
	if _vertices.size() == 0:
		_add_slice()
	
	move_forward(distance)
	_total_dist += distance
	_add_slice()

## Rotates and adds a slice (useful for smooth curves).
func turn_and_extrude(angle_degrees: float, steps: int = 1) -> void:
	if _vertices.size() == 0:
		_add_slice()
		
	var step_angle = angle_degrees / float(steps)
	# For turn distance, we approximate based on the outer radius or center
	var approx_dist = abs(deg_to_rad(angle_degrees) * 4.0) / steps # 4.0 is approx radius
	
	for i in range(steps):
		turn_left(step_angle)
		_total_dist += approx_dist
		_add_slice()

## Rotates and moves simultaneously in small increments to create smooth geometry.
func smooth_step(yaw: float, pitch: float, roll: float, distance: float, sub_steps: int = 4) -> void:
	if _vertices.size() == 0:
		_add_slice()
		
	var step_yaw = yaw / float(sub_steps)
	var step_pitch = pitch / float(sub_steps)
	var step_roll = roll / float(sub_steps)
	var step_dist = distance / float(sub_steps)
	
	for i in range(sub_steps):
		turn_left(step_yaw)
		turn_up(step_pitch)
		roll(step_roll)
		move_forward(step_dist)
		_total_dist += step_dist
		_add_slice()

## Returns the generated mesh.
func commit_mesh() -> Mesh:
	# No longer need generate_normals() as we provide them
	return _st.commit()

## Static helper to create a standard road profile.
static func create_road_profile(width: float, thickness: float, wall_h: float = 0.0) -> Array[Vector2]:
	var p: Array[Vector2] = []
	var hw = width / 2.0
	
	# Simple flat road
	p.append(Vector2(-hw, thickness)) # Left top
	p.append(Vector2(hw, thickness))  # Right top
	
	# If walls requested
	if wall_h > 0:
		p.insert(0, Vector2(-hw, thickness + wall_h))
		p.append(Vector2(hw, thickness + wall_h))
		
	return p
