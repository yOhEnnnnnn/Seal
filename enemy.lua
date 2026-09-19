Enemy = Object:extend()
Enemy:implement(GameObject)
Enemy:implement(Physics)
Enemy:implement(Unit)

function Enemy:init(args)
  self:init_game_object(args)
  self:init_physics(args)
  self.base_score = self.base_score or EnemyConfig.base_score
  self.max_hp = self.max_hp or EnemyConfig.max_hp
  self:init_unit(args)
  self.hp = self.hp or self.max_hp
  self.v = self.v or self.speed or EnemyConfig.move_speed
  self.damage = self.damage or EnemyConfig.damage
  self.def = self.def or 0
  self.width = self.width or EnemyConfig.width
  self.height = self.height or EnemyConfig.height
  self.color = self.color or {1, 1, 1, 1}
  self.hit_color = self.hit_color or {1, 1, 1, 1}
  self.effects = self.effects or Group()
  self.invincible = self.invincible or false
  self.stationary = self.stationary or false
  self.hit_spring = Spring(1)
  self.hit_duration = EnemyConfig.hit_duration
  self.hit_time = 0
  self:set_as_rectangle(self.width, self.height, "dynamic", "enemy")
end

function Enemy:update(dt, player, enemies)
  if self.dead then return end
  local speed = self.v
  self.max_v = speed
  self.max_speed = speed
  self.hit_spring:update(dt)
  self.hit_time = math.max(self.hit_time - dt, 0)
  if self.stationary then
    self:stop()
  else
    local dx, dy = player.x - self.x, player.y - self.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > 0 then
      self.r = math.atan2(dy, dx)
      self:set_velocity(dx / distance * speed, dy / distance * speed)
    else
      self:stop()
    end
    self:update_physics(dt)
  end
  if self:is_colliding_with_object(player) then
    player:hit(self.damage)
    self.reached_center = true
    self.dead = true
  end
end

function Enemy:spawn_hit_particles(r, impact_color)
  impact_color = impact_color or self.hit_color
  for index = 1, 3 do
    local width = 4.5 + love.math.random() * 2.5
    self.effects:add(HitParticle{
      x = self.x,
      y = self.y,
      r = r + (love.math.random() * 2 - 1) * math.pi / 2,
      speed = 65 + love.math.random() * 70,
      duration = 0.18 + love.math.random() * 0.18,
      width = width,
      height = width / 2,
      color = index == 1 and impact_color or self.color,
    })
  end

  self.effects:add(HitCircle{
    x = self.x,
    y = self.y,
    radius = 7,
    duration = 0.08,
    color = self.hit_color,
    target_color = impact_color,
  })
end

function Enemy:hit(damage, projectile)
  if self.dead then return end
  self.hit_spring:pull(0.25, 200, 10)
  self.hit_time = self.hit_duration
  if self.invincible then return end
  Unit.hit(self, damage * 100 / (100 + self.def))
  if self.dead then
    self.kill_score = self.base_score + (projectile and projectile.score_bonus or 0)
  end
end

function Enemy:on_death()
  for _ = 1, love.math.random(4, 6) do
    self.effects:add(HitParticle{
      x = self.x,
      y = self.y,
      color = self.color,
    })
  end

  self.effects:add(HitCircle{
    x = self.x,
    y = self.y,
    radius = 12,
    color = self.hit_color,
    target_color = self.color,
  })
end

function Enemy:get_health_alpha()
  local health = math.max(0, math.min(self.hp / self.max_hp, 1))
  local minimum = EnemyConfig.min_health_alpha
  return minimum + health ^ EnemyConfig.health_alpha_exponent * (1 - minimum)
end

function Enemy:get_color()
  local color = self.hit_time > 0 and self.hit_color or self.color
  return graphics.color_with_alpha(color, self:get_health_alpha())
end

function Enemy:get_depth_color()
  return {0.48, 0.49, 0.47, self:get_health_alpha() * 0.8}
end

function Enemy:draw()
  if self.dead then return end
  love.graphics.push("all")
  love.graphics.translate(self.x + EnemyConfig.depth_offset,
    self.y + EnemyConfig.depth_offset)
  love.graphics.rotate(self.r)
  love.graphics.scale(self.hit_spring.x, self.hit_spring.x)
  graphics.rectangle(0, 0, self.width, self.height, 1, 1,
    self:get_depth_color())
  love.graphics.pop()

  love.graphics.push("all")
  love.graphics.translate(self.x, self.y)
  love.graphics.rotate(self.r)
  love.graphics.scale(self.hit_spring.x, self.hit_spring.x)
  graphics.rectangle(0, 0, self.width, self.height, 1, 1, self:get_color())
  love.graphics.pop()
end
