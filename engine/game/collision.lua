Collision = {}

local function overlaps_axis(dx, dy, ax, ay, ac, as, aw, ah, bc, bs, bw, bh)
  local a_radius = aw * math.abs(ax * ac + ay * as) +
    ah * math.abs(-ax * as + ay * ac)
  local b_radius = bw * math.abs(ax * bc + ay * bs) +
    bh * math.abs(-ax * bs + ay * bc)
  return math.abs(dx * ax + dy * ay) <= a_radius + b_radius
end

function Collision.rectangles(a, aw, ah, b, bw, bh)
  local ac, as = math.cos(a.r or 0), math.sin(a.r or 0)
  local bc, bs = math.cos(b.r or 0), math.sin(b.r or 0)
  local dx, dy = b.x - a.x, b.y - a.y
  aw, ah, bw, bh = aw / 2, ah / 2, bw / 2, bh / 2
  return overlaps_axis(dx, dy, ac, as, ac, as, aw, ah, bc, bs, bw, bh) and
    overlaps_axis(dx, dy, -as, ac, ac, as, aw, ah, bc, bs, bw, bh) and
    overlaps_axis(dx, dy, bc, bs, ac, as, aw, ah, bc, bs, bw, bh) and
    overlaps_axis(dx, dy, -bs, bc, ac, as, aw, ah, bc, bs, bw, bh)
end

local function segment_circle(x, y, dx, dy, cx, cy, radius)
  x, y = x - cx, y - cy
  local c = x * x + y * y - radius * radius
  if c <= 0 then return 0 end
  local a = dx * dx + dy * dy
  if a == 0 then return math.huge end
  local b = x * dx + y * dy
  local discriminant = b * b - a * c
  if discriminant < 0 then return math.huge end
  local t = (-b - math.sqrt(discriminant)) / a
  return t >= 0 and t <= 1 and t or math.huge
end

local function slab(position, delta, extent)
  if delta == 0 then
    if math.abs(position) > extent then return math.huge, -math.huge end
    return -math.huge, math.huge
  end
  local a, b = (-extent - position) / delta, (extent - position) / delta
  return math.min(a, b), math.max(a, b)
end

local function segment_box(x, y, dx, dy, hw, hh)
  local x_enter, x_exit = slab(x, dx, hw)
  local y_enter, y_exit = slab(y, dy, hh)
  local enter = math.max(0, x_enter, y_enter)
  local leave = math.min(1, x_exit, y_exit)
  return enter <= leave and enter or math.huge
end

-- First contact along a segment, expressed as a fraction in [0, 1].
function Collision.sweep_circle(x, y, end_x, end_y, radius, object)
  local shape = object.shape or object
  local dx, dy = end_x - x, end_y - y
  if shape.type == "circle" or (not shape.type and shape.radius) then
    return segment_circle(x, y, dx, dy, object.x, object.y,
      radius + shape.radius)
  end

  local c, s = math.cos(object.r or 0), math.sin(object.r or 0)
  x, y = x - object.x, y - object.y
  x, y = c * x + s * y, -s * x + c * y
  dx, dy = c * dx + s * dy, -s * dx + c * dy
  local hw, hh = shape.width / 2, shape.height / 2
  -- Broad phase rejects distant objects before testing the rounded corners.
  if segment_box(x, y, dx, dy, hw + radius, hh + radius) == math.huge then
    return math.huge
  end
  -- A rectangle expanded by a circle has rounded, not square, corners.
  return math.min(
    segment_box(x, y, dx, dy, hw + radius, hh),
    segment_box(x, y, dx, dy, hw, hh + radius),
    segment_circle(x, y, dx, dy, -hw, -hh, radius),
    segment_circle(x, y, dx, dy, hw, -hh, radius),
    segment_circle(x, y, dx, dy, -hw, hh, radius),
    segment_circle(x, y, dx, dy, hw, hh, radius))
end
