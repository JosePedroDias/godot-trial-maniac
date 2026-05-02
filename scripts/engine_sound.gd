extends AudioStreamPlayer3D

var playback: AudioStreamGeneratorPlayback
var sample_rate: float
var phase: float = 0.0

var rpm_raw: float = 0.0 # Real RPM value (e.g. 3000 to 12000)
var throttle: float = 0.0

var _phases = [0.0, 0.0, 0.0]

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
		
	# F1 V6 usually revs 4000 to 12000 in our sim range
	# We map rpm_raw to a fundamental frequency
	var fundamental = rpm_raw / 60.0 # Hz
	
	for i in range(frames_available):
		var samples = 0.0
		
		# Oscillator 1: Fundamental (Low weight, sub)
		_phases[0] = fmod(_phases[0] + fundamental / sample_rate, 1.0)
		samples += 0.4 * sin(_phases[0] * TAU)
		
		# Oscillator 2: 3rd Harmonic (V6 characteristic)
		_phases[1] = fmod(_phases[1] + (fundamental * 3.0) / sample_rate, 1.0)
		var saw = 2.0 * (_phases[1] - floor(0.5 + _phases[1]))
		samples += 0.6 * saw
		
		# Oscillator 3: 1.5th Harmonic (Roughness/Frequency modulation)
		_phases[2] = fmod(_phases[2] + (fundamental * 1.5) / sample_rate, 1.0)
		samples += 0.3 * (2.0 * (_phases[2] - floor(0.5 + _phases[2])))
		
		# Throttle-based distortion and growl
		var drive = 1.0 + throttle * 2.5
		samples *= drive
		
		# Soft clipping / Saturation
		samples = tanh(samples)
		
		# High-frequency "whine" (Turbo/Hybrid)
		var whine_freq = 2000.0 + fundamental * 2.0
		var whine = sin(float(i + phase) * whine_freq * TAU / sample_rate) * 0.05 * throttle
		samples += whine
		
		var sample = Vector2(samples, samples) * 0.5
		playback.push_frame(sample)
