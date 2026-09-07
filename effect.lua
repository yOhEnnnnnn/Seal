LightningArc = Object:extend()
LightningArc:implement(GameObject)

function LightningArc:init(args)
  self:init_game_object(args)
  self.time = 0
  self.duration = self.duration or 0.1
  self.width = 3
  self.color = self.color or {1 / 255, 155 / 255, 214 / 255, 1}
  self:generate()
  self.particles = {}
  for _ = 1, 2 do
    self.particles[#self.particles + 1] = HitParticle{x = self.x, y = self.y, color = self.color}
  end
  self.particles[#self.particles + 1] = HitParticle{x = self.target_x, y = self.target_y, color = self.color}
end

-- Ported from SNKRX LightningLine (objects.lua); see licenses/SNKRX-LICENSE.txt.
function LightningArc:generate()
  local lines = {{x1 = self.x, y1 = self.y, x2 = self.target_x, y2 = self.target_y}}
  local offset = self.max_offset or 8
  for _ = 1, self.generations or 3 do
    for i = #lines, 1, -1 do
      local line = table.remove(lines, i)
      local dx, dy = line.x2 - line.x1, line.y2 - line.y1
      local length = math.sqrt(dx * dx + dy * dy)
      local nx, ny = 0, 0
      if length > 0 then nx, ny = -dy / length, dx / length end
      local x = (line.x1 + line.x2) / 2 + nx * (love.math.random() * 2 - 1) * offset
      local y = (line.y1 + line.y2) / 2 + ny * (love.math.random() * 2 - 1) * offset
      lines[#lines + 1] = {x1 = line.x1, y1 = line.y1, x2 = x, y2 = y}
      lines[#lines + 1] = {x1 = x, y1 = y, x2 = line.x2, y2 = line.y2}
    end
    offset = offset / 2
  end
  self.points = {}
  while #lines > 0 do
    local nearest_distance, nearest_index = math.huge, 1
    for i, line in ipairs(lines) do
      local distance = (line.x1 - self.x) ^ 2 + (line.y1 - self.y) ^ 2
      if distance < nearest_distance then nearest_distance, nearest_index = distance, i end
    end
    local line = table.remove(lines, nearest_index)
    self.points[#self.points + 1] = line.x1
    self.points[#self.points + 1] = line.y1
  end
end

function LightningArc:update(dt)
  self.time = self.time + dt
  self.width = 3 - 2 * math.min(self.time / self.duration, 1)
  for i = #self.particles, 1, -1 do
    self.particles[i]:update(dt)
    if self.particles[i].dead then table.remove(self.particles, i) end
  end
  if self.time >= self.duration and #self.particles == 0 then self.dead = true end
end

function LightningArc:draw()
  if self.time < self.duration then
    graphics.polyline(self.color, self.width, unpack(self.points))
    local foreground = {218 / 255, 218 / 255, 218 / 255, 1}
    graphics.circle(self.x, self.y, 6, foreground)
    graphics.circle(self.target_x, self.target_y, 6, foreground)
  end
  for _, particle in ipairs(self.particles) do particle:draw() end
end

HitParticle = Object:extend()
HitParticle:implement(GameObject)

local function cubic_in_out(t)
  t = t * 2
  if t < 1 then return 0.5 * t * t * t end
  t = t - 2
  return 0.5 * (t * t * t + 2)
end

local function remap(value, in_min, in_max, out_min, out_max)
  local t = (value - in_min) / (in_max - in_min)
  t = math.max(0, math.min(1, t))
  return out_min + (out_max - out_min) * t
end

local function draw_seal_area_frame(x, y, size, color, fill_color)
  local half = size / 2
  local corner = size * 0.16
  local x1, y1 = x - half, y - half
  local x2, y2 = x + half, y + half
  local line_width = remap(size, 64, 160, 2, 3)

  graphics.rectangle(x, y, size, size, nil, nil, fill_color)
  graphics.polyline(color, line_width, x1, y1 + corner, x1, y1, x1 + corner, y1)
  graphics.polyline(color, line_width, x2 - corner, y1, x2, y1, x2, y1 + corner)
  graphics.polyline(color, line_width, x2, y2 - corner, x2, y2, x2 - corner, y2)
  graphics.polyline(color, line_width, x1 + corner, y2, x1, y2, x1, y2 - corner)
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

SlowParticle = Object:extend()
SlowParticle:implement(GameObject)

function SlowParticle:init(args)
  self:init_game_object(args)
  self.vx = self.vx or 0
  self.vy = self.vy or 0
  self.size = self.size or love.math.random(1, 2)
  self.duration = self.duration or 0.28
  self.time = 0
end

function SlowParticle:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  self.x = self.x + self.vx * dt
  self.y = self.y + self.vy * dt
  if self.time == self.duration then self.dead = true end
end

function SlowParticle:draw()
  local alpha = 1 - self.time / self.duration
  graphics.rectangle(self.x, self.y, self.size, self.size,
    nil, nil, graphics.color_with_alpha(self.color, alpha))
end

FrostCircleArea = Object:extend()
FrostCircleArea:implement(GameObject)

function FrostCircleArea:init(args)
  self:init_game_object(args)
  self.radius = self.radius or 64
  self.duration = self.duration or 4.0
  self.damage = self.damage or 5
  self.slow_multiplier = self.slow_multiplier or 0.4
  self.tick_interval = self.tick_interval or 0.1
  self.slow_duration = self.tick_interval * 2
  self.fill_alpha = self.fill_alpha or 0.06
  self.entry_blink_duration = 0.16
  self.exit_blink_duration = 0.32
  self.blink_interval = 0.08
  self.arc_span = math.pi / 5
  self.r = love.math.random() * 2 * math.pi
  self.rotation_speed = (love.math.random() - 0.5) * math.pi / 2
  self.hit = {}
  self.time = 0
  self.tick_time = 0
end

function FrostCircleArea:contains(enemy)
  local dx, dy = enemy.x - self.x, enemy.y - self.y
  return dx * dx + dy * dy <= self.radius * self.radius
end

function FrostCircleArea:affect_enemies(enemies)
  for _, enemy in ipairs(enemies or {}) do
    if not enemy.dead and self:contains(enemy) then
      if not self.hit[enemy] then
        enemy:hit(self.damage)
        self.hit[enemy] = true
      end
      enemy:apply_slow(self.slow_multiplier, self.slow_duration)
    end
  end
end

function FrostCircleArea:update(dt, enemies)
  self.time = math.min(self.time + dt, self.duration)
  self.tick_time = self.tick_time - dt
  self.r = self.r + self.rotation_speed * dt

  if self.tick_time <= 0 then
    self.tick_time = self.tick_interval
    self:affect_enemies(enemies)
  end

  if self.time == self.duration then self.dead = true end
end

function FrostCircleArea:draw()
  local remaining = self.duration - self.time
  local entry_blinking = self.time < self.entry_blink_duration
  local exit_blinking = remaining <= self.exit_blink_duration

  if entry_blinking then
    if math.floor(self.time / self.blink_interval) % 2 == 1 then return end
  elseif exit_blinking then
    local elapsed = self.exit_blink_duration - remaining
    if math.floor(elapsed / self.blink_interval) % 2 == 1 then return end
  end

  local outline = entry_blinking and {1, 1, 1, 1} or self.color
  graphics.circle(self.x, self.y, self.radius,
    graphics.color_with_alpha(self.color, self.fill_alpha))
  for index = 1, 4 do
    local center = self.r + (index - 1) * math.pi / 2 + math.pi / 4
    graphics.arc("open", self.x, self.y, self.radius,
      center - self.arc_span / 2, center + self.arc_span / 2,
      outline, 2)
  end
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

BlockBurstEffect = Object:extend()
BlockBurstEffect:implement(GameObject)

function BlockBurstEffect:init(args)
  self:init_game_object(args)
  self.target_size = self.size or self.radius or 28
  self.rotation = self.rotation or love.math.random() * math.pi
  self.fill_alpha = self.fill_alpha or 0.08
  self.flash_duration = 0.12
  self.grow_duration = 0.08
  self.blink_interval = 0.06
  self.blink_count = 4
  self.duration = self.duration or self.flash_duration + self.blink_interval * self.blink_count
  self.size = 0
  self.time = 0
end

function BlockBurstEffect:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  self.size = self.target_size * cubic_in_out(math.min(self.time / self.grow_duration, 1))

  if self.time == self.duration then self.dead = true end
end

function BlockBurstEffect:draw()
  if self.time >= self.flash_duration then
    local blink_index = math.floor((self.time - self.flash_duration) / self.blink_interval)
    if blink_index % 2 == 1 then return end
  end

  local color = self.time < self.flash_duration and {1, 1, 1, 1} or self.color
  local fill_color = graphics.color_with_alpha(self.color, self.fill_alpha)

  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.rotation)
  draw_seal_area_frame(0, 0, self.size, color, fill_color)
  love.graphics.pop()
end

BurningSquareArea = Object:extend()
BurningSquareArea:implement(GameObject)

function BurningSquareArea:init(args)
  self:init_game_object(args)
  self.size = self.size or 72
  self.duration = self.duration or 1.4
  self.tick_interval = self.tick_interval or 0.25
  self.damage = self.damage or 2
  self.rotation = self.rotation or 0
  self.fill_alpha = self.fill_alpha or 0.065
  self.entry_blink_duration = 0.16
  self.exit_blink_duration = 0.32
  self.blink_interval = 0.08
  self.time = 0
  self.tick_time = 0
end

function BurningSquareArea:update(dt, enemies)
  self.time = math.min(self.time + dt, self.duration)
  self.tick_time = self.tick_time - dt

  if self.tick_time <= 0 then
    self.tick_time = self.tick_interval
    self:damage_enemies(enemies)
  end

  if self.time == self.duration then self.dead = true end
end

function BurningSquareArea:contains(enemy)
  local dx, dy = enemy.x - self.x, enemy.y - self.y
  local c, s = math.cos(-self.rotation), math.sin(-self.rotation)
  local local_x = dx * c - dy * s
  local local_y = dx * s + dy * c
  return math.abs(local_x) <= self.size / 2 and math.abs(local_y) <= self.size / 2
end

function BurningSquareArea:damage_enemies(enemies)
  for _, enemy in ipairs(enemies or {}) do
    if not enemy.dead and self:contains(enemy) then enemy:hit(self.damage) end
  end
end

function BurningSquareArea:draw()
  local progress = self.time / self.duration
  local remaining = self.duration - self.time
  local entry_blinking = self.time < self.entry_blink_duration
  local exit_blinking = remaining <= self.exit_blink_duration

  if entry_blinking then
    local blink_index = math.floor(self.time / self.blink_interval)
    if blink_index % 2 == 1 then return end
  elseif exit_blinking then
    local blink_index = math.floor((self.exit_blink_duration - remaining) / self.blink_interval)
    if blink_index % 2 == 1 then return end
  end

  local flashing = entry_blinking or exit_blinking
  local alpha = math.max(1 - progress * 0.45, 0)
  local heat = 0.55 + 0.45 * math.sin(self.time * 7) ^ 2
  local color = flashing and {1, 1, 1, 1} or
    graphics.color_with_alpha(self.color, alpha)
  local fill_color = graphics.color_with_alpha(self.color, self.fill_alpha * heat)

  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.rotation)
  draw_seal_area_frame(0, 0, self.size, color, fill_color)
  love.graphics.pop()
end
