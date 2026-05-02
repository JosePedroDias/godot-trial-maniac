extends RigidBody3D

enum Strategy { RAYCAST, SIMPLE }
@export var physics_strategy: Strategy = Strategy.RAYCAST # RAYCAST, SIMPLE

@export_group("Engine")
@export var engine_power: float = 150000.0
@export var brake_force: float = 100000.0
@export var max_speed: float = 320.0 # km/h
@export var reverse_force: float = 30000.0

@export_group("Steering")
@export var steering_speed: float = 8.0
@export var steering_angle: float = 15.0
@export var grip: float = 9.0

@export_group("Suspension")
@export var suspension_rest_dist: float = 0.4
@export var spring_strength: float = 300.0
@export var spring_damping: float = 15.0
@export var wheel_radius: float = 0.33
@export var aero_downforce: float = 5.0

# Input & State (Shared with physics strategies)
var steering_input: float = 0.0
var throttle_input: float = 0.0
var brake_input: float = 0.0
var is_on_ground: bool = false
var on_ground: bool = false # Alias for ghost system
var ground_normal: Vector3 = Vector3.UP
var is_skidding: bool = false
var is_braking: bool = false

# Ghost System / Compatibility
var current_rpm: float = 0.0
var engine_input: float = 0.0

var _raycasts = []
var _wheels = []
var _wheel_rot: float = 0.0
var fall_timer: float = 0.0
var _physics_logic: Node = null

# Audio & Visuals
var engine_player: Node3D
var skid_player: AudioStreamPlayer3D
var collision_player: AudioStreamPlayer3D
var current_gear: int = 1
var gear_shift_points = [0, 60, 110, 150, 190, 230, 270, 310, 400]

func _ready():
	_raycasts = [$RayCastFL, $RayCastFR, $RayCastRL, $RayCastRR]
	_wheels = [$WheelFL, $WheelFR, $WheelRL, $WheelRR]
	
	for ray in _raycasts:
		ray.add_exception(self)
		ray.target_position = Vector3(0, -1.5, 0)
	
	# Physics setup
	gravity_scale = 2.0
	linear_damp = 0.5
	angular_damp = 5.0
	center_of_mass_mode = 1
	center_of_mass = Vector3(0, 0.25, 0.2)
	
	_init_physics_strategy()
	_setup_audio()
	
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.sfx_toggled.connect(_on_sfx_toggled)
		_on_sfx_toggled(gm.sfx_enabled)

func _init_physics_strategy():
	if _physics_logic:
		_physics_logic.queue_free()
	
	match physics_strategy:
		Strategy.RAYCAST:
			_physics_logic = Node.new()
			_physics_logic.set_script(load("res://scripts/car_physics_raycast.gd"))
		Strategy.SIMPLE:
			_physics_logic = Node.new()
			_physics_logic.set_script(load("res://scripts/car_physics_simple.gd"))
			
	add_child(_physics_logic)
	_physics_logic.setup(self)
	_sync_physics_params()

func _sync_physics_params():
	if not _physics_logic: return
	_physics_logic.engine_power = engine_power
	_physics_logic.brake_force = brake_force
	_physics_logic.max_speed = max_speed
	_physics_logic.reverse_force = reverse_force
	_physics_logic.steering_angle = steering_angle
	_physics_logic.grip = grip
	_physics_logic.suspension_rest_dist = suspension_rest_dist
	_physics_logic.spring_strength = spring_strength
	_physics_logic.spring_damping = spring_damping
	_physics_logic.wheel_radius = wheel_radius
	_physics_logic.aero_downforce = aero_downforce

func _on_sfx_toggled(enabled):
	if engine_player and engine_player.has_method("set_enabled"):
		engine_player.set_enabled(enabled)
	if skid_player: skid_player.stream_paused = !enabled

func _setup_audio():
	engine_player = Node3D.new()
	engine_player.set_script(load("res://scripts/engine_sound.gd"))
	add_child(engine_player)
	
	skid_player = AudioStreamPlayer3D.new()
	add_child(skid_player)
	var skid_stream = AudioStreamWAV.new()
	skid_stream.format = AudioStreamWAV.FORMAT_16_BITS
	skid_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	skid_stream.mix_rate = 44100
	var data = PackedByteArray()
	data.resize(22050 * 2)
	for i in range(22050):
		data.encode_s16(i*2, int((randf()*2-1)*3000))
	skid_stream.data = data
	skid_stream.loop_end = 22050
	skid_player.stream = skid_stream
	skid_player.volume_db = -80
	skid_player.play()
	
	collision_player = AudioStreamPlayer3D.new()
	add_child(collision_player)
	var coll_stream = AudioStreamWAV.new()
	coll_stream.format = AudioStreamWAV.FORMAT_16_BITS
	coll_stream.mix_rate = 44100
	var c_data = PackedByteArray()
	c_data.resize(4410 * 2)
	for i in range(4410):
		c_data.encode_s16(i*2, int((randf()*2-1)*15000 * exp(-float(i)/1000.0)))
	coll_stream.data = c_data
	collision_player.stream = coll_stream

func _on_body_entered(_body):
	if linear_velocity.length() > 5.0 and collision_player:
		collision_player.play()

func _physics_process(delta):
	_read_input(delta)
	
	is_skidding = false
	is_braking = false
	engine_input = throttle_input - brake_input
	
	if _physics_logic:
		_physics_logic.apply_physics(delta)
	
	# Fall Detection
	var gm = get_node_or_null("/root/GameManager")
	if !is_on_ground or global_position.y < -50.0:
		fall_timer += delta
		if fall_timer > 2.5 or global_position.y < -100.0:
			if gm: gm.reset_race()
			fall_timer = 0.0
			return
	else:
		fall_timer = 0.0

	# HUD & Audio Update
	var speed_kmh = linear_velocity.length() * 3.6
	if gm: gm.speed_updated.emit(speed_kmh)
	_update_audio(delta, speed_kmh)
	current_rpm = engine_player.rpm_raw if engine_player else 0.0
	
	# Visual Wheel Update
	_wheel_rot += (global_basis.z.dot(linear_velocity) * delta * 5.0)
	if _physics_logic:
		_physics_logic.update_wheels(delta, steering_input, _wheel_rot)

func _read_input(delta):
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var get_val = func(slot):
			if slot.get("is_kb", false): return 1.0 if Input.is_key_pressed(slot.key) else 0.0
			return clamp((Input.get_joy_axis(slot.dev, slot.axis) - slot.get("snap", 0.0)) * slot.sign, 0.0, 1.0)
		
		var target_steer = get_val.call(gm.steer_left) - get_val.call(gm.steer_right)
		steering_input = lerp(steering_input, target_steer, steering_speed * delta)
		throttle_input = get_val.call(gm.throttle)
		brake_input = get_val.call(gm.brake)
	else:
		var target_steer = Input.get_axis("ui_right", "ui_left")
		steering_input = lerp(steering_input, target_steer, steering_speed * delta)
		throttle_input = Input.get_action_strength("ui_up")
		brake_input = Input.get_action_strength("ui_down")

func _update_audio(delta, speed_kmh):
	if engine_player:
		var old_gear = current_gear
		for g in range(1, 9):
			if speed_kmh < gear_shift_points[g]:
				current_gear = g; break
		if current_gear != old_gear:
			var gm = get_node_or_null("/root/GameManager")
			if gm: gm.gear_updated.emit(current_gear)
		
		var gear_min = gear_shift_points[current_gear-1]
		var gear_max = gear_shift_points[current_gear]
		var rpm_pct = clamp((speed_kmh - gear_min) / max(1.0, gear_max - gear_min), 0.0, 1.0)
		engine_player.rpm_raw = lerp(3000.0, 12000.0, rpm_pct)
		engine_player.throttle = throttle_input
		engine_player.gear = current_gear
	
	if skid_player:
		var target_vol = 5 if (is_skidding and is_on_ground) else -80
		skid_player.volume_db = lerp(skid_player.volume_db, float(target_vol), delta * 10.0)
