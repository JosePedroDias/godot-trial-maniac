extends Node

const Turtle = preload("res://scripts/turtle.gd")

const ROAD_WIDTH = 8.0
const ROAD_LENGTH = 4.0

# Block definitions derived from scripts/create_blocks.gd (Turtle version)
# Curves now start at (0, 0, R) and end at (R, 0, 0)
var block_defs = {
	"RoadStart": {
		"path": "res://scenes/blocks/RoadStart.tscn",
		"entry_t": Transform3D(Basis(), Vector3(0, 0, 2)),
		"exit_t": Transform3D(Basis(), Vector3(0, 0, -2)),
		"aabb": AABB(Vector3(-4, 0, -2), Vector3(8, 2.5, 4)),
		"weight": 0
	},
	"RoadFinish": {
		"path": "res://scenes/blocks/RoadFinish.tscn",
		"entry_t": Transform3D(Basis(), Vector3(0, 0, 2)),
		"exit_t": Transform3D(Basis(), Vector3(0, 0, -2)),
		"aabb": AABB(Vector3(-4, 0, -2), Vector3(8, 2.5, 4)),
		"weight": 0
	},
	"RoadStraight": {
		"path": "res://scenes/blocks/RoadStraight.tscn",
		"entry_t": Transform3D(Basis(), Vector3(0, 0, 2)),
		"exit_t": Transform3D(Basis(), Vector3(0, 0, -2)),
		"aabb": AABB(Vector3(-4, 0, -2), Vector3(8, 1, 4)),
		"weight": 20
	},
	"RoadStraightLong": {
		"path": "res://scenes/blocks/RoadStraightLong.tscn",
		"entry_t": Transform3D(Basis(), Vector3(0, 0, 8)),
		"exit_t": Transform3D(Basis(), Vector3(0, 0, -8)),
		"aabb": AABB(Vector3(-4, 0, -8), Vector3(8, 1, 16)),
		"weight": 15
	},
	"RoadBooster": {
		"path": "res://scenes/blocks/RoadBooster.tscn",
		"entry_t": Transform3D(Basis(), Vector3(0, 0, 2)),
		"exit_t": Transform3D(Basis(), Vector3(0, 0, -2)),
		"aabb": AABB(Vector3(-4, 0, -2), Vector3(8, 1, 4)),
		"weight": 5
	},
	"RoadCurveTightRight": {
		"path": "res://scenes/blocks/RoadCurveTight.tscn",
		# radius 2.0 -> center_radius 6.0. Entry (0,0,6), Exit (6,0,0)
		"entry_t": Transform3D(Basis(), Vector3(0, 0, 6)),
		"exit_t": Transform3D(Basis().rotated(Vector3.UP, -PI/2.0), Vector3(6, 0, 0)),
		"aabb": AABB(Vector3(0, 0, 0), Vector3(10, 1, 10)),
		"weight": 5
	},
	"RoadCurveTightLeft": {
		"path": "res://scenes/blocks/RoadCurveTight.tscn",
		# Flip: Entry (6,0,0), Exit (0,0,6)
		"entry_t": Transform3D(Basis().rotated(Vector3.UP, PI), Vector3(6, 0, 0)),
		"exit_t": Transform3D(Basis().rotated(Vector3.UP, PI/2.0), Vector3(0, 0, 6)),
		"aabb": AABB(Vector3(0, 0, 0), Vector3(10, 1, 10)),
		"weight": 5
	},
	"RoadCurveWideRight": {
		"path": "res://scenes/blocks/RoadCurveWide.tscn",
		# center_radius 14.0
		"entry_t": Transform3D(Basis(), Vector3(0, 0, 14)),
		"exit_t": Transform3D(Basis().rotated(Vector3.UP, -PI/2.0), Vector3(14, 0, 0)),
		"aabb": AABB(Vector3(0, 0, 0), Vector3(18, 1, 18)),
		"weight": 4
	},
	"RoadCurveWideLeft": {
		"path": "res://scenes/blocks/RoadCurveWide.tscn",
		"entry_t": Transform3D(Basis().rotated(Vector3.UP, PI), Vector3(14, 0, 0)),
		"exit_t": Transform3D(Basis().rotated(Vector3.UP, PI/2.0), Vector3(0, 0, 14)),
		"aabb": AABB(Vector3(0, 0, 0), Vector3(18, 1, 18)),
		"weight": 4
	},
	"RoadCurveExtraWideRight": {
		"path": "res://scenes/blocks/RoadCurveExtraWide.tscn",
		# center_radius 22.0
		"entry_t": Transform3D(Basis(), Vector3(0, 0, 22)),
		"exit_t": Transform3D(Basis().rotated(Vector3.UP, -PI/2.0), Vector3(22, 0, 0)),
		"aabb": AABB(Vector3(0, 0, 0), Vector3(26, 1, 26)),
		"weight": 3
	},
	"RoadCurveExtraWideLeft": {
		"path": "res://scenes/blocks/RoadCurveExtraWide.tscn",
		"entry_t": Transform3D(Basis().rotated(Vector3.UP, PI), Vector3(22, 0, 0)),
		"exit_t": Transform3D(Basis().rotated(Vector3.UP, PI/2.0), Vector3(0, 0, 22)),
		"aabb": AABB(Vector3(0, 0, 0), Vector3(26, 1, 26)),
		"weight": 3
	}
}

var occupied_aabbs: Array[AABB] = []
var rng = RandomNumberGenerator.new()

func generate(seed_val: int = -1, max_blocks: int = 20) -> String:
	if seed_val == -1:
		seed_val = Time.get_ticks_msec()
	rng.seed = seed_val
	print("Generating track with seed: ", seed_val)

	occupied_aabbs.clear()
	_total_attempts = 0

	# Load base track and instantiate
	var base_scene = load("res://scenes/base_track.tscn")
	var track_root = base_scene.instantiate()
	track_root.name = "TrackScene"

	# Find or create Track node
	var track_node = track_root.get_node_or_null("Track")
	if not track_node:
		track_node = Node3D.new()
		track_node.name = "Track"
		track_root.add_child(track_node)
		track_node.owner = track_root

	var car = track_root.get_node("Car")
	var turtle = Turtle.new()
	
	# 0. Setup Start Area
	_setup_start_area(track_root, track_node, turtle, car)
	
	# 1. Recursive Generation
	_best_path_nodes = []
	_generate_recursive(track_node, turtle, max_blocks - 3, 0, "RoadStraight") 
	
	if _best_path_nodes.size() < (max_blocks - 3):
		print("  [Warning] Backtracking limit. Completing from best path.")
		turtle.set_position(_best_path_transform.origin)
		turtle.set_orientation(_best_path_transform.basis)
		_try_place_block(track_node, turtle, "RoadStraightLong", true)
		_try_place_block(track_node, turtle, "RoadFinish", true)

	# 2. Save Scene
	var scene = PackedScene.new()
	scene.pack(track_root)
	var path = "res://scenes/track_%d.tscn" % seed_val
	ResourceSaver.save(scene, path)
	print("Track saved: ", path)
	
	track_root.free()
	return path

func _setup_start_area(root, track_node, turtle, car):
	# Platform
	turtle.push_state()
	turtle.turn_left(180)
	var platform = _place_block(track_node, turtle, "RoadStraight")
	occupied_aabbs.append(_transform_aabb(platform.transform, block_defs["RoadStraight"].aabb))
	turtle.pop_state()
	
	# Car (higher to sit on thicker road surface)
	var car_basis = Basis().rotated(Vector3.UP, PI)
	car.transform = Transform3D(car_basis, turtle.get_position() + Vector3(0, 1.5, 2.5))
	car.owner = root 
	
	# RoadStart
	var start_block = _place_block(track_node, turtle, "RoadStart")
	occupied_aabbs.append(_transform_aabb(start_block.transform, block_defs["RoadStart"].aabb))
	
	_try_place_block(track_node, turtle, "RoadStraight", true)
	_try_place_block(track_node, turtle, "RoadStraight", true)

var _total_attempts = 0
const MAX_SEARCH_ATTEMPTS = 15000
var _best_path_nodes: Array[Node3D] = []
var _best_path_transform: Transform3D = Transform3D.IDENTITY

func _is_curve(b_name: String) -> bool:
	return "Curve" in b_name

func _generate_recursive(track_node: Node3D, turtle: Turtle, remaining: int, depth: int, last_block_name: String) -> bool:
	_total_attempts += 1
	if _total_attempts > MAX_SEARCH_ATTEMPTS: return false 

	if depth > _best_path_nodes.size():
		_best_path_nodes.clear()
		for i in range(track_node.get_child_count()):
			if i >= 4: _best_path_nodes.append(track_node.get_child(i))
		_best_path_transform = turtle.get_transform()

	if remaining <= 0:
		if _try_place_block(track_node, turtle, "RoadFinish", false):
			return true
		return false

	var options = _get_weighted_shuffled_blocks()
	for block_name in options:
		# Booster constraint
		if block_name == "RoadBooster" and _is_curve(last_block_name): continue
		if _is_curve(block_name) and last_block_name == "RoadBooster": continue

		turtle.push_state()
		if _try_place_block(track_node, turtle, block_name, false):
			if _generate_recursive(track_node, turtle, remaining - 1, depth + 1, block_name):
				return true
			_undo_last_placement(track_node, turtle)
		else:
			turtle.pop_state()
	return false

func _undo_last_placement(track_node: Node3D, turtle: Turtle):
	occupied_aabbs.pop_back()
	var last_child = track_node.get_child(track_node.get_child_count() - 1)
	last_child.free()
	turtle.pop_state()

func _get_weighted_shuffled_blocks() -> Array[String]:
	var pool: Array[String] = []
	for b_name in block_defs:
		if block_defs[b_name].weight > 0:
			for i in range(block_defs[b_name].weight): pool.append(b_name)
	pool.shuffle()
	var unique: Array[String] = []
	for b in pool:
		if not unique.has(b): unique.append(b)
	return unique

func _try_place_block(root: Node3D, turtle: Turtle, block_name: String, force: bool = false) -> bool:
	var def = block_defs[block_name]
	var block_transform = turtle.get_transform() * def.entry_t.affine_inverse()
	var world_aabb = _transform_aabb(block_transform, def.aabb)
	
	if not force:
		var check_aabb = world_aabb.grow(-0.1)
		for i in range(occupied_aabbs.size()):
			if block_name == "RoadFinish" and i <= 3: continue
			if occupied_aabbs[i].intersects(check_aabb): return false
	
	_place_block(root, turtle, block_name)
	occupied_aabbs.append(world_aabb)
	return true

func _place_block(root: Node3D, turtle: Turtle, block_name: String) -> Node3D:
	var def = block_defs[block_name]
	var block = load(def.path).instantiate() as Node3D
	root.add_child(block)
	block.owner = root.owner if root.owner else root
	block.transform = turtle.get_transform() * def.entry_t.affine_inverse()
	var exit_world = block.transform * def.exit_t
	turtle.set_position(exit_world.origin)
	turtle.set_orientation(exit_world.basis)
	return block

func _transform_aabb(t: Transform3D, aabb: AABB) -> AABB:
	var corners = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size
	]
	var new_min = Vector3(INF, INF, INF); var new_max = Vector3(-INF, -INF, -INF)
	for c in corners:
		var wc = t * c
		new_min.x = min(new_min.x, wc.x); new_min.y = min(new_min.y, wc.y); new_min.z = min(new_min.z, wc.z)
		new_max.x = max(new_max.x, wc.x); new_max.y = max(new_max.y, wc.y); new_max.z = max(new_max.z, wc.z)
	return AABB(new_min, new_max - new_min)
