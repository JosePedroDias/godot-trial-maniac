# Source of Truth for F1 Telemetry Mappings
# Mapping Godot track IDs to FastF1 Event Names and the best available data year.

F1_CONFIG = {
    "abu_dhabi": {"name": "Abu Dhabi", "year": 2025},
    "australia": {"name": "Australia", "year": 2025},
    "austria": {"name": "Austria", "year": 2025},
    "azerbaijan": {"name": "Azerbaijan", "year": 2025},
    "bahrain": {"name": "Bahrain", "year": 2025},
    "belgium": {"name": "Belgium", "year": 2024}, # Prefer 2024 for Spa dry data
    "brazil": {"name": "São Paulo", "year": 2025},
    "canada": {"name": "Canada", "year": 2025},
    "china": {"name": "China", "year": 2025},
    "great_britain": {"name": "British", "year": 2025},
    "hungary": {"name": "Hungary", "year": 2025},
    "italy_emilia": {"name": "Emilia Romagna", "year": 2025},
    "italy_monza": {"name": "Italian", "year": 2025},
    "japan": {"name": "Japan", "year": 2023},
    "mexico": {"name": "Mexico City", "year": 2025},
    "monaco": {"name": "Monaco", "year": 2025},
    "netherlands": {"name": "Netherlands", "year": 2025},
    "qatar": {"name": "Qatar", "year": 2025},
    "saudi_arabia": {"name": "Saudi Arabia", "year": 2025},
    "singapore": {"name": "Singapore", "year": 2025},
    "spain_barcelona": {"name": "Spain", "year": 2023},
    "usa_cota": {"name": "United States", "year": 2025},
    "usa_las_vegas": {"name": "Las Vegas", "year": 2025},
    "usa_miami": {"name": "Miami", "year": 2025}
}

def get_track_info(track_id):
    return F1_CONFIG.get(track_id.lower())
