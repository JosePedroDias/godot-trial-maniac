class_name MeshTurtle
extends Turtle

## A Turtle that generates a 3D mesh as it moves.

var _st: SurfaceTool = SurfaceTool.new()
var _profile: Array[Vector2] = [] # 2D cross-section points (X, Y)
var _profile_colors: Array[Color] = []

# Buffer data to allow post-processing
var _slices_v: Array[Array] = [] # Array[Array[Vector3]]
var _slices_n: Array[Array] = [] # Array[Array[Vector3]]
var _slices_c: Array[Array] = [] # Array[Array[Color]]
var _slices_uv: Array[Array] = [] # Array[Array[Vector2]]
var _breaks: Array[int] = [] # Indices of slices where extrusion was broken

var _total_dist: float = 0.0
var _skip_connection: bool = false

func _init(initial_transform: Transform3D = Transform3D.IDENTITY) -> void:
	super._init(initial_transform)

## Sets the 2D cross-section to be extruded.
func set_profile(points: Array[Vector2], colors: Array[Color] = []) -> void:
	_profile = points
	_profile_colors = colors

## Stops connecting the next slice to the previous one (breaks the extrusion).
func stop_extrusion() -> void:
	_skip_connection = true

## Captures the current cross-section vertices in world space.
func add_slice() -> void:
	if _skip_connection:
		_breaks.append(_slices_v.size())
		_skip_connection = false
		
	var slice_verts: Array[Vector3] = []
	var slice_normals: Array[Vector3] = []
	var slice_colors: Array[Color] = []
	var slice_uvs: Array[Vector2] = []
	
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
			
		var u = float(i) / (_profile.size() - 1)
		slice_uvs.append(Vector2(u, _total_dist * 0.1))
	
	_slices_v.append(slice_verts)
	_slices_n.append(slice_normals)
	_slices_c.append(slice_colors)
	_slices_uv.append(slice_uvs)

## Smooths the mesh to fix intersections at tight corners.
func smooth_mesh(iterations: int = 1) -> void:
	if _slices_v.size() < 3: return
	
	for iter in range(iterations):
		var new_v = _slices_v.duplicate(true)
		
		# For each slice (except first and last and breaks)
		for i in range(1, _slices_v.size() - 1):
			if _breaks.has(i) or _breaks.has(i+1): continue
			
			var prev_s = _slices_v[i-1]
			var curr_s = _slices_v[i]
			var next_s = _slices_v[i+1]
			
			for j in range(curr_s.size()):
				# Laplacian-style smoothing along the track direction
				# This evens out distances and reduces overlapping at inner corners
				new_v[i][j] = (prev_s[j] + next_s[j] + 2.0 * curr_s[j]) / 4.0
				
				# Identify intersections/folds: if vertex i is too close to vertex i-1 
				# compared to the centerline distance, it's a pinch.
				# A more advanced pass could weld here, but simple smoothing often resolves it.
		
		_slices_v = new_v

## Returns the generated mesh.
func commit_mesh() -> Mesh:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var vertex_count = 0
	for i in range(_slices_v.size()):
		var sv = _slices_v[i]
		var sn = _slices_n[i]
		var sc = _slices_c[i]
		var suv = _slices_uv[i]
		
		for j in range(sv.size()):
			_st.set_normal(sn[j])
			_st.set_color(sc[j])
			_st.set_uv(suv[j])
			_st.add_vertex(sv[j])
		
		# Connect to previous slice
		if i > 0 and not _breaks.has(i):
			var prev_start = vertex_count - sv.size()
			var curr_start = vertex_count
			
			for j in range(sv.size() - 1):
				var v1 = prev_start + j
				var v2 = prev_start + j + 1
				var v3 = curr_start + j
				var v4 = curr_start + j + 1
				
				# Triangle 1
				_st.add_index(v1); _st.add_index(v2); _st.add_index(v3)
				# Triangle 2
				_st.add_index(v2); _st.add_index(v4); _st.add_index(v3)
				
		vertex_count += sv.size()
		
	return _st.commit()

## Helper methods kept for compatibility
func move_and_extrude(distance: float) -> void:
	if _slices_v.size() == 0 or _skip_connection:
		add_slice()
	move_forward(distance)
	_total_dist += distance
	add_slice()

func smooth_step(yaw: float, pitch: float, roll: float, distance: float, sub_steps: int = 4) -> void:
	if _slices_v.size() == 0 or _skip_connection:
		add_slice()
	var step_yaw = yaw / float(sub_steps); var step_pitch = pitch / float(sub_steps)
	var step_roll = roll / float(sub_steps); var step_dist = distance / float(sub_steps)
	for i in range(sub_steps):
		turn_left(step_yaw); turn_up(step_pitch); roll(step_roll)
		move_forward(step_dist); _total_dist += step_dist
		add_slice()

## Static helper to create an F1 road profile.
static func create_f1_profile(width: float = 16.0, kerb_w: float = 1.5, grass_w: float = 10.0) -> Dictionary:
	var p: Array[Vector2] = []; var c: Array[Color] = []
	var hw = width / 2.0
	var col_asphalt = Color(0.15, 0.15, 0.15)
	var col_grass = Color(0.1, 0.4, 0.1)
	var col_kerb = Color.WHITE
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

static func create_road_profile(width: float, thickness: float, wall_h: float = 0.0, base_color: Color = Color(0.2, 0.2, 0.2)) -> Dictionary:
	var p: Array[Vector2] = []; var c: Array[Color] = []
	var hw = width / 2.0
	if wall_h > 0:
		var wall_color = Color(0.4, 0.4, 0.4)
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
