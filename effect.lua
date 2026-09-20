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

RevivePulse = Object:extend()
RevivePulse:implement(GameObject)

function RevivePulse:init(args)
  self:init_game_object(args)
  self.time = 0
  self.duration = 0.45
end

function RevivePulse:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  if self.time == self.duration then self.dead = true end
end

function RevivePulse:draw()
  local progress = self.time / self.duration
  local radius = Data.rules.revive_clear_radius * progress
  graphics.circle(self.x, self.y, radius,
    {1, 1, 1, (1 - progress) * 0.16})
  graphics.circle(self.x, self.y, radius,
    {0, 240 / 255, 1, 1 - progress}, 2)
end

ConvergenceBurst = Object:extend()
ConvergenceBurst:implement(GameObject)

function ConvergenceBurst:init(args)
  self:init_game_object(args)
  self.origins = self.origins or {}
  self.radius = self.radius or Data.player.convergence_base_radius
  self.duration = Data.player.convergence_duration
  self.time = 0
end

function ConvergenceBurst:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  if self.time == self.duration then self.dead = true end
end

function ConvergenceBurst:draw()
  local progress = self.time / self.duration
  local gather = math.min(progress * 2.4, 1)
  local eased = cubic_in_out(gather)
  local color = {0, 240 / 255, 1, 1 - gather * 0.65}
  for _, origin in ipairs(self.origins) do
    local start_x = origin.x + (self.x - origin.x) * eased
    local start_y = origin.y + (self.y - origin.y) * eased
    graphics.line(start_x, start_y, self.x, self.y, color, 1.5)
    graphics.rectangle(start_x, start_y, 3, 3, nil, nil, color)
  end

  local blast = math.max(0, (progress - 0.32) / 0.68)
  if blast > 0 then
    local blast_radius = self.radius * cubic_in_out(blast)
    graphics.circle(self.x, self.y, blast_radius,
      {0, 240 / 255, 1, (1 - blast) * 0.14})
    graphics.circle(self.x, self.y, blast_radius,
      {1, 1, 1, 1 - blast}, 2)
  end
end
