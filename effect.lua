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
    graphics.color_with_alpha(Data.theme.colors.accent, 1 - progress), 2)
end

ShockwavePulse = Object:extend()
ShockwavePulse:implement(GameObject)

function ShockwavePulse:init(args)
  self:init_game_object(args)
  self.radius = self.radius or Data.player.shockwave_base_radius
  self.power = self.power or 0
  self.duration = Data.player.shockwave_duration
  self.time = 0
end

function ShockwavePulse:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  if self.time == self.duration then self.dead = true end
end

function ShockwavePulse:draw()
  local progress = self.time / self.duration
  local expansion = 1 - (1 - progress) ^ 3
  graphics.circle(self.x, self.y, self.radius * expansion,
    graphics.color_with_alpha(
      Data.theme.colors.accent, (1 - progress) * 0.9),
    2 + self.power * 1.5)
end

DetonationBurst = Object:extend()
DetonationBurst:implement(GameObject)

function DetonationBurst:init(args)
  self:init_game_object(args)
  self.radius = self.radius or Data.player.blast_base_radius
  self.duration = Data.player.blast_duration
  self.time = 0
end

function DetonationBurst:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  if self.time == self.duration then self.dead = true end
end

function DetonationBurst:get_expansion_state()
  local progress = self.time / self.duration
  local expansion = math.max(0, math.min(progress, 1))
  local main_radius = self.radius * cubic_in_out(expansion)
  local trail_progress = math.max(0, math.min(
    (expansion - Data.player.blast_trail_delay) /
      (1 - Data.player.blast_trail_delay), 1))
  local trail_radius = self.radius * cubic_in_out(trail_progress)
  return main_radius, trail_radius, expansion
end

function DetonationBurst:draw_center_flash(expansion)
  local progress = math.min(
    expansion / Data.player.blast_flash_duration, 1)
  if progress == 1 then return end
  graphics.circle(self.x, self.y, 2 + 3 * progress,
    {1, 1, 1, 1 - progress})
end

function DetonationBurst:draw()
  local main_radius, trail_radius, expansion = self:get_expansion_state()
  local appear = math.min(expansion / 0.08, 1)
  local fade = 1 - math.max(0, (expansion - 0.72) / 0.28)
  graphics.circle(self.x, self.y, trail_radius,
    graphics.color_with_alpha(
      Data.theme.colors.accent, appear * fade * 0.5), 2)
  graphics.circle(self.x, self.y, main_radius,
    graphics.color_with_alpha(
      Data.theme.colors.foreground, appear * fade), 2.5)
  self:draw_center_flash(expansion)
end
