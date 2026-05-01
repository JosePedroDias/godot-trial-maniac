import json
import numpy as np
from scipy.interpolate import CubicSpline
import os

def process_track(input_path, output_path, target_spacing=5.0):
    with open(input_path, 'r') as f:
        data = json.load(f)
    
    points = np.array([[p['x'], p['y'], p['z']] for p in data['points']])
    
    # Close the loop if it's not closed
    if not np.allclose(points[0], points[-1]):
        points = np.vstack([points, points[0]])
    
    # Smooth elevation (Y) using circular padding for a flawless loop
    if len(points) > 10:
        y = points[:, 1]
        window_size = 11 # Larger window for smoother results
        # Circular padding
        y_padded = np.pad(y, (window_size, window_size), mode='wrap')
        y_smoothed = np.convolve(y_padded, np.ones(window_size)/window_size, mode='same')
        # Extract the original range
        points[:, 1] = y_smoothed[window_size:-window_size]
        
        # Additional step: Ensure the very first and last point (the same point) 
        # has exactly matching Y after smoothing (it should due to wrap, but let's be safe)
        avg_y = (points[0, 1] + points[-1, 1]) / 2.0
        points[0, 1] = avg_y
        points[-1, 1] = avg_y

    # Calculate cumulative distance along the track
    dists = np.sqrt(np.sum(np.diff(points, axis=0)**2, axis=1))
    cumulative_dist = np.concatenate(([0], np.cumsum(dists)))
    total_length = cumulative_dist[-1]
    
    # Create Cubic Spline
    # bc_type='periodic' ensures smooth transition at start/end
    cs = CubicSpline(cumulative_dist, points, bc_type='periodic')
    
    # Resample
    num_samples = int(total_length / target_spacing)
    # Using endpoint=False for consistent loop spacing
    new_dists = np.linspace(0, total_length, num_samples, endpoint=False)
    new_points = cs(new_dists)
    
    # Also calculate tangents (for orientation)
    tangents = cs.derivative()(new_dists)
    # Normalize tangents
    norms = np.linalg.norm(tangents, axis=1)
    # Avoid division by zero
    norms[norms == 0] = 1.0
    tangents /= norms[:, np.newaxis]
    
    # Prepare output data
    processed_points = []
    for i in range(len(new_points)):
        processed_points.append({
            "x": float(new_points[i][0]),
            "y": float(new_points[i][1]),
            "z": float(new_points[i][2]),
            "tx": float(tangents[i][0]),
            "ty": float(tangents[i][1]),
            "tz": float(tangents[i][2])
        })
        
    output_data = {
        "track_name": data.get("track_name", "unknown"),
        "total_length": float(total_length),
        "points": processed_points
    }
    
    with open(output_path, 'w') as f:
        json.dump(output_data, f, indent=2)
    
    print(f"Processed {input_path} -> {output_path}")
    print(f"Original points: {len(points)}, New points: {len(new_points)}, Length: {total_length:.2f}m")

if __name__ == "__main__":
    tracks_dir = "/Users/jdi14/Personal/track-osm-gen/results/tracks"
    output_dir = "assets/tracks"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    import glob
    files = glob.glob(os.path.join(tracks_dir, "*_points.json"))
    for input_file in files:
        track_name = os.path.basename(input_file).replace("_points.json", "")
        output_file = os.path.join(output_dir, f"{track_name}_processed.json")
        process_track(input_file, output_file)
