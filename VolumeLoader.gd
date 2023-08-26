extends Node3D

const rank: float = 64
var global_minimum_height: float
var global_maximum_height: float
var blocks: Array[Color]

func _process(delta):
	if Input.is_key_pressed(KEY_ENTER):
		get_tree().reload_current_scene()
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()

func write_color(x, y, h, pixel):
	blocks[x + y * rank + (h - global_minimum_height) * rank * rank] = pixel

func read_color(x, y, h) -> Color:
	return blocks[x + y * rank + (h - global_minimum_height) * rank * rank]

# Checks for air blocks
func is_free(x, y, h):
	if x < 0 or y < 0 or h < global_minimum_height:
		return true

	if x >= rank or y >= rank or h >= global_maximum_height:
		return true

	var bl = read_color(x, y, h)
	if bl.r == 0 and bl.g == 0 and bl.b == 0:
		return true

	return false

func read_or_default(path: String, fallback: Color):
	if FileAccess.file_exists(path):
		return Image.load_from_file(path)
	else:
		var im = Image.create(rank, rank, false, Image.FORMAT_RGBA8)
		for x in range(rank):
			for y in range(rank):
				im.set_pixel(x, y, fallback)
		return im

func read_text_or_default(path: String, fallback: String):
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	else:
		return fallback

func _ready():
	var dirs = ProjectSettings.globalize_path('res://')
	print(dirs)
	var conf = read_text_or_default(dirs + '/world/conf.json', '{ "global_minimum_height": -256, "global_maximum_height": 256 }')
	var config = JSON.parse_string(conf)
	
	var g_conf = read_text_or_default(dirs + '/world/godot_conf.json', '{ "chunk_x": 0, "chunk_y": 0, "radius": 1 }')
	var g_config = JSON.parse_string(g_conf)
	
	global_minimum_height = config.global_minimum_height
	global_maximum_height = config.global_maximum_height
	init_blocks() # Write the blocks array with air

	var chunks = DirAccess.get_directories_at(dirs + '/world/')
	var radius = g_config.radius
	var sx = g_config.chunk_x
	var sy = g_config.chunk_y

	if len(chunks) > 0:
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var chunk = str(x + sx) + ' ' + str(y + sy)
				if DirAccess.dir_exists_absolute(dirs + '/world/' + chunk + '/'):
					load_chunk(dirs, chunk)

func load_chunk(dirs, chunk: String):
	clear_blocks()
	print('chunk: ' + chunk)
	var vals = chunk.split(' ')
	var chunk_x = int(vals[0])
	var chunk_y = -int(vals[1])
	var chunk_conf = read_text_or_default(dirs + 'world/' + chunk + '/base/conf.json', '{ "chunk_height_offset": -5 }')
	var chunk_config = JSON.parse_string(chunk_conf)
	var water_base = read_or_default(dirs + 'world/' + chunk + '/base/water_base.png', Color(0.1, 0.1, 0.65))
	var water_level = read_or_default(dirs + 'world/' + chunk + '/base/water_level.png', Color(0, 0, 0))
	var base = read_or_default(dirs + 'world/' + chunk + '/base/base.png', Color(0.36, 0.2, 0.01))
	var heightmap = read_or_default(dirs + 'world/' + chunk + '/base/heightmap.png', Color(0, 0, 0))
	var objects = read_or_default(dirs + 'world/' + chunk + '/base/objects.png', Color(1, 1, 1))
	var top_filler = read_or_default(dirs + 'world/' + chunk + '/base/top_filler.png', Color(0.36, 0.2, 0.01))
	new_base_layer(chunk_config.chunk_height_offset, base, top_filler, objects, heightmap, water_base, water_level)

	# Load veins
	if DirAccess.dir_exists_absolute(dirs + 'world/' + chunk + '/veins/'):
		for vein in DirAccess.get_directories_at(dirs + 'world/' + chunk + '/veins/'):
			var vein_path = dirs + 'world/' + chunk + '/veins/' + vein
			var vein_conf = read_text_or_default(vein_path + '/conf.json', '{ "vein_layer_height": -10 }')
			var vein_config = JSON.parse_string(vein_conf)
			var vein_base = read_or_default(vein_path + '/vein_base.png', Color(1, 1, 1))
			var vein_ceiling = read_or_default(vein_path + '/vein_ceiling.png', Color(47 / 256.0, 47 / 256.0, 47 / 256.0))
			var vein_layer_floor = read_or_default(vein_path + '/vein_floor_height.png', Color(0, 0, 0))
			new_vein_layer(vein_config.vein_layer_height, vein_base, vein_ceiling, vein_layer_floor)

	# Load caverns
	if DirAccess.dir_exists_absolute(dirs + 'world/' + chunk + '/caverns/'):
		for cavern in DirAccess.get_directories_at(dirs + 'world/' + chunk + '/caverns/'):
			var cav_path = dirs + 'world/' + chunk + '/caverns/' + cavern
			var cavern_conf = read_text_or_default(cav_path + '/conf.json', '{ "cavern_layer_height": -10 }')
			var cavern_config = JSON.parse_string(cavern_conf)
			var cavern_water_base = read_or_default(cav_path + '/cavern_water_base.png', Color(0.1, 0.1, 0.65))
			var cavern_water_level = read_or_default(cav_path + '/cavern_water_level.png', Color(0, 0, 0))
			var cavern_layer_objects = read_or_default(cav_path + '/cavern_objects.png', Color(1, 1, 1))
			var cavern_layer_ceiling = read_or_default(cav_path + '/cavern_ceiling.png', Color(47 / 256.0, 47 / 256.0, 47 / 256.0))
			var cavern_layer_floor = read_or_default(cav_path + '/cavern_floor_height.png', Color(0, 0, 0))
			new_cavern_layer(cavern_config.cavern_layer_height, cavern_layer_objects, cavern_layer_ceiling, cavern_layer_floor, cavern_water_base, cavern_water_level)

	# Load constructions
	if DirAccess.dir_exists_absolute(dirs + 'world/' + chunk + '/structures/'):
		for cons in DirAccess.get_directories_at(dirs + 'world/' + chunk + '/structures/'):
			var con_path = dirs + 'world/' + chunk + '/structures/' + cons
			var con_conf = read_text_or_default(con_path + '/conf.json', '{ "structure_base_height": 0 }')
			var con_config = JSON.parse_string(con_conf)
			for layer in DirAccess.get_files_at(con_path + '/'):
				if layer.ends_with('.png'):
					var h = int(layer.split('.')[0]) + con_config.structure_base_height
					var structure_texture = read_or_default(con_path + '/' + layer, Color(0.1, 0.1, 0.65))
					for x in range(rank):
						for y in range(rank):
							var st = structure_texture.get_pixel(x, y)
							if st.r == 1 and st.g == 1 and st.b == 1:
								continue # Skip blocks that weren't modified!
							write_color(x, y, h, st)
	create_gfx(chunk_x, chunk_y) # Finalize by creating graphics

func init_blocks():
	# Init blocks array
	for x in range(rank):
		for y in range(rank):
			for h in range(global_minimum_height, global_maximum_height):
				blocks.push_back(Color(0, 0, 0))

# Wipes all blocks with 0, 0, 0
func clear_blocks():
	for x in range(rank):
		for y in range(rank):
			for h in range(global_minimum_height, global_maximum_height):
				write_color(x, y, h, Color(0, 0, 0))

func new_base_layer(chunk_height_offset: float, base_texture: Image, top_filler_texture: Image, objects_texture: Image, heightmap_texture: Image, water_base_texture: Image, water_level_texture: Image):
	# Base texture
	for x in range(rank):
		for y in range(rank):
			var base_pixel = base_texture.get_pixel(x, y)
			var top_filler_pixel = top_filler_texture.get_pixel(x, y)
			var final_height = chunk_height_offset + floor(heightmap_texture.get_pixel(x, y).r8 / 15)
			var water = water_base_texture.get_pixel(x, y)
			var water_level = floor(water_level_texture.get_pixel(x, y).r8 / 15)
			new_block(base_pixel, x, y, final_height)
			for h in range(global_minimum_height, final_height):
				if(abs(final_height - h) <= 3):
					new_block(top_filler_pixel, x, y, h)
				else:
					new_block(Color(0.2, 0.2, 0.2), x, y, h)
			for h in range(chunk_height_offset, chunk_height_offset + water_level):
				if is_free(x, y, h) and water_level > 0 and water_level >= h:
					new_block(water, x, y, h)

	# Objects texture
	for x in range(rank):
		for y in range(rank):
			var pixel = objects_texture.get_pixel(x, y)
			if pixel.r != 1 or pixel.g != 1 or pixel.b != 1:
				var probability = 0.15
				if randf() < probability:
					new_block(pixel, x, y, chunk_height_offset + floor(heightmap_texture.get_pixel(x, y).r8 / 15) + 1)

func create_gfx(chunk_x, chunk_y):
	# After everything is written we can finally do the final step and display the blocks!
	var sf = SurfaceTool.new()
	var count = 0
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(rank):
		for y in range(rank):
			for h in range(global_minimum_height, global_maximum_height):
				if not is_free(x, y, h):
					var c = read_color(x, y, h)
					if is_free(x + 1, y, h):
						sf.set_color(c)
						count += 4
						quad(sf, c,
							Vector3(x + 1, h, y),
							Vector3(x + 1, h + 1, y),
							Vector3(x + 1, h, y + 1),
							Vector3(x + 1, h + 1, y + 1),
							count
						)
					if is_free(x - 1, y, h):
						count += 4
						quad(sf, c,
							Vector3(x, h, y),
							Vector3(x, h, y + 1),
							Vector3(x, h + 1, y),
							Vector3(x, h + 1, y + 1),
							count
						)
					if is_free(x, y + 1, h):
						count += 4
						quad(sf, c,
							Vector3(x, h, y + 1),
							Vector3(x + 1, h, y + 1),
							Vector3(x, h + 1, y + 1),
							Vector3(x + 1, h + 1, y + 1),
							count
						)
					if is_free(x, y - 1, h):
						count += 4
						quad(sf, c,
							Vector3(x, h, y),
							Vector3(x, h + 1, y),
							Vector3(x + 1, h, y),
							Vector3(x + 1, h + 1, y),
							count
						)
					if is_free(x, y, h + 1):
						count += 4
						quad(sf, c,
							Vector3(x, h + 1, y),
							Vector3(x, h + 1, y + 1),
							Vector3(x + 1, h + 1, y),
							Vector3(x + 1, h + 1, y + 1),
							count
						)
					if is_free(x, y, h - 1):
						count += 4
						quad(sf, c,
							Vector3(x, h, y),
							Vector3(x + 1, h, y),
							Vector3(x, h, y + 1),
							Vector3(x + 1, h, y + 1),
							count
						)
					#if is_free(x + 1, y, h) or is_free(x - 1, y, h) or is_free(x, y + 1, h) or is_free(x, y - 1, h) or is_free(x, y, h + 1) or is_free(x, y, h - 1):
					#	instance_block(read_color(x, y, h), x + chunk_x * rank, y + chunk_y * rank, h)
	var am = ArrayMesh.new()
	sf.commit(am)
	var inst = MeshInstance3D.new()
	inst.mesh = am
	add_child(inst)
	inst.position = Vector3(chunk_x * rank, 0, chunk_y * rank)
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	inst.material_override = mat
	inst.cast_shadow = true
	
func quad(sf: SurfaceTool, color, v1, v2, v3, v4, count):
	var norm = (v2 - v1).cross(v3 - v1)
	sf.set_normal(norm)
	sf.set_color(color)
	sf.add_vertex(v1)
	sf.set_normal(norm)
	sf.set_color(color)
	sf.add_vertex(v2)
	sf.set_normal(norm)
	sf.set_color(color)
	sf.add_vertex(v3)
	sf.set_normal(norm)
	sf.set_color(color)
	sf.add_vertex(v4)
	sf.add_index(count - 4)
	sf.add_index(count - 2)
	sf.add_index(count - 3)
	sf.add_index(count - 3)
	sf.add_index(count - 2)
	sf.add_index(count - 1)
####################
### CAVERN LAYER ###
####################
func new_cavern_layer(cavern_layer_height: float, cavern_layer_objects: Image, cavern_layer_ceiling: Image, cavern_layer_floor: Image, cavern_water_base: Image, cavern_water_level: Image):
	for x in range(rank):
		for y in range(rank):
			var rr = cavern_layer_floor.get_pixel(x, y)
			if rr.r > 0:
				var height = floor(rr.r8 / 15) + cavern_layer_height
				var ceiling = floor(cavern_layer_ceiling.get_pixel(x, y).r8 / 15)
				var water = cavern_water_base.get_pixel(x, y)
				var water_level = floor(cavern_water_level.get_pixel(x, y).r8 / 15)
				for h in range(height, height + ceiling):
					if water_level > 0 and water_level >= h - cavern_layer_height:
						new_block(water, x, y, h)
					else:
						new_block(Color(0, 0, 0), x, y, h)
				var object_pixel = cavern_layer_objects.get_pixel(x, y)
				if ceiling > 0 and (object_pixel.r != 1 or object_pixel.g != 1 or object_pixel.b != 1):
					var probability = 0.15
					if randf() < probability:
						new_block(object_pixel, x, y, height)

####################
### VEIN LAYER ###
####################
func new_vein_layer(vein_layer_height: float, vein_layer_base: Image, vein_layer_ceiling: Image, vein_layer_floor: Image):
	for x in range(rank):
		for y in range(rank):
			var base = vein_layer_base.get_pixel(x, y)
			if base.r != 1 or base.g != 1 or base.b != 1:
				var rr = vein_layer_floor.get_pixel(x, y)
				var height = floor(rr.r8 / 15) + vein_layer_height
				var ceiling = floor(vein_layer_ceiling.get_pixel(x, y).r8 / 15)
				for h in range(height, height + ceiling):
					new_block(base, x, y, h)

func new_block(pixel: Color, x: float, y: float, h: float):
	write_color(x, y, h, pixel)
