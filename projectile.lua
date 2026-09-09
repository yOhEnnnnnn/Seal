Projectile = Object:extend()
Projectile:implement(GameObject)
Projectile:implement(Physics)

function Projectile:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.speed = self.speed or 160
  self.damage = self.damage or 10
  self.width = self.width or 8
  self.height = self.height or 3.2
  self.color = self.color or {1, 1, 1, 1}
  self.effects = self.effects or {}
  self.pierce = self.pierce or 0
  self.damage_decay = self.damage_decay or 1
  self.hit_enemies = self.hit_enemies or {}
  self:set_as_rectangle(self.width, self.height, "dynamic", "projectile")
  self:set_velocity(self.speed * math.cos(self.r), self.speed * math.sin(self.r))
end

function Projectile:update(dt, enemies)
  self:update_game_object(dt)
  if self.lifetime then
    self.lifetime = math.max(self.lifetime - dt, 0)
    if self.lifetime == 0 then
      self.dead = true
      return
    end
  end
  self:check_hits(enemies)
  if not self.dead then self:check_bounds() end
end

function Projectile:spawn_wall_impact_particles(hit_x, hit_y)
  local r
  if hit_x and hit_y then
    r = self.r + math.pi
  elseif hit_x then
    r = self.x < gw / 2 and 0 or math.pi
  else
    r = self.y < gh / 2 and math.pi / 2 or -math.pi / 2
  end
  for _ = 1, 3 do
    local width = 4.5 + love.math.random() * 2
    self.effects[#self.effects + 1] = HitParticle{
      x = self.x,
      y = self.y,
      r = r + (love.math.random() * 2 - 1) * math.pi / 2,
      speed = 60 + love.math.random() * 60,
      duration = 0.18 + love.math.random() * 0.12,
      width = width,
      height = width / 2,
      color = self.color,
    }
  end


  self.effects[#self.effects + 1] = HitCircle{
    x = self.x,
    y = self.y,
    radius = 6,
    duration = 0.08,
    color = {1, 1, 1, 1},
    target_color = self.color,
  }
end

function Projectile:check_bounds()
  local half_width = self.width / 2
  local half_height = self.height / 2
  local cosine = math.abs(math.cos(self.r))
  local sine = math.abs(math.sin(self.r))
  local extent_x = half_width * cosine + half_height * sine
  local extent_y = half_width * sine + half_height * cosine
  local hit_x = self.x - extent_x <= 0 or self.x + extent_x >= gw
  local hit_y = self.y - extent_y <= 0 or self.y + extent_y >= gh

  if self.bounces ~= nil then
    if not hit_x and not hit_y then return end

    if self.bounces <= 0 then
      self:spawn_wall_impact_particles(hit_x, hit_y)
      self.dead = true
      return
    end

    self.x = math.max(extent_x, math.min(gw - extent_x, self.x))
    self.y = math.max(extent_y, math.min(gh - extent_y, self.y))
    if hit_x then self.vx = -self.vx end
    if hit_y then self.vy = -self.vy end
    self.r = math.atan2(self.vy, self.vx)
    self.bounces = self.bounces - 1
    return
  end

  if hit_x or hit_y then
    self:spawn_wall_impact_particles(hit_x, hit_y)
    self.dead = true
  end
end

function Projectile:check_hits(enemies)
  if self.dead then return end

  for _, enemy in ipairs(enemies or {}) do
    if not enemy.dead and not self.hit_enemies[enemy] and
      self:is_colliding_with_object(enemy) then
      enemy:hit(self.damage)
      if self.slow_multiplier and enemy.apply_slow then
        enemy:apply_slow(self.slow_multiplier, self.slow_duration)
      end
      self.hit_enemies[enemy] = true
      enemy:spawn_hit_particles(self.r + math.pi, self.color)
      if self.on_hit then self.on_hit(self, enemy, enemies) end

      if self.pierce <= 0 then
        self.dead = true
        return
      end

      self.pierce = self.pierce - 1
      self.damage = self.damage * self.damage_decay
      return
    end
  end
end

function Projectile:draw()
  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.r)
  graphics.rectangle(0, 0, self.width, self.height, 1.6, 1.6, self.color)
  love.graphics.pop()
end

require("projectile.wisp")
