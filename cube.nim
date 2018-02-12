import glfw3 as glfw
import opengl
import glm
import sokol/gfx as sg

# initialize GLFW, FlextGL and sokol
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
let win = glfw.CreateWindow(640, 480, "Cube (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
sg.setup(sg.desc())

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
let vbuf = sg.make_buffer(sg.buffer_desc(
    size: sizeof(verts).cint,
    content: addr(verts)
))

# a cube index buffer
var indices = [
     0u16, 1,  2,   0,  2,  3,
     6,    5,  4,   7,  6,  4,
     8,    9, 10,   8, 10, 11,
    14,   13, 12,  15, 14, 12,
    16,   17, 18,  16, 18, 19,
    22,   21, 20,  23, 22, 20
]
let ibuf = sg.make_buffer(sg.buffer_desc(
    type: BUFFERTYPE_INDEXBUFFER,
    size: sizeof(indices).int32,
    content: addr(indices)
))

# a uniform block with a model-view-projection matrix
type params_t = object
    mvp: Mat4f

# a shader
let shd = sg.make_shader(sg.shader_desc(
    vs: stage_desc(
        uniform_blocks: %[
            uniform_block_desc(
                size: sizeof(params_t).cint,
                uniforms: %[
                    uniform_desc(name: "mvp", type: UNIFORMTYPE_MAT4)
                ]
            )
        ],
        source: """
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
    ),
    fs: stage_desc(
        source: """
            #version 330
            in vec4 color;
            out vec4 frag_color;
            void main() {
                frag_color = color;
            }
            """
    )
))

# a pipeline state object
let pip = sg.make_pipeline(sg.pipeline_desc(
    shader: shd,
    layout: layout_desc(
        attrs: %[
            attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3),
            attr_desc(name: "color0", format: VERTEXFORMAT_FLOAT4)
        ]
    ),
    index_type: INDEXTYPE_UINT16,
    depth_stencil: depth_stencil_desc(
        depth_compare_func: COMPAREFUNC_LESS_EQUAL,
        depth_write_enabled: true
    ),
    rasterizer: rasterizer_desc(
        cull_mode: CULLMODE_BACK
    )
))

# a draw state with the resource bindings
let draw_state = sg.draw_state(
    pipeline: pip,
    vertex_buffers: %[vbuf],
    index_buffer: ibuf
)

# a default pass action (clear to grey)
let pass_action = sg.pass_action()

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
