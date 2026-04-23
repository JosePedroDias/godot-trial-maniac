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

### 4. Build Tools
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

## License
This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)** license. See the [LICENSE](LICENSE) file for details.
