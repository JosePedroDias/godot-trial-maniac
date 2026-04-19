# Godot Trial Maniac

A high-paced, Trackmania-inspired time trial racing game built with Godot 4 and Jolt Physics.

## Core Game Logic

### 1. Car Physics (`scripts/car_controller.gd`)
The car is modeled as an open-seater racing vehicle (Formula style) using a custom Raycast-based suspension system.
- **Visuals:** Features a procedurally generated mesh (`assets/open_seater_mesh.tscn`) with a tapered nose, front and rear wings, and sidepods for a high-performance aesthetic.
- **Suspension:** Four raycasts calculate spring and damping forces. The car is tuned with a low `suspension_rest_dist` (0.3m) for better stability and to sit within the safety walls.
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
This script acts as a procedural generation utility for the track's modular pieces. 

**Note: This tool does NOT run automatically at game start.** It is a build-time utility used to update the `.tscn` files in `res://scenes/blocks/`.

#### When to run the tool:
- You modify road dimensions, colors, or wall heights in the script.
- You change the procedural mesh generation logic.
- You add new block types to the library.

#### How to run the tool:
Execute the following command from the project root:
```bash
godot --headless -s scripts/create_blocks.gd
```

- **Procedural Meshes:** Uses `SurfaceTool` to generate geometry for complex shapes like curves (`RoadCurveTight`, `RoadCurveWide`, `RoadCurveExtraWide`).
- **Safety Walls:** Automatically generates 0.25m high side walls for all track segments to provide a low-profile guide while preventing the car from falling off.
- **Automated Collision:** Automatically generates `TrimeshCollisionShape3D` for procedural meshes (including walls) and `BoxShape3D` for standard ones.
- **Material & Shading:** Assigns materials with specific properties, such as emission for boosters and consistent road colors.
- **Gate Generation:** Procedurally constructs the Start and Finish gate structures scaled to the road width.
- **Global Offsets:** Ensures all blocks are correctly aligned on the Y-axis (0.5m offset) to maintain consistent physics interaction.

### 4. Track Block System (`scripts/track_block.gd`)
The modular pieces created by the generator are used to assemble levels.
- **Block Types:**
  - `START`: Triggers the race timer via `GameManager`.
  - `FINISH`: Stops the timer and records the score.
  - `BOOSTER`: Applies a massive forward impulse to the car's RigidBody.
  - `STRAIGHT`, `STRAIGHT_LONG`: Standard road pieces (8m wide, 4m and 16m lengths).
  - `STRAIGHT_LONG_WO_WALLS`: 16m straight piece without any side walls, perfect for placing next to wall-ride sections.
  - `RAMP`: Inclined road for jumps and elevation changes.
  - `CURVE_TIGHT`, `CURVE_WIDE`, `CURVE_EXTRA_WIDE`: Curved segments with increasing radii and an 8m road width. All curves include 0.25m side walls with 0.1m thickness.
  - `SIDE_PIPE_LEFT`, `SIDE_PIPE_RIGHT`: 8m long segments that transition from a flat road into a 90-degree cylindrical wall ride (6m radius). These segments have a 0.1m radial thickness and a closed top rim for a solid, high-quality look. Standard safety walls are omitted to allow for seamless entry.
  - `LOOP_360`, `LOOP_90`: Vertical looping segments with a 24m radius and 8m width. Omit side walls for high-speed stunts.

### 5. Camera System (`scripts/follow_camera.gd`)
A smooth follow camera that tracks the car's position and orientation, looking slightly ahead of the vehicle to give the player a better view of the track.

### 6. HUD & UI (`scripts/hud.gd`)
- **Timer:** Real-time display of the current race duration using the "Press Start 2P" retro font.
- **Finish Screen:** Displays completion time and personal best with high-visibility styling.
- **Controls:** Handles global inputs for SFX toggling, race restarts, and quitting.

## Assets
- `assets/fonts/PressStart2P-Regular.ttf`: Google Font used for the retro-styled HUD.
- `assets/open_seater_mesh.tscn`: Procedural mesh for the player vehicle.

## Controls
- **Accelerate/Brake:** Up/Down / W/S
- **Steer:** Left/Right / A/D
- **Restart Race:** T
- **Toggle SFX:** 1
- **Toggle Fullscreen:** 0
- **Quit Game:** Escape
