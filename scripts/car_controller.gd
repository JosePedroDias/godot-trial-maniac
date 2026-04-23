extends RigidBody3D

@export_group("Suspension")
@export var suspension_rest_dist: float = 0.3
@export var spring_strength: float = 120000.0
@export var spring_damping: float = 12000.0
@export var wheel_radius: float = 0.3

@export_group("Engine")
@export var engine_power: float = 18000.0
@export var max_speed: float = 120.0
@export var booster_force: float = 20000.0
@export var downforce: float = 10000.0

@export_group("Steering")
@export var steering_angle: float = 25.0
@export var steering_speed: float = 4.0
@export var grip: float = 20.0

@onready var raycasts = [
	$RayCastFL, $RayCastFR, $RayCastRL, $RayCastRR
]
@onready var wheels = [
	$WheelFL, $WheelFR, $WheelRL, $WheelRR
]

var steering_input = 0.0
var engine_input = 0.0
var fall_timer: float = 0.0

var engine_player: AudioStreamPlayer3D
var skid_player: AudioStreamPlayer3D
var collision_player: AudioStreamPlayer3D

var engine_rpm: float = 0.0
var trails = []

func _ready():
	# Set up physics for collision detection
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Set up raycasts
	for ray in raycasts:
		ray.target_position = Vector3(0, -(suspension_rest_dist + wheel_radius), 0)
		ray.add_exception(self)
	
	_setup_audio()
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.sfx_toggled.connect(_on_sfx_toggled)
		_update_sfx_mute(gm.sfx_enabled)

func _on_sfx_toggled(enabled):
	_update_sfx_mute(enabled)

func _update_sfx_mute(enabled):
	var players = [engine_player, skid_player, collision_player, get_meta("brake_player")]
	for p in players:
		if p:
			if not enabled:
				p.stop()
			else:
				if p == engine_player or p == skid_player or p == get_meta("brake_player"):
					p.play()

func _setup_audio():
	engine_player = AudioStreamPlayer3D.new()
	engine_player.set_script(load("res://scripts/engine_sound.gd"))
	skid_player = AudioStreamPlayer3D.new()
	collision_player = AudioStreamPlayer3D.new()
	
	add_child(engine_player)
	add_child(skid_player)
	add_child(collision_player)
	
	engine_player.unit_size = 30.0
	engine_player.play()
	
	# 2. Skid Sound (Noise)
	var skid_stream = AudioStreamWAV.new()
	skid_stream.format = AudioStreamWAV.FORMAT_16_BITS
	skid_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	skid_stream.mix_rate = 44100
	var s_data = PackedByteArray()
	var s_len = 22050 # 0.5s
	s_data.resize(s_len * 2)
	for i in range(s_len):
		var val = int((randf() * 2.0 - 1.0) * 5000)
		s_data.encode_s16(i * 2, val)
	skid_stream.data = s_data
	skid_stream.loop_end = s_len
	skid_player.stream = skid_stream
	skid_player.unit_size = 30.0
	skid_player.play()
	
	# 3. Braking Sound (High pitch squeal)
	var brake_player = AudioStreamPlayer3D.new()
	brake_player.unit_size = 30.0
	add_child(brake_player)
	self.set_meta("brake_player", brake_player)
	var brake_stream = AudioStreamWAV.new()
	brake_stream.format = AudioStreamWAV.FORMAT_16_BITS
	brake_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	brake_stream.mix_rate = 44100
	var b_data = PackedByteArray()
	var b_len = 4410 # 0.1s
	b_data.resize(b_len * 2)
	for i in range(b_len):
		var t = float(i) / b_len
		var val = int(sin(t * 800.0) * 3000) # High frequency sine
		b_data.encode_s16(i * 2, val)
	brake_stream.data = b_data
	brake_stream.loop_end = b_len
	brake_player.stream = brake_stream
	brake_player.volume_db = -80
	brake_player.play()
	
	# 4. Collision Sound (Thump)
	var coll_stream = AudioStreamWAV.new()
	coll_stream.format = AudioStreamWAV.FORMAT_16_BITS
	coll_stream.mix_rate = 44100
	var c_data = PackedByteArray()
	var c_len = 22050 # 0.5s
	c_data.resize(c_len * 2)
	for i in range(c_len):
		var t = float(i) / c_len
		var noise = (randf() * 2.0 - 1.0) * 15000 * exp(-t * 20.0)
		var tone = sin(t * 80.0) * exp(-t * 8.0) * 20000
		var val = int(clamp(tone + noise, -32768, 32767))
		c_data.encode_s16(i * 2, val)
	coll_stream.data = c_data
	collision_player.stream = coll_stream
	collision_player.unit_size = 20.0
	
	# Set up trails
	for i in range(4):
		var trail = MeshInstance3D.new()
		trail.set_script(load("res://scripts/trail_renderer.gd"))
		# Add to scene root so they don't inherit car's transform/scale
		get_tree().current_scene.add_child.call_deferred(trail)
		trails.append(trail)

func _physics_process(delta):
	var gm = get_node_or_null("/root/GameManager")
	var sfx_enabled = gm.sfx_enabled if gm else true
	
	var on_ground = false
	for ray in raycasts:
		if ray.is_colliding():
			on_ground = true
			break

	# Update Audio
	var speed_cur = linear_velocity.length()
	var speed_kmh = speed_cur * 3.6
	var forward_speed = global_basis.z.dot(linear_velocity)
	
	if gm:
		gm.speed_updated.emit(speed_kmh) # Convert m/s to km/h
	
	if engine_player and sfx_enabled:
		_update_engine_audio(delta, speed_kmh)
	
	# Skid and Brake detection
	var is_skidding = false
	var is_braking = false
	
	if speed_cur > 5.0:
		var lateral_speed = abs(global_basis.x.dot(linear_velocity))
		if lateral_speed > 3.0:
			is_skidding = true
	
	# Brake logic: available at any speed
	if (forward_speed > 0.1 and engine_input < -0.1) or (forward_speed < -0.1 and engine_input > 0.1):
		is_braking = true
	
	# Apply actual braking force opposite to velocity
	if is_braking:
		var lateral_speed = abs(global_basis.x.dot(linear_velocity))
		# If we are sliding sideways (drifting), don't kill the momentum too hard
		# This allows the "loose rear" to swing around.
		var drift_mod = lerp(1.0, 0.1, clamp(lateral_speed / 5.0, 0.0, 1.0))
		
		# Stronger speed factor at very low speeds
		var speed_factor = lerp(5.0, 1.0, clamp(speed_cur / 10.0, 0.0, 1.0))
		var brake_force = -linear_velocity.normalized() * engine_power * 1.0 * speed_factor * drift_mod
		apply_central_force(brake_force)
		
		# Snap to stop if we are crawling while braking (and not sliding)
		if speed_cur < 2.0 and lateral_speed < 1.0:
			linear_velocity *= 0.5
			if speed_cur < 0.2:
				linear_velocity = Vector3.ZERO
	
	if skid_player and sfx_enabled:
		var target_skid_vol = 5 if (is_skidding and on_ground) else -80
		skid_player.volume_db = lerp(skid_player.volume_db, float(target_skid_vol), 10.0 * delta)
	
	var brake_plr = get_meta("brake_player") as AudioStreamPlayer3D
	if brake_plr and sfx_enabled:
		var target_brake_vol = 0 if (is_braking and on_ground) else -80
		brake_plr.volume_db = lerp(brake_plr.volume_db, float(target_brake_vol), 15.0 * delta)

	# Rolling resistance and Drag
	if on_ground:
		var resistance = -linear_velocity * mass * 0.2
		if abs(engine_input) < 0.05:
			resistance *= 2.0 # Extra resistance when coasting
		apply_central_force(resistance)
		
	# Fall detection (ditch fixed Y < -20 check)
	if !on_ground and linear_velocity.y < -5.0:
		fall_timer += delta
		if fall_timer > 2.0:
			if gm: gm.reset_race()
			fall_timer = 0.0
			return
	else:
		fall_timer = 0.0

	# Get Input
	if gm:
		var get_val = func(slot):
			if slot.get("is_kb", false):
				return 1.0 if Input.is_key_pressed(slot.key) else 0.0
			
			if slot.dev < 0: return 0.0
			if slot.get("is_btn", false):
				return 1.0 if Input.is_joy_button_pressed(slot.dev, slot.btn) else 0.0
			
			var cur_val = Input.get_joy_axis(slot.dev, slot.axis)
			var snap = slot.get("snap", 0.0)
			return clamp((cur_val - snap) * slot.sign, 0.0, 1.0)
		
		var s_left = get_val.call(gm.steer_left)
		var s_right = get_val.call(gm.steer_right)
		var t_val = get_val.call(gm.throttle)
		var b_val = get_val.call(gm.brake)
		
		var target_steer = s_left - s_right
		# Squared input for softer center
		target_steer = sign(target_steer) * pow(abs(target_steer), 1.5)
		
		var steer_speed = steering_speed * 2.0 if gm.steer_left.get("is_kb", false) else steering_speed
		steering_input = lerp(steering_input, target_steer, steer_speed * delta)
		engine_input = t_val - b_val
	else:
		var kb_engine = Input.get_axis("ui_down", "ui_up")
		var kb_steer = Input.get_axis("ui_right", "ui_left")
		kb_steer = sign(kb_steer) * pow(abs(kb_steer), 1.5)
		engine_input = kb_engine
		steering_input = lerp(steering_input, kb_steer, steering_speed * delta)
	
	var is_on_sticky = false
	
	for i in range(raycasts.size()):
		var ray = raycasts[i]
		var wheel = wheels[i]
		var trail = trails[i]
		
		wheel.position.x = ray.position.x
		wheel.position.z = ray.position.z
		
		if ray.is_colliding():
			on_ground = true
			var collider = ray.get_collider()
			
			if collider.has_method("get_script") and collider.get_script() and collider.get_script().get_path() == "res://scripts/track_block.gd":
				_check_track_block(collider)
				if collider.is_sticky():
					is_on_sticky = true
			
			var hit_point = ray.get_collision_point()
			var hit_normal = ray.get_collision_normal()
			var dist = (ray.global_position - hit_point).length()
			
			# 1. Suspension
			var compression = (suspension_rest_dist + wheel_radius) - dist
			if compression > 0:
				var wheel_velocity = linear_velocity + angular_velocity.cross(ray.global_position - global_position)
				var upward_vel = hit_normal.dot(wheel_velocity)
				var spring_force = compression * spring_strength
				var damping_force = upward_vel * spring_damping
				var total_force = (spring_force - damping_force) * hit_normal
				
				# 1.1 Apply Suspension Force
				apply_force(total_force, ray.global_position - global_position)
				
				# 1.2 Apply Downforce
				if is_on_sticky:
					var downforce_dir = -hit_normal
					apply_force(downforce_dir * downforce / raycasts.size(), ray.global_position - global_position)
				
				# 2. Driving
				var wheel_basis = ray.global_basis
				if i < 2:
					# More aggressive steering reduction at high speed (30.0 instead of 35.0)
					var steer_speed_factor = exp(-speed_cur / 30.0)
					var effective_steer = steering_input * deg_to_rad(steering_angle) * steer_speed_factor
					wheel_basis = wheel_basis.rotated(global_basis.y, effective_steer)
				
				var forward_dir = wheel_basis.z
				var right_dir = wheel_basis.x
				
				if abs(engine_input) > 0.05 and !is_braking:
					# engine_input > 0 is forward, < 0 is reverse/brake.
					# Allow engine power if we are pushing in the same direction we're moving,
					# OR if we are nearly stopped (allowing us to start moving).
					var starting_from_stop = abs(forward_speed) < 1.0
					var pushing_forward = forward_speed > 0 and engine_input > 0
					var pushing_reverse = forward_speed < 0 and engine_input < 0
					
					if starting_from_stop or pushing_forward or pushing_reverse:
						var accel_force = forward_dir * engine_input * engine_power
						apply_force(accel_force, ray.global_position - global_position)
				
				var lateral_vel = right_dir.dot(wheel_velocity)
				# Stronger taper at low speeds to prevent physics jitter
				var low_speed_taper = clamp(speed_cur / 5.0, 0.0, 1.0)
				
				# Drifting logic: reduce rear grip when braking
				var grip_factor = 1.0
				if i >= 2: # Rear wheels
					if is_braking:
						grip_factor = 0.15 # Slightly more than before for stability
					
					# Maintain drift with throttle
					if is_skidding and engine_input > 0.1:
						grip_factor = min(grip_factor, 0.5)
					
					# Recovery: increase grip as we align with movement
					if speed_cur > 1.0:
						var move_dir = linear_velocity.normalized()
						var alignment = abs(forward_dir.dot(move_dir))
						# Only recover if we aren't intentionally sliding
						if !is_braking:
							grip_factor = lerp(grip_factor, 1.0, alignment)
				
				var grip_force = -right_dir * lateral_vel * grip * mass * low_speed_taper * grip_factor
				apply_force(grip_force, ray.global_position - global_position)
				
				wheel.global_position = hit_point + hit_normal * wheel_radius
				wheel.global_basis = wheel_basis.rotated(wheel_basis.z, PI/2.0)
				
				# Trails: Only when braking or skidding
				if is_braking or is_skidding:
					trail.add_point(hit_point, hit_normal)
			else:
				wheel.position.y = -suspension_rest_dist
		else:
			wheel.position.y = -suspension_rest_dist
			var wheel_basis = ray.global_basis
			if i < 2:
				var steer_speed_factor = exp(-speed_cur / 35.0)
				wheel_basis = wheel_basis.rotated(global_basis.y, steering_input * deg_to_rad(steering_angle) * steer_speed_factor)
			wheel.global_basis = wheel_basis.rotated(wheel_basis.z, PI/2.0)

	if !on_ground:
		var air_torque = Vector3.ZERO
		apply_torque(global_basis * air_torque * mass)

func _update_engine_audio(delta, speed_kmh):
	var throttle = abs(engine_input)
	var target_rpm = clamp(speed_kmh / 200.0, 0.0, 1.0)
	engine_rpm = lerp(engine_rpm, target_rpm, 10.0 * delta)
	engine_player.rpm = engine_rpm
	engine_player.throttle = throttle
	engine_player.volume_db = -10 + clamp(speed_kmh / 20.0, 0, 10)

func _check_track_block(block):
	var gm = get_node_or_null("/root/GameManager")
	match block.type:
		3: # BOOSTER
			apply_central_force(global_basis.z * booster_force)

func _on_body_entered(_body):
	var gm = get_node_or_null("/root/GameManager")
	if linear_velocity.length() > 2.0 and collision_player and (not gm or gm.sfx_enabled):
		collision_player.play()
