# Godot Open Seater: F1 Time Trial

<video src="media/demo.mp4" muted autoplay loop controls style="max-width: 100%;"></video>

A precision-focused, open-seater time trial racing game built with Godot 4 and Jolt Physics, featuring real-world F1 circuits.

## Core Game Systems

### 1. Car Physics (`scripts/car_controller.gd`)
The vehicle utilizes a custom Raycast-based suspension system designed for high-speed stability and aerodynamic grip.
- **Visuals:** WIP. super basic track and car for now
- **Suspension & Downforce:** Four independent raycasts simulate spring and damping forces. A dynamic downforce system increases grip at high speeds.
- **Tire Model:** Physics include lateral grip calculations and slip angles, allowing for realistic cornering and controlled slides under heavy braking.
- **Audio:** Real-time procedural engine synthesis (`engine_sound.gd`), tire scrub noise, and environmental collisions.
- **Trails:** Dynamic tire mark rendering (`trail_renderer.gd`) based on slip velocity and surface pressure.

### 2. Race Management (`scripts/game_manager.gd`)
A global singleton (Autoload) managing the competitive lifecycle and state.
- **Ghost Car:** Automatically records your fastest lap and replays it as a semi-transparent opponent (`scripts/ghost_car.gd`).
- **Persistence:** Highscores, lap times, and user configurations are saved to `user://game_data.json`.
- **Global Control:** Quick restart (T), SFX toggles (1), Track cycling (2), and Ghost visibility (4).

### 3. Track Generation (`scripts/track_from_json.gd`)
Constructs semi-accurate racing circuits from OSM/GeoJSON/Telemetry data.
- **Profile:** Uses an F1-spec road profile with distinct kerbs and runoff areas.
- **Precision:** Supports high-frequency elevation data and banking (roll) per point.
- **Customization:** Data-driven transformation flags for reversing direction or shifting start/finish lines.

### 4. F1 Telemetry & Audit Pipeline
Tools to ensure parity between in-game tracks and real-world data.

- **Visual Comparison (`scripts/compare_elevation.py`):** Generates side-by-side elevation profiles of the game track vs. official F1 telemetry.
- **Telemetry Injection (`scripts/inject_f1_elevation.py`):** Replaces noisy manual data with high-precision GPS/Altimeter telemetry from FastF1.
- **3D Inspector (`scenes/track_viewer.tscn`):** Dedicated tool for auditing geometry, banking, and elevation in 3D.

## Controls
- **Accelerate/Brake/Steer:** - programmable keys/joystick (press 3 to rebind)
- **Restart Race:** T / Joypad Button 3 (Y/Triangle)
- **Previous Track:** 1
- **Next Track:** 2
- **Rebind controls:** 3
- **Toggle Ghost:** 4
- **Toggle Sound:** 5
- **Toggle Camera:** 6/C
- **Toggle Map:**: 7/M
- **Toggle Fullscreen:** 0
- **Reset record:** X
- **Quit Game:** Escape

## command line args

```
--track <trackname>
--generate [--force]
```

## circuit tweaks

- **Toggle Edit Mode:** ctrl+E 
- **lerp/normalize heights:** V
- **Less points:** [
- **More points:** ]
- **Save:** ctrl+S

## Credits & Acknowledgments
- **Engine Sound Loops:** by [domasx2](https://opengameart.org/users/domasx2) (CC0) from [OpenGameArt](https://opengameart.org/content/racing-car-engine-sound-loops).
- **[FastF1](https://github.com/theOehrly/Fast-F1):** Used for retrieving high-precision F1 telemetry data to fix some circuit heights and disparities.
- **[f1-circuits (bacinger)](https://github.com/bacinger/f1-circuits):** Source for the Madrid (Madring) circuit GeoJSON used to map the upcoming 2026 layout.

## License
This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** license. See the [LICENSE](LICENSE) file for details.
