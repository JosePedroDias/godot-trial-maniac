import json
import os
import sys
import numpy as np
from scipy.interpolate import interp1d
import fastf1
import logging

# Mapping Godot track names to FastF1 event names and best data years
TRACK_MAPPING = {
    "abu_dhabi": {"name": "Abu Dhabi", "year": 2023},
    "australia": {"name": "Australia", "year": 2024},
    "austria": {"name": "Austria", "year": 2024},
    "azerbaijan": {"name": "Azerbaijan", "year": 2024},
    "bahrain": {"name": "Bahrain", "year": 2024},
    "belgium": {"name": "Belgium", "year": 2023},
    "brazil": {"name": "São Paulo", "year": 2023},
    "canada": {"name": "Canada", "year": 2024},
    "china": {"name": "China", "year": 2024},
    "great_britain": {"name": "Great Britain", "year": 2024},
    "hungary": {"name": "Hungary", "year": 2024},
    "italy_emilia": {"name": "Emilia Romagna", "year": 2024},
    "italy_monza": {"name": "Italy", "year": 2023},
    "japan": {"name": "Japan", "year": 2024},
    "mexico": {"name": "Mexico City", "year": 2023},
    "monaco": {"name": "Monaco", "year": 2024},
    "netherlands": {"name": "Netherlands", "year": 2023},
    "qatar": {"name": "Qatar", "year": 2023},
    "saudi_arabia": {"name": "Saudi Arabia", "year": 2024},
    "singapore": {"name": "Singapore", "year": 2023},
    "spain_barcelona": {"name": "Spain", "year": 2024},
    "usa_cota": {"name": "United States", "year": 2023},
    "usa_las_vegas": {"name": "Las Vegas", "year": 2023},
    "usa_miami": {"name": "Miami", "year": 2024}
}

def inject_elevation(track_id, year_override=None):
    json_path = f"assets/tracks/{track_id}_processed.json"
    if not os.path.exists(json_path):
        print(f"Error: Game track file not found at {json_path}")
        return
        
    event_info = TRACK_MAPPING.get(track_id)
    if not event_info:
        print(f"Error: No mapping for {track_id}")
        return

    event_name = event_info["name"]
    year = year_override if year_override else event_info["year"]

    # 1. Load Game Track
    with open(json_path, 'r') as f:
        data = json.load(f)
    
    points = data.get("points", [])
    if not points: return
    
    # Calculate current cumulative distance for game points (Horizontal)
    game_dists = [0.0]
    curr_dist = 0.0
    for i in range(1, len(points)):
        p1, p2 = points[i-1], points[i]
        d = np.sqrt((p2['x']-p1['x'])**2 + (p2['z']-p1['z'])**2)
        curr_dist += d
        game_dists.append(curr_dist)
    
    game_dist_norm = np.array(game_dists) / curr_dist

    # 2. Fetch F1 Telemetry
    fastf1.Cache.enable_cache('assets/fastf1_cache')
    logging.getLogger('fastf1').setLevel(logging.WARNING)
    print(f"Fetching FastF1 telemetry for {event_name} {year}...")
    
    try:
        session = fastf1.get_session(year, event_name, 'Q')
        session.load(telemetry=True, weather=False, messages=False)
        lap = session.laps.pick_fastest()
        tel = lap.get_telemetry()
        
        f1_dist = tel['Distance'].values
        f1_z = tel['Z'].values / 10.0 # Convert to meters
        f1_dist_norm = f1_dist / f1_dist[-1]
        
        # 3. Interpolate
        f_interp = interp1d(f1_dist_norm, f1_z, kind='cubic', fill_value="extrapolate")
        new_y_vals = f_interp(game_dist_norm)
        
        # 4. Normalize and Offset
        new_y_vals = new_y_vals - np.min(new_y_vals) + 5.0 # Baseline at 5m
        
        # 5. Update and Save
        # Flatten transformation flags
        data["reverseDirection"] = False
        data["startPositionRatio"] = 0.0
        
        for i in range(len(points)):
            points[i]['y'] = float(new_y_vals[i])
            
        data["points"] = points
        
        with open(json_path, 'w') as f:
            json.dump(data, f, indent=2)
            
        print(f"Successfully injected elevation into {json_path}")
        
    except Exception as e:
        print(f"Injection Error: {e}")

if __name__ == "__main__":
    for tid in sys.argv[1:]:
        inject_elevation(tid.lower())
