import json
import os
import glob
import math

def analyze_track(file_path):
    with open(file_path) as f:
        data = json.load(f)
        points = data.get("points", [])
        if not points:
            return None
            
        y_vals = [p["y"] for p in points]
        min_y = min(y_vals)
        max_y = max(y_vals)
        delta = max_y - min_y
        
        max_slope = 0
        total_dist = 0
        for i in range(1, len(points)):
            p1, p2 = points[i-1], points[i]
            dist = math.sqrt((p2["x"]-p1["x"])**2 + (p2["z"]-p1["z"])**2 + (p2["y"]-p1["y"])**2)
            total_dist += dist
            
            horiz_dist = math.sqrt((p2["x"]-p1["x"])**2 + (p2["z"]-p1["z"])**2)
            if horiz_dist > 0.1: # Avoid division by near-zero
                slope = abs(p2["y"]-p1["y"]) / horiz_dist
                max_slope = max(max_slope, slope)
                
        return {
            "name": os.path.basename(file_path).replace("_processed.json", ""),
            "min_y": min_y,
            "max_y": max_y,
            "delta": delta,
            "max_slope_pct": max_slope * 100,
            "length": total_dist
        }

def main():
    tracks = glob.glob("assets/tracks/*_processed.json")
    results = []
    for t in tracks:
        res = analyze_track(t)
        if res:
            results.append(res)
            
    # Sort by delta descending
    results.sort(key=lambda x: x["delta"], reverse=True)
    
    print(f"{'Track':<20} | {'Delta (m)':<10} | {'Max Slope %':<12} | {'Length (m)':<10}")
    print("-" * 60)
    for r in results:
        print(f"{r['name']:<20} | {r['delta']:<10.2f} | {r['max_slope_pct']:<12.2f} | {r['length']:<10.0f}")

if __name__ == "__main__":
    main()
