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

## Captures the current cross-section vertices in world space.
func _add_slice() -> void:
	var slice_verts: Array[Vector3] = []
	for p in _profile:
		# Transform the 2D profile point into the turtle's 3D local space (X, Y, 0)
		# and then into world space.
		var local_p = Vector3(p.x, p.y, 0)
		slice_verts.append(transform * local_p)
	
	# If we have a previous slice, connect it with triangles
	if _vertices.size() >= _profile.size():
		var prev_start = _vertices.size() - _profile.size()
		var curr_start = _vertices.size()
		
		for i in range(_profile.size() - 1):
			var v1 = prev_start + i
			var v2 = prev_start + i + 1
			var v3 = curr_start + i
			var v4 = curr_start + i + 1
			
			# Triangle 1
			_st.add_index(v1)
			_st.add_index(v3)
			_st.add_index(v2)
			
			# Triangle 2
			_st.add_index(v2)
			_st.add_index(v3)
			_st.add_index(v4)
			
	for v in slice_verts:
		_st.add_vertex(v)
		_vertices.append(v)

## Moves forward and adds a geometry slice.
func move_and_extrude(distance: float) -> void:
	if _vertices.size() == 0:
		_add_slice()
	
	move_forward(distance)
	_add_slice()

## Rotates and adds a slice (useful for smooth curves).
func turn_and_extrude(angle_degrees: float, steps: int = 1) -> void:
	if _vertices.size() == 0:
		_add_slice()
		
	var step_angle = angle_degrees / float(steps)
	for i in range(steps):
		turn_left(step_angle)
		_add_slice()

## Returns the generated mesh.
func commit_mesh() -> Mesh:
	_st.generate_normals()
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
