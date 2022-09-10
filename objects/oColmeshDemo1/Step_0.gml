//Verlet integration

//Controls
jump = keyboard_check_pressed(vk_space);
var h = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var v = keyboard_check(ord("W")) - keyboard_check(ord("S"));
if (h != 0 && v != 0)
{	//If walking diagonally, divide the input vector by its own length
	var s = 1 / sqrt(2);
	h *= s;
	v *= s;
}

var acc = agent.ground ? 4 : 1;
var ax = - acc * v;
var ay = - acc * h;
var az = agent.ground * jump * 20;
agent.step(ax, ay, az);
agent.avoid(levelColmesh);

//Put player in the middle of the map if he falls off
if (agent.z < -400)
{
	agent.x = 0;
	agent.y = 0;
	agent.z = 300;
	agent.prevX = agent.x;
	agent.prevY = agent.y;
	agent.prevZ = agent.z;
}

x = agent.x;
y = agent.y;
z = agent.z;

var d = 150;
global.camX = agent.x + d * dcos(yaw) * dcos(pitch);
global.camY = agent.y + d * dsin(yaw) * dcos(pitch);
global.camZ = agent.z + d * dsin(pitch);
camera_set_view_mat(view_camera[0], matrix_build_lookat(global.camX, global.camY, global.camZ, agent.x, agent.y, agent.z, agent.xup, agent.yup, agent.zup));