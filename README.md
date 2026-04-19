# Godot Trial Maniac

A high-paced, Trackmania-inspired time trial racing game built with Godot 4 and Jolt Physics.

## Core Game Logic

### 1. Car Physics (`scripts/car_controller.gd`)
The car is modeled as an open-seater racing vehicle (Formula style) using a custom Raycast-based suspension system.
- **Visuals:** Features a procedurally generated mesh (`assets/open_seater_mesh.tscn`) with a tapered nose, front and rear wings, and sidepods.
- **Suspension & Downforce:** Four raycasts calculate spring and damping forces. A custom "Sticky Downforce" system applies 10,000 units of force towards the track surface **only when driving on Loop or Side Pipe segments**, allowing the car to complete vertical stunts without affecting natural physics on standard track pieces.
- **Performance:** Tuned with a 1,500kg mass and 30,000 engine power. Top speed is approximately 360 KM/H (100 m/s).
- **Engine & Steering:** Forces are applied locally to the RigidBody based on wheel orientation. Boosters apply a 40,000 unit forward impulse. Steering is speed-sensitive, gradually reducing at higher speeds for better stability.
- **Grip:** Lateral forces are applied to simulate tire friction and prevent excessive sliding.
- **Air Control:** Pitch control allows players to adjust their orientation while in the air.
- **Out-of-Bounds:** Automatically resets the race if the car falls below Y = -20.
- **Audio:** Procedural engine loops, skid noise, brake squeals, and collision thumps.

### 2. Race Management (`scripts/game_manager.gd`)
A global singleton (Autoload) that handles the race lifecycle, track progression, and persistence.
- **States:** `PRE_START`, `RACING`, `FINISHED`.
- **Timing:** Precision timer that starts at the start gate and stops at the finish gate.
- **Track Progression:** Automatically transitions to the next track in the list 2 seconds after crossing the finish line. Manual switching available via the '2' key.
- **Persistence:** Highscores are saved to `user://highscores.json`. If no record exists, it defaults to 10:00.000.
- **Best Time:** Tracks and displays the personal best for the current session and track.
- **Global Input:** Manages restart (T), SFX toggle (1), Next Track (2), Fullscreen (0), and Quit (Esc).

### 3. Track Generation Tool (`scripts/create_blocks.gd`)
This script acts as a procedural generation utility for the track's modular pieces. 

**Note: This tool does NOT run automatically at game start.** It is a build-time utility used to update the `.tscn` files in `res://scenes/blocks/`.

#### How to run the tool:
Execute the following command from the project root:
```bash
godot --headless -s scripts/create_blocks.gd
```

- **Procedural Meshes:** Uses `SurfaceTool` to generate geometry for curves, side pipes, and loops.
- **Block Types:**
  - `START`, `FINISH`, `BOOSTER`
  - `STRAIGHT`, `STRAIGHT_LONG`, `STRAIGHT_LONG_WO_WALLS`
  - `RAMP`, `CURVE_TIGHT`, `CURVE_WIDE`, `CURVE_EXTRA_WIDE`
  - `SIDE_PIPE`, `LOOP_360`, `LOOP_90`

### 4. Camera System (`scripts/follow_camera.gd`)
A smooth follow camera with 2-frame easing and high-speed stabilization to filter out physics jitter.

### 5. HUD & UI (`scripts/hud.gd`)
- **Timer:** Displays race duration using "Press Start 2P" font.
- **Speedometer:** Real-time speed in KM/H.
- **Record:** Displays the all-time best for the current track in the top-right corner.
- **Finish Screen:** Completion details and session personal best.

## Assets
- `assets/fonts/PressStart2P-Regular.ttf`: Retro-styled HUD font.
- `assets/open_seater_mesh.tscn`: Procedural player vehicle mesh.

## Controls
- **Accelerate/Brake:** Up/Down / W/S / Joypad R2/L2 or Axis
- **Steer:** Left/Right / A/D / Joypad Left Stick
- **Restart Race:** T / Joypad Button 3 (Y/Triangle)
- **Next Track:** 2 / Joypad Button 9 (Select/Share)
- **Toggle SFX:** 1
- **Toggle Fullscreen:** 0
- **Quit Game:** Escape / Joypad Start/Options (via ui_cancel)
