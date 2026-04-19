extends SceneTree

func _init():
	var mesh_library = MeshLibrary.new()
	var source_scene = load("res://assets/tracks/track_library_source.tscn").instantiate()
	
	for child in source_scene.get_children():
		if child is MeshInstance3D:
			var id = mesh_library.get_last_unused_item_id()
			mesh_library.create_item(id)
			mesh_library.set_item_mesh(id, child.mesh)
			mesh_library.set_item_name(id, child.name)
			
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
