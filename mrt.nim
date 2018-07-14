# multiple-rendertarget rendering
#
#   - render into a render-target with multiple attached images in
#     an offscreen-pass
#   - ...and access those images later in unique textures
#
import glfw3 as glfw
import glm
import math
import sokol/gfx as sg

const
    WIDTH = 640
    HEIGHT = 480

# uniform block structs
type offscreen_params_t = object
    mvp: Mat4f

type params_t = object
    offset: Vec2f

# initialize GLFW and sokol-gfx
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, 1)
let win = glfw.CreateWindow(WIDTH, HEIGHT, "Multiple Rendertarget (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
when defined(windows):
    discard gladLoadGL()
sg.setup(sg.desc())

# a pass object with 3 color attachment-, and one depth attachment-image
let offscreen_sample_count: cint = if sg.query_feature(FEATURE_MSAA_RENDER_TARGETS): 4 else: 1
var color_img_desc = sg.image_desc(
    render_target: true,
    width: WIDTH,
    height: HEIGHT,
    pixel_format: PIXELFORMAT_RGBA8,
    min_filter: FILTER_LINEAR,
    mag_filter: FILTER_LINEAR,
    wrap_u: WRAP_CLAMP_TO_EDGE,
    wrap_v: WRAP_CLAMP_TO_EDGE,
    sample_count: offscreen_sample_count
)
var depth_img_desc = color_img_desc
depth_img_desc.pixel_format = PIXELFORMAT_DEPTH
var mrt_images: array[3, sg.image]
for i in 0..mrt_images.high:
    mrt_images[i] = sg.make_image(color_img_desc)
let offscreen_pass = sg.make_pass(pass_desc(
    color_attachments: %[
        attachment_desc(image: mrt_images[0]),
        attachment_desc(image: mrt_images[1]),
        attachment_desc(image: mrt_images[2])
    ],
    depth_stencil_attachment: attachment_desc(image: sg.make_image(depth_img_desc))
))

# a matching pass-action with clear colors
let offscreen_pass_action = sg.pass_action(
    colors: %[
        color_attachment_action(action: ACTION_CLEAR, val: [0.25f, 0.0f, 0.0f, 1.0f]),
        color_attachment_action(action: ACTION_CLEAR, val: [0.0f, 0.25f, 0.0f, 1.0f]),
        color_attachment_action(action: ACTION_CLEAR, val: [0.0f, 0.0f, 0.25f, 1.0f])
    ]
)

# a cube vertex buffer
var cube_vertices = [
    # pos + brightness
    -1.0f, -1.0f, -1.0f,   1.0f,
     1.0f, -1.0f, -1.0f,   1.0f,
     1.0f,  1.0f, -1.0f,   1.0f,
    -1.0f,  1.0f, -1.0f,   1.0f,

    -1.0f, -1.0f,  1.0f,   0.8f,
     1.0f, -1.0f,  1.0f,   0.8f,
     1.0f,  1.0f,  1.0f,   0.8f,
    -1.0f,  1.0f,  1.0f,   0.8f,

    -1.0f, -1.0f, -1.0f,   0.6f,
    -1.0f,  1.0f, -1.0f,   0.6f,
    -1.0f,  1.0f,  1.0f,   0.6f,
    -1.0f, -1.0f,  1.0f,   0.6f,

    1.0f, -1.0f, -1.0f,    0.4f,
    1.0f,  1.0f, -1.0f,    0.4f,
    1.0f,  1.0f,  1.0f,    0.4f,
    1.0f, -1.0f,  1.0f,    0.4f,

    -1.0f, -1.0f, -1.0f,   0.5f,
    -1.0f, -1.0f,  1.0f,   0.5f,
     1.0f, -1.0f,  1.0f,   0.5f,
     1.0f, -1.0f, -1.0f,   0.5f,

    -1.0f,  1.0f, -1.0f,   0.7f,
    -1.0f,  1.0f,  1.0f,   0.7f,
     1.0f,  1.0f,  1.0f,   0.7f,
     1.0f,  1.0f, -1.0f,   0.7f,    
]
let cube_vbuf = sg.make_buffer(buffer_desc(
    size: sizeof(cube_vertices).cint,
    content: addr(cube_vertices)
))

# a cube index buffer
var cube_indices = [
    0u16, 1, 2,  0, 2, 3,
    6, 5, 4,  7, 6, 4,
    8, 9, 10,  8, 10, 11,
    14, 13, 12,  15, 14, 12,
    16, 17, 18,  16, 18, 19,
    22, 21, 20,  23, 22, 20    
]
let cube_ibuf = sg.make_buffer(buffer_desc(
    type: BUFFERTYPE_INDEXBUFFER,
    size: sizeof(cube_indices).cint,
    content: addr(cube_indices)
))

# a shader to render a cube into an MRT offscreen pass
let cube_shd = sg.make_shader(shader_desc(
    vs: stage_desc(
        uniform_blocks: %[
            uniform_block_desc(
                size: sizeof(offscreen_params_t).cint,
                uniforms: %[
                    uniform_desc(name: "mvp", type: UNIFORMTYPE_MAT4)
                ]
            )
        ],
        source: """
            #version 330
            uniform mat4 mvp;
            in vec4 position;
            in float bright0;
            out float bright;
            void main() {
              gl_Position = mvp * position;
              bright = bright0;
            }
            """
    ),
    fs: stage_desc(
        source: """
            #version 330
            in float bright;
            layout(location=0) out vec4 frag_color_0;
            layout(location=1) out vec4 frag_color_1;
            layout(location=2) out vec4 frag_color_2;
            void main() {
              frag_color_0 = vec4(bright, 0.0, 0.0, 1.0);
              frag_color_1 = vec4(0.0, bright, 0.0, 1.0);
              frag_color_2 = vec4(0.0, 0.0, bright, 1.0);
            }
            """
    )
))

# a pipeline object for the offscreen-rendered cube
let cube_pip = sg.make_pipeline(pipeline_desc(
    layout: layout_desc(
        attrs: %[
            attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3),
            attr_desc(name: "bright0", format: VERTEXFORMAT_FLOAT)
        ]
    ),
    shader: cube_shd,
    index_type: INDEXTYPE_UINT16,
    depth_stencil: depth_stencil_desc(
        depth_compare_func: COMPAREFUNC_LESS_EQUAL,
        depth_write_enabled: true
    ),
    blend: blend_desc(
        color_attachment_count: 3,
        color_format: PIXELFORMAT_RGBA8,
        depth_format: PIXELFORMAT_DEPTH
    ),
    rasterizer: rasterizer_desc(
        cull_mode: CULLMODE_BACK,
        sample_count: offscreen_sample_count
    )
))

# draw state for rendering the offscreen cube
let offscreen_ds = sg.draw_state(
    pipeline: cube_pip,
    vertex_buffers: %[ cube_vbuf ],
    index_buffer: cube_ibuf
)

# a vertex buffer to render a fullscreen quad
var quad_vertices = [ 0.0f, 0.0f,  1.0f, 0.0f,  0.0f, 1.0f,  1.0f, 1.0f ]
let quad_vbuf = sg.make_buffer(buffer_desc(
    size: sizeof(quad_vertices).cint,
    content: addr(quad_vertices)
))

# a shader which renders a fullscreen rectangle which 'composes' the 
# 3 MRT images onto the screen
let fsq_shd = sg.make_shader(shader_desc(
    vs: stage_desc(
        uniform_blocks: %[
            uniform_block_desc(
                size: sizeof(params_t).cint,
                uniforms: %[
                    uniform_desc(name: "offset", type: UNIFORMTYPE_FLOAT2)
                ]
            )
        ],
        source: """
            #version 330
            uniform vec2 offset;
            in vec2 pos;
            out vec2 uv0;
            out vec2 uv1;
            out vec2 uv2;
            void main() {
              gl_Position = vec4(pos*2.0-1.0, 0.5, 1.0);
              uv0 = pos + vec2(offset.x, 0.0);
              uv1 = pos + vec2(0.0, offset.y);
              uv2 = pos;
            }
            """
    ),
    fs: stage_desc(
        images: %[
            shader_image_desc(name: "tex0", type: IMAGETYPE_2D),
            shader_image_desc(name: "tex1", type: IMAGETYPE_2D),
            shader_image_desc(name: "tex2", type: IMAGETYPE_2D)
        ],
        source: """
            #version 330
            uniform sampler2D tex0;
            uniform sampler2D tex1;
            uniform sampler2D tex2;
            in vec2 uv0;
            in vec2 uv1;
            in vec2 uv2;
            out vec4 frag_color;
            void main() {
              vec3 c0 = texture(tex0, uv0).xyz;
              vec3 c1 = texture(tex1, uv1).xyz;
              vec3 c2 = texture(tex2, uv2).xyz;
              frag_color = vec4(c0 + c1 + c2, 1.0);
            }
            """
    )
))

# a pipeline object for the fullscreen quad
let fsq_pip = sg.make_pipeline(pipeline_desc(
    layout: layout_desc(
        attrs: %[ attr_desc(name: "pos", format: VERTEXFORMAT_FLOAT2) ]
    ),
    shader: fsq_shd,
    primitive_type: PRIMITIVETYPE_TRIANGLE_STRIP
))

# a draw state to render the fullscreen quad
let fsq_ds = sg.draw_state(
    pipeline: fsq_pip,
    vertex_buffers: %[ quad_vbuf ],
    fs_images: %[ mrt_images[0], mrt_images[1], mrt_images[2] ]
)

# another draw state to render a debug-visualization at the bottom of the screen
var dbg_ds = sg.draw_state(
    vertex_buffers: %[ quad_vbuf ],
    pipeline: sg.make_pipeline(pipeline_desc(
        layout: layout_desc(
            attrs: %[ attr_desc(name: "pos", format: VERTEXFORMAT_FLOAT2) ]
        ),
        primitive_type: PRIMITIVETYPE_TRIANGLE_STRIP,
        shader: sg.make_shader(shader_desc(
            vs: stage_desc(
                source: """
                    #version 330
                    in vec2 pos;
                    out vec2 uv;
                    void main() {
                      gl_Position = vec4(pos*2.0-1.0, 0.5, 1.0);
                      uv = pos;
                    }
                    """
            ),
            fs: stage_desc(
                images: %[ shader_image_desc(name: "tex", type: IMAGETYPE_2D) ],
                source: """
                    #version 330
                    uniform sampler2D tex;
                    in vec2 uv;
                    out vec4 frag_color;
                    void main() {
                      frag_color = vec4(texture(tex,uv).xyz, 1.0);
                    }
                    """
            )
        ))
    ))
)

# the default pass-action, no clear needed, since the whole screen is overwritten
let pass_action = sg.pass_action(
    colors: %[
        color_attachment_action(action: ACTION_DONTCARE),
        color_attachment_action(action: ACTION_DONTCARE),
        color_attachment_action(action: ACTION_DONTCARE),
    ],
    depth: depth_attachment_action(action: ACTION_DONTCARE),
    stencil: stencil_attachment_action(action: ACTION_DONTCARE)
)

const proj = perspective(radians(60.0f), WIDTH.float32/HEIGHT.float32, 0.01f, 10.0f)
const view = lookAt(vec3(0.0f, 1.5f, 6.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f))
const view_proj = proj * view
var offscreen_params: offscreen_params_t
var params: params_t
var rx, ry = 0.0f

while glfw.WindowShouldClose(win) == 0:
    rx += radians(1.0f); ry += radians(2.0f)
    let rxm = rotate(mat4(1.0f), rx, 1.0f, 0.0f, 0.0f)
    let rym = rotate(mat4(1.0f), ry, 0.0f, 1.0f, 0.0f)
    let model = rxm * rym
    offscreen_params.mvp = view_proj * model
    params.offset = vec2(sin(rx)*0.1f, sin(ry)*0.1f)

    # render cube into offscreen MRT
    sg.begin_pass(offscreen_pass, offscreen_pass_action)
    sg.apply_draw_state(offscreen_ds)
    sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(offscreen_params), sizeof(offscreen_params))
    sg.draw(0, 36, 1)
    sg.end_pass()

    # render fullscreen quad with the composed image, and 3 small
    # debug visualization rects at the bottom
    var w, h: cint
    glfw.GetFramebufferSize(win, addr(w), addr(h))
    sg.begin_default_pass(pass_action, w, h)
    sg.apply_draw_state(fsq_ds)
    sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(params), sizeof(params))
    sg.draw(0, 4, 1)
    for i in 0..2:
        sg.apply_view_port(i*100, 0, 100, 100, false)
        dbg_ds.fs_images[0] = mrt_images[i]
        sg.apply_draw_state(dbg_ds)
        sg.draw(0, 4, 1)
    sg.end_pass()
    sg.commit()
    glfw.SwapBuffers(win)
    glfw.PollEvents()

sg.shutdown()
glfw.Terminate()