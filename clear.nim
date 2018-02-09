import glfw3 as glfw
import opengl
import sokol/gfx as sg
import sokol/flextgl as flextgl

# initialize GLFW, FlextGL and sokol
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
let win = glfw.CreateWindow(640, 480, "Triangle (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
flextgl.init()
var desc = sg.desc()
sg.setup(desc)

# a pass action (clear to color)
var pass_action = sg.pass_action()
pass_action.colors[0].action = ACTION_CLEAR
pass_action.colors[0].val = [1.0f, 0.0f, 0.0f, 1.0f]

# draw loop
while glfw.WindowShouldClose(win) == 0:
    # animate clear color
    var g = pass_action.colors[0].val[1] + 0.01
    if (g > 1.0f): g = 0.0f
    pass_action.colors[0].val[1] = g;

    var w, h: cint
    glfw.GetFramebufferSize(win, addr(w), addr(h))
    sg.begin_default_pass(pass_action, w, h)
    sg.end_pass()
    sg.commit()
    glfw.PollEvents()
    glfw.SwapBuffers(win)

sg.shutdown()
glfw.Terminate()
