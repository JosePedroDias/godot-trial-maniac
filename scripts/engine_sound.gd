extends AudioStreamPlayer3D

var playback: AudioStreamGeneratorPlayback
var sample_rate: float
var phase: float = 0.0

var rpm: float = 0.0 # 0.0 to 1.0
var throttle: float = 0.0

func _ready():
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.1
	stream = generator
	sample_rate = generator.mix_rate
	play()

func _process(_delta):
	if not playing:
		playback = null
		return
		
	if not playback:
		playback = get_stream_playback()
	
	if playback:
		_fill_buffer()

func _fill_buffer():
	var frames_available = playback.get_frames_available()
	if frames_available == 0:
		return
		
	# Frequency scaling based on RPM
	var base_freq = lerp(30.0, 160.0, rpm)
	
	for i in range(frames_available):
		var increment = base_freq / sample_rate
		phase = fmod(phase + increment, 1.0)
		
		# Stable Sawtooth Synthesis
		var s1 = 2.0 * (phase - floor(0.5 + phase))
		var phase2 = fmod(phase + 0.35, 1.0)
		var s2 = 2.0 * (phase2 - floor(0.5 + phase2))
		
		# Combine for a fixed "engine" timbre
		var s = s1 * 0.6 + s2 * 0.4
		s += 0.3 * sin(phase * 0.5 * TAU) # Sub-bass weight
		
		# Constant Soft Clipping for a consistent grit
		# We use a fixed drive level instead of throttle-based
		s *= 2.0 
		s = s / (1.0 + abs(s))
		
		# Subtle constant mechanical noise
		var noise = (randf() - 0.5) * 0.05
		s += noise
		
		# The resulting sample has a constant character, 
		# only the 'base_freq' changes with speed.
		var sample = Vector2(s, s) * 0.7
		playback.push_frame(sample)
