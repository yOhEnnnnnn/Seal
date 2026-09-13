Projectile = Object:extend()
Projectile:implement(GameObject)
Projectile:implement(Physics)

function Projectile:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.speed = self.speed or 160
  self.damage = self.damage or 10
  self.radius = self.radius or 2.5
  self.width = self.radius * 2
  self.height = self.radius * 2
  self.color = self.color or {1, 1, 1, 1}
  self.effects = self.effects or Group()
  self.pierce = self.pierce or 0
  self.damage_decay = self.damage_decay or 1
  self.hit_enemies = self.hit_enemies or {}
  self:set_as_circle(self.radius, "dynamic", "projectile")
  self:set_velocity(self.speed * math.cos(self.r), self.speed * math.sin(self.r))
end

function Projectile:update(dt, enemies)
  if self.dead then return end
  if self.lifetime then dt = math.min(dt, self.lifetime) end
  local remaining = dt
  while remaining > 0 and not self.dead do
    local dx, dy = self.vx * remaining, self.vy * remaining
    local tx = dx > 0 and (gw - self.radius - self.x) / dx or
      (dx < 0 and (self.radius - self.x) / dx or math.huge)
    local ty = dy > 0 and (gh - self.radius - self.y) / dy or
      (dy < 0 and (self.radius - self.y) / dy or math.huge)
    local wall_t = math.min(tx, ty)
    local travel = math.max(0, math.min(1, wall_t))
    self:check_hits(enemies, self.x + dx * travel, self.y + dy * travel)
    if self.dead or wall_t > 1 then break end

    local hit_x, hit_y = tx <= ty, ty <= tx
    if not self.bounces or self.bounces <= 0 then
      self:spawn_wall_impact_particles(hit_x, hit_y)
      self.dead = true
      break
    end
    if hit_x then self.vx = -self.vx end
    if hit_y then self.vy = -self.vy end
    self.r = math.atan2(self.vy, self.vx)
    self.bounces = self.bounces - 1
    remaining = remaining * (1 - travel)
  end
  if self.lifetime then
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then self.dead = true end
  end
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
  while not self.dead do
    local nearest, hit_t = nil, math.huge
    for _, enemy in ipairs(enemies) do
      if not enemy.dead and not self.hit_enemies[enemy] then
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
    nearest:hit(self.damage)
    self.hit_enemies[nearest] = true
    nearest:spawn_hit_particles(self.r + math.pi, self.color)
    if self.on_hit then self.on_hit(self, nearest, enemies) end
    if self.pierce <= 0 then
      self.dead = true
      return
    end
    self.pierce = self.pierce - 1
    self.damage = self.damage * self.damage_decay
  end
end

function Projectile:draw()
  graphics.circle(self.x, self.y, self.radius, self.color)
end
