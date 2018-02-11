# Package

version       = "0.1.0"
author        = "Andre Weissflog"
description   = "Example code for https://github.com/floooh/sokol-nim"
license       = "MIT"

bin = @["clear", "triangle", "cube", "texcube", "offscreen"

# Dependencies

requires "nim >= 0.17.2"
requires "https://github.com/floooh/sokol-nim.git"
requires "nimrod-glfw >= 3.2.0"
requires "opengl >= 1.1"
requires "glm"

