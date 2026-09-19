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

LuckyOrb = Object:extend()
LuckyOrb:implement(GameObject)

function LuckyOrb:init(args)
  self:init_game_object(args)
  self.radius = Data.upgrades.luck_orb_radius
  self.speed = Data.upgrades.luck_orb_speed
  self.vx = math.cos(self.r) * self.speed
  self.vy = math.sin(self.r) * self.speed
  self.rotation = 0
  self.rotation_speed = (love.math.random() < 0.5 and -1 or 1) *
    (0.7 + love.math.random() * 0.5)
  self.touching_enemies = {}
end

function LuckyOrb:update(dt, enemies)
  self.rotation = self.rotation + self.rotation_speed * dt
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  if self.x <= self.radius or self.x >= aw - self.radius then
    self.x = math.max(self.radius, math.min(aw - self.radius, self.x))
    self.vx = self.x == self.radius and math.abs(self.vx) or -math.abs(self.vx)
  end
  if self.y <= self.radius or self.y >= ah - self.radius then
    self.y = math.max(self.radius, math.min(ah - self.radius, self.y))
    self.vy = self.y == self.radius and math.abs(self.vy) or -math.abs(self.vy)
  end

  local touching_enemies = {}
  for _, enemy in ipairs(enemies) do
    if not enemy.dead and Collision.sweep_circle(
      self.x, self.y, self.x, self.y, self.radius, enemy) < math.huge then
      touching_enemies[enemy] = true
      if not self.touching_enemies[enemy] then
        local luck_bonus = math.floor(
          (self.luck_state.level - 1) /
            Data.upgrades.luck_damage_levels_per_point)
        enemy:hit(self.hit_power + luck_bonus, self.source)
      end
    end
  end
  self.touching_enemies = touching_enemies
end

function LuckyOrb:draw()
  local blue = {0, 240 / 255, 1, 1}
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.rotation)
  graphics.circle(0, 0, self.radius, {0, 240 / 255, 1, 0.08})
  for index = 0, 3 do
    local center = index * math.pi / 2 + math.pi / 4
    graphics.arc("open", 0, 0, self.radius,
      center - math.pi / 8, center + math.pi / 8, blue, 2)
  end
  love.graphics.pop()
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
