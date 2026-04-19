extends SceneTree

func _init():
	var mesh_library = MeshLibrary.new()
	var source_scene = load("res://assets/tracks/track_library_source.tscn").instantiate()
	
	for child in source_scene.get_children():
		if child is MeshInstance3D:
			var id = mesh_library.get_last_unused_item_id()
			mesh_library.create_item(id)
			mesh_library.set_item_name(id, child.name)
			
			# Create a single mesh for the item by merging children if necessary
			# But GridMap items usually expect a single mesh. 
			# For simplicity in this script, we'll just use the main mesh and its immediate children if they are meshes.
			# Actually, MeshLibrary can store a scene if we use create_item from a scene, 
			# but let's stick to meshes for now and just use a placeholder if it's complex, 
			# OR we can use the main road mesh and just know the gates are visual.
			
			mesh_library.set_item_mesh(id, child.mesh)
			
			# Handle collision
			for subchild in child.get_children():
				if subchild is StaticBody3D:
					var shape_data = []
					for shape_node in subchild.get_children():
						if shape_node is CollisionShape3D:
							shape_data.append(shape_node.shape)
							shape_data.append(shape_node.transform)
					mesh_library.set_item_shapes(id, shape_data)
	
	var err = ResourceSaver.save(mesh_library, "res://assets/tracks/track_library.tres")
	if err == OK:
		print("Successfully exported MeshLibrary to res://assets/tracks/track_library.tres")
	else:
		printerr("Failed to export MeshLibrary: ", err)
	
	quit()
