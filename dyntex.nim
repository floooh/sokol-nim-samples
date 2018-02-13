#  renders a cube with a dynamic texture updated by the CPU
#
import opengl
import glm
import random
import glfw3 as glfw
import sokol/gfx as sg

const DISPLAY_WIDTH = 640
const DISPLAY_HEIGHT = 480
const IMAGE_WIDTH = 64
const IMAGE_HEIGHT = 64
const LIVING = 0xFFFFFFFFu32
const DEAD = 0xFF000000u32

var pixels: array[IMAGE_HEIGHT, array[IMAGE_WIDTH, uint32]]

# a function to initialize a new game-of-life state
proc game_of_life_init() =
    for y in 0..<IMAGE_HEIGHT:
        for x in 0..<IMAGE_WIDTH:
            pixels[y][x] = if random(255)>230: LIVING else: DEAD

# ...and a function to update the game-of-life state
proc game_of_life_update(frame_index: int) =
    for y in 0..<IMAGE_HEIGHT:
        for x in 0..<IMAGE_WIDTH:
            var num_living_neighbours = 0
            for ny in -1..1:
                for nx in -1..1:
                    if nx == 0 and ny == 0:
                        continue
                    elif pixels[(y+ny)and(IMAGE_HEIGHT-1)][(x+nx)and(IMAGE_WIDTH-1)] == LIVING:
                        num_living_neighbours += 1
            # any living cell...
            if pixels[y][x] == LIVING:
                if num_living_neighbours < 2:
                    # ...with fewer then 2 living neighbours dies, as if caused by underpopulation
                    pixels[y][x] = DEAD
                elif num_living_neighbours > 3:
                    # ...with more then 3 living neihbours dies, as if caused by overpopulation
                    pixels[y][x] = DEAD
            elif num_living_neighbours == 3:
                # any dead cell with exactly 3 living neighbours becomes a live cell, as if by reproduction
                pixels[y][x] = LIVING
    # reset game of life after a couple of frame 
    if frame_index mod 240 == 0:
        game_of_life_init()

# initialize GLFW and sokol-gfx
if glfw.Init() != 1:
    quit(QUIT_FAILURE)
glfw.WindowHint(CONTEXT_VERSION_MAJOR, 3)
glfw.WindowHint(CONTEXT_VERSION_MINOR, 3)
glfw.WindowHint(OPENGL_PROFILE, OPENGL_CORE_PROFILE)
glfw.WindowHint(OPENGL_FORWARD_COMPAT, GL_TRUE.cint)
let win = glfw.CreateWindow(DISPLAY_WIDTH, DISPLAY_HEIGHT, "Instancing (sokol-nim)", nil, nil)
glfw.MakeContextCurrent(win)
sg.setup(sg.desc())

# an empty image with streaming usage hint
let img = sg.make_image(image_desc(
    width: IMAGE_WIDTH,
    height: IMAGE_HEIGHT,
    pixel_format: PIXELFORMAT_RGBA8,
    usage: USAGE_STREAM,
    min_filter: FILTER_LINEAR,
    mag_filter: FILTER_LINEAR,
    wrap_u: WRAP_CLAMP_TO_EDGE,
    wrap_v: WRAP_CLAMP_TO_EDGE
))

# a cube vertex buffer
var vertices = [
    # pos                   color                       uvs
    -1.0f, -1.0f, -1.0f,    1.0f, 0.0f, 0.0f, 1.0f,     0.0f, 0.0f,
     1.0f, -1.0f, -1.0f,    1.0f, 0.0f, 0.0f, 1.0f,     1.0f, 0.0f,
     1.0f,  1.0f, -1.0f,    1.0f, 0.0f, 0.0f, 1.0f,     1.0f, 1.0f,
    -1.0f,  1.0f, -1.0f,    1.0f, 0.0f, 0.0f, 1.0f,     0.0f, 1.0f,

    -1.0f, -1.0f,  1.0f,    0.0f, 1.0f, 0.0f, 1.0f,     0.0f, 0.0f, 
     1.0f, -1.0f,  1.0f,    0.0f, 1.0f, 0.0f, 1.0f,     1.0f, 0.0f,
     1.0f,  1.0f,  1.0f,    0.0f, 1.0f, 0.0f, 1.0f,     1.0f, 1.0f,
    -1.0f,  1.0f,  1.0f,    0.0f, 1.0f, 0.0f, 1.0f,     0.0f, 1.0f,

    -1.0f, -1.0f, -1.0f,    0.0f, 0.0f, 1.0f, 1.0f,     0.0f, 0.0f,
    -1.0f,  1.0f, -1.0f,    0.0f, 0.0f, 1.0f, 1.0f,     1.0f, 0.0f,
    -1.0f,  1.0f,  1.0f,    0.0f, 0.0f, 1.0f, 1.0f,     1.0f, 1.0f,
    -1.0f, -1.0f,  1.0f,    0.0f, 0.0f, 1.0f, 1.0f,     0.0f, 1.0f,

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
     1.0f,  1.0f, -1.0f,    1.0f, 0.0f, 0.5f, 1.0f,     0.0f, 1.0f    
]
let vbuf = sg.make_buffer(buffer_desc(
    size: sizeof(vertices).cint,
    content: addr(vertices)
))

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

# a uniform block with a model-view-projection matrix
type params_t = object
    mvp: Mat4f

# a shader to render the textured cube
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
            in vec4 color0;
            in vec2 texcoord0;
            out vec2 uv;
            out vec4 color;
            void main() {
              gl_Position = mvp * position;
              uv = texcoord0;
              color = color0;
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
              frag_color = texture(tex, uv) * color;
            }
            """
    )
))

# a pipeline state object for the textured cube
let pip = sg.make_pipeline(pipeline_desc(
    layout: layout_desc(
        attrs: %[
            attr_desc(name: "position", format: VERTEXFORMAT_FLOAT3),
            attr_desc(name: "color0", format: VERTEXFORMAT_FLOAT4),
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

# a default pass action (clear to grey)
let pass_action = sg.pass_action()

# a view-projection matrix
const proj = perspective(radians(45.0f), 640.0f/480.0f, 0.01f, 100.0f)
const view = lookAt(vec3(0.0f, 1.5f, 6.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 1.0f, 0.0f))
var params = params_t()
var rx, ry = 0.0f
var frame_index = 0

# initialize the game-of-life state
game_of_life_init()

# the draw loop
while glfw.WindowShouldClose(win) == 0:
    frame_index += 1
    # rotated model-view-proj matrix
    rx += 1.0f
    ry += 2.0f;
    let rxm = rotate(mat4f(1.0f), radians(rx), 1.0f, 0.0f, 0.0f)
    let rym = rotate(mat4f(1.0f), radians(ry), 0.0f, 1.0f, 0.0f)
    let model = rxm * rym
    let mvp = proj * view * model
    params.mvp = mvp
    
    # update game-of-life state
    game_of_life_update(frame_index)

    # update the dynamic image
    sg.update_image(img, image_content(
        subimage: %[
            subimage_content(content: addr(pixels), size: sizeof(pixels).cint)
        ]
    ))

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