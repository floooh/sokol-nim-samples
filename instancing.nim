import opengl
import glm
import random
import glfw3 as glfw
import sokol/gfx as sg

const
    WIDTH = 640
    HEIGHT = 480
    MAX_PARTICLES = 512*1024
    NUM_PARTICLES_EMITTED_PER_FRAME = 10

# a uniform block with a model-view-projection matrix
type params_t = object
    mvp: Mat4f

# particle positions and velocity
var num_particles = 0
var pos: array[MAX_PARTICLES, Vec3f]
var vel: array[MAX_PARTICLES, Vec3f]

# initialize GLFW, FlextGL and sokol
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
let win = glfw.CreateWindow(640, 480, "Clear (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
sg.setup(sg.desc())

# a vertex buffer for the static geometry (goes into vertex buffer bind slot 0)
const r = 0.05f
var vertices = [
    # positions             colors
    0.0f,   -r, 0.0f,       1.0f, 0.0f, 0.0f, 1.0f,
       r, 0.0f, r,          0.0f, 1.0f, 0.0f, 1.0f,
       r, 0.0f, -r,         0.0f, 0.0f, 1.0f, 1.0f,
      -r, 0.0f, -r,         1.0f, 1.0f, 0.0f, 1.0f,
      -r, 0.0f, r,          0.0f, 1.0f, 1.0f, 1.0f,
    0.0f,    r, 0.0f,       1.0f, 0.0f, 1.0f, 1.0f
]
let vbuf_geom = sg.make_buffer(buffer_desc(
    size: sizeof(vertices).cint,
    content: addr(vertices)
))

# an index buffer for the static geometry
var indices = [
    0u16, 1, 2,    0, 2, 3,    0, 3, 4,    0, 4, 1,
    5,    1, 2,    5, 2, 3,    5, 3, 4,    5, 4, 1    
]
let ibuf_geom = sg.make_buffer(buffer_desc(
    type: BUFFERTYPE_INDEXBUFFER,
    size: sizeof(indices).cint,
    content: addr(indices)
))

# an empty, dynamic instance-data buffer (goes into vertex buffer slot 1)
let vbuf_inst = sg.make_buffer(buffer_desc(
    usage: USAGE_STREAM,
    size: (sizeof(Vec3f) * MAX_PARTICLES).cint
))

# a shader for instanced rendering
let shd = sg.make_shader(shader_desc(
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
            in vec3 position;
            in vec4 color0;
            in vec3 instance_pos;
            out vec4 color;
            void main() {
                vec4 pos = vec4(position + instance_pos, 1.0);
                gl_Position = mvp * pos;
                color = color0;
            }
            """,
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

# a pipeline state object, note the vertex layout definition
let pip = sg.make_pipeline(pipeline_desc(
    layout: layout_desc(
        buffers: %[
            buffer_layout_desc(stride: 28),
            buffer_layout_desc(stride: 12, step_func: VERTEXSTEP_PER_INSTANCE)
        ],
        attrs: %[
            attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3, buffer_index: 0),
            attr_desc(name: "color0", format: VERTEXFORMAT_FLOAT4, buffer_index: 0),
            attr_desc(name: "instance_pos", format: VERTEXFORMAT_FLOAT3, buffer_index: 1)
        ]
    ),
    shader: shd,
    index_type: INDEXTYPE_UINT16,
    depth_stencil: depth_stencil_desc(
        depth_compare_func: COMPAREFUNC_LESS_EQUAL,
        depth_write_enabled: true
    ),
    rasterizer: rasterizer_desc(
        cull_mode: CULLMODE_BACK
    )
))

# a draw state with the resource bindings, note the two vertex buffers
let draw_state = sg.draw_state(
    pipeline: pip,
    vertex_buffers: %[ vbuf_geom, vbuf_inst ],
    index_buffer: ibuf_geom
)

# default pass_action (clear to grey)
let pass_action = sg.pass_action()

# a view-projection matrix and frame-variables
const proj = perspective(radians(60.0f), WIDTH.float32/HEIGHT.float32, 0.01f, 50.0f)
const view = lookAt(vec3(0.0f, 1.5f, 12.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f))
const view_proj = proj * view
var params = params_t()
var roty = 0.0f
const frame_time = 1.0f/60.0f

# the update/draw loop
while glfw.WindowShouldClose(win) == 0:
    # emit new particles
    for i in 0..<NUM_PARTICLES_EMITTED_PER_FRAME:
        if num_particles < MAX_PARTICLES:
            pos[num_particles] = vec3f(0.0f)
            vel[num_particles] = vec3f(
                random(1.0f) - 0.5f,
                random(1.0f) * 0.5 + 2.0f,
                random(1.0f) - 0.5f)
            num_particles += 1
        else:
            break
    for i in 0..<num_particles:
        vel[i].y -= 1.0f * frame_time
        pos[i] += vel[i] * frame_time
        if pos[i].y < -2.0:
            pos[i].y = -1.8f
            vel[i].y = -vel[i].y
            vel[i] *= 0.8f

    # update instance data
    sg.update_buffer(vbuf_inst, addr(pos), sizeof(pos).cint)

    # update model-view-proj matrix
    roty += radians(1.0f)
    params.mvp = view_proj * rotate(mat4(1.0f), roty, 0.0f, 1.0f, 0.0f)

    # draw the frame
    var w, h: cint
    glfw.GetFramebufferSize(win, addr(w), addr(h))
    sg.begin_default_pass(pass_action, w, h)
    sg.apply_draw_state(draw_state)
    sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(params), sizeof(params).cint)
    sg.draw(0, 24, num_particles.cint)
    sg.end_pass()
    sg.commit()
    glfw.SwapBuffers(win)
    glfw.PollEvents()

# ...and done
sg.shutdown()
glfw.Terminate()
