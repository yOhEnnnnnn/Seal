Projectile = Object:extend()
Projectile:implement(GameObject)
Projectile:implement(Physics)

function Projectile:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.speed = self.speed or Data.player.projectile_speed
  self.hit_power = self.hit_power or Data.player.projectile_hit_power
  self.radius = self.radius or Data.player.projectile_radius
  self.visual_width = self.visual_width or Data.player.projectile_width
  self.visual_height = self.visual_height or Data.player.projectile_height
  self.arena_width = self.arena_width or aw
  self.arena_height = self.arena_height or ah
  self.width = self.radius * 2
  self.height = self.radius * 2
  self.effects = self.effects or Group()
  self.color = self.color or Data.bullets.color
  self.score_bonus = self.score_bonus or Data.bullets.score_bonus
  self.bounces = self.bounces or 0
  self.critical_chance = self.critical_chance or 0
  self.luck_chance = self.luck_chance or 0
  self.critical = love.math.random() < self.critical_chance
  if self.critical then
    self.hit_power = self.hit_power * Data.upgrades.critical_multiplier
    self.radius = self.radius + 1
    self.visual_width = self.visual_width * 1.25
    self.visual_height = self.visual_height * 1.25
    self.width, self.height = self.radius * 2, self.radius * 2
    self.color = Data.theme.colors.gold
  end
  self:set_as_circle(self.radius, "dynamic", "projectile")
  self:set_velocity(self.speed * math.cos(self.r), self.speed * math.sin(self.r))
end

function Projectile:trigger_lucky_effect(origin, enemies)
  if love.math.random() >= self.luck_chance then return end
  local effect = love.math.random(1, 3)
  if effect == 1 then
    local closest, closest_distance
    local range_squared = Data.upgrades.luck_chain_range ^ 2
    for _, enemy in ipairs(enemies) do
      if enemy ~= origin and not enemy.dead then
        local dx, dy = enemy.x - origin.x, enemy.y - origin.y
        local distance = dx * dx + dy * dy
        if distance <= range_squared and
          (not closest_distance or distance < closest_distance) then
          closest, closest_distance = enemy, distance
        end
      end
    end
    if closest then
      closest:hit(self:get_effect_hit_power(0.6), self)
      self.effects:add(LuckyChain{
        x = origin.x, y = origin.y,
        target_x = closest.x, target_y = closest.y,
      })
    end
  elseif effect == 2 then
    self.effects:add(LuckyEmber{
      x = origin.x, y = origin.y,
      hit_power = self:get_effect_hit_power(0.25),
      source = self,
    })
  else
    self.effects:add(LuckyFrost{x = origin.x, y = origin.y})
  end
end

function Projectile:get_effect_hit_power(multiplier)
  return math.max(1, math.floor(self.hit_power * multiplier + 0.5))
end

function Projectile:update(dt, enemies)
  if self.dead then return end
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
    self:check_hits(enemies, self.x + dx * travel, self.y + dy * travel)
    if self.dead or wall_t > 1 then break end

    local hit_x, hit_y = tx <= ty, ty <= tx
    self:hit_wall(hit_x, hit_y)
    remaining = remaining * (1 - travel)
  end
  if self.lifetime then
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then self.dead = true end
  end
end

function Projectile:hit_wall(hit_x, hit_y)
  if self.audio then self.audio:play("wall_hit") end
  if self.bounces <= 0 then
    self:spawn_wall_impact_particles(hit_x, hit_y)
    self.dead = true
    return
  end
  if hit_x then self.vx = -self.vx end
  if hit_y then self.vy = -self.vy end
  self.r = math.atan2(self.vy, self.vx)
  self.bounces = self.bounces - 1
  self.score_bonus = self.score_bonus + Data.bullets.bounce_score_bonus
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
    if not enemy.dead then
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
  nearest:hit(self.hit_power, self)
  nearest:spawn_hit_particles(self.r + math.pi, self.color)
  self:trigger_lucky_effect(nearest, enemies)
  self.dead = true
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
