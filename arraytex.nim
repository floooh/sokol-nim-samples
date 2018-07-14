# demonstrates creating and rendering from an 2d-array-texture
#
import glfw3 as glfw
import glm
import sokol/gfx as sg

const
    WIDTH = 800
    HEIGHT = 600
    IMG_LAYERS = 3
    IMG_WIDTH = 16
    IMG_HEIGHT = 16

# a uniform block struct for the vertex shader
type params_t = object
    mvp: Mat4f
    offset0: Vec2f
    offset1: Vec2f
    offset2: Vec2f

# initialize GLFW and sokol-gfx
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, 1)
let win = glfw.CreateWindow(WIDTH, HEIGHT, "Array Texture (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
when defined(windows):
    discard gladLoadGL()
sg.setup(sg.desc())

# a 16x16 array texture with 3 layers and a checkerboard pattern
var pixels: array[IMG_LAYERS, array[IMG_HEIGHT, array[IMG_WIDTH, uint32]]]
var even_odd = 0u32
for layer in 0..<IMG_LAYERS:
    for y in 0..<IMG_HEIGHT:
        for x in 0..<IMG_WIDTH:
            pixels[layer][y][x] = if (even_odd and 1) == 0: 0xFF000000u32 else:
                case layer
                    of 0: 0xFF0000FFu32
                    of 1: 0xFF00FF00u32
                    else: 0xFFFF0000u32
            even_odd += 1
        even_odd += 1
let img = sg.make_image(image_desc(
    type: IMAGETYPE_ARRAY,
    width: IMG_WIDTH,
    height: IMG_HEIGHT,
    slices: IMG_LAYERS,
    pixel_format: PIXELFORMAT_RGBA8,
    min_filter: FILTER_LINEAR,
    mag_filter: FILTER_LINEAR,
    content: image_content(
        subimage: %[
            subimage_content(size: sizeof(pixels).cint, content: addr(pixels))
        ]
    )
))

# a cube vertex buffers
var vertices = [
    # pos                  uvs
    -1.0f, -1.0f, -1.0f,    0.0f, 0.0f,
     1.0f, -1.0f, -1.0f,    1.0f, 0.0f,
     1.0f,  1.0f, -1.0f,    1.0f, 1.0f,
    -1.0f,  1.0f, -1.0f,    0.0f, 1.0f,

    -1.0f, -1.0f,  1.0f,    0.0f, 0.0f, 
     1.0f, -1.0f,  1.0f,    1.0f, 0.0f,
     1.0f,  1.0f,  1.0f,    1.0f, 1.0f,
    -1.0f,  1.0f,  1.0f,    0.0f, 1.0f,

    -1.0f, -1.0f, -1.0f,    0.0f, 0.0f,
    -1.0f,  1.0f, -1.0f,    1.0f, 0.0f,
    -1.0f,  1.0f,  1.0f,    1.0f, 1.0f,
    -1.0f, -1.0f,  1.0f,    0.0f, 1.0f,

     1.0f, -1.0f, -1.0f,    0.0f, 0.0f,
     1.0f,  1.0f, -1.0f,    1.0f, 0.0f,
     1.0f,  1.0f,  1.0f,    1.0f, 1.0f,
     1.0f, -1.0f,  1.0f,    0.0f, 1.0f,

    -1.0f, -1.0f, -1.0f,    0.0f, 0.0f,
    -1.0f, -1.0f,  1.0f,    1.0f, 0.0f,
     1.0f, -1.0f,  1.0f,    1.0f, 1.0f,
     1.0f, -1.0f, -1.0f,    0.0f, 1.0f,

    -1.0f,  1.0f, -1.0f,    0.0f, 0.0f,
    -1.0f,  1.0f,  1.0f,    1.0f, 0.0f,
     1.0f,  1.0f,  1.0f,    1.0f, 1.0f,
     1.0f,  1.0f, -1.0f,    0.0f, 1.0f
]
let vbuf = sg.make_buffer(buffer_desc(
    size: sizeof(vertices).cint,
    content: addr(vertices)
))

# an index buffer for the cube
var indices = [
    0u16, 1, 2,  0, 2, 3,
    6, 5, 4,  7, 6, 4,
    8, 9, 10,  8, 10, 11,
    14, 13, 12,  15, 14, 12,
    16, 17, 18,  16, 18, 19,
    22, 21, 20,  23, 22, 20
]
let ibuf = sg.make_buffer(buffer_desc(
    type: BUFFERTYPE_INDEXBUFFER,
    size: sizeof(indices).cint,
    content: addr(indices)
))

# a shader to sample from the array texture
let shd = sg.make_shader(shader_desc(
    vs: stage_desc(
        uniform_blocks: %[
            uniform_block_desc(
                size: sizeof(params_t).cint,
                uniforms: %[
                    uniform_desc(name: "mvp", type: UNIFORMTYPE_MAT4),
                    uniform_desc(name: "offset0", type: UNIFORMTYPE_FLOAT2),
                    uniform_desc(name: "offset1", type: UNIFORMTYPE_FLOAT2),
                    uniform_desc(name: "offset2", type: UNIFORMTYPE_FLOAT2)
                ]
            )
        ],
        source: """
            #version 330
            uniform mat4 mvp;
            uniform vec2 offset0;
            uniform vec2 offset1;
            uniform vec2 offset2;
            in vec4 position;
            in vec2 texcoord0;
            out vec3 uv0;
            out vec3 uv1;
            out vec3 uv2;
            void main() {
              gl_Position = mvp * position;
              uv0 = vec3(texcoord0 + offset0, 0.0);
              uv1 = vec3(texcoord0 + offset1, 1.0);
              uv2 = vec3(texcoord0 + offset2, 2.0);
            }
            """
    ),
    fs: stage_desc(
        images: %[
            shader_image_desc(name: "tex", type: IMAGETYPE_ARRAY)
        ],
        source: """
            #version 330
            uniform sampler2DArray tex;
            in vec3 uv0;
            in vec3 uv1;
            in vec3 uv2;
            out vec4 frag_color;
            void main() {
              vec4 c0 = texture(tex, uv0);
              vec4 c1 = texture(tex, uv1);
              vec4 c2 = texture(tex, uv2);
              frag_color = vec4(c0.xyz + c1.xyz + c2.xyz, 1.0);
            }
            """
    )
))

# a pipeline state object
let pip = sg.make_pipeline(pipeline_desc(
    layout: layout_desc(
        attrs: %[
            attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3),
            attr_desc(name: "texcoord0", format: VERTEXFORMAT_FLOAT2)
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

# a draw state with the resource bindings
let draw_state = sg.draw_state(
    pipeline: pip,
    vertex_buffers: %[ vbuf ],
    index_buffer: ibuf,
    fs_images: %[ img ]
)

# a pass action to clear to black
let pass_action = sg.pass_action(
    colors: %[
        color_attachment_action(action: ACTION_CLEAR, val: [0.0f, 0.0f, 0.0f, 1.0f])
    ]
)

# a view-projection matrix
const proj = perspective(radians(60.0f), WIDTH.float32/HEIGHT.float32, 0.01f, 10.0f)
const view = lookAt(vec3(0.0f, 1.5f, 6.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f))
const view_proj = proj * view
var params: params_t
var rx, ry =  0.0f
var frame_index = 0
while glfw.WindowShouldClose(win) == 0:
    # build a model-view-projection matrix
    rx += radians(0.25f); ry += radians(0.2f)
    let rxm = rotate(mat4(1.0f), rx, 1.0f, 0.0f, 0.0f)
    let rym = rotate(mat4(1.0f), ry, 0.0f, 1.0f, 0.0f)
    let model = rxm * rym
    let mvp = view_proj * model

    # setup the uniform block content
    params.mvp = mvp
    let offset = frame_index.float32 * 0.0001f
    params.offset0 = vec2(-offset, offset)
    params.offset1 = vec2(offset, -offset)
    params.offset2 = vec2(0.0f, 0.0f)
    frame_index += 1

    # ...and draw
    var w, h: cint
    glfw.GetFramebufferSize(win, addr(w), addr(h))
    sg.begin_default_pass(pass_action, w, h)
    sg.apply_draw_state(draw_state)
    sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(params), sizeof(params))
    sg.draw(0, 36, 1)
    sg.end_pass()
    sg.commit()
    glfw.SwapBuffers(win)
    glfw.PollEvents()

sg.shutdown()
glfw.Terminate()
