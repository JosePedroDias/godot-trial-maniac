import json
import os
import sys
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import savgol_filter
from scipy.interpolate import interp1d, CubicSpline
import fastf1
import logging
from f1_config import F1_CONFIG

def load_game_track(track_id):
    path = f"assets/tracks/{track_id}_processed.json"
    if not os.path.exists(path):
        print(f"Error: Game track file not found at {path}")
        return None
    
    with open(path, 'r') as f:
        data = json.load(f)
    
    points = data.get("points", [])
    if not points: return None
        
    y_vals = np.array([p['y'] for p in points])
    # IMPORTANT: The raw JSON is in "Processor Space". 
    # Loader flips X. We want to align the RAW data first.
    x_coords = np.array([p['x'] for p in points]) 
    z_coords = np.array([p['z'] for p in points])
    
    return {
        "raw_data": data,
        "y": y_vals,
        "x": x_coords,
        "z": z_coords,
        "points": points
    }

def fetch_fastf1_telemetry(event_name, year):
    fastf1.Cache.enable_cache('assets/fastf1_cache')
    logging.getLogger('fastf1').setLevel(logging.WARNING)
    print(f"Fetching FastF1 telemetry for {event_name} {year}...")
    try:
        session = fastf1.get_session(year, event_name, 'Q')
        session.load(telemetry=True, weather=False, messages=False)
        lap = session.laps.pick_fastest()
        tel = lap.get_telemetry()
        
        # FastF1 uses X, Y for horizontal, Z for elevation
        # Ensure distance starts at 0 for robust interpolation
        dist = tel['Distance'].values
        dist = dist - dist[0]
        
        return {
            "dist": dist,
            "z_elev": tel['Z'].values / 10.0, # Elevation
            "x": tel['X'].values,
            "y": tel['Y'].values # Horizontal Y
        }
    except Exception as e:
        print(f"FastF1 Error: {e}")
        return None

def align_track(game_data, f1_data):
    # Center both
    f1_x = f1_data['x'] - np.mean(f1_data['x'])
    f1_y = f1_data['y'] - np.mean(f1_data['y'])
    
    # Scale F1 to roughly match game scale for better alignment heuristics
    # (FastF1 units are 0.1m, Game JSON is meters usually)
    f1_x /= 10.0
    f1_y /= 10.0
    
    best_mse = float('inf')
    best_config = None # (flip_x, flip_z, swap, offset)
    
    gx_orig = game_data['x'] - np.mean(game_data['x'])
    gz_orig = game_data['z'] - np.mean(game_data['z'])

    print("Optimizing spatial alignment...")
    
    # Test 8 orientations
    for flip_x in [1, -1]:
        for flip_z in [1, -1]:
            for swap in [False, True]:
                gx = gx_orig * flip_x
                gz = gz_orig * flip_z
                if swap: gx, gz = gz, gx
                
                # Heuristic: Match 4 quadrants of the lap
                # To handle different sample counts, we interpolate
                f_x = interp1d(np.linspace(0, 1, len(f1_x)), f1_x)
                f_y = interp1d(np.linspace(0, 1, len(f1_y)), f1_y)
                
                # Test offsets (sliding start line)
                # For efficiency, we only test 10% increments for the initial guess
                for offset_pct in np.linspace(0, 0.9, 10):
                    shifted_gx = np.roll(gx, -int(offset_pct * len(gx)))
                    shifted_gz = np.roll(gz, -int(offset_pct * len(gz)))
                    
                    target_gx = interp1d(np.linspace(0, 1, len(shifted_gx)), shifted_gx)
                    target_gz = interp1d(np.linspace(0, 1, len(shifted_gz)), shifted_gz)
                    
                    mse = 0
                    for t in [0, 0.25, 0.5, 0.75]:
                        mse += (f_x(t) - target_gx(t))**2 + (f_y(t) - target_gz(t))**2
                    
                    if mse < best_mse:
                        best_mse = mse
                        best_config = (flip_x, flip_z, swap, offset_pct)

    print(f"Best Alignment MSE: {best_mse:.2f}")
    return best_config

def calculate_tangents(points):
    """Recalculate normalized tangents for MeshTurtle."""
    n = len(points)
    tangents = []
    for i in range(n):
        p_prev = points[(i - 1 + n) % n]
        p_next = points[(i + 1) % n]
        
        diff = p_next - p_prev
        mag = np.linalg.norm(diff)
        if mag > 0:
            tangents.append(diff / mag)
        else:
            tangents.append(np.array([0, 0, 1]))
    return np.array(tangents)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 sync_track_to_f1.py <track_id> [--adopt-shape]")
        return

    track_id = sys.argv[1].lower()
    adopt_shape = "--adopt-shape" in sys.argv
    
    config = F1_CONFIG.get(track_id)
    if not config:
        print(f"Error: No mapping for {track_id}")
        return
        
    game_data = load_game_track(track_id)
    f1_data = fetch_fastf1_telemetry(config["name"], config["year"])
    
    if not game_data or not f1_data: return

    # 1. Align
    flip_x, flip_z, swap, offset_pct = align_track(game_data, f1_data)
    
    # Apply spatial transform to original points
    points = game_data['points']
    n = len(points)
    offset = int(offset_pct * n)
    points = points[offset:] + points[:offset]
    
    for p in points:
        p['x'] *= flip_x
        p['z'] *= flip_z
        if swap: p['x'], p['z'] = p['z'], p['x']
        # Note: Tangents also need flipping but we will just recalculate them to be safe
    
    # 2. Correction
    # F1 Telemetry Normalization
    f1_dist_norm = f1_data['dist'] / f1_data['dist'][-1]
    f1_z = f1_data['z_elev'] - np.min(f1_data['z_elev']) + 5.0
    
    # Ensure periodic closure for F1 data
    f1_z[0] = (f1_z[0] + f1_z[-1]) / 2.0
    f1_z[-1] = f1_z[0]
    
    f1_z_smooth = savgol_filter(f1_z, 15, 3) if len(f1_z) > 15 else f1_z
    f1_z_smooth[-1] = f1_z_smooth[0] # Re-force after smoothing
    
    f_elev = CubicSpline(f1_dist_norm, f1_z_smooth, bc_type='periodic')
    
    # Target Resampling at 5m spacing
    total_len = f1_data['dist'][-1] # FastF1 distance is already in meters
    num_samples = int(total_len / 5.0)
    sample_dist_norm = np.linspace(0, 1, num_samples, endpoint=False)
    
    new_points = []
    if adopt_shape:
        print(f"REPAIR MODE: Adopting full F1 telemetry shape and resampling to {num_samples} points...")
        fx = (f1_data['x'] - np.mean(f1_data['x'])) / 10.0
        fz = (f1_data['y'] - np.mean(f1_data['y'])) / 10.0
        
        # Ensure closure for shape
        fx[0] = (fx[0] + fx[-1]) / 2.0; fx[-1] = fx[0]
        fz[0] = (fz[0] + fz[-1]) / 2.0; fz[-1] = fz[0]
        
        f_x = CubicSpline(f1_dist_norm, fx, bc_type='periodic')
        f_z = CubicSpline(f1_dist_norm, fz, bc_type='periodic')
        
        pos_xyz = np.stack([f_x(sample_dist_norm), f_elev(sample_dist_norm), f_z(sample_dist_norm)], axis=1)
    else:
        print(f"SYNC MODE: Resampling OSM shape and injecting F1 elevation ({num_samples} points)...")
        osm_xyz = np.array([[p['x'], p['y'], p['z']] for p in points])
        
        # Ensure OSM loop is closed for periodic spline
        if not np.allclose(osm_xyz[0], osm_xyz[-1]):
            osm_xyz = np.vstack([osm_xyz, osm_xyz[0]])
            
        dists = [0.0]
        curr_d = 0.0
        for i in range(1, len(osm_xyz)):
            curr_d += np.sqrt(np.sum((osm_xyz[i][:3:2] - osm_xyz[i-1][:3:2])**2))
            dists.append(curr_d)
        osm_dist_norm = np.array(dists) / curr_d
        
        # Re-force exact equality for floating point safety
        osm_x = osm_xyz[:, 0]; osm_x[-1] = osm_x[0]
        osm_z = osm_xyz[:, 2]; osm_z[-1] = osm_z[0]
        
        f_osm_x = CubicSpline(osm_dist_norm, osm_x, bc_type='periodic')
        f_osm_z = CubicSpline(osm_dist_norm, osm_z, bc_type='periodic')
        
        pos_xyz = np.stack([f_osm_x(sample_dist_norm), f_elev(sample_dist_norm), f_osm_z(sample_dist_norm)], axis=1)
    
    # Calculate smooth tangents from the new clean positions
    tangents = calculate_tangents(pos_xyz)
    
    for i in range(num_samples):
        new_points.append({
            "x": float(pos_xyz[i][0]), "y": float(pos_xyz[i][1]), "z": float(pos_xyz[i][2]),
            "tx": float(tangents[i][0]), "ty": float(tangents[i][1]), "tz": float(tangents[i][2])
        })

    # 3. Save
    data = game_data['raw_data']
    data['points'] = new_points
    data['reverseDirection'] = False
    data['startPositionRatio'] = 0.0
    
    out_path = f"assets/tracks/{track_id}_processed.json"
    with open(out_path, 'w') as f:
        json.dump(data, f, indent=2)
        
    print(f"SAVED: {out_path} ({len(new_points)} points)")
    
    # 4. Plot Verification
    # (Reuse plotting logic from compare script)
    os.system(f"python3 scripts/compare_elevation.py {track_id}")

if __name__ == "__main__":
    main()
