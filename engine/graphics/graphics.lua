graphics = {}

local function color_values(color)
  return
    color.r or color[1] or 1,
    color.g or color[2] or 1,
    color.b or color[3] or 1,
    color.a or color[4] or 1
end

local function set_style(color, line_width)
  if color then love.graphics.setColor(color_values(color)) end
  if line_width then love.graphics.setLineWidth(line_width) end
end

function graphics.set_color(color)
  love.graphics.setColor(color_values(color))
end

function graphics.color_with_alpha(color, alpha)
  return {
    color.r or color[1] or 1,
    color.g or color[2] or 1,
    color.b or color[3] or 1,
    alpha,
  }
end

function graphics.shape(shape, color, line_width, ...)
  local mode = color and not line_width and "fill" or "line"
  love.graphics.push("all")
  set_style(color, line_width)
  love.graphics[shape](mode, ...)
  love.graphics.pop()
end

function graphics.rectangle(x, y, width, height, rx, ry, color, line_width)
  graphics.shape("rectangle", color, line_width,
    x - width / 2, y - height / 2, width, height, rx, ry)
end

function graphics.rectangle2(x, y, width, height, rx, ry, color, line_width)
  graphics.shape("rectangle", color, line_width, x, y, width, height, rx, ry)
end

function graphics.polygon(vertices, color, line_width)
  graphics.shape("polygon", color, line_width, vertices)
end

function graphics.circle(x, y, radius, color, line_width)
  graphics.shape("circle", color, line_width, x, y, radius)
end

function graphics.arc(arc_type, x, y, radius, angle1, angle2, color, line_width)
  graphics.shape("arc", color, line_width,
    arc_type, x, y, radius, angle1, angle2)
end

function graphics.line(x1, y1, x2, y2, color, line_width)
  love.graphics.push("all")
  set_style(color, line_width)
  love.graphics.line(x1, y1, x2, y2)
  love.graphics.pop()
end

function graphics.polyline(color, line_width, ...)
  love.graphics.push("all")
  set_style(color, line_width)
  love.graphics.line(...)
  love.graphics.pop()
end
