class_name MeshTurtle
extends Turtle

## A Turtle that generates a 3D mesh as it moves.

var _st: SurfaceTool = SurfaceTool.new()
var _vertices: Array[Vector3] = []
var _profile: Array[Vector2] = [] # 2D cross-section points (X, Y)

func _init(initial_transform: Transform3D = Transform3D.IDENTITY) -> void:
	super._init(initial_transform)
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)

var _profile_colors: Array[Color] = []

## Sets the 2D cross-section to be extruded.
## Points should be in local X-Y plane (road width and height).
func set_profile(points: Array[Vector2], colors: Array[Color] = []) -> void:
	_profile = points
	_profile_colors = colors

var _total_dist: float = 0.0
var _skip_connection: bool = false

## Stops connecting the next slice to the previous one (breaks the extrusion).
func stop_extrusion() -> void:
	_skip_connection = true

## Captures the current cross-section vertices in world space.
func add_slice() -> void:
	var slice_verts: Array[Vector3] = []
	var slice_normals: Array[Vector3] = []
	var slice_colors: Array[Color] = []
	
	var up = transform.basis.y.normalized()
	
	for i in range(_profile.size()):
		var p = _profile[i]
		var local_p = Vector3(p.x, p.y, 0)
		slice_verts.append(transform * local_p)
		slice_normals.append(up)
		if _profile_colors.size() > i:
			slice_colors.append(_profile_colors[i])
		else:
			slice_colors.append(Color.WHITE)
	
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
			_st.add_index(v1); _st.add_index(v2); _st.add_index(v3)
			# Triangle 2
			_st.add_index(v2); _st.add_index(v4); _st.add_index(v3)
			
	_skip_connection = false
	
	for i in range(slice_verts.size()):
		_st.set_normal(slice_normals[i])
		_st.set_color(slice_colors[i])
		# UV: X is across road (0 to 1), Y is along road distance
		var u = float(i) / (_profile.size() - 1)
		_st.set_uv(Vector2(u, _total_dist * 0.1)) # Scale UV for tiling
		_st.add_vertex(slice_verts[i])
		_vertices.append(slice_verts[i])

## Moves forward and adds a geometry slice.
func move_and_extrude(distance: float) -> void:
	if _vertices.size() == 0 or _skip_connection:
		add_slice()
	
	move_forward(distance)
	_total_dist += distance
	add_slice()

## Rotates and adds a slice (useful for turning in place).
func turn_and_extrude(angle_degrees: float, steps: int = 1) -> void:
	if _vertices.size() == 0 or _skip_connection:
		add_slice()
		
	var step_angle = angle_degrees / float(steps)
	for i in range(steps):
		turn_left(step_angle)
		add_slice()

## Rotates and moves simultaneously in small increments to create smooth geometry.
func smooth_step(yaw: float, pitch: float, roll: float, distance: float, sub_steps: int = 4) -> void:
	if _vertices.size() == 0 or _skip_connection:
		add_slice()
		
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
		add_slice()

## Returns the generated mesh.
func commit_mesh() -> Mesh:
	return _st.commit()

## Static helper to create a standard road profile.
static func create_road_profile(width: float, thickness: float, wall_h: float = 0.0, base_color: Color = Color(0.2, 0.2, 0.2)) -> Dictionary:
	var p: Array[Vector2] = []
	var c: Array[Color] = []
	var hw = width / 2.0
	var wall_color = Color(0.4, 0.4, 0.4) # Lighter than asphalt
	
	# Profile points (X, Y)
	if wall_h > 0:
		# Points:
		# 0: Outer Wall Top Left
		# 1: Inner Wall Top Left
		# 2: Road Surface Left (base of wall)
		# 3: Road Surface Right (base of wall)
		# 4: Inner Wall Top Right
		# 5: Outer Wall Top Right
		# 6: Bottom Right
		# 7: Bottom Left
		# 8: Close
		
		p.append(Vector2(-hw - 0.1, wall_h)); c.append(wall_color)
		p.append(Vector2(-hw, wall_h)); c.append(wall_color)
		p.append(Vector2(-hw, 0)); c.append(base_color)
		p.append(Vector2(hw, 0)); c.append(base_color)
		p.append(Vector2(hw, wall_h)); c.append(wall_color)
		p.append(Vector2(hw + 0.1, wall_h)); c.append(wall_color)
		p.append(Vector2(hw + 0.1, -thickness)); c.append(base_color)
		p.append(Vector2(-hw - 0.1, -thickness)); c.append(base_color)
		p.append(Vector2(-hw - 0.1, wall_h)); c.append(wall_color)
	else:
		p.append(Vector2(-hw, 0)); c.append(base_color)
		p.append(Vector2(hw, 0)); c.append(base_color)
		p.append(Vector2(hw, -thickness)); c.append(base_color)
		p.append(Vector2(-hw, -thickness)); c.append(base_color)
		p.append(Vector2(-hw, 0)); c.append(base_color)
		
	return {"points": p, "colors": c}

static func create_f1_profile(width: float = 16.0, kerb_w: float = 1.5, grass_w: float = 10.0) -> Dictionary:
	var p: Array[Vector2] = []
	var c: Array[Color] = []
	var hw = width / 2.0
	
	var col_asphalt = Color(0.15, 0.15, 0.15)
	var col_grass = Color(0.1, 0.4, 0.1)
	var col_kerb = Color.WHITE # Will be alternated in generation
	
	# Grass Left
	p.append(Vector2(-hw - kerb_w - grass_w, -0.2)); c.append(col_grass)
	p.append(Vector2(-hw - kerb_w, 0)); c.append(col_grass)
	# Kerb Left
	p.append(Vector2(-hw - kerb_w, 0)); c.append(col_kerb)
	p.append(Vector2(-hw, 0.1)); c.append(col_kerb)
	# Road
	p.append(Vector2(-hw, 0)); c.append(col_asphalt)
	p.append(Vector2(hw, 0)); c.append(col_asphalt)
	# Kerb Right
	p.append(Vector2(hw, 0.1)); c.append(col_kerb)
	p.append(Vector2(hw + kerb_w, 0)); c.append(col_kerb)
	# Grass Right
	p.append(Vector2(hw + kerb_w, 0)); c.append(col_grass)
	p.append(Vector2(hw + kerb_w + grass_w, -0.2)); c.append(col_grass)
	
	return {"points": p, "colors": c}
