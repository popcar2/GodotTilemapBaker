@tool
extends StaticBody2D

## This script pre-bakes collisions for square tilemaps, therefore optimizing code 
## and getting rid of weird physics bugs!
##
## How it works TLDR:
## This script finds the position of every tile on the layer you've selected from the top left
## It then goes to the right until it reaches an edge, then created a rectange CollisionShape2D
##    and places it in the correct position and size. It keeps doing this until it reaches the end.
## For further optimizations, it combines different rows of CollisionShapes if 
##    they are the same size.

## Your TileMap Node
@export var tilemap_nodepath: NodePath

## The tilemap layer to bake collisions on.
## You can bake for multiple layers by disabling delete_children_on_run and running multiple times.
@export var target_tiles_layer: int = 0

## Whether or not you want the children of this node to be deleted on run or not.
## Be careful with this!
@export var delete_children_on_run: bool = true

## A fake button to run the code. Bakes collisions and adds colliders as children to this node!
@export var run_script: bool = false : set = run_code

func run_code(_fake_bool = null):
	var tile_map: TileMap = get_node(tilemap_nodepath)
	if tile_map == null:
		print("Hey, you forgot to set your Tilemap Nodepath.")
		return
	
	if delete_children_on_run:
		delete_children()
	
	var tile_size = tile_map.tile_set.tile_size
	var tilemap_locations = tile_map.get_used_cells(target_tiles_layer)
	
	if tilemap_locations.size() == 0:
		print("Hey, this tilemap is empty (did you choose the correct layer?)")
		return
	
	# I use .pop_back() to go through the array, so I sort them from bottom right to top left.
	tilemap_locations.sort_custom(sortVectorsByY)
	
	var last_loc: Vector2i = Vector2i(-99999, -99999)
	var size: Vector2i = Vector2i(1, 1)
	var xMarginStart = 0
	
	print("Starting first pass (Creating initial colliders)...")
	
	var first_colliders_arr = []
	## First pass: add horizontal rect colliders starting from the top left
	while true:
		var temp_loc = tilemap_locations.pop_back()
		
		if temp_loc == null:
			# Add the last collider and break out of loop
			var newXPos = (xMarginStart + abs(last_loc.x - xMarginStart) / 2.0 + 0.5) * tile_size.x
			@warning_ignore("integer_division")
			var newYPos = last_loc.y * tile_size.y - (-tile_size.y / 2)
			first_colliders_arr.append(createCollisionShape(Vector2i(newXPos, newYPos), size, tile_size))
			print("Finished calculating first pass!")
			break
		
		if last_loc == Vector2i(-99999, -99999):
			last_loc = temp_loc
			xMarginStart = temp_loc.x
			continue
		
		if last_loc.y == temp_loc.y and abs(last_loc.x - temp_loc.x) == 1:
			size += Vector2i(1,0)
		else:
			var newXPos = (xMarginStart + abs(last_loc.x - xMarginStart) / 2.0 + 0.5) * tile_size.x
			@warning_ignore("integer_division")
			var newYPos = last_loc.y * tile_size.y - (-tile_size.y / 2)
			first_colliders_arr.append(createCollisionShape(Vector2i(newXPos, newYPos), size, tile_size))
			size = Vector2i(1, 1)
			xMarginStart = temp_loc.x
			#print("New row placed at (%s, %s)" % [newXPos, newYPos])
		
		last_loc = temp_loc
	
	## Sort collider nodes for use in second pass
	first_colliders_arr.sort_custom(sortNodesByX)
	
	var last_collider_pos: Vector2 = Vector2(-99999, -99999)
	var last_collider
	var colliders_to_merge = 1 # Used to count how many colliders will merge
	
	var second_colliders_arr = []
	
	print("Starting second pass (Merging colliders)...")
	
	## Second pass: Merge colliders that are on top of eachother and are the same size
	while true:
		var temp_collider = first_colliders_arr.pop_back()
		
		if temp_collider == null:
			# Add final merged collider and break
			last_collider.shape.size.y = tile_size.y * colliders_to_merge
			last_collider.position.y -= (colliders_to_merge / 2.0 - 0.5) * tile_size.y
			second_colliders_arr.append(last_collider)
			
			print("Finished baking tilemap collisions!")
			break
		
		if last_collider_pos == Vector2(-99999, -99999):
			last_collider_pos = temp_collider.position
			last_collider = temp_collider
			continue
		
		var tile_y_distance = abs(temp_collider.position.y - last_collider_pos.y) / tile_size.y
		if last_collider_pos.x == temp_collider.position.x and tile_y_distance == 1:
			#print("Adding 1 to the merge")
			colliders_to_merge += 1
			last_collider_pos = temp_collider.position
		else:
			#print("Merging %s colliders" % colliders_to_merge)
			last_collider_pos = temp_collider.position
			last_collider.shape.size.y = tile_size.y * colliders_to_merge
			last_collider.position.y -= (colliders_to_merge / 2.0 - 0.5) * tile_size.y
			second_colliders_arr.append(last_collider)
			
			colliders_to_merge = 1
			
		last_collider = temp_collider
	
	## Adds all colliders as children to this node
	for collider in second_colliders_arr:
		add_child(collider, true)
		collider.owner = get_tree().edited_scene_root
	
	## Move this node's position to cover the tilemap
	position = tile_map.position

func createCollisionShape(pos, size, tile_size) -> CollisionShape2D:
	var collisionShape = CollisionShape2D.new()
	var rectangleShape = RectangleShape2D.new()
	
	rectangleShape.size = size * tile_size
	collisionShape.set_shape(rectangleShape)
	collisionShape.position = pos
	
	return collisionShape

func delete_children():
	for child in get_children():
		child.queue_free()

## Sorts array of vectors in ascending order with respect to Y
func sortVectorsByY(a, b):
	if a.y > b.y:
		return true
	if a.y == b.y:
		if a.x > b.x:
			return true
	return false

## Sorts array of nodes in ascending order with respects to position
func sortNodesByX(a, b):
	if a.position.x > b.position.x:
		return true
	if a.position.x == b.position.x:
		if a.position.y > b.position.y:
			return true
	return false
