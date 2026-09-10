HitParticle = Object:extend()
HitParticle:implement(GameObject)

local function cubic_in_out(t)
  t = t * 2
  if t < 1 then return 0.5 * t * t * t end
  t = t - 2
  return 0.5 * (t * t * t + 2)
end

function HitParticle:init(args)
  self:init_game_object(args)
  self.speed = self.speed or 50 + love.math.random() * 100
  self.r = args.r or love.math.random() * 2 * math.pi
  self.duration = self.duration or 0.2 + love.math.random() * 0.4
  self.width = self.width or 3.5 + love.math.random() * 3.5
  self.height = self.height or self.width / 2
  self.start_speed = self.speed
  self.start_width = self.width
  self.start_height = self.height
  self.time = 0
end

function HitParticle:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  local progress = cubic_in_out(self.time / self.duration)
  self.width = self.start_width + (2 - self.start_width) * progress
  self.height = self.start_height + (2 - self.start_height) * progress
  self.speed = self.start_speed * (1 - progress)
  self.x = self.x + self.speed * math.cos(self.r) * dt
  self.y = self.y + self.speed * math.sin(self.r) * dt
  if self.time == self.duration then self.dead = true end
end

function HitParticle:draw()
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.r)
  graphics.rectangle(0, 0, self.width, self.height, 2, 2, self.color)
  love.graphics.pop()
end

HitCircle = Object:extend()
HitCircle:implement(GameObject)

function HitCircle:init(args)
  self:init_game_object(args)
  self.radius = self.radius or 12
  self.start_radius = self.radius
  self.duration = self.duration or 0.05
  self.time = 0
end

function HitCircle:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  self.radius = self.start_radius * (1 - cubic_in_out(self.time / self.duration))
  if self.time >= self.duration / 2 then self.color = self.target_color end
  if self.time == self.duration then self.dead = true end
end

function HitCircle:draw()
  graphics.circle(self.x, self.y, self.radius, self.color)
end

AreaPulse = Object:extend()
AreaPulse:implement(GameObject)

function AreaPulse:init(args)
  self:init_game_object(args)
  self.radius = self.radius or 48
  self.duration = self.duration or 0.2
  self.line_width = self.line_width or 2
  self.time = 0
end

function AreaPulse:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  if self.time == self.duration then self.dead = true end
end

function AreaPulse:draw()
  local progress = cubic_in_out(self.time / self.duration)
  graphics.circle(self.x, self.y, self.radius * progress,
    graphics.color_with_alpha(self.color, 1 - progress), self.line_width)
end

CoinParticle = Object:extend()
CoinParticle:implement(GameObject)

function CoinParticle:init(args)
  self:init_game_object(args)
  self.radius = self.radius or 2
  self.color = self.color or {250 / 255, 207 / 255, 0, 1}
  self.value = self.value or 1
  self.burst_duration = self.burst_duration or 0.18
  self.pick_radius = self.pick_radius or 6
  self.is_coin = true
  self.time = 0

  local r = love.math.random() * 2 * math.pi
  local speed = 35 + love.math.random() * 30
  self.vx = math.cos(r) * speed
  self.vy = math.sin(r) * speed
end

function CoinParticle:collect()
  if self.dead then return end
  self.dead = true
  if self.on_collect then self.on_collect(self.value) end
end

function CoinParticle:update(dt)
  self.time = self.time + dt
  if self.time <= self.burst_duration then
    local damping = math.max(0, 1 - 7 * dt)
    self.vx = self.vx * damping
    self.vy = self.vy * damping
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
  end
end

function CoinParticle:contains_point(x, y)
  local dx, dy = x - self.x, y - self.y
  return dx * dx + dy * dy <= self.pick_radius * self.pick_radius
end

function CoinParticle:draw()
  local pulse = 1 + 0.08 * math.sin(self.time * 24)
  graphics.circle(self.x, self.y, self.radius * pulse, self.color)
end

CoinPickupEffect = Object:extend()
CoinPickupEffect:implement(GameObject)

function CoinPickupEffect:init(args)
  self:init_game_object(args)
  self.color = self.color or {250 / 255, 207 / 255, 0, 1}
  self.duration = self.duration or 0.32
  self.radius = self.radius or 2
  self.rise_distance = self.rise_distance or 10
  self.start_y = self.y
  self.time = 0
end

function CoinPickupEffect:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  if self.time == self.duration then self.dead = true end
end

function CoinPickupEffect:draw()
  local progress = cubic_in_out(self.time / self.duration)
  local fade_progress = math.max(0, (progress - 0.65) / 0.35)
  local alpha = 1 - fade_progress
  local y = self.start_y - self.rise_distance * progress
  local turn = progress * 2 * math.pi
  local scale_x = 0.18 + 0.82 * math.abs(math.cos(turn))

  love.graphics.push("all")
  love.graphics.translate(self.x, y)
  love.graphics.scale(scale_x, 1)
  graphics.circle(0, 0, self.radius,
    graphics.color_with_alpha(self.color, alpha))
  graphics.circle(-0.6, -0.6, 0.55,
    graphics.color_with_alpha({1, 1, 1, 1}, alpha * 0.8))
  love.graphics.pop()
end
