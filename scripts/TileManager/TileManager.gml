/// @function TileManager
function TileManager(_tile_size) constructor {
	tile_size = _tile_size;
	h_tile_size = tile_size * 0.5; // half size
	
	enum eTileType { // all the tiles in tile sprite, top -> bottom and left -> right
		// b = bottom, t = top, m = middle, l = left, r = right, hor = horizontal, vert = vertical
		none,
		wedge_tl,
		wedge_tr,
		wedge_flat_hor_tl,
		wedge_flat_hor_tr,
		wedge_flat_vert_tl,
		wedge_flat_vert_tr,
		block_vert_m,
		cube,
		wedge_bl,
		wedge_br,
		wedge_flat_hor_bl,
		wedge_flat_hor_br,
		wedge_flat_vert_bl,
		wedge_flat_vert_br,
		block_hor_m,
		wedge_skinny_hor_tl,
		wedge_skinny_hor_tr,
		wedge_skinny_vert_tl,
		wedge_skinny_vert_tr,
		wedge_small_tl,
		wedge_small_tr,
		block_hor_b,
		block_hor_t,
		wedge_skinny_hor_bl,
		wedge_skinny_hor_br,
		wedge_skinny_vert_bl,
		wedge_skinny_vert_br,
		wedge_small_bl,
		wedge_small_br,
		block_vert_r,
		block_vert_l
	}
	
	/// @function tile_layer_to_colmesh
	/// @param colmesh
	/// @param {string} tile_layer_name
	static tile_layer_to_colmesh = function(_colmesh, _tile_layer_name){
		var lay_id = layer_get_id(_tile_layer_name);
		var _tiles  = layer_tilemap_get_id(lay_id);
		var _z = floor(layer_get_depth(lay_id) div TILE_SIZE);
		var _width  = room_width div TILE_SIZE;
		var _height = room_height div TILE_SIZE;
		var _tileX = 0;
		var _tileY = -TILE_SIZE;

		for (var _x = 0; _x < _width; _x++) {
			for (var _y = 0; _y < _height; _y++) {
				_tileY += TILE_SIZE;
				var _index = tilemap_get(_tiles, _x, _y) & tile_index_mask;
				add_colmesh_at_grid(_colmesh, _index, _x, _y, _z);
			}
			_tileX += TILE_SIZE;
			_tileY = -TILE_SIZE;
		}
		
		//layer_destroy(lay_id);
	}
	
	/// @function add_colmesh_at_grid
	/// @param colmesh
	/// @param tile_type - enum describing the tile type
	/// @param cell_x
	/// @param cell_y
	/// @param cell_z
	/// @description Add a given mesh or shape to the level colmesh
	static add_colmesh_at_grid = function(_colmesh, _tile_type, cx, cy, cz) {
		var tx = cx * tile_size + h_tile_size;
		var ty = cy * tile_size + h_tile_size;
		var tz = cz * tile_size + h_tile_size;
		var xscale = tile_size;
		var yscale = tile_size;
		var zscale = tile_size;
		
		// Get orientation
		var orientation_array = array_create(3, 0);
		switch(_tile_type){
			// Top left
			case eTileType.wedge_tl:
			case eTileType.wedge_flat_hor_tl:
			case eTileType.wedge_flat_vert_tl:
			case eTileType.wedge_skinny_hor_tl:
			case eTileType.wedge_skinny_vert_tl:
			case eTileType.wedge_small_tl:
				orientation_array = [180, 90, -90];
				break
			// Top right
			case eTileType.wedge_tr:
			case eTileType.wedge_flat_hor_tr:
			case eTileType.wedge_flat_vert_tr:
			case eTileType.wedge_skinny_hor_tr:
			case eTileType.wedge_skinny_vert_tr:
			case eTileType.wedge_small_tr:
				orientation_array = [180, 90, 180];
				break;
			// Bottom left
			case eTileType.wedge_bl:
			case eTileType.wedge_flat_hor_bl:
			case eTileType.wedge_flat_vert_bl:
			case eTileType.wedge_skinny_hor_bl:
			case eTileType.wedge_skinny_vert_bl:
			case eTileType.wedge_small_bl:
				orientation_array = [180, -90, -90];
				break;
			// Bottom right
			case eTileType.wedge_br:
			case eTileType.wedge_flat_hor_br:
			case eTileType.wedge_flat_vert_br:
			case eTileType.wedge_skinny_hor_br:
			case eTileType.wedge_skinny_vert_br:
			case eTileType.wedge_small_br:
				orientation_array = [180, 90, 90];
				break;
		}
		
		// Find scale
		switch(_tile_type){
			case eTileType.wedge_skinny_hor_tl:
			case eTileType.wedge_skinny_hor_tr:
			case eTileType.wedge_skinny_hor_bl:
			case eTileType.wedge_skinny_hor_br:
				yscale *= 0.5;
				break;
			case eTileType.wedge_skinny_vert_tl:
			case eTileType.wedge_skinny_vert_tr:
			case eTileType.wedge_skinny_vert_bl:
			case eTileType.wedge_skinny_vert_br:
				xscale *= 0.5;
				break;
			case eTileType.wedge_small_tl:
			case eTileType.wedge_small_tr:
			case eTileType.wedge_small_bl:
			case eTileType.wedge_small_br:
				xscale *= 0.5;
				yscale *= 0.5;
				break;
			case eTileType.block_vert_l:
			case eTileType.block_vert_r:
			case eTileType.block_vert_m:
				xscale *= 0.25;
				yscale *= 0.5;
				zscale *= 0.5;
				break;
			case eTileType.block_hor_b:
			case eTileType.block_hor_m:
			case eTileType.block_hor_t:
				xscale *= 0.5;
				yscale *= 0.25;
				zscale *= 0.5;
				break;
		}
		
		// Translate y
		switch(_tile_type){
			case eTileType.wedge_skinny_hor_bl:
			case eTileType.wedge_skinny_hor_br:
			case eTileType.wedge_small_bl:
			case eTileType.wedge_small_br:
				ty -= h_tile_size * 0.5;
				break;
			case eTileType.wedge_skinny_hor_tl:
			case eTileType.wedge_skinny_hor_tr:
			case eTileType.wedge_small_tl:
			case eTileType.wedge_small_tr:
				ty += h_tile_size * 0.5;
				break;
			case eTileType.block_hor_t:
				ty -= h_tile_size * 0.5;
				break;
			case eTileType.block_hor_b:
				ty += h_tile_size * 0.5;
				break;
		}
		
		// Translate x
		switch(_tile_type){
			case eTileType.wedge_small_bl:
			case eTileType.wedge_small_tl:
			case eTileType.wedge_skinny_vert_tl:
			case eTileType.wedge_skinny_vert_bl:
				tx += h_tile_size * 0.5;
				break;
			case eTileType.wedge_small_br:
			case eTileType.wedge_small_tr:
			case eTileType.wedge_skinny_vert_tr:
			case eTileType.wedge_skinny_vert_br:
				tx -= h_tile_size * 0.5;
				break;
			case eTileType.block_vert_l:
				tx -= h_tile_size;
				break;
			case eTileType.block_vert_r:
				tx += h_tile_size;
				break;
		}
		
		// Get mesh/shape
		var mesh_or_shape = undefined;
		switch(_tile_type){
			case eTileType.wedge_tl:
			case eTileType.wedge_tr:
			case eTileType.wedge_bl:
			case eTileType.wedge_br:
			case eTileType.wedge_skinny_hor_tl:
			case eTileType.wedge_skinny_hor_tr:
			case eTileType.wedge_skinny_hor_bl:
			case eTileType.wedge_skinny_hor_br:
			case eTileType.wedge_skinny_vert_tl:
			case eTileType.wedge_skinny_vert_tr:
			case eTileType.wedge_skinny_vert_bl:
			case eTileType.wedge_skinny_vert_br:
			case eTileType.wedge_small_tl:
			case eTileType.wedge_small_tr:
			case eTileType.wedge_small_bl:
			case eTileType.wedge_small_br:
				mesh_or_shape = "wedge.obj";
				break;
			case eTileType.wedge_flat_hor_tl:
			case eTileType.wedge_flat_hor_tr:
			case eTileType.wedge_flat_hor_bl:
			case eTileType.wedge_flat_hor_br:
			case eTileType.wedge_flat_vert_tl:
			case eTileType.wedge_flat_vert_tr:
			case eTileType.wedge_flat_vert_bl:
			case eTileType.wedge_flat_vert_br:
				mesh_or_shape = "wedge-flat.obj";
				break;
			case eTileType.cube:
				mesh_or_shape = new colmesh_cube(tx, ty, tz, xscale, yscale, zscale);
				break;
			case eTileType.block_vert_l:
			case eTileType.block_vert_m:
			case eTileType.block_vert_r:
			case eTileType.block_hor_t:
			case eTileType.block_hor_m:
			case eTileType.block_hor_b:
				mesh_or_shape = new colmesh_block(matrix_build(tx, ty, tz, orientation_array[0], orientation_array[1], orientation_array[2], xscale, yscale, zscale));
				break;
		}
		
		// Add it to level's colmesh
		if is_string(mesh_or_shape) { // mesh
			_colmesh.addMesh(mesh_or_shape, matrix_build(tx, ty, tz, orientation_array[0], orientation_array[1], orientation_array[2], xscale, yscale, zscale));
		} else if is_struct(mesh_or_shape) { // shape
			_colmesh.addShape(mesh_or_shape);
		}
	}
}