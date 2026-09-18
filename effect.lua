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

ChainLightning = Object:extend()
ChainLightning:implement(GameObject)

function ChainLightning:init(args)
  self:init_game_object(args)
  self.duration, self.time = self.duration or 0.1, 0
  self.width = 3
  self.color = self.color or {1 / 255, 155 / 255, 214 / 255, 1}
  self.flash_color = {218 / 255, 218 / 255, 218 / 255, 1}
  self:generate()
  if self.effects then
    for index = 1, 3 do
      self.effects:add(HitParticle{
        x = index <= 2 and self.x or self.target_x,
        y = index <= 2 and self.y or self.target_y,
        color = self.color,
      })
    end
  end
end

-- Match SNKRX's LightningLine subdivision and point ordering.
function ChainLightning:generate()
  local lines = {{self.x, self.y, self.target_x, self.target_y}}
  local offset = self.max_offset or 8
  for generation = 1, self.generations or 3 do
    for index = #lines, 1, -1 do
      local line = table.remove(lines, index)
      local x1, y1, x2, y2 = unpack(line)
      local dx, dy = x2 - x1, y2 - y1
      local length = math.sqrt(dx * dx + dy * dy)
      local nx, ny = 0, 0
      if length > 0 then nx, ny = -dy / length, dx / length end
      local x = (x1 + x2) / 2 + nx * (love.math.random() * 2 - 1) * offset
      local y = (y1 + y2) / 2 + ny * (love.math.random() * 2 - 1) * offset
      lines[#lines + 1] = {x1, y1, x, y}
      lines[#lines + 1] = {x, y, x2, y2}
    end
    offset = offset / 2
  end

  self.points = {}
  while #lines > 0 do
    local nearest, distance = 1, math.huge
    for index, line in ipairs(lines) do
      local d = (line[1] - self.x)^2 + (line[2] - self.y)^2
      if d < distance then nearest, distance = index, d end
    end
    local line = table.remove(lines, nearest)
    self.points[#self.points + 1] = line[1]
    self.points[#self.points + 1] = line[2]
  end
end

function ChainLightning:update(dt)
  self.time = math.min(self.time + dt, self.duration)
  self.width = 3 - 2 * self.time / self.duration
  if self.time == self.duration then self.dead = true end
end

function ChainLightning:draw()
  graphics.circle(self.x, self.y, 6, self.flash_color)
  graphics.circle(self.target_x, self.target_y, 6, self.flash_color)
  love.graphics.push("all")
  graphics.set_color(self.color)
  love.graphics.setLineWidth(self.width)
  love.graphics.line(self.points)
  love.graphics.pop()
end

BurningArea = Object:extend()
BurningArea:implement(GameObject)

function BurningArea:init(args)
  self:init_game_object(args)
  self.size = self.size or 96
  self.duration = self.duration or 2.4
  self.tick_interval = self.tick_interval or 0.4
  self.impact_damage = self.damage or 10
  self.damage = 2.5
  self.time, self.tick_time = 0, 0
  self.visual_size = 0
  self.can_damage = true
  self.impact_pending = true
  self.hidden = false
  self.foreground = {218 / 255, 218 / 255, 218 / 255, 1}
end

function BurningArea:update(dt, enemies)
  self.time = math.min(self.time + dt, self.duration)
  self.visual_size = self.size * cubic_in_out(math.min(self.time / 0.05, 1))
  if self.time >= self.duration - 0.35 then
    self.hidden = math.floor((self.time - self.duration + 0.35) / 0.05) % 2 == 0
  end
  local half_size = self.size / 2
  local cosine, sine = math.cos(self.r), math.sin(self.r)
  if self.impact_pending then
    self.impact_pending = false
    for _, enemy in ipairs(enemies) do
      local dx, dy = enemy.x - self.x, enemy.y - self.y
      local local_x = cosine * dx + sine * dy
      local local_y = -sine * dx + cosine * dy
      if not enemy.dead and math.abs(local_x) <= half_size and
        math.abs(local_y) <= half_size then
        enemy:hit(self.impact_damage, self.source)
        enemy:spawn_hit_particles(math.atan2(dy, dx), self.color)
      end
    end
  end
  self.tick_time = self.tick_time + dt
  while self.tick_time >= self.tick_interval do
    self.tick_time = self.tick_time - self.tick_interval
    for _, enemy in ipairs(enemies) do
      local dx, dy = enemy.x - self.x, enemy.y - self.y
      local local_x = cosine * dx + sine * dy
      local local_y = -sine * dx + cosine * dy
      if not enemy.dead and math.abs(local_x) <= half_size and
        math.abs(local_y) <= half_size then
        enemy:hit(self.damage, self.source)
      end
    end
  end
  if self.time == self.duration then self.dead = true end
end

function BurningArea:draw()
  if self.hidden then return end
  local half = self.visual_size / 2
  local corner = self.visual_size / 10
  local x1, y1, x2, y2 = -half, -half, half, half
  local line_color = self.time < 0.2 and self.foreground or self.color
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.r)
  graphics.rectangle(0, 0, self.visual_size, self.visual_size,
    nil, nil, graphics.color_with_alpha(self.color, 0.08))
  graphics.polyline(line_color, 2, x1, y1 + corner, x1, y1, x1 + corner, y1)
  graphics.polyline(line_color, 2, x2 - corner, y1, x2, y1, x2, y1 + corner)
  graphics.polyline(line_color, 2, x2 - corner, y2, x2, y2, x2, y2 - corner)
  graphics.polyline(line_color, 2, x1, y2 - corner, x1, y2, x1 + corner, y2)
  love.graphics.pop()
end

FrostArea = Object:extend()
FrostArea:implement(GameObject)

function FrostArea:init(args)
  self:init_game_object(args)
  self.radius = self.radius or 60
  self.duration = self.duration or 2.5
  self.slow_multiplier = self.slow_multiplier or 0.45
  self.impact_damage = self.damage or 10
  self.impact_pending = true
  self.time, self.rotation = 0, 0
  self.visual_radius = 0
  self.hidden = false
  self.rotation_speed = (love.math.random() < 0.5 and -1 or 1) *
    (math.pi / 4) * (0.5 + love.math.random() * 0.5)
  self.foreground = {218 / 255, 218 / 255, 218 / 255, 1}
end

function FrostArea:update(dt, enemies)
  self.time = math.min(self.time + dt, self.duration)
  self.rotation = self.rotation + self.rotation_speed * dt
  self.visual_radius = self.radius * cubic_in_out(math.min(self.time / 0.05, 1))
  if self.time >= self.duration - 0.35 then
    self.hidden = math.floor((self.time - self.duration + 0.35) / 0.05) % 2 == 0
  end
  local radius_squared = self.radius * self.radius
  for _, enemy in ipairs(enemies) do
    local dx, dy = enemy.x - self.x, enemy.y - self.y
    if not enemy.dead and dx * dx + dy * dy <= radius_squared then
      if self.impact_pending then
        enemy:hit(self.impact_damage, self.source)
        enemy:spawn_hit_particles(math.atan2(dy, dx), self.color)
      end
      enemy:slow(self.slow_multiplier, 0.1)
    end
  end
  self.impact_pending = false
  if self.time == self.duration then self.dead = true end
end

function FrostArea:draw()
  if self.hidden then return end
  local line_color = self.time < 0.2 and self.foreground or self.color
  graphics.circle(self.x, self.y, self.visual_radius,
    graphics.color_with_alpha(self.color, 0.08))
  for index = 1, 4 do
    local center = self.rotation + (index - 1) * math.pi / 2 + math.pi / 4
    graphics.arc("open", self.x, self.y, self.visual_radius,
      center - math.pi / 8, center + math.pi / 8, line_color, 2)
  end
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
    self.x, self.y = gw / 2, gh / 2
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
