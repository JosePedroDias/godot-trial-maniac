# Godot Trial Maniac

<video src="media/demo.mp4" muted autoplay loop controls style="max-width: 100%;"></video>

A high-paced, Trackmania-inspired time trial racing game built with Godot 4 and Jolt Physics.

## Core Game Logic

### 1. Car Physics (`scripts/car_controller.gd`)
The car uses a custom Raycast-based suspension system for high-speed stability and grip.
- **Visuals:** Features a procedurally generated racing blue chassis (`assets/open_seater_mesh.tscn`).
- **Suspension & Downforce:** Four raycasts calculate spring and damping forces. A "Sticky Downforce" system applies force towards the track surface on Loops and Side Pipes to allow inverted driving.
- **Drifting & Grip:** Physics model includes lateral grip calculations, allowing for controlled drifts when braking or applying high throttle while turning.
- **Audio:** Real-time procedural engine loops (`engine_sound.gd`), skid noise, brake squeals, and collision thumps.
- **Trails:** Procedural trail rendering (`trail_renderer.gd`) for tire marks during skidding and braking.

### 2. Race Management (`scripts/game_manager.gd`)
A global singleton (Autoload) that handles the race lifecycle and track progression.
- **Ghost Car:** Records your best run and displays it as a semi-transparent actor (`scripts/ghost_car.gd`) using custom resources (`scripts/ghost_resource.gd`).
- **Persistence:** Automatically saves highscores and input assignments to `user://game_data.json`.
- **Global Input:** Manages restart (T), SFX toggle (1), Next Track (2), Fullscreen (0), Joypad Binding (3), and Ghost Toggle (4).

### 3. Track Generation Systems
The game features two distinct methods of procedural track generation, both built on the **MeshTurtle** geometry engine.

#### MeshTurtle (`scripts/mesh_turtle.gd`)
A 3D "Turtle" API that extrudes a 2D cross-section (profile) into 3D geometry as it moves. 
- **Conventions:** Road surface is strictly aligned at **Y=0** in local space.
- **Features:** Supports smooth stepping for curves, branching (push/pop state), and automatic UV mapping for tiled road textures.

#### A. Modular Generator (`scripts/track_generator.gd`)
Uses a tile-based backtracking algorithm to assemble pre-generated blocks.
- **Logic:** Shuffles available blocks based on weights, checks for AABB collisions, and backtracks if it hits a dead end.
- **Regenerate Tracks:** `godot --headless -s scripts/test_gen.gd`

#### B. Organic Continuous Generator (`scripts/continuous_track_generator.gd`)
Generates one massive, flowing mesh using smoothed random steering.
- **Logic:** Uses lerped targets for Yaw, Pitch, and Roll to create roller-coaster-like paths with collision detection to prevent self-intersection.
- **Regenerate Tracks:** `godot --headless -s scripts/test_gen_continuous.gd`

#### C. JSON-based Track Generator (`scripts/track_from_json.gd`)
Generates tracks from external point data (e.g., F1 circuit data).
- **Optional JSON Fields:**
  - `reverseDirection` (boolean): If `true`, reverses the point sequence and flips tangents. Useful for fixing clockwise/counter-clockwise errors.
  - `startPositionRatio` (float, 0.0 to 1.0): Rotates the starting point of the track loop by the given ratio. Useful for aligning the start/finish gate.
- **Regenerate Tracks:** `godot --headless -s scripts/test_gen_json.gd`

#### D. Track Height Editor (`scripts/track_editor.gd`)
A runtime tool to refine track elevations directly in-game.
- **Toggle Edit Mode:** `Ctrl + E`
- **Adjust Height:** `PageUp` / `PageDown` (Nearest point)
- **Smooth Adjust (Brush):** `Shift` + `PageUp` / `PageDown` (Averages neighboring points for smooth slopes)
- **Save to JSON:** `Ctrl + S` (Overwrites the source `.json` file and flattens transformation flags for perfect offline persistence)

### 4. Track Audit & Repair Pipeline
A suite of tools to ensure tracks match real-world Formula 1 circuits.

#### A. Visual Audit (`scripts/compare_elevation.py`)
Generates a side-by-side comparison of the game's track vs. official F1 telemetry.
```bash
python3 scripts/compare_elevation.py <track_id>
```
Outputs an image (`elevation_comparison_<id>.png`) showing track alignment and elevation profiles.

#### B. Automated Repair (`scripts/inject_f1_elevation.py`)
Injects high-precision F1 telemetry data directly into the game's JSON files, fixing spikes and inaccuracies.
```bash
python3 scripts/inject_f1_elevation.py <track_id>
```
*Note: Run `godot -s scripts/test_gen_json.gd --force` after injecting to update the game scenes.*

#### C. 3D Inspection (`scenes/track_viewer.tscn`)
A dedicated orbit-camera viewer to inspect track geometry and elevation in 3D.
```bash
godot scenes/track_viewer.tscn -- <track_id>
```
- **LMB (Drag):** Orbit
- **RMB (Drag):** Pan
- **Wheel:** Zoom

### 5. Build Tools
These scripts are utility tools used to generate the static assets of the game.

- **Block Regeneration (`scripts/create_blocks.gd`):** 
  Constructs all modular blocks (Curves, Loops, Ramps, Side Pipes) and saves them as `.tscn` files.
  ```bash
  godot --headless -s scripts/create_blocks.gd
  ```
- **Car Mesh Generation (`scripts/create_car_mesh.gd`):**
  Constructs the racing vehicle and saves it as `res://assets/open_seater_mesh.tscn`.
  ```bash
  godot --headless -s scripts/create_car_mesh.gd
  ```

## Controls
- **Accelerate/Brake:** Up/Down / W/S / Joypad Triggers
- **Steer:** Left/Right / A/D / Joypad Stick
- **Restart Race:** T / Joypad Button 3 (Y/Triangle)
- **Toggle SFX:** 1
- **Next Track:** 2 / Joypad Button 9 (Select)
- **Bind Inputs:** 3
- **Toggle Ghost:** 4
- **Toggle Fullscreen:** 0
- **Quit Game:** Escape

## Credits & Acknowledgments
- **[FastF1](https://github.com/theOehrly/Fast-F1):** Used for retrieving high-precision F1 telemetry data to fix circuit heights and disparities.
- **[f1-circuits (bacinger)](https://github.com/bacinger/f1-circuits):** Source for the Madrid (Madring) circuit GeoJSON used to map the upcoming 2026 layout.

## License
This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** license. See the [LICENSE](LICENSE) file for details.
