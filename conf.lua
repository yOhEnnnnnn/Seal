local display = require("data.display")

function love.conf(t)
  t.version = "11.3"
  t.identity = "star"
  t.window.title = "STAR"
  t.window.width = display.window_width
  t.window.height = display.window_height
  t.window.resizable = true
  t.window.minwidth = display.width
  t.window.minheight = display.height
  t.window.vsync = 1
  t.window.msaa = 0
  t.window.usedpiscale = false
end
