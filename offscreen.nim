# offscreen rendering
#
#   - renders a rotating cube into an offscreen render target...
#   - ...and uses the offscreen render target as texture for 
#     rendering a textured cube to the default framebuffer
#   - a pass object with a color- and depth-image attachemnt
#   - 2 sets of shaders and pipeline-state-objects, one for 
#     offscreen rendering, the other for rendering into the
#     default framebuffer
#
import glfw3 as glfw
import opengl
import glm
import sokol/gfx as sg

# initialize GLFW and sokol-gfx
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
let win = glfw.CreateWindow(640, 480, "Offscreen Rendering (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
sg.setup(sg.desc())

# create a render target with a color- and depth-image
let offscreen_sample_count = if sg.query_feature(FEATURE_MSAA_RENDER_TARGETS): 4 else: 1
var img_desc = sg.image_desc(
    render_target: true,
    width: 512,
    height: 512,
    pixel_format: PIXELFORMAT_RGBA8,
    min_filter: FILTER_LINEAR,
    mag_filter: FILTER_LINEAR,
    sample_count: offscreen_sample_count.cint
)
let color_img = sg.make_image(img_desc)
img_desc.pixel_format = PIXELFORMAT_DEPTH
let depth_img = sg.make_image(img_desc)
let offscreen_pass = sg.make_pass(pass_desc(
    color_attachments: %[ attachment_desc(image: color_img) ],
    depth_stencil_attachment: attachment_desc(image: depth_img)
))

# pass action for offscreen pass, clear to black
let offscreen_pass_action = sg.pass_action(
    colors: %[ 
        color_attachment_action(action: ACTION_CLEAR, val: [0.0f, 0.0f, 0.0f, 1.0f])
    ]
)

# pass action for default pass, clear to blue-ish
let default_pass_action = sg.pass_action(
    colors: %[
        color_attachment_action(action: ACTION_CLEAR, val: [0.0f, 0.25f, 1.0f, 1.0f])
    ]
)

# cube vertex buffer with positions, colors and tex coords
var vertices = [
    # pos                  color                       uvs
    -1.0f, -1.0f, -1.0f,    1.0f, 0.5f, 0.5f, 1.0f,     0.0f, 0.0f,
     1.0f, -1.0f, -1.0f,    1.0f, 0.5f, 0.5f, 1.0f,     1.0f, 0.0f,
     1.0f,  1.0f, -1.0f,    1.0f, 0.5f, 0.5f, 1.0f,     1.0f, 1.0f,
    -1.0f,  1.0f, -1.0f,    1.0f, 0.5f, 0.5f, 1.0f,     0.0f, 1.0f,

    -1.0f, -1.0f,  1.0f,    0.5f, 1.0f, 0.5f, 1.0f,     0.0f, 0.0f, 
     1.0f, -1.0f,  1.0f,    0.5f, 1.0f, 0.5f, 1.0f,     1.0f, 0.0f,
     1.0f,  1.0f,  1.0f,    0.5f, 1.0f, 0.5f, 1.0f,     1.0f, 1.0f,
    -1.0f,  1.0f,  1.0f,    0.5f, 1.0f, 0.5f, 1.0f,     0.0f, 1.0f,

    -1.0f, -1.0f, -1.0f,    0.5f, 0.5f, 1.0f, 1.0f,     0.0f, 0.0f,
    -1.0f,  1.0f, -1.0f,    0.5f, 0.5f, 1.0f, 1.0f,     1.0f, 0.0f,
    -1.0f,  1.0f,  1.0f,    0.5f, 0.5f, 1.0f, 1.0f,     1.0f, 1.0f,
    -1.0f, -1.0f,  1.0f,    0.5f, 0.5f, 1.0f, 1.0f,     0.0f, 1.0f,

     1.0f, -1.0f, -1.0f,    1.0f, 0.5f, 0.0f, 1.0f,     0.0f, 0.0f,
     1.0f,  1.0f, -1.0f,    1.0f, 0.5f, 0.0f, 1.0f,     1.0f, 0.0f,
     1.0f,  1.0f,  1.0f,    1.0f, 0.5f, 0.0f, 1.0f,     1.0f, 1.0f,
     1.0f, -1.0f,  1.0f,    1.0f, 0.5f, 0.0f, 1.0f,     0.0f, 1.0f,

    -1.0f, -1.0f, -1.0f,    0.0f, 0.5f, 1.0f, 1.0f,     0.0f, 0.0f,
    -1.0f, -1.0f,  1.0f,    0.0f, 0.5f, 1.0f, 1.0f,     1.0f, 0.0f,
     1.0f, -1.0f,  1.0f,    0.0f, 0.5f, 1.0f, 1.0f,     1.0f, 1.0f,
     1.0f, -1.0f, -1.0f,    0.0f, 0.5f, 1.0f, 1.0f,     0.0f, 1.0f,

    -1.0f,  1.0f, -1.0f,    1.0f, 0.0f, 0.5f, 1.0f,     0.0f, 0.0f,
    -1.0f,  1.0f,  1.0f,    1.0f, 0.0f, 0.5f, 1.0f,     1.0f, 0.0f,
     1.0f,  1.0f,  1.0f,    1.0f, 0.0f, 0.5f, 1.0f,     1.0f, 1.0f,
     1.0f, 1.0f,  -1.0f,    1.0f, 0.0f, 0.5f, 1.0f,     0.0f, 1.0f
]
let vbuf = sg.make_buffer(buffer_desc(
    size: sizeof(vertices).cint,
    content: addr(vertices)
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
let ibuf = sg.make_buffer(buffer_desc(
    type: BUFFERTYPE_INDEXBUFFER,
    size: sizeof(indices).cint,
    content: addr(indices)
))

# a uniform block with a model-view-projection matrix
type params_t = object
    mvp: Mat4f

# a shader for a non-textured cube, rendered in the offscreen pass
let offscreen_shd = sg.make_shader(shader_desc(
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

# and another shader for rendering a textured cube into the default pass
let default_shd = sg.make_shader(shader_desc(
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
            in vec2 texcoord0;
            out vec4 color;
            out vec2 uv;
            void main() {
              gl_Position = mvp * position;
              color = color0;
              uv = texcoord0;
            }
            """
    ),
    fs: stage_desc(
        images: %[
            shader_image_desc(name: "tex", type: IMAGETYPE_2D)
        ],
        source: """
            #version 330
            uniform sampler2D tex;
            in vec4 color;
            in vec2 uv;
            out vec4 frag_color;
            void main() {
              frag_color = texture(tex, uv) + color * 0.5;
            }
            """
    )
))

# pipeline object for offscreen rendering, don't need texcoord here
let offscreen_pip = sg.make_pipeline(pipeline_desc(
    layout: layout_desc(
        buffers: %[
            # need to provide a buffer stride because of gaps between vertices
            buffer_layout_desc(stride: 36)
        ],
        attrs: %[
            attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3),
            attr_desc(name: "color0", format: VERTEXFORMAT_FLOAT4)
        ]
    ),
    shader: offscreen_shd,
    index_type: INDEXTYPE_UINT16,
    depth_stencil: depth_stencil_desc(
        depth_compare_func: COMPAREFUNC_LESS_EQUAL,
        depth_write_enabled: true
    ),
    blend: blend_desc(
        color_format: PIXELFORMAT_RGBA8,
        depth_format: PIXELFORMAT_DEPTH
    ),
    rasterizer: rasterizer_desc(
        cull_mode: CULLMODE_BACK,
        sample_count: offscreen_sample_count.cint
    )
))

# and another pipeline object for the default pass
let default_pip = sg.make_pipeline(pipeline_desc(
    layout: layout_desc(
        attrs: %[
            attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3),
            attr_desc(name: "color0", format: VERTEXFORMAT_FLOAT4),
            attr_desc(name: "texcoord0", format: VERTEXFORMAT_FLOAT2)
        ]
    ),
    shader: default_shd,
    index_type: INDEXTYPE_UINT16,
    depth_stencil: depth_stencil_desc(
        depth_compare_func: COMPAREFUNC_LESS_EQUAL,
        depth_write_enabled: true
    ),
    rasterizer: rasterizer_desc(
        cull_mode: CULLMODE_BACK
    )
))

# a draw state with the resource bindings for offscreen rendering
let offscreen_ds = sg.draw_state(
    pipeline: offscreen_pip,
    vertex_buffers: %[vbuf],
    index_buffer: ibuf
)

# and another draw state for the default pass where a textured cube
# will be rendered, note how the render-target image is used as texture here
let default_ds = sg.draw_state(
    pipeline: default_pip,
    vertex_buffers: %[vbuf],
    index_buffer: ibuf,
    fs_images: %[color_img]
)

const proj = perspective(radians(45.0f), 640.0f/480.0f, 0.01f, 100.0f)
const view = lookAt(vec3(0.0f, 1.5f, 6.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f))
var params = params_t()
var rx, ry = 0.0f

# the draw loop
while glfw.WindowShouldClose(win) == 0:
    # rotated model-view-proj matrix
    rx += 1.0f
    ry += 2.0f;
    var rxm = rotate(mat4f(1.0f), radians(rx), 1.0f, 0.0f, 0.0f)
    var rym = rotate(mat4f(1.0f), radians(ry), 0.0f, 1.0f, 0.0f)
    var model = rxm * rym
    var mvp = proj * view * model
    params.mvp = mvp

    # render an untextured cube into the offscreen pass
    sg.begin_pass(offscreen_pass, offscreen_pass_action)
    sg.apply_draw_state(offscreen_ds)
    sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(params), sizeof(params).cint)
    sg.draw(0, 36, 1)
    sg.end_pass()

    # and the default-pass, which renders a textured cube
    var w, h: cint
    glfw.GetFramebufferSize(win, addr(w), addr(h))
    sg.begin_default_pass(default_pass_action, w, h)
    sg.apply_draw_state(default_ds)
    sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(params), sizeof(params).cint)
    sg.draw(0, 36, 1)
    sg.end_pass()
    sg.commit()
    glfw.SwapBuffers(win)
    glfw.PollEvents()

# shutdown sokol-gfx and glfw
sg.shutdown()
glfw.Terminate()
