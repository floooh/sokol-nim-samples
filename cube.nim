import glfw3 as glfw, opengl, glm, sokol/gfx as sg

# initialize GLFW, FlextGL and sokol
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
let win = glfw.CreateWindow(640, 480, "Cube (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
var desc = sg.desc()
sg.setup(desc)

# a draw state to be filled with the resource bindings
var draw_state = sg.draw_state()

# a cube vertex buffer
var verts: array[168, float32] = [
    -1.0f, -1.0f, -1.0f,   1.0f, 0.0f, 0.0f, 1.0f, 
     1.0f, -1.0f, -1.0f,   1.0f, 0.0f, 0.0f, 1.0f,
     1.0f,  1.0f, -1.0f,   1.0f, 0.0f, 0.0f, 1.0f,
    -1.0f,  1.0f, -1.0f,   1.0f, 0.0f, 0.0f, 1.0f,

    -1.0f, -1.0f,  1.0f,   0.0f, 1.0f, 0.0f, 1.0f,
     1.0f, -1.0f,  1.0f,   0.0f, 1.0f, 0.0f, 1.0f, 
     1.0f,  1.0f,  1.0f,   0.0f, 1.0f, 0.0f, 1.0f,
    -1.0f,  1.0f,  1.0f,   0.0f, 1.0f, 0.0f, 1.0f,

    -1.0f, -1.0f, -1.0f,   0.0f, 0.0f, 1.0f, 1.0f, 
    -1.0f,  1.0f, -1.0f,   0.0f, 0.0f, 1.0f, 1.0f, 
    -1.0f,  1.0f,  1.0f,   0.0f, 0.0f, 1.0f, 1.0f, 
    -1.0f, -1.0f,  1.0f,   0.0f, 0.0f, 1.0f, 1.0f,

     1.0f, -1.0f, -1.0f,   1.0f, 0.5f, 0.0f, 1.0f, 
     1.0f,  1.0f, -1.0f,   1.0f, 0.5f, 0.0f, 1.0f, 
     1.0f,  1.0f,  1.0f,   1.0f, 0.5f, 0.0f, 1.0f, 
     1.0f, -1.0f,  1.0f,   1.0f, 0.5f, 0.0f, 1.0f,

    -1.0f, -1.0f, -1.0f,   0.0f, 0.5f, 1.0f, 1.0f, 
    -1.0f, -1.0f,  1.0f,   0.0f, 0.5f, 1.0f, 1.0f, 
     1.0f, -1.0f,  1.0f,   0.0f, 0.5f, 1.0f, 1.0f, 
     1.0f, -1.0f, -1.0f,   0.0f, 0.5f, 1.0f, 1.0f,

    -1.0f,  1.0f, -1.0f,   1.0f, 0.0f, 0.5f, 1.0f, 
    -1.0f,  1.0f,  1.0f,   1.0f, 0.0f, 0.5f, 1.0f, 
     1.0f,  1.0f,  1.0f,   1.0f, 0.0f, 0.5f, 1.0f, 
     1.0f,  1.0f, -1.0f,   1.0f, 0.0f, 0.5f, 1.0f    
]
var vbuf_desc = sg.buffer_desc(
    size: sizeof(verts).cint,
    content: addr(verts)
)
draw_state.vertex_buffers[0] = sg.make_buffer(vbuf_desc)

# a cube index buffer
var indices: array[36, uint16] = [
     0u16,  1u16,  2u16,   0u16,  2u16,  3u16,
     6u16,  5u16,  4u16,   7u16,  6u16,  4u16,
     8u16,  9u16, 10u16,   8u16, 10u16, 11u16,
    14u16, 13u16, 12u16,  15u16, 14u16, 12u16,
    16u16, 17u16, 18u16,  16u16, 18u16, 19u16,
    22u16, 21u16, 20u16,  23u16, 22u16, 20u16
]
var ibuf_desc = sg.buffer_desc(
    type: BUFFERTYPE_INDEXBUFFER,
    size: sizeof(indices).int32,
    content: addr(indices)
)
draw_state.index_buffer = sg.make_buffer(ibuf_desc)

# a uniform block with a model-view-projection matrix
type params_t = object
    mvp: Mat4f

# a shader
# FIXME: is there a way to partially initialize arrays from within
# the object creation call?
var shd_desc = sg.shader_desc()
shd_desc.vs.uniform_blocks[0].size = sizeof(params_t).int32
shd_desc.vs.uniform_blocks[0].uniforms[0] = sg.shader_uniform_desc(name: "mvp", type: UNIFORMTYPE_MAT4)
shd_desc.vs.source = """
    #version 330
    uniform mat4 mvp;
    in vec4 position;
    in vec4 color0;
    out vec4 color;
    void main() {
        gl_Position = mvp * position;
        color = color0;
    }
    """
shd_desc.fs.source = """
    #version 330
    in vec4 color;
    out vec4 frag_color;
    void main() {
        frag_color = color;
    }
    """

# a pipeline state object
var pip_desc = sg.pipeline_desc(
    shader: sg.make_shader(shd_desc),
    index_type: INDEXTYPE_UINT16,
    depth_stencil: sg.depth_stencil_state(
        depth_compare_func: COMPAREFUNC_LESS_EQUAL,
        depth_write_enabled: true
    ),
    rasterizer: sg.rasterizer_state(
        cull_mode: CULLMODE_BACK
    )
)
pip_desc.layout.attrs[0] = sg.vertex_attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3)
pip_desc.layout.attrs[1] = sg.vertex_attr_desc(name: "color0", format: VERTEXFORMAT_FLOAT4)
draw_state.pipeline = sg.make_pipeline(pip_desc)

# a default pass action (clear to grey)
var pass_action = sg.pass_action()

# a view-projection matrix
const proj = perspective(radians(60.0f), 640.0f/480.0f, 0.01f, 100.0f)
const view = lookAt(vec3(0.0f, 1.5f, 6.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f))
var params = params_t()
var rx, ry = 0.0f

# draw loop
while glfw.WindowShouldClose(win) == 0:
    # rotated model-view-proj matrix
    rx += 1.0f
    ry += 2.0f;
    var rxm = rotate(mat4f(1.0f), radians(rx), 1.0f, 0.0f, 0.0f)
    var rym = rotate(mat4f(1.0f), radians(ry), 0.0f, 1.0f, 0.0f)
    var model = rxm * rym
    var mvp = proj * view * model
    params.mvp = mvp

    var w, h: cint
    glfw.GetFramebufferSize(win, addr(w), addr(h))
    sg.begin_default_pass(pass_action, w, h)
    sg.apply_draw_state(draw_state)
    sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(params), sizeof(params).cint)
    sg.draw(0, 36, 1)
    sg.end_pass()
    sg.commit()
    glfw.SwapBuffers(win)
    glfw.PollEvents()

sg.shutdown()
glfw.Terminate()
