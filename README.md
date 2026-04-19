# Godot Trial Maniac

A high-paced, Trackmania-inspired time trial racing game built with Godot 4 and Jolt Physics.

## Core Game Logic

### 1. Car Physics (`scripts/car_controller.gd`)
The car uses a custom Raycast-based suspension system rather than the built-in VehicleBody3D for more arcade-like control.
- **Suspension:** Four raycasts calculate spring and damping forces to keep the car afloat.
- **Engine & Steering:** Forces are applied locally to the RigidBody based on wheel orientation.
- **Grip:** Lateral forces are applied to simulate tire friction and prevent excessive sliding.
- **Air Control:** Torque is applied while in the air to allow players to adjust their pitch and yaw.
- **Out-of-Bounds:** Automatically resets the race if the car falls below Y = -20.

### 2. Race Management (`scripts/game_manager.gd`)
A global singleton (Autoload) that handles the lifecycle of a race.
- **States:** `PRE_START`, `RACING`, `FINISHED`.
- **Timing:** Precision timer that starts at the start gate and stops at the finish gate.
- **Best Time:** Persists the best time during the session.
- **Formatting:** Utility for converting seconds into `MM:SS.mmm` format.

### 3. Track Generation Tool (`scripts/create_blocks.gd`)
This script acts as a procedural generation utility for the track's modular pieces. It is designed to be run as a tool (or via `SceneTree`) to rebuild the library of track segments.
- **Procedural Meshes:** Uses `SurfaceTool` to generate geometry for complex shapes like curves (`RoadCurveTight`, `RoadCurveWide`) with custom inner/outer radii.
- **Automated Collision:** Automatically generates `TrimeshCollisionShape3D` for procedural meshes and `BoxShape3D` for standard ones.
- **Material & Shading:** Assigns materials with specific properties, such as emission for boosters and consistent road colors.
- **Gate Generation:** Procedurally constructs the Start and Finish gate structures.
- **Global Offsets:** Ensures all blocks are correctly aligned on the Y-axis (0.5m offset) to maintain consistent physics interaction.

### 4. Track Block System (`scripts/track_block.gd`)
The modular pieces created by the generator are used to assemble levels.
- **Block Types:**
  - `START`: Triggers the race timer via `GameManager`.
  - `FINISH`: Stops the timer and records the score.
  - `BOOSTER`: Applies a massive forward impulse to the car's RigidBody.
  - `STRAIGHT`, `RAMP`, `CURVE`: Structural road pieces that provide collision and visual feedback.

### 5. Camera System (`scripts/follow_camera.gd`)
A smooth follow camera that tracks the car's position and orientation, looking slightly ahead of the vehicle to give the player a better view of the track.

### 5. HUD & UI (`scripts/hud.gd`)
- **Timer:** Real-time display of the current race duration.
- **Finish Screen:** Displays completion time and personal best.
- **Controls:** `ui_cancel` (Esc) triggers an immediate race reset.

## Project Structure
- `assets/`: 3D models and textures.
- `scenes/`: Main game levels and the UI.
- `scenes/blocks/`: Individual modular track pieces.
- `scripts/`: All GDScript logic.

## Controls
- **Accelerate/Brake:** Up/Down / W/S
- **Steer:** Left/Right / A/D
- **Pitch/Yaw (Air):** Arrow Keys / WASD
- **Reset:** Escape
