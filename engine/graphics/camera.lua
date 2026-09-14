Camera = Object:extend()

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(maximum, value))
end

local function reset_spring(spring)
  spring.x = 0
  spring.v = 0
  spring.target_x = 0
end

function Camera:init(x, y, width, height)
  self.base_x = x or gw / 2
  self.base_y = y or gh / 2
  self.x, self.y = self.base_x, self.base_y
  self.width = width or gw
  self.height = height or gh
  self.r, self.sx, self.sy = 0, 1, 1
  self.spring_x = Spring()
  self.spring_y = Spring()
  self.offset_x, self.offset_y = 0, 0
end

function Camera:reset()
  reset_spring(self.spring_x)
  reset_spring(self.spring_y)
  self.offset_x, self.offset_y = 0, 0
  self.x, self.y = self.base_x, self.base_y
  self.r, self.sx, self.sy = 0, 1, 1
end

function Camera:update(dt)
  self.spring_x:update(dt)
  self.spring_y:update(dt)
  self.offset_x = clamp(self.spring_x.x, -8, 8)
  self.offset_y = clamp(self.spring_y.x, -8, 8)
  self.x = self.base_x + self.offset_x
  self.y = self.base_y + self.offset_y
end

function Camera:attach()
  love.graphics.push()
  love.graphics.translate(self.width / 2, self.height / 2)
  love.graphics.scale(self.sx, self.sy)
  love.graphics.rotate(self.r)
  love.graphics.translate(-self.x, -self.y)
end

function Camera:detach()
  love.graphics.pop()
end

function Camera:to_world(x, y)
  if not x or not y then return end

  local dx = (x - self.width / 2) / self.sx
  local dy = (y - self.height / 2) / self.sy
  local cosine, sine = math.cos(-self.r), math.sin(-self.r)
  local world_x = cosine * dx - sine * dy + self.x
  local world_y = sine * dx + cosine * dy + self.y
  return world_x, world_y
end

function Camera:spring_shake(intensity, angle, stiffness, damping)
  angle = angle or 0
  self.spring_x:pull(-intensity * math.cos(angle), stiffness, damping)
  self.spring_y:pull(-intensity * math.sin(angle), stiffness, damping)
end
