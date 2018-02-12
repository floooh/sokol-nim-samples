#
#   Test blend-state combinations
#
#   - creates many pipeline state objects, each with a different blend
#     operations and render quads in front of a checkered background
#   - also, this uses a triangle-strip for the quads
#
import opengl
import glm
import glfw3 as glfw
import sokol/gfx as sg

const NUM_BLEND_FACTORS = 15
const WIDTH = 1024
const HEIGHT = 720

# uniform block structs for vertex- and fragment-shaders
type vs_params_t = object
    mvp: Mat4f

type fs_params_t = object
    tick: float32

# initialize GLFW and sokol-gfx
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
let win = glfw.CreateWindow(WIDTH, HEIGHT, "Quad (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)

# need to bump up the default pool size for pipeline objects in sokol-gfx
sg.setup(sg.desc(
    pipeline_pool_size: NUM_BLEND_FACTORS*NUM_BLEND_FACTORS+1
))

# a quad vertex buffer
var vertices = [
    # pos                color
    -1.0f, -1.0f, 0.0f,  1.0f, 0.0f, 0.0f, 0.5f,
    +1.0f, -1.0f, 0.0f,  0.0f, 1.0f, 0.0f, 0.5f,
    -1.0f, +1.0f, 0.0f,  0.0f, 0.0f, 1.0f, 0.5f,
    +1.0f, +1.0f, 0.0f,  1.0f, 1.0f, 0.0f, 0.5f
]
let vbuf = sg.make_buffer(buffer_desc(
    size: sizeof(vertices).cint,
    content: addr(vertices)
))

# a shader for the fullscreen background quad
let bg_shd = sg.make_shader(shader_desc(
    vs: stage_desc(
        source: """
            #version 330
            in vec2 position;
            void main() {
              gl_Position = vec4(position, 0.5, 1.0);
            }
        """
    ),
    fs: stage_desc(
        uniform_blocks: %[
            uniform_block_desc(
                size: sizeof(fs_params_t).cint,
                uniforms: %[
                    uniform_desc(name: "tick", type: UNIFORMTYPE_FLOAT)
                ]
            )
        ],
        source: """
            #version 330
            uniform float tick;
            out vec4 frag_color;
            void main() {
              vec2 xy = fract((gl_FragCoord.xy-vec2(tick)) / 50.0);
              frag_color = vec4(vec3(xy.x*xy.y), 1.0);
            }
        """
    )
))

# a pipeline-state-object for rendering the background
let bg_pip = sg.make_pipeline(pipeline_desc(
    layout: layout_desc(
        # need to provide a stride, because we're using only the pos x/y of a vertex
        buffers: %[ buffer_layout_desc(stride: 28)],
        attrs: %[ attr_desc(name: "position", format: VERTEXFORMAT_FLOAT2)]
    ),
    shader: bg_shd,
    primitive_type: PRIMITIVETYPE_TRIANGLE_STRIP
))

# a shader for the blended quads
let quad_shd = sg.make_shader(shader_desc(
    vs: stage_desc(
        uniform_blocks: %[
            uniform_block_desc(
                size: sizeof(vs_params_t).cint,
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

# create one pipeline object per blend-factor combo
var pips: array[NUM_BLEND_FACTORS, array[NUM_BLEND_FACTORS, pipeline]]
var pip_desc = sg.pipeline_desc(
    layout: layout_desc(
        attrs: %[
            attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3),
            attr_desc(name: "color0", format: VERTEXFORMAT_FLOAT4)
        ]
    ),
    shader: quad_shd,
    primitive_type: PRIMITIVETYPE_TRIANGLE_STRIP,
    blend: blend_desc(
        enabled: true,
        blend_color: [1.0f, 0.0f, 0.0f, 1.0f],
        src_factor_alpha: BLENDFACTOR_ONE,
        dst_factor_alpha: BLENDFACTOR_ZERO
    )
)
for src in 0..<NUM_BLEND_FACTORS:
    for dst in 0..<NUM_BLEND_FACTORS:
        let src_blend = (src+1).blend_factor
        let dst_blend = (dst+1).blend_factor
        pip_desc.blend.src_factor_rgb = src_blend
        pip_desc.blend.dst_factor_rgb = dst_blend
        pips[src][dst] = sg.make_pipeline(pip_desc)

# a pass action which does not clear, since the entire screen is overwritten anyway
let pass_action = sg.pass_action(
    colors: %[
        color_attachment_action(action: ACTION_DONTCARE)
    ],
    depth: depth_attachment_action(action: ACTION_DONTCARE),
    stencil: stencil_attachment_action(action: ACTION_DONTCARE)
)

# a draw state with resource bindings
var draw_state = sg.draw_state(
    vertex_buffers: %[ vbuf ]
)

# a view-projection matrix
const proj = perspective(radians(90.0f), WIDTH.float32/HEIGHT.float32, 0.01f, 100.0f)
const view = lookAt(vec3(0.0f, 0.0f, 20.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f))
const view_proj = proj * view

# frame variables and draw loop
var vs_params: vs_params_t
var fs_params: fs_params_t
var r = 0.0f
fs_params.tick = 0.0f
while glfw.WindowShouldClose(win) == 0:
    var w, h: cint
    glfw.GetFramebufferSize(win, addr(w), addr(h))
    sg.begin_default_pass(pass_action, w, h)

    # the background quad
    draw_state.pipeline = bg_pip
    sg.apply_draw_state(draw_state)
    sg.apply_uniform_block(SHADERSTAGE_FS, 0, addr(fs_params), sizeof(fs_params).cint)
    sg.draw(0, 4, 1)

    # the blended quads
    var r0 = r
    for src in 0..<NUM_BLEND_FACTORS:
        for dst in 0..<NUM_BLEND_FACTORS:
            # compute model-view-projection matrix
            let rm = rotate(mat4(1.0f), r0, 0.0f, 1.0f, 0.0f)
            let x = (dst.float32 - NUM_BLEND_FACTORS/2) * 3.0f
            let y = (src.float32 - NUM_BLEND_FACTORS/2) * 2.2f
            let model = translate(mat4(1.0f), x, y, 0.0f) * rm
            vs_params.mvp = view_proj * model
            # ...and the draw call
            draw_state.pipeline = pips[src][dst]
            sg.apply_draw_state(draw_state)
            sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(vs_params), sizeof(vs_params).cint)
            sg.draw(0, 4, 1)

    sg.end_pass()
    sg.commit()
    glfw.SwapBuffers(win)
    glfw.PollEvents()
    r += radians(0.6f)
    fs_params.tick += 1.0f

sg.shutdown()
glfw.Terminate()
