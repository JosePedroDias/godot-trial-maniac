# Godot Trial Maniac

A high-paced, Trackmania-inspired time trial racing game built with Godot 4 and Jolt Physics.

## Core Game Logic

### 1. Car Physics (`scripts/car_controller.gd`)
The car is modeled as an open-seater racing vehicle (Formula style) using a custom Raycast-based suspension system.
- **Visuals:** Features a procedurally generated mesh (`assets/open_seater_mesh.tscn`) with a tapered nose, front and rear wings, and sidepods.
- **Suspension & Downforce:** Four raycasts calculate spring and damping forces (stiffened for high-speed stability). A custom "Sticky Downforce" system applies 10,000 units of force towards the track surface **only when driving on Loop or Side Pipe segments**.
- **Performance:** Tuned with a 1,500kg mass and 15,000 engine power for controlled acceleration. Top speed is approximately 360 KM/H (100 m/s).
- **Engine & Steering:** Supports both standard Input Map and advanced per-device axis assignments. Steering is speed-sensitive.
- **Audio:** Procedural engine loops, skid noise, brake squeals, and collision thumps.

### 2. Race Management (`scripts/game_manager.gd`)
A global singleton (Autoload) that handles the race lifecycle, track progression, and data persistence.
- **States:** `PRE_START`, `RACING`, `FINISHED`, `BINDING`.
- **Timing:** Precision timer that starts at the start gate and stops at the finish gate.
- **Track Progression:** Automatically transitions to the next track in the list 2 seconds after crossing the finish line. Manual switching via '2'.
- **Ghost Car:** Records your best run per track and displays it as a semi-transparent ghost during the race.
- **Persistence:** Highscores, Input Assignments (v3), and Ghost data are saved to the user folder.
- **Global Input:** Manages restart (T), SFX toggle (1), Next Track (2), Fullscreen (0), Joypad Binding (3), and Ghost Toggle (4).

### 3. Track Generation Tool (`scripts/create_blocks.gd`)
This script acts as a procedural generation utility for the track's modular pieces. 

**Note: This tool does NOT run automatically at game start.** It is a build-time utility used to update the `.tscn` files in `res://scenes/blocks/`.

#### How to run the tool:
Execute the following command from the project root:
```bash
godot --headless -s scripts/create_blocks.gd
```

- **Procedural Meshes:** Uses `SurfaceTool` to generate geometry for curves, side pipes, and loops.
- **Block Types:** `START`, `FINISH`, `BOOSTER`, `STRAIGHT`, `STRAIGHT_LONG`, `STRAIGHT_LONG_WO_WALLS`, `RAMP`, `CURVE_TIGHT`, `CURVE_WIDE`, `CURVE_EXTRA_WIDE`, `SIDE_PIPE`, `LOOP_360`, `LOOP_90`.

### 4. Camera System (`scripts/follow_camera.gd`)
A smooth follow camera with 2-frame easing and high-speed stabilization.

### 5. HUD & UI (`scripts/hud.gd`)
- **Timer:** Displays race duration using "Press Start 2P" font.
- **Speedometer:** Real-time speed in KM/H.
- **Record:** Displays the all-time best for the current track.
- **Binding Overlay:** Guided instructions for joypad axis assignment.
- **Finish Screen:** Completion details and "NEW RECORD!" feedback.

## Controls
- **Accelerate/Brake:** Up/Down / W/S / Joypad Triggers or Assigned Axis
- **Steer:** Left/Right / A/D / Joypad Stick or Assigned Axis
- **Restart Race:** T / Joypad Button 3 (Y/Triangle)
- **Next Track:** 2 / Joypad Button 9 (Select)
- **Toggle SFX:** 1
- **Toggle Ghost:** 4
- **Toggle Fullscreen:** 0
- **Bind Joypad Axis:** 3
- **Quit Game:** Escape
