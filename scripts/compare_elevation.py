import json
import os
import sys
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import savgol_filter
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
    if not points:
        return None
        
    dists = [0.0]
    total_dist = 0.0
    for i in range(1, len(points)):
        p1, p2 = points[i-1], points[i]
        d = np.sqrt((p2['x']-p1['x'])**2 + (p2['z']-p1['z'])**2 + (p2['y']-p1['y'])**2)
        total_dist += d
        dists.append(total_dist)
        
    y_vals = np.array([p['y'] for p in points])
    # Apply the same X-flip as track_from_json.gd
    x_coords = np.array([-p['x'] for p in points]) 
    z_coords = np.array([p['z'] for p in points])
    
    return {
        "dist": np.array(dists),
        "y": y_vals,
        "x": x_coords,
        "z": z_coords,
        "total_length": total_dist
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
        
        dist = tel['Distance'].values
        z = tel['Z'].values
        x = tel['X'].values
        y = tel['Y'].values
        
        if len(z) > 15:
            z = savgol_filter(z, 15, 3)
            
        return {
            "dist": dist,
            "z": z,
            "x": x,
            "y": y,
            "total_length": dist[-1]
        }
    except Exception as e:
        print(f"FastF1 Error: {e}")
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 compare_elevation.py <track_id> [year]")
        print("Available track_ids: " + ", ".join(F1_CONFIG.keys()))
        return

    track_id = sys.argv[1].lower()
    if track_id not in F1_CONFIG:
        print(f"Error: Unknown track_id '{track_id}'")
        return
        
    event_info = F1_CONFIG[track_id]
    event_name = event_info["name"]
    year = int(sys.argv[2]) if len(sys.argv) > 2 else event_info["year"]
    
    game_data = load_game_track(track_id)
    f1_data = fetch_fastf1_telemetry(event_name, year)
    
    if not game_data or not f1_data:
        print("Failed to load one or both datasets.")
        return
        
    game_dist_norm = game_data['dist'] / game_data['total_length']
    f1_dist_norm = f1_data['dist'] / f1_data['total_length']
    
    game_y_norm = game_data['y'] - np.min(game_data['y'])
    f1_y_norm = (f1_data['z'] - np.min(f1_data['z'])) / 10.0
    
    def get_norm_map(x, y):
        x_c = x - np.mean(x)
        y_c = y - np.mean(y)
        scale = max(np.max(np.abs(x_c)), np.max(np.abs(y_c)))
        return x_c / scale, y_c / scale

    f1_mx, f1_my = get_norm_map(f1_data['x'], f1_data['y'])
    
    best_game_mx, best_game_my = get_norm_map(game_data['x'], game_data['z'])
    min_error = float('inf')
    
    gx = game_data['x']
    gz = game_data['z']
    orientations = [
        (gx, gz), (-gx, gz), (gx, -gz), (-gx, -gz),
        (gz, gx), (-gz, gx), (gz, -gx), (-gz, -gx)
    ]
    
    for ox, oy in orientations:
        nmx, nmy = get_norm_map(ox, oy)
        indices = [0, len(nmx)//4, len(nmx)//2, 3*len(nmx)//4]
        f1_indices = [0, len(f1_mx)//4, len(f1_mx)//2, 3*len(f1_mx)//4]
        error = 0
        for i in range(len(indices)):
            error += (nmx[indices[i]] - f1_mx[f1_indices[i]])**2 + (nmy[indices[i]] - f1_my[f1_indices[i]])**2
        
        if error < min_error:
            min_error = error
            best_game_mx, best_game_my = nmx, nmy

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 12), gridspec_kw={'height_ratios': [1.2, 1]})
    
    ax1.plot(f1_mx, f1_my, color='blue', alpha=0.3, linewidth=6, label='FastF1 (Reference)')
    ax1.plot(best_game_mx, best_game_my, color='red', linestyle='--', linewidth=2, label='Game JSON (Auto-Aligned)')
    
    ax1.scatter(f1_mx[0], f1_my[0], color='green', s=100, zorder=5, label='Start/Finish')
    ax1.scatter(best_game_mx[0], best_game_my[0], color='green', s=30, zorder=5)
    
    ax1.set_aspect('equal')
    ax1.set_title(f"Track Shape Alignment Check - {event_name} ({year})")
    ax1.legend()
    ax1.grid(True, alpha=0.1)
    
    ax2.plot(f1_dist_norm * 100, f1_y_norm, label='FastF1 (Real World)', color='blue', linewidth=2)
    ax2.plot(game_dist_norm * 100, game_y_norm, label='Game JSON (Current)', color='red', linestyle='--', alpha=0.8)
    
    ax2.set_xlabel("Lap Distance (%)")
    ax2.set_ylabel("Relative Elevation (m)")
    ax2.set_title(f"Elevation Profile Comparison - {event_name}")
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    output_img = f"elevation_comparison_{track_id}.png"
    plt.savefig(output_img)
    print(f"Comparison saved to {output_img}")

if __name__ == "__main__":
    main()
