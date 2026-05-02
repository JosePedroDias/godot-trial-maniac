import json
import os
import sys
import numpy as np
from scipy.interpolate import interp1d
import fastf1
import logging

# Reuse mapping from compare script
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

def inject_elevation(track_id, year=2023):
    json_path = f"assets/tracks/{track_id}_processed.json"
    if not os.path.exists(json_path):
        print(f"Error: Game track file not found at {json_path}")
        return
        
    event_name = TRACK_MAPPING.get(track_id)
    if not event_name:
        print(f"Error: No mapping for {track_id}")
        return

    # 1. Load Game Track
    with open(json_path, 'r') as f:
        data = json.load(f)
    
    points = data.get("points", [])
    if not points: return
    
    # Calculate current cumulative distance for game points
    game_dists = [0.0]
    curr_dist = 0.0
    for i in range(1, len(points)):
        p1, p2 = points[i-1], points[i]
        d = np.sqrt((p2['x']-p1['x'])**2 + (p2['z']-p1['z'])**2) # Horizontal dist
        curr_dist += d
        game_dists.append(curr_dist)
    
    game_dist_norm = np.array(game_dists) / curr_dist

    # 2. Fetch F1 Telemetry
    fastf1.Cache.enable_cache('assets/fastf1_cache')
    logging.getLogger('fastf1').setLevel(logging.WARNING)
    print(f"Fetching FastF1 telemetry for {event_name}...")
    
    try:
        session = fastf1.get_session(year, event_name, 'Q')
        session.load(telemetry=True, weather=False, messages=False)
        lap = session.laps.pick_fastest()
        tel = lap.get_telemetry()
        
        f1_dist = tel['Distance'].values
        f1_z = tel['Z'].values / 10.0 # Convert to meters
        f1_dist_norm = f1_dist / f1_dist[-1]
        
        # 3. Interpolate
        # Use periodic interpolation if possible, or just linear
        f_interp = interp1d(f1_dist_norm, f1_z, kind='cubic', fill_value="extrapolate")
        new_y_vals = f_interp(game_dist_norm)
        
        # 4. Normalize and Offset
        # We want to keep the relative heights but potentially match the original start line height
        # Or just start at 5.0m baseline
        orig_min_y = min([p['y'] for p in points])
        new_y_vals = new_y_vals - np.min(new_y_vals) + 5.0 # Start at 5m
        
        # 5. Update and Save
        # IMPORTANT: We flatten transformation flags because the current point array order 
        # is the one that was aligned with the FastF1 distance 0-1.
        data["reverseDirection"] = False
        data["startPositionRatio"] = 0.0
        
        # Note: points in points_data are already neg-flipped (x = -x) from the loader.
        # But here we are reading the _processed.json which is on-disk.
        # The _processed.json has the Godot-friendly coordinates.
        # To make it "Offline Regeneratable", we MUST flip back to the system scripts/track_from_json.gd expects.
        # Actually, let's keep it simple: overwrite the Y and reset flags.
        
        for i in range(len(points)):
            # Update only the Y value based on F1 telemetry
            points[i]['y'] = float(new_y_vals[i])
            # Keep X and TX as they are in the JSON file
            # The Godot loader will handle the neg-flip during scene generation
            
        data["points"] = points
        
        with open(json_path, 'w') as f:
            json.dump(data, f, indent=2)
            
        print(f"Successfully injected elevation into {json_path}")
        
    except Exception as e:
        print(f"Injection Error: {e}")

if __name__ == "__main__":
    for tid in sys.argv[1:]:
        inject_elevation(tid.lower())
