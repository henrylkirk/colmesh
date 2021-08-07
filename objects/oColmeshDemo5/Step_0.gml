// Move camera
var d = 100;
global.camX = obj_player.x + d * dcos(yaw) * dcos(pitch);
global.camY = obj_player.y + d * dsin(yaw) * dcos(pitch);
global.camZ = obj_player.z + d * dsin(pitch);
camera_set_view_mat(view_camera[0], matrix_build_lookat(global.camX, global.camY, global.camZ, obj_player.x, obj_player.y, obj_player.z, obj_player.xup, obj_player.yup, obj_player.zup));