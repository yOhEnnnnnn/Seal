Physics = Object:extend()

local function get_shape(object)
  if object.shape then
    if object.shape.type == "circle" then
      return "circle", object.shape.radius
    elseif object.shape.type == "rectangle" then
      return "rectangle", object.shape.width, object.shape.height
    end
  end

  if object.radius then
    return "circle", object.radius
  elseif object.width and object.height then
    return "rectangle", object.width, object.height
  end
end

local function circle_rectangle_collision(circle, radius, rectangle, width, height)
  local half_width = width / 2
  local half_height = height / 2
  local dx = circle.x - rectangle.x
  local dy = circle.y - rectangle.y
  local cosine = math.cos(rectangle.r or 0)
  local sine = math.sin(rectangle.r or 0)
  local local_x = cosine * dx + sine * dy
  local local_y = -sine * dx + cosine * dy
  local closest_x = math.max(-half_width, math.min(local_x, half_width))
  local closest_y = math.max(-half_height, math.min(local_y, half_height))
  dx = local_x - closest_x
  dy = local_y - closest_y

  return dx * dx + dy * dy <= radius * radius
end

function Physics:init_physics(args)
  args = args or {}
  self.vx = self.vx or args.vx or 0
  self.vy = self.vy or args.vy or 0
  self.ax = self.ax or args.ax or 0
  self.ay = self.ay or args.ay or 0
  self.max_speed = self.max_speed or args.max_speed
  self.linear_damping = self.linear_damping or args.linear_damping or 0
  return self
end

function Physics:update_physics(dt)
  self.vx = (self.vx or 0) + (self.ax or 0) * dt
  self.vy = (self.vy or 0) + (self.ay or 0) * dt

  local linear_damping = self.linear_damping or 0
  if linear_damping > 0 then
    local damping = math.max(0, 1 - linear_damping * dt)
    self.vx = self.vx * damping
    self.vy = self.vy * damping
  end

  if self.max_speed then
    local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
    if speed > self.max_speed and speed > 0 then
      self.vx = self.vx / speed * self.max_speed
      self.vy = self.vy / speed * self.max_speed
    end
  end

  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  return self
end

function Physics:set_as_circle(radius, body_type, tag)
  self.radius = radius
  self.body_type = body_type or "dynamic"
  self.tag = tag
  self.shape = {
    type = "circle",
    radius = radius,
  }
  return self
end

function Physics:set_as_rectangle(width, height, body_type, tag)
  self.width = width
  self.height = height
  self.body_type = body_type or "dynamic"
  self.tag = tag
  self.shape = {
    type = "rectangle",
    width = width,
    height = height,
  }
  return self
end

function Physics:set_velocity(vx, vy)
  self.vx = vx
  self.vy = vy
  return self
end

function Physics:stop()
  return self:set_velocity(0, 0)
end

function Physics:is_colliding_with_object(object)
  local self_type, self_a, self_b = get_shape(self)
  local other_type, other_a, other_b = get_shape(object)

  if self_type == "circle" and other_type == "circle" then
    local dx = object.x - self.x
    local dy = object.y - self.y
    local radius = self_a + other_a
    return dx * dx + dy * dy <= radius * radius
  elseif self_type == "rectangle" and other_type == "rectangle" then
    return Collision.rectangles(self, self_a, self_b, object, other_a, other_b)
  elseif self_type == "circle" and other_type == "rectangle" then
    return circle_rectangle_collision(self, self_a, object, other_a, other_b)
  elseif self_type == "rectangle" and other_type == "circle" then
    return circle_rectangle_collision(object, other_a, self, self_a, self_b)
  end

  return false
end
