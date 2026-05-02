import json
import os
import sys
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import savgol_filter
import fastf1
import logging

# Mapping Godot track names to FastF1 event names
TRACK_MAPPING = {
    "abu_dhabi": "Abu Dhabi",
    "australia": "Australia",
    "austria": "Austria",
    "azerbaijan": "Azerbaijan",
    "bahrain": "Bahrain",
    "belgium": "Belgium",
    "brazil": "Brazil",
    "canada": "Canada",
    "china": "China",
    "great_britain": "Great Britain",
    "hungary": "Hungary",
    "italy_emilia": "Emilia Romagna",
    "italy_monza": "Italy",
    "japan": "Japan",
    "mexico": "Mexico",
    "monaco": "Monaco",
    "netherlands": "Netherlands",
    "qatar": "Qatar",
    "saudi_arabia": "Saudi Arabia",
    "singapore": "Singapore",
    "spain_barcelona": "Spain",
    "usa_cota": "United States",
    "usa_las_vegas": "Las Vegas",
    "usa_miami": "Miami"
}

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
        
    # Calculate cumulative distance
    dists = [0.0]
    total_dist = 0.0
    for i in range(1, len(points)):
        p1, p2 = points[i-1], points[i]
        d = np.sqrt((p2['x']-p1['x'])**2 + (p2['z']-p1['z'])**2 + (p2['y']-p1['y'])**2)
        total_dist += d
        dists.append(total_dist)
        
    y_vals = np.array([p['y'] for p in points])
    # Apply the same X-flip as track_from_json.gd to match Godot/Real World
    x_coords = np.array([-p['x'] for p in points]) 
    z_coords = np.array([p['z'] for p in points])
    
    return {
        "dist": np.array(dists),
        "y": y_vals,
        "x": x_coords,
        "z": z_coords,
        "total_length": total_dist
    }

def fetch_fastf1_telemetry(event_name, year=2023):
    fastf1.Cache.enable_cache('assets/fastf1_cache')
    logging.getLogger('fastf1').setLevel(logging.WARNING)
    
    print(f"Fetching FastF1 telemetry for {event_name} {year}...")
    try:
        session = fastf1.get_session(year, event_name, 'Q')
        session.load(telemetry=True, weather=False, messages=False)
        lap = session.laps.pick_fastest()
        tel = lap.get_telemetry()
        
        # Get relative distance
        dist = tel['Distance'].values
        z = tel['Z'].values
        x = tel['X'].values
        y = tel['Y'].values
        
        # Smooth Z data
        if len(z) > 15:
            z = savgol_filter(z, 15, 3)
            
        return {
            "dist": dist,
            "z": z, # elevation in FastF1 is Z
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
        print("Available track_ids: " + ", ".join(TRACK_MAPPING.keys()))
        return

    track_id = sys.argv[1].lower()
    year = int(sys.argv[2]) if len(sys.argv) > 2 else 2023
    
    if track_id not in TRACK_MAPPING:
        print(f"Error: Unknown track_id '{track_id}'")
        return
        
    event_name = TRACK_MAPPING[track_id]
    
    # Load data
    game_data = load_game_track(track_id)
    f1_data = fetch_fastf1_telemetry(event_name, year)
    
    if not game_data or not f1_data:
        print("Failed to load one or both datasets.")
        return
        
    # Normalize Distance (0 to 1)
    game_dist_norm = game_data['dist'] / game_data['total_length']
    f1_dist_norm = f1_data['dist'] / f1_data['total_length']
    
    # Normalize Elevation (Base at 0)
    game_y_norm = game_data['y'] - np.min(game_data['y'])
    f1_y_norm = (f1_data['z'] - np.min(f1_data['z'])) / 10.0 # FastF1 Z is often in 10cm units
    
    # Normalize Map Coordinates for Overlay
    def get_norm_map(x, y):
        x_c = x - np.mean(x)
        y_c = y - np.mean(y)
        scale = max(np.max(np.abs(x_c)), np.max(np.abs(y_c)))
        return x_c / scale, y_c / scale

    f1_mx, f1_my = get_norm_map(f1_data['x'], f1_data['y'])
    game_mx, game_my = get_norm_map(game_data['x'], game_data['z'])

    # Create Visualization
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 12), gridspec_kw={'height_ratios': [1.2, 1]})
    
    # Plot 1: Map Overlay
    ax1.plot(f1_mx, f1_my, color='blue', alpha=0.3, linewidth=4, label='FastF1 (Reference)')
    ax1.plot(game_mx, game_my, color='red', linestyle='--', linewidth=1, label='Game JSON')
    
    # Mark Start Points (index 0)
    ax1.scatter(f1_mx[0], f1_my[0], color='green', s=100, zorder=5, label='Start/Finish')
    ax1.scatter(game_mx[0], game_my[0], color='green', s=30, zorder=5)
    
    ax1.set_aspect('equal')
    ax1.set_title(f"Track Shape Alignment Check - {event_name}")
    ax1.legend()
    ax1.grid(True, alpha=0.1)
    
    # Plot 2: Elevation
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
    # plt.show() # Uncomment if running locally with display

if __name__ == "__main__":
    main()
