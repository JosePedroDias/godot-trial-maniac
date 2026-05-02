extends AudioStreamPlayer3D

var playback: AudioStreamGeneratorPlayback
var sample_rate: float
var phase: float = 0.0

var rpm_raw: float = 0.0 # 3000 to 12000
var throttle: float = 0.0
var gear: int = 1

var _phases = [0.0, 0.0, 0.0, 0.0]

func _ready():
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.1
	stream = generator
	sample_rate = generator.mix_rate
	play()

func set_enabled(enabled: bool):
	stream_paused = !enabled

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
		
	var rpm_octaves = log(max(3000.0, rpm_raw) / 3000.0) / log(2.0)
	var gear_octaves = (gear - 1) * 1.5 / 12.0 # 1.5 semitones per gear
	var fundamental = 50.0 * pow(2.0, rpm_octaves + gear_octaves)
	
	for i in range(frames_available):
		var samples = 0.0
		
		# 1. Fundamental (Sine for body)
		_phases[0] = fmod(_phases[0] + fundamental / sample_rate, 1.0)
		samples += 0.3 * sin(_phases[0] * TAU)
		
		# 2. Main Character (Square/Pulse mix for "rasp")
		# We use two saws with slightly different phases to create a pulse-width effect
		_phases[1] = fmod(_phases[1] + fundamental / sample_rate, 1.0)
		var saw1 = 2.0 * (_phases[1] - floor(0.5 + _phases[1]))
		var pulse_phase = fmod(_phases[1] + 0.1 + (throttle * 0.1), 1.0)
		var saw2 = 2.0 * (pulse_phase - floor(0.5 + pulse_phase))
		samples += 0.5 * (saw1 - saw2)
		
		# 3. Mechanical "Clatter" (Phase-locked noise)
		# Noise that triggers once per engine cycle to simulate mechanical impacts
		_phases[2] = fmod(_phases[2] + (fundamental * 0.5) / sample_rate, 1.0) # Camshaft speed
		if _phases[2] < 0.05:
			samples += (randf() * 2.0 - 1.0) * 0.2 * (1.0 + throttle)
		
		# 4. Harmonic richness (3rd Harmonic)
		_phases[3] = fmod(_phases[3] + (fundamental * 3.0) / sample_rate, 1.0)
		samples += 0.2 * (2.0 * (_phases[3] - floor(0.5 + _phases[3])))

		# 5. Asymmetric Drive / Distortion
		# High performance engines have uneven cylinder firing/exhaust pressures
		var drive = 1.0 + throttle * 3.0
		samples *= drive
		# Asymmetric tanh for more complex even harmonics
		if samples > 0:
			samples = tanh(samples * 1.2)
		else:
			samples = tanh(samples * 0.8)
		
		# 6. Final High-Freq Polish
		var hiss = (randf() * 2.0 - 1.0) * 0.02 * (1.0 + throttle)
		samples += hiss
		
		var sample = Vector2(samples, samples) * 0.4
		playback.push_frame(sample)
