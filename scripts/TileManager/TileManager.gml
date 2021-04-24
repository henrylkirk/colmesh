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
		block_hor_bm,
		block_hor_tm,
		wedge_skinny_hor_bl,
		wedge_skinny_hor_br,
		wedge_skinny_vert_bl,
		wedge_skinny_vert_br,
		wedge_small_bl,
		wedge_small_br,
		block_vert_r,
		block_vert_l
	}
	
	/// @function add_colmesh_at_grid
	/// @param colmesh
	/// @param tile_type - enum describing the tile type
	/// @param cell_x
	/// @param cell_y
	/// @param cell_z
	/// @description Add a given mesh or shape to the level colmesh
	static add_colmesh_at_grid = function(_colmesh, _tile_type, cx, cy, cz) {
		var tx = cx*tile_size + h_tile_size;
		var ty = cy*tile_size + h_tile_size;
		var tz = cz * tile_size + h_tile_size;
		
		var mesh_or_shape = undefined;
		
		// Get mesh/shape
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
		}
		
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
		var xscale = tile_size;
		var yscale = tile_size;
		var zscale = tile_size;
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
		}
		
		// Add it to level's colmesh
		if is_string(mesh_or_shape) { // mesh
			_colmesh.addMesh(mesh_or_shape, matrix_build(tx, ty, tz, orientation_array[0], orientation_array[1], orientation_array[2], xscale, yscale, zscale));
		} else if is_struct(mesh_or_shape) { // shape
			_colmesh.addShape(mesh_or_shape);
		}
		
		//switch(_tile_type){
		//	case eTileType.wedge_tl:
		//		_colmesh.addMesh("wedge.obj", matrix_build(tx, ty, tz, 180, 90, -90, tile_size, tile_size, tile_size));
		//		break;
		//	case eTileType.wedge_tr:
		//		_colmesh.addMesh("wedge.obj", matrix_build(tx, ty, tz, 180, 90, 180, tile_size, tile_size, tile_size));
		//		break;
		//	case eTileType.wedge_bl:
		//		_colmesh.addMesh("wedge.obj", matrix_build(tx, ty, tz, 180, -90, -90, tile_size, tile_size, tile_size));
		//		break;
		//	case eTileType.wedge_br:
		//		_colmesh.addMesh("wedge.obj", matrix_build(tx, ty, tz, 180, 90, 90, tile_size, tile_size, tile_size));
		//		break;
		//	case eTileType.cube:
		//		_colmesh.addShape(new colmesh_cube(tx, ty, tz, tile_size, tile_size, tile_size));
		//		break;
		//	case eTileType.wedge_flat_hor_tl:
		//		_colmesh.addMesh("wedge-flat.obj", matrix_build(tx, ty, tz, 180, 90, -90, tile_size, tile_size, tile_size));
		//		break;
		//}
	}
}