event_inherited();

var o = world_to_screen(x + radius, y, z + height, camera_get_view_mat(view_camera[0]), camera_get_proj_mat(view_camera[0]));
draw_circle_color(o.x, o.y, 2, c_red, c_red, false);