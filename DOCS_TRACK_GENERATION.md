# Track Generation from JSON Points

This document describes the process of adapting real-world (or OSM-derived) 3D points into a format suitable for high-quality track generation in Godot.

## Process Overview

1.  **Source Data**: JSON files containing a list of `x, y, z` coordinates representing the centerline of a track.
2.  **Harmonization (Preprocessing)**:
    -   Raw points are often unevenly spaced or too sparse for smooth mesh extrusion.
    -   A Python script (`scripts/process_track.py`) uses **Cubic Spline Interpolation** (specifically `scipy.interpolate.CubicSpline` with periodic boundary conditions) to create a smooth, continuous path.
    -   The path is resampled at a consistent interval (e.g., every 5 meters) to ensure uniform geometry.
    -   **Tangents** are calculated at each point to provide orientation for the road cross-section.
3.  **Godot Adaptation**:
    -   The processed points are saved to a new JSON format containing `x, y, z` and `tx, ty, tz` (tangent vector).
    -   A Godot script (`scripts/track_from_json.gd`) reads these points.
    -   It uses a `MeshTurtle` (a custom extrusion tool) to "sweep" a road profile along the interpolated path.
    -   The `MeshTurtle` is oriented at each step using the tangent vectors and optional **roll (banking)** data, ensuring the road surface correctly follows the track's direction and banking (e.g., Madrid's 24% turn).
    -   The result is a single continuous mesh with optimized UVs and collision geometry.

## Optional JSON Fields
-   `roll` (float): Banking angle in radians. Used to tilt the track surface. Supported in both raw points (interpolated via Spline) and processed points.

## Tools Used

-   **Python 3**: For spline interpolation and resampling.
    -   `scipy`: Used for Cubic Spline calculation.
    -   `numpy`: Used for vector operations.
-   **Godot 4**: For mesh generation and scene creation.
    -   `MeshTurtle`: A procedural geometry class that handles `SurfaceTool` operations.

## How to generate new tracks

1.  Place your raw JSON points in the source directory.
2.  Run the Python processing script:
    ```bash
    python3 scripts/process_track.py
    ```
3.  Run the Godot generation script (can be done headlessly):
    ```bash
    godot --headless -s scripts/test_gen_json.gd
    ```
4.  The generated scenes will be available in `res://scenes/`.

## Results
-   **USA Miami**: Resampled from 259 to 1086 points (5.4km).
-   **Spain (Barcelona)**: Resampled from 221 to 942 points (4.7km).
-   **Spain (Madrid)**: 2026 layout with 24% banking on Turn 12.
-   **Netherlands (Zandvoort)**: Authentic 34% (Turn 3) and 32% (Turn 14) banking.
