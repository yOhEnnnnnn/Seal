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

LuckyChain = Object:extend()
LuckyChain:implement(GameObject)

function LuckyChain:init(args)
  self:init_game_object(args)
  self.time = 0
  self.duration = 0.16
end

function LuckyChain:update(dt)
  self.time = self.time + dt
  if self.time >= self.duration then self.dead = true end
end

function LuckyChain:draw()
  graphics.line(self.x, self.y, self.target_x, self.target_y,
    {138 / 255, 59 / 255, 236 / 255, 1}, 2)
end

LuckyEmber = Object:extend()
LuckyEmber:implement(GameObject)

function LuckyEmber:init(args)
  self:init_game_object(args)
  self.time, self.tick = 0, 0
  self.duration = Data.upgrades.luck_area_duration
  self.size = Data.upgrades.luck_area_size
  self.can_damage = true
end

function LuckyEmber:update(dt, enemies)
  self.time = self.time + dt
  self.tick = self.tick - dt
  if self.tick <= 0 then
    self.tick = 0.4
    for _, enemy in ipairs(enemies) do
      if not enemy.dead and math.abs(enemy.x - self.x) <= self.size / 2 and
        math.abs(enemy.y - self.y) <= self.size / 2 then
        enemy:hit(self.damage, self.source)
      end
    end
  end
  if self.time >= self.duration then self.dead = true end
end

function LuckyEmber:draw()
  graphics.rectangle(self.x, self.y, self.size, self.size, 2, 2,
    {213 / 255, 14 / 255, 61 / 255, 0.28})
end

LuckyFrost = Object:extend()
LuckyFrost:implement(GameObject)

function LuckyFrost:init(args)
  self:init_game_object(args)
  self.time = 0
  self.duration = Data.upgrades.luck_area_duration
  self.radius = Data.upgrades.luck_area_size / 2
end

function LuckyFrost:update(dt, enemies)
  self.time = self.time + dt
  for _, enemy in ipairs(enemies) do
    local dx, dy = enemy.x - self.x, enemy.y - self.y
    if not enemy.dead and dx * dx + dy * dy <= self.radius ^ 2 then
      enemy:slow(Data.upgrades.luck_frost_slow, 0.12)
    end
  end
  if self.time >= self.duration then self.dead = true end
end

function LuckyFrost:draw()
  graphics.circle(self.x, self.y, self.radius,
    {0, 240 / 255, 1, 0.22})
end

SceneTransition = Object:extend()
SceneTransition:implement(GameObject)

function SceneTransition:init(args)
  self:init_game_object(args)
  self.time = 0
  self.radius = 0
  self.text_scale = 0
  self.max_radius = 1.2 * gw
  self.delay = 0.25
  self.expand_duration = 0.6
  self.hold_duration = 0.3
  self.shrink_duration = 0.6
  self.switched = false
end

function SceneTransition:update(dt)
  self.time = self.time + dt
  local cover_time = self.delay + self.expand_duration
  local reveal_time = cover_time + self.hold_duration
  local end_time = reveal_time + self.shrink_duration

  if self.time < self.delay then
    self.radius = 0
  elseif self.time < cover_time then
    self.radius = self.max_radius *
      (self.time - self.delay) / self.expand_duration
  elseif self.time < reveal_time then
    self.radius = self.max_radius
  else
    self.x, self.y = aw / 2, ah / 2
    self.radius = self.max_radius * math.max(0,
      1 - (self.time - reveal_time) / self.shrink_duration)
  end

  if not self.switched and self.time >= cover_time then
    self.switched = true
    if self.transition_action then self.transition_action() end
  end

  local text_in_start = self.delay + 0.1
  if self.time >= text_in_start and self.time < text_in_start + 0.1 then
    self.text_scale = cubic_in_out((self.time - text_in_start) / 0.1)
  elseif self.time >= text_in_start and self.time < end_time - 0.05 then
    self.text_scale = 1
  elseif self.time >= end_time - 0.05 then
    self.text_scale = math.max(0, (end_time - self.time) / 0.05)
  end

  if self.time >= end_time then self.dead = true end
end

function SceneTransition:draw()
  graphics.circle(self.x, self.y, self.radius, self.color)
  if self.text_scale <= 0 then return end
  love.graphics.push("all")
  love.graphics.translate(gw / 2, gh / 2)
  love.graphics.scale(self.text_scale, self.text_scale)
  love.graphics.setFont(self.font)
  graphics.set_color(self.text_color)
  love.graphics.printf(self.text, -gw / 2,
    -self.font:getHeight() / 2, gw, "center")
  love.graphics.pop()
end
