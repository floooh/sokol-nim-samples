# tests different mipmap- and anisotropic-filtering
#
import opengl
import glfw3 as glfw
import glm
import sokol/gfx as sg

const
    WIDTH = 800
    HEIGHT = 600

# room for a 256*256 texture with mipmaps
var pixels: array[(256*256*4) div 3, uint32]

let mip_colors = [
    0xFF0000FFu32,  # red
    0xFF00FF00u32,  # green
    0xFFFF0000u32,  # blue
    0xFFFF00FFu32,  # magenta
    0xFFFFFF00u32,  # cyan
    0xFF00FFFFu32,  # yellow
    0xFFFF00A0u32,  # violet
    0xFFFFA0FFu32,  # orange
    0xFFA000FFu32,  # purple
]

# initialize GLFW and sokol-gfx
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
let win = glfw.CreateWindow(WIDTH, HEIGHT, "Multiple Rendertarget (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
sg.setup(sg.desc())

# a plane vertex buffer
var vertices = [
    # pos             uv
    -1.0f, -1.0f, 0.0f,  0.0f, 0.0f,
    +1.0f, -1.0f, 0.0f,  1.0f, 0.0f,
    -1.0f, +1.0f, 0.0f,  0.0f, 1.0f,
    +1.0f, +1.0f, 0.0f,  1.0f, 1.0f,
]
let vbuf = sg.make_buffer(buffer_desc(
    size: sizeof(vertices).cint,
    content: addr(vertices)
))

# fill the image content with differently colored checkerboard pattern per mipmap
var img_content = sg.image_content()
var pixel_index = 0
var even_odd = false
for mip_index in 0..8:
    let dim = 1 shl (8 - mip_index)
    img_content.subimage[mip_index].content = addr(pixels[pixel_index])
    img_content.subimage[mip_index].size = (dim * dim * 4).cint
    for y in 0..<dim:
        for x in 0..<dim:
            pixels[pixel_index] = if even_odd: mip_colors[mip_index] else: 0xFF000000u32
            even_odd = not even_odd
            pixel_index += 1
        even_odd = not even_odd

# setup 12 images with different mipmap filters, min/max lod, and anisotropy levels
var img: array[12, sg.image]

var img_desc = sg.image_desc(
    width: 256,
    height: 256,
    num_mipmaps: 9,
    pixel_format: PIXELFORMAT_RGBA8,
    mag_filter: FILTER_LINEAR,
    content: img_content
)
let min_filter = [
    FILTER_NEAREST_MIPMAP_NEAREST,
    FILTER_LINEAR_MIPMAP_NEAREST,
    FILTER_NEAREST_MIPMAP_LINEAR,
    FILTER_LINEAR_MIPMAP_LINEAR
]
for i in 0..3:
    img_desc.min_filter = min_filter[i]
    img[i] = sg.make_image(img_desc)

img_desc.min_lod = 2.0f
img_desc.max_lod = 4.0f
for i in 4..7:
    img_desc.min_filter = min_filter[i-4]
    img[i] = sg.make_image(img_desc)

img_desc.min_lod = 0.0f
img_desc.max_lod = 0.0f
for i in 8..11:
    img_desc.max_anisotropy = (1 shl (i-7)).uint32
    img[i] = sg.make_image(img_desc)

# a uniform block struct with model-view-projection matrix
type params_t = object
    mvp: Mat4f

# a shader
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
            in vec4 position;
            in vec2 texcoord0;
            out vec2 uv;
            void main() {
              gl_Position = mvp * position;
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
            in vec2 uv;
            out vec4 frag_color;
            void main() {
              frag_color = texture(tex, uv);
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
    primitive_type: PRIMITIVETYPE_TRIANGLE_STRIP,
))

# view-projection matrix and frame variables
const proj = perspective(radians(90.0f), WIDTH.float32/HEIGHT.float32, 0.01f, 10.0f)
const view = lookAt(vec3(0.0f, 0.0f, 5.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f))
const view_proj = proj * view
var params: params_t
var r = 0.0f

# the draw loop
while glfw.WindowShouldClose(win) == 0:
    r += radians(0.1f)
    var rm = rotate(mat4(1.0f), r, 1.0f, 0.0f, 0.0f)
    var w, h: cint
    glfw.GetFramebufferSize(win, addr(w), addr(h))
    sg.begin_default_pass(sg.pass_action(), w, h)
    for i in 0..<12:
        let x = ((i and 3).float32 - 1.5f) * 2.0f
        let y = ((i div 4).float32 - 1.0f) * -2.0f
        let model = translate(mat4(1.0f), x, y, 0.0f) * rm
        sg.apply_draw_state(sg.draw_state(
            pipeline: pip,
            vertex_buffers: %[ vbuf ],
            fs_images: %[ img[i] ]
        ))
        params.mvp = view_proj * model
        sg.apply_uniform_block(SHADERSTAGE_VS, 0, addr(params), sizeof(params).cint)
        sg.draw(0, 4, 1)
    sg.end_pass()
    sg.commit()
    glfw.SwapBuffers(win)
    glfw.PollEvents()

sg.commit()
glfw.Terminate()


