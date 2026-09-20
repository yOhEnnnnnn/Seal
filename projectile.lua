Projectile = Object:extend()
Projectile:implement(GameObject)
Projectile:implement(Physics)

function Projectile:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.speed = self.speed or Data.player.projectile_speed
  self.base_speed = self.speed
  self.base_hit_power = self.hit_power or Data.player.projectile_hit_power
  self.base_radius = self.radius or Data.player.projectile_radius
  self.radius = self.base_radius
  self.base_visual_width = self.visual_width or Data.player.projectile_width
  self.base_visual_height = self.visual_height or Data.player.projectile_height
  self.visual_width = self.base_visual_width
  self.visual_height = self.base_visual_height
  self.arena_width = self.arena_width or aw
  self.arena_height = self.arena_height or ah
  self.width = self.radius * 2
  self.height = self.radius * 2
  self.effects = self.effects or Group()
  self.color = self.color or Data.bullets.color
  self.score_bonus = self.score_bonus or Data.bullets.score_bonus
  self.momentum = 0
  self.momentum_gain = 1
  self.momentum_decay_time = 0
  self.ignored_enemy = nil
  self.ignore_time = 0
  self:set_as_circle(self.radius, "dynamic", "projectile")
  self:set_velocity(self.speed * math.cos(self.r), self.speed * math.sin(self.r))
  self:update_momentum_stats()
end

function Projectile:update_momentum_stats()
  self.radius = self.base_radius
  self.width, self.height = self.radius * 2, self.radius * 2
  local scale = self.radius / Data.player.projectile_radius
  self.visual_width = self.base_visual_width * scale
  self.visual_height = self.base_visual_height * scale

  local speed_multiplier = 1 + math.min(
    self.momentum * Data.upgrades.momentum_speed_per_point,
    Data.upgrades.momentum_speed_bonus_max)
  self.speed = self.base_speed * speed_multiplier
  if self.vx and self.vy then
    self:set_velocity(self.speed * math.cos(self.r), self.speed * math.sin(self.r))
  end
end

function Projectile:add_momentum()
  self.momentum = self.momentum + self.momentum_gain
  self.momentum_decay_time = Data.upgrades.momentum_decay_delay
  self:update_momentum_stats()
end

function Projectile:update(dt, enemies)
  if self.dead then return end
  self.ignore_time = math.max(self.ignore_time - dt, 0)
  if self.ignore_time == 0 then self.ignored_enemy = nil end
  if self.momentum_decay_time > 0 then
    self.momentum_decay_time = math.max(self.momentum_decay_time - dt, 0)
  elseif self.momentum > 0 then
    self.momentum = math.max(
      0, self.momentum - Data.upgrades.momentum_decay_per_second * dt)
    self:update_momentum_stats()
  end
  if self.lifetime then dt = math.min(dt, self.lifetime) end
  local remaining = dt
  while remaining > 0 and not self.dead do
    local dx, dy = self.vx * remaining, self.vy * remaining
    local tx = dx > 0 and (self.arena_width - self.radius - self.x) / dx or
      (dx < 0 and (self.radius - self.x) / dx or math.huge)
    local ty = dy > 0 and (self.arena_height - self.radius - self.y) / dy or
      (dy < 0 and (self.radius - self.y) / dy or math.huge)
    local wall_t = math.min(tx, ty)
    local travel = math.max(0, math.min(1, wall_t))
    local hit_enemy = self:check_hits(
      enemies, self.x + dx * travel, self.y + dy * travel)
    if hit_enemy or self.dead or wall_t > 1 then break end

    local hit_x, hit_y = tx <= ty, ty <= tx
    self:hit_wall(hit_x, hit_y)
    remaining = remaining * (1 - travel)
  end
  if self.lifetime then
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then self:shatter() end
  end
end

function Projectile:shatter()
  if self.dead then return end
  for _ = 1, 3 do
    local width = 4 + love.math.random() * 2
    self.effects:add(HitParticle{
      x = self.x,
      y = self.y,
      r = love.math.random() * math.pi * 2,
      speed = 45 + love.math.random() * 55,
      duration = 0.14 + love.math.random() * 0.12,
      width = width,
      height = width / 2,
      color = self.color,
    })
  end
  self.effects:add(HitCircle{
    x = self.x,
    y = self.y,
    radius = 5,
    duration = 0.08,
    color = {1, 1, 1, 1},
    target_color = self.color,
  })
  self.dead = true
end

function Projectile:hit_wall(hit_x, hit_y)
  if self.audio then self.audio:play("wall_hit") end
  self:spawn_wall_impact_particles(hit_x, hit_y)
  self.dead = true
end

function Projectile:spawn_wall_impact_particles(hit_x, hit_y)
  local r
  if hit_x and hit_y then
    r = self.r + math.pi
  elseif hit_x then
    r = self.x < self.arena_width / 2 and 0 or math.pi
  else
    r = self.y < self.arena_height / 2 and math.pi / 2 or -math.pi / 2
  end
  for _ = 1, 3 do
    local width = 4.5 + love.math.random() * 2
    self.effects:add(HitParticle{
      x = self.x,
      y = self.y,
      r = r + (love.math.random() * 2 - 1) * math.pi / 2,
      speed = 60 + love.math.random() * 60,
      duration = 0.18 + love.math.random() * 0.12,
      width = width,
      height = width / 2,
      color = self.color,
    })
  end

  self.effects:add(HitCircle{
    x = self.x,
    y = self.y,
    radius = 6,
    duration = 0.08,
    color = {1, 1, 1, 1},
    target_color = self.color,
  })
end

function Projectile:check_hits(enemies, end_x, end_y)
  local start_x, start_y = self.x, self.y
  local nearest, hit_t = nil, math.huge
  for _, enemy in ipairs(enemies) do
    if not enemy.dead and enemy ~= self.ignored_enemy then
      local t = Collision.sweep_circle(start_x, start_y, end_x, end_y,
        self.radius, enemy)
      if t < hit_t then nearest, hit_t = enemy, t end
    end
  end
  if not nearest then
    self.x, self.y = end_x, end_y
    return
  end

  self.x = start_x + (end_x - start_x) * hit_t
  self.y = start_y + (end_y - start_y) * hit_t
  local hit_power = self.base_hit_power + math.floor(
    self.momentum / Data.upgrades.momentum_damage_step)
  self.score_bonus = Data.bullets.score_bonus + math.floor(self.momentum / 3)
  nearest:hit(hit_power, self)
  self.ignored_enemy = nearest
  self.ignore_time = 0.06
  nearest:spawn_hit_particles(self.r + math.pi, self.color)
  self:add_momentum()
  local normal_x, normal_y = self.x - nearest.x, self.y - nearest.y
  local normal_length = math.sqrt(normal_x * normal_x + normal_y * normal_y)
  if normal_length == 0 then
    normal_x, normal_y, normal_length = -self.vx, -self.vy, self.speed
  end
  normal_x, normal_y = normal_x / normal_length, normal_y / normal_length
  local velocity_dot_normal = self.vx * normal_x + self.vy * normal_y
  self.vx = self.vx - 2 * velocity_dot_normal * normal_x
  self.vy = self.vy - 2 * velocity_dot_normal * normal_y
  self.r = math.atan2(self.vy, self.vx)
  self.x = self.x + normal_x * 0.01
  self.y = self.y + normal_y * 0.01
  return true
end

function Projectile:draw()
  local offset = Data.player.projectile_depth_offset
  love.graphics.push("all")
  love.graphics.translate(self.x + offset, self.y + offset)
  love.graphics.rotate(self.r)
  graphics.rectangle(0, 0, self.visual_width, self.visual_height,
    1, 1, {0.32, 0.33, 0.32, 0.72})
  love.graphics.pop()

  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.r)
  graphics.rectangle(0, 0, self.visual_width, self.visual_height,
    1, 1, self.color)
  love.graphics.pop()
end
